import Foundation
import Fuzi

final class XMLFeedParser {
    private let data: Data
    private let baseURL: URL
    private let maxItems: Int = 50
    
    // Cached regex for efficiency
    private lazy var imgRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<img[^>]+src=["\']([^"\']+)["\']"#, options: .caseInsensitive)
    }()
    
    init(data: Data, baseURL: URL) {
        self.data = data
        self.baseURL = baseURL
    }
    
    func parseRSS2() throws -> (FeedMeta, [FeedItem]) {
        guard let document = try? XMLDocument(data: data) else {
            throw FeedError.notFeed
        }
        
        var meta = FeedMeta()
        var items: [FeedItem] = []
        
        // Parse feed metadata
        meta.title = document.firstChild(xpath: "/rss/channel/title")?.stringValue
        
        if let imageURL = document.firstChild(xpath: "/rss/channel/image/url")?.stringValue {
            meta.thumbnailURL = URL(string: imageURL, relativeTo: baseURL)?.absoluteURL
        }
        
        if meta.thumbnailURL == nil {
            meta.thumbnailURL = getFaviconURL()
        }
        
        // Parse items (limited to maxItems)
        let itemNodes = Array(document.xpath("/rss/channel/item").prefix(maxItems))
        
        for itemNode in itemNodes {
            var item = FeedItem(
                title: "",
                link: baseURL,
                contentHTML: nil,
                author: nil,
                publishedAt: nil,
                featuredImageURL: nil
            )
            
            // Title
            item.title = itemNode.firstChild(tag: "title")?.stringValue ?? ""
            
            // Link
            if let linkString = itemNode.firstChild(tag: "link")?.stringValue,
               let url = URL(string: linkString, relativeTo: baseURL) {
                item.link = url.absoluteURL
            }
            
            // Content (prefer content:encoded over description)
            let contentEncoded = itemNode.firstChild(xpath: "*[local-name()='encoded']")?.stringValue
            let description = itemNode.firstChild(tag: "description")?.stringValue
            item.contentHTML = contentEncoded ?? description
            
            // Author (try both author and dc:creator)
            item.author = itemNode.firstChild(tag: "author")?.stringValue ??
                         itemNode.firstChild(xpath: "*[local-name()='creator']")?.stringValue
            
            // Published date
            if let dateString = itemNode.firstChild(tag: "pubDate")?.stringValue ??
                               itemNode.firstChild(tag: "published")?.stringValue {
                item.publishedAt = RFCDate.parse(dateString)
            }
            
            // Featured image - try enclosure first
            if let enclosure = itemNode.firstChild(tag: "enclosure"),
               let type = enclosure["type"],
               type.hasPrefix("image/"),
               let urlString = enclosure["url"],
               let url = URL(string: urlString, relativeTo: baseURL) {
                item.featuredImageURL = url.absoluteURL
            }
            
            // Try media:content or media:thumbnail
            if item.featuredImageURL == nil {
                if let mediaURL = itemNode.firstChild(xpath: "*[local-name()='content']")?["url"] ??
                                 itemNode.firstChild(xpath: "*[local-name()='thumbnail']")?["url"],
                   let url = URL(string: mediaURL, relativeTo: baseURL) {
                    item.featuredImageURL = url.absoluteURL
                }
            }
            
            // Extract from HTML content as fallback
            if item.featuredImageURL == nil {
                if let html = contentEncoded ?? description {
                    item.featuredImageURL = extractImageFromHTML(html)
                }
            }
            
            items.append(item)
        }
        
        return (meta, items)
    }
    
    func parseAtom() throws -> (FeedMeta, [FeedItem]) {
        guard let document = try? XMLDocument(data: data) else {
            throw FeedError.notFeed
        }
        
        var meta = FeedMeta()
        var items: [FeedItem] = []
        
        // Parse feed metadata
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
        
        if meta.thumbnailURL == nil {
            meta.thumbnailURL = getFaviconURL()
        }
        
        // Parse entries (limited to maxItems)
        let entryNodes = document.xpath("/feed/entry")
        let entries = entryNodes.isEmpty ? document.xpath("//*[local-name()='entry']") : entryNodes
        
        for (index, entryNode) in entries.enumerated() {
            guard index < maxItems else { break }
            
            var item = FeedItem(
                title: "",
                link: baseURL,
                contentHTML: nil,
                author: nil,
                publishedAt: nil,
                featuredImageURL: nil
            )
            
            // Title
            item.title = entryNode.firstChild(tag: "title")?.stringValue ?? ""
            
            // Link (Atom uses link element with href attribute)
            if let linkElement = entryNode.firstChild(tag: "link"),
               let href = linkElement["href"],
               let url = URL(string: href, relativeTo: baseURL) {
                item.link = url.absoluteURL
            }
            
            // Content (prefer content over summary)
            let content = entryNode.firstChild(tag: "content")?.stringValue
            let summary = entryNode.firstChild(tag: "summary")?.stringValue
            item.contentHTML = content ?? summary
            
            // Author
            item.author = entryNode.firstChild(xpath: "author/name")?.stringValue ??
                         entryNode.firstChild(xpath: "*[local-name()='author']/*[local-name()='name']")?.stringValue
            
            // Published date (try published, fall back to updated)
            if let dateString = entryNode.firstChild(tag: "published")?.stringValue ??
                               entryNode.firstChild(tag: "updated")?.stringValue {
                item.publishedAt = RFCDate.parse(dateString)
            }
            
            // Extract image from HTML content
            if let html = content ?? summary {
                item.featuredImageURL = extractImageFromHTML(html)
            }
            
            items.append(item)
        }
        
        return (meta, items)
    }
    
    // Extract first image URL from HTML content
    private func extractImageFromHTML(_ html: String) -> URL? {
        guard let regex = imgRegex else { return nil }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else { return nil }
        
        let urlRange = match.range(at: 1)
        guard let swiftRange = Range(urlRange, in: html) else { return nil }
        
        let urlString = String(html[swiftRange])
        return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
    }
    
    // Generate favicon URL as fallback
    private func getFaviconURL() -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        
        guard let baseHost = components.url else { return nil }
        return URL(string: "/favicon.ico", relativeTo: baseHost)?.absoluteURL
    }
}
