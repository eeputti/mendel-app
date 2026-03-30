import UserNotifications
import SwiftUI

// MARK: - Notification Identifiers

enum NotificationID {
    static let dailyLog       = "mendel.daily.log"
    static let morningBrief   = "mendel.morning.brief"
    static let recoveryNudge  = "mendel.recovery.nudge"
    static let streakReminder = "mendel.streak.reminder"
}

// MARK: - Notification Manager

@Observable
final class NotificationManager {

    var isAuthorized: Bool = false
    var authorizationDenied: Bool = false

    private let center = UNUserNotificationCenter.current()

    init() {
        Task { await checkStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
                authorizationDenied = !granted
            }
            if granted { await scheduleAll() }
        } catch {
            await MainActor.run { authorizationDenied = true }
        }
    }

    func checkStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule All

    /// Call after authorization and after recommendation changes.
    func scheduleAll(recommendation: SharedRecommendation? = nil) async {
        await center.removeAllPendingNotificationRequests()

        await scheduleMorningBrief(recommendation: recommendation)
        await scheduleDailyLogReminder()
        await scheduleRecoveryNudge(recommendation: recommendation)
    }

    // MARK: - Morning Brief (08:00)
    // "today: recover — walk 20 min + light mobility"

    private func scheduleMorningBrief(recommendation: SharedRecommendation?) async {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive  // no wake-up sound, shows quietly

        if let rec = recommendation {
            content.title = "today: \(rec.state.lowercased())"
            content.body  = rec.steps.prefix(2).joined(separator: " · ")
        } else {
            content.title = "good morning"
            content.body  = "open mendel to see today's recommendation."
        }

        // Deep link directly to Today tab
        content.userInfo = ["deeplink": "mendel://today"]

        var components = DateComponents()
        components.hour   = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.morningBrief,
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Daily Log Reminder (20:30)
    // Varies based on whether user has already logged today

    func scheduleDailyLogReminder(hasLoggedToday: Bool = false) async {
        guard !hasLoggedToday else {
            // Already logged — cancel the reminder for today
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog])
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive

        let variants: [(title: String, body: String)] = [
            ("log today's session", "keep your data clean. it takes 20 seconds."),
            ("did you train today?", "log it before you forget."),
            ("one tap to log", "your week view is only as good as your logs."),
            ("today's session?", "30 seconds. tap to log."),
        ]

        // Rotate through variants by day of year
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let variant   = variants[dayOfYear % variants.count]

        content.title    = variant.title
        content.body     = variant.body
        content.userInfo = ["deeplink": "mendel://log"]

        var components = DateComponents()
        components.hour   = 20
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.dailyLog,
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Recovery Nudge (sent when engine outputs RECOVER/REST)
    // Fires at 12:00 on recover days as a midday check-in

    private func scheduleRecoveryNudge(recommendation: SharedRecommendation?) async {
        guard let rec = recommendation,
              rec.state == "RECOVER" || rec.state == "REST" else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.recoveryNudge])
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .passive

        if rec.state == "REST" {
            content.title = "rest day"
            content.body  = "no training today. your body is working even when you're not."
        } else {
            content.title = "recovery day"
            content.body  = rec.steps.first ?? "keep it easy today."
        }

        content.userInfo = ["deeplink": "mendel://today"]

        // Fire once at 12:00 today (non-repeating)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour   = 12
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.recoveryNudge,
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel all

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Called from AppState when a new log is saved
    // Cancels the evening reminder for today since user already logged.

    func didLogSession() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog])
    }
}
