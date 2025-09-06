//
//  ArticleFilter.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import Foundation

enum ArticleFilter: Hashable {
    case all
    case unread
    case starred
    case feed(Feed)
    
    var displayName: String {
        switch self {
        case .all:
            "All Articles"
        case .unread:
            "Unread"
        case .starred:
            "Starred"
        case .feed(let feed):
            feed.title
        }
    }
}
