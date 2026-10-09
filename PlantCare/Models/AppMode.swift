import Foundation

/// Which flow the user chose before taking a photo.
enum AppMode: String, Codable, CaseIterable, Identifiable {
    /// Home plants — the reading is saved to local history and shown in statistics.
    case home
    /// One-off — nothing is saved, the plant is not added to history.
    case oneTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:    return "Home plants"
        case .oneTime: return "One-time"
        }
    }

    var subtitle: String {
        switch self {
        case .home:    return "History & stats are saved"
        case .oneTime: return "Nothing is saved"
        }
    }
}
