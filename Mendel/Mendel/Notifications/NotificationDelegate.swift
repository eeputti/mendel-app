import UserNotifications
import SwiftUI

// MARK: - Notification Delegate
// Handles notification taps and foreground delivery.
// Register in MendelApp.init() — see integration notes below.

final class MendelNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // Called when a notification is tapped — routes deep link to the app
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let deeplink = userInfo["deeplink"] as? String,
           let url = URL(string: deeplink) {
            // Post to NotificationCenter — RootView listens and routes the tab
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .mendelDeepLink,
                    object: url
                )
            }
        }

        completionHandler()
    }

    // Show notifications as banners even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let mendelDeepLink = Notification.Name("mendel.deeplink")
}

// MARK: - Integration Notes
//
// 1. In MendelApp.swift, register the delegate:
//
//    @main
//    struct MendelApp: App {
//        private let notifDelegate = MendelNotificationDelegate()
//
//        init() {
//            UNUserNotificationCenter.current().delegate = notifDelegate
//        }
//
//        var body: some Scene {
//            WindowGroup {
//                RootView()
//                    .modelContainer(for: [Session.self, RecoveryLog.self])
//            }
//        }
//    }
//
// 2. In RootView, listen for the deep link notification:
//
//    .onReceive(NotificationCenter.default.publisher(for: .mendelDeepLink)) { note in
//        if let url = note.object as? URL {
//            DeepLinkHandler.handle(url: url, appState: appState)
//        }
//    }
//
// 3. Inject NotificationManager into environment in RootView:
//
//    @State private var notificationManager = NotificationManager()
//    // ...
//    .environment(notificationManager)
//
// 4. Add settings button to TodayView header:
//
//    @State private var showingSettings = false
//    // ...
//    .sheet(isPresented: $showingSettings) {
//        NotificationSettingsView()
//            .environment(notificationManager)
//    }
//
// 5. In AppState.refresh(), after syncWidget(), add:
//
//    Task {
//        await notificationManager.scheduleAll(recommendation: SharedStore.load())
//    }
//
// 6. In LogView, after saving a session, call:
//
//    notificationManager.didLogSession()
//    // This cancels the evening log reminder since user already logged today.
