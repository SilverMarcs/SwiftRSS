//
//  AISummaryView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI

struct AISummaryView: View {
    let extractedText: String
    @AppStorage("geminiApiKey") private var apiKey = ""
    @State private var summary: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("Generating summary...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
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
            if !apiKey.isEmpty {
                generateSummary()
            } else {
                errorMessage = "API key not set in settings"
            }
        }
    }

    private func generateSummary() {
        isLoading = true
        errorMessage = nil

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Summarize this article concisely:\n\(extractedText)"]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            errorMessage = "Failed to encode request"
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        summary = text
                    } else {
                        errorMessage = "Failed to parse response"
                    }
                } catch {
                    errorMessage = "Failed to decode response"
                }
            }
        }.resume()
    }
}
