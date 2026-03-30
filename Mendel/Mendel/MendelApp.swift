import SwiftUI
import SwiftData

@main
struct MendelApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [Session.self, RecoveryLog.self])
        }
    }
}
