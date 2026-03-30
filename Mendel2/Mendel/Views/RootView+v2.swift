import SwiftUI
import SwiftData

// MARK: - RootView v2
// Replaces RootView.swift — injects PurchaseManager + HealthKitManager.

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appState      = AppState()
    @State private var purchaseManager = PurchaseManager()
    @State private var healthKit     = HealthKitManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .today: TodayView()
                case .log:   LogView()
                case .week:  WeekView()
                case .coach: CoachView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MendelTabBar()
        }
        .environment(appState)
        .environment(purchaseManager)
        .environment(healthKit)
        .ignoresSafeArea(edges: .bottom)
        .background(MendelColors.bg)
        .onChange(of: sessions.count)        { recompute() }
        .onChange(of: recoveryLogs.count)    { recompute() }
        .onChange(of: healthKit.recentWorkouts.count) { recompute() }
        .onChange(of: healthKit.hrv)         { recompute() }
        .onChange(of: healthKit.restingHeartRate) { recompute() }
        .onAppear {
            recompute()
            Task { await healthKit.requestAuthorization() }
        }
    }

    private func recompute() {
        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs, hk: healthKit)
    }
}
