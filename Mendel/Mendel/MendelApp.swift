import SwiftUI
import SwiftData

// MARK: - MendelApp v3
// Replaces MendelApp.swift — registers notification delegate.

@main
struct MendelApp: App {

    // Keep a strong reference — delegate must outlive the notification center
    private let notifDelegate = MendelNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [Session.self, RecoveryLog.self])
        }
    }
}
