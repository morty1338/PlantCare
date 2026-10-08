import SwiftUI

/// Fresh, salad-green palette and shared visual tokens.
enum Theme {
    // Greens
    static let leaf       = Color(red: 0.404, green: 0.733, blue: 0.361) // primary salad green
    static let leafDeep   = Color(red: 0.243, green: 0.560, blue: 0.290) // deeper accent
    static let sprout     = Color(red: 0.545, green: 0.812, blue: 0.416)
    static let mint       = Color(red: 0.847, green: 0.945, blue: 0.831) // soft fill
    static let mintDeep   = Color(red: 0.741, green: 0.894, blue: 0.706)

    // Pot / earth accents
    static let potLight   = Color(red: 0.847, green: 0.573, blue: 0.376)
    static let pot        = Color(red: 0.741, green: 0.475, blue: 0.290)
    static let potDark    = Color(red: 0.549, green: 0.337, blue: 0.196)
    static let soil       = Color(red: 0.400, green: 0.290, blue: 0.220)

    // Flat terracotta pot (garden cards) — #C87F4E body, #B26E3F rim, #A85F30 shadow
    static let terracotta       = Color(red: 0.784, green: 0.498, blue: 0.306)
    static let terracottaRim    = Color(red: 0.698, green: 0.431, blue: 0.247)
    static let terracottaShadow = Color(red: 0.659, green: 0.373, blue: 0.188)

    // Accent bloom (cactus flower)
    static let bloom      = Color(red: 0.945, green: 0.510, blue: 0.635)

    // Neutrals
    static let ink        = Color(red: 0.16, green: 0.22, blue: 0.17)
    static let subtleInk  = Color(red: 0.42, green: 0.48, blue: 0.43)

    /// Page background — a green, plant-themed backdrop.
    static var background: some View {
        PlantyBackground()
    }

    static let cornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 16
}

/// A soft, rounded card surface used throughout the app.
struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
            .fill(.white.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(Theme.mintDeep.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Theme.leafDeep.opacity(0.08), radius: 10, y: 4)
    }
}

extension View {
    /// Wrap content in the standard app card.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self.padding(padding).background(CardBackground())
    }
}

/// A bold, embossed / convex app title that stands apart from everything else.
struct EmbossedTitle: View {
    let text: String
    var size: CGFloat = 42

    private var font: Font { .system(size: size, weight: .black, design: .rounded) }

    var body: some View {
        ZStack {
            // Dark drop shadow (depth below-right)
            Text(text).foregroundStyle(Theme.potDark.opacity(0.30))
                .offset(x: 2, y: 3).blur(radius: 0.5)
            // Light highlight (above-left) for the convex bevel
            Text(text).foregroundStyle(.white.opacity(0.95))
                .offset(x: -1.2, y: -1.5)
            // Main green gradient face
            Text(text).foregroundStyle(
                LinearGradient(colors: [Theme.sprout, Theme.leaf, Theme.leafDeep],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        .font(font)
        .shadow(color: Theme.leafDeep.opacity(0.28), radius: 6, y: 4)
        .accessibilityLabel(text)
    }
}

/// A primary, compact green action button style.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.leaf, Theme.leafDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A secondary, outlined button style.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.leafDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.leaf, lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
