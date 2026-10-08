import SwiftUI

/// Presented full-screen while analyzing. Switches between loading, result and error.
struct FlowContainer: View {
    @ObservedObject var appVM: AppViewModel
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appVM.reset()
                    } label: {
                        Label(lang.t("Close", "Закрити"), systemImage: "xmark")
                    }
                    .tint(Theme.leafDeep)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appVM.flow {
        case .idle:
            Color.clear
        case .loading:
            LoadingView()
        case .result(let analysis):
            ResultScreen(
                analysis: analysis,
                image: appVM.capturedImage,
                mode: appVM.mode,
                savedPlantID: appVM.savedPlantID,
                onRetake: { appVM.reset() },
                onSubmitName: { name in appVM.analyze(name: name, history: history, language: lang.current.promptName) }
            )
        case .failure(let message):
            ErrorScreen(message: message) {
                appVM.retry(history: history)
            }
        }
    }
}

/// Loading state — a calm spinner with reassuring text.
struct LoadingView: View {
    @EnvironmentObject private var lang: LanguageManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            CactusPot(size: 96, raised: true)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            ProgressView()
                .tint(Theme.leafDeep)
            Text(lang.t("Analyzing the photo…", "Аналізуємо фото…"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(lang.t("Identifying species, soil and plant condition",
                        "Визначаємо вид, ґрунт і стан рослини"))
                .font(.subheadline)
                .foregroundStyle(Theme.subtleInk)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .onAppear { pulse = true }
    }
}

/// Error state — clear message and a retry button.
struct ErrorScreen: View {
    let message: String
    let onRetry: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Theme.leafDeep)
            Text(lang.t("Something went wrong", "Щось пішло не так"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.subtleInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                onRetry()
            } label: {
                Label(lang.t("Try again", "Спробувати ще раз"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(32)
    }
}
