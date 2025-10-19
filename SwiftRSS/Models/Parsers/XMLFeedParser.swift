import Foundation
import Fuzi

final class XMLFeedParser {
    private let data: Data
    private let baseURL: URL
    
    // 🚀 Cache regex patterns (created once, reused for all items)
    private static let imageRegex = try! NSRegularExpression(
        pattern: #"<img[^>]+src=["\']([^"\']+)["\']"#,
        options: .caseInsensitive
    )
    
    private static let featuredImageRegex = try! NSRegularExpression(
        pattern: #"<div[^>]*class=["\'][^"\']*feat-image[^"\']*["\'][^>]*>.*?<img[^>]+src=["\']([^"\']+)["\']"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    
    init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
    }
    
    func parseRSS2() throws -> (FeedMeta, [FeedItem]) {
        let doc = try XMLDocument(data: data)
        registerRSSNamespaces(doc)
        
        // 🚀 Find channel once, then traverse children directly
        guard let channel = doc.firstChild(xpath: "//channel") else {
            return (FeedMeta(), [])
        }
        
        let meta = extractRSSMeta(from: channel)
        let items = parseRSSItemsIteratively(from: channel)
        
        return (meta, items)
    }
    
    func parseAtom() throws -> (FeedMeta, [FeedItem]) {
        let doc = try XMLDocument(data: data)
        doc.definePrefix("atom", forNamespace: "http://www.w3.org/2005/Atom")
        
        guard let feed = doc.firstChild(xpath: "//feed") else {
            return (FeedMeta(), [])
        }
        
        let meta = extractAtomMeta(from: feed)
        let items = parseAtomEntriesIteratively(from: feed)
        
        return (meta, items)
    }
    
    // MARK: - RSS Parsing
    
    private func registerRSSNamespaces(_ doc: XMLDocument) {
        doc.definePrefix("content", forNamespace: "http://purl.org/rss/1.0/modules/content/")
        doc.definePrefix("dc", forNamespace: "http://purl.org/dc/elements/1.1/")
        doc.definePrefix("media", forNamespace: "http://search.yahoo.com/mrss/")
    }
    
    private func extractRSSMeta(from channel: XMLElement) -> FeedMeta {
        var meta = FeedMeta()
        meta.title = channel.firstChild(tag: "title")?.stringValue
        
        if let imageURL = channel.firstChild(tag: "image")?.firstChild(tag: "url")?.stringValue {
            meta.thumbnailURL = makeURL(from: imageURL)
        }
        meta.thumbnailURL = meta.thumbnailURL ?? getFaviconURL()
        
        return meta
    }
    
    // 🚀 Iterate through siblings instead of running XPath query
    private func parseRSSItemsIteratively(from channel: XMLElement) -> [FeedItem] {
        var items: [FeedItem] = []
        items.reserveCapacity(20) // typical RSS feed size
        
        var node: XMLElement? = channel.firstChild(tag: "item")
        while let itemNode = node {
            if let item = parseRSSItem(itemNode) {
                items.append(item)
            }
            // Traverse to next <item> sibling
            node = itemNode.nextSibling
            while node != nil && node?.tag != "item" {
                node = node?.nextSibling
            }
        }
        
        return items
    }
    
    private func parseRSSItem(_ element: XMLElement) -> FeedItem? {
        guard let title = element.firstChild(tag: "title")?.stringValue else {
            return nil
        }
        
        // 🚀 Single pass through all children - batch extraction
        var linkStr: String?
        var contentHTML: String?
        var description: String?
        var author: String?
        var pubDateStr: String?
        var enclosureURL: String?
        var enclosureType: String?
        var mediaURL: String?
        
        for child in element.children {
            let tag = child.tag ?? ""
            let ns = child.namespace
            
            switch tag {
            case "link": linkStr = child.stringValue
            case "description": description = child.stringValue
            case "author": author = child.stringValue
            case "pubDate": pubDateStr = child.stringValue
            case "enclosure":
                enclosureURL = child["url"]
                enclosureType = child["type"]
            case "encoded" where ns == "content":
                contentHTML = child.stringValue
            case "creator" where ns == "dc":
                author = author ?? child.stringValue
            case "content" where ns == "media", "thumbnail" where ns == "media":
                mediaURL = mediaURL ?? child["url"]
            default: break
            }
        }
        
        let link = linkStr.flatMap { makeURL(from: $0) } ?? baseURL
        let publishedAt = pubDateStr.flatMap { RFCDate.parse($0) }
        
        // 🚀 Fast featured image extraction
        let featuredImageURL = extractFeaturedImageFast(
            enclosureURL: enclosureURL,
            enclosureType: enclosureType,
            mediaURL: mediaURL,
            contentHTML: contentHTML,
            description: description
        )
        
        return FeedItem(
            title: title,
            link: link,
            contentHTML: contentHTML,
            author: author,
            publishedAt: publishedAt,
            featuredImageURL: featuredImageURL
        )
    }
    
