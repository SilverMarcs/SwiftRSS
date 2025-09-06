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
        
        var descriptor: FetchDescriptor<Article>
        
        switch filter {
        case .all:
            descriptor = FetchDescriptor<Article>(
                sortBy: [SortDescriptor(\Article.publishedAt, order: .reverse)]
            )
            
        case .unread:
            descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { $0.isRead == false },
                sortBy: [SortDescriptor(\Article.publishedAt, order: .reverse)]
            )
            
        case .starred:
            descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { $0.isStarred == true },
                sortBy: [SortDescriptor(\Article.publishedAt, order: .reverse)]
            )
            
        case .feed(let feed):
            let feedID = feed.persistentModelID
            descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { article in
                    article.feed.persistentModelID == feedID
                },
                sortBy: [SortDescriptor(\Article.publishedAt, order: .reverse)]
            )
        }
        
        // Set the fetch limit to 100 for all cases
        descriptor.fetchLimit = 100
        
        _articles = Query(descriptor)
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
