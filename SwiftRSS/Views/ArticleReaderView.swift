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
    
    @State var extractedText: String? = nil
    @State private var showAISheet = false
    
    @Namespace private var aiTransition
    
    var body: some View {
        if let article = article {
            ReeeederView(url: article.link) { text in
                extractedText = text
            } imageRenderer: { url in
                SMVImage(url: url.absoluteString, targetSize: 400)
            }
            .environment(\.openURL, OpenURLAction { url in
                return .systemAction(prefersInApp: true)
            })
            .onAppear { store.setRead(articleID: articleID, true) }
            .toolbar {
                ToolbarItemGroup(placement: .platformBar) {
                    Button {
                        store.toggleRead(articleID: articleID)
                    } label: {
                        Label(article.isRead(in: store) ? "Unread" : "Read", systemImage: article.isRead(in: store) ? "largecircle.fill.circle" : "circle")
                    }
                    Button {
                        store.toggleStar(articleID: articleID)
                    } label: {
                        Label(article.isStarred(in: store) ? "Unstar" : "Star", systemImage: article.isStarred(in: store) ? "star.fill" : "star")
                    }
                }
                
                ToolbarSpacer(.flexible, placement: .platformBar)
                
                ToolbarItem(placement: .platformBar) {
                    Button {
                        showAISheet = true
                    } label: {
                        Label("AI Summary", systemImage: "sparkles")
                    }
                    .disabled(extractedText == nil)
                }
                #if !os(macOS)
                .matchedTransitionSource(id: "ai-button", in: aiTransition)
                #endif
                
                ToolbarItem(placement: .platformBar) {
                    ShareLink(item: article.link)
                }
            }
            .sheet(isPresented: $showAISheet) {
                if let text = extractedText {
                    AISummaryView(extractedText: text)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                        #if !os(macOS)
                        .navigationTransition(.zoom(sourceID: "ai-button", in: aiTransition))
                        #endif
                }
            }
        } else {
            Text("Article not found")
        }
    }
}
