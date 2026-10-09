import SwiftUI
import UIKit

/// Re-opens the full first-request information for a saved plant (no new request),
/// with the same chat entry so the user can still ask follow-ups.
struct FullInfoScreen: View {
    let plantName: String
    let entry: PlantEntry
    let plantImage: UIImage?

    @EnvironmentObject private var lang: LanguageManager
    @State private var showChat = false
    @StateObject private var chatVM = ChatViewModel(plantName: "", summary: "", originalImage: nil, firstQuestion: nil)

    private var analysis: PlantAnalysis { entry.asAnalysis(plantName: plantName) }

    var body: some View {
        ZStack {
            Theme.background
            ScrollView {
                VStack(spacing: 16) {
                    Text(plantName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    AnalysisSections(analysis: analysis, onOpenChat: openChat)
                }
                .padding(20)
            }
        }
        .navigationTitle(lang.t("Full details", "Повна інформація"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChat) {
            ChatView(vm: chatVM).environmentObject(lang)
        }
    }

    private func openChat() {
        chatVM.start(plantName: plantName,
                     summary: Self.summary(of: analysis),
                     originalImage: plantImage,
                     firstQuestion: nil,
                     opener: lang.t("Ask anything about your plant, or add a photo.",
                                    "Запитайте будь-що про вашу рослину або додайте фото."),
                     language: lang.current.promptName)
        showChat = true
    }

    private static func summary(of a: PlantAnalysis) -> String {
        var parts: [String] = []
        if let n = a.plantName { parts.append("species \(n)") }
        if let s = a.conditionScore { parts.append("condition \(s)/10") }
        if !a.recommendations.isEmpty { parts.append("advice: " + a.recommendations.prefix(3).joined(separator: "; ")) }
        return parts.joined(separator: ", ")
    }
}
