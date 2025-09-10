//
//  BackgroundFeedProcessor.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 10/09/2025.
//

import Foundation
import SwiftData

actor BackgroundFeedProcessor {
    private let modelContainer: ModelContainer
    private let batchSize = 50
    private let maxArticlesPerFeed = 50
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func refreshAll() async throws -> Int {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let feeds = try context.fetch(FetchDescriptor<Feed>())
        var totalRefreshed = 0
        
        for feed in feeds {
            do {
                let count = try await processFeed(feed, context: context)
                totalRefreshed += count
            } catch {
                print("Failed to refresh feed \(feed.title): \(error)")
            }
        }
        
        try context.save()
        return totalRefreshed
    }
    
    func refreshSingle(feedURL: URL) async throws -> Int {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let predicate = #Predicate<Feed> { $0.url == feedURL }
        guard let feed = try context.fetch(FetchDescriptor<Feed>(predicate: predicate)).first else {
            throw FeedError.invalidResponse
        }
        
        let count = try await processFeed(feed, context: context)
        try context.save()
        return count
    }
    
    func subscribe(url: URL, title: String? = nil) async throws -> Feed {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        // Check if exists
        let predicate = #Predicate<Feed> { $0.url == url }
        if let existing = try context.fetch(FetchDescriptor<Feed>(predicate: predicate)).first {
            return existing
        }
        
        // Fetch and parse
        let data = try await FeedService.fetch(url: url)
        let parsed = try await FeedService.parseFeed(data: data, url: url)
        let feedTitle = parsed.meta.title ?? title ?? url.host ?? "Untitled Feed"
        
        // Create feed
        let feed = Feed(title: feedTitle, url: url, thumbnailURL: parsed.meta.thumbnailURL)
        context.insert(feed)
        
        // Process articles
        try await processArticles(parsed.items, into: feed, context: context)
        try context.save()
        
        return feed
    }
    
    func importOPML(data: Data) async throws -> [Feed] {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        let feedsToImport = try parseOPML(data: data)
        var importedFeeds: [Feed] = []
        
        for (title, url) in feedsToImport {
            do {
                let feed = try await subscribe(url: url, title: title)
                importedFeeds.append(feed)
            } catch {
                print("Failed to import feed \(title): \(error)")
            }
        }
        
        return importedFeeds
    }
    
    // MARK: - Private Helpers
    private func processFeed(_ feed: Feed, context: ModelContext) async throws -> Int {
        let data = try await FeedService.fetch(url: feed.url)
        let parsed = try await FeedService.parseFeed(data: data, url: feed.url)
        
        try await processArticles(parsed.items, into: feed, context: context)
        try cleanupOldArticles(feed: feed, context: context)
        
        return parsed.items.count
    }
    
    private func processArticles(_ items: [FeedItem], into feed: Feed, context: ModelContext) async throws {
        for batchStart in stride(from: 0, to: items.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, items.count)
            let itemBatch = Array(items[batchStart..<batchEnd])
            
            for item in itemBatch {
                let link = item.link
                let predicate = #Predicate<Article> { $0.link == link }
                let existing = try context.fetch(FetchDescriptor<Article>(predicate: predicate)).first
                
                if let article = existing {
                    // Update existing (preserve user state)
                    article.title = item.title
                    article.contentHTML = item.contentHTML
                    article.author = item.author
                    article.featuredImageURL = item.featuredImageURL
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
    
    private func cleanupOldArticles(feed: Feed, context: ModelContext) throws {
        let allArticles = feed.articles.sorted { $0.publishedAt > $1.publishedAt }
        if allArticles.count > maxArticlesPerFeed {
            let toDelete = Array(allArticles[maxArticlesPerFeed...])
            toDelete.forEach { context.delete($0) }
        }
    }
    
    private func parseOPML(data: Data) throws -> [(title: String, url: URL)] {
        class OPMLParser: NSObject, XMLParserDelegate {
            var feeds: [(String, URL)] = []
            var currentTitle: String?
            var currentUrl: String?

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "outline", let type = attributeDict["type"], type == "rss" {
                    currentTitle = attributeDict["title"] ?? attributeDict["text"]
                    currentUrl = attributeDict["xmlUrl"]
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "outline",
                   let title = currentTitle,
                   let urlString = currentUrl,
                   let url = URL(string: urlString) {
                    
                    // Convert to HTTPS if needed
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
