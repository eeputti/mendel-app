# Mendel Widget — Integration Guide

---

## 1. Add Widget Extension in Xcode

1. File → New → Target → Widget Extension
2. Name: `MendelWidget`
3. Include Configuration Intent: **No** (we use StaticConfiguration)
4. Activate scheme when prompted: **Yes**

---

## 2. App Group (critical — this is how app & widget share data)

### Main App Target:
Signing & Capabilities → + Capability → **App Groups**
Add: `group.com.dipworks.mendel`

### Widget Target:
Same — add the same App Group: `group.com.dipworks.mendel`

Both targets must share the **same App Group ID** or the widget will always show the placeholder.

---

## 3. Add Files to Each Target

| File | Main App | Widget |
|---|:---:|:---:|
| `Shared/SharedRecommendation.swift` | ✓ | ✓ |
| `Shared/WidgetSync.swift` | ✓ | — |
| `Shared/DeepLinkHandler.swift` | ✓ | — |
| `MendelWidget/MendelProvider.swift` | — | ✓ |
| `MendelWidget/MendelWidgetViews.swift` | — | ✓ |
| `MendelWidget/MendelWidget.swift` | — | ✓ |

To assign a file to a target: select the file → File Inspector (right panel) → Target Membership.

---

## 4. Wire syncWidget() into AppState

In `AppState+v2.swift`, update the `refresh()` method:

```swift
func refresh(sessions: [Session], recoveryLogs: [RecoveryLog], hk: HealthKitManager) {
    // ... existing logic ...
    weeklySummary = WeeklySummary.compute(sessions: sessions)

    // ADD THIS LINE:
    syncWidget()
}
```

This writes the recommendation to the App Group and triggers a WidgetKit reload every time the engine recomputes.

---

## 5. Add Deep Link Handler to RootView

In `RootView+v2.swift`, add `.onOpenURL` to the main ZStack:

```swift
ZStack(alignment: .bottom) {
    // ... existing content ...
}
.onOpenURL { url in
    DeepLinkHandler.handle(url: url, appState: appState)
}
```

---

## 6. URL Scheme (for widget tap → open app)

Target (main app) → Info → URL Types → + :
- Identifier: `com.dipworks.mendel`
- URL Schemes: `mendel`

This enables `mendel://today` deep links from the widget.

---

## 7. Widget Sizes Supported

| Size | Family | Use case |
|---|---|---|
| Small (2×2) | `.systemSmall` | Quick glance — state word only |
| Medium (4×2) | `.systemMedium` | State + 2 steps |
| Large (4×4) | `.systemLarge` | Full recommendation + all steps |
| Lock Screen bar | `.accessoryRectangular` | State + context on lock screen |
| Lock Screen inline | `.accessoryInline` | State word only (Watch-style) |

---

## 8. Testing in Simulator

1. Run the main app target first (populates the App Group)
2. Switch scheme to `MendelWidget`
3. Run → widget previews appear in the widget gallery
4. Or: long-press home screen → + → search "Mendel"

To test different states, temporarily add a mock write to `SharedStore` at app launch:

```swift
SharedStore.save(SharedRecommendation(
    state: "RECOVER",
    context: "high load this week. give it a day.",
    steps: ["walk 20 min", "light mobility", "sleep early"],
    updatedAt: .now
))
```

---

## 9. How the Data Flow Works

```
User logs session
      ↓
AppState.refresh()
      ↓
DecisionEngine.recommend() → Recommendation
      ↓
SharedStore.save() → UserDefaults(App Group)
      ↓
WidgetCenter.reloadTimelines()
      ↓
MendelProvider.getTimeline() → SharedStore.load()
      ↓
Widget re-renders on home screen
```

The widget never runs the decision engine itself — it just reads what the app wrote. This keeps the widget fast and battery-efficient.
