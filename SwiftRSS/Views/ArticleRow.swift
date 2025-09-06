//
//  ArticleRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SafariServices
import CachedAsyncImage

struct ArticleRow: View {
    @Environment(\.modelContext) private var context
    @State private var showingSafari = false
    
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image at the top
            if let imageURL = article.featuredImageURL ?? article.thumbnailURL {
                CachedAsyncImage(url: imageURL, targetSize: .init(width: 500, height: 350))
                    .frame(height: 150)
                    .cornerRadius(8)
            }
            
            // Content below image
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .lineLimit(2)
                        .foregroundColor(article.isRead ? .secondary : .primary)
                        .font(.headline)
                    
                    HStack {
                        Text(article.feed.title)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let date = article.publishedAt {
                            Text(date.publishedFormat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack {
                    if !article.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                    if article.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
        }
        .contentShape(.contextMenuPreview, .rect)
        .swipeActions(edge: .leading) {
            Button {
                article.isRead.toggle()
            } label: {
                Label(article.isRead ? "Unread" : "Read", systemImage: article.isRead ? "circle" : "checkmark")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                article.isStarred.toggle()
            } label: {
                Label(article.isStarred ? "Unstar" : "Star", systemImage: "star")
            }
            .tint(.orange)
        }
    }
}
