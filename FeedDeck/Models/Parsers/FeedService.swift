import Foundation
import Fuzi

enum FeedService {
    static func fetch(url: URL) async throws -> FetchedFeed {
        var request = URLRequest(url: url)
        request.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5",
                         forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw FeedError.badStatus(response.statusCode) }
        guard let format = detectFormat(from: data),
              let document = try? Fuzi.XMLDocument(data: data) else { throw FeedError.notFeed }

        let parser: any FeedParser = switch format {
        case .rss2: RSSParser(baseURL: url)
        case .atom: AtomParser(baseURL: url)
        }
        return FetchedFeed(
            metadata: parser.parseMeta(from: document),
            items: try parser.parseItems(from: document)
        )
    }

    private static func detectFormat(from data: Data) -> FeedFormat? {
        let prefix = String(data: data.prefix(512), encoding: .utf8)?.lowercased() ?? ""
        if prefix.contains("<rss") || prefix.contains("<rdf") { return .rss2 }
        if prefix.contains("<feed") { return .atom }
        return nil
    }
}
