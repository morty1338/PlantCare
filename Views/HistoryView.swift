import SwiftUI
import UIKit

/// "My garden". Hold a pot to lift it (it floats on top, following your finger) and
/// drop it on another pot to swap places; tap to open. Reordering happens on drop so
/// the drag is never cancelled mid-gesture, and the scroll is disabled while dragging.
struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var path: [UUID] = []
    @State private var frames: [UUID: CGRect] = [:]
    @State private var draggingID: UUID?
    @State private var dragLocation: CGPoint = .zero

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]
    private let space = "garden"
    private let liftHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let dropHaptic = UISelectionFeedbackGenerator()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background
                if history.plants.isEmpty {
                    emptyState
                } else {
                    garden
                }
                dragPreview
            }
            .coordinateSpace(name: space)
            .navigationTitle(lang.t("My garden", "Мій сад"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("Done", "Готово")) { dismiss() }.tint(Theme.leafDeep)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PlantDetailView(plantID: id)
                    .environmentObject(history)
                    .environmentObject(lang)
            }
        }
    }

    private var garden: some View {
        ScrollView {
            Text(lang.t("Tap to open · hold & drag to swap", "Торкніться, щоб відкрити · утримуйте й тягніть, щоб поміняти місцями"))
                .font(.footnote)
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(history.plants) { plant in
                    GardenPotView(plant: plant)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: PotFramesKey.self,
                                                       value: [plant.id: geo.frame(in: .named(space))])
                            }
                        )
                        .opacity(draggingID == plant.id ? 0 : 1)
                        .onTapGesture { path.append(plant.id) }
                        .gesture(reorderGesture(plant))
                }
            }
            .padding(20)
            .onPreferenceChange(PotFramesKey.self) { frames = $0 }
        }
        .scrollDisabled(draggingID != nil)
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let id = draggingID, let plant = history.plant(with: id) {
            let size = frames[id]?.size ?? CGSize(width: 150, height: 200)
            GardenPotView(plant: plant)
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.12)
                .shadow(color: Theme.potDark.opacity(0.4), radius: 16, y: 12)
                .position(dragLocation)
                .allowsHitTesting(false)
                .zIndex(100)
        }
    }

    /// Hold to lift, drag to move, drop on another pot to swap. The array is only
    /// mutated on drop, so the in-progress gesture is never interrupted. Uses a
    /// normal (not high-priority) gesture so a quick tap still opens the pot.
    private func reorderGesture(_ plant: PlantRecord) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(space)))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if draggingID != plant.id {
                    draggingID = plant.id
                    dragLocation = frames[plant.id]?.center ?? drag.location
                    liftHaptic.impactOccurred()
                }
                dragLocation = drag.location
            }
            .onEnded { value in
                defer { draggingID = nil }
                guard case .second(_, let drag?) = value else { return }
                if let target = targetPot(for: plant.id, at: drag.location) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        history.swap(plant.id, target)
                    }
                    history.persistOrder()
                    dropHaptic.selectionChanged()
                }
            }
    }

    /// The pot the finger was dropped on: the one whose frame contains the point,
    /// otherwise the nearest pot within a comfortable radius.
    private func targetPot(for dragged: UUID, at point: CGPoint) -> UUID? {
        let others = frames.filter { $0.key != dragged }
        if let hit = others.first(where: { $0.value.contains(point) })?.key { return hit }
        let nearest = others.min {
            $0.value.center.distance(to: point) < $1.value.center.distance(to: point)
        }
        if let nearest, nearest.value.center.distance(to: point) < 120 { return nearest.key }
        return nil
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            CactusPot(size: 120, raised: true)
            Text(lang.t("Your garden is empty", "Ваш сад порожній"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(lang.t("Take a photo in “Home plants” mode and a pot will grow here.",
                        "Зробіть фото в режимі «Домашні рослини», і тут виросте горщик."))
                .font(.subheadline)
                .foregroundStyle(Theme.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private struct PotFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
