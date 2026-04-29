#if !WIDGET_EXTENSION
//
// MendelAppState.swift
// Shared app state and routing helpers.
//

import SwiftUI
import WidgetKit

enum MendelTab: String, CaseIterable {
    case home = "Home"
    case calendar = "Calendar"
    case coach = "Coach"
    case plan = "Plan"
    case profile = "Profile"
    case log = "Log"

    static let tabBarTabs: [MendelTab] = [.home, .calendar, .coach, .plan, .profile]

    var icon: String {
        switch self {
        case .home:
            return "house"
        case .calendar:
            return "calendar"
        case .coach:
            return "bubble.left.and.bubble.right"
        case .plan:
            return "square.text.square"
        case .profile:
            return "person"
        case .log:
            return "plus.circle"
        }
    }
}

@Observable
final class MendelAppState {
    var selectedTab: MendelTab = .home
    var recommendation = Recommendation(state: .train, context: "loading…", steps: [])
    var weeklySummary = WeeklySummary(
        strengthSessions: 0,
        enduranceSessions: 0,
        recoverySessions: 0,
        totalLoadScore: 0,
        strengthBalance: 0,
        enduranceBalance: 0
    )
    var suggestedPlanAdjustment: PlanAdjustmentProposal?
    var healthPromptDismissed = false
    private let dismissedPlanAdjustmentKey = "coach.dismissedPlanAdjustmentFingerprint"

    func refresh(sessions: [Session], recoveryLogs: [RecoveryLog], hk: HealthKitManager) {
        let completedSessions = sessions.filter { $0.sessionStatus == .completed }
        let healthSessions = hk.toEngineSessions()
        let latest = recoveryLogs.sorted { $0.date > $1.date }.first
        recommendation = DecisionEngine.recommend(
            sessions: completedSessions,
            healthSessions: healthSessions,
            latestRecovery: latest,
            restingHeartRate: hk.restingHeartRate,
            hrv: hk.hrv
        )
        weeklySummary = WeeklySummary.compute(sessions: completedSessions)
        let proposal = CoachPlanningService.detectAdjustmentProposal(
            sessions: sessions,
            healthSessions: healthSessions
        )
        let dismissedFingerprint = UserDefaults.standard.string(forKey: dismissedPlanAdjustmentKey)
        suggestedPlanAdjustment = proposal?.fingerprint == dismissedFingerprint ? nil : proposal
        syncWidget()
    }

    func dismissSuggestedPlanAdjustment() {
        guard let fingerprint = suggestedPlanAdjustment?.fingerprint else { return }
        UserDefaults.standard.set(fingerprint, forKey: dismissedPlanAdjustmentKey)
        suggestedPlanAdjustment = nil
    }

    func clearDismissedPlanAdjustmentFingerprint() {
        UserDefaults.standard.removeObject(forKey: dismissedPlanAdjustmentKey)
    }

    func syncWidget() {
        let shared = SharedRecommendation(
            state: recommendation.state.rawValue,
            context: recommendation.context,
            steps: recommendation.steps,
            updatedAt: .now
        )
        SharedStore.save(shared)
        WidgetCenter.shared.reloadTimelines(ofKind: MendelWidgetKind.today)
    }
}

enum DeepLinkHandler {
    static func handle(url: URL, state: MendelAppState) {
        guard url.scheme == AppStrings.DeepLinks.scheme else { return }
        switch url.host {
        case "today":
            state.selectedTab = .home
        case "home":
            state.selectedTab = .home
        case "calendar":
            state.selectedTab = .calendar
        case "log":
            state.selectedTab = .log
        case "week", "plan":
            state.selectedTab = .plan
        case "coach":
            state.selectedTab = .coach
        case "profile", "settings":
            state.selectedTab = .profile
        default:
            state.selectedTab = .home
        }
    }
}
#endif
