import Foundation
import Observation

@Observable
final class FeedStore {
    var feeds: [Feed] = [] { didSet { saveToDisk() } }
    var articles: [Article] = []
    var isRefreshing: Bool = false

    // MARK: - Persistence
    @ObservationIgnored
    private let defaults = UserDefaults.standard
    @ObservationIgnored
    private let feedsKey = "feeds_v3"
    @ObservationIgnored
    private let readIDsKey = "articleReadIDs_v1"
    @ObservationIgnored
    private let starredIDsKey = "articleStarredIDs_v1"
    @ObservationIgnored
    private let lastRefreshKey = "lastRefreshDate_v1"

    // Persist only IDs for read/starred state
    @ObservationIgnored
    private(set) var readIDs: Set<String> = [] { didSet { saveArticleState() } }
    @ObservationIgnored
    private(set) var starredIDs: Set<String> = [] { didSet { saveArticleState() } }

    init() {
        loadFromDisk()
        loadArticleState()
        if !feeds.isEmpty {
            Task { await self.refreshAll() }
        }
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

    private func loadArticleState() {
        let readArray = (defaults.array(forKey: readIDsKey) as? [String]) ?? []
        let starredArray = (defaults.array(forKey: starredIDsKey) as? [String]) ?? []

        // Migrate legacy IDs to normalized form
        func normalizeIDString(_ s: String) -> String {
            if let url = URL(string: s) { return URLNormalizer.normalizedArticleID(from: url) }
            return s
        }
        let normalizedRead = Set(readArray.map(normalizeIDString))
        let normalizedStarred = Set(starredArray.map(normalizeIDString))

        let changed = normalizedRead.count != readArray.count || normalizedStarred.count != starredArray.count ||
                      Set(readArray) != normalizedRead || Set(starredArray) != normalizedStarred

        readIDs = normalizedRead
        starredIDs = normalizedStarred
        if changed { saveArticleState() }
    }

    private func saveArticleState() {
        defaults.set(Array(readIDs), forKey: readIDsKey)
        defaults.set(Array(starredIDs), forKey: starredIDsKey)
    }

    // MARK: - Refresh Tracking
    var lastRefreshDate: Date? {
        defaults.object(forKey: lastRefreshKey) as? Date
    }

    private func updateLastRefreshDate(_ date: Date = .now) {
        defaults.set(date, forKey: lastRefreshKey)
    }

    // MARK: - Subscriptions
    private func fetchArticles(for feed: Feed) async throws -> [Article] {
        let articles = try await FeedService.fetchArticles(url: feed.url)
        
        var newArticles: [Article] = []
        newArticles.reserveCapacity(articles.count)

        for item in articles {
            let article = Article(
                feed: feed,
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
        isRefreshing = true
        defer { isRefreshing = false }

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
        
        var merged = allNewArticles.sorted { $0.publishedAt > $1.publishedAt }
        applyPersistedState(into: &merged)
        self.articles = merged
        updateLastRefreshDate()
    }
    
    /// Adds a feed without refreshing articles
    func addFeed(url: URL) async throws {
        let meta = try await FeedService.fetchMeta(url: url)
        let feedTitle = meta.title ?? url.host ?? "Untitled Feed"
        let feed = Feed(title: feedTitle, url: url, thumbnailURL: meta.thumbnailURL)
        
        if !feeds.contains(where: { $0.id == feed.id }) {
            feeds.append(feed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    func deleteFeed(_ feed: Feed) {
        feeds.removeAll { $0.id == feed.id }
        articles.removeAll { $0.feed.id == feed.id }
    }
}

// MARK: - OPML
extension FeedStore {
    // Apply read/star states to freshly fetched articles (with raw->normalized migration)
    fileprivate func applyPersistedState(into list: inout [Article]) {
        var needsSave = false
        for idx in list.indices {
            let rawID = list[idx].link.absoluteString
            let normID = list[idx].id

            // Read state
            let read = readIDs.contains(normID) || readIDs.contains(rawID)
            list[idx].isRead = read
            if readIDs.contains(rawID) && !readIDs.contains(normID) {
                readIDs.insert(normID)
                needsSave = true
            }

            // Starred state
            let starred = starredIDs.contains(normID) || starredIDs.contains(rawID)
            list[idx].isStarred = starred
            if starredIDs.contains(rawID) && !starredIDs.contains(normID) {
                starredIDs.insert(normID)
                needsSave = true
            }
        }
        if needsSave { saveArticleState() }
    }

    // MARK: Read/Star API
    func setRead(_ isRead: Bool, for articleID: String) {
        if isRead { readIDs.insert(articleID) } else { readIDs.remove(articleID) }
        if let idx = articles.firstIndex(where: { $0.id == articleID }) {
            articles[idx].isRead = isRead
        }
    }

    func toggleRead(articleID: String) {
        let newValue = !readIDs.contains(articleID)
        setRead(newValue, for: articleID)
    }

    func setStarred(_ isStarred: Bool, for articleID: String) {
        if isStarred { starredIDs.insert(articleID) } else { starredIDs.remove(articleID) }
        if let idx = articles.firstIndex(where: { $0.id == articleID }) {
            articles[idx].isStarred = isStarred
        }
    }

    func toggleStarred(articleID: String) {
        let newValue = !starredIDs.contains(articleID)
        setStarred(newValue, for: articleID)
    }

    func markAllAsRead(articleIDs: [String]) {
        readIDs.formUnion(articleIDs)
        for id in articleIDs {
            if let idx = articles.firstIndex(where: { $0.id == id }) {
                articles[idx].isRead = true
            }
        }
    }

    func importOPML(data: Data) async throws {
        let urls = OPMLParser.parse(data: data)
        
        // Add all feeds using the existing addFeed logic
        for url in urls {
            try await addFeed(url: url)
        }
        
        // Refresh all feeds once at the end
        await refreshAll()
    }
}
