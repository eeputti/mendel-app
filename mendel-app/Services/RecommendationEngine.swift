#if !WIDGET_EXTENSION
//
// RecommendationEngine.swift
// Conservative extraction of the recommendation logic.
//

import Foundation

struct DecisionEngine {
    static func recommend(
        sessions: [Session],
        healthSessions: [HealthSession] = [],
        latestRecovery: RecoveryLog? = nil,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil
    ) -> Recommendation {
        let window = 5
        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now)!
        let manual = sessions.filter { $0.date >= cutoff }
        let health = healthSessions.filter { $0.date >= cutoff }
        let calendar = Calendar.current

        let manualLoad = manual.reduce(0.0) { $0 + $1.loadScore }
        let manualDays = Set(manual.map { calendar.startOfDay(for: $0.date) })
        let dedupedHealthLoad = health
            .filter { !manualDays.contains(calendar.startOfDay(for: $0.date)) }
            .reduce(0.0) { $0 + $1.loadScore }
        let totalLoad = manualLoad + dedupedHealthLoad

        let strengthLoad = manual
            .filter { $0.bodyLoad == .strength }
            .reduce(0.0) { $0 + $1.loadScore }
            + health
            .filter { $0.type == .strength }
            .reduce(0.0) { $0 + $1.loadScore }

