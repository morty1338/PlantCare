import SwiftUI

/// A collapsible "shade" with a downward chevron. Collapsed by default: only the
/// clickable chevron (and title) is visible; tapping reveals the content.
struct DisclosureCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @State private var expanded: Bool
    let content: () -> Content

    init(title: String, systemImage: String? = nil, initiallyExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(Theme.leafDeep)
                    }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.leafDeep)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                content()
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
    }
}

/// A bulleted list of recommendation strings.
struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.leaf)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact 1–10 condition indicator with a colored bar.
struct ConditionScoreView: View {
    let score: Int

    private var color: Color {
        switch score {
        case ..<4:  return Color(red: 0.86, green: 0.36, blue: 0.30)
        case 4..<7: return Color(red: 0.93, green: 0.70, blue: 0.28)
        default:    return Theme.leafDeep
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ 10")
                    .font(.headline)
                    .foregroundStyle(Theme.subtleInk)
                Spacer()
                Text("Condition")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.subtleInk)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.mint)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 10.0)
                }
            }
            .frame(height: 10)
        }
    }
}
