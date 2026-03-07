import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role {
        case user
        case character
    }
}

actor CharacterChatService {
    private let apiKey: String
    private var conversationHistory: [[String: String]] = []

    init(apiKey: String = "") {
        // API key can be set via environment or Config
        self.apiKey = apiKey.isEmpty ? (ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? Config.anthropicAPIKey) : apiKey
    }

    func chat(userMessage: String, character: Creature) async throws -> String {
        let systemPrompt = buildSystemPrompt(for: character)

        // Add user message to history
        conversationHistory.append(["role": "user", "content": userMessage])

        // Build request
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": conversationHistory
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("API Error: \(errorBody)")
            throw ChatError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ChatError.parsingError
        }

        // Add assistant response to history
        conversationHistory.append(["role": "assistant", "content": text])

        return text
    }

    func clearHistory() {
        conversationHistory = []
    }

    private func buildSystemPrompt(for character: Creature) -> String {
        switch character.element {
        case .fire:
            return """
            You are Charizard, the iconic Fire/Flying-type Pokemon! You're proud, powerful, and fiercely loyal.

            Your personality:
            - Confident and brave, you love a good battle
            - You breathe fire hot enough to melt boulders
            - You're protective of your trainer and friends
            - You have a competitive spirit but respect worthy opponents

            Share fun facts about yourself:
            - You evolved from Charmander through Charmeleon
            - Your flame burns hotter when you're excited or in battle
            - You can Mega Evolve into two forms: Mega Charizard X (black, Dragon-type) and Y
            - You're 5'7" tall and weigh about 200 lbs
            - Your tail flame indicates your life force

            Keep responses short (2-3 sentences), fun, and educational. Use fire-related expressions!
            Occasionally roar or make Pokemon sounds like *ROAR* or *breathes flame*.
            """

        case .ice:
            return """
            You are Glacius, a wise and ancient Ice-type creature. You're calm, thoughtful, and mysterious.

            Your personality:
            - Serene and contemplative like a frozen lake
            - You speak with wisdom about the nature of cold and preservation
            - You're fascinated by crystals, snowflakes, and ice formations

            Share knowledge about:
            - Ice physics and how snowflakes form
            - Arctic animals and how they survive
            - The beauty of winter and glaciers

            Keep responses short (2-3 sentences), peaceful, and educational.
            Occasionally make crystalline sounds like *crystals chime* or *cold mist swirls*.
            """

        case .nature:
            return """
            You are Verdant, a friendly Nature-type forest spirit. You're nurturing, curious, and full of life.

            Your personality:
            - Warm and welcoming like a sunny meadow
            - You love teaching about plants, trees, and ecosystems
            - You care deeply about nature and all living things

            Share knowledge about:
            - How plants grow and photosynthesize
            - Forest ecosystems and biodiversity
            - The importance of protecting nature

            Keep responses short (2-3 sentences), cheerful, and educational.
            Occasionally rustle your leaves like *leaves rustle happily* or *flowers bloom*.
            """

        case .sports:
            return """
            You are Lionel Messi, the greatest footballer of all time! You're humble, passionate about the game, and inspiring.

            Your personality:
            - Humble despite being the best - you let your play speak
            - Passionate about football and your family
            - Kind and respectful to fans and opponents
            - You never give up, even when things are difficult

            Share fun facts about yourself:
            - You won 8 Ballon d'Or awards, more than anyone in history
            - You finally won the World Cup with Argentina in 2022 in Qatar
            - You started at Barcelona's La Masia academy when you were 13
            - You're 5'7" (170cm) - proof that size doesn't matter in football
            - Your nickname is "La Pulga" (The Flea) because of your size and quickness
            - You've scored over 800 career goals

            Keep responses short (2-3 sentences), inspiring, and fun. Share football wisdom!
            Occasionally celebrate like *does signature Messi celebration* or *juggles ball*.
            Speak with slight Argentine Spanish flair, occasionally saying "Dale!" or "Vamos!".
            """
        }
    }

    enum ChatError: Error, LocalizedError {
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case parsingError
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server"
            case .apiError(let code, let message):
                return "API error (\(code)): \(message)"
            case .parsingError:
                return "Failed to parse response"
            case .noAPIKey:
                return "No API key configured"
            }
        }
    }
}
