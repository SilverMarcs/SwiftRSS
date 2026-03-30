//
//  Article.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation
import SwiftData

@Model
final class Article {
    var articleID: String = ""
    var link: URL?
    var title: String = ""
    var author: String?
    var featuredImageURL: URL?
    var publishedAt: Date = Date.now
    var isRead: Bool = false
    var isStarred: Bool = false

    var feed: Feed?

    init(feed: Feed, link: URL, title: String, author: String? = nil, featuredImageURL: URL? = nil, publishedAt: Date) {
        self.feed = feed
        self.link = link
        self.articleID = URLNormalizer.normalizedArticleID(from: link)
        self.title = title
        self.author = author
        self.featuredImageURL = featuredImageURL
        self.publishedAt = publishedAt
    }
}
