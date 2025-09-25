import SwiftUI
import Observation

struct ArticleListView: View {
    @Environment(FeedStore.self) private var store
    private var articles: [Article] {
        var list = store.articles
        switch filter {
        case .all:
            break
        case .unread:
            list = list.filter { !$0.isRead }
        case .starred:
            list = list.filter { $0.isStarred }
        case .feed(let feed):
            list = list.filter { $0.feedID == feed.id }
        case .today:
            let cal = Calendar.current
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            list = list.filter { $0.publishedAt >= start && $0.publishedAt < end }
        }
        if showingUnreadOnly {
            list = list.filter { !$0.isRead }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.title.localizedStandardContains(searchText) }
        }
        return list.sorted { $0.publishedAt > $1.publishedAt }
    }
    
    let filter: ArticleFilter
    let searchText: String
    let showingUnreadOnly: Bool
    
    // Move the state here instead of receiving it as a binding
    @State private var showingMarkAllReadAlert: Bool = false

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
        .navigationSubtitle("\(articles.count) articles")
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
        }
    }
    
    init(filter: ArticleFilter, searchText: String, showingUnreadOnly: Bool) {
        self.filter = filter
        self.searchText = searchText
        self.showingUnreadOnly = showingUnreadOnly
    }

    // MARK: - Actions
    private func markAllAsRead() {
        store.markAllRead(in: articles)
    }
}