    // MARK: - Atom Parsing
    
    private func extractAtomMeta(from feed: XMLElement) -> FeedMeta {
        var meta = FeedMeta()
        meta.title = feed.firstChild(tag: "title")?.stringValue
        
        if let logoURL = feed.firstChild(tag: "logo")?.stringValue
                      ?? feed.firstChild(tag: "icon")?.stringValue {
            meta.thumbnailURL = makeURL(from: logoURL)
        }
        meta.thumbnailURL = meta.thumbnailURL ?? getFaviconURL()
        
        return meta
    }
    
    private func parseAtomEntriesIteratively(from feed: XMLElement) -> [FeedItem] {
        var items: [FeedItem] = []
        items.reserveCapacity(20)
        
        var node: XMLElement? = feed.firstChild(tag: "entry")
        while let entryNode = node {
            if let item = parseAtomEntry(entryNode) {
                items.append(item)
            }
            node = entryNode.nextSibling
            while node != nil && node?.tag != "entry" {
                node = node?.nextSibling
            }
        }
        
        return items
    }
    
    private func parseAtomEntry(_ element: XMLElement) -> FeedItem? {
        guard let title = element.firstChild(tag: "title")?.stringValue else {
            return nil
        }
        
        // 🚀 Single pass batch extraction
        var linkHref: String?
        var contentHTML: String?
        var summary: String?
        var authorName: String?
        var publishedStr: String?
        
        for child in element.children {
            switch child.tag {
            case "link": linkHref = linkHref ?? child["href"]
            case "content": contentHTML = child.stringValue
            case "summary": summary = child.stringValue
            case "published", "updated": publishedStr = publishedStr ?? child.stringValue
            case "author": authorName = child.firstChild(tag: "name")?.stringValue
            default: break
            }
        }
        
        let link = linkHref.flatMap { makeURL(from: $0) } ?? baseURL
        let publishedAt = publishedStr.flatMap { RFCDate.parse($0) }
        
        var featuredImageURL: URL?
        if let html = contentHTML ?? summary {
            featuredImageURL = extractImageFromHTMLFast(html)
        }
        
        return FeedItem(
            title: title,
            link: link,
            contentHTML: contentHTML,
            author: authorName,
            publishedAt: publishedAt,
            featuredImageURL: featuredImageURL
        )
    }
    
    // MARK: - Optimized Helper Methods
    
    private func extractFeaturedImageFast(enclosureURL: String?,
                                          enclosureType: String?,
                                          mediaURL: String?,
                                          contentHTML: String?,
                                          description: String?) -> URL? {
        // Check in order of likelihood and performance
        if let urlStr = enclosureURL,
           let type = enclosureType,
           type.hasPrefix("image/") {
            return makeURL(from: urlStr)
        }
        
        if let urlStr = mediaURL {
            return makeURL(from: urlStr)
        }
        
        if let html = contentHTML ?? description {
            return extractImageFromHTMLFast(html)
        }
        
        return nil
    }
    
    // 🚀 Reuses static cached regex
    private func extractImageFromHTMLFast(_ html: String) -> URL? {
        let nsRange = NSRange(html.startIndex..., in: html)
        
        // Try featured image first (more specific)
        if let match = Self.featuredImageRegex.firstMatch(in: html, range: nsRange),
           let range = Range(match.range(at: 1), in: html),
           let url = makeURL(from: String(html[range])) {
            return url
        }
        
        // Fall back to any image
        if let match = Self.imageRegex.firstMatch(in: html, range: nsRange),
           let range = Range(match.range(at: 1), in: html),
           let url = makeURL(from: String(html[range])) {
            return url
        }
        
        return nil
    }
    
    // 🚀 Inline for performance
    @inline(__always)
    private func makeURL(from string: String) -> URL? {
        guard !string.isEmpty else { return nil }
        return URL(string: string, relativeTo: baseURL)?.absoluteURL
    }
    
    // 🚀 Lazy cached favicon - computed once
    private lazy var cachedFaviconURL: URL? = {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        guard let baseHost = components.url else { return nil }
        return URL(string: "/favicon.ico", relativeTo: baseHost)?.absoluteURL
    }()
    
    @inline(__always)
    private func getFaviconURL() -> URL? {
        cachedFaviconURL
    }
}
