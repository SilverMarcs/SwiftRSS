//
//  StarterFeeds.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import Foundation

struct StarterFeed: Identifiable {
    let name: String
    let url: String
    let category: String

    var id: String { url }
}

enum StarterFeedCategory: String, CaseIterable {
    case tech = "Tech"
    case apple = "Apple"
    case dev = "Development"
    case news = "News"
    case design = "Design"
    case science = "Science"

    var feeds: [StarterFeed] {
        Self.allFeeds.filter { $0.category == rawValue }
    }

    static let allFeeds: [StarterFeed] = [
        // Tech
        StarterFeed(name: "The Verge", url: "https://www.theverge.com/rss/index.xml", category: "Tech"),
        StarterFeed(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", category: "Tech"),
        StarterFeed(name: "Hacker News", url: "https://hnrss.org/frontpage", category: "Tech"),
        StarterFeed(name: "TechCrunch", url: "https://techcrunch.com/feed/", category: "Tech"),
        StarterFeed(name: "Wired", url: "https://www.wired.com/feed/rss", category: "Tech"),

        // Apple
        StarterFeed(name: "9to5Mac", url: "https://9to5mac.com/feed", category: "Apple"),
        StarterFeed(name: "Daring Fireball", url: "https://daringfireball.net/feeds/main", category: "Apple"),
        StarterFeed(name: "MacRumors", url: "https://feeds.macrumors.com/MacRumors-All", category: "Apple"),
        StarterFeed(name: "Six Colors", url: "https://sixcolors.com/feed/", category: "Apple"),

        // Development
        StarterFeed(name: "Swift by Sundell", url: "https://www.swiftbysundell.com/rss", category: "Development"),
        StarterFeed(name: "Hacking with Swift", url: "https://www.hackingwithswift.com/articles/rss", category: "Development"),
        StarterFeed(name: "NSHipster", url: "https://nshipster.com/feed.xml", category: "Development"),
        StarterFeed(name: "CSS-Tricks", url: "https://css-tricks.com/feed/", category: "Development"),

        // News
        StarterFeed(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", category: "News"),
        StarterFeed(name: "Reuters", url: "https://www.reutersagency.com/feed/", category: "News"),
        StarterFeed(name: "NPR News", url: "https://feeds.npr.org/1001/rss.xml", category: "News"),

        // Design
        StarterFeed(name: "A List Apart", url: "https://alistapart.com/main/feed/", category: "Design"),
        StarterFeed(name: "Smashing Magazine", url: "https://www.smashingmagazine.com/feed/", category: "Design"),

        // Science
        StarterFeed(name: "NASA Breaking News", url: "https://www.nasa.gov/news-release/feed/", category: "Science"),
        StarterFeed(name: "Nature News", url: "https://www.nature.com/nature.rss", category: "Science"),
    ]
}
