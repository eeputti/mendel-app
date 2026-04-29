#if !WIDGET_EXTENSION
//
// NotificationManager.swift
// Daily and recovery reminder scheduling.
//

import Foundation
import UserNotifications

enum NotificationID {
    static let dailyLog = "mendel.daily.log"
    static let morningBrief = "mendel.morning.brief"
    static let recoveryNudge = "mendel.recovery.nudge"
}

private enum NotificationPreferenceKey {
    static let morningBrief = "notif.morningBrief"
    static let eveningReminder = "notif.eveningReminder"
    static let recoveryNudge = "notif.recoveryNudge"
}

@Observable
final class NotificationManager {
    var isAuthorized = false
    var authorizationDenied = false
    private let center = UNUserNotificationCenter.current()

    init() {
        Task { await checkStatus() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
                authorizationDenied = !granted
            }
            if granted {
                await scheduleAll()
            }
        } catch {
            await MainActor.run { authorizationDenied = true }
        }
    }

    func checkStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
            authorizationDenied = settings.authorizationStatus == .denied
        }
    }

    func scheduleAll(recommendation: SharedRecommendation? = nil) async {
        await checkStatus()
        center.removeAllPendingNotificationRequests()
        guard isAuthorized else { return }

        if isNotificationEnabled(NotificationPreferenceKey.morningBrief) {
            await scheduleMorning(recommendation: recommendation)
        }
        if isNotificationEnabled(NotificationPreferenceKey.eveningReminder) {
            await scheduleEvening()
        }
        if isNotificationEnabled(NotificationPreferenceKey.recoveryNudge) {
            await scheduleRecovery(recommendation: recommendation)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.recoveryNudge])
        }
    }

    func scheduleEvening(hasLoggedToday: Bool = false) async {
        guard !hasLoggedToday else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog])
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive
        content.title = "log today's session"
        content.body = "keep your data clean. it takes 20 seconds."
        content.userInfo = ["deeplink": AppStrings.DeepLinks.log]

        var components = DateComponents()
        components.hour = 20
        components.minute = 30

        let request = UNNotificationRequest(
            identifier: NotificationID.dailyLog,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    func didLogSession() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog])
    }

    private func scheduleMorning(recommendation: SharedRecommendation?) async {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive
        if let recommendation {
            content.title = "today: \(recommendation.state.lowercased())"
            content.body = recommendation.steps.prefix(2).joined(separator: " · ")
        } else {
            content.title = "good morning"
            content.body = AppStrings.Notifications.openRecommendation
        }
        content.userInfo = ["deeplink": AppStrings.DeepLinks.today]

        var components = DateComponents()
        components.hour = 8
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: NotificationID.morningBrief,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    private func scheduleRecovery(recommendation: SharedRecommendation?) async {
        guard let recommendation, recommendation.state == "RECOVER" || recommendation.state == "REST" else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.recoveryNudge])
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive
        content.title = recommendation.state == "REST" ? "rest day" : "recovery day"
        content.body = recommendation.steps.first ?? "keep it easy today."
        content.userInfo = ["deeplink": AppStrings.DeepLinks.today]

        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = 12
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: NotificationID.recoveryNudge,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    private func isNotificationEnabled(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        guard let value = defaults.object(forKey: key) as? Bool else {
            return true
        }
        return value
    }
}

final class MendelNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let deeplink = response.notification.request.content.userInfo["deeplink"] as? String,
           let url = URL(string: deeplink) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .mendelDeepLink, object: url)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let mendelDeepLink = Notification.Name("mendel.deeplink")
}
#endif
