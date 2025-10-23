import Foundation
import Fuzi

struct FeedService {
    private let data: Data
    private let baseURL: URL
    private let maxItems: Int = 50
    
    private var imgRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<img[^>]+src=["\']([^"\']+)["\']"#, options: .caseInsensitive)
    }()
    
    // MARK: - Main Public API
    
    static func fetchArticles(url: URL) async throws -> [FeedItem] {
        let data = try await fetch(url: url)
        let parser = FeedService(data: data, baseURL: url)
        return try parser.parse()
    }
    
    static func fetchMeta(url: URL) async throws -> FeedMeta {
        let data = try await fetch(url: url)
        let parser = FeedService(data: data, baseURL: url)
        return try parser.parseMeta()
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
    
    private func createDocument() throws -> XMLDocument {
        guard let document = try? XMLDocument(data: data) else {
            throw FeedError.notFeed
        }
        return document
    }
    
    private func parseMeta() throws -> FeedMeta {
        guard let format = Self.detectFormat(from: data) else { throw FeedError.notFeed }
        let document = try createDocument()
        
        return switch format {
        case .rss2: parseRSSMeta(document: document)
        case .atom: parseAtomMeta(document: document)
        }
    }
    
    private func parse() throws -> [FeedItem] {
        guard let format = Self.detectFormat(from: data) else { throw FeedError.notFeed }
        let document = try createDocument()
        
        return switch format {
        case .rss2: try parseRSS2(document: document)
        case .atom: try parseAtom(document: document)
        }
    }
    
    // MARK: - RSS Parsing
    
    private func parseRSSMeta(document: XMLDocument) -> FeedMeta {
        var meta = FeedMeta()
        meta.title = document.firstChild(xpath: "/rss/channel/title")?.stringValue
        
        if let imageURL = document.firstChild(xpath: "/rss/channel/image/url")?.stringValue {
            meta.thumbnailURL = URL(string: imageURL, relativeTo: baseURL)?.absoluteURL
        }
        
        meta.thumbnailURL = meta.thumbnailURL ?? getFaviconURL()
        return meta
    }
    
    private func parseRSS2(document: XMLDocument) throws -> [FeedItem] {
        let itemNodes = Array(document.xpath("/rss/channel/item").prefix(maxItems))
        let items = itemNodes.map { parseRSSItem($0) }
        
        return items
    }
    
    private func parseRSSItem(_ itemNode: XMLElement) -> FeedItem {
        var item = FeedItem(
            title: itemNode.firstChild(tag: "title")?.stringValue ?? "",
            link: extractLink(from: itemNode, tag: "link"),
            contentHTML: nil,
            author: nil,
            publishedAt: nil,
            featuredImageURL: nil
        )
        
        // Content (prefer content:encoded over description)
        let contentEncoded = itemNode.firstChild(xpath: "*[local-name()='encoded']")?.stringValue
        let description = itemNode.firstChild(tag: "description")?.stringValue
        item.contentHTML = contentEncoded ?? description
        
        // Author
        item.author = itemNode.firstChild(tag: "author")?.stringValue ??
                     itemNode.firstChild(xpath: "*[local-name()='creator']")?.stringValue
        
        // Published date
        if let dateString = itemNode.firstChild(tag: "pubDate")?.stringValue ??
                           itemNode.firstChild(tag: "published")?.stringValue {
            item.publishedAt = RFCDate.parse(dateString)
        }
        
        // Featured image - multiple sources
        item.featuredImageURL = extractRSSImage(from: itemNode, html: item.contentHTML)
        
        return item
    }
    
    private func extractRSSImage(from itemNode: XMLElement, html: String?) -> URL? {
        // Try enclosure first
        if let enclosure = itemNode.firstChild(tag: "enclosure"),
           let type = enclosure["type"],
           type.hasPrefix("image/"),
           let urlString = enclosure["url"],
           let url = URL(string: urlString, relativeTo: baseURL) {
            return url.absoluteURL
        }
        
        // Try media:content or media:thumbnail
        if let mediaURL = itemNode.firstChild(xpath: "*[local-name()='content']")?["url"] ??
                         itemNode.firstChild(xpath: "*[local-name()='thumbnail']")?["url"],
           let url = URL(string: mediaURL, relativeTo: baseURL) {
            return url.absoluteURL
        }
        
        // Extract from HTML content as fallback
        if let html = html {
            return extractImageFromHTML(html)
        }
        
        return nil
    }
    
    // MARK: - Atom Parsing
    
    private func parseAtomMeta(document: XMLDocument) -> FeedMeta {
        var meta = FeedMeta()
        
        meta.title = document.firstChild(xpath: "/feed/title")?.stringValue ??
                    document.firstChild(xpath: "//*[local-name()='feed']/*[local-name()='title']")?.stringValue
        
        // Try logo first, then icon
        let logoURL = document.firstChild(xpath: "/feed/logo")?.stringValue ??
                     document.firstChild(xpath: "//*[local-name()='feed']/*[local-name()='logo']")?.stringValue
        let iconURL = document.firstChild(xpath: "/feed/icon")?.stringValue ??
                     document.firstChild(xpath: "//*[local-name()='feed']/*[local-name()='icon']")?.stringValue
        
        if let logo = logoURL {
            meta.thumbnailURL = URL(string: logo, relativeTo: baseURL)?.absoluteURL
        } else if let icon = iconURL {
            meta.thumbnailURL = URL(string: icon, relativeTo: baseURL)?.absoluteURL
        }
        
        meta.thumbnailURL = meta.thumbnailURL ?? getFaviconURL()
        return meta
    }
    
    private func parseAtom(document: XMLDocument) throws -> [FeedItem] {
        let entryNodes = document.xpath("/feed/entry")
        let entries = entryNodes.isEmpty ? document.xpath("//*[local-name()='entry']") : entryNodes
        let items = entries.prefix(maxItems).map { parseAtomItem($0) }
        
        return items
    }
    
    private func parseAtomItem(_ entryNode: XMLElement) -> FeedItem {
        var item = FeedItem(
            title: entryNode.firstChild(tag: "title")?.stringValue ?? "",
            link: extractAtomLink(from: entryNode),
            contentHTML: nil,
            author: nil,
            publishedAt: nil,
            featuredImageURL: nil
        )
        
        // Content (prefer content over summary)
        let content = entryNode.firstChild(tag: "content")?.stringValue
        let summary = entryNode.firstChild(tag: "summary")?.stringValue
        item.contentHTML = content ?? summary
        
        // Author
        item.author = entryNode.firstChild(xpath: "author/name")?.stringValue ??
                     entryNode.firstChild(xpath: "*[local-name()='author']/*[local-name()='name']")?.stringValue
        
        // Published date
        if let dateString = entryNode.firstChild(tag: "published")?.stringValue ??
                           entryNode.firstChild(tag: "updated")?.stringValue {
            item.publishedAt = RFCDate.parse(dateString)
        }
        
        // Extract image from HTML content
        if let html = item.contentHTML {
            item.featuredImageURL = extractImageFromHTML(html)
        }
        
        return item
    }
    
    // MARK: - Helper Methods
    
    private func extractLink(from node: XMLElement, tag: String) -> URL {
        if let linkString = node.firstChild(tag: tag)?.stringValue,
           let url = URL(string: linkString, relativeTo: baseURL) {
            return url.absoluteURL
        }
        return baseURL
    }
    
    private func extractAtomLink(from node: XMLElement) -> URL {
        if let linkElement = node.firstChild(tag: "link"),
           let href = linkElement["href"],
           let url = URL(string: href, relativeTo: baseURL) {
            return url.absoluteURL
        }
        return baseURL
    }
    
    private func extractImageFromHTML(_ html: String) -> URL? {
        guard let regex = imgRegex else { return nil }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else { return nil }
        
        let urlRange = match.range(at: 1)
        guard let swiftRange = Range(urlRange, in: html) else { return nil }
        
        let urlString = String(html[swiftRange])
        return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
    }
    
    private func getFaviconURL() -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        
        guard let baseHost = components.url else { return nil }
        return URL(string: "/favicon.ico", relativeTo: baseHost)?.absoluteURL
    }
}
