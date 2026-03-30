import Foundation

// MARK: - Recommendation Output

struct Recommendation: Equatable {
    let state: TrainingState
    let context: String
    let steps: [String]
}

enum TrainingState: String, Equatable {
    case train   = "TRAIN"
    case recover = "RECOVER"
    case rest    = "REST"

    var color: String {
        // Used for subtle UI tinting if needed
        switch self {
        case .train:   return "primary"
        case .recover: return "accent"
        case .rest:    return "secondary"
        }
    }
}

// MARK: - Decision Engine

struct DecisionEngine {

    /// Main entry point. Pass in recent sessions and the latest recovery log.
    static func recommend(
        sessions: [Session],
        latestRecovery: RecoveryLog?
    ) -> Recommendation {

        let window = 5 // days to look back
        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now)!
        let recent = sessions.filter { $0.date >= cutoff }

        let totalLoad      = recent.reduce(0.0) { $0 + $1.loadScore }
        let strengthLoad   = recent.filter { $0.bodyLoad == .strength }.reduce(0.0) { $0 + $1.loadScore }
        let enduranceLoad  = recent.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }.reduce(0.0) { $0 + $1.loadScore }

        let soreness       = latestRecovery?.soreness ?? .low
        let sleepQuality   = latestRecovery?.sleepQuality ?? .ok

        // — Rules, in priority order —

        // 1. High soreness → always recover
        if soreness == .high {
            return Recommendation(
                state: .recover,
                context: "high soreness detected. your body is asking for a break.",
                steps: [
                    "walk 20 min, easy pace",
                    "light mobility: hips, calves, shoulders",
                    "eat well, hydrate, sleep early"
                ]
            )
        }

        // 2. Very high load → recover
        if totalLoad > 14 {
            return Recommendation(
                state: .recover,
                context: "you've trained hard this week. give it a day.",
                steps: [
                    "walk 20–30 min or full rest",
                    "mobility work, 10–15 min",
                    "prioritise sleep tonight"
                ]
            )
        }

        // 3. High load + poor sleep → rest
        if totalLoad > 8 && sleepQuality == .poor {
            return Recommendation(
                state: .rest,
                context: "high load and poor sleep is a risky combo. rest today.",
                steps: [
                    "full rest — no training",
                    "nap if you can",
                    "get to bed early, phone off"
                ]
            )
        }

        // 4. Low overall load → definitely train
        if totalLoad < 4 {
            let focus = suggestFocus(strengthLoad: strengthLoad, enduranceLoad: enduranceLoad)
            return Recommendation(
                state: .train,
                context: "you're fresh. good day to put in work.",
                steps: focus.steps
            )
        }

        // 5. Imbalanced: only strength recently
        if strengthLoad > 0 && enduranceLoad == 0 && recent.count >= 2 {
            return Recommendation(
                state: .train,
                context: "all strength, no cardio this week. balance it out.",
                steps: [
                    "easy run: 4–6 km, conversational pace",
                    "don't push the intensity — this is aerobic base work",
                    "stretch after"
                ]
            )
        }

        // 6. Imbalanced: only endurance recently
        if enduranceLoad > 0 && strengthLoad == 0 && recent.count >= 2 {
            return Recommendation(
                state: .train,
                context: "cardio-heavy week so far. add some strength.",
                steps: [
                    "upper body strength: 3–4 exercises, 3–4 sets",
                    "moderate intensity — not max effort",
                    "focus on compound movements"
                ]
            )
        }

        // 7. Moderate balanced load + medium soreness → light train
        if totalLoad >= 4 && totalLoad <= 8 && soreness == .medium {
            return Recommendation(
                state: .train,
                context: "moderate load. keep it controlled today.",
                steps: [
                    "train, but stay below RPE 7",
                    "shorten the session if needed",
                    "stretch and walk after"
                ]
            )
        }

        // 8. Default: train normally
        let focus = suggestFocus(strengthLoad: strengthLoad, enduranceLoad: enduranceLoad)
        return Recommendation(
            state: .train,
            context: "load is balanced. you're good to go.",
            steps: focus.steps
        )
    }

    // MARK: - Helpers

    private struct Focus {
        let steps: [String]
    }

    private static func suggestFocus(strengthLoad: Double, enduranceLoad: Double) -> Focus {
        if strengthLoad > enduranceLoad * 1.5 {
            return Focus(steps: [
                "run or row: 30–45 min, moderate effort",
                "keep heart rate conversational",
                "cool down + light stretch"
            ])
        } else if enduranceLoad > strengthLoad * 1.5 {
            return Focus(steps: [
                "strength: full body or lower body focus",
                "3–5 sets, 5–8 reps, compound movements",
                "leave 1–2 reps in the tank"
            ])
        } else {
            return Focus(steps: [
                "strength: 45–60 min, your choice of split",
                "or run: 5–8 km at moderate pace",
                "listen to your body on intensity"
            ])
        }
    }
}

// MARK: - Weekly Summary

struct WeeklySummary {
    let strengthSessions: Int
    let enduranceSessions: Int
    let recoverySessions: Int
    let totalLoadScore: Double
    let strengthBalance: Double  // 0–1
    let enduranceBalance: Double // 0–1

    static func compute(sessions: [Session]) -> WeeklySummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let week   = sessions.filter { $0.date >= cutoff }

        let str = week.filter { $0.bodyLoad == .strength }
        let end = week.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }
        let total = week.reduce(0.0) { $0 + $1.loadScore }

        let strLoad = str.reduce(0.0) { $0 + $1.loadScore }
        let endLoad = end.reduce(0.0) { $0 + $1.loadScore }
        let maxLoad = max(strLoad + endLoad, 1)

        return WeeklySummary(
            strengthSessions:  str.count,
            enduranceSessions: end.count,
            recoverySessions:  0,
            totalLoadScore:    total,
            strengthBalance:   min(strLoad / maxLoad, 1.0),
            enduranceBalance:  min(endLoad / maxLoad, 1.0)
        )
    }
}
