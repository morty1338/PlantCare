import Foundation

/// One saved home plant — a "pot" in the history screen.
///
/// Each pot carries a species name (from recognition), an optional custom name the
/// user can set, and a chronological list of readings (`entries`).
struct PlantRecord: Codable, Identifiable, Equatable {
    var id: UUID
    /// Name the user typed for this pot, if any. Overrides the species in the UI.
    var customName: String?
    /// Species / plant name as identified by the model.
    var speciesName: String
    /// Optional thumbnail of the most recent photo (JPEG, or transparent PNG cut-out).
    var thumbnailData: Data?
    /// Whether `thumbnailData` is a transparent subject cut-out (vs a raw photo).
    var thumbnailIsCutout: Bool?
    /// Readings over time, oldest first.
    var entries: [PlantEntry]

    init(id: UUID = UUID(),
         customName: String? = nil,
         speciesName: String,
         thumbnailData: Data? = nil,
         thumbnailIsCutout: Bool? = nil,
         entries: [PlantEntry] = []) {
        self.id = id
        self.customName = customName
        self.speciesName = speciesName
        self.thumbnailData = thumbnailData
        self.thumbnailIsCutout = thumbnailIsCutout
        self.entries = entries
    }

    /// The longest single word in the display name — used to decide if it fits a pot.
    var longestWordLength: Int {
        displayName.split(separator: " ").map(\.count).max() ?? displayName.count
    }

    /// The name shown to the user: the custom name if set, otherwise the species.
    var displayName: String {
        if let customName, !customName.trimmingCharacters(in: .whitespaces).isEmpty {
            return customName
        }
        return speciesName
    }

    /// The most recent reading, if any.
    var latestEntry: PlantEntry? {
        entries.max(by: { $0.date < $1.date })
    }
}

/// A single reading taken on a given day.
struct PlantEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    /// 1–10 health score, if it could be determined.
    var conditionScore: Int?
    var soilCondition: String?
    /// Whether the condition could be determined for this reading.
    var conditionDetermined: Bool
    /// Pointed, situation-specific recommendations.
    var recommendations: [String]
    /// Generic care tips for this kind of plant.
    var generalCare: [String]
    // Full first-request info, kept so it can be reopened without a new request.
    var wildHabitat: String?
    var soilType: String?
    var homePlacement: String?
    var message: String?

    init(id: UUID = UUID(),
         date: Date = Date(),
         conditionScore: Int?,
         soilCondition: String?,
         conditionDetermined: Bool,
         recommendations: [String],
         generalCare: [String],
         wildHabitat: String? = nil,
         soilType: String? = nil,
         homePlacement: String? = nil,
         message: String? = nil) {
        self.id = id
        self.date = date
        self.conditionScore = conditionScore
        self.soilCondition = soilCondition
        self.conditionDetermined = conditionDetermined
        self.recommendations = recommendations
        self.generalCare = generalCare
        self.wildHabitat = wildHabitat
        self.soilType = soilType
        self.homePlacement = homePlacement
        self.message = message
    }

    init(from analysis: PlantAnalysis, date: Date = Date()) {
        self.init(date: date,
                  conditionScore: analysis.conditionScore,
                  soilCondition: analysis.soilCondition,
                  conditionDetermined: analysis.conditionDetermined,
                  recommendations: analysis.recommendations,
                  generalCare: analysis.generalCare,
                  wildHabitat: analysis.wildHabitat,
                  soilType: analysis.soilType,
                  homePlacement: analysis.homePlacement,
                  message: analysis.message)
    }

    /// Rebuild an analysis object from this stored reading (for the full-info view).
    func asAnalysis(plantName: String) -> PlantAnalysis {
        PlantAnalysis(identified: true,
                      plantName: plantName,
                      soilCondition: soilCondition,
                      conditionScore: conditionScore,
                      conditionDetermined: conditionDetermined,
                      recommendations: recommendations,
                      generalCare: generalCare,
                      wildHabitat: wildHabitat,
                      soilType: soilType,
                      needsClarification: false,
                      clarificationPrompt: nil,
                      homePlacement: homePlacement,
                      message: message)
    }
}
