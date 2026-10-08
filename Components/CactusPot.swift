import SwiftUI

/// The app's signature figure: a brown, line-patterned pot with a tall cactus
/// growing straight up. Used as the hero on the home screen (animates in on load),
/// as the history button, and as a small accent in native corners.
struct CactusPot: View {
    /// Height of the figure; width is derived (~0.78 × height).
    var size: CGFloat = 120
    /// Adds a soft drop shadow for a more three-dimensional look.
    var raised: Bool = false

    private var width: CGFloat { size * 0.78 }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            let potBrown = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.potLight, Theme.pot, Theme.potDark]),
                startPoint: CGPoint(x: 0, y: h * 0.6),
                endPoint: CGPoint(x: w, y: h)
            )
            let cactusGreen = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.sprout, Theme.leaf, Theme.leafDeep]),
                startPoint: CGPoint(x: w * 0.3, y: 0),
                endPoint: CGPoint(x: w * 0.7, y: h)
            )

            // --- Cactus (drawn first, pot occludes its base) ---
            drawCactus(context, w: w, h: h, shading: cactusGreen)

            // --- Pot ---
            drawPot(context, w: w, h: h, shading: potBrown)
        }
        .frame(width: width, height: size)
        .shadow(color: raised ? Theme.potDark.opacity(0.35) : .clear,
                radius: raised ? 8 : 0, x: 0, y: raised ? 5 : 0)
        .accessibilityLabel("Pot with a cactus")
    }

    private func drawCactus(_ context: GraphicsContext, w: CGFloat, h: CGFloat,
                            shading: GraphicsContext.Shading) {
        // Main stem
        let stem = Path(roundedRect: CGRect(x: w * 0.40, y: h * 0.10,
                                            width: w * 0.20, height: h * 0.58),
                        cornerRadius: w * 0.10)
        context.fill(stem, with: shading)

        // Left arm (horizontal + vertical capsules forming an L)
        let lArmH = Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.42,
                                             width: w * 0.16, height: h * 0.075),
                         cornerRadius: h * 0.037)
        let lArmV = Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.30,
                                             width: w * 0.10, height: h * 0.16),
                         cornerRadius: w * 0.05)
        context.fill(lArmH, with: shading)
        context.fill(lArmV, with: shading)

        // Right arm (higher than the left)
        let rArmH = Path(roundedRect: CGRect(x: w * 0.56, y: h * 0.32,
                                             width: w * 0.16, height: h * 0.075),
                         cornerRadius: h * 0.037)
        let rArmV = Path(roundedRect: CGRect(x: w * 0.62, y: h * 0.20,
                                             width: w * 0.10, height: h * 0.16),
                         cornerRadius: w * 0.05)
        context.fill(rArmH, with: shading)
        context.fill(rArmV, with: shading)

        // Spine ridges — light vertical lines along the stem
        var ridges = Path()
        for frac in [0.46, 0.54] {
            ridges.move(to: CGPoint(x: w * frac, y: h * 0.16))
            ridges.addLine(to: CGPoint(x: w * frac, y: h * 0.62))
        }
        context.stroke(ridges, with: .color(.white.opacity(0.25)),
                       style: StrokeStyle(lineWidth: max(1, w * 0.012), lineCap: .round))

        // A tiny flower bud on top
        let bud = Path(ellipseIn: CGRect(x: w * 0.44, y: h * 0.055,
                                         width: w * 0.12, height: h * 0.075))
        context.fill(bud, with: .color(Theme.bloom))
    }

    private func drawPot(_ context: GraphicsContext, w: CGFloat, h: CGFloat,
                         shading: GraphicsContext.Shading) {
        // Rim
        let rim = Path(roundedRect: CGRect(x: w * 0.16, y: h * 0.60,
                                           width: w * 0.68, height: h * 0.09),
                       cornerRadius: h * 0.02)
        context.fill(rim, with: shading)

        // Tapered body
        var body = Path()
        body.move(to: CGPoint(x: w * 0.20, y: h * 0.69))
        body.addLine(to: CGPoint(x: w * 0.80, y: h * 0.69))
        body.addLine(to: CGPoint(x: w * 0.70, y: h * 0.97))
        body.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.97),
                          control: CGPoint(x: w * 0.50, y: h * 1.02))
        body.closeSubpath()
        context.fill(body, with: shading)

        // Line pattern on the body
        var lines = Path()
        for y in [0.77, 0.86] {
            lines.move(to: CGPoint(x: w * 0.24, y: h * y))
            lines.addLine(to: CGPoint(x: w * 0.76, y: h * y))
        }
        context.stroke(lines, with: .color(Theme.potDark.opacity(0.55)),
                       style: StrokeStyle(lineWidth: max(1, h * 0.012), lineCap: .round))
    }
}

#Preview {
    HStack(spacing: 20) {
        CactusPot(size: 140, raised: true)
        CactusPot(size: 60)
    }
    .padding()
    .background(Theme.mint)
}
