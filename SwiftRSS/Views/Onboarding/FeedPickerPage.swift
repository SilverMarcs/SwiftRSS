//
//  FeedPickerPage.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI

struct FeedPickerPage: View {
    @Environment(FeedStore.self) private var store

    @State private var selectedFeeds: Set<String> = []
    @State private var isAdding = false

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(StarterFeedCategory.allCases, id: \.self) { category in
                    if !category.feeds.isEmpty {
                        Section(category.rawValue) {
                            ForEach(category.feeds) { feed in
                                Button {
                                    toggleFeed(feed.url)
                                } label: {
                                    HStack {
                                        Text(feed.name)

                                        Spacer()

                                        if selectedFeeds.contains(feed.url) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.accent)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Some Feeds")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onComplete()
                    }
                    .disabled(isAdding)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected") {
                        Task { await addSelectedFeeds() }
                    }
                    .disabled(selectedFeeds.isEmpty || isAdding)
                }
            }
        }
    }

    private func toggleFeed(_ url: String) {
        if selectedFeeds.contains(url) {
            selectedFeeds.remove(url)
        } else {
            selectedFeeds.insert(url)
        }
    }

    private func addSelectedFeeds() async {
        isAdding = true
        for feed in StarterFeedCategory.allFeeds where selectedFeeds.contains(feed.url) {
            if let url = URL(string: feed.url) {
                try? await store.addFeed(url: url)
            }
        }
        await store.refreshAll()
        onComplete()
    }
}
