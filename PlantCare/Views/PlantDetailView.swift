import SwiftUI
import UIKit

/// One pot's page: big name, rename, add/change photo, and the timeline of readings.
struct PlantDetailView: View {
    let plantID: UUID
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var activePicker: PhotoSource?

    private var plant: PlantRecord? { history.plant(with: plantID) }

    var body: some View {
        ZStack {
            Theme.background
            if let plant {
                content(for: plant)
            } else {
                Text(lang.t("Plant deleted", "Рослину видалено"))
                    .foregroundStyle(Theme.subtleInk)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        nameDraft = plant?.customName ?? plant?.speciesName ?? ""
                        renaming = true
                    } label: {
                        Label(lang.t("Rename", "Перейменувати"), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        history.delete(plantID)
                        dismiss()
                    } label: {
                        Label(lang.t("Delete", "Видалити"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(Theme.leafDeep)
            }
        }
        .fullScreenCover(item: $activePicker) { source in
            photoPicker(for: source).ignoresSafeArea()
        }
        .alert(lang.t("Name your plant", "Назвіть рослину"), isPresented: $renaming) {
            TextField(lang.t("Name", "Назва"), text: $nameDraft)
                .onChange(of: nameDraft) { newValue in
                    if newValue.count > maxPotNameLength {
                        nameDraft = String(newValue.prefix(maxPotNameLength))
                    }
                }
            Button(lang.t("Save", "Зберегти")) { history.rename(plantID, to: nameDraft) }
            Button(lang.t("Cancel", "Скасувати"), role: .cancel) {}
        } message: {
            Text(lang.t("Up to \(maxPotNameLength) characters so it fits nicely on the pot.",
                        "До \(maxPotNameLength) символів, щоб гарно вмістилося на горщику."))
        }
    }

    private func startCamera() {
        guard CameraAuthorization.isCameraAvailable else { return }
        Task {
            if await CameraAuthorization.requestAccess() { activePicker = .camera }
        }
    }

    @ViewBuilder
    private func photoPicker(for source: PhotoSource) -> some View {
        let onImage: (UIImage) -> Void = { image in
            history.setPhoto(plantID, data: image.jpegData(compressionQuality: 0.7))
            activePicker = nil
        }
        switch source {
        case .camera:
            CameraPicker(onImage: onImage, onCancel: { activePicker = nil })
        case .library:
            LibraryPicker(onImage: onImage, onCancel: { activePicker = nil })
        }
    }

    private func content(for plant: PlantRecord) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                header(for: plant)

                if let latest = plant.latestEntry {
                    NavigationLink {
                        FullInfoScreen(plantName: plant.displayName,
                                       entry: latest,
                                       plantImage: plant.thumbnailData.flatMap(UIImage.init))
                    } label: {
                        Label(lang.t("Show full details", "Показати повну інформацію"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                ForEach(plant.entries.sorted(by: { $0.date > $1.date })) { entry in
                    EntryCard(entry: entry)
                }
            }
            .padding(20)
        }
    }

    private func header(for plant: PlantRecord) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.mint).frame(width: 110, height: 110)
                if let data = plant.thumbnailData, let uiImage = UIImage(data: data) {
                    if plant.thumbnailIsCutout == true {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFit()
                            .frame(width: 92, height: 92)
                    } else {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    }
                } else {
                    PotSproutIcon(size: 68)
                }
            }
            .overlay(Circle().stroke(Theme.leaf.opacity(0.4), lineWidth: 2))
            // Small camera badge — the hint that you can add a photo here.
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button { activePicker = .library } label: {
                        Label(plant.thumbnailData == nil ? lang.t("Add photo", "Додати фото")
                                                         : lang.t("Change photo", "Змінити фото"), systemImage: "photo")
                    }
                    if CameraAuthorization.isCameraAvailable {
                        Button { startCamera() } label: { Label(lang.t("Take a photo", "Зробити фото"), systemImage: "camera") }
                    }
                    if plant.thumbnailData != nil {
                        Button(role: .destructive) { history.setPhoto(plantID, data: nil) } label: {
                            Label(lang.t("Remove photo", "Видалити фото"), systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.leafDeep))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: Theme.potDark.opacity(0.25), radius: 3, y: 2)
                }
                .offset(x: 4, y: 4)
            }

            Text(plant.displayName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            if plant.customName != nil {
                Text(plant.speciesName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtleInk)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// One reading: date + score always visible; recommendations behind a chevron shade.
private struct EntryCard: View {
    let entry: PlantEntry
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(entry.date.formatted(date: .long, time: .omitted),
                      systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.subtleInk)
                Spacer()
            }

            if entry.conditionDetermined, let score = entry.conditionScore {
                ConditionScoreView(score: score)
            } else {
                Label(lang.t("Condition not determined", "Стан не визначено"), systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtleInk)
            }

            if let soil = entry.soilCondition, !soil.isEmpty {
                Label(soil, systemImage: "drop.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtleInk)
            }

            // Pointed recommendations — hidden by default behind the chevron.
            if !entry.recommendations.isEmpty {
                DisclosureCard(title: lang.t("Latest recommendations", "Останні поради"), systemImage: "leaf.fill") {
                    BulletList(items: entry.recommendations)
                }
            }
        }
        .cardStyle()
    }
}
