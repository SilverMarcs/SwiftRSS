import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var context
    @Query private var articles: [Article]
    
    let filter: ArticleFilter
    let searchText: String
    let showingUnreadOnly: Bool
    @Binding var showingMarkAllReadAlert: Bool

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
        .confirmationDialog("Mark All as Read", isPresented: $showingMarkAllReadAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Mark All Read", role: .destructive) {
                markAllAsRead()
            }
        } message: {
            Text("Are you sure you want to mark all \(articles.count) articles as read?")
        }
        .onChange(of: showingMarkAllReadAlert) { _, newValue in
            if newValue {
                // Disable the button if all articles are read
                showingMarkAllReadAlert = !articles.allSatisfy { $0.isRead }
            }
        }
    }
    
    init(filter: ArticleFilter, searchText: String, showingUnreadOnly: Bool, showingMarkAllReadAlert: Binding<Bool>) {
        self.filter = filter
        self.searchText = searchText
        self.showingUnreadOnly = showingUnreadOnly
        self._showingMarkAllReadAlert = showingMarkAllReadAlert
        
        // Build compound predicate based on filter type and additional conditions
        let basePredicate = Self.buildBasePredicate(for: filter)
        let finalPredicate = Self.buildCompoundPredicate(
            basePredicate: basePredicate,
            searchText: searchText,
            showingUnreadOnly: showingUnreadOnly
        )
        
        _articles = Query(
            filter: finalPredicate,
            sort: [SortDescriptor(\Article.publishedAt, order: .reverse)],
            animation: .default
        )
    }
    
    // MARK: - Predicate Building
    
    private static func buildBasePredicate(for filter: ArticleFilter) -> Predicate<Article>? {
        switch filter {
        case .all:
            return nil // No base filter needed
        case .unread:
            return #Predicate<Article> { $0.isRead == false }
        case .starred:
            return #Predicate<Article> { $0.isStarred == true }
        case .feed(let feed):
            let feedID = feed.persistentModelID
            return #Predicate<Article> { article in
                article.feed.persistentModelID == feedID
            }
        case .today:
            let today = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: today)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return #Predicate<Article> { article in
                article.publishedAt >= startOfDay && article.publishedAt < endOfDay
            }
        }
    }
    
    private static func buildCompoundPredicate(
        basePredicate: Predicate<Article>?,
        searchText: String,
        showingUnreadOnly: Bool
    ) -> Predicate<Article>? {
        
        let hasSearchText = !searchText.isEmpty
        let hasUnreadFilter = showingUnreadOnly
        let hasBaseFilter = basePredicate != nil
        
        // If no filters at all, return nil
        if !hasSearchText && !hasUnreadFilter && !hasBaseFilter {
            return nil
        }
        
        // Build compound predicate based on what filters are active
        switch (hasBaseFilter, hasSearchText, hasUnreadFilter) {
        case (false, false, true):
            return #Predicate<Article> { $0.isRead == false }
            
        case (false, true, false):
            return #Predicate<Article> { article in
                article.title.localizedStandardContains(searchText)
            }
            
        case (false, true, true):
            return #Predicate<Article> { article in
                article.title.localizedStandardContains(searchText) &&
                article.isRead == false
            }
            
        case (true, false, false):
            return basePredicate
            
        case (true, false, true):
            return combinePredicates(basePredicate!, unreadOnly: true, searchText: nil)
            
        case (true, true, false):
            return combinePredicates(basePredicate!, unreadOnly: false, searchText: searchText)
            
        case (true, true, true):
            return combinePredicates(basePredicate!, unreadOnly: true, searchText: searchText)
            
        default:
            return basePredicate
        }
    }
    
    private static func combinePredicates(
        _ basePredicate: Predicate<Article>,
        unreadOnly: Bool,
        searchText: String?
    ) -> Predicate<Article> {
        
        if let searchText = searchText, !searchText.isEmpty {
            if unreadOnly {
                // Base + Search + Unread
                return #Predicate<Article> { article in
                    basePredicate.evaluate(article) &&
                    article.title.localizedStandardContains(searchText) &&
                    article.isRead == false
                }
            } else {
                // Base + Search
                return #Predicate<Article> { article in
                    basePredicate.evaluate(article) &&
                    article.title.localizedStandardContains(searchText)
                }
            }
        } else if unreadOnly {
            // Base + Unread
            return #Predicate<Article> { article in
                basePredicate.evaluate(article) &&
                article.isRead == false
            }
        }
        
        return basePredicate
    }
    
    // MARK: - Actions
    
    private func markAllAsRead() {
        context.autosaveEnabled = false
        for article in articles where !article.isRead {
            article.isRead = true
        }
        try? context.save()
        context.autosaveEnabled = true
    }
}
