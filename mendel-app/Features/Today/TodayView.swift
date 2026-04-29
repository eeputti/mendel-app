#if !WIDGET_EXTENSION
//
// TodayView.swift
// Premium home dashboard with streak-first training summary.
//

import SwiftUI
import SwiftData
import HealthKit

struct TodayView: View {
    @Query(sort: \Session.date, order: .forward) private var sessions: [Session]
    @Query(sort: \RecoveryLog.date, order: .reverse) private var recoveryLogs: [RecoveryLog]
    @Environment(MendelAppState.self) private var appState
    @Environment(HealthKitManager.self) private var hk
    @Environment(PurchaseManager.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.modelContext) private var modelContext

    @State private var showingSettings = false
    @State private var showLogActivity = false
    @State private var importFeedbackVisible = false

    @AppStorage("prompt.dismissed.health") private var healthPromptDismissed = false
    @AppStorage("prompt.dismissed.notifications") private var notificationPromptDismissed = false

    private let calendar = Calendar.current

    var body: some View {
        KestoScreen {
            HomeHeader(
                greeting: greeting,
                dateString: dateString,
                onLogActivityTap: { showLogActivity = true },
                onNotificationsTap: { showingSettings = true }
            )

            KestoStreakCard(
                streakCount: currentStreak,
                activeDays: lastSevenDayActivity,
                summary: streakSummary,
                valueLabel: currentStreak == 1 ? "day in rhythm" : "days in rhythm"
            )

            KestoCard(style: .muted) {
                VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                    KestoSectionHeader(
                        eyebrow: "This Week",
                        title: "Consistency",
                        subtitle: "\(consistencyPercent)% of the last 7 days had activity."
                    )

                    KestoConsistencyStrip(
                        days: weekDays,
                        states: weekDayStates
                    )

                    KestoProgressBar(
                        value: Double(activeDaysThisWeek) / Double(max(weekDays.count, 1)),
                        tint: KestoTheme.Colors.ember
                    )
                }
            }

            HStack(alignment: .top, spacing: KestoTheme.Spacing.md) {
                KestoStatCard(
                    title: "Weekly load",
                    value: "\(Int(appState.weeklySummary.totalLoadScore.rounded()))",
                    detail: "\(weeklyCompletedSessions) completed sessions this week.",
                    tone: weeklyCompletedSessions >= 3 ? .forest : .neutral
                )

                KestoStatCard(
                    title: "Planned",
                    value: "\(weeklyCompletedMinutes)/\(max(weeklyPlannedMinutes, weeklyCompletedMinutes)) min",
                    detail: "\(weeklyCompletedSessions) of \(max(weeklyPlannedSessions, weeklyCompletedSessions)) sessions logged.",
                    tone: weeklyCompletedSessions >= weeklyPlannedSessions && weeklyCompletedSessions > 0 ? .forest : .ember
                )
            }

            HomeBalanceCard(
                strengthValue: appState.weeklySummary.strengthBalance,
                enduranceValue: appState.weeklySummary.enduranceBalance,
                trainingSummary: trainingBalanceSummary,
                nextAction: nextActionText
            )

            HomeRecoveryCard(
                latestRecovery: recoveryLogs.first,
                restingHeartRate: hk.restingHeartRate,
                hrv: hk.hrv,
                steps: hk.stepsToday,
                showsSignals: store.hasPremiumAccess && hk.isAuthorized
            )

            CoachInsightCard(
                recommendation: appState.recommendation,
                nextPlannedSession: nextPlannedSession
            ) {
                appState.selectedTab = .coach
            }

            QuickLogCard(
                onLogTap: { appState.selectedTab = .log },
                onCalendarTap: { appState.selectedTab = .calendar },
                onPlanTap: { appState.selectedTab = .plan }
            )

            if let proposal = appState.suggestedPlanAdjustment {
                CoachPlanProposalCard(
                    titleLabel: "Coach adjustment",
                    proposal: proposal,
                    acceptTitle: "apply update",
                    onAccept: {
                        CoachPlanningService.apply(proposal, sessions: sessions, modelContext: modelContext)
                        appState.clearDismissedPlanAdjustmentFingerprint()
                        appState.suggestedPlanAdjustment = nil
                    },
                    onDismiss: { appState.dismissSuggestedPlanAdjustment() }
                )
            }

            if hk.isAuthorized && !hk.recentWorkouts.isEmpty {
                WorkoutsImportBanner { _ in
                    Task {
                        await hk.fetchAll()
                        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs, hk: hk)
                        showImportFeedback()
                    }
                }
            }

