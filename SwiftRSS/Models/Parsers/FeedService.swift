import Foundation
import SwiftData

struct FeedService {
    // Fetch raw data
    static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5",
                    forHTTPHeaderField: "Accept")

        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FeedError.badStatus(http.statusCode) }

        return data
    }

    // Detect format
    static func detectFormat(from data: Data) -> FeedFormat? {
        let prefix = String(data: data.prefix(512), encoding: .utf8)?.lowercased() ?? ""
        if prefix.contains("<rss") || prefix.contains("<rdf") { return .rss2 }
        if prefix.contains("<feed") { return .atom }
        return nil
    }

    // Parse feed
    static func parseFeed(data: Data, url: URL) throws -> (meta: FeedMeta, items: [FeedItem]) {
        guard let format = detectFormat(from: data) else { throw FeedError.notFeed }
        let parser = XMLFeedParser(data: data, baseURL: url)
        switch format {
        case .rss2: return try parser.parseRSS2()
        case .atom: return try parser.parseAtom()
        }
    }

    // MARK: - Public API
    static func subscribe(url: URL, modelContainer: ModelContainer) async throws -> Feed {
        let processor = BackgroundFeedProcessor(modelContainer: modelContainer)
        return try await processor.subscribe(url: url)
    }

    static func refresh(_ feed: Feed, modelContainer: ModelContainer) async throws -> Int {
        let processor = BackgroundFeedProcessor(modelContainer: modelContainer)
        return try await processor.refreshSingle(feedURL: feed.url)
    }

    static func refreshAll(modelContainer: ModelContainer) async throws -> Int {
        let processor = BackgroundFeedProcessor(modelContainer: modelContainer)
        return try await processor.refreshAll()
    }
    
    static func importOPML(data: Data, modelContainer: ModelContainer) async throws -> [Feed] {
        let processor = BackgroundFeedProcessor(modelContainer: modelContainer)
        return try await processor.importOPML(data: data)
    }
}
