# Mendel — Setup Guide: StoreKit 2 + HealthKit

---

## 1. Info.plist Keys

Add these to your Info.plist (or Target → Info tab in Xcode):

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>Mendel reads your workouts, heart rate, and HRV to improve training recommendations.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Mendel does not write to Apple Health.</string>

<!-- Required for HealthKit capability -->
<!-- Enable in Target → Signing & Capabilities → + Capability → HealthKit -->
```

---

## 2. Xcode Capabilities

In Target → Signing & Capabilities, add:

- **HealthKit** — enables HKHealthStore
- **In-App Purchase** — required for StoreKit 2 (auto-added with StoreKit)

---

## 3. App Store Connect — In-App Purchase Setup

1. Go to App Store Connect → Your App → In-App Purchases
2. Click **+** → Non-Consumable
3. Product ID: `com.dipworks.mendel.unlock`
4. Reference Name: `Mendel Unlock`
5. Price: Tier 10 (€9.99) or Tier 15 (€14.99)
6. Localisation: Add EN + FI descriptions
7. Review Information: Screenshot of paywall

---

## 4. StoreKit Configuration File (for testing in Simulator)

1. File → New → File → StoreKit Configuration File → `Mendel.storekit`
2. Add a Non-Consumable product:
   - Identifier: `com.dipworks.mendel.unlock`
   - Reference Name: Mendel Unlock
   - Price: 14.99
3. In your Scheme → Run → Options → StoreKit Configuration → select `Mendel.storekit`

This lets you test purchases in Simulator without App Store Connect.

---

## 5. HealthKit Testing

- HealthKit requires a **real device** — it doesn't work in Simulator
- Add test data via the Health app on device
- Or use the `HealthKitManager.toEngineSessions()` mock by returning hardcoded `HealthSession` values during development

---

## 6. File Integration Notes

| New File | Replaces |
|---|---|
| `AppState+v2.swift` | `AppState.swift` (rename/replace) |
| `RootView+v2.swift` | `RootView.swift` (rename/replace) |
| `TodayView+v2.swift` | `TodayView.swift` (rename/replace) |
| `CoachView+v2.swift` | `CoachView.swift` (rename/replace) |
| `DecisionEngine+HealthKit.swift` | Add alongside existing `DecisionEngine.swift` |
| `PurchaseManager.swift` | New file |
| `PaywallView.swift` | New file |
| `HealthKitManager.swift` | New file |
| `HealthKitViews.swift` | New file |

---

## 7. Paywall Logic Summary

| Feature | Free | Unlocked |
|---|---|---|
| Today recommendation | ✓ | ✓ |
| Manual logging | ✓ | ✓ |
| Week overview | ✓ | ✓ |
| Coach AI (unlimited) | — | ✓ |
| HRV / RHR signals on Today | — | ✓ |
| Weekly planning via Coach | — | ✓ |

Coach screen: free users see the chat UI and chips, but tapping any input shows the paywall sheet.
The paywall is a soft gate — not a hard block — so users understand the value before paying.

---

## 8. Privacy

Mendel reads HealthKit data on-device only.
No health data is sent to any server.
The only external call is to the Anthropic API (Coach messages), which contains no health identifiers.
Add this to your App Store privacy label accordingly.