            if !hk.isAuthorized && !hk.authorizationDenied && !healthPromptDismissed {
                HealthKitPromptCard {
                    healthPromptDismissed = true
                }
            }

            if !notifications.isAuthorized && !notifications.authorizationDenied && !notificationPromptDismissed {
                NotificationPromptCard {
                    notificationPromptDismissed = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView().environment(notifications)
        }
        .sheet(isPresented: $showLogActivity) {
            LogView()
        }
        .overlay(alignment: .top) {
            if importFeedbackVisible {
                ImportFeedbackToast(text: AppStrings.Today.importConfirmed)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: importFeedbackVisible)
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: .now)
    }

    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var lastSevenDayWindow: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: calendar.startOfDay(for: .now)) }
    }

    private var sessionsByDay: [Date: [Session]] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    }

    private var syncedWorkoutCountByDay: [Date: Int] {
        Dictionary(grouping: hk.recentWorkouts) { calendar.startOfDay(for: $0.endDate) }
            .mapValues(\.count)
    }

    private var lastSevenDayActivity: [Bool] {
        lastSevenDayWindow.map { date in
            let day = calendar.startOfDay(for: date)
            let hasCompletedSession = sessionsByDay[day]?.contains(where: { $0.sessionStatus == .completed }) ?? false
            let hasHealthWorkout = (syncedWorkoutCountByDay[day] ?? 0) > 0
            return hasCompletedSession || hasHealthWorkout
        }
    }

    private var activeDaysThisWeek: Int {
        weekDays.reduce(into: 0) { count, day in
            let normalized = calendar.startOfDay(for: day)
            let hasCompletedSession = sessionsByDay[normalized]?.contains(where: { $0.sessionStatus == .completed }) ?? false
            let hasHealthWorkout = (syncedWorkoutCountByDay[normalized] ?? 0) > 0
            if hasCompletedSession || hasHealthWorkout {
                count += 1
            }
        }
    }

    private var consistencyPercent: Int {
        Int((Double(lastSevenDayActivity.filter { $0 }.count) / Double(max(lastSevenDayActivity.count, 1)) * 100).rounded())
    }

    private var currentStreak: Int {
        var streak = 0
        for active in lastSevenDayActivity.reversed() {
            if active {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var streakSummary: String {
        if currentStreak >= 4 {
            return "You have been showing up with calm consistency."
        }
        if currentStreak >= 1 {
            return "Keep the week alive with one more check-in or session."
        }
        return "A single session today starts the rhythm again."
    }

    private var weekDayStates: [KestoConsistencyState] {
        weekDays.map { day in
            let normalized = calendar.startOfDay(for: day)
            let completed = sessionsByDay[normalized]?.contains(where: { $0.sessionStatus == .completed }) ?? false
            let planned = sessionsByDay[normalized]?.contains(where: { $0.sessionStatus == .planned }) ?? false
            let synced = (syncedWorkoutCountByDay[normalized] ?? 0) > 0

            if completed || synced {
                return KestoConsistencyState(
                    fill: KestoTheme.Colors.ember,
                    border: KestoTheme.Colors.ember.opacity(0.16),
                    text: KestoTheme.Colors.whiteWarm
                )
            }

            if planned {
                return KestoConsistencyState(
                    fill: KestoTheme.Colors.whiteWarm,
                    border: KestoTheme.Colors.ember.opacity(0.18),
                    text: KestoTheme.Colors.ember
                )
            }

            return KestoConsistencyState(
                fill: KestoTheme.Colors.bone.opacity(0.45),
                border: KestoTheme.Colors.borderSoft,
                text: KestoTheme.Colors.ink
            )
        }
    }

    private var nextPlannedSession: Session? {
        sessions
            .filter { $0.sessionStatus == .planned && $0.date >= calendar.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
            .first
    }

    private var weeklyCompletedMinutes: Int {
        sessionsThisWeek
            .filter { $0.sessionStatus == .completed }
            .reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }

    private var weeklyPlannedMinutes: Int {
        sessionsThisWeek
            .filter { $0.sessionStatus == .planned }
            .reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }

    private var weeklyCompletedSessions: Int {
        sessionsThisWeek.filter { $0.sessionStatus == .completed }.count
    }

    private var weeklyPlannedSessions: Int {
        sessionsThisWeek.filter { $0.sessionStatus == .planned }.count
    }

    private var sessionsThisWeek: [Session] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return sessions.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    private var trainingBalanceSummary: String {
        if appState.weeklySummary.strengthBalance > 0.65 {
            return "Strength is leading the week. Add a lighter aerobic touch if recovery allows."
        }
        if appState.weeklySummary.enduranceBalance > 0.65 {
            return "Endurance is carrying the load. A short strength session would rebalance the week."
        }
        return "Your week is balancing strength and endurance well."
    }

    private var nextActionText: String {
        if let step = appState.recommendation.steps.first {
            return step
        }
        if let nextPlannedSession {
            return "\(nextPlannedSession.displayTitle) \(dayString(from: nextPlannedSession.date))."
        }
        return "Log today’s training or recovery check-in."
    }

    private func showImportFeedback() {
        importFeedbackVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            importFeedbackVisible = false
        }
    }

    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

private struct HomeHeader: View {
    let greeting: String
    let dateString: String
    let onLogActivityTap: () -> Void
    let onNotificationsTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: KestoTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppStrings.Brand.displayName)
                    .font(KestoTheme.Typography.label)
                    .tracking(1.8)
                    .foregroundStyle(KestoTheme.Colors.ember)
                Text(greeting)
                    .font(KestoTheme.Typography.screenTitle)
                    .foregroundStyle(KestoTheme.Colors.ink)
                Text(dateString)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
            }

            Spacer()

            HStack(spacing: 10) {
                HeaderIconButton(systemName: "plus", action: onLogActivityTap)
                HeaderIconButton(systemName: "bell", action: onNotificationsTap)
            }
        }
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KestoTheme.Colors.ink)
                .frame(width: 40, height: 40)
                .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeBalanceCard: View {
    let strengthValue: Double
    let enduranceValue: Double
    let trainingSummary: String
    let nextAction: String

    var body: some View {
        KestoCard(style: .elevated) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Training Balance",
                    title: "Load distribution",
                    subtitle: trainingSummary
                )

                LoadBar(
                    label: "Strength",
                    value: strengthValue,
                    detail: "\(Int((strengthValue * 100).rounded()))%"
                )

                LoadBar(
                    label: "Endurance",
                    value: enduranceValue,
                    detail: "\(Int((enduranceValue * 100).rounded()))%"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Today’s focus")
                        .font(KestoTheme.Typography.label)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                    Text(nextAction)
                        .font(KestoTheme.Typography.body)
                        .foregroundStyle(KestoTheme.Colors.ink)
                        .lineSpacing(3)
                }
            }
        }
    }
}

