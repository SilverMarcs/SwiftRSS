//
//  FeedStore.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData

@Observable
final class FeedStore {
    var isRefreshing = false

    @ObservationIgnored
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Refresh

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let feeds: [Feed]
        do {
            feeds = try modelContext.fetch(FetchDescriptor<Feed>())
        } catch { return }

        let feedURLs = feeds.compactMap { feed -> (String, URL)? in
            guard let url = feed.url else { return nil }
            return (url.absoluteString, url)
        }

        // Fetch articles from network concurrently
        var fetchedItems: [(String, [FeedItem])] = []

        await withTaskGroup(of: (String, [FeedItem]).self) { group in
            for (urlString, url) in feedURLs {
                group.addTask {
                    let items = (try? await FeedService.fetchArticles(url: url)) ?? []
                    return (urlString, items)
                }
            }
            for await result in group {
                fetchedItems.append(result)
            }
        }

        // Merge into database
        let feedsByURL = Dictionary(uniqueKeysWithValues: feeds.compactMap { feed -> (String, Feed)? in
            guard let url = feed.url else { return nil }
            return (url.absoluteString, feed)
        })

        for (urlString, items) in fetchedItems {
            guard let feed = feedsByURL[urlString] else { continue }
            for item in items {
                upsertArticle(item, feed: feed)
            }
        }
    }

    private func upsertArticle(_ item: FeedItem, feed: Feed) {
        let normID = URLNormalizer.normalizedArticleID(from: item.link)
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.articleID == normID })

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.title = item.title
            existing.author = item.author
            existing.featuredImageURL = item.featuredImageURL
        } else {
            modelContext.insert(Article(
                feed: feed,
                link: item.link,
                title: item.title,
                author: item.author,
                featuredImageURL: item.featuredImageURL,
                publishedAt: item.publishedAt ?? .now
            ))
        }
    }

    // MARK: - Feed Management

    func addFeed(url: URL) async throws {
        let meta = try await FeedService.fetchMeta(url: url)
        let title = meta.title ?? url.host ?? "Untitled Feed"

        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == url })
        guard (try? modelContext.fetch(descriptor))?.isEmpty ?? true else { return }

        modelContext.insert(Feed(title: title, url: url, thumbnailURL: meta.thumbnailURL))
    }

    func removeFeed(url: URL) {
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == url })
        guard let feeds = try? modelContext.fetch(descriptor) else { return }
        for feed in feeds {
            modelContext.delete(feed)
        }
    }

    // MARK: - OPML

    func importOPML(data: Data) async throws {
        let urls = OPMLParser.parse(data: data)
        for url in urls {
            try await addFeed(url: url)
        }
        await refreshAll()
    }
}
