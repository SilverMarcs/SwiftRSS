//
//  RSSParser.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 23/10/2025.
//

import Foundation
import Fuzi

struct RSSParser: FeedParser {
    let baseURL: URL
    private let maxItems: Int = 50
    private let imgRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<img[^>]+src=["\']([^"\']+)["\']"#, options: .caseInsensitive)
    }()
    
    func parseItems(from document: XMLDocument) throws -> [FeedItem] {
        let itemNodes = Array(document.xpath("/rss/channel/item").prefix(maxItems))
        return itemNodes.map { parseItem($0) }
    }
    
    func parseMeta(from document: XMLDocument) -> FeedMeta {
        var meta = FeedMeta()
        meta.title = document.firstChild(xpath: "/rss/channel/title")?.stringValue
        
        if let imageURL = document.firstChild(xpath: "/rss/channel/image/url")?.stringValue {
            meta.thumbnailURL = URL(string: imageURL, relativeTo: baseURL)?.absoluteURL
        }
        
        meta.thumbnailURL = meta.thumbnailURL ?? getFaviconURL()
        return meta
    }
    
    private func parseItem(_ itemNode: XMLElement) -> FeedItem {
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
        
        // Featured image
        item.featuredImageURL = extractImage(from: itemNode, html: item.contentHTML)
        
        return item
    }
    
    private func extractImage(from itemNode: XMLElement, html: String?) -> URL? {
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
    
    private func extractLink(from node: XMLElement, tag: String) -> URL {
        if let linkString = node.firstChild(tag: tag)?.stringValue,
           let url = URL(string: linkString, relativeTo: baseURL) {
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
