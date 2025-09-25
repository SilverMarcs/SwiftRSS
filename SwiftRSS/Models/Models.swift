import Foundation

// Minimal, value-type models persisted via UserDefaults
// Note: We keep only current fetched articles; older ones are not stored.

struct Feed: Identifiable, Hashable, Codable {
    // Use URL absoluteString as stable ID
    var id: String { url.absoluteString }

    var title: String
    var url: URL
    var thumbnailURL: URL?
    var addedAt: Date = .now
}

struct Article: Identifiable, Hashable, Codable {
    // Use link absoluteString as stable ID
    var id: String { link.absoluteString }

    // Minimal article data for display and navigation
    var feedID: String // Feed.id (url.absoluteString)
    var feedTitle: String
    var feedThumbnailURL: URL?

    var link: URL
    var title: String
    var author: String?
    var contentHTML: String?
    var featuredImageURL: URL?
    var publishedAt: Date

    var isRead: Bool = false
    var isStarred: Bool = false
}
