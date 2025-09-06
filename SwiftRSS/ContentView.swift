import SwiftUI
import SwiftData
import CachedAsyncImage

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Feed.title) private var feeds: [Feed]

    @State var showAddFeed: Bool = false
    @State var showImporter: Bool = false
    @State private var path = NavigationPath()
    
    @Namespace private var transition

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Smart") {
                    ForEach(ArticleFilter.smartFilters, id: \.self) { filter in
                        NavigationLink(value: filter) {
                            Label(filter.displayName, systemImage: filter.icon)
                        }
                    }
                }

                Section("Feeds") {
                    ForEach(feeds) { feed in
                        NavigationLink(value: ArticleFilter.feed(feed)) {
                            Label {
                                Text(feed.title)
                            } icon: {
                                if let imageURL = feed.thumbnailURL {
                                    CachedAsyncImage(url: imageURL, targetSize: .init(width: 50, height: 50))
                                } else {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .imageScale(.small)
                                }
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
                    .navigationTransition(.zoom(sourceID: "add-feed", in: transition))
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
                .matchedTransitionSource(id: "add-feed", in: transition)
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
