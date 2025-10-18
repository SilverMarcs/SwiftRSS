import Foundation
import Observation

@Observable
final class FeedStore {
    // Persist only feeds (article states now managed globally)
    var feeds: [Feed] = [] { didSet { persistFeeds() } }
    var articles: [Article] = [] // Transient, loaded fresh from feeds

    @ObservationIgnored
    private let defaults = UserDefaults.standard
    @ObservationIgnored
    private let feedsKey = "feeds_v2"

    init() {
        load()
        // Load articles fresh from feeds on init
        Task {
            try? await refreshAll()
        }
    }

    // MARK: - Persistence
    private func load() {
        let dec = JSONDecoder()
        
        // Load feeds
        if let data = defaults.data(forKey: feedsKey),
           let decoded = try? dec.decode([Feed].self, from: data) {
            feeds = decoded
        }
    }

    private func persistFeeds() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(feeds) {
            defaults.set(data, forKey: feedsKey)
        }
    }

    // MARK: - Feed Operations
    func subscribe(url: URL, title overrideTitle: String? = nil) async throws -> Feed {
        let data = try await FeedService.fetch(url: url)
        let parsed = try FeedService.parseFeed(data: data, url: url)

        let feedTitle = parsed.meta.title ?? overrideTitle ?? url.host ?? "Untitled Feed"
        let thumb = parsed.meta.thumbnailURL
        let feed = Feed(title: feedTitle, url: url, thumbnailURL: thumb)

        // Upsert feed
        if let idx = feeds.firstIndex(where: { $0.id == feed.id }) {
            // For existing feeds, preserve title and thumbnailURL
            let existing = feeds[idx]
            let updatedFeed = Feed(title: existing.title, url: url, thumbnailURL: existing.thumbnailURL)
            feeds[idx] = updatedFeed
        } else {
            feeds.append(feed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        // Build new articles from this fetch; replace existing ones for this feed
        var newArticles: [Article] = []
        newArticles.reserveCapacity(parsed.items.count)

        for item in parsed.items {
            let article = Article(
                feed: feed,
                link: item.link,
                title: item.title,
                author: item.author,
                contentHTML: item.contentHTML,
                featuredImageURL: item.featuredImageURL,
                publishedAt: item.publishedAt ?? .now
            )
            newArticles.append(article)
        }

         // Limit to top 100 articles, sorted by publishedAt descending
         let limitedNewArticles = newArticles.sorted { $0.publishedAt > $1.publishedAt }.prefix(100)
 
         // Batch update: remove old articles for this feed and rebuild sorted list
         var updated = articles.filter { $0.feed.id != feed.id }
         updated.append(contentsOf: limitedNewArticles)
         articles = updated.sorted { $0.publishedAt > $1.publishedAt }

        return feed
    }

    func refresh(_ feed: Feed) async throws -> Int {
        let beforeCount = articles.count(where: { $0.feed.id == feed.id })
        _ = try await subscribe(url: feed.url, title: feed.title)
        let afterCount = articles.count(where: { $0.feed.id == feed.id })
        return afterCount - beforeCount
    }

    func refreshAll() async throws -> Int {
        try await withThrowingTaskGroup(of: Int.self) { group in
            for feed in feeds {
                group.addTask {
                    try await self.refresh(feed)
                }
            }
            var total = 0
            for try await count in group {
                total += count
            }
            return total
        }
    }

    func importOPML(data: Data) async throws -> [Feed] {
        let imports = try parseOPML(data: data)
        return try await withThrowingTaskGroup(of: Feed?.self) { group in
            for (title, url) in imports {
                group.addTask {
                    do {
                        let f = try await self.subscribe(url: url, title: title)
                        return f
                    } catch {
                        print("Failed to import feed \(title): \(error)")
                        return nil
                    }
                }
            }
            var imported: [Feed] = []
            for try await feed in group {
                if let feed = feed {
                    imported.append(feed)
                }
            }
            return imported
        }
    }

    func deleteFeed(_ feed: Feed) {
        feeds.removeAll { $0.id == feed.id }
        articles.removeAll { $0.feed.id == feed.id }
        // Note: We keep article states even after feed deletion
        // to preserve read/starred status if feed is re-added
    }

    // MARK: - Article Operations
    func setRead(articleID: String, _ isRead: Bool) {
        ArticleStateManager.shared.setRead(articleID: articleID, isRead)
    }

    func toggleRead(articleID: String) {
        ArticleStateManager.shared.toggleRead(articleID: articleID)
    }

    func toggleStar(articleID: String) {
        ArticleStateManager.shared.toggleStar(articleID: articleID)
    }

    func markAllRead(in articlesList: [Article]) {
        for article in articlesList {
            ArticleStateManager.shared.setRead(articleID: article.id, true)
        }
    }

    // MARK: - OPML
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

// Convenience helper
extension Collection {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { $0 + (predicate($1) ? 1 : 0) }
    }
}
