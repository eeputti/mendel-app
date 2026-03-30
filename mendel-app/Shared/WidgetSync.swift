import Foundation
import WidgetKit

// MARK: - Widget Sync
// Add this to AppState.refresh() after computing the recommendation.
// Writes to the shared App Group so the widget always shows current state.

extension AppState {

    /// Call at the end of refresh() to keep widget in sync.
    func syncWidget() {
        let shared = SharedRecommendation(
            state:     recommendation.state.rawValue,
            context:   recommendation.context,
            steps:     recommendation.steps,
            updatedAt: .now
        )
        SharedStore.save(shared)

        // Tell WidgetKit to reload all Mendel timelines immediately
        WidgetCenter.shared.reloadTimelines(ofKind: MendelWidgetKind.today)
    }
}

enum MendelWidgetKind {
    static let today = "MendelTodayWidget"
}
