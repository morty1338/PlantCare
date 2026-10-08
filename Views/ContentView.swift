import SwiftUI

/// Root screen: pick a mode, then a photo source. The result flow is presented
/// as a full-screen cover on top.
struct ContentView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var rooms: RoomStore
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var appVM = AppViewModel()

    @State private var showingHistory = false
    @State private var showingRooms = false
    @State private var activePicker: PhotoSource?
    @State private var cameraDeniedAlert = false
    @State private var cameraUnavailableAlert = false

    // Name search ("app not working? type a plant name")
    @State private var showNameSearch = false
    @State private var nameQuery = ""

    // Drives the hero figure's appear animation.
    @State private var heroAppeared = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Theme.background
                homeContent
                // History entry point — a plain pot icon, no circle or background.
                HistoryButton { showingHistory = true }
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                // Language toggle — top-left.
                languageToggle
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 20)
                    .padding(.top, 10)
            }
            .navigationBarHidden(true)
            .overlay { nameSearchOverlay }
        }
        // History
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .environmentObject(history)
                .environmentObject(lang)
        }
        // My home (placement planning)
        .sheet(isPresented: $showingRooms) {
            RoomsView()
                .environmentObject(rooms)
                .environmentObject(lang)
        }
        // Photo pickers
        .fullScreenCover(item: $activePicker) { source in
            pickerView(for: source)
                .ignoresSafeArea()
        }
        // Result / loading / error flow
        .fullScreenCover(isPresented: flowPresented) {
            resultFlow
        }
        // Alerts
        .alert(lang.t("No camera access", "Немає доступу до камери"), isPresented: $cameraDeniedAlert) {
            Button(lang.t("Open Settings", "Відкрити налаштування")) { CameraAuthorization.openSettings() }
            Button(lang.t("Cancel", "Скасувати"), role: .cancel) {}
        } message: {
            Text(lang.t("Allow camera access in Settings to photograph your plant.",
                        "Дозвольте доступ до камери в налаштуваннях, щоб сфотографувати рослину."))
        }
        .alert(lang.t("Camera unavailable", "Камера недоступна"), isPresented: $cameraUnavailableAlert) {
            Button(lang.t("Choose from library", "Обрати з галереї")) { activePicker = .library }
            Button(lang.t("Cancel", "Скасувати"), role: .cancel) {}
        } message: {
            Text(lang.t("This device has no camera (e.g. the Simulator). Pick a photo from the library.",
                        "На цьому пристрої немає камери (напр. симулятор). Оберіть фото з галереї."))
        }
    }

    // MARK: - Home content

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if !Config.hasAPIKey {
                    missingKeyBanner
                }

                modeSelector

                sourceButtons
                    .padding(.top, 2)

                homeButton

                nameSearchPrompt
                    .padding(.top, 2)

                Spacer(minLength: 12)
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            CactusPot(size: 132, raised: true)
                .padding(.top, 6)
                .scaleEffect(heroAppeared ? 1 : 0.4)
                .opacity(heroAppeared ? 1 : 0)
                .rotationEffect(.degrees(heroAppeared ? 0 : -8))
                .animation(.spring(response: 0.65, dampingFraction: 0.55), value: heroAppeared)
                .onAppear { heroAppeared = true }

            EmbossedTitle(text: "PlantDoctor", size: 42)

            Text(lang.t("Plant care recommendations from a photo",
                        "Поради з догляду за рослинами за фото"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private var missingKeyBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key.fill").foregroundStyle(.orange)
            Text("No API key set. Open PlantCare/Config.swift and paste your Anthropic key.")
                .font(.footnote)
                .foregroundStyle(Theme.ink)
        }
        .cardStyle()
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("Mode", "Режим"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                ForEach(AppMode.allCases) { mode in
                    ModeCard(mode: mode, isSelected: appVM.mode == mode) {
                        appVM.mode = mode
                    }
                }
            }
        }
    }

    private var sourceButtons: some View {
        VStack(spacing: 10) {
            Button {
                startCamera()
            } label: {
                Label(lang.t("Take a photo", "Зробити фото"), systemImage: "camera.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                activePicker = .library
            } label: {
                Label(lang.t("Choose from library", "Обрати з галереї"), systemImage: "photo.on.rectangle")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    /// Entry point to "My home" — room photos used for placement advice.
    private var homeButton: some View {
        Button {
            showingRooms = true
        } label: {
            Label(rooms.rooms.isEmpty
                  ? lang.t("Set up My home for placement tips", "Налаштуйте «Мій дім» для порад щодо розміщення")
                  : lang.t("My home · \(rooms.rooms.count) places", "Мій дім · місць: \(rooms.rooms.count)"),
                  systemImage: "house.fill")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    /// Small native hint + magnifier that opens the framed name-search box.
    private var nameSearchPrompt: some View {
        HStack(spacing: 6) {
            Text(lang.t("Camera not working? Enter a plant name and get all the info you need",
                        "Камера не працює? Введіть назву рослини й отримайте всю потрібну інформацію"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showNameSearch = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.leafDeep)
                    .padding(6)
            }
            .accessibilityLabel("Search by plant name")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Name search overlay (framed input box)

    @ViewBuilder
    private var nameSearchOverlay: some View {
        if showNameSearch {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { dismissNameSearch() }

                NameSearchBox(
                    text: $nameQuery,
                    onSubmit: submitNameSearch,
                    onClose: dismissNameSearch
                )
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    private func submitNameSearch() {
        let trimmed = nameQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dismissNameSearch()
        appVM.analyze(name: trimmed, history: history, language: lang.current.promptName)
    }

    private func dismissNameSearch() {
        withAnimation(.easeOut(duration: 0.2)) { showNameSearch = false }
        nameQuery = ""
    }

    // MARK: - Actions

    private func startCamera() {
        guard CameraAuthorization.isCameraAvailable else {
            cameraUnavailableAlert = true
            return
        }
        Task {
            let granted = await CameraAuthorization.requestAccess()
            if granted {
                activePicker = .camera
            } else {
                cameraDeniedAlert = true
            }
        }
    }

    // MARK: - Picker view

    @ViewBuilder
    private func pickerView(for source: PhotoSource) -> some View {
        switch source {
        case .camera:
            CameraPicker(
                onImage: { image in
                    activePicker = nil
                    appVM.analyze(image: image, history: history, rooms: rooms.images, language: lang.current.promptName)
                },
                onCancel: { activePicker = nil }
            )
        case .library:
            LibraryPicker(
                onImage: { image in
                    activePicker = nil
                    appVM.analyze(image: image, history: history, rooms: rooms.images, language: lang.current.promptName)
                },
                onCancel: { activePicker = nil }
            )
        }
    }

    // MARK: - Result flow

    private var flowPresented: Binding<Bool> {
        Binding(
            get: { appVM.flow != .idle },
            set: { if !$0 { appVM.reset() } }
        )
    }

    @ViewBuilder
    private var resultFlow: some View {
        FlowContainer(appVM: appVM)
            .environmentObject(history)
            .environmentObject(lang)
    }

    /// EN/UK toggle shown in the top-left corner.
    private var languageToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { lang.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe").font(.footnote.weight(.semibold))
                Text(lang.current.label).font(.subheadline.weight(.heavy))
            }
            .foregroundStyle(Theme.leafDeep)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                Capsule().fill(.white.opacity(0.9))
                    .overlay(Capsule().stroke(Theme.leaf.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: Theme.leafDeep.opacity(0.15), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang.t("Language", "Мова"))
    }
}

/// A selectable mode card. Home mode shows the pot-and-sprout icon.
private struct ModeCard: View {
    let mode: AppMode
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    private var title: String {
        mode == .home ? lang.t("Home plants", "Домашні рослини") : lang.t("One-time", "Разово")
    }
    private var subtitle: String {
        mode == .home ? lang.t("History & stats are saved", "Історія та показники зберігаються")
                      : lang.t("Nothing is saved", "Нічого не зберігається")
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Group {
                    if mode == .home {
                        PotSproutIcon(size: 32,
                                      leafColor: isSelected ? .white : Theme.leafDeep,
                                      potColor: isSelected ? .white.opacity(0.9) : Theme.pot)
                    } else {
                        Image(systemName: "bolt.badge.clock")
                            .font(.system(size: 26))
                            .foregroundStyle(isSelected ? .white : Theme.leafDeep)
                    }
                }
                .frame(height: 36)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Theme.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : Theme.subtleInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [Theme.leaf, Theme.leafDeep],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.white.opacity(0.88)))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .stroke(isSelected ? Color.clear : Theme.mintDeep.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// A small, nicely-framed text box for typing a plant name.
private struct NameSearchBox: View {
    @Binding var text: String
    let onSubmit: () -> Void
    let onClose: () -> Void
    @EnvironmentObject private var lang: LanguageManager
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(lang.t("Plant name", "Назва рослини"), systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.subtleInk.opacity(0.6))
                }
            }

            HStack(spacing: 8) {
                TextField(lang.t("e.g. Monstera", "напр. Монстера"), text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
                if !text.isEmpty {
                    Button(action: onSubmit) {
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
                        .stroke(Theme.leaf, lineWidth: 1.5))
            )

            Button(lang.t("Get info", "Отримати інформацію"), action: onSubmit)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LinearGradient(colors: [Theme.leaf, Theme.leafDeep],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2)
                )
                .shadow(color: Theme.leafDeep.opacity(0.25), radius: 20, y: 8)
        )
        .onAppear { focused = true }
    }
}
