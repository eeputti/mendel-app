import SwiftUI
import SwiftData

// MARK: - TodayView v3
// Replaces TodayView+v2.swift
// Adds: settings button → NotificationSettingsView sheet.

struct TodayView: View {

    @Environment(AppState.self)            private var appState
    @Environment(HealthKitManager.self)    private var hk
    @Environment(PurchaseManager.self)     private var store
    @Environment(NotificationManager.self) private var notifications
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appeared         = false
    @State private var showingSettings  = false

    var recommendation: Recommendation { appState.recommendation }
    var summary: WeeklySummary         { appState.weeklySummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Top row: date + settings button
                HStack(alignment: .top) {
                    Text(dateString)
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.inkSoft)
                        .tracking(1.0)
                        .textCase(.uppercase)

                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(MendelColors.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(MendelColors.inkFaint.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 28)
                .opacity(appeared ? 1 : 0)

                // State word
                Text(recommendation.state.rawValue)
                    .font(MendelType.stateWord())
                    .foregroundStyle(MendelColors.ink)
                    .tracking(-3)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)

                // Context
                Text(recommendation.context)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .lineSpacing(4)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)

                // HK signals (unlocked)
                if store.isUnlocked && hk.isAuthorized {
                    RecoverySignalRow()
                        .padding(.top, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.13), value: appeared)
                }

                // Divider
                Rectangle()
                    .fill(MendelColors.inkFaint)
                    .frame(width: 32, height: 1)
                    .padding(.vertical, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                // Steps
                SectionLabel(text: "do this")
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.18), value: appeared)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recommendation.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("→")
                                .font(MendelType.caption())
                                .foregroundStyle(MendelColors.inkFaint)
                                .padding(.top, 1)
                            Text(step)
                                .font(MendelType.body())
                                .foregroundStyle(MendelColors.ink)
                                .lineSpacing(3)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(
                            .easeOut(duration: 0.4).delay(0.22 + Double(idx) * 0.06),
                            value: appeared
                        )
                    }
                }

                Spacer().frame(height: 32)

                // HealthKit banners
                if hk.isAuthorized && !hk.recentWorkouts.isEmpty {
                    WorkoutsImportBanner { _ in }
                        .padding(.bottom, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                }

                if !hk.isAuthorized && !hk.authorizationDenied {
                    HealthKitPromptCard()
                        .padding(.bottom, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                }

                // Notification prompt (first time, not yet authorized)
                if !notifications.isAuthorized && !notifications.authorizationDenied {
                    NotificationPromptCard()
                        .padding(.bottom, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.33), value: appeared)
                }

                // Load bars
                VStack(spacing: 10) {
                    LoadBar(label: "Strength",  value: summary.strengthBalance,  detail: "\(summary.strengthSessions)×")
                    LoadBar(label: "Endurance", value: summary.enduranceBalance, detail: "\(summary.enduranceSessions)×")
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)

                Spacer().frame(height: 24)

                PrimaryButton(title: "+ log activity") {
                    appState.selectedTab = .log
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(MendelColors.bg)
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView()
                .environment(notifications)
        }
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            }
        }
        .onChange(of: recommendation.state) {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { appeared = true }
            }
        }
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"
        return f.string(from: .now)
    }
}

// MARK: - Notification Prompt Card (inline, Today screen)

struct NotificationPromptCard: View {
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(MendelColors.stone)
                Text("daily brief")
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
            }
            Text("get today's recommendation at 8am and a log reminder in the evening. that's it.")
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(3)

            HStack(spacing: 10) {
                GhostButton(title: "not now") { }
                PrimaryButton(title: "turn on") {
                    Task { await notifications.requestAuthorization() }
                }
            }
        }
        .padding(16)
        .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MendelRadius.md)
                .stroke(MendelColors.inkFaint, lineWidth: 0.5)
        )
    }
}
