import Foundation
import SwiftData

struct FeedItem {
    var title: String
    var link: URL
    var contentHTML: String?
    var author: String?
    var publishedAt: Date?
    var featuredImageURL: URL?
}

struct FeedMeta {
    var title: String?
    var thumbnailURL: URL?
}

enum FeedFormat { case rss2, atom }

enum FeedError: Error {
    case invalidResponse
    case notFeed
    case badStatus(Int)
}

// MARK: - Unified FeedService
struct FeedService {
    private static let batchSize = 50
    private static let maxArticlesPerFeed = 50
    
    // MARK: - Core Operations
    
    static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5",
                    forHTTPHeaderField: "Accept")
        
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FeedError.badStatus(http.statusCode) }
        
        return data
    }
    
    static func detectFormat(from data: Data) -> FeedFormat? {
        let prefix = String(data: data.prefix(512), encoding: .utf8)?.lowercased() ?? ""
        if prefix.contains("<rss") || prefix.contains("<rdf") { return .rss2 }
        if prefix.contains("<feed") { return .atom }
        return nil
    }
    
    static func parseFeed(data: Data, url: URL) throws -> (meta: FeedMeta, items: [FeedItem]) {
        guard let format = detectFormat(from: data) else { throw FeedError.notFeed }
        let parser = XMLFeedParser(data: data, baseURL: url)
        switch format {
        case .rss2: return try parser.parseRSS2()
        case .atom: return try parser.parseAtom()
        }
    }
    
    // MARK: - Main Operations
    
    static func subscribe(url: URL, title: String? = nil, modelContainer: ModelContainer) async throws -> Feed {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        // Check if exists
        let predicate = #Predicate<Feed> { $0.url == url }
        if let existing = try context.fetch(FetchDescriptor<Feed>(predicate: predicate)).first {
            return existing
        }
        
        // Fetch and parse
        let data = try await fetch(url: url)
        let parsed = try parseFeed(data: data, url: url)
        let feedTitle = parsed.meta.title ?? title ?? url.host ?? "Untitled Feed"
        
        // Create feed
        let feed = Feed(title: feedTitle, url: url, thumbnailURL: parsed.meta.thumbnailURL)
        context.insert(feed)
        
        // Save articles
        try saveArticles(parsed.items, to: feed, context: context)
        try context.save()
        
        return feed
    }
    
    static func refresh(_ feed: Feed, modelContainer: ModelContainer) async throws -> Int {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let data = try await fetch(url: feed.url)
        let parsed = try parseFeed(data: data, url: feed.url)
        
        try saveArticles(parsed.items, to: feed, context: context)
        
        // Cleanup old articles
        let allArticles = feed.articles.sorted { $0.publishedAt > $1.publishedAt }
        if allArticles.count > maxArticlesPerFeed {
            let toDelete = Array(allArticles[maxArticlesPerFeed...])
            toDelete.forEach { context.delete($0) }
        }
        
        try context.save()
        return parsed.items.count
    }
    
    static func refreshAll(modelContainer: ModelContainer) async throws -> Int {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let feeds = try context.fetch(FetchDescriptor<Feed>())
        var totalRefreshed = 0
        
        for feed in feeds {
            do {
                let data = try await fetch(url: feed.url)
                let parsed = try parseFeed(data: data, url: feed.url)
                try saveArticles(parsed.items, to: feed, context: context)
                totalRefreshed += parsed.items.count
            } catch {
                print("Failed to refresh feed \(feed.title): \(error)")
            }
        }
        
        // Cleanup all feeds
        for feed in feeds {
            let allArticles = feed.articles.sorted { $0.publishedAt > $1.publishedAt }
            if allArticles.count > maxArticlesPerFeed {
                let toDelete = Array(allArticles[maxArticlesPerFeed...])
                toDelete.forEach { context.delete($0) }
            }
        }
        
        try context.save()
        return totalRefreshed
    }
    
    static func importOPML(data: Data, modelContainer: ModelContainer) async throws -> [Feed] {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let feedsToImport = try parseOPML(data: data)
        var importedFeeds: [Feed] = []
        
        for (title, url) in feedsToImport {
            do {
                // Check if exists
                let predicate = #Predicate<Feed> { $0.url == url }
                if let existing = try context.fetch(FetchDescriptor<Feed>(predicate: predicate)).first {
                    importedFeeds.append(existing)
                    continue
                }
                
                let feed = try await subscribe(url: url, title: title, modelContainer: modelContainer)
                importedFeeds.append(feed)
            } catch {
                print("Failed to import feed \(title): \(error)")
            }
        }
        
        return importedFeeds
    }
    
    // MARK: - Helper Methods
    
    private static func saveArticles(_ items: [FeedItem], to feed: Feed, context: ModelContext) throws {
        // Process in batches
        for batchStart in stride(from: 0, to: items.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, items.count)
            let itemBatch = Array(items[batchStart..<batchEnd])
            
            for item in itemBatch {
                let link = item.link
                let predicate = #Predicate<Article> { $0.link == link }
                let existingArticles = try context.fetch(FetchDescriptor<Article>(predicate: predicate))
                
                if let existing = existingArticles.first {
                    // Update existing (preserve user state)
                    existing.title = item.title
                    existing.contentHTML = item.contentHTML
                    existing.author = item.author
                    existing.featuredImageURL = item.featuredImageURL
                } else {
                    // Create new
                    let article = Article(
                        feed: feed,
                        title: item.title,
                        link: item.link,
                        publishedAt: item.publishedAt ?? Date.now
                    )
                    article.contentHTML = item.contentHTML
                    article.author = item.author
                    article.featuredImageURL = item.featuredImageURL
                    context.insert(article)
                }
            }
        }
    }
    
    private static func parseOPML(data: Data) throws -> [(title: String, url: URL)] {
        class OPMLParser: NSObject, XMLParserDelegate {
            var feeds: [(String, URL)] = []
            var currentTitle: String?
            var currentUrl: String?

            func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName qName: String?,
                       attributes attributeDict: [String : String] = [:]) {
                if elementName == "outline",
                   let type = attributeDict["type"], type == "rss" {
                    currentTitle = attributeDict["title"] ?? attributeDict["text"]
                    currentUrl = attributeDict["xmlUrl"]
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "outline",
                   let title = currentTitle,
                   let urlString = currentUrl,
                   let url = URL(string: urlString) {
                    // Convert HTTP to HTTPS
                    let secureUrl = url.scheme?.lowercased() == "http"
                        ? URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")) ?? url
                        : url
                    feeds.append((title, secureUrl))
                    currentTitle = nil
                    currentUrl = nil
                }
            }
        }

        let parser = XMLParser(data: data)
        let opmlParser = OPMLParser()
        parser.delegate = opmlParser
        parser.parse()
        return opmlParser.feeds
    }
}
