//
//  AtomParser.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 23/10/2025.
//

import Foundation
import Fuzi

struct AtomParser: FeedParser {
    let baseURL: URL
    private let maxItems: Int = 50
    
    func parseItems(from document: XMLDocument) throws -> [FeedItem] {
        let entryNodes = document.xpath("/feed/entry")
        let entries = entryNodes.isEmpty ? document.xpath("//*[local-name()='entry']") : entryNodes
        return entries.prefix(maxItems).map { parseItem($0) }
    }
    
    func parseMeta(from document: XMLDocument) -> FeedMeta {
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
    
    private func parseItem(_ entryNode: XMLElement) -> FeedItem {
        var item = FeedItem(
            title: entryNode.firstChild(tag: "title")?.stringValue ?? "",
            link: extractLink(from: entryNode),
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
    
    private func extractLink(from node: XMLElement) -> URL {
        if let linkElement = node.firstChild(tag: "link"),
           let href = linkElement["href"],
           let url = URL(string: href, relativeTo: baseURL) {
            return url.absoluteURL
        }
        return baseURL
    }
    
    private func extractImageFromHTML(_ html: String) -> URL? {
        let pattern = #"<img[^>]+src=["\']([^"\']+)["\']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
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
