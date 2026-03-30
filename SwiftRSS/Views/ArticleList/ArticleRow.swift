//
//  ArticleRow.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData
import SwiftMediaViewer

struct ArticleRow: View {
    @Environment(\.modelContext) private var modelContext

    let article: Article

    var body: some View {
        VStack(alignment: .leading) {
            if let imageURL = article.featuredImageURL {
                CachedAsyncImage(url: imageURL, targetSize: 400)
                    .frame(height: 170)
                    .aspectRatio(contentMode: .fill)
                    .cornerRadius(8)
            }

            Text(article.title)
                .lineLimit(2)
                .font(.headline)

            HStack {
                Group {
                    if let imageURL = article.feed?.thumbnailURL {
                        CachedAsyncImage(url: imageURL, targetSize: 50)
                            .clipShape(.rect(cornerRadius: 4))
                    } else {
                        Image(systemName: "apple.book.pages.fill")
                            .imageScale(.small)
                    }
                }
                .frame(width: 15, height: 15)

                Text(article.feed?.title ?? "")
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
        .contextMenu {
            readButton
            starButton
            Divider()
            if let link = article.link {
                ShareLink(item: link)
            }
        }
        .swipeActions(edge: .leading) {
            readButton.tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            starButton.tint(.orange)
        }
    }

    var readButton: some View {
        Button {
            article.isRead.toggle()
        } label: {
            Label(article.isRead ? "Mark Unread" : "Mark Read", systemImage: article.isRead ? "largecircle.fill.circle" : "circle")
        }
    }

    var starButton: some View {
        Button {
            article.isStarred.toggle()
        } label: {
            Label(article.isStarred ? "Unstar" : "Star", systemImage: article.isStarred ? "star.fill" : "star")
        }
    }
}
