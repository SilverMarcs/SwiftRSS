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
        .badge(feed.articles?.filter { !$0.isRead }.count ?? 0)
    }
}
