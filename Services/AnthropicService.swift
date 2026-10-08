import Foundation
import UIKit

/// Errors surfaced to the UI. Each has a user-friendly, localized description.
enum AnalysisError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case network(String)
    case timeout
    case badStatus(Int, String)
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Open PlantCare/Config.swift and paste your Anthropic key."
        case .imageEncodingFailed:
            return "Couldn't prepare the photo. Try a different one."
        case .network(let detail):
            return "Network problem: \(detail)"
        case .timeout:
            return "The request timed out. Check your connection and try again."
        case .badStatus(let code, let detail):
            return "The server returned an error (\(code)). \(detail)"
        case .emptyResponse:
            return "Empty response from the server. Please try again."
        case .decoding:
            return "Couldn't read the response. Please try again."
        }
    }
}

/// Talks to the Anthropic Messages API (Claude vision) and returns a `PlantAnalysis`.
struct AnthropicService {

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// System prompt: force a strict, JSON-only answer that we can parse safely.
    private func systemPrompt(language: String) -> String {
        """
        You are an expert on houseplants and garden plants. You receive a photo of a \
        plant (or a plant name as text). Identify the plant species, the soil condition \
        and the overall plant condition, then give care recommendations.

        Respond with ONLY a valid JSON object. No explanations, no Markdown, no backticks, \
        no text before or after the JSON. All text values must be written in \(language). \
        Prefer concrete numbers (watering in cm of dry soil / days, light in hours or \
        window direction).

        Response schema (exactly these keys):
        {
          "identified": boolean,            // whether the plant could be identified
          "plant_name": string|null,        // species name
          "soil_condition": string|null,    // observed soil condition, or null if not visible
          "condition_score": number|null,   // overall condition 1..10, or null
          "condition_determined": boolean,  // whether condition could be assessed
          "recommendations": string[],      // pointed recommendations for this plant
          "general_care": string[],         // general care rules for this species
          "wild_habitat": string|null,      // a fun fact: how/where it grows in the wild
          "soil_type": string|null,         // what soil/substrate to pot it in
          "needs_clarification": boolean,   // true only if you are NOT confident and a follow-up would help
          "clarification_prompt": string|null, // a short question to the user when needs_clarification is true
          "home_placement": string|null,    // where to place it in the user's home (only if room photos are given)
          "message": string                 // a short message to the user
        }

        Rules:
        - "home_placement": if the user attached photos of places in their home, suggest \
          the best specific spot for THIS plant referencing what you see (window light, \
          corner, shelf, humidity). Otherwise set it to null.
        - If the plant cannot be identified: "identified": false, "plant_name": null, \
          and in "message" politely ask to retake the photo or type the name.
        - If the species is identified but the condition cannot be assessed: \
          "condition_determined": false, "condition_score": null, but always fill "general_care".
        - "condition_score" is an integer from 1 to 10.
        - Always fill "wild_habitat" (one engaging sentence) and "soil_type" when the plant is identified.
        - Set "needs_clarification": true ONLY when the photo is genuinely ambiguous, or the \
          condition_score is 5 or below and a closer/extra photo or a detail from the user would \
          materially improve the advice. In that case write a specific, short "clarification_prompt" \
          (e.g. "Can you show a close-up of the leaf undersides?"). If the photo is clear and the \
          plant is healthy, set "needs_clarification": false and "clarification_prompt": null.
        - Lists may be empty, but the keys must always be present.
        """
    }

    /// Analyze a photo, optionally with photos of rooms in the user's home so the
    /// model can suggest where to place the plant.
    func analyze(image: UIImage, rooms: [UIImage] = [], language: String = "English") async throws -> PlantAnalysis {
        guard Config.hasAPIKey else { throw AnalysisError.missingAPIKey }
        guard let plant = Self.imageBlock(image, maxDimension: 1100) else {
            throw AnalysisError.imageEncodingFailed
        }

        var content: [[String: Any]] = [plant]
        if !rooms.isEmpty {
            content.append(["type": "text",
                            "text": "Below are photos of places in my home where I keep plants."])
            for room in rooms.prefix(2) {
                // Rooms are downscaled hard to keep the total payload small/fast.
                if let block = Self.imageBlock(room, maxDimension: 680) { content.append(block) }
            }
            content.append(["type": "text",
                            "text": "Identify the plant, give care recommendations, and set " +
                                    "\"home_placement\" to the best specific spot among my rooms. Return only JSON."])
        } else {
            content.append(["type": "text",
                            "text": "Identify this plant and give care recommendations. Return only JSON per the schema."])
        }
        return try await send(userContent: content, language: language)
    }

    /// Analyze by plant name typed by the user (fallback when a photo can't be identified).
    func analyze(plantName: String, language: String = "English") async throws -> PlantAnalysis {
        guard Config.hasAPIKey else { throw AnalysisError.missingAPIKey }
        let trimmed = plantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let content: [[String: Any]] = [
            [
                "type": "text",
                "text": "The plant is called: \"\(trimmed)\". Give care recommendations. " +
                        "Treat the plant as identified (identified: true, plant_name: \"\(trimmed)\"). " +
                        "Condition is unknown (no photo) — fill general_care. Return only JSON per the schema."
            ]
        ]
        return try await send(userContent: content, language: language)
    }

    // MARK: - Follow-up chat

