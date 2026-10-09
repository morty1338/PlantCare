import SwiftUI

enum AppLanguage: String, CaseIterable {
    case en, uk
    /// Short label for the toggle.
    var label: String { self == .en ? "EN" : "UA" }
    /// Name used when instructing the model which language to answer in.
    var promptName: String { self == .en ? "English" : "Ukrainian" }
}

/// Holds the in-app language choice (independent of the system language) and a
/// tiny `t(en, uk)` helper used throughout the UI.
@MainActor
final class LanguageManager: ObservableObject {
    @Published var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key) }
    }

    private static let key = "app_language"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppLanguage.en.rawValue
        current = AppLanguage(rawValue: raw) ?? .en
    }

    func toggle() {
        current = (current == .en) ? .uk : .en
    }

    /// Pick the string for the current language.
    func t(_ en: String, _ uk: String) -> String {
        current == .uk ? uk : en
    }
}
