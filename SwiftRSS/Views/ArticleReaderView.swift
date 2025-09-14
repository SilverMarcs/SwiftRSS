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
    @State var extractedText: String? = nil
    @State private var showAISheet = false
    
    @Namespace private var aiTransition
    
    var body: some View {
        ReeeederView(url: article.link) { text in
            extractedText = text
        }
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
                    #if !os(macOS)
                    .navigationTransition(.zoom(sourceID: "ai-button", in: aiTransition))
                    #endif
            }
        }

    }
}
