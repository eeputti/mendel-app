import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appState = AppState()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active screen
            Group {
                switch appState.selectedTab {
                case .today: TodayView()
                case .log:   LogView()
                case .week:  WeekView()
                case .coach: CoachView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            MendelTabBar()
        }
        .environment(appState)
        .ignoresSafeArea(edges: .bottom)
        .background(MendelColors.background)
        .onChange(of: sessions.count)     { recompute() }
        .onChange(of: recoveryLogs.count) { recompute() }
        .onAppear { recompute() }
    }

    private func recompute() {
        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs)
    }
}
