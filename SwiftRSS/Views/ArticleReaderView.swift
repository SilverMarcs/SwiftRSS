//
//  ArticleReaderView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import Reeeed

struct ArticleReaderView: View {
    var article: Article
    
    var body: some View {
        ReeeederView(url: article.link)
            .onAppear {
                article.isRead = true
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        article.isRead.toggle()
                    } label: {
                        Label(article.isRead ? "Unread" : "Read", systemImage: article.isRead ? "largecircle.fill.circle" : "circle")
                    }
                    Button {
                        article.isStarred.toggle()
                    } label: {
                        Label(article.isStarred ? "Unstar" : "Star", systemImage: article.isStarred ? "star.fill" : "star")
                    }
                }
                
                ToolbarSpacer(.flexible, placement: .bottomBar)
                
                ToolbarItem(placement: .bottomBar) {
                    ShareLink(item: article.link)
                }
            }
    }
}
