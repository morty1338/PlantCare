import SwiftUI

/// A green, plant-themed background with the user's hand-drawn leaf as a soft
/// watermark (multiply blend of a lightened copy). Leaves sit in the corners so
/// they never sit behind the central text column.
struct PlantyBackground: View {
    private struct Placement {
        let x: CGFloat, y: CGFloat, width: CGFloat, angle: Double
    }

    /// Static and index-identified: the background has no stored values that change between
    /// redraws, so a parent re-rendering (every frame of a drag) never rebuilds the leaves.
    /// (They used to get a fresh `UUID()` per redraw, which made them blink.)
    private static let placements: [Placement] = [
        .init(x: -0.04, y: 0.05, width: 0.40, angle: -22),
        .init(x: 1.04, y: 0.30, width: 0.40, angle: 150),
        .init(x: -0.06, y: 0.92, width: 0.42, angle: 30),
        .init(x: 1.02, y: 0.97, width: 0.5, angle: -150)
    ]

    /// Starts from the cached drawing, so a newly opened screen never shows a bare background.
    @State private var leaf: Image? = LeafArt.ready

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.831, green: 0.929, blue: 0.784),
                    Color(red: 0.612, green: 0.824, blue: 0.537)
                ],
                startPoint: .top, endPoint: .bottom
            )

            if let leaf {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ForEach(Self.placements.indices, id: \.self) { index in
                        let p = Self.placements[index]
                        leaf
                            .resizable()
                            .scaledToFit()
                            .frame(width: w * p.width)
                            .rotationEffect(.degrees(p.angle))
                            .position(x: w * p.x, y: h * p.y)
                            .blendMode(.multiply)
                    }
                }
            }
        }
        // Never take part in animations running on top (a reorder, a sheet): the
        // background just stays put.
        .transaction { $0.animation = nil }
        // Rasterise once into a single layer: the multiply blends aren't recomposited on
        // every frame of every animation that happens on top of the background.
        .drawingGroup()
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .task {
            if leaf == nil {
                leaf = await LeafArt.load()
            }
        }
    }
}

#Preview { PlantyBackground() }
