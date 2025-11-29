//
//  AISummaryView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/09/2025.
//

import SwiftUI

struct AISummaryView: View {
    let extractedText: String
    
    // Change this key name if you want to reuse the same setting as before
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    
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
        guard !geminiApiKey.isEmpty else {
            errorMessage = "API key not set in Settings."
            return
        }
        
        isLoading = true
        summary = ""
        errorMessage = nil
        
        // MARK: - OpenAI Request / Response DTOs
        
        struct OpenAIChatRequest: Encodable {
            struct Message: Encodable {
                let role: String
                let content: String
            }
            
            let model: String
            let messages: [Message]
            let stream: Bool
        }
        
        struct OpenAIStreamChunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable {
                    let content: String?
                }
                let delta: Delta
                let finish_reason: String?
            }
            
            let id: String
            let object: String
            let created: Int
            let model: String
            let choices: [Choice]
        }
        
        // MARK: - Build Request Body
        
        let userPrompt = "Summarize this article concisely:\n\(extractedText)"
        
        let requestBody = OpenAIChatRequest(
            model: "gemini-2.5-flash",  // or another supported model
            messages: [
                .init(role: "system", content: "You are a helpful assistant that creates concise summaries of articles."),
                .init(role: "user", content: userPrompt)
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
            
            // OpenAI streaming uses "data: {json}" lines (SSE-like).
            // URLSession.AsyncBytes.lines gives each line; we strip "data: " then decode.
            for try await line in bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                // Stop on [DONE]
                if trimmed == "data: [DONE]" || trimmed == "[DONE]" {
                    break
                }
                
                let jsonPart: String
                if trimmed.hasPrefix("data: ") {
                    jsonPart = String(trimmed.dropFirst("data: ".count))
                } else {
                    jsonPart = trimmed
                }
                
                guard let chunkData = jsonPart.data(using: .utf8) else { continue }
                
                // Decode each streaming chunk
                if let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: chunkData) {
                    let deltaText = chunk.choices
                        .compactMap { $0.delta.content }
                        .joined()
                    
                    if !deltaText.isEmpty {
                        isLoading = false
                        summary.append(deltaText)
                    }
                }
            }
        } catch {
            errorMessage = "Error generating summary: \(error.localizedDescription)"
        }
        
        if summary.isEmpty, errorMessage == nil {
            errorMessage = "No summary returned. Try again."
        }
    }
}
