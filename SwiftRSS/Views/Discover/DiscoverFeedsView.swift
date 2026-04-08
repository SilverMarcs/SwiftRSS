//
//  DiscoverFeedsView.swift
//  FeedDeck
//
//  Created by Zabir Raihan on 08/04/2026.
//

import SwiftUI
import SwiftData
import SwiftMediaViewer

enum FeedRowState {
    case available, adding, added, removing
}

struct DiscoverFeedsView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @Query private var existingFeeds: [Feed]

    @State private var searchText = ""
    @State private var isAdding: Set<String> = []
    @State private var isRemoving: Set<String> = []
    @State private var addedFeeds: Set<String> = []
    @State private var showAddByURL = false

    private var existingFeedURLs: Set<String> {
        Set(existingFeeds.compactMap { $0.url?.absoluteString })
    }

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

    private func feedState(for feed: StarterFeed) -> FeedRowState {
        if isRemoving.contains(feed.url) {
            return .removing
        }
        if existingFeedURLs.contains(feed.url) || addedFeeds.contains(feed.url) {
            return .added
        }
        if isAdding.contains(feed.url) {
            return .adding
        }
        return .available
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories, id: \.self) { category in
                    let feeds = filteredFeeds(for: category)
                    if !feeds.isEmpty {
                        Section {
                            ForEach(feeds) { feed in
                                DiscoverFeedRow(
                                    feed: feed,
                                    state: feedState(for: feed),
                                    onAdd: { await addFeed(feed) },
                                    onRemove: { await removeFeed(feed) }
                                )
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search feeds")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .navigationTitle("Discover Feeds")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showAddByURL = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddByURL) {
                AddFeedByURLSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Actions

    private func addFeed(_ feed: StarterFeed) async {
        guard let url = URL(string: feed.url) else { return }
        isAdding.insert(feed.url)
        defer { isAdding.remove(feed.url) }

        do {
            try await store.addFeed(url: url)
            addedFeeds.insert(feed.url)
        } catch {
            // Silently fail for catalog feeds
        }
    }

    private func removeFeed(_ feed: StarterFeed) async {
        guard let url = URL(string: feed.url) else { return }
        isRemoving.insert(feed.url)
        defer { isRemoving.remove(feed.url) }

        store.removeFeed(url: url)
        addedFeeds.remove(feed.url)
    }
}
