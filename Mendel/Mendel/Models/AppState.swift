import SwiftUI
import SwiftData

// MARK: - App State (single source of truth)

@Observable
final class AppState {

    // Navigation
    var selectedTab: Tab = .today

    // Today
    var recommendation: Recommendation = Recommendation(
        state: .train,
        context: "loading your data…",
        steps: []
    )

    // Log sheet
    var showingLogSheet = false

    // Weekly summary
    var weeklySummary: WeeklySummary = WeeklySummary(
        strengthSessions: 0,
        enduranceSessions: 0,
        recoverySessions: 0,
        totalLoadScore: 0,
        strengthBalance: 0,
        enduranceBalance: 0
    )

    // Recompute from SwiftData on each launch / change
    func refresh(sessions: [Session], recoveryLogs: [RecoveryLog]) {
        let latest = recoveryLogs.sorted { $0.date > $1.date }.first
        recommendation = DecisionEngine.recommend(sessions: sessions, latestRecovery: latest)
        weeklySummary  = WeeklySummary.compute(sessions: sessions)
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
