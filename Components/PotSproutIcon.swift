import SwiftUI

/// A custom, vector-drawn icon: a pot with a green sprout growing inside it.
///
/// Used for the "Home plants" mode chip and the round history button.
struct PotSproutIcon: View {
    /// Overall square size of the icon.
    var size: CGFloat = 28
    /// Tint of the sprout leaves.
    var leafColor: Color = Theme.leafDeep
    /// Tint of the pot.
    var potColor: Color = Theme.pot

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // --- Sprout ---
            let stemBottom = CGPoint(x: w * 0.5, y: h * 0.58)
            let stemTop = CGPoint(x: w * 0.5, y: h * 0.20)

            var stem = Path()
            stem.move(to: stemBottom)
            stem.addLine(to: stemTop)
            context.stroke(stem, with: .color(leafColor),
                           style: StrokeStyle(lineWidth: max(1.4, w * 0.05), lineCap: .round))

            // Left leaf
            let leftLeaf = leafPath(
                base: CGPoint(x: w * 0.5, y: h * 0.40),
                tip: CGPoint(x: w * 0.20, y: h * 0.20),
                control1: CGPoint(x: w * 0.28, y: h * 0.42),
                control2: CGPoint(x: w * 0.16, y: h * 0.34)
            )
            context.fill(leftLeaf, with: .color(leafColor))

            // Right leaf
            let rightLeaf = leafPath(
                base: CGPoint(x: w * 0.5, y: h * 0.36),
                tip: CGPoint(x: w * 0.82, y: h * 0.14),
                control1: CGPoint(x: w * 0.74, y: h * 0.38),
                control2: CGPoint(x: w * 0.86, y: h * 0.28)
            )
            context.fill(rightLeaf, with: .color(Theme.sprout))

            // --- Pot ---
            // Rim
            let rimRect = CGRect(x: w * 0.24, y: h * 0.56, width: w * 0.52, height: h * 0.10)
            let rim = Path(roundedRect: rimRect, cornerRadius: h * 0.03)
            context.fill(rim, with: .color(potColor))

            // Body (tapered)
            var body = Path()
            body.move(to: CGPoint(x: w * 0.27, y: h * 0.66))
            body.addLine(to: CGPoint(x: w * 0.73, y: h * 0.66))
            body.addLine(to: CGPoint(x: w * 0.66, y: h * 0.92))
            body.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.92),
                              control: CGPoint(x: w * 0.50, y: h * 0.96))
            body.closeSubpath()
            context.fill(body, with: .color(potColor.opacity(0.92)))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Pot with sprout")
    }

    private func leafPath(base: CGPoint, tip: CGPoint, control1: CGPoint, control2: CGPoint) -> Path {
        var path = Path()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: control1)
        path.addQuadCurve(to: base, control: control2)
        path.closeSubpath()
        return path
    }
}

/// A prominent, three-dimensional cactus-pot button — the entry point to the garden.
struct HistoryButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CactusPot(size: 60, raised: true)
                .frame(width: 56, height: 62)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("My garden")
    }
}

#Preview {
    HStack(spacing: 24) {
        PotSproutIcon(size: 64)
        HistoryButton(action: {})
    }
    .padding()
    .background(Theme.mint)
}
