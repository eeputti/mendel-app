# Mendel

> A minimal decision system for hybrid athletes.

---

## Project Structure

```
Mendel/
├── MendelApp.swift              # App entry + SwiftData container
├── Models/
│   ├── Models.swift             # Session, RecoveryLog + enums
│   └── AppState.swift           # @Observable app state
├── Engine/
│   └── DecisionEngine.swift     # Core logic: TRAIN / RECOVER / REST
├── Services/
│   └── ClaudeService.swift      # Anthropic API integration
├── Views/
│   ├── RootView.swift           # Tab container
│   ├── Components/
│   │   ├── DesignSystem.swift   # Colors, type, spacing constants
│   │   └── Components.swift     # Reusable UI components
│   ├── Today/
│   │   └── TodayView.swift      # Main recommendation screen
│   ├── Log/
│   │   └── LogView.swift        # Activity logging
│   ├── Week/
│   │   └── WeekView.swift       # Weekly overview
│   └── Coach/
│       └── CoachView.swift      # AI coach chat
└── Resources/
    └── Colors.md                # Asset catalog color spec
```

---

## Setup

### 1. Create Xcode Project
- New Project → iOS App
- Interface: SwiftUI
- Storage: SwiftData
- Minimum deployment: iOS 17

### 2. Add Files
Drop all files into the Xcode project, maintaining the folder structure.

### 3. Color Assets
In Assets.xcassets, create named colors per `Resources/Colors.md`.
Or use the fallback inline colors (already in DesignSystem.swift) for initial dev.

### 4. Claude API Key
In `Services/ClaudeService.swift`, replace:
```swift
private let apiKey = "YOUR_ANTHROPIC_API_KEY"
```
For production, load from Keychain or a config file (never hardcode in shipping app).

### 5. Build & Run
No external dependencies. Pure SwiftUI + SwiftData.

---

## Architecture

```
SwiftData (Session, RecoveryLog)
        ↓
    AppState (@Observable)
        ↓
  DecisionEngine.recommend()
        ↓
  Recommendation { state, context, steps }
        ↓
  TodayView (observes AppState)
```

AppState refreshes automatically whenever sessions or recoveryLogs change (via `.onChange` in RootView).

---

## Decision Engine Rules

| Condition                          | Output  |
|------------------------------------|---------|
| Soreness == high                   | RECOVER |
| Total load > 14                    | RECOVER |
| Total load > 8 + sleep == poor     | REST    |
| Total load < 4                     | TRAIN   |
| Only strength, no cardio (3+ days) | TRAIN → run |
| Only cardio, no strength (3+ days) | TRAIN → lift |
| Moderate load, medium soreness     | TRAIN (light) |
| Default                            | TRAIN   |

Load score per session:
- Strength: `min((sets × reps / 24) × intensity, 5)`
- Run: `min(km × intensity × 0.3, 5)`
- Sport: `min(hours × intensity, 5)`

---

## Coach AI

The Coach screen sends the full conversation to Claude claude-sonnet-4-20250514 with a system prompt
containing the user's weekly context (load, sessions, sleep, soreness).

The system prompt enforces Mendel's tone: calm, direct, specific. No hype.

Free tier (future): limit to 3 Coach queries/week via StoreKit 2 gate.

---

## Roadmap

- [ ] StoreKit 2 one-time purchase (€14.99)
- [ ] HealthKit integration (heart rate, steps)
- [ ] Notification: "time to log?" at end of day
- [ ] Apple Watch companion (log from wrist)
- [ ] iCloud sync via CloudKit
- [ ] Widgets (Today recommendation on home screen)
