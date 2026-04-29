#if !WIDGET_EXTENSION
//
// KestoDesignSystem.swift
// Shared visual primitives for the premium KESTO interface refresh.
//

import SwiftUI

enum KestoSurfaceStyle {
    case elevated
    case muted
    case tinted
}

enum KestoChipTone {
    case neutral
    case ember
    case forest
}

struct KestoScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.sectionGap) {
                content
            }
            .padding(.horizontal, KestoTheme.Spacing.screenPadding)
            .padding(.top, KestoTheme.Spacing.xl)
            .padding(.bottom, 108)
        }
        .scrollIndicators(.hidden)
        .background(KestoTheme.Colors.paper)
    }
}

struct KestoCard<Content: View>: View {
    let style: KestoSurfaceStyle
    let padding: CGFloat
    let content: Content

    init(
        style: KestoSurfaceStyle = .elevated,
        padding: CGFloat = KestoTheme.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: KestoTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KestoTheme.Radius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.9)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
    }

    private var background: Color {
        switch style {
        case .elevated:
            return KestoTheme.Colors.white
        case .muted:
            return KestoTheme.Colors.whiteWarm
        case .tinted:
            return KestoTheme.Colors.bone.opacity(0.65)
        }
    }

    private var borderColor: Color {
        switch style {
        case .elevated:
            return KestoTheme.Colors.border
        case .muted:
            return KestoTheme.Colors.borderSoft
        case .tinted:
            return KestoTheme.Colors.border
        }
    }

    private var shadowColor: Color {
        style == .elevated ? KestoTheme.Colors.shadow : .clear
    }

    private var shadowRadius: CGFloat {
        style == .elevated ? 18 : 0
    }

    private var shadowYOffset: CGFloat {
        style == .elevated ? 8 : 0
    }
}

struct KestoSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .top, spacing: KestoTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.xs) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(KestoTheme.Typography.label)
                        .tracking(1.6)
                        .foregroundStyle(KestoTheme.Colors.ember)
                }

                Text(title)
                    .font(KestoTheme.Typography.sectionTitle)
                    .foregroundStyle(KestoTheme.Colors.ink)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                        .lineSpacing(3)
                }
            }

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(KestoTheme.Typography.buttonSmall)
                        .foregroundStyle(KestoTheme.Colors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(KestoTheme.Colors.paper, in: Capsule())
                        .overlay(Capsule().stroke(KestoTheme.Colors.border, lineWidth: 0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct KestoChip: View {
    let title: String
    let icon: String?
    let tone: KestoChipTone

    init(_ title: String, icon: String? = nil, tone: KestoChipTone = .neutral) {
        self.title = title
        self.icon = icon
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(title)
                .font(KestoTheme.Typography.buttonSmall)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor, in: Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: 0.9))
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return KestoTheme.Colors.slate
        case .ember:
            return KestoTheme.Colors.ember
        case .forest:
            return KestoTheme.Colors.forest
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return KestoTheme.Colors.whiteWarm
        case .ember:
            return KestoTheme.Colors.emberSoft
        case .forest:
            return KestoTheme.Colors.forestSoft
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return KestoTheme.Colors.border
        case .ember:
            return KestoTheme.Colors.ember.opacity(0.14)
        case .forest:
            return KestoTheme.Colors.forest.opacity(0.16)
        }
    }
}

struct KestoProgressBar: View {
    let value: Double
    let tint: Color
    var track: Color = KestoTheme.Colors.bone.opacity(0.7)

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width * min(max(value, 0), 1), 10)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(track)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tint)
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }
}

struct KestoConsistencyStrip: View {
    let days: [Date]
    let states: [KestoConsistencyState]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 8) {
                    Text(shortWeekday(for: day))
                        .font(KestoTheme.Typography.label)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(states[safe: index]?.fill ?? KestoTheme.Colors.bone.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(states[safe: index]?.border ?? KestoTheme.Colors.borderSoft, lineWidth: 0.8)
                        )
                        .frame(height: 44)
                        .overlay {
                            Text(dayNumber(for: day))
                                .font(KestoTheme.Typography.bodyStrong)
                                .foregroundStyle(states[safe: index]?.text ?? KestoTheme.Colors.ink)
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }
}

struct KestoConsistencyState {
    let fill: Color
    let border: Color
    let text: Color
}

struct KestoStreakCard: View {
    let streakCount: Int
    let activeDays: [Bool]
    let summary: String
    let valueLabel: String

    var body: some View {
        KestoCard(style: .elevated, padding: KestoTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        KestoChip("Streak", icon: "flame.fill", tone: .ember)
                        Text("\(streakCount)")
                            .font(KestoTheme.Typography.hero)
                            .foregroundStyle(KestoTheme.Colors.ink)
                        Text(valueLabel)
                            .font(KestoTheme.Typography.bodyStrong)
                            .foregroundStyle(KestoTheme.Colors.slate)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Text(summary)
                            .font(KestoTheme.Typography.detail)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                            .multilineTextAlignment(.trailing)

                        HStack(spacing: 6) {
                            ForEach(Array(activeDays.enumerated()), id: \.offset) { _, active in
                                Circle()
                                    .fill(active ? KestoTheme.Colors.ember : KestoTheme.Colors.bone.opacity(0.55))
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(active ? KestoTheme.Colors.ember.opacity(0.14) : KestoTheme.Colors.borderSoft, lineWidth: 0.8))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 days")
                        .font(KestoTheme.Typography.label)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                    HStack(spacing: 8) {
                        ForEach(Array(activeDays.enumerated()), id: \.offset) { index, active in
                            Capsule()
                                .fill(active ? KestoTheme.Colors.ember : KestoTheme.Colors.bone.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .frame(height: 8)
                                .overlay(alignment: .topLeading) {
                                    if index == activeDays.count - 1 {
                                        EmptyView()
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
}

struct KestoStatCard: View {
    let title: String
    let value: String
    let detail: String
    let tone: KestoChipTone

    var body: some View {
        KestoCard(style: .muted, padding: KestoTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title.uppercased())
                    .font(KestoTheme.Typography.label)
                    .tracking(1.2)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)

                Text(value)
                    .font(KestoTheme.Typography.metric)
                    .foregroundStyle(KestoTheme.Colors.ink)

                Text(detail)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
                    .lineSpacing(2)

                KestoChip(chipTitle, tone: tone)
            }
        }
    }

    private var chipTitle: String {
        switch tone {
        case .neutral:
            return "Stable"
        case .ember:
            return "Needs care"
        case .forest:
            return "On track"
        }
    }
}

struct KestoListRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: KestoTheme.Spacing.md) {
            leading
                .frame(width: 40, height: 40)
                .background(KestoTheme.Colors.bone.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(KestoTheme.Typography.bodyStrong)
                    .foregroundStyle(KestoTheme.Colors.ink)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                }
            }

            Spacer(minLength: 0)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KestoEmptyState: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        KestoCard(style: .muted, padding: KestoTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(KestoTheme.Colors.slate)
                    .frame(width: 50, height: 50)
                    .background(KestoTheme.Colors.bone.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(title)
                    .font(KestoTheme.Typography.sectionTitle)
                    .foregroundStyle(KestoTheme.Colors.ink)

                Text(detail)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
                    .lineSpacing(3)
            }
        }
    }
}

struct KestoBottomSheet<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            KestoScreen {
                KestoSectionHeader(title: title, subtitle: subtitle)
                content
            }
        }
        .presentationDragIndicator(.visible)
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
#endif
