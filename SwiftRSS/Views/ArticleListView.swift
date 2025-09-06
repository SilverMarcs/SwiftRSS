import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var context
    @Query private var articles: [Article]
    
    let filter: ArticleFilter

    var body: some View {
        List {
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    ArticleRow(article: article)
                }
                .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .contentMargins(.top, 2)
        .contentMargins(.horizontal, 5)
//        .listStyle(.plain)
        .toolbar {
            ToolbarItem {
                Button {
                    
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
        .navigationTitle(filter.displayName)
        .navigationSubtitle("\(articles.count) articles")
        .toolbarTitleDisplayMode(.inline)
        .refreshable {
            await refreshCurrentScope()
        }
    }
    
    init(filter: ArticleFilter) {
        self.filter = filter
        
        switch filter {
        case .all:
            _articles = Query(sort: \Article.publishedAt, order: .reverse)
        case .unread:
            _articles = Query(
                filter: #Predicate<Article> { $0.isRead == false },
                sort: \Article.publishedAt,
                order: .reverse
            )
        case .starred:
            _articles = Query(
                filter: #Predicate<Article> { $0.isStarred == true },
                sort: \Article.publishedAt,
                order: .reverse
            )
        case .feed(let feed):
            let feedID = feed.persistentModelID
            let predicate = #Predicate<Article> { article in
                article.feed.persistentModelID == feedID
            }
            _articles = Query(filter: predicate, sort: \Article.publishedAt, order: .reverse)
        }
    }

    private func refreshCurrentScope() async {
        switch filter {
        case .feed(let feed):
            let _ = try? await FeedService.refresh(feed, context: context)
        default:
            await FeedService.refreshAll(context: context)
        }
    }
}
