import Foundation
import Observation

@Observable
final class FeedStore {
    // Persist only feeds and article states (read/starred)
    var feeds: [Feed] = [] { didSet { persistFeeds() } }
    var articles: [Article] = [] // Transient, loaded fresh from feeds
    
    // Efficient O(1) lookup for article states using Dictionary
    private var articleStates: [String: ArticleState] = [:] { didSet { persistArticleStates() } }

    @ObservationIgnored
    private let defaults = UserDefaults.standard
    @ObservationIgnored
    private let feedsKey = "feeds_v2"
    @ObservationIgnored
    private let articleStatesKey = "articleStates_v2"

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
        
        // Load article states
        if let data = defaults.data(forKey: articleStatesKey),
           let decoded = try? dec.decode([String: ArticleState].self, from: data) {
            articleStates = decoded
        }
        
        // Clean up old keys if migrating
        if defaults.data(forKey: "feeds_v1") != nil {
            defaults.removeObject(forKey: "feeds_v1")
        }
        if defaults.data(forKey: "articles_v1") != nil {
            defaults.removeObject(forKey: "articles_v1")
        }
    }

    private func persistFeeds() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(feeds) {
            defaults.set(data, forKey: feedsKey)
        }
    }

    private func persistArticleStates() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(articleStates) {
            defaults.set(data, forKey: articleStatesKey)
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
            let articleID = item.link.absoluteString
            
            let article = Article(
                feed: feed,
                link: item.link,
                title: item.title,
                author: item.author,
                contentHTML: item.contentHTML,
                featuredImageURL: item.featuredImageURL,
                publishedAt: item.publishedAt ?? .now,
                stateProvider: { [weak self] in
                    self?.articleStates[articleID] ?? ArticleState()
                }
            )
            newArticles.append(article)
        }

        // Limit to top 100 articles, sorted by publishedAt descending
        let limitedNewArticles = newArticles.sorted { $0.publishedAt > $1.publishedAt }.prefix(100)

        // Remove previous articles for this feed and insert the new batch
        articles.removeAll { $0.feed.id == feed.id }
        articles.append(contentsOf: limitedNewArticles)
        articles.sort { $0.publishedAt > $1.publishedAt }

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
    
    // Clean up article states for articles that no longer exist (optional maintenance)
    func cleanupArticleStates() {
        let currentArticleIDs = Set(articles.map { $0.id })
        let statesToKeep = articleStates.filter { currentArticleIDs.contains($0.key) || $0.value.isStarred }
        articleStates = statesToKeep
    }

    // MARK: - Article Operations
    func setRead(articleID: String, _ isRead: Bool) {
        // Update state in dictionary (O(1) lookup) - Article objects read from here
        var state = articleStates[articleID] ?? ArticleState()
        state.isRead = isRead
        articleStates[articleID] = state
    }

    func toggleRead(articleID: String) {
        // Update state in dictionary (O(1) lookup) - Article objects read from here
        var state = articleStates[articleID] ?? ArticleState()
        state.isRead.toggle()
        articleStates[articleID] = state
    }

    func toggleStar(articleID: String) {
        // Update state in dictionary (O(1) lookup) - Article objects read from here
        var state = articleStates[articleID] ?? ArticleState()
        state.isStarred.toggle()
        articleStates[articleID] = state
    }

    func markAllRead(in articlesList: [Article]) {
        // Batch update states - Article objects will automatically reflect changes
        for article in articlesList {
            var state = articleStates[article.id] ?? ArticleState()
            state.isRead = true
            articleStates[article.id] = state
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
