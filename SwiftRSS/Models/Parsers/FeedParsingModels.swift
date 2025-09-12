//
//  FeedItem.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 10/09/2025.
//

import Foundation

// MARK: - Core Types (unchanged)
struct FeedItem {
    var title: String
    var link: URL
    var contentHTML: String?
    var author: String?
    var publishedAt: Date?
    var featuredImageURL: URL?
}

struct FeedMeta {
    var title: String?
    var thumbnailURL: URL?
}

enum FeedFormat { case rss2, atom }

enum FeedError: Error {
    case invalidResponse
    case notFeed
    case badStatus(Int)
}
