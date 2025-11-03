//
//  ContentView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import Observation
import Reeeed
import SwiftMediaViewer

struct ContentView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State var showAddFeed: Bool = false
    @State var showSettings: Bool = false
    @State var initialFetchDone: Bool = false
    @State var navigationPath = NavigationPath()
    
    @Namespace private var transition

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    ForEach(store.feeds) { feed in
                        NavigationLink(value: ArticleFilter.feed(feed)) {
                            FeedRow(feed: feed)
                        }
                    }
                    .onDelete(perform: deleteFeeds)
                }
            }
            .navigationTitle("Feed")
            .navigationDestination(for: ArticleFilter.self) { filter in
                ArticleListView(filter: filter)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleReaderView(articleID: article.id)
            }
            .navigationDestination(for: URL.self) { url in
                ReederSpecificView(url: url)
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await store.refreshAll()
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
                .matchedTransitionSource(id: "settings", in: transition)
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
                    #if !os(macOS)
                    .navigationTransition(.zoom(sourceID: "settings", in: transition))
                    #endif
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await store.refreshAll()
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            navigationPath.append(url)
            return .handled
        })
    }
    
    // MARK: - Delete Function
    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            let feedToDelete = store.feeds[index]
            store.deleteFeed(feedToDelete)
        }
    }
}
