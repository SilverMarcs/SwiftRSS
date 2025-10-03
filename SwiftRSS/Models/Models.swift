import Foundation

// Minimal, value-type models persisted via UserDefaults
// Note: Articles are loaded fresh from feeds; only their state (read/starred) is persisted.

struct Feed: Identifiable, Hashable, Codable {
    // Use URL absoluteString as stable ID
    var id: String { url.absoluteString }

    var title: String
    var url: URL
    var thumbnailURL: URL?
    var addedAt: Date = .now
}

// Persistent article state (read/starred status only)
struct ArticleState: Codable {
    var isRead: Bool = false
    var isStarred: Bool = false
}

// Transient article data (loaded fresh from feeds)
struct Article: Identifiable, Hashable {
    // Use link absoluteString as stable ID
    var id: String { link.absoluteString }

    var feed: Feed

    var link: URL
    var title: String
    var author: String?
    var contentHTML: String?
    var featuredImageURL: URL?
    var publishedAt: Date

    // State is now computed from external source to avoid duplication
    private let stateProvider: () -> ArticleState
    
    var isRead: Bool { stateProvider().isRead }
    var isStarred: Bool { stateProvider().isStarred }
    
    init(feed: Feed, link: URL, title: String, author: String?, contentHTML: String?, featuredImageURL: URL?, publishedAt: Date, stateProvider: @escaping () -> ArticleState) {
        self.feed = feed
        self.link = link
        self.title = title
        self.author = author
        self.contentHTML = contentHTML
        self.featuredImageURL = featuredImageURL
        self.publishedAt = publishedAt
        self.stateProvider = stateProvider
    }
    
    // Manual Hashable implementation (excluding closure)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Manual Equatable implementation (excluding closure)
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
    }
}
