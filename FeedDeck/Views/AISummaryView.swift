//
//  AISummaryView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI

struct AISummaryView: View {
    let instructions: String
    let prompt: String
    var navigationTitle: String = "AI Summary"

    @State private var model = AISummaryModel()

    var body: some View {
        NavigationStack {
            Group {
                if let errorMessage = model.errorMessage {
                    ContentUnavailableView(
                        "Unable to generate summary",
                        systemImage: "bolt.trianglebadge.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if model.isLoading && model.summary.isEmpty {
                    ProgressView("Generating summary…")
                } else {
                    ScrollView {
                        Text(LocalizedStringKey(model.summary))
                            .lineSpacing(3)
                            .scenePadding(.horizontal)
                            .scenePadding(.bottom)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
        }
        .task {
            await model.generate(instructions: instructions, prompt: prompt)
        }
    }
}
