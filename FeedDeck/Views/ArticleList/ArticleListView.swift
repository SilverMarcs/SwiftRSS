//
//  ArticleListView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Article.publishedAt, order: .reverse) private var allArticles: [Article]

    let filter: ArticleFilter
    @Binding var selection: Article?

    @State private var searchText = ""
    @State private var showingUnreadOnly = false
    @State private var showingMarkAllReadAlert = false
    @State private var isRefreshableInFlight = false

    private var articles: [Article] {
        allArticles.filter { article in
            var matches = true

            switch filter {
            case .all:
                break
            case .unread:
                matches = !article.isRead
            case .starred:
                matches = article.isStarred
            case .feed(let feed):
                matches = article.feed?.url == feed.url
            case .today:
                let cal = Calendar.current
                let start = cal.startOfDay(for: .now)
                let end = cal.date(byAdding: .day, value: 1, to: start)!
                matches = article.publishedAt >= start && article.publishedAt < end
            }

            if matches && showingUnreadOnly {
                matches = !article.isRead
            }

            if matches && !searchText.isEmpty {
                matches = article.title.localizedStandardContains(searchText)
            }

            return matches
        }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(articles) { article in
                ArticleRow(article: article)
                    .tag(article)
            }
            .listRowSeparator(.hidden, edges: .top)
            .listRowSeparator(.visible, edges: .bottom)
        }
        .contentMargins(.top, 4)
        .contentMargins(.horizontal, 5)
        .navigationTitle(filter.displayName)
        .toolbarTitleDisplayMode(.inline)
        .navigationSubtitle("\(articles.count) articles")
//        .safeAreaBar(edge: .top) {
//            HStack {
//                Image(systemName: "magnifyingglass")
//                    .foregroundStyle(.secondary)
//                TextField("Search Articles", text: $searchText)
//                    .textFieldStyle(.plain)
//                
//                if !searchText.isEmpty {
//                    Button(action: { searchText = "" }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//            .padding(.vertical, 5)
//            .padding(.horizontal, 7)
//            .background(.fill.tertiary)
//            .cornerRadius(16)
//            .padding(.horizontal, 10)
//        }
        #if !os(macOS)
        .searchable(text: $searchText, prompt: "Search Articles")
        #endif
        .refreshable {
            isRefreshableInFlight = true
            defer { isRefreshableInFlight = false }
            await store.refreshAll()
        }
        .toolbar {
            ToolbarItem(placement: .platformBar) {
                Button {
                    if !articles.allSatisfy(\.isRead) {
                        showingMarkAllReadAlert = true
                    }
                } label: {
                    Label("Mark all as read", systemImage: "largecircle.fill.circle")
                }
                .disabled(articles.allSatisfy(\.isRead))
                .confirmationDialog("Mark All as Read", isPresented: $showingMarkAllReadAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Mark All Read", role: .destructive) {
                        for article in articles { article.isRead = true }
                    }
                } message: {
                    Text("Are you sure you want to mark all \(articles.count) articles as read?")
                }
            }

            if filter != .unread {
                ToolbarItem {
                    Button {
                        withAnimation {
                            showingUnreadOnly.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundStyle(showingUnreadOnly ? .accent : .primary)
                    }
                }
            }

            #if os(macOS)
            ToolbarSpacer()
            #else
            ToolbarSpacer(.flexible, placement: .bottomBar)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            #endif
        }
        .overlay {
            if store.isRefreshing && !isRefreshableInFlight {
                ProgressView()
                    .controlSize(.large)
            }
        }
    }
}
