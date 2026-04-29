#if !WIDGET_EXTENSION
//
// MendelTabBar.swift
// Shared custom tab bar.
//

import SwiftUI

struct MendelTabBar: View {
    @Environment(MendelAppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MendelTab.tabBarTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.rawValue)
                            .font(KestoTheme.Typography.label)
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(isSelected(tab) ? KestoTheme.Colors.ink : KestoTheme.Colors.slateSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected(tab) ? KestoTheme.Colors.whiteWarm : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(KestoTheme.Colors.paper.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                )
                .shadow(color: KestoTheme.Colors.shadow, radius: 18, y: 6)
        )
        .padding(.horizontal, KestoTheme.Spacing.lg)
        .padding(.bottom, 20)
    }

    private func isSelected(_ tab: MendelTab) -> Bool {
        if appState.selectedTab == .log {
            return tab == .home
        }
        return appState.selectedTab == tab
    }
}
#endif