        let enduranceLoad = manual
            .filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }
            .reduce(0.0) { $0 + $1.loadScore }
            + health
            .filter { $0.type == .run || $0.type == .sport }
            .reduce(0.0) { $0 + $1.loadScore }

        let soreness = latestRecovery?.soreness ?? .low
        let sleepQuality = latestRecovery?.sleepQuality ?? .ok
        let hrvLow = hrv.map { $0 < 30 } ?? false
        let rhrElevated = restingHeartRate.map { $0 > 70 } ?? false
        let signals = deriveSignals(
            manualSessions: manual,
            healthSessions: health
        )
        let fatigueScore = fatigueScore(
            totalLoad: totalLoad,
            soreness: soreness,
            sleepQuality: sleepQuality,
            hrvLow: hrvLow,
            rhrElevated: rhrElevated,
            signals: signals
        )

        if hrvLow && rhrElevated && fatigueScore >= 8 {
            return Recommendation(
                state: .recover,
                context: rationale(
                    primary: "recovery markers are down",
                    signals: signals,
                    fallback: "recovery markers are down and fatigue is high"
                ),
                steps: ["full rest or gentle walk only", "prioritise sleep — aim for 8+ hours", "no training today"]
            )
        }
        if soreness == .high {
            return Recommendation(
                state: .recover,
                context: rationale(
                    primary: "soreness is high",
                    signals: signals,
                    fallback: "soreness is high and the body needs a lighter day"
                ),
                steps: ["walk 20 min, easy pace", "light mobility: hips, calves, shoulders", "eat well, hydrate, sleep early"]
            )
        }
        if fatigueScore >= 7.5 {
            return Recommendation(
                state: .recover,
                context: rationale(
                    primary: "fatigue is building",
                    signals: signals,
                    fallback: "recent load is high and fatigue is building"
                ),
                steps: ["walk or full rest", "mobility work, 10–15 min", "prioritise sleep tonight"]
            )
        }
        if fatigueScore >= 6.5 && sleepQuality == .poor {
            return Recommendation(
                state: .rest,
                context: rationale(
                    primary: "sleep is poor and fatigue is already high",
                    signals: signals,
                    fallback: "sleep is poor and fatigue is already high"
                ),
                steps: ["full rest — no training", "nap if possible", "in bed early, phone off"]
            )
        }
        if hrvLow && fatigueScore >= 5.5 {
            return Recommendation(
                state: .train,
                context: rationale(
                    primary: "readiness is slightly down",
                    signals: signals,
                    fallback: "readiness is slightly down, so keep training easy"
                ),
                steps: ["easy walk or zone 2 run: 20–30 min", "keep heart rate below 140 bpm", "skip heavy lifting today"]
            )
        }
        if totalLoad < 4 && signals.consistency == .lowActivity {
            return Recommendation(
                state: .train,
                context: rationale(
                    primary: "low recent activity",
                    signals: signals,
                    fallback: "low recent activity, safe to train"
                ),
                steps: suggestFocus(strengthLoad: strengthLoad, enduranceLoad: enduranceLoad)
            )
        }
        if strengthLoad > 0 && enduranceLoad < strengthLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(
                state: .train,
                context: rationale(
                    primary: "strength load is leading",
                    signals: signals,
                    fallback: "strength load is leading, so add some endurance"
                ),
                steps: ["easy run: 4–6 km, conversational pace", "zone 2 — keep heart rate below 145 bpm", "stretch after"]
            )
        }
        if enduranceLoad > 0 && strengthLoad < enduranceLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(
                state: .train,
                context: rationale(
                    primary: "endurance load is leading",
                    signals: signals,
                    fallback: "endurance load is leading, so add some strength"
                ),
                steps: ["upper body strength: 3–4 exercises, 3–4 sets", "moderate intensity — not max effort", "compound movements: press, row, pull"]
            )
        }
        if fatigueScore >= 4.5 && soreness == .medium {
            return Recommendation(
                state: .train,
                context: rationale(
                    primary: "training has been consistent, but fatigue is building",
                    signals: signals,
                    fallback: "training has been consistent, but fatigue is building"
                ),
                steps: ["train, stay below RPE 7", "shorten the session if needed", "stretch and walk after"]
            )
        }
        return Recommendation(
            state: .train,
            context: rationale(
                primary: "load is balanced",
                signals: signals,
                fallback: "load is balanced, safe to train"
            ),
            steps: suggestFocus(strengthLoad: strengthLoad, enduranceLoad: enduranceLoad)
        )
    }

    private static func fatigueScore(
        totalLoad: Double,
        soreness: SorenessLevel,
        sleepQuality: SleepQuality,
        hrvLow: Bool,
        rhrElevated: Bool,
        signals: ReadinessSignals
    ) -> Double {
        var score = totalLoad * 0.45
        score += Double(soreness.score - 1) * 1.4
        score += sleepQuality == .poor ? 1.2 : 0
        score += hrvLow ? 1.2 : 0
        score += rhrElevated ? 1.0 : 0

        switch signals.momentum {
        case .rising:
            score += 0.8
        case .stable:
            score += 0.2
        case .falling:
            score -= 0.5
        }

        switch signals.consistency {
        case .lowActivity:
            score -= 0.7
        case .consistent:
            score += 0.3
        case .highFrequency:
            score += 0.9
        }

        switch signals.strainBalance {
        case .hardHeavy:
            score += 1.0
        case .recoveryHeavy:
            score -= 0.4
        case .balanced:
            break
        }

        return max(score, 0)
    }

    private static func suggestFocus(strengthLoad: Double, enduranceLoad: Double) -> [String] {
        if strengthLoad > enduranceLoad * 1.5 {
            return ["run or row: 30–45 min, moderate effort", "keep heart rate conversational", "cool down + light stretch"]
        } else if enduranceLoad > strengthLoad * 1.5 {
            return ["strength: full body or lower body focus", "3–5 sets, 5–8 reps, compound movements", "leave 1–2 reps in the tank"]
        } else {
            return ["strength: 45–60 min, your choice of split", "or run: 5–8 km at moderate pace", "listen to your body on intensity"]
        }
    }

    private static func deriveSignals(
        manualSessions: [Session],
        healthSessions: [HealthSession]
    ) -> ReadinessSignals {
        let recentDays = recentDailyLoads(manualSessions: manualSessions, healthSessions: healthSessions, days: 5)
        let activityWindow = activityCount(manualSessions: manualSessions, healthSessions: healthSessions, days: 7)
        let hardSessions = hardSessionCount(manualSessions: manualSessions, healthSessions: healthSessions, days: 5)
        let recoverySessions = recoverySessionCount(manualSessions: manualSessions, healthSessions: healthSessions, days: 5)

        return ReadinessSignals(
            momentum: classifyMomentum(loads: recentDays),
            consistency: classifyConsistency(activityCount: activityWindow),
            strainBalance: classifyStrainBalance(hardSessions: hardSessions, recoverySessions: recoverySessions)
        )
    }

    private static func recentDailyLoads(
        manualSessions: [Session],
        healthSessions: [HealthSession],
        days: Int
    ) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let manualByDay = Dictionary(grouping: manualSessions) { calendar.startOfDay(for: $0.date) }
        let healthByDay = Dictionary(grouping: healthSessions) { calendar.startOfDay(for: $0.date) }

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let manualForDay = manualByDay[day] ?? []
            let healthForDay = healthByDay[day] ?? []
            let manualLoad = manualForDay.reduce(0.0) { $0 + $1.loadScore }
            let manualExists = !manualForDay.isEmpty
            let healthLoad = manualExists ? 0 : healthForDay.reduce(0.0) { $0 + $1.loadScore }
            return manualLoad + healthLoad
        }
    }

    private static func activityCount(
        manualSessions: [Session],
        healthSessions: [HealthSession],
        days: Int
    ) -> Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let manualWindow = manualSessions.filter { $0.date >= cutoff }
        let healthWindow = healthSessions.filter { $0.date >= cutoff }
        let manualDays = Set(manualWindow.map { calendar.startOfDay(for: $0.date) })
        let healthDays = Set(
            healthWindow
                .map { calendar.startOfDay(for: $0.date) }
                .filter { !manualDays.contains($0) }
        )
        return manualWindow.count + healthDays.count
    }

    private static func hardSessionCount(
        manualSessions: [Session],
        healthSessions: [HealthSession],
        days: Int
    ) -> Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let manualCount = manualSessions
            .filter { $0.date >= cutoff && $0.sessionStatus == .completed }
            .filter { $0.intensity == .hard || ($0.perceivedEffort ?? 0) >= 4 }
            .count
        let healthCount = healthSessions
            .filter { $0.date >= cutoff && $0.intensity == .hard }
            .count
        return manualCount + healthCount
    }

    private static func recoverySessionCount(
        manualSessions: [Session],
        healthSessions: [HealthSession],
        days: Int
    ) -> Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let manualCount = manualSessions
            .filter { $0.date >= cutoff && $0.sessionStatus == .completed }
            .filter {
                $0.displayCategory == .mobility ||
                $0.displayCategory == .recovery ||
                $0.intensity == .easy
            }
            .count
        let healthCount = healthSessions
            .filter { $0.date >= cutoff && $0.intensity == .easy }
            .count
        return manualCount + healthCount
    }

    private static func classifyMomentum(loads: [Double]) -> MomentumSignal {
        guard loads.count >= 4 else { return .stable }
        let midpoint = loads.count / 2
        let earlier = loads.prefix(midpoint).reduce(0.0, +) / Double(midpoint)
        let later = loads.suffix(loads.count - midpoint).reduce(0.0, +) / Double(loads.count - midpoint)
        let delta = later - earlier

        if delta > 1.2 {
            return .rising
        }
        if delta < -1.2 {
            return .falling
        }
        return .stable
    }

    private static func classifyConsistency(activityCount: Int) -> ConsistencySignal {
        switch activityCount {
        case 0...2:
            return .lowActivity
        case 3...5:
            return .consistent
        default:
            return .highFrequency
        }
    }

    private static func classifyStrainBalance(hardSessions: Int, recoverySessions: Int) -> StrainBalanceSignal {
        if hardSessions >= 3 && hardSessions > recoverySessions + 1 {
            return .hardHeavy
        }
        if recoverySessions >= 2 && hardSessions == 0 {
            return .recoveryHeavy
        }
        return .balanced
    }

    private static func rationale(
        primary: String,
        signals: ReadinessSignals,
        fallback: String
    ) -> String {
        let candidates = [
            recoveryCandidate(for: primary),
            momentumCandidate(for: signals.momentum),
            consistencyCandidate(for: signals.consistency),
            strainCandidate(for: signals.strainBalance)
        ]
            .compactMap { $0 }
            .sorted { lhs, rhs in
                abs(lhs.impact) > abs(rhs.impact)
            }

        guard let dominant = candidates.first else {
            return fallback
        }

        let secondary = candidates.first {
            $0.text != dominant.text && abs($0.impact) >= 0.35
        }

        if let secondary {
            return "\(dominant.text)\n\(secondary.text)"
        }

        return dominant.text
    }

    private static func recoveryCandidate(for primary: String) -> RationaleCandidate? {
        switch primary {
        case "recovery markers are down":
            return .init(text: primary, impact: 1.6)
        case "soreness is high":
            return .init(text: primary, impact: 1.5)
        case "fatigue is building":
            return .init(text: primary, impact: 1.3)
        case "sleep is poor and fatigue is already high":
            return .init(text: primary, impact: 1.4)
        case "readiness is slightly down":
            return .init(text: primary, impact: 1.1)
        case "strength load is leading":
            return .init(text: primary, impact: 0.75)
        case "endurance load is leading":
            return .init(text: primary, impact: 0.75)
        case "load is balanced":
            return .init(text: primary, impact: 0.2)
        default:
            return nil
        }
    }

    private static func momentumCandidate(for signal: MomentumSignal) -> RationaleCandidate? {
        switch signal {
        case .rising:
            return .init(text: "load is rising", impact: 0.8)
        case .stable:
            return nil
        case .falling:
            return .init(text: "load is easing", impact: -0.5)
        }
    }

    private static func consistencyCandidate(for signal: ConsistencySignal) -> RationaleCandidate? {
        switch signal {
        case .lowActivity:
            return .init(text: "recent activity is low", impact: -0.7)
        case .consistent:
            return .init(text: "training has been consistent", impact: 0.3)
        case .highFrequency:
            return .init(text: "frequency has been high", impact: 0.9)
        }
    }

    private static func strainCandidate(for signal: StrainBalanceSignal) -> RationaleCandidate? {
        switch signal {
        case .hardHeavy:
            return .init(text: "hard sessions are stacking up", impact: 1.0)
        case .recoveryHeavy:
            return .init(text: "recent work has been mostly recovery", impact: -0.4)
        case .balanced:
            return nil
        }
    }
}

private struct ReadinessSignals {
    let momentum: MomentumSignal
    let consistency: ConsistencySignal
    let strainBalance: StrainBalanceSignal
}

private enum MomentumSignal {
    case rising
    case stable
    case falling
}

private enum ConsistencySignal {
    case lowActivity
    case consistent
    case highFrequency
}

private enum StrainBalanceSignal {
    case hardHeavy
    case recoveryHeavy
    case balanced
}

private struct RationaleCandidate {
    let text: String
    let impact: Double
}
#endif
