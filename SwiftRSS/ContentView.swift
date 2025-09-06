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
    @State private var path = NavigationPath()
    
    @Namespace private var transition

    var body: some View {
        NavigationStack(path: $path) {
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
                                .badge(feed.articles.count(where: { !$0.isRead })) 
                        }
                    }
                    .onDelete(perform: deleteFeeds)
                }
            }
            .navigationTitle("Feed")
            .navigationDestinations(path: $path)
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await FeedService.refreshAll(context: context)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarSpacer(.flexible, placement: .bottomBar)
                
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showAddFeed.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .matchedTransitionSource(id: "add-feed", in: transition)
            }
            .sheet(isPresented: $showAddFeed) {
                AddFeedSheet()
                    .presentationDetents([.medium])
                    .navigationTransition(.zoom(sourceID: "add-feed", in: transition))
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
