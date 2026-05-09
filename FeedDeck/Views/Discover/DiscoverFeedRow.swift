//
//  DiscoverFeedRow.swift
//  FeedDeck
//
//  Created by Zabir Raihan on 08/04/2026.
//

import SwiftUI
import SwiftMediaViewer

struct DiscoverFeedRow: View {
    let feed: StarterFeed
    let state: FeedRowState
    let onAdd: () async -> Void
    let onRemove: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let iconURL = feed.iconURL {
                CachedAsyncImage(url: iconURL, targetSize: 40)
                    .frame(width: 28, height: 28)
                    .clipShape(.rect(cornerRadius: 6))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }

            Text(feed.name)

            Spacer()

            switch state {
            case .available:
                Button {
                    Task { await onAdd() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.accent)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            case .adding, .removing:
                ProgressView()
                    .controlSize(.small)
            case .added:
                Button {
                    Task { await onRemove() }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }
}
