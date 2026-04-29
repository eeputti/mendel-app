#if !WIDGET_EXTENSION
//
// MendelApp.swift
// Main app entry point.
//

import SwiftUI
import SwiftData
import UserNotifications

private let notifDelegate = MendelNotificationDelegate()

@main
struct MendelApp: App {
    @State private var appState = MendelAppState()
    @State private var purchaseManager = PurchaseManager()
    @State private var healthKit = HealthKitManager()
    @State private var notificationManager = NotificationManager()
    @State private var onboardingStore = OnboardingStore()

    init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
    }

    var body: some Scene {
        WindowGroup {
            AppContainerView()
                .environment(appState)
                .environment(purchaseManager)
                .environment(healthKit)
                .environment(notificationManager)
                .environment(onboardingStore)
                .modelContainer(for: [Session.self, RecoveryLog.self])
        }
    }
}
#endif
