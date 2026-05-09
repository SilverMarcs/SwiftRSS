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
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("Generating summary…")
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to generate summary",
                    systemImage: "bolt.trianglebadge.exclamationmark",
                    description: Text(errorMessage)
                )
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
            await generateSummary()
        }
    }

    private func generateSummary() async {
        guard !extractedText.isEmpty else { return }

        let model = SystemLanguageModel.default

        switch model.availability {
        case .unavailable(.deviceNotEligible):
            errorMessage = "This device does not support Apple Intelligence."
            return
        case .unavailable(.appleIntelligenceNotEnabled):
            errorMessage = "Please enable Apple Intelligence in Settings to use AI Summary."
            return
        case .unavailable(.modelNotReady):
            errorMessage = "Apple Intelligence model is still downloading. Please try again later."
            return
        case .unavailable:
            errorMessage = "Apple Intelligence is not available."
            return
        case .available:
            break
        @unknown default:
            break
        }

        isLoading = true
        summary = ""
        errorMessage = nil

        do {
            let session = LanguageModelSession(
                instructions: "You are a helpful assistant that creates concise summaries of articles."
            )

            let stream = session.streamResponse(to: "Summarize this article concisely:\n\(extractedText)")

            for try await partial in stream {
                isLoading = false
                summary = partial.content
            }
        } catch {
            errorMessage = "Error generating summary: \(error.localizedDescription)"
        }

        if summary.isEmpty, errorMessage == nil {
            errorMessage = "No summary returned. Try again."
        }
    }
}
