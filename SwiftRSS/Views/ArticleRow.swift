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
                    .frame(height: 165)
                    .cornerRadius(8)
            }
            
            // Content below image
            Text(article.title)
                .lineLimit(2)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .font(.headline)
            
            HStack {
                Group {
                    if let imageURL = article.feed.thumbnailURL {
                        CachedAsyncImage(url: imageURL, targetSize: .init(width: 50, height: 50))
                            .clipShape(.rect(cornerRadius: 4))
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .imageScale(.small)
                    }
                }
                .frame(width: 15, height: 15)
                
                Text(article.feed.title)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                
                if !article.isRead {
                    Circle()
                        .fill(.accent)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                if article.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                
                if let date = article.publishedAt {
                    Text(date.publishedFormat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(.contextMenuPreview, .rect)
        .swipeActions(edge: .leading) {
            Button {
                article.isRead.toggle()
                try? article.modelContext?.save()
            } label: {
                Label(article.isRead ? "Unread" : "Read", systemImage: article.isRead ? "circle" : "checkmark")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                article.isStarred.toggle()
                try? article.modelContext?.save()
            } label: {
                Label(article.isStarred ? "Unstar" : "Star", systemImage: "star")
            }
            .tint(.orange)
        }
    }
}
