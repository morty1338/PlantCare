import SwiftUI

/// Max characters for a user-chosen plant name (kept short so it fits on the pot).
let maxPotNameLength = 14

/// A garden card: a flat terracotta pot with a pretty, seed-varied plant growing
/// out of it. By default the plant shows an illustrated bloom; once the user adds a
/// photo, the whole photo sits neatly in a rounded frame at the top of the stem.
struct GardenPotView: View {
    let plant: PlantRecord
    private let cardHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let seed = Self.seed(for: plant.id)
            let topCenter = CGPoint(x: w * 0.5, y: h * 0.16)

            ZStack {
                // Stem + leaves (+ bloom when there is no photo), behind the pot.
                PlantArtwork(seed: seed, hasPhoto: plant.thumbnailData != nil)

                // The user's photo, kept whole in a rounded frame at the stem top.
                if let data = plant.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w * 0.44, height: w * 0.44)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white, lineWidth: 3))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.leafDeep.opacity(0.25), lineWidth: 1))
                        .shadow(color: Theme.potDark.opacity(0.25), radius: 5, y: 3)
                        .position(topCenter)
                }

                FlatPot()

                // Name on the pot: at most two words, sized to fit the pot body.
                Text(potLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.potDark.opacity(0.95), radius: 1.5, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(width: w * 0.52)
                    .position(x: w * 0.5, y: h * 0.74)
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    /// Shorten a long name to at most two words (no trailing ellipsis).
    private var potLabel: String {
        let words = plant.displayName.split(separator: " ")
        guard words.count > 2 else { return plant.displayName }
        return words.prefix(2).joined(separator: " ")
    }

    /// A stable per-plant seed derived from the UUID bytes (same across launches).
    static func seed(for id: UUID) -> Int {
        let b = id.uuid
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                     b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15]
        return bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7fffffff }
    }
}

/// Vector stem + leaves, plus an illustrated bloom when there is no photo.
struct PlantArtwork: View {
    let seed: Int
    let hasPhoto: Bool

    private var greenShades: [Color] {
        let sets: [[Color]] = [
            [Theme.leaf, Theme.leafDeep],
            [Theme.sprout, Theme.leaf],
            [Theme.leafDeep, Theme.leaf]
        ]
        return sets[seed % sets.count]
    }
    private var bloomColors: [Color] {
        [Color(red: 0.95, green: 0.51, blue: 0.64),   // pink
         Color(red: 0.98, green: 0.78, blue: 0.30),   // yellow
         Color(red: 0.72, green: 0.55, blue: 0.90),   // lavender
         Color(red: 0.96, green: 0.60, blue: 0.42),   // coral
         Color(red: 0.98, green: 0.98, blue: 0.98)]   // white
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let green = greenShades

            let stemBottom = CGPoint(x: w * 0.5, y: h * 0.54)
            let stemTop = CGPoint(x: w * 0.5, y: h * 0.24)

            // Stem
            var stem = Path()
            stem.move(to: stemBottom)
            stem.addQuadCurve(to: stemTop, control: CGPoint(x: w * 0.56, y: h * 0.4))
            context.stroke(stem, with: .color(green[1]),
                           style: StrokeStyle(lineWidth: max(2, w * 0.025), lineCap: .round))

            // Leaves along the stem — count & tilt vary by seed.
            let leafCount = 2 + seed % 2
            for i in 0..<leafCount {
                let t = Double(i + 1) / Double(leafCount + 1)
                let baseY = h * (0.30 + 0.22 * t)
                let toLeft = (i % 2 == 0)
                let base = CGPoint(x: w * 0.5, y: baseY)
                let tip = CGPoint(x: w * (toLeft ? 0.24 : 0.76) - CGFloat(seed % 3) * 0.01 * w,
                                  y: baseY - h * 0.09)
                drawLeaf(context, from: base, to: tip, width: w * 0.14, color: green[i % 2])
            }

            // Bloom (only when there is no photo).
            if !hasPhoto {
                drawBloom(context, at: CGPoint(x: w * 0.5, y: h * 0.16), radius: w * 0.15)
            }
        }
    }

    private func drawLeaf(_ context: GraphicsContext, from base: CGPoint, to tip: CGPoint,
                          width: CGFloat, color: Color) {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let len = max(1, hypot(dx, dy))
        let nx = -dy / len * width / 2, ny = dx / len * width / 2
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        var leaf = Path()
        leaf.move(to: base)
        leaf.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        leaf.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
        leaf.closeSubpath()
        context.fill(leaf, with: .color(color))
    }

    private func drawBloom(_ context: GraphicsContext, at center: CGPoint, radius: CGFloat) {
        let petalColor = bloomColors[seed % bloomColors.count]
        let petals = 5 + seed % 4
        let petalLen = radius
        let petalW = radius * 0.62
        for i in 0..<petals {
            let angle = Double(i) / Double(petals) * 2 * .pi + Double(seed % 7) * 0.1
            let px = center.x + CGFloat(cos(angle)) * radius * 0.55
            let py = center.y + CGFloat(sin(angle)) * radius * 0.55
            let rect = CGRect(x: px - petalW / 2, y: py - petalLen / 2, width: petalW, height: petalLen)
            var petal = context
            petal.translateBy(x: px, y: py)
            petal.rotate(by: .radians(angle + .pi / 2))
            petal.translateBy(x: -px, y: -py)
            petal.fill(Path(ellipseIn: rect), with: .color(petalColor))
        }
        // Flower centre
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.34, y: center.y - radius * 0.34,
                                            width: radius * 0.68, height: radius * 0.68)),
                     with: .color(Color(red: 0.99, green: 0.83, blue: 0.36)))
    }
}

/// Flat, vector-drawn terracotta pot: rounded body tapering downward, a clear rim,
/// and a single light two-tone inner shadow. No gradients or highlights.
struct FlatPot: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var body = Path()
            body.move(to: CGPoint(x: 0.16 * w, y: 0.58 * h))
            body.addLine(to: CGPoint(x: 0.84 * w, y: 0.58 * h))
            body.addLine(to: CGPoint(x: 0.74 * w, y: 0.92 * h))
            body.addQuadCurve(to: CGPoint(x: 0.26 * w, y: 0.92 * h),
                              control: CGPoint(x: 0.50 * w, y: 0.975 * h))
            body.closeSubpath()
            context.fill(body, with: .color(Theme.terracotta))

            var shade = context
            shade.clip(to: body)
            shade.fill(Path(CGRect(x: 0, y: 0.58 * h, width: w, height: 0.07 * h)),
                       with: .color(Theme.terracottaShadow))

            let rim = Path(roundedRect: CGRect(x: 0.10 * w, y: 0.50 * h,
                                               width: 0.80 * w, height: 0.10 * h),
                           cornerRadius: h * 0.035)
            context.fill(rim, with: .color(Theme.terracottaRim))
        }
    }
}

#Preview {
    let a = PlantRecord(customName: "Monty", speciesName: "Monstera", entries: [])
    let b = PlantRecord(customName: nil, speciesName: "Alocasia amazonica polly", entries: [])
    return HStack(spacing: 16) {
        GardenPotView(plant: a).frame(width: 165)
        GardenPotView(plant: b).frame(width: 165)
    }
    .padding()
    .background(Theme.mint)
}
