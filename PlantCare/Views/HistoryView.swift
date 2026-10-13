import SwiftUI

/// "My garden". Tap a pot to open it. Press and hold a pot for a moment and it lifts under
/// the finger — keep holding and drag it: the neighbours glide out of the way live and the
/// order is saved on release. No separate edit mode.
///
/// Pot positions are computed (not measured with GeometryReader), as in SoundMarks: hit-testing
/// is exact, and the lifted pot follows the finger from where it was picked up, so reordering
/// the array under it never makes it jump or cancels the gesture.
struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var path: [UUID] = []
    /// The lifted pot, the slot centre it was picked up from, and the finger offset.
    @State private var dragged: UUID?
    @State private var dragStart: CGPoint = .zero
    @State private var dragTranslation: CGSize = .zero
    @State private var orderChanged = false
    /// True while a pot is held; resets by itself if the system cancels the touch,
    /// so a pot can never stay stuck in the air.
    @GestureState private var isHolding = false

    private static let space = "garden"

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background
                if history.plants.isEmpty {
                    emptyState
                } else {
                    garden
                }
            }
            .navigationTitle(lang.t("My garden", "Мій сад"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("Done", "Готово")) { dismiss() }
                        .tint(Theme.leafDeep)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PlantDetailView(plantID: id)
                    .environmentObject(history)
                    .environmentObject(lang)
            }
        }
        // While a pot is in the air, a downward drag must never close the garden.
        .interactiveDismissDisabled(dragged != nil)
        .onChange(of: isHolding) { holding in
            if !holding { drop() }
        }
    }

    // MARK: - Garden

    private var garden: some View {
        GeometryReader { geo in
            let layout = GardenLayout(width: geo.size.width, count: history.plants.count)
            ScrollView {
                VStack(spacing: 10) {
                    Text(lang.t("Tap to open · hold and drag to move",
                                "Торкніться, щоб відкрити · утримуйте й тягніть, щоб перемістити"))
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    potField(layout)
                }
                .padding(.top, 8)
            }
            .scrollDisabled(dragged != nil)
        }
    }

    private func potField(_ layout: GardenLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(history.plants.enumerated()), id: \.element.id) { index, plant in
                let isDragged = dragged == plant.id
                GardenPotView(plant: plant)
                    .equatable()
                    .frame(width: layout.cellWidth, height: layout.cellHeight)
                    .contentShape(Rectangle())
                    // While one pot is in the air, the others wiggle like Home Screen icons.
                    .modifier(Wobble(isOn: dragged != nil && !isDragged, seed: Double(index)))
                    .scaleEffect(isDragged ? 1.1 : 1)
                    .shadow(color: Theme.potDark.opacity(isDragged ? 0.35 : 0),
                            radius: isDragged ? 14 : 0, y: isDragged ? 10 : 0)
                    // Only the lift (scale/shadow) animates here — the position is set below
                    // without animation, so the pot sticks to the finger with no lag.
                    .animation(Motion.quick, value: isDragged)
                    .position(isDragged
                              ? CGPoint(x: dragStart.x + dragTranslation.width,
                                        y: dragStart.y + dragTranslation.height)
                              : layout.center(index))
                    .zIndex(isDragged ? 1 : 0)
                    .onTapGesture { path.append(plant.id) }
                    .gesture(moveGesture(for: plant, layout: layout))
            }
        }
        .frame(width: layout.width, height: layout.height)
        .coordinateSpace(name: Self.space)
    }

    // MARK: - Moving a pot

    /// Hold (0.3 s) → the pot lifts; keep the finger down and drag. A quick tap fails the
    /// hold, so it still opens the plant.
    private func moveGesture(for plant: PlantRecord, layout: GardenLayout) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .updating($isHolding) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if dragged != plant.id { lift(plant, layout: layout) }
                guard let drag else { return }
                dragTranslation = drag.translation
                moveIfOverAnotherPot(plant, layout: layout)
            }
            .onEnded { _ in drop() }
    }

    private func lift(_ plant: PlantRecord, layout: GardenLayout) {
        guard let index = history.plants.firstIndex(where: { $0.id == plant.id }) else { return }
        dragStart = layout.center(index)
        dragTranslation = .zero
        dragged = plant.id
        Haptics.lift()
    }

    /// Over another pot's place → take it; the rest shift live.
    private func moveIfOverAnotherPot(_ plant: PlantRecord, layout: GardenLayout) {
        let point = CGPoint(x: dragStart.x + dragTranslation.width,
                            y: dragStart.y + dragTranslation.height)
        let ids = history.plants.map(\.id)
        guard let target = ids.indices.first(where: {
            ids[$0] != plant.id && layout.center($0).distance(to: point) < layout.hitRadius
        }) else { return }
        Haptics.select()
        orderChanged = true
        withAnimation(Motion.reorder) {
            history.move(id: plant.id, to: target)
        }
    }

    /// Settle the pot into its slot and save the order (safe to call twice).
    private func drop() {
        guard dragged != nil else { return }
        if orderChanged { history.persistOrder() }
        orderChanged = false
        withAnimation(Motion.standard) {
            dragged = nil
            dragTranslation = .zero
        }
    }

    // MARK: - Empty

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

// MARK: - Layout

/// Where every pot goes: a fixed grid computed from the width, so hit-testing and the
/// dragged pot's position never depend on (one-frame-late) measured frames.
private struct GardenLayout {
    let width: CGFloat
    let count: Int

    private let sideInset: CGFloat = 20
    private let spacing: CGFloat = 16
    private let rowSpacing: CGFloat = 14
    let cellHeight = GardenPotView.cardHeight

    var columns: Int {
        max(2, Int((width - 2 * sideInset + spacing) / (150 + spacing)))
    }

    var cellWidth: CGFloat {
        (width - 2 * sideInset - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    }

    private var rows: Int { (count + columns - 1) / columns }

    var height: CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * cellHeight + CGFloat(rows - 1) * rowSpacing + 24
    }

    /// A pot counts as "under the finger" within this distance of its centre.
    var hitRadius: CGFloat { min(cellWidth, cellHeight) * 0.45 }

    func center(_ index: Int) -> CGPoint {
        let row = index / columns
        let column = index % columns
        return CGPoint(x: sideInset + CGFloat(column) * (cellWidth + spacing) + cellWidth / 2,
                       y: CGFloat(row) * (cellHeight + rowSpacing) + cellHeight / 2)
    }
}

// MARK: - Wobble

/// Pot wiggle in edit mode, like icons on the Home Screen (SoundMarks' `Wobble`).
/// The modifier is always present; only its value changes, so the pot isn't recreated.
private struct Wobble: ViewModifier {
    let isOn: Bool
    let seed: Double

    @State private var tilt = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isOn ? (tilt ? 1.8 : -1.8) : 0))
            .onAppear { if isOn { start() } }
            .onChange(of: isOn) { on in
                if on { start() } else { stop() }
            }
    }

    private func start() {
        // Slightly different speeds so the garden doesn't wiggle in lockstep.
        withAnimation(.easeInOut(duration: 0.13 + seed.truncatingRemainder(dividingBy: 3) * 0.012)
            .repeatForever(autoreverses: true)) {
            tilt.toggle()
        }
    }

    private func stop() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { tilt = false }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
