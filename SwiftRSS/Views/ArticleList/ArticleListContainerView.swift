//
//  ArticleListContainerView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI
import SwiftData

struct ArticleListContainerView: View {
    @Environment(\.modelContext) private var context
    
    let filter: ArticleFilter
    
    @State private var searchText: String = ""
    @State private var showingUnreadOnly: Bool = false

    var body: some View {
        ArticleListView(
            filter: filter,
            searchText: searchText,
            showingUnreadOnly: showingUnreadOnly
        )
        .navigationTitle(filter.displayName)
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search Articles")
        .refreshable {
            await refreshCurrentScope()
        }
        .toolbar {
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
            
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            
            ToolbarSpacer(.fixed, placement: .bottomBar)
        }
    }
    
    private func refreshCurrentScope() async {
        switch filter {
        case .feed(let feed):
            let _ = try? await FeedService.refresh(feed, context: context)
        case .starred:
            print("Doesnt make sense to refresh")
        default:
            await FeedService.refreshAll(context: context)
        }
    }
}
