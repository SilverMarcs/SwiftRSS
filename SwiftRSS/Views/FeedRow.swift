//
//  FeedRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import CachedAsyncImage

struct FeedRow: View {
    let feed: Feed
    
    var body: some View {
        Label {
            Text(feed.title)
        } icon: {
            if let imageURL = feed.thumbnailURL {
                CachedAsyncImage(url: imageURL, targetSize: .init(width: 50, height: 50))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .imageScale(.small)
            }
        }
    }
}

#Preview {
    FeedRow(feed: .init(title: "Test", url: URL(string: "https://com.example.com")!))
}
