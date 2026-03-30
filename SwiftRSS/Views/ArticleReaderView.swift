//
//  ArticleReaderView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData
import SwiftMediaViewer

struct ArticleReaderView: View {
    @Environment(\.modelContext) private var modelContext

    let article: Article

    var body: some View {
        if let link = article.link {
            ReederSpecificView(url: link)
                .onAppear {
                    article.isRead = true
                }
                .toolbar {
                    ToolbarItemGroup(placement: .platformBar) {
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
                }
        }
    }
}
