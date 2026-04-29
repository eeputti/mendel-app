#if !WIDGET_EXTENSION
//
// OnboardingAnalytics.swift
// Lightweight analytics shim for onboarding instrumentation.
//

import Foundation

enum OnboardingAnalytics {
    static func log(_ event: Event, metadata: [String: String] = [:]) {
        #if DEBUG
        let payload = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        print("[OnboardingAnalytics] \(event.rawValue)\(payload.isEmpty ? "" : " | \(payload)")")
        #endif
    }

    enum Event: String {
        case viewedStep = "viewed_step"
        case tappedContinue = "tapped_continue"
        case tappedBack = "tapped_back"
        case selectedOption = "selected_option"
        case personalizationStarted = "personalization_started"
        case personalizationCompleted = "personalization_completed"
        case commitmentSigned = "commitment_signed"
        case accountContinue = "account_continue"
        case notificationsPrompted = "notifications_prompted"
        case healthPrompted = "health_prompted"
        case paywallViewed = "paywall_viewed"
        case paywallPurchased = "paywall_purchased"
        case completedOnboarding = "completed_onboarding"
    }
}
#endif
