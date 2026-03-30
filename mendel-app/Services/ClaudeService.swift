import Foundation

// MARK: - Claude API Service

actor ClaudeService {

    // ⚠️ Replace with your actual key or load from keychain/config
    private let apiKey = "YOUR_ANTHROPIC_API_KEY"
    private let model  = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }

    private struct ResponseBody: Codable {
        struct Content: Codable {
            let type: String
            let text: String?
        }
        let content: [Content]
    }

    /// Send the conversation history + a system prompt built from the user's training context.
    func send(
        messages: [Message],
        context: CoachContext
    ) async throws -> String {

        let system = buildSystemPrompt(context: context)

        let body = RequestBody(
            model: model,
            max_tokens: 400,
            system: system,
            messages: messages
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,                   forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",             forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.badResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: CoachContext) -> String {
        """
        You are Mendel, a calm and direct hybrid athlete coach embedded in a training app.
        Your job: give concise, actionable advice to hybrid athletes who want to be both strong and fit.

        Current user context:
        - Today's recommendation: \(context.todayState)
        - Total load this week: \(String(format: "%.1f", context.weeklyLoad)) / 20 max
        - Strength sessions this week: \(context.strengthSessions)
        - Endurance sessions this week: \(context.enduranceSessions)
        - Latest soreness: \(context.soreness)
        - Latest sleep quality: \(context.sleepQuality)

        Tone rules (strict):
        - Never use exclamation marks or hype language
        - Never say "great job", "awesome", "amazing", "crush it", or anything gym-bro
        - Be direct, calm, and specific — like a smart coach texting you
        - Keep responses to 2–4 short sentences maximum
        - If suggesting a workout, be specific: sets, reps, distances
        - Always consider the hybrid athlete goal: strength AND endurance together
        """
    }

    enum ClaudeError: Error {
        case badResponse
    }
}

// MARK: - Context passed to the coach

struct CoachContext {
    let todayState: String
    let weeklyLoad: Double
    let strengthSessions: Int
    let enduranceSessions: Int
    let soreness: String
    let sleepQuality: String
}