private struct HomeRecoveryCard: View {
    let latestRecovery: RecoveryLog?
    let restingHeartRate: Double?
    let hrv: Double?
    let steps: Int
    let showsSignals: Bool

    var body: some View {
        KestoCard(style: .muted) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Recovery",
                    title: "Readiness",
                    subtitle: summaryText
                )

                if showsSignals {
                    HStack(spacing: 10) {
                        SignalPill(label: "RHR", value: restingHeartRate.map { "\(Int($0)) bpm" } ?? "—")
                        SignalPill(label: "HRV", value: hrv.map { "\(Int($0)) ms" } ?? "—")
                        SignalPill(label: "Steps", value: steps > 0 ? "\(steps.formatted())" : "—")
                    }
                }

                if let latestRecovery {
                    HStack(spacing: 8) {
                        KestoChip("Sleep: \(latestRecovery.sleepQuality.rawValue.capitalized)", tone: latestRecovery.sleepQuality == .good ? .forest : .neutral)
                        KestoChip("Soreness: \(latestRecovery.soreness.rawValue.capitalized)", tone: latestRecovery.soreness == .high ? .ember : .neutral)
                    }
                } else {
                    Text("Add a recovery check-in to sharpen today’s recommendation.")
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                }
            }
        }
    }

    private var summaryText: String {
        guard let latestRecovery else {
            return "Recovery data is light. A quick check-in would make the guidance sharper."
        }

        if latestRecovery.sleepQuality == .good && latestRecovery.soreness == .low {
            return "Signals look steady and supportive for quality work."
        }
        if latestRecovery.soreness == .high || latestRecovery.sleepQuality == .poor {
            return "Recovery looks a bit compromised, so keep the next session measured."
        }
        return "Recovery is acceptable, with room to stay disciplined today."
    }
}

