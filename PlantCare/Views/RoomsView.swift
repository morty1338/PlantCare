import SwiftUI
import UIKit

/// "My home" — a small catalogue of named places where the user keeps plants.
/// Each place is a framed photo with a title. When analyzing a plant, these are
/// sent so the AI can suggest a specific spot (🏠).
struct RoomsView: View {
    @EnvironmentObject private var rooms: RoomStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var activePicker: PhotoSource?
    @State private var pendingImage: UIImage?
    @State private var nameDraft = ""
    @State private var namingNewPlace = false
    @State private var renamingID: UUID?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                ScrollView {
                    VStack(spacing: 16) {
                        intro
                        if !rooms.rooms.isEmpty { grid }
                        addButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(lang.t("My home", "Мій дім"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("Done", "Готово")) { dismiss() }.tint(Theme.leafDeep)
                }
            }
            .fullScreenCover(item: $activePicker) { source in
                picker(for: source).ignoresSafeArea()
            }
            // Name a newly added place.
            .alert(lang.t("Name this place", "Назвіть це місце"), isPresented: $namingNewPlace) {
                TextField(lang.t("e.g. Living room window", "напр. Вікно у вітальні"), text: $nameDraft)
                Button(lang.t("Save", "Зберегти")) {
                    if let image = pendingImage {
                        rooms.add(image, name: nameDraft.isEmpty ? lang.t("My place", "Моє місце") : nameDraft)
                    }
                    pendingImage = nil; nameDraft = ""
                }
                Button(lang.t("Cancel", "Скасувати"), role: .cancel) { pendingImage = nil; nameDraft = "" }
            } message: {
                Text(lang.t("Give this spot a short name so tips can reference it.",
                            "Дайте цьому місцю коротку назву, щоб поради могли на нього посилатися."))
            }
            // Rename an existing place.
            .alert(lang.t("Rename place", "Перейменувати місце"), isPresented: renamingBinding) {
                TextField(lang.t("Name", "Назва"), text: $nameDraft)
                Button(lang.t("Save", "Зберегти")) { if let id = renamingID { rooms.rename(id, to: nameDraft) } }
                Button(lang.t("Cancel", "Скасувати"), role: .cancel) {}
            }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "house.fill").foregroundStyle(Theme.leafDeep)
            Text(lang.t("Add named photos of the places where you keep plants. When you analyze a plant, PlantDoctor suggests the best spot for it in your home.",
                        "Додайте підписані фото місць, де ви тримаєте рослини. Під час аналізу PlantDoctor підкаже найкраще місце для рослини у вашому домі."))
                .font(.footnote).foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(rooms.rooms) { room in
                VStack(spacing: 8) {
                    if let image = UIImage(data: room.imageData) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white, lineWidth: 3))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.mintDeep, lineWidth: 1))
                            .shadow(color: Theme.leafDeep.opacity(0.12), radius: 5, y: 3)
                            .overlay(alignment: .topTrailing) {
                                Button { rooms.delete(room.id) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3).foregroundStyle(.white).shadow(radius: 2)
                                }
                                .padding(6)
                            }
                    }
                    Text(room.name.isEmpty ? lang.t("My place", "Моє місце") : room.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                .onTapGesture {
                    nameDraft = room.name
                    renamingID = room.id
                }
            }
        }
    }

    private var addButton: some View {
        Menu {
            Button { activePicker = .library } label: { Label(lang.t("Choose from library", "Обрати з галереї"), systemImage: "photo") }
            if CameraAuthorization.isCameraAvailable {
                Button { startCamera() } label: { Label(lang.t("Take a photo", "Зробити фото"), systemImage: "camera") }
            }
        } label: {
            Label(lang.t("Add a place", "Додати місце"), systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private func startCamera() {
        guard CameraAuthorization.isCameraAvailable else { return }
        Task { if await CameraAuthorization.requestAccess() { activePicker = .camera } }
    }

    @ViewBuilder
    private func picker(for source: PhotoSource) -> some View {
        let onImage: (UIImage) -> Void = { image in
            activePicker = nil
            pendingImage = image
            nameDraft = ""
            namingNewPlace = true
        }
        switch source {
        case .camera: CameraPicker(onImage: onImage, onCancel: { activePicker = nil })
        case .library: LibraryPicker(onImage: onImage, onCancel: { activePicker = nil })
        }
    }
}
