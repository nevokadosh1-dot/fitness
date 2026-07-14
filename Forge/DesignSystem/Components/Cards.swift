import SwiftUI

/// Standard elevated card used across every screen.
struct Card<Content: View>: View {
    var accent: Color?
    @ViewBuilder var content: Content

    init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    )
            )
            .overlay(alignment: .leading) {
                if let accent {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, Spacing.m)
                        .padding(.leading, 1)
                }
            }
    }
}

/// Prominent gradient-sheen card for the dashboard hero.
struct HeroCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content

    init(tint: Color = Theme.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.16), tint.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                    )
            )
    }
}

/// Section header with an optional trailing action.
struct SectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.forgeOverline)
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, Spacing.xs)
    }
}

/// Small labeled statistic used inside cards and grids.
struct StatTile: View {
    var label: String
    var value: String
    var unit: String?
    var tint: Color

    init(label: String, value: String, unit: String? = nil, tint: Color = Theme.textPrimary) {
        self.label = label
        self.value = value
        self.unit = unit
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.forgeOverline)
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.forgeStat)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rounded capsule tag (muscle groups, equipment, run types…).
struct TagChip: View {
    var text: String
    var tint: Color = Theme.textSecondary
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(.forgeCaption)
            .foregroundStyle(isSelected ? Color.black : tint)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? tint : tint.opacity(0.14))
            )
    }
}

/// Circular completion indicator with a percentage label.
struct ProgressRing: View {
    var progress: Double
    var tint: Color = Theme.accent
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            Text(Formatting.percent(progress))
                .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Completion \(Formatting.percent(progress))")
    }
}

/// Friendly empty state with an optional call to action.
struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.forgeHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.forgeSubheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, Spacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
    }
}