private struct CoachInsightCard: View {
    let recommendation: Recommendation
    let nextPlannedSession: Session?
    let onOpenCoach: () -> Void

    var body: some View {
        KestoCard(style: .elevated) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        KestoChip(recommendation.state.rawValue, tone: recommendation.state == .train ? .forest : .ember)
                        Text(recommendation.context)
                            .font(KestoTheme.Typography.body)
                            .foregroundStyle(KestoTheme.Colors.ink)
                            .lineSpacing(4)
                    }

                    Spacer()
                }

                if !recommendation.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(recommendation.steps.prefix(3).enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(format: "%02d", index + 1))
                                    .font(KestoTheme.Typography.label)
                                    .foregroundStyle(KestoTheme.Colors.slateSoft)
                                    .frame(width: 24, alignment: .leading)
                                Text(step)
                                    .font(KestoTheme.Typography.detail)
                                    .foregroundStyle(KestoTheme.Colors.slate)
                            }
                        }
                    }
                }

                if let nextPlannedSession {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next planned")
                            .font(KestoTheme.Typography.label)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                        Text(nextPlannedSession.displayTitle)
                            .font(KestoTheme.Typography.bodyStrong)
                            .foregroundStyle(KestoTheme.Colors.ink)
                        Text(nextPlannedSession.detailText)
                            .font(KestoTheme.Typography.detail)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                    }
                }

                KestoSecondaryButton(title: "Open coach", icon: "bubble.left.and.bubble.right", action: onOpenCoach)
            }
        }
    }
}

private struct QuickLogCard: View {
    let onLogTap: () -> Void
    let onCalendarTap: () -> Void
    let onPlanTap: () -> Void

    var body: some View {
        KestoCard(style: .muted) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Next Step",
                    title: "Quick actions",
                    subtitle: "Keep momentum without clutter."
                )

                HStack(spacing: 10) {
                    QuickActionButton(title: "Log", icon: "plus", action: onLogTap)
                    QuickActionButton(title: "Calendar", icon: "calendar", action: onCalendarTap)
                    QuickActionButton(title: "Plan", icon: "square.text.square", action: onPlanTap)
                }
            }
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KestoTheme.Colors.ink)
                    .frame(width: 38, height: 38)
                    .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title)
                    .font(KestoTheme.Typography.buttonSmall)
                    .foregroundStyle(KestoTheme.Colors.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(KestoTheme.Colors.bone.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ImportFeedbackToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(KestoTheme.Typography.buttonSmall)
            .foregroundStyle(KestoTheme.Colors.whiteWarm)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(KestoTheme.Colors.ink, in: Capsule())
            .padding(.top, 60)
    }
}

struct HealthKitPromptCard: View {
    @Environment(HealthKitManager.self) private var hk
    let onDismiss: () -> Void

    var body: some View {
        KestoCard(style: .muted) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                KestoSectionHeader(
                    eyebrow: "Health",
                    title: AppStrings.Today.healthPromptTitle.capitalized,
                    subtitle: AppStrings.Today.healthPrompt
                )

                HStack(spacing: 10) {
                    KestoSecondaryButton(title: "Not now", action: onDismiss)
                    KestoPrimaryButton(title: "Connect") {
                        Task { await hk.requestAuthorization() }
                    }
                }
            }
        }
    }
}

struct RecoverySignalRow: View {
    @Environment(HealthKitManager.self) private var hk

