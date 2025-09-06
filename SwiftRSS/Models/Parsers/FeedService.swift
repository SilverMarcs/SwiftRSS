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

struct FeedService {
    // Fetch raw data
    static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5", forHTTPHeaderField: "Accept")

        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FeedError.badStatus(http.statusCode) }

        return data
    }

    // Detect format by root tag
    static func detectFormat(from data: Data) -> FeedFormat? {
        // Simple sniff
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

    static func subscribe(url: URL, context: ModelContext) async throws -> Feed {
        // Fetch and parse once to confirm it's a feed and get title
        let data = try await fetch(url: url)
        let parsed = try parseFeed(data: data, url: url)
        let title = parsed.meta.title ?? url.host ?? "Untitled Feed"

        // Check if exists
        if let existing = try? context.fetch(FetchDescriptor<Feed>(predicate: #Predicate { $0.url == url })).first {
            return existing
        }

        let feed = Feed(title: title, url: url, thumbnailURL: parsed.meta.thumbnailURL)
        context.insert(feed)

        // Save initial items
        try saveItems(parsed.items, into: feed, context: context)
        try context.save()
        return feed
    }

    static func refresh(_ feed: Feed, context: ModelContext) async throws -> Int {
        let data = try await fetch(url: feed.url)
        let parsed = try parseFeed(data: data, url: feed.url)
        try saveItems(parsed.items, into: feed, context: context)
        
        context.autosaveEnabled = false
        // Keep only top 50 most recent articles
        let allArticles = feed.articles.sorted { ($0.publishedAt ?? Date.distantPast) > ($1.publishedAt ?? Date.distantPast) }
        if allArticles.count > 50 {
            let toDelete = Array(allArticles[50...])
            for article in toDelete {
                context.delete(article)
            }
        }
        try context.save()
        context.autosaveEnabled = true
        
        return parsed.items.count
    }

    static func refreshAll(context: ModelContext) async {
        let feeds = (try? context.fetch(FetchDescriptor<Feed>())) ?? []
        for feed in feeds {
            _ = try? await refresh(feed, context: context)
        }
    }

    private static func saveItems(_ items: [FeedItem], into feed: Feed, context: ModelContext) throws {
        for item in items {
            // Check if article already exists by ID (which is the URL string)
            let articleId = item.link
            let predicate = #Predicate<Article> { article in
                article.link == articleId
            }
            let existingArticles = try context.fetch(FetchDescriptor<Article>(predicate: predicate))
            
            let article: Article
            if let existing = existingArticles.first {
                // Update existing article (preserve isRead and isStarred)
                article = existing
                article.title = item.title
                article.contentHTML = item.contentHTML
                article.author = item.author
                article.featuredImageURL = item.featuredImageURL
                // Don't update publishedAt if it already exists to avoid date inconsistencies
                if article.publishedAt == nil {
                    article.publishedAt = item.publishedAt
                }
            } else {
                // Create new article
                article = Article(feed: feed,
                                  title: item.title,
                                  link: item.link,
                                  publishedAt: item.publishedAt)
                article.contentHTML = item.contentHTML
                article.author = item.author
                article.featuredImageURL = item.featuredImageURL
                context.insert(article)
            }
        }
    }
}
