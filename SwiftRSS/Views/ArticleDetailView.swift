import SwiftUI
import SwiftData

struct ArticleDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(article.title).font(.title2).bold()
                HStack {
                    Text(article.feed.title)
                    if let date = article.publishedAt { Text("· \(date.formatted())") }
                }
                .font(.subheadline).foregroundStyle(.secondary)

                if let summary = article.summary {
                    Text(summary)
                }

                if let html = article.contentHTML {
                    // Minimal rendering; for production, consider WKWebView
                    Text(html).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            if !article.isRead {
                article.isRead = true
                try? context.save()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    article.isStarred.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: article.isStarred ? "star.fill" : "star")
                }
                Button {
                    article.isRead = true
                    try? context.save()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                if let url = article.link as URL? {
                    ShareLink(item: url)
                    
                    Button {
                        openURL(url, prefersInApp: true)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
    }
}
