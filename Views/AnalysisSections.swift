import SwiftUI

/// The shared body of a plant result, ordered: the essentials (condition), an
/// interesting fact, then watering/light and placement behind disclosure "shades"
/// (like in history) so the layout stays calm. An always-present chat entry is
/// subtle when the plant is healthy and prominent when the score is 6 or below.
struct AnalysisSections: View {
    let analysis: PlantAnalysis
    let onOpenChat: () -> Void

    @EnvironmentObject private var lang: LanguageManager

    private var isConcern: Bool {
        analysis.needsClarification || (analysis.conditionScore ?? 10) <= 6
    }

    var body: some View {
        VStack(spacing: 16) {
            // 1 — The essentials: condition.
            if analysis.conditionDetermined, let score = analysis.conditionScore {
                ConditionScoreView(score: score).cardStyle()
            } else {
                infoRow(icon: "questionmark.circle",
                        text: lang.t("Condition couldn't be assessed — showing general care tips.",
                                     "Стан оцінити не вдалося — показано загальні поради."))
            }

            // 2 — Chat entry (prominence depends on the score).
            chatEntry

            // 3 — Interesting fact.
            if let habitat = analysis.wildHabitat, !habitat.isEmpty {
                infoRow(icon: "globe.europe.africa.fill",
                        title: lang.t("Interesting fact", "Цікавий факт"), text: habitat)
            }

            // 4 — Watering & light (shade, open by default).
            if !analysis.recommendations.isEmpty {
                DisclosureCard(title: lang.t("Watering & light", "Полив і світло"),
                               systemImage: "drop.fill", initiallyExpanded: true) {
                    BulletList(items: analysis.recommendations)
                }
            }

            // 5 — Soil & general care (shade).
            if analysis.soilType != nil || analysis.soilCondition != nil || !analysis.generalCare.isEmpty {
                DisclosureCard(title: lang.t("Soil & general care", "Ґрунт і загальний догляд"),
                               systemImage: "square.stack.3d.up.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let soilType = analysis.soilType, !soilType.isEmpty {
                            labeled(lang.t("Best soil", "Найкращий ґрунт"), soilType)
                        }
                        if let soil = analysis.soilCondition, !soil.isEmpty {
                            labeled(lang.t("Soil condition", "Стан ґрунту"), soil)
                        }
                        if !analysis.generalCare.isEmpty { BulletList(items: analysis.generalCare) }
                    }
                }
            }

            // 6 — Placement (shade), only when room photos were provided.
            if let placement = analysis.homePlacement, !placement.isEmpty {
                DisclosureCard(title: lang.t("Where to place it", "Де розмістити"),
                               systemImage: "house.fill") {
                    Text(placement)
                        .font(.subheadline).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var chatEntry: some View {
        if isConcern {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .foregroundStyle(.orange).frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lang.t("Want a more precise answer?", "Хочете точнішу відповідь?"))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text(analysis.clarificationPrompt?.isEmpty == false
                             ? analysis.clarificationPrompt!
                             : lang.t("Add a photo of the soil or the affected leaves and I'll tell you what's missing.",
                                      "Додайте фото ґрунту чи уражених листків — і я скажу, чого бракує."))
                            .font(.subheadline).foregroundStyle(Theme.subtleInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Button(action: onOpenChat) {
                    Label(lang.t("Open chat · add a photo", "Відкрити чат · додати фото"), systemImage: "paperclip")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .cardStyle()
        } else {
            Button(action: onOpenChat) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                    Text(lang.t("Ask a follow-up question", "Поставити додаткове запитання"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.leafDeep)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
    }

    private func labeled(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(text).font(.subheadline).foregroundStyle(Theme.subtleInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(icon: String, title: String? = nil, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.leafDeep).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                }
                Text(text).font(.subheadline).foregroundStyle(Theme.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }
}
