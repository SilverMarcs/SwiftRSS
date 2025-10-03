//
//  Article.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation

// Persistent article state (read/starred status only)
struct ArticleState: Codable {
    var isRead: Bool = false
    var isStarred: Bool = false
}

// Transient article data (loaded fresh from feeds)
struct Article: Identifiable, Hashable {
    // Use link absoluteString as stable ID
    var id: String { link.absoluteString }

    var feed: Feed

    var link: URL
    var title: String
    var author: String?
    var contentHTML: String?
    var featuredImageURL: URL?
    var publishedAt: Date

    // State accessed globally like SwiftTube - simpler but less encapsulated
    var isRead: Bool {
        ArticleStateManager.shared.getState(for: id)?.isRead ?? false
    }
    
    var isStarred: Bool {
        ArticleStateManager.shared.getState(for: id)?.isStarred ?? false
    }
    
    init(feed: Feed, link: URL, title: String, author: String?, contentHTML: String?, featuredImageURL: URL?, publishedAt: Date) {
        self.feed = feed
        self.link = link
        self.title = title
        self.author = author
        self.contentHTML = contentHTML
        self.featuredImageURL = featuredImageURL
        self.publishedAt = publishedAt
    }
}