    var body: some View {
        HStack(spacing: 14) {
            SignalPill(label: "RHR", value: hk.restingHeartRate.map { "\(Int($0)) bpm" } ?? "—")
            SignalPill(label: "HRV", value: hk.hrv.map { "\(Int($0)) ms" } ?? "—")
            SignalPill(label: "Steps", value: hk.stepsToday > 0 ? "\(hk.stepsToday.formatted())" : "—")
        }
    }
}

struct WorkoutsImportBanner: View {
    @Environment(HealthKitManager.self) private var hk
    let onImport: ([HealthSession]) -> Void

    var body: some View {
        if hk.recentWorkouts.count > 0 {
            KestoCard(style: .muted) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(KestoTheme.Colors.ember)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: AppStrings.Today.importTitleFormat, hk.recentWorkouts.count))
                            .font(KestoTheme.Typography.bodyStrong)
                            .foregroundStyle(KestoTheme.Colors.ink)
                        Text(AppStrings.Today.importBody)
                            .font(KestoTheme.Typography.detail)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                    }

                    Spacer()

                    Button("Import") {
                        onImport(hk.toEngineSessions())
                    }
                    .font(KestoTheme.Typography.buttonSmall)
                    .foregroundStyle(KestoTheme.Colors.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(KestoTheme.Colors.whiteWarm, in: Capsule())
                    .overlay(Capsule().stroke(KestoTheme.Colors.border, lineWidth: 0.9))
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notif.morningBrief") private var morningOn = true
    @AppStorage("notif.eveningReminder") private var eveningOn = true
    @AppStorage("notif.recoveryNudge") private var recoveryOn = true

    var body: some View {
        KestoBottomSheet(
            title: AppStrings.Notifications.settingsTitle.capitalized,
            subtitle: AppStrings.Notifications.settingsSubtitle
        ) {
            if !notifications.isAuthorized {
                KestoCard(style: .muted) {
                    VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                        Text("Enable notifications")
                            .font(KestoTheme.Typography.sectionTitle)
                            .foregroundStyle(KestoTheme.Colors.ink)

                        KestoPrimaryButton(title: "Allow") {
                            Task { await notifications.requestAuthorization() }
                        }
                    }
                }
            }

            KestoCard(style: .elevated) {
                VStack(spacing: KestoTheme.Spacing.lg) {
                    NotificationToggleRow(icon: "sun.horizon", title: "Morning brief", detail: "Today’s recommendation at 8:00", isOn: $morningOn)
                    NotificationToggleRow(icon: "moon", title: "Log reminder", detail: "A calm evening reminder at 20:30", isOn: $eveningOn)
                    NotificationToggleRow(icon: "heart", title: "Recovery check-in", detail: "Midday nudge on lighter days", isOn: $recoveryOn)
                }
            }

            KestoSecondaryButton(title: "Close", action: { dismiss() })
        }
        .background(KestoTheme.Colors.paper)
        .onChange(of: morningOn) { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
        .onChange(of: eveningOn) { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
        .onChange(of: recoveryOn) { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
    }
}

struct NotificationPromptCard: View {
    @Environment(NotificationManager.self) private var notifications
    let onDismiss: () -> Void

    var body: some View {
        KestoCard(style: .muted) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                KestoSectionHeader(
                    eyebrow: "Briefing",
                    title: AppStrings.Today.notificationPromptTitle.capitalized,
                    subtitle: AppStrings.Today.notificationPromptBody
                )

                HStack(spacing: 10) {
                    KestoSecondaryButton(title: "Not now", action: onDismiss)
                    KestoPrimaryButton(title: "Turn on") {
                        Task { await notifications.requestAuthorization() }
                    }
                }
            }
        }
    }
}

private struct SignalPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KestoTheme.Typography.label)
                .foregroundStyle(KestoTheme.Colors.slateSoft)
            Text(value)
                .font(KestoTheme.Typography.bodyStrong)
                .foregroundStyle(KestoTheme.Colors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
        )
    }
}

private struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        KestoListRow(title: title, subtitle: detail) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KestoTheme.Colors.ink)
        } trailing: {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KestoTheme.Colors.ink)
        }
    }
}
#endif
