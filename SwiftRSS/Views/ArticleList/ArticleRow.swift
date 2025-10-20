//
//  ArticleRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import Observation

struct ArticleRow: View {
    @Environment(FeedStore.self) private var store
    
    let article: Article

    var body: some View {
        VStack(alignment: .leading) {
            // Image at the top
            if let imageURL = article.featuredImageURL {
                CachedAsyncImage(url: imageURL, targetSize: 400)
                    .frame(height: 170)
                    .aspectRatio(contentMode: .fill)
                    .cornerRadius(8)
            }
            
            // Content below image
            Text(article.title)
                .lineLimit(2)
                .font(.headline)
            
            HStack {
                Group {
                    if let imageURL = article.feed.thumbnailURL {
                        CachedAsyncImage(url: imageURL, targetSize: 50)
                            .clipShape(.rect(cornerRadius: 4))
                    } else {
                        Image(systemName: "apple.book.pages.fill")
                            .imageScale(.small)
                    }
                }
                .frame(width: 15, height: 15)
                
                Text(article.feed.title)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if article.isStarred(in: store) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                
                Text(article.publishedAt.publishedFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(article.isRead(in: store) ? 0.5 : 1)
        .contextMenu {
            readButton
            
            starButton
            
            Divider()
            
            ShareLink(item: article.link)
        }
        .swipeActions(edge: .leading) {
            readButton
                .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            starButton
                .tint(.orange)
        }
    }
    
    var readButton: some View {
        Button {
            store.toggleRead(articleID: article.id)
        } label: {
            Label(article.isRead(in: store) ? "Mark Unread" : "Mark Read", systemImage: article.isRead(in: store) ? "largecircle.fill.circle" : "circle")
        }
    }
    
    var starButton: some View {
        Button {
            store.toggleStar(articleID: article.id)
        } label: {
            Label(article.isStarred(in: store) ? "Unstar" : "Star", systemImage: "star")
        }
    }
}
