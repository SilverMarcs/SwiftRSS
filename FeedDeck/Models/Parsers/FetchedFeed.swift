import Foundation

struct FetchedFeed: Sendable {
    let metadata: FeedMeta
    let items: [FeedItem]
}
