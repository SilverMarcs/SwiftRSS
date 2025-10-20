//
//  FeedRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import Observation

struct FeedRow: View {
    let feed: Feed
    @Environment(FeedStore.self) private var store
    
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
        .badge(store.articles.filter { $0.feed.id == feed.id }.count)
    }
}
