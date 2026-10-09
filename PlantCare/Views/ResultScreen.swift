import SwiftUI

/// Compact result layout. Branches on the JSON fields:
/// - `identified == false`  → retake / type-a-name fallback.
/// - `conditionDetermined == false` → show general care instead of a score.
/// - otherwise → full result with big plant name.
struct ResultScreen: View {
    let analysis: PlantAnalysis
    let image: UIImage?
    let mode: AppMode
    let savedPlantID: UUID?
    let onRetake: () -> Void
    let onSubmitName: (String) -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var showChat = false
    @StateObject private var chatVM = ChatViewModel(plantName: "", summary: "", originalImage: nil, firstQuestion: nil)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                if analysis.identified {
                    identifiedContent
                } else {
                    NotIdentifiedView(message: analysis.message, onRetake: onRetake, onSubmitName: onSubmitName)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showChat) {
            ChatView(vm: chatVM).environmentObject(lang)
        }
    }

    private func openChat() {
        chatVM.start(plantName: analysis.plantName ?? lang.t("plant", "рослина"),
                     summary: Self.summary(of: analysis),
                     originalImage: image,
                     firstQuestion: analysis.clarificationPrompt,
                     opener: lang.t("Ask anything about your plant, or add a photo.",
                                    "Запитайте будь-що про вашу рослину або додайте фото."),
                     language: lang.current.promptName)
        showChat = true
    }

    private static func summary(of a: PlantAnalysis) -> String {
        var parts: [String] = []
        if let n = a.plantName { parts.append("species \(n)") }
        if let s = a.conditionScore { parts.append("condition \(s)/10") }
        if let soil = a.soilCondition { parts.append("soil: \(soil)") }
        if !a.recommendations.isEmpty { parts.append("advice: " + a.recommendations.prefix(3).joined(separator: "; ")) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Identified

    private var identifiedContent: some View {
        VStack(spacing: 16) {
            // Big plant name
            VStack(spacing: 6) {
                Text(analysis.plantName ?? lang.t("Plant", "Рослина"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if mode == .home && savedPlantID != nil {
                    Label(lang.t("Saved to history", "Збережено в історії"), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.leafDeep)
                }
            }
            .frame(maxWidth: .infinity)

            if let message = analysis.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtleInk)
                    .multilineTextAlignment(.center)
            }

            AnalysisSections(analysis: analysis, onOpenChat: openChat)

            Button(action: onRetake) {
                Label(lang.t("Done", "Готово"), systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
    }
}

/// Fallback when the plant could not be identified: retake or type the name.
private struct NotIdentifiedView: View {
    let message: String?
    let onRetake: () -> Void
    let onSubmitName: (String) -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.leafDeep)
            Text(lang.t("Couldn't identify the plant", "Не вдалося розпізнати рослину"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message?.isEmpty == false ? message! :
                    lang.t("Take another photo or type the plant name.",
                           "Зробіть інше фото або введіть назву рослини."))
                .font(.subheadline)
                .foregroundStyle(Theme.subtleInk)
                .multilineTextAlignment(.center)

            Button {
                onRetake()
            } label: {
                Label(lang.t("Take another photo", "Зробити інше фото"), systemImage: "camera.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            VStack(alignment: .leading, spacing: 10) {
                Text(lang.t("Or type a name", "Або введіть назву"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                HStack {
                    TextField(lang.t("e.g. Monstera", "напр. Монстера"), text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focused)
                        .submitLabel(.go)
                        .onSubmit(submit)
                    if !name.isEmpty {
                        Button {
                            submit()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.leafDeep)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.mintDeep, lineWidth: 1))
                )
            }
            .cardStyle()
        }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        focused = false
        onSubmitName(trimmed)
    }
}
