import Foundation
import Observation

@Observable
final class FeedStore {
    // Persist minimal data only
    var feeds: [Feed] = [] { didSet { persistFeeds() } }
    var articles: [Article] = [] { didSet { persistArticles() } }

    @ObservationIgnored
    private let defaults = UserDefaults.standard
    @ObservationIgnored
    private let feedsKey = "feeds_v1"
    @ObservationIgnored
    private let articlesKey = "articles_v1"

    init() {
        load()
    }

    // MARK: - Persistence
    private func load() {
        let dec = JSONDecoder()
        if let data = defaults.data(forKey: feedsKey),
           let decoded = try? dec.decode([Feed].self, from: data) {
            feeds = decoded
        }
        if let data = defaults.data(forKey: articlesKey),
           let decoded = try? dec.decode([Article].self, from: data) {
            articles = decoded
        }
    }

    private func persistFeeds() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(feeds) {
            defaults.set(data, forKey: feedsKey)
        }
    }

    private func persistArticles() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(articles) {
            defaults.set(data, forKey: articlesKey)
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
            // For existing feeds, preserve title and thumbnailURL; only update on initial subscribe
            let existing = feeds[idx]
            let updatedFeed = Feed(title: existing.title, url: url, thumbnailURL: existing.thumbnailURL)
            feeds[idx] = updatedFeed
        } else {
            feeds.append(feed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        // Build new articles from this single fetch; replace existing ones for this feed
        let oldByLink = Dictionary(uniqueKeysWithValues: articles
            .filter { $0.feedID == feed.id }
            .map { ($0.link, $0) })

        var newArticles: [Article] = []
        newArticles.reserveCapacity(parsed.items.count)

        for item in parsed.items {
            let link = item.link
            let preserved = oldByLink[link]
            let article = Article(
                feedID: feed.id,
                feedTitle: feed.title,
                feedThumbnailURL: feed.thumbnailURL,
                link: link,
                title: item.title,
                author: item.author,
                contentHTML: item.contentHTML,
                featuredImageURL: item.featuredImageURL,
                publishedAt: item.publishedAt ?? .now,
                isRead: preserved?.isRead ?? false,
                isStarred: preserved?.isStarred ?? false
            )
            // Ensure minimal data; nothing else to compute here
            newArticles.append(article)
        }

        // Limit to top 100 articles, sorted by publishedAt descending
        let limitedNewArticles = newArticles.sorted { $0.publishedAt > $1.publishedAt }.prefix(100)

        // Remove previous articles for this feed and insert the new batch
        articles.removeAll { $0.feedID == feed.id }
        articles.append(contentsOf: limitedNewArticles)
        articles.sort { $0.publishedAt > $1.publishedAt }

        return feed
    }

    func refresh(_ feed: Feed) async throws -> Int {
        let beforeCount = articles.count(where: { $0.feedID == feed.id })
        _ = try await subscribe(url: feed.url, title: feed.title)
        let afterCount = articles.count(where: { $0.feedID == feed.id })
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
        articles.removeAll { $0.feedID == feed.id }
    }

    // MARK: - Article Operations
    func setRead(articleID: String, _ isRead: Bool) {
        if let idx = articles.firstIndex(where: { $0.id == articleID }) {
            articles[idx].isRead = isRead
        }
    }

    func toggleRead(articleID: String) {
        if let idx = articles.firstIndex(where: { $0.id == articleID }) {
            articles[idx].isRead.toggle()
        }
    }

    func toggleStar(articleID: String) {
        if let idx = articles.firstIndex(where: { $0.id == articleID }) {
            articles[idx].isStarred.toggle()
        }
    }

    func markAllRead(in articlesList: [Article]) {
        let ids = Set(articlesList.map { $0.id })
        for i in articles.indices {
            if ids.contains(articles[i].id) {
                articles[i].isRead = true
            }
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
