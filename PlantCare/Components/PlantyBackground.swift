import SwiftUI

/// A green, plant-themed background with the user's hand-drawn leaf as a soft
/// watermark (multiply blend of a lightened copy). Leaves sit in the corners so
/// they never sit behind the central text column.
struct PlantyBackground: View {
    private struct Placement: Identifiable {
        let id = UUID()
        let x: CGFloat, y: CGFloat, width: CGFloat, angle: Double
    }

    private let placements: [Placement] = [
        .init(x: -0.04, y: 0.05, width: 0.40, angle: -22),
        .init(x: 1.04, y: 0.30, width: 0.40, angle: 150),
        .init(x: -0.06, y: 0.92, width: 0.42, angle: 30),
        .init(x: 1.02, y: 0.97, width: 0.5, angle: -150)
    ]

    @State private var leaf: Image?

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
                    ForEach(placements) { p in
                        leaf
                            .resizable()
                            .scaledToFit()
                            .frame(width: w * p.width)
                            .rotationEffect(.degrees(p.angle))
                            .position(x: w * p.x, y: h * p.y)
                            .blendMode(.multiply)
                    }
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .task {
            if leaf == nil {
                let loaded = await LeafArt.load()
                withAnimation(.easeIn(duration: 0.3)) { leaf = loaded }
            }
        }
    }
}

#Preview { PlantyBackground() }