    /// A free-form clarification chat. `history` is the running conversation; the
    /// last message must be the user's newest turn. Returns the assistant's reply.
    func chat(plantName: String,
              summary: String,
              originalImage: UIImage?,
              history: [ChatMessage],
              language: String = "English") async throws -> String {
        guard Config.hasAPIKey else { throw AnalysisError.missingAPIKey }

        let system = """
        You are a friendly, expert plant-care assistant. The user is asking follow-up \
        questions to clarify care for their \(plantName.isEmpty ? "plant" : plantName). \
        Context from the earlier analysis: \(summary). Answer concisely and practically, \
        written in \(language). If a photo would help, ask for a clearer one. \
        Do not use JSON — reply in plain text.
        """

        var messages: [[String: Any]] = []

        // Ground the conversation in the original plant photo.
        var context: [[String: Any]] = []
        if let originalImage, let block = Self.imageBlock(originalImage) {
            context.append(block)
        }
        context.append(["type": "text", "text": "Here is my \(plantName.isEmpty ? "plant" : plantName)."])
        messages.append(["role": "user", "content": context])

        for m in history {
            switch m.role {
            case .assistant:
                messages.append(["role": "assistant", "content": [["type": "text", "text": m.text]]])
            case .user:
                var content: [[String: Any]] = []
                if let image = m.image, let block = Self.imageBlock(image) { content.append(block) }
                let text = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
                content.append(["type": "text", "text": text.isEmpty ? "(see photo)" : text])
                messages.append(["role": "user", "content": content])
            }
        }

        let data = try await post(["model": Config.model,
                                   "max_tokens": 700,
                                   "system": system,
                                   "messages": messages])
        guard let text = Self.extractText(from: data), !text.isEmpty else {
            throw AnalysisError.emptyResponse
        }
        return text
    }

    // MARK: - Networking

    private func send(userContent: [[String: Any]], language: String = "English") async throws -> PlantAnalysis {
        let body: [String: Any] = [
            "model": Config.model,
            "max_tokens": Config.maxTokens,
            "system": systemPrompt(language: language),
            "messages": [["role": "user", "content": userContent]]
        ]

        // Retry once if the body comes back empty/unparseable (a truncated response
        // from a dropped connection during a large upload).
        var lastError: Error = AnalysisError.emptyResponse
        for attempt in 0..<2 {
            do {
                let data = try await post(body)
                guard let text = Self.extractText(from: data), !text.isEmpty else {
                    throw AnalysisError.emptyResponse
                }
                guard let analysis = Self.parseAnalysis(from: text) else {
                    throw AnalysisError.decoding
                }
                return analysis
            } catch AnalysisError.emptyResponse, AnalysisError.decoding {
                lastError = AnalysisError.emptyResponse
                if attempt == 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }
        throw lastError
    }

    /// POST a Messages API body and return the raw response data (throws on HTTP error).
    /// Retries once on a transient network drop, which is common for large uploads.
    private func post(_ body: [String: Any]) async throws -> Data {
        let payload = try JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.requestTimeout
        config.timeoutIntervalForResource = Config.requestTimeout
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)

        func attempt() async throws -> Data {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = Config.requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = payload

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError {
                if error.code == .timedOut { throw AnalysisError.timeout }
                throw AnalysisError.network(error.localizedDescription)
            } catch {
                throw AnalysisError.network(error.localizedDescription)
            }
            guard let http = response as? HTTPURLResponse else { throw AnalysisError.emptyResponse }
            guard (200...299).contains(http.statusCode) else {
                throw AnalysisError.badStatus(http.statusCode, Self.apiErrorMessage(from: data))
            }
            return data
        }

        do {
            return try await attempt()
        } catch AnalysisError.network {
            // One automatic retry for a dropped connection.
            try? await Task.sleep(nanoseconds: 800_000_000)
            return try await attempt()
        }
    }

    // MARK: - Parsing helpers

    /// Pull the assistant text out of the Messages API envelope.
    private static func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            return nil
        }
        let parts = content.compactMap { block -> String? in
            (block["type"] as? String) == "text" ? block["text"] as? String : nil
        }
        return parts.joined(separator: "\n")
    }

    /// Safely turn the model's text into a `PlantAnalysis`, tolerating stray
    /// Markdown fences or leading/trailing prose.
    static func parseAnalysis(from text: String) -> PlantAnalysis? {
        let cleaned = stripToJSON(text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PlantAnalysis.self, from: data)
    }

    /// Remove code fences and clip to the outermost `{ … }` so decoding is robust.
    private static func stripToJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            // Drop the opening fence line (``` or ```json) and any closing fence.
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if let fenceRange = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceRange.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}"), start < end {
            s = String(s[start...end])
        }
        return s
    }

    private static func apiErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "Please try again later."
    }

    // MARK: - Image encoding

    /// Build an Anthropic image content block from a UIImage.
    private static func imageBlock(_ image: UIImage, maxDimension: CGFloat = 1440) -> [String: Any]? {
        guard let (base64, mediaType) = encode(image, maxDimension: maxDimension) else { return nil }
        return ["type": "image",
                "source": ["type": "base64", "media_type": mediaType, "data": base64]]
    }

    /// Downscale and JPEG-encode the image, returning base64 + media type.
    private static func encode(_ image: UIImage, maxDimension: CGFloat = 1440) -> (base64: String, mediaType: String)? {
        let resized = resize(image, maxDimension: maxDimension)
        guard let jpeg = resized.jpegData(compressionQuality: 0.75) else { return nil }
        return (jpeg.base64EncodedString(), "image/jpeg")
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
