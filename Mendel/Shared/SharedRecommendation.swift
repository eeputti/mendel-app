import Foundation

// MARK: - App Group Identifier
// Must match exactly in:
//   1. Main app target → Signing & Capabilities → App Groups
//   2. Widget extension target → Signing & Capabilities → App Groups
//   3. This file

enum MendelGroup {
    static let identifier = "group.com.dipworks.mendel"
}

// MARK: - Shared Recommendation Entry
// Written by the main app, read by the widget.
// Stored in UserDefaults(suiteName:) — lightweight, fast, widget-safe.

struct SharedRecommendation: Codable {
    let state:   String   // "TRAIN" | "RECOVER" | "REST"
    let context: String
    let steps:   [String]
    let updatedAt: Date

    // Convenience
    var stateDisplay: String { state }

    var stepsSummary: String {
        // First 2 steps joined for small widget
        steps.prefix(2).joined(separator: " · ")
    }

    static let placeholder = SharedRecommendation(
        state:     "TRAIN",
        context:   "open mendel to get started",
        steps:     ["log your first session", "get your recommendation"],
        updatedAt: .now
    )
}

// MARK: - Shared Store

enum SharedStore {
    private static let key = "mendel_recommendation"

    static func save(_ rec: SharedRecommendation) {
        guard let defaults = UserDefaults(suiteName: MendelGroup.identifier) else { return }
        let data = try? JSONEncoder().encode(rec)
        defaults.set(data, forKey: key)
    }

    static func load() -> SharedRecommendation {
        guard
            let defaults = UserDefaults(suiteName: MendelGroup.identifier),
            let data = defaults.data(forKey: key),
            let rec = try? JSONDecoder().decode(SharedRecommendation.self, from: data)
        else {
            return .placeholder
        }
        return rec
    }
}
