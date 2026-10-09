import SwiftUI

/// Drives the clarification chat: keeps the running conversation and talks to the API.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isSending = false
    @Published var errorText: String?

    private var plantName: String
    private var summary: String
    private var originalImage: UIImage?
    private var language: String = "English"
    private let service = AnthropicService()

    init(plantName: String, summary: String, originalImage: UIImage?, firstQuestion: String?) {
        self.plantName = plantName
        self.summary = summary
        self.originalImage = originalImage
        if firstQuestion != nil || !plantName.isEmpty {
            start(plantName: plantName, summary: summary, originalImage: originalImage,
                  firstQuestion: firstQuestion, opener: nil, language: "English")
        }
    }

    /// (Re)configure the conversation with fresh context and an opening question.
    func start(plantName: String, summary: String, originalImage: UIImage?,
               firstQuestion: String?, opener: String? = nil, language: String = "English") {
        self.plantName = plantName
        self.summary = summary
        self.originalImage = originalImage
        self.language = language
        let text = (firstQuestion?.isEmpty == false) ? firstQuestion!
            : (opener ?? "Ask me anything about caring for your \(plantName.isEmpty ? "plant" : plantName), or add a photo.")
        messages = [ChatMessage(role: .assistant, text: text)]
        isSending = false
        errorText = nil
    }

    func send(text: String, image: UIImage?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil, !isSending else { return }

        messages.append(ChatMessage(role: .user, text: trimmed, image: image))
        isSending = true
        errorText = nil

        let history = messages
        Task {
            do {
                let reply = try await service.chat(plantName: plantName,
                                                   summary: summary,
                                                   originalImage: originalImage,
                                                   history: history,
                                                   language: language)
                messages.append(ChatMessage(role: .assistant, text: reply))
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSending = false
        }
    }
}
