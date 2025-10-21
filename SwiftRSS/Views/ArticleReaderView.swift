//
//  ArticleReaderView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import Reeeed
import SwiftMediaViewer
import Observation

struct ArticleReaderView: View {
    var articleID: String
    @Environment(FeedStore.self) private var store
    
    private var article: Article? {
        store.articles.first { $0.id == articleID }
    }
    
    @Namespace private var aiTransition
    
    var body: some View {
        if let article = article {
            ReederSpecificView(url: article.link)
                .onAppear {
//                    store.setRead(articleID: articleID, true)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .platformBar) {
                        Button {
//                            store.toggleRead(articleID: articleID)
                        } label: {
                            Label(article.isRead ? "Unread" : "Read", systemImage: article.isRead ? "largecircle.fill.circle" : "circle")
                        }
                        Button {
//                            store.toggleStar(articleID: articleID)
                        } label: {
                            Label(article.isStarred ? "Unstar" : "Star", systemImage: article.isStarred ? "star.fill" : "star")
                        }
                    }
                }
        }
    }
}
