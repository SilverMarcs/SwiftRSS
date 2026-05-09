//
//  ContentView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData
import Reeeed
import SwiftMediaViewer

struct ContentView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Feed.title) private var feeds: [Feed]

    @State var showAddFeed = false
    @State var showSettings = false
    @State private var selectedFilter: ArticleFilter?
    @State private var selectedArticle: Article?
    @State private var detailPath = NavigationPath()

    @AppStorage("openLinksInReaderView") private var openLinksInReaderView = true
    @AppStorage("lastRefreshDate") private var lastRefreshDate: Double = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    @Namespace private var transition

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFilter) {
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
            .navigationTitle("FeedDeck")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await store.refreshAll()
                lastRefreshDate = Date.now.timeIntervalSince1970
            }
            #if os(macOS)
            .safeAreaBar(edge: .bottom) {
                Button {
                    showAddFeed.toggle()
                } label: {
                    Label("Discover Feeds", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            #else
            .toolbar {
                ToolbarItem {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                .matchedTransitionSource(id: "settings", in: transition)

                ToolbarSpacer(.flexible, placement: .platformBar)

                ToolbarItem(placement: .platformBar) {
                    Button {
                        showAddFeed.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                }
                .matchedTransitionSource(id: "add-feed", in: transition)
            }
            #endif
        } content: {
            if let selectedFilter {
                ArticleListView(filter: selectedFilter, selection: $selectedArticle)
            } else {
                ScrollView {
                    ContentUnavailableView("Select a Feed", systemImage: "list.bullet.rectangle")
                }
                .defaultScrollAnchor(.center)
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selectedArticle {
                    ArticleReaderView(article: selectedArticle)
                        .id(selectedArticle.id)
                        .navigationDestination(for: URL.self) { url in
                            ReederSpecificView(url: url)
                        }
                } else {
                    ScrollView {
                        ContentUnavailableView("Select an Article", systemImage: "doc.richtext")
                    }
                    .defaultScrollAnchor(.center)
                }
            }
        }
        .sheet(isPresented: $showAddFeed) {
            Task { await store.refreshAll() }
        } content: {
            DiscoverFeedsView()
                #if os(macOS)
                .frame(minWidth: 500, idealWidth: 600, minHeight: 500, idealHeight: 600)
                #else
                .navigationTransition(.zoom(sourceID: "add-feed", in: transition))
                #endif
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                #if !os(macOS)
                .navigationTransition(.zoom(sourceID: "settings", in: transition))
                #endif
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                let oneHour: TimeInterval = 3600
                if Date.now.timeIntervalSince1970 - lastRefreshDate < oneHour { return }
                await store.refreshAll()
                lastRefreshDate = Date.now.timeIntervalSince1970
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if openLinksInReaderView {
                detailPath.append(url)
                return .handled
            }
            return .systemAction(prefersInApp: true)
        })
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
                .interactiveDismissDisabled(false)
        }
    }

    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(feeds[index])
        }
    }
}
