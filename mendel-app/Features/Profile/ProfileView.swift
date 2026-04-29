#if !WIDGET_EXTENSION
//
// ProfileView.swift
// Grouped profile and settings surface in the refreshed KESTO language.
//

import SwiftUI

struct ProfileView: View {
    @Environment(PurchaseManager.self) private var store
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(NotificationManager.self) private var notifications

    @State private var showingNotifications = false
    @State private var showingPaywall = false

    var body: some View {
        KestoScreen {
            KestoSectionHeader(
                eyebrow: "Profile",
                title: "Settings",
                subtitle: "Account, integrations, and the quieter parts of KESTO."
            )

            KestoCard(style: .elevated) {
                VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                    KestoSectionHeader(
                        eyebrow: "Status",
                        title: "Your setup",
                        subtitle: "A quick view of access, health data, and reminders."
                    )

                    ProfileRow(title: "Premium", detail: store.hasPremiumAccess ? "Unlocked" : "Free", icon: "sparkles") {
                        if !store.hasPremiumAccess {
                            showingPaywall = true
                        }
                    }

                    ProfileRow(title: "Apple Health", detail: healthSummary, icon: "heart.text.square") {
                        if !healthKit.isAuthorized && !healthKit.authorizationDenied {
                            Task { await healthKit.requestAuthorization() }
                        }
                    }

                    ProfileRow(title: "Notifications", detail: notificationSummary, icon: "bell.badge") {
                        showingNotifications = true
                    }
                }
            }

            KestoCard(style: .muted) {
                VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                    KestoSectionHeader(
                        eyebrow: "Support",
                        title: "Help and account",
                        subtitle: "Feedback and legal/account surfaces can live here in phase two."
                    )

                    SimpleInfoRow(title: "Support", detail: "In-app help and feedback")
                    SimpleInfoRow(title: "Legal", detail: "Terms and privacy")
                    SimpleInfoRow(title: "Account", detail: "Purchase and data controls")
                }
            }

            KestoCard(style: .muted) {
                VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                    KestoSectionHeader(
                        eyebrow: "About",
                        title: "KESTO",
                        subtitle: AppStrings.Profile.about
                    )
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationSettingsView().environment(notifications)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView().environment(store)
        }
    }

    private var healthSummary: String {
        if healthKit.isAuthorized { return "Connected" }
        return healthKit.authorizationDenied ? "Not available" : "Not connected"
    }

    private var notificationSummary: String {
        notifications.isAuthorized ? "Enabled" : "Manage"
    }
}

private struct ProfileRow: View {
    let title: String
    let detail: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KestoListRow(title: title, subtitle: detail) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KestoTheme.Colors.ink)
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SimpleInfoRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(KestoTheme.Typography.bodyStrong)
                .foregroundStyle(KestoTheme.Colors.ink)
            Text(detail)
                .font(KestoTheme.Typography.detail)
                .foregroundStyle(KestoTheme.Colors.slateSoft)
        }
    }
}
#endif
