//
//  ContentView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Query(sort: \Feed.title) private var feeds: [Feed]

    @State var showAddFeed: Bool = false
    @State var showSettings: Bool = false
    @State var initialFetchDone: Bool = false
    
    @Namespace private var transition

    var body: some View {
        NavigationStack {
            List {
                Section("Smart") {
                    ForEach(ArticleFilter.smartFilters, id: \.self) { filter in
                        NavigationLink(value: filter) {
                            Label {
                                Text(filter.displayName)
                            } icon: {
                                Image(systemName: filter.icon)
                                    .foregroundStyle(filter.color)
                            }
                        }
                    }
                }

                Section("Feeds") {
                    ForEach(feeds) { feed in
                        NavigationLink(value: ArticleFilter.feed(feed)) {
                            FeedRow(feed: feed)
                        }
                    }
                    .onDelete(perform: deleteFeeds)
                }
            }
            .navigationTitle("Feed")
            .navigationDestination(for: ArticleFilter.self) { filter in
                ArticleListContainerView(filter: filter)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleReaderView(article: article)
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                if !initialFetchDone {
                    let _ = try? await FeedService.refreshAll(modelContainer: context.container)
                    initialFetchDone = true
                }
            }
            .refreshable {
                let _ = try? await FeedService.refreshAll(modelContainer: context.container)
            }
            .toolbar {
                #if !os(macOS)
                ToolbarItem {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                #endif
                
                ToolbarSpacer(.flexible, placement: .platformBar)
                
                ToolbarItem(placement: .platformBar) {
                    Button {
                        showAddFeed.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #if !os(macOS)
                .matchedTransitionSource(id: "add-feed", in: transition)
                #endif
            }
            .sheet(isPresented: $showAddFeed) {
                AddFeedSheet()
                    .presentationDetents([.medium])
                    #if !os(macOS)
                    .navigationTransition(.zoom(sourceID: "add-feed", in: transition))
                    #endif
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Delete Function
    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            let feedToDelete = feeds[index]
            context.delete(feedToDelete)
        }
    }
}
