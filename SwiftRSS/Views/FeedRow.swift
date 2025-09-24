//
//  FeedRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct FeedRow: View {
    let feed: Feed
    
    var body: some View {
        Label {
            Text(feed.title)
        } icon: {
            if let imageURL = feed.thumbnailURL {
                CachedAsyncImage(url: imageURL, targetSize: 50)
                    .clipShape(.rect(cornerRadius: 5))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .imageScale(.small)
            }
        }
        .badge(feed.articles.count(where: { !$0.isRead })) 
    }
}

#Preview {
    FeedRow(feed: .init(title: "Test", url: URL(string: "https://com.example.com")!))
}
