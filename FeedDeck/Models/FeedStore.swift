//
//  FeedStore.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
final class FeedStore {
    private var activeRefreshes = 0
    var isRefreshing: Bool { activeRefreshes > 0 }

    @ObservationIgnored
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Refresh

    func refreshAll() async {
        activeRefreshes += 1
        defer { activeRefreshes -= 1 }

        let feeds: [Feed]
        do {
            feeds = try modelContext.fetch(FetchDescriptor<Feed>())
        } catch { return }

        let feedURLs = Set(feeds.compactMap(\.url))

        await withTaskGroup(of: (URL, FetchedFeed?).self) { group in
            for url in feedURLs {
                group.addTask {
                    let result = try? await FeedService.fetch(url: url)
                    return (url, result)
                }
            }
            for await (url, result) in group {
                guard !Task.isCancelled, let result else { continue }

                for feed in feeds where feed.url == url && !feed.isDeleted && feed.modelContext != nil {
                    mergeArticles(result.items, into: feed)
                }
            }
        }
        try? modelContext.save()
    }

    private func mergeArticles(_ items: [FeedItem], into feed: Feed) {
        let storedArticles = feed.articles ?? []
        let storedByID = Dictionary(
            storedArticles.map { ($0.articleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let fetchedByID = Dictionary(
            items.map { (URLNormalizer.normalizedArticleID(from: $0.link), $0) },
            uniquingKeysWith: { _, last in last }
        )

        var datesByID = storedByID.mapValues(\.publishedAt)
        for (id, item) in fetchedByID {
            // Undated entries keep a stable position across refreshes.
            datesByID[id] = item.publishedAt ?? datesByID[id] ?? .distantPast
        }

        let retainedIDs: Set<String>
        if UserDefaults.standard.bool(forKey: "limitArticlesPerFeed") {
            let newest = datesByID.sorted {
                $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
            }
            retainedIDs = Set(newest.prefix(50).map(\.key))
        } else {
            retainedIDs = Set(datesByID.keys)
        }

        for (id, item) in fetchedByID where retainedIDs.contains(id) {
            let publishedAt = datesByID[id] ?? .distantPast
            if let article = storedByID[id] {
                article.link = item.link
                article.title = item.title
                article.author = item.author
                article.featuredImageURL = item.featuredImageURL
                article.publishedAt = publishedAt
            } else {
                modelContext.insert(Article(
                    feed: feed,
                    link: item.link,
                    title: item.title,
                    author: item.author,
                    featuredImageURL: item.featuredImageURL,
                    publishedAt: publishedAt
                ))
            }
        }

        for article in storedArticles where !retainedIDs.contains(article.articleID) || storedByID[article.articleID] !== article {
            modelContext.delete(article)
        }
    }

    // MARK: - Feed Management

    func addFeed(url: URL) async throws {
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == url })
        guard try modelContext.fetch(descriptor).isEmpty else { return }

        let result = try await FeedService.fetch(url: url)
        try Task.checkCancellation()
        guard try modelContext.fetch(descriptor).isEmpty else { return }

        let feed = Feed(
            title: result.metadata.title ?? url.host ?? "Untitled Feed",
            url: url,
            thumbnailURL: result.metadata.thumbnailURL
        )
        modelContext.insert(feed)
        mergeArticles(result.items, into: feed)
        try modelContext.save()
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
    }
}
