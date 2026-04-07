//
//  FeedItem.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 10/09/2025.
//

import Foundation

struct FeedItem: Sendable {
    var title: String
    var link: URL
    var contentHTML: String?
    var author: String?
    var publishedAt: Date?
    var featuredImageURL: URL?
}

struct FeedMeta: Sendable {
    var title: String?
    var thumbnailURL: URL?

    static func faviconURL(for feedURL: URL) -> URL? {
        guard let host = feedURL.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }
}

enum FeedFormat { case rss2, atom }

enum FeedError: Error {
    case invalidResponse
    case notFeed
    case badStatus(Int)
}
