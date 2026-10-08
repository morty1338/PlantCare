import Foundation

/// Configuration for the app.
///
/// This file is listed in `.gitignore` and is NOT committed to the repository.
/// Paste your Anthropic API key into `anthropicAPIKey` below.
enum Config {

    /// The Claude model used for recognition. Change here and only here.
    static let model = "claude-sonnet-5"

    /// Your Anthropic API key (starts with `sk-ant-...`).
    static let anthropicAPIKey = "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"

    /// Upper bound on tokens in the model reply. Roomy enough that the JSON (with
    /// habitat, soil, placement, all possibly in Ukrainian) is never truncated.
    static let maxTokens = 2048

    /// Network timeout for a single request, in seconds. Generous, because a
    /// request may carry the plant photo plus several room photos.
    static let requestTimeout: TimeInterval = 120

    /// Whether a usable key has been provided.
    static var hasAPIKey: Bool {
        !anthropicAPIKey.isEmpty && anthropicAPIKey != "PASTE_YOUR_ANTHROPIC_API_KEY_HERE"
    }
}
