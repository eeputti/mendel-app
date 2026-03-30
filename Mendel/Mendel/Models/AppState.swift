import SwiftUI
import SwiftData

// MARK: - AppState v2
// Drop-in replacement for AppState.swift — adds HealthKit + purchase awareness.

@Observable
final class AppState {

    // Navigation
    var selectedTab: Tab = .today

    // Recommendation
    var recommendation: Recommendation = Recommendation(
        state: .train,
        context: "loading your data…",
        steps: []
    )

    // Weekly summary
    var weeklySummary: WeeklySummary = WeeklySummary(
        strengthSessions:  0,
        enduranceSessions: 0,
        recoverySessions:  0,
        totalLoadScore:    0,
        strengthBalance:   0,
        enduranceBalance:  0
    )

    // HealthKit prompt dismissed
    var healthPromptDismissed: Bool = false

    // MARK: - Refresh (called from RootView on data change)

    func refresh(
        sessions: [Session],
        recoveryLogs: [RecoveryLog],
        hk: HealthKitManager
    ) {
        let latest = recoveryLogs.sorted { $0.date > $1.date }.first

        recommendation = DecisionEngine.recommend(
            sessions:         sessions,
            healthSessions:   hk.toEngineSessions(),
            latestRecovery:   latest,
            restingHeartRate: hk.restingHeartRate,
            hrv:              hk.hrv
        )

        weeklySummary = WeeklySummary.compute(sessions: sessions)
    }
}

enum Tab: String, CaseIterable {
    case today  = "Today"
    case log    = "Log"
    case week   = "Week"
    case coach  = "Coach"

    var icon: String {
        switch self {
        case .today: return "circle.fill"
        case .log:   return "plus"
        case .week:  return "chart.bar"
        case .coach: return "bubble.left"
        }
    }
}
