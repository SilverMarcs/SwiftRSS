//
//  Feed.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import Foundation
import SwiftData

@Model
final class Feed {
    var title: String = ""
    var url: URL?
    var thumbnailURL: URL?

    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]?

    init(title: String, url: URL, thumbnailURL: URL? = nil) {
        self.title = title
        self.url = url
        self.thumbnailURL = thumbnailURL
    }
}
