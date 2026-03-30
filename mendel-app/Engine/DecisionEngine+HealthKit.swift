import Foundation

// MARK: - Extended Decision Engine (v2)
// Merges manual sessions + HealthKit sessions + HRV/RHR signals.

extension DecisionEngine {

    /// Full recommendation using both manual logs and HealthKit data.
    static func recommend(
        sessions: [Session],
        healthSessions: [HealthSession] = [],
        latestRecovery: RecoveryLog? = nil,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil
    ) -> Recommendation {

        let window  = 5
        let cutoff  = Calendar.current.date(byAdding: .day, value: -window, to: .now)!
        let manual  = sessions.filter { $0.date >= cutoff }
        let health  = healthSessions.filter { $0.date >= cutoff }

        // Merge load scores
        let manualLoad   = manual.reduce(0.0)  { $0 + $1.loadScore }
        let healthLoad   = health.reduce(0.0)  { $0 + $1.loadScore }

        // Prefer manual over HealthKit for the same day (avoid double counting)
        let manualDays   = Set(manual.map { Calendar.current.startOfDay(for: $0.date) })
        let dedupedHLoad = health
            .filter { !manualDays.contains(Calendar.current.startOfDay(for: $0.date)) }
            .reduce(0.0) { $0 + $1.loadScore }

        let totalLoad    = manualLoad + dedupedHLoad

        // Body type loads
        let strLoad = manual.filter { $0.bodyLoad == .strength }.reduce(0.0) { $0 + $1.loadScore }
            + health.filter { $0.type == .strength }.reduce(0.0) { $0 + $1.loadScore }
        let endLoad = manual.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }.reduce(0.0) { $0 + $1.loadScore }
            + health.filter { $0.type == .run || $0.type == .sport }.reduce(0.0) { $0 + $1.loadScore }

        // Recovery signals (manual > HRV heuristic)
        let soreness     = latestRecovery?.soreness ?? .low
        let sleepQuality = latestRecovery?.sleepQuality ?? .ok

        // HRV signal: low HRV (< 30ms) + recent training = elevate to RECOVER
        let hrvLow = hrv.map { $0 < 30 } ?? false
        // RHR elevation: if RHR > personal norm heuristic (we use >70 as conservative flag)
        let rhrElevated = restingHeartRate.map { $0 > 70 } ?? false

        // ── Rules ──────────────────────────────────────────────────────────

        // 1. Physiological stress flags from HealthKit
        if hrvLow && rhrElevated && totalLoad > 6 {
            return Recommendation(
                state: .recover,
                context: "your HRV is low and resting HR is elevated. your nervous system needs a break.",
                steps: [
                    "full rest or gentle walk only",
                    "prioritise sleep — aim for 8+ hours",
                    "no training today"
                ]
            )
        }

        // 2. High soreness
        if soreness == .high {
            return Recommendation(
                state: .recover,
                context: "high soreness. your body is in repair mode.",
                steps: [
                    "walk 20 min, easy pace",
                    "light mobility: hips, calves, shoulders",
                    "eat well, hydrate, sleep early"
                ]
            )
        }

        // 3. Very high accumulated load
        if totalLoad > 14 {
            return Recommendation(
                state: .recover,
                context: "high load this week — \(String(format: "%.0f", totalLoad)) points. give it a day.",
                steps: [
                    "walk or full rest",
                    "mobility work, 10–15 min",
                    "prioritise sleep tonight"
                ]
            )
        }

        // 4. High load + poor sleep
        if totalLoad > 8 && sleepQuality == .poor {
            return Recommendation(
                state: .rest,
                context: "high load and poor sleep don't mix. rest today.",
                steps: [
                    "full rest — no training",
                    "nap if possible",
                    "in bed early, phone off"
                ]
            )
        }

        // 5. HRV low (but not critical) — suggest easy session
        if hrvLow && totalLoad > 5 {
            return Recommendation(
                state: .train,
                context: "HRV is a bit low. train easy today — don't push intensity.",
                steps: [
                    "easy walk or zone 2 run: 20–30 min",
                    "keep heart rate below 140 bpm",
                    "skip heavy lifting today"
                ]
            )
        }

        // 6. Fresh
        if totalLoad < 4 {
            let focus = suggestFocusFrom(strLoad: strLoad, endLoad: endLoad)
            return Recommendation(
                state: .train,
                context: "you're fresh. good day to put in work.",
                steps: focus
            )
        }

        // 7. Strength-heavy imbalance
        if strLoad > 0 && endLoad < strLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(
                state: .train,
                context: "strength-heavy week. balance it with some cardio.",
                steps: [
                    "easy run: 4–6 km, conversational pace",
                    "zone 2 — keep heart rate below 145 bpm",
                    "stretch after"
                ]
            )
        }

        // 8. Endurance-heavy imbalance
        if endLoad > 0 && strLoad < endLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(
                state: .train,
                context: "cardio-heavy week. time to add strength.",
                steps: [
                    "upper body strength: 3–4 exercises, 3–4 sets",
                    "moderate intensity — not max effort",
                    "compound movements: press, row, pull"
                ]
            )
        }

        // 9. Moderate load + medium soreness
        if totalLoad >= 4 && totalLoad <= 8 && soreness == .medium {
            return Recommendation(
                state: .train,
                context: "moderate load. keep intensity controlled.",
                steps: [
                    "train, stay below RPE 7",
                    "shorten the session if needed",
                    "stretch and walk after"
                ]
            )
        }

        // 10. Default
        let focus = suggestFocusFrom(strLoad: strLoad, endLoad: endLoad)
        return Recommendation(
            state: .train,
            context: "load is balanced. you're good to go.",
            steps: focus
        )
    }

    private static func suggestFocusFrom(strLoad: Double, endLoad: Double) -> [String] {
        if strLoad > endLoad * 1.5 {
            return [
                "run or row: 30–45 min, moderate effort",
                "keep heart rate conversational",
                "cool down + light stretch"
            ]
        } else if endLoad > strLoad * 1.5 {
            return [
                "strength: full body or lower body focus",
                "3–5 sets, 5–8 reps, compound movements",
                "leave 1–2 reps in the tank"
            ]
        } else {
            return [
                "strength: 45–60 min, your choice of split",
                "or run: 5–8 km at moderate pace",
                "listen to your body on intensity"
            ]
        }
    }
}
