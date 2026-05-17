//
//  AISummaryView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI
import FoundationModels

struct AISummaryView: View {
    let instructions: String
    let prompt: String
    var navigationTitle: String = "AI Summary"

    @AppStorage("geminiApiKey") private var geminiApiKey = ""

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
                .navigationTitle(navigationTitle)
                .toolbarTitleDisplayMode(.inline)
            }
        }
        .task {
            await generateSummary()
        }
    }

    private func generateSummary() async {
        guard !prompt.isEmpty else { return }

        if !geminiApiKey.isEmpty {
            await generateWithGemini()
        } else {
            await generateWithAppleIntelligence()
        }
    }

    private func generateWithAppleIntelligence() async {
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
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: prompt)

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

    private func generateWithGemini() async {
        isLoading = true
        summary = ""
        errorMessage = nil

        struct ChatRequest: Encodable {
            struct Message: Encodable {
                let role: String
                let content: String
            }
            let model: String
            let messages: [Message]
            let stream: Bool
        }

        struct StreamChunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable { let content: String? }
                let delta: Delta
                let finish_reason: String?
            }
            let choices: [Choice]
        }

        let requestBody = ChatRequest(
            model: "gemini-flash-latest",
            messages: [
                .init(role: "system", content: instructions),
                .init(role: "user", content: prompt)
            ],
            stream: true
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions") else {
            errorMessage = "Invalid API endpoint."
            isLoading = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(geminiApiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                errorMessage = "Failed to generate summary. Check your API key or model name."
                isLoading = false
                return
            }

            for try await line in bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if trimmed == "data: [DONE]" || trimmed == "[DONE]" { break }

                let jsonPart = trimmed.hasPrefix("data: ")
                    ? String(trimmed.dropFirst("data: ".count))
                    : trimmed
                guard let chunkData = jsonPart.data(using: .utf8) else { continue }

                if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: chunkData) {
                    let deltaText = chunk.choices.compactMap { $0.delta.content }.joined()
                    if !deltaText.isEmpty {
                        isLoading = false
                        summary.append(deltaText)
                    }
                }
            }
        } catch {
            errorMessage = "Error generating summary: \(error.localizedDescription)"
        }

        isLoading = false
        if summary.isEmpty, errorMessage == nil {
            errorMessage = "No summary returned. Try again."
        }
    }
}
