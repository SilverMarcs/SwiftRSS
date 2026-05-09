import Foundation
import Fuzi

struct FeedService {
    private let data: Data
    private let baseURL: URL
    
    // MARK: - Main Public API
    
    static func fetchArticles(url: URL) async throws -> [FeedItem] {
        let data = try await fetch(url: url)
        let service = FeedService(data: data, baseURL: url)
        return try service.parse()
    }
    
    static func fetchMeta(url: URL) async throws -> FeedMeta {
        let data = try await fetch(url: url)
        let service = FeedService(data: data, baseURL: url)
        return try service.parseMeta()
    }
    
    // MARK: - Private Static Helpers
    
    private static func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5",
                    forHTTPHeaderField: "Accept")

        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FeedError.badStatus(http.statusCode) }
        return data
    }
    
    private static func detectFormat(from data: Data) -> FeedFormat? {
        let prefix = String(data: data.prefix(512), encoding: .utf8)?.lowercased() ?? ""
        if prefix.contains("<rss") || prefix.contains("<rdf") { return .rss2 }
        if prefix.contains("<feed") { return .atom }
        return nil
    }
    
    // MARK: - Instance Methods
    
    private init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
    }
    
    private func createDocument() throws -> Fuzi.XMLDocument {
        guard let document = try? Fuzi.XMLDocument(data: data) else {
            throw FeedError.notFeed
        }
        return document
    }
    
    private func getParser(for format: FeedFormat) -> FeedParser {
        switch format {
        case .rss2:
            return RSSParser(baseURL: baseURL)
        case .atom:
            return AtomParser(baseURL: baseURL)
        }
    }
    
    private func parseMeta() throws -> FeedMeta {
        guard let format = Self.detectFormat(from: data) else { throw FeedError.notFeed }
        let document = try createDocument()
        let parser = getParser(for: format)
        return parser.parseMeta(from: document)
    }
    
    private func parse() throws -> [FeedItem] {
        guard let format = Self.detectFormat(from: data) else { throw FeedError.notFeed }
        let document = try createDocument()
        let parser = getParser(for: format)
        return try parser.parseItems(from: document)
    }
}
