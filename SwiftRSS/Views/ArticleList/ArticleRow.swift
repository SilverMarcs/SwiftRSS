//
//  ArticleRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData
import CachedAsyncImage

struct ArticleRow: View {
    @Environment(\.modelContext) private var context
    
    let article: Article

    var body: some View {
        VStack(alignment: .leading) {
            // Image at the top
            if let imageURL = article.featuredImageURL {
                CachedAsyncImage(url: imageURL, targetSize: .init(width: 600, height: 450))
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 170)
                    .cornerRadius(8)
            }
            
            // Content below image
            Text(article.title)
                .lineLimit(2)
                .font(.headline)
            
            HStack {
                Group {
                    if let imageURL = article.feed.thumbnailURL {
                        CachedAsyncImage(url: imageURL, targetSize: .init(width: 50, height: 50))
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
                
//                if !article.isRead {
//                    Image(systemName: "circle.fill")
//                        .font(.caption2)
//                        .foregroundStyle(.accent)
//                }
                
                Spacer()
                
                if article.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                
                Text(article.publishedAt.publishedFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(article.isRead ? 0.5 : 1)
        .contentShape(.contextMenuPreview, .rect)
        .swipeActions(edge: .leading) {
            Button {
                article.isRead.toggle()
                try? context.save()
            } label: {
                Label(article.isRead ? "Unread" : "Read", systemImage: article.isRead ? "largecircle.fill.circle" : "circle")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                article.isStarred.toggle()
                try? context.save()
            } label: {
                Label(article.isStarred ? "Unstar" : "Star", systemImage: "star")
            }
            .tint(.orange)
        }
    }
}
