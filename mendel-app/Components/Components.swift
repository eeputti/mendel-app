import SwiftUI

// MARK: - Tab Bar

struct MendelTabBar: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundStyle(
                                appState.selectedTab == tab
                                    ? MendelColors.ink
                                    : MendelColors.inkFaint
                            )
                        Text(tab.rawValue)
                            .font(MendelType.label())
                            .foregroundStyle(
                                appState.selectedTab == tab
                                    ? MendelColors.ink
                                    : MendelColors.inkSoft
                            )
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Rectangle()
                .fill(MendelColors.bg.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MendelColors.inkFaint)
                        .frame(height: 0.5)
                }
        )
        .padding(.bottom, 20) // safe area bottom
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(MendelType.label())
            .foregroundStyle(MendelColors.inkSoft)
            .tracking(1.0)
    }
}

// MARK: - Load Bar

struct LoadBar: View {
    let label: String
    let value: Double   // 0–1
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
                .tracking(0.5)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.inkFaint)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.ink)
                        .frame(width: geo.size.width * max(value, 0), height: 3)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }
            .frame(height: 3)

            Text(detail)
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkFaint)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MendelType.bodyMedium())
                .foregroundStyle(MendelColors.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MendelColors.ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost Button (outline)

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MendelType.bodyMedium())
                .foregroundStyle(MendelColors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .stroke(MendelColors.inkFaint, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Effort Selector (5 dots)

struct EffortSelector: View {
    @Binding var level: Int
    var max: Int = 5

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...max, id: \.self) { i in
                Button {
                    level = i
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                i <= level ? MendelColors.ink : MendelColors.inkFaint,
                                lineWidth: 1.5
                            )
                            .background(
                                Circle().fill(i <= level ? MendelColors.ink : .clear)
                            )
                            .frame(width: 30, height: 30)
                        Text("\(i)")
                            .font(MendelType.label())
                            .foregroundStyle(i <= level ? MendelColors.bg : MendelColors.inkSoft)
                    }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
}

// MARK: - Pill Selector

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
                        .font(MendelType.caption())
                        .foregroundStyle(selected == option ? MendelColors.bg : MendelColors.ink)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: MendelRadius.sm)
                                .fill(selected == option ? MendelColors.ink : MendelColors.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MendelRadius.sm)
                                        .stroke(
                                            selected == option ? MendelColors.ink : MendelColors.inkFaint,
                                            lineWidth: 0.5
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: selected)
            }
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            TextField(placeholder, text: $value)
                .font(MendelType.bodyMedium())
                .foregroundStyle(MendelColors.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MendelColors.bg, in: RoundedRectangle(cornerRadius: MendelRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.sm)
                        .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                )
                .keyboardType(keyboardType)
        }
    }
}
