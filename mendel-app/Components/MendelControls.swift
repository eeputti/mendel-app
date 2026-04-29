#if !WIDGET_EXTENSION
//
// MendelControls.swift
// Shared controls and compatibility wrappers for the refreshed KESTO design system.
//

import SwiftUI

enum KestoCardStyle {
    case primary
    case secondary
    case inline
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(KestoTheme.Typography.label)
            .foregroundStyle(KestoTheme.Colors.slateSoft)
            .tracking(1.3)
    }
}

struct KestoScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        KestoSectionHeader(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle
        )
    }
}

struct LoadBar: View {
    let label: String
    let value: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(KestoTheme.Typography.bodyStrong)
                    .foregroundStyle(KestoTheme.Colors.ink)

                Spacer()

                Text(detail)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
            }

            KestoProgressBar(
                value: value,
                tint: KestoTheme.Colors.slate,
                track: KestoTheme.Colors.bone.opacity(0.5)
            )
        }
    }
}

struct KestoPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(KestoTheme.Typography.bodyStrong)
            }
            .foregroundStyle(KestoTheme.Colors.whiteWarm)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(KestoTheme.Colors.ink, in: Capsule())
            .overlay(Capsule().stroke(KestoTheme.Colors.ink, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

struct KestoSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(KestoTheme.Typography.bodyStrong)
            }
            .foregroundStyle(KestoTheme.Colors.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(KestoTheme.Colors.whiteWarm, in: Capsule())
            .overlay(Capsule().stroke(KestoTheme.Colors.border, lineWidth: 0.9))
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        KestoPrimaryButton(title: title, action: action)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        KestoSecondaryButton(title: title, action: action)
    }
}

struct EffortSelector: View {
    @Binding var level: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    level = index
                } label: {
                    ZStack {
                        Circle()
                            .fill(index <= level ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                            .overlay(
                                Circle()
                                    .stroke(index <= level ? KestoTheme.Colors.ink : KestoTheme.Colors.border, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)

                        Text("\(index)")
                            .font(KestoTheme.Typography.buttonSmall)
                            .foregroundStyle(index <= level ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                    }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: level)
            }
        }
    }
}

struct PillSelector<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    @Binding var selected: T?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                } label: {
                    Text(label(option))
                        .font(KestoTheme.Typography.buttonSmall)
                        .foregroundStyle(selected == option ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous)
                                .fill(selected == option ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous)
                                        .stroke(selected == option ? KestoTheme.Colors.ink : KestoTheme.Colors.border, lineWidth: 0.9)
                                )
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: selected)
            }
        }
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            TextField(placeholder, text: $value)
                .font(KestoTheme.Typography.body)
                .foregroundStyle(KestoTheme.Colors.ink)
                .padding(.horizontal, KestoTheme.Spacing.inlinePadding)
                .padding(.vertical, 13)
                .kestoCard(.inline, padding: 0)
                .keyboardType(keyboardType)
        }
    }
}

extension View {
    func kestoCard(_ style: KestoCardStyle = .secondary, padding: CGFloat? = KestoTheme.Spacing.cardPadding) -> some View {
        modifier(KestoCardModifier(style: style, padding: padding))
    }
}

private struct KestoCardModifier: ViewModifier {
    let style: KestoCardStyle
    let padding: CGFloat?

    func body(content: Content) -> some View {
        Group {
            switch style {
            case .inline:
                content
                    .padding(padding ?? 0)
                    .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous)
                            .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                    )
            case .primary:
                KestoCard(style: .elevated, padding: padding ?? KestoTheme.Spacing.cardPadding) {
                    content
                }
            case .secondary:
                KestoCard(style: .muted, padding: padding ?? KestoTheme.Spacing.cardPadding) {
                    content
                }
            }
        }
    }
}
#endif
