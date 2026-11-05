import Foundation

@MainActor
struct OpenAISummaryService {
    func streamSummary(
        instructions: String,
        prompt: String,
        apiKey: String,
        onDelta: (String) -> Void
    ) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw Failure("Invalid OpenAI endpoint.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Request(instructions: instructions, input: prompt))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw Failure("OpenAI returned an invalid response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            switch response.statusCode {
            case 401:
                throw Failure("Check your OpenAI API key in Settings.")
            case 429:
                throw Failure("OpenAI usage limit reached. Check your quota or try again later.")
            default:
                throw Failure("OpenAI request failed (\(response.statusCode)). Please try again.")
            }
        }

        var receivedText = false
        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let event = try decoder.decode(Event.self, from: Data(line.dropFirst(5).utf8))

            switch event.type {
            case "response.output_text.delta":
                if let delta = event.delta, !delta.isEmpty {
                    receivedText = true
                    onDelta(delta)
                }
            case "response.completed":
                guard receivedText else { throw Failure("No summary returned. Try again.") }
                return
            case "response.failed", "error":
                throw Failure(event.response?.error?.message ?? event.message ?? "OpenAI could not generate a summary.")
            case "response.incomplete":
                throw Failure("The summary was cut short. Please try again.")
            case "response.refusal.delta":
                throw Failure("OpenAI could not summarize this content.")
            default:
                continue
            }
        }
        try Task.checkCancellation()
        throw Failure("The connection ended before the summary finished. Please try again.")
    }

    private struct Request: Encodable {
        let model = "gpt-6-luna"
        let instructions: String
        let input: String
        let stream = true
        let store = false
        let reasoning = ["effort": "none"]
    }

    private struct Event: Decodable {
        let type: String
        let delta: String?
        let message: String?
        let response: Response?

        struct Response: Decodable {
            let error: APIError?
        }

        struct APIError: Decodable {
            let message: String
        }
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?

        init(_ message: String) {
            errorDescription = message
        }
    }
}
