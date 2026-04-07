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
    @State var navigationPath = NavigationPath()

    @AppStorage("openLinksInReaderView") private var openLinksInReaderView = true
    @AppStorage("lastRefreshDate") private var lastRefreshDate: Double = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
                ArticleListView(filter: filter)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleReaderView(article: article)
            }
            .navigationDestination(for: URL.self) { url in
                ReederSpecificView(url: url)
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await store.refreshAll()
                lastRefreshDate = Date.now.timeIntervalSince1970
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
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                }
                #if !os(macOS)
                .matchedTransitionSource(id: "add-feed", in: transition)
                #endif
            }
            .sheet(isPresented: $showAddFeed) {
                Task { await store.refreshAll() }
            } content: {
                DiscoverFeedsView()
                    #if !os(macOS)
                    .navigationTransition(.zoom(sourceID: "add-feed", in: transition))
                    #endif
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    #if !os(macOS)
                    .navigationTransition(.zoom(sourceID: "settings", in: transition))
                    #endif
            }
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
                navigationPath.append(url)
                return .handled
            }
            return .systemAction(prefersInApp: true)
        })
        .onAppear {
            if !feeds.isEmpty {
                hasCompletedOnboarding = true
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(feeds[index])
        }
    }
}
