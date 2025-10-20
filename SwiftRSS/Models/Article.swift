//
//  Article.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 03/10/2025.
//

import Foundation
import Observation

struct Article: Identifiable, Hashable, Codable {
    var id: String { link.absoluteString }

    var feed: Feed
    var link: URL
    var title: String
    var author: String?
    var contentHTML: String?
    var featuredImageURL: URL?
    var publishedAt: Date
}

extension Article {
    func isRead(in store: FeedStore) -> Bool {
        store.getArticleState(id).isRead
    }
    
    func isStarred(in store: FeedStore) -> Bool {
        store.getArticleState(id).isStarred
    }
}
