import Foundation

enum MendelGroup {
    static let identifier = "group.com.dipworks.mendel"
}

struct SharedRecommendation: Codable {
    let state: String
    let context: String
    let steps: [String]
    let updatedAt: Date

    var stepsSummary: String {
        steps.prefix(2).joined(separator: " · ")
    }

    static let placeholder = SharedRecommendation(
        state: "TRAIN",
        context: "open mendel to get started",
        steps: ["log your first session", "get your recommendation"],
        updatedAt: .now
    )
}

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
        else { return .placeholder }
        return rec
    }
}

enum MendelWidgetKind {
    static let today = "MendelTodayWidget"
}
