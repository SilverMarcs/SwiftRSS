import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SafariServices

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Feed.title) private var feeds: [Feed]

    @State var showAddFeed: Bool = false
    @State var showImporter: Bool = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Smart") {
                    NavigationLink(value: ArticleFilter.all) {
                        Label("All Articles", systemImage: "tray.full")
                    }
                    NavigationLink(value: ArticleFilter.unread) {
                        Label("Unread", systemImage: "circle.fill")
                    }
                    NavigationLink(value: ArticleFilter.starred) {
                        Label("Starred", systemImage: "star.fill")
                    }
                }

                Section("Feeds") {
                    ForEach(feeds) { feed in
                        NavigationLink(value: ArticleFilter.feed(feed)) {
                            Label {
                                Text(feed.title)
                            } icon: {
                                AsyncImage(url: feed.thumbnailURL)
                            }
                        }
                    }
                    .onDelete(perform: deleteFeeds)
                }
            }
            .navigationTitle("Feed")
            .navigationDestinations(path: $path)
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showAddFeed) {
                AddFeedSheet()
                    .presentationDetents([.medium])
            }
            .task {
                await FeedService.refreshAll(context: context)
            }
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showAddFeed = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    // MARK: - Delete Function
    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            let feedToDelete = feeds[index]
            context.delete(feedToDelete)
        }
    }
}
