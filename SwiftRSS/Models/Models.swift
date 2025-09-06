import SwiftData
import Foundation

@Model
final class Feed {
    @Attribute(.unique) var id: String
    var title: String
    var url: URL
    var thumbnailURL: URL?
    var addedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article] = []

    init(title: String, url: URL, thumbnailURL: URL? = nil) {
        self.title = title
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.id = url.absoluteString
    }
}

@Model
final class Article {
    @Relationship var feed: Feed
    
    @Attribute(.unique) var id: String

    var title: String
    var link: URL
    var author: String?
    var contentHTML: String?
    var summary: String?
    var thumbnailURL: URL?
    var featuredImageURL: URL?

    var publishedAt: Date?
    var updatedAt: Date?

    var isRead: Bool = false
    var isStarred: Bool = false

    init(feed: Feed, title: String, link: URL, publishedAt: Date?) {
        self.feed = feed
        self.title = title
        self.link = link
        self.publishedAt = publishedAt
        self.id = link.absoluteString
    }
}
