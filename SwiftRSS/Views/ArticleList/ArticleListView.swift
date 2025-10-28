import SwiftUI
import Observation

struct ArticleListView: View {
    @Environment(FeedStore.self) private var store
    
    let filter: ArticleFilter
    
    @State private var searchText: String = ""
    @State private var showingUnreadOnly: Bool = false
    @State private var showingMarkAllReadAlert: Bool = false
    
    private var articles: [Article] {
        store.articles.filter { article in
            var matches = true
            
            switch filter {
            case .all:
                break
            case .unread:
                matches = !article.isRead
            case .starred:
                matches = article.isStarred
            case .feed(let feed):
                matches = article.feed.id == feed.id
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
        List {
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    ArticleRow(article: article)
                }
                .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .contentMargins(.top, 4)
        .contentMargins(.horizontal, 5)
        .navigationTitle(filter.displayName)
        .toolbarTitleDisplayMode(.inline)
        .navigationSubtitle("\(articles.count) articles")
        .searchable(text: $searchText, prompt: "Search Articles")
        .refreshable {
            await store.refreshAll()
        }
        .task {
            if articles.isEmpty {
                await store.refreshAll()
            }
        }
         .toolbar {
             ToolbarItem(placement: .platformBar) {
                 Button {
                     if !articles.allSatisfy({ $0.isRead }) {
                         showingMarkAllReadAlert = true
                     }
                 } label: {
                     Label("Mark all as read", systemImage: "largecircle.fill.circle")
                 }
                 .disabled(articles.allSatisfy({ $0.isRead }))
                .confirmationDialog("Mark All as Read", isPresented: $showingMarkAllReadAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Mark All Read", role: .destructive) {
                        markAllAsRead()
                    }
                } message: {
                    Text("Are you sure you want to mark all \(articles.count) articles as read?")
                }
            }
            
            if filter != .unread {
                ToolbarItem {
                    Button {
                        showingUnreadOnly.toggle()
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
    }

    private func markAllAsRead() {
        let ids = articles.map { $0.id }
        store.markAllAsRead(articleIDs: ids)
    }
}
