import Foundation

/// The structured result returned by Claude for a single photo (or a text query).
struct PlantAnalysis: Codable, Equatable {
    let identified: Bool
    let plantName: String?
    let soilCondition: String?
    let conditionScore: Int?
    let conditionDetermined: Bool
    let recommendations: [String]
    let generalCare: [String]
    /// A fun fact about how / where the plant grows in the wild.
    let wildHabitat: String?
    /// What soil / substrate the plant should be potted in.
    let soilType: String?
    /// Whether the model wants the user to clarify or add another photo.
    let needsClarification: Bool
    /// A short question shown when clarification is needed.
    let clarificationPrompt: String?
    /// Where to place the plant in the user's home (only when room photos were given).
    let homePlacement: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case identified
        case plantName = "plant_name"
        case soilCondition = "soil_condition"
        case conditionScore = "condition_score"
        case conditionDetermined = "condition_determined"
        case recommendations
        case generalCare = "general_care"
        case wildHabitat = "wild_habitat"
        case soilType = "soil_type"
        case needsClarification = "needs_clarification"
        case clarificationPrompt = "clarification_prompt"
        case homePlacement = "home_placement"
        case message
    }

    /// Tolerant decoding: any missing or `null` field falls back to a safe default,
    /// so a partially-filled model reply never crashes the UI.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func optString(_ key: CodingKeys) -> String? {
            (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil
        }
        func optInt(_ key: CodingKeys) -> Int? {
            (try? c.decodeIfPresent(Int.self, forKey: key)) ?? nil
        }
        func boolOrFalse(_ key: CodingKeys) -> Bool {
            ((try? c.decodeIfPresent(Bool.self, forKey: key)) ?? nil) ?? false
        }
        func stringArray(_ key: CodingKeys) -> [String] {
            ((try? c.decodeIfPresent([String].self, forKey: key)) ?? nil) ?? []
        }

        identified = boolOrFalse(.identified)
        plantName = optString(.plantName)
        soilCondition = optString(.soilCondition)
        conditionScore = PlantAnalysis.clampScore(optInt(.conditionScore))
        conditionDetermined = boolOrFalse(.conditionDetermined)
        recommendations = stringArray(.recommendations)
        generalCare = stringArray(.generalCare)
        wildHabitat = optString(.wildHabitat)
        soilType = optString(.soilType)
        needsClarification = boolOrFalse(.needsClarification)
        clarificationPrompt = optString(.clarificationPrompt)
        homePlacement = optString(.homePlacement)
        message = optString(.message)
    }

    init(identified: Bool,
         plantName: String?,
         soilCondition: String?,
         conditionScore: Int?,
         conditionDetermined: Bool,
         recommendations: [String],
         generalCare: [String],
         wildHabitat: String? = nil,
         soilType: String? = nil,
         needsClarification: Bool = false,
         clarificationPrompt: String? = nil,
         homePlacement: String? = nil,
         message: String?) {
        self.identified = identified
        self.plantName = plantName
        self.soilCondition = soilCondition
        self.conditionScore = PlantAnalysis.clampScore(conditionScore)
        self.conditionDetermined = conditionDetermined
        self.recommendations = recommendations
        self.generalCare = generalCare
        self.wildHabitat = wildHabitat
        self.soilType = soilType
        self.needsClarification = needsClarification
        self.clarificationPrompt = clarificationPrompt
        self.homePlacement = homePlacement
        self.message = message
    }

    private static func clampScore(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(10, max(1, value))
    }
}
