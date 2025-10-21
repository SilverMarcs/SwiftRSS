//
//  ReederSpecifivView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 21/10/2025.
//

import SwiftUI
import SwiftMediaViewer
import Reeeed

struct ReederSpecificView: View {
    let url: URL
    
    @State var extractedText: String? = nil
    @State private var showAISheet = false
    
    @Namespace private var aiTransition
    
    var body: some View {
        ReeeederView(url: url) { text in
            extractedText = text
        } imageRenderer: { url in
            SMVImage(url: url.absoluteString, targetSize: 400)
        }
        .toolbar {
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
                ShareLink(item: url)
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
    }
}
