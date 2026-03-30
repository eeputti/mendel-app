import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MendelEntry: TimelineEntry {
    let date: Date
    let recommendation: SharedRecommendation
}

// MARK: - Timeline Provider

struct MendelProvider: TimelineProvider {

    // Placeholder shown while widget loads (e.g. in widget gallery)
    func placeholder(in context: Context) -> MendelEntry {
        MendelEntry(date: .now, recommendation: .placeholder)
    }

    // Snapshot: shown in widget picker preview — make it look great
    func getSnapshot(in context: Context, completion: @escaping (MendelEntry) -> Void) {
        let rec = SharedRecommendation(
            state:     "TRAIN",
            context:   "load is balanced. you're good to go.",
            steps:     ["strength: 45–60 min, your split", "or run: 5–8 km, moderate pace"],
            updatedAt: .now
        )
        completion(MendelEntry(date: .now, recommendation: rec))
    }

    // Timeline: refresh every 30 min, but main app also triggers reload on log
    func getTimeline(in context: Context, completion: @escaping (Timeline<MendelEntry>) -> Void) {
        let rec   = SharedStore.load()
        let entry = MendelEntry(date: .now, recommendation: rec)

        // Refresh at next 30-min boundary
        let next  = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
}
