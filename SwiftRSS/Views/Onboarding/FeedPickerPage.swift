//
//  FeedPickerPage.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 02/04/2026.
//

import SwiftUI
import SwiftMediaViewer

struct FeedPickerPage: View {
    @Environment(FeedStore.self) private var store

    @State private var selectedFeeds: Set<String> = []
    @State private var isAdding = false
    @State private var searchText = ""

    var onComplete: () -> Void

    private var filteredCategories: [StarterFeedCategory] {
        if searchText.isEmpty {
            return StarterFeedCategory.allCases
        }
        return StarterFeedCategory.allCases.filter { category in
            !filteredFeeds(for: category).isEmpty
        }
    }

    private func filteredFeeds(for category: StarterFeedCategory) -> [StarterFeed] {
        let feeds = category.feeds
        if searchText.isEmpty { return feeds }
        let query = searchText.lowercased()
        return feeds.filter {
            $0.name.lowercased().contains(query) ||
            $0.category.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories, id: \.self) { category in
                    let feeds = filteredFeeds(for: category)
                    if !feeds.isEmpty {
                        Section {
                            ForEach(feeds) { feed in
                                Button {
                                    toggleFeed(feed.url)
                                } label: {
                                    FeedPickerRow(
                                        feed: feed,
                                        isSelected: selectedFeeds.contains(feed.url)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isAdding)
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search feeds")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .navigationTitle("Add Feeds")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onComplete()
                    }
                    .disabled(isAdding)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addSelectedFeeds() }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add Selected")
                        }
                    }
                    .disabled(selectedFeeds.isEmpty || isAdding)
                }
            }
        }
    }

    private func toggleFeed(_ url: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if selectedFeeds.contains(url) {
                selectedFeeds.remove(url)
            } else {
                selectedFeeds.insert(url)
            }
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

// MARK: - Feed Picker Row

struct FeedPickerRow: View {
    let feed: StarterFeed
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let iconURL = feed.iconURL {
                CachedAsyncImage(url: iconURL, targetSize: 40)
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 5))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
            }

            Text(feed.name)

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .accent : .secondary)
        }
        .contentShape(Rectangle())
    }
}
