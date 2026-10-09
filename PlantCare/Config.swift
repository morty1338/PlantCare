import Foundation

/// Configuration for the app.
///
/// The API key is not stored in code: it lives in `Config/Secrets.xcconfig` (listed in
/// `.gitignore`), goes into Info.plist at build time and is read from the bundle here.
/// Template: `Config/Secrets.example.xcconfig`.
enum Config {

    /// The Claude model used for recognition. Change here and only here.
    static let model = "claude-sonnet-5"

    /// Your Anthropic API key (starts with `sk-ant-...`), injected from `Secrets.xcconfig`.
    static let anthropicAPIKey: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "AnthropicAPIKey") as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    /// Upper bound on tokens in the model reply. Roomy enough that the JSON (with
    /// habitat, soil, placement, all possibly in Ukrainian) is never truncated.
    static let maxTokens = 2048

    /// Network timeout for a single request, in seconds. Generous, because a
    /// request may carry the plant photo plus several room photos.
    static let requestTimeout: TimeInterval = 120

    /// Whether a usable key has been provided.
    static var hasAPIKey: Bool {
        anthropicAPIKey.hasPrefix("sk-ant-")
    }
}
