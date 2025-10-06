//
//  AISummaryView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI
import FoundationModels

struct AISummaryView: View {
    let extractedText: String
    @State private var summary: String = ""

    var body: some View {
        NavigationStack {
            if summary.isEmpty {
                ProgressView("Generating summary...")
            } else {
                ScrollView {
                    Text(LocalizedStringKey(summary))
                        .lineSpacing(3)
                        .scenePadding(.horizontal)
                        .scenePadding(.bottom)
                }
                .navigationTitle("AI Summary")
                .toolbarTitleDisplayMode(.inline)
            }
        }
        .task {
            generateSummary()
        }
    }

    private func generateSummary() {
        Task {
            let session = LanguageModelSession()
            do {
                let stream = session.streamResponse(to: "Summarize this article concisely:\n\(extractedText)")
                for try await response in stream{
                    summary = response.content
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
