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
        Group {
#if os(macOS)
            compactBody
#else
            standardBody
#endif
        }
        .opacity(article.isRead ? 0.7 : 1)
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

    var standardBody: some View {
        VStack(alignment: .leading) {
            if let imageURL = article.featuredImageURL {
                CachedAsyncImage(url: imageURL, targetSize: 400)
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
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
    }

    var compactBody: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if let imageURL = article.featuredImageURL {
                    CachedAsyncImage(url: imageURL, targetSize: 150)
                        .aspectRatio(contentMode: .fill)
                } else if let imageURL = article.feed?.thumbnailURL {
                    CachedAsyncImage(url: imageURL, targetSize: 150)
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "apple.book.pages.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .clipped()
            .clipShape(.rect(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .lineLimit(2)
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()

                HStack(spacing: 4) {
                    Text(article.feed?.title ?? "")
                        .lineLimit(1)
                    Text("·")
                    Text(article.publishedAt.publishedFormat)
                    if article.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(5)
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
