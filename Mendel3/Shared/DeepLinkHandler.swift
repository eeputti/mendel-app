import SwiftUI

// MARK: - Deep Link Handler
// Add .onOpenURL to RootView to handle widget taps.
//
// Usage: add this modifier to the ZStack in RootView (v2):
//
//   .onOpenURL { url in
//       DeepLinkHandler.handle(url: url, appState: appState)
//   }

enum DeepLinkHandler {

    static func handle(url: URL, appState: AppState) {
        guard url.scheme == "mendel" else { return }
        switch url.host {
        case "today":  appState.selectedTab = .today
        case "log":    appState.selectedTab = .log
        case "week":   appState.selectedTab = .week
        case "coach":  appState.selectedTab = .coach
        default:       appState.selectedTab = .today
        }
    }
}

// MARK: - URL Scheme Setup
// In Xcode → Target (main app) → Info → URL Types:
//   Identifier: com.dipworks.mendel
//   URL Schemes: mendel
//
// This enables mendel://today, mendel://log, etc.
