import Foundation
import Observation

@Observable
final class FeedStore {
    var feeds: [Feed] = [] { didSet { saveToDisk() } }
    var articles: [Article] = []

    // MARK: - Persistence
    @ObservationIgnored
    private let defaults = UserDefaults.standard
    @ObservationIgnored
    private let feedsKey = "feeds_v3"

    init() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        let dec = JSONDecoder()

        if let data = defaults.data(forKey: feedsKey),
           let decoded = try? dec.decode([Feed].self, from: data) {
            feeds = decoded
        }
    }

    private func saveToDisk() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(feeds) {
            defaults.set(data, forKey: feedsKey)
        }
    }

    // MARK: - Subscriptions
    private func fetchArticles(for feed: Feed) async throws -> [Article] {
        let parsed = try await FeedService.fetchAndParse(url: feed.url)
        
        let thumb = parsed.meta.thumbnailURL
        let updatedFeed = Feed(title: feed.title, url: feed.url, thumbnailURL: thumb)

        if let idx = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[idx] = updatedFeed
        } else {
            feeds.append(updatedFeed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        var newArticles: [Article] = []
        newArticles.reserveCapacity(parsed.items.count)

        for item in parsed.items {
            let article = Article(
                feed: updatedFeed,
                link: item.link,
                title: item.title,
                author: item.author,
                featuredImageURL: item.featuredImageURL,
                publishedAt: item.publishedAt ?? .now,
                isRead: false,
                isStarred: false
            )
            
            newArticles.append(article)
        }
        
        return newArticles
    }

    func refreshAll() async {
        var allNewArticles: [Article] = []
        
        do {
            try await withThrowingTaskGroup(of: [Article].self) { group in
                for feed in feeds {
                    group.addTask {
                        do {
                            return try await self.fetchArticles(for: feed)
                        } catch {
                            print("Failed to refresh feed \(feed.title): \(error)")
                            return []
                        }
                    }
                }
                
                for try await newArticles in group {
                    allNewArticles.append(contentsOf: newArticles)
                }
            }
        } catch {
            print("Failed to refresh feeds: \(error)")
        }
        
        articles = allNewArticles.sorted { $0.publishedAt > $1.publishedAt }
    }
    
    func addFeed(url: URL) async throws {
        let parsed = try await FeedService.fetchAndParse(url: url)
        let feedTitle = parsed.meta.title ?? url.host ?? "Untitled Feed"
        let feed = Feed(title: feedTitle, url: url, thumbnailURL: parsed.meta.thumbnailURL)
        
        // Add to feeds array if not already present
        if !feeds.contains(where: { $0.id == feed.id }) {
            feeds.append(feed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        // Refresh all to get articles
        await refreshAll()
    }
    
    func deleteFeed(_ feed: Feed) {
        feeds.removeAll { $0.id == feed.id }
        articles.removeAll { $0.feed.id == feed.id }
    }
}

// MARK: - OPML
extension FeedStore {
    func importOPML(data: Data) async throws {
        let imports = OPMLParser.parse(data: data)
        
        // Add all feeds from OPML to the feeds array
        for feed in imports {
            if !feeds.contains(where: { $0.id == feed.id }) {
                feeds.append(feed)
            }
        }
        feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        // Refresh all feeds to fetch their articles
        await refreshAll()
    }
}
