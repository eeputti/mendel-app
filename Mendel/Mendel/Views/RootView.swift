import SwiftUI
import SwiftData

// MARK: - RootView v3
// Replaces RootView+v2.swift
// Adds: NotificationManager environment + deep link listener from notifications.

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appState           = AppState()
    @State private var purchaseManager    = PurchaseManager()
    @State private var healthKit          = HealthKitManager()
    @State private var notificationManager = NotificationManager()

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
        .environment(notificationManager)
        .ignoresSafeArea(edges: .bottom)
        .background(MendelColors.bg)
        // Widget tap deep links
        .onOpenURL { url in
            DeepLinkHandler.handle(url: url, appState: appState)
        }
        // Notification tap deep links
        .onReceive(NotificationCenter.default.publisher(for: .mendelDeepLink)) { note in
            if let url = note.object as? URL {
                DeepLinkHandler.handle(url: url, appState: appState)
            }
        }
        .onChange(of: sessions.count)                     { recompute() }
        .onChange(of: recoveryLogs.count)                 { recompute() }
        .onChange(of: healthKit.recentWorkouts.count)     { recompute() }
        .onChange(of: healthKit.hrv)                      { recompute() }
        .onChange(of: healthKit.restingHeartRate)         { recompute() }
        .onAppear {
            recompute()
            Task { await healthKit.requestAuthorization() }
        }
    }

    private func recompute() {
        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs, hk: healthKit)

        // Re-schedule notifications with latest recommendation
        Task {
            await notificationManager.scheduleAll(recommendation: SharedStore.load())
        }
    }
}
