import Foundation
import Observation

struct Feed: Identifiable, Hashable, Codable {
    // Use URL absoluteString as stable ID
    var id: String { url.absoluteString }

    var title: String
    var url: URL
    var thumbnailURL: URL?
    var addedAt: Date = .now
}
