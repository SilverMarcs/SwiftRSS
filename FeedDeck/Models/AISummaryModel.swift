import Foundation
import FoundationModels
import Observation

@Observable
@MainActor
final class AISummaryModel {
    private(set) var summary = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func generate(instructions: String, prompt: String) async {
        guard !prompt.isEmpty else { return }
        isLoading = true
        summary = ""
        errorMessage = nil
        defer { isLoading = false }

        do {
            let key = try OpenAIAPIKeyStore.load()
            if key.isEmpty {
                try await generateWithAppleIntelligence(instructions: instructions, prompt: prompt)
            } else {
                try await OpenAISummaryService().streamSummary(
                    instructions: instructions,
                    prompt: prompt,
                    apiKey: key
                ) { delta in
                    summary.append(delta)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }

        if !Task.isCancelled, summary.isEmpty, errorMessage == nil {
            errorMessage = "No summary returned. Try again."
        }
    }

    private func generateWithAppleIntelligence(instructions: String, prompt: String) async throws {
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
            errorMessage = "Apple Intelligence is not available."
            return
        }

        let session = LanguageModelSession(instructions: instructions)
        for try await partial in session.streamResponse(to: prompt) {
            try Task.checkCancellation()
            summary = partial.content
        }
    }
}
