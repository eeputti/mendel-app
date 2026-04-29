//
// AppStrings.swift
// Centralized user-facing copy and shared app identity strings.
//

import Foundation

enum AppStrings {
    enum Brand {
        static let displayName = "KESTO"
        static let displayNameLowercased = "kesto"
        static let tagline = "Built to endure."
    }

    enum DeepLinks {
        static let scheme = "mendel"
        static let today = "\(scheme)://today"
        static let log = "\(scheme)://log"
    }

    enum Today {
        static let healthPrompt = "\(Brand.displayName) reads your workouts, heart rate, and HRV from Apple Health to sharpen daily guidance."
        static let importConfirmed = "Health workouts folded into today’s signal."
        static let headerLabel = Brand.displayName
        static let headerSupport = Brand.tagline
        static let actionLabel = "Today"
        static let statusLabel = "Readiness"
        static let loadLabel = "Weekly balance"
        static let notificationPromptTitle = "daily brief"
        static let notificationPromptBody = "Get a calm morning read and an evening logging reminder."
        static let healthPromptTitle = "connect health"
        static let importTitleFormat = "%d workouts in Apple Health"
        static let importBody = "Refresh your signal with the latest training data."
        static let primaryCTA = "log training"
    }

    enum Notifications {
        static let openRecommendation = "open \(Brand.displayNameLowercased) to see today's recommendation."
        static let settingsTitle = "notifications"
        static let settingsSubtitle = "calm reminders. never noise."
    }

    enum Profile {
        static let about = "\(Brand.displayName) keeps your recommendations, coaching, and training signals aligned for long-term progress."
    }

    enum Shared {
        static let placeholderContext = "open \(Brand.displayNameLowercased) to get started"
    }

    enum Paywall {
        static let brandLabel = Brand.displayNameLowercased
    }

    enum Widget {
        static let brandLabel = Brand.displayNameLowercased
        static let displayName = Brand.displayName
        static let openPrompt = "tap to open \(Brand.displayNameLowercased)"
    }
}
