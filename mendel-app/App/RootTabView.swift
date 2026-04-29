#if !WIDGET_EXTENSION
//
// RootTabView.swift
// Root app container with custom tab switching.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @Environment(MendelAppState.self) private var appState
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(NotificationManager.self) private var notificationManager

    var body: some View {
        Group {
            switch appState.selectedTab {
            case .home:
                TodayView()
            case .calendar:
                CalendarView()
            case .coach:
                CoachView()
            case .plan:
                PlanView()
            case .profile:
                ProfileView()
            case .log:
                LogView()
            }
        }
        .background(MendelColors.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MendelTabBar()
        }
        .onOpenURL { url in
            DeepLinkHandler.handle(url: url, state: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mendelDeepLink)) { note in
            if let url = note.object as? URL {
                DeepLinkHandler.handle(url: url, state: appState)
            }
        }
        .onChange(of: sessionRefreshKey) { recompute() }
        .onChange(of: recoveryLogs.count) { recompute() }
        .onChange(of: healthKit.recentWorkouts.count) { recompute() }
        .onChange(of: healthKit.hrv) { recompute() }
        .onChange(of: healthKit.restingHeartRate) { recompute() }
        .onAppear {
            recompute()
        }
    }

    private func recompute() {
        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs, hk: healthKit)
        Task {
            await notificationManager.scheduleAll(recommendation: SharedStore.load())
        }
    }

    private var sessionRefreshKey: [String] {
        sessions.map {
            [
                $0.id.uuidString,
                String($0.date.timeIntervalSince1970),
                $0.sessionStatus.rawValue,
                $0.displayCategory.rawValue,
                $0.subtype ?? "",
                $0.notes ?? ""
            ].joined(separator: "|")
        }
    }
}
#endif
