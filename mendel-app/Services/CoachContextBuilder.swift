#if !WIDGET_EXTENSION
//
// CoachContextBuilder.swift
// Builds a realistic coach context from the app's existing data.
//

import Foundation

enum CoachContextBuilder {
    static func makeContext(
        sessions: [Session],
        recoveryLogs: [RecoveryLog],
        healthSessions: [HealthSession]
    ) -> CoachTrainingContext {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let today = calendar.startOfDay(for: .now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now)

        let completedSessions = sessions
            .filter { $0.sessionStatus == .completed }
            .sorted { $0.date > $1.date }
        let plannedSessions = sessions
            .filter { $0.sessionStatus == .planned && $0.date >= today }
            .sorted { $0.date < $1.date }
        let recentSessions = completedSessions.filter { $0.date >= cutoff }
        let recentHealthSessions = healthSessions
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
        let latestRecovery = recoveryLogs.sorted { $0.date > $1.date }.first

        let lastWorkout = recentSessions.first.map(lastWorkoutSummary)
            ?? recentHealthSessions.first.map(lastHealthWorkoutSummary)
            ?? "no recent workout logged"
        let todayPlan = plannedSessions.first(where: { calendar.isDateInToday($0.date) }).map(plannedWorkoutSummary)
        let nextPlanned = plannedSessions.first.map(plannedWorkoutSummary)
        let plannedSessionsThisWeek = plannedSessions.filter {
            if let weekInterval {
                return weekInterval.contains($0.date)
            }
            return false
        }

        // Training load over the trailing 7 days.
        let weeklyRunDistance = recentSessions
            .filter { $0.displayCategory == .running }
            .reduce(0.0) { total, session in
                total + (session.distanceKm ?? estimatedDistanceKm(for: session.durationMinutes))
            }
            + recentHealthSessions
            .filter { $0.type == .run }
            .reduce(0.0) { total, session in
                total + (session.distanceKm ?? estimatedDistanceKm(for: session.durationMinutes))
            }

        let strengthSessionsCompleted = recentSessions.filter { $0.bodyLoad == .strength }.count
            + recentHealthSessions.filter { $0.type == .strength }.count

        let loadScore = recentSessions.reduce(0.0) { $0 + $1.loadScore }
            + recentHealthSessions.reduce(0.0) { $0 + $1.loadScore }
        let hardSessionsCompleted = recentSessions.filter { $0.intensity == .hard }.count
            + recentHealthSessions.filter { $0.intensity == .hard }.count
        let mostRecentHardSession = recentSessions.first(where: { $0.intensity == .hard }).map(lastWorkoutSummary)
            ?? recentHealthSessions.first(where: { $0.intensity == .hard }).map(lastHealthWorkoutSummary)

        // Recovery inputs are derived from the latest logged recovery entry only.
        let sorenessScore = latestRecovery.map { computeSorenessScore(from: $0.soreness.score) } ?? 2
        let sleepHours = latestRecovery.map { estimatedSleepHours(for: $0) } ?? 7.0
        let fatigueScore = min(
            10,
            max(
                1,
                Int((loadScore / 2.5).rounded()) + sorenessScore + (sleepHours < 6.5 ? 2 : 0)
            )
        )

        let readiness: String
        switch fatigueScore {
        case 1...3:
            readiness = "high"
        case 4...6:
            readiness = "medium"
        default:
            readiness = "low"
        }

        let goal = UserDefaults.standard.string(forKey: "plan.goal") ?? "general health"
        let preferredSports = UserDefaults.standard.string(forKey: "plan.sports")
            .map { PlanSport.decodeList(from: $0).map(\.rawValue) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? TrainingGoal(rawValue: goal)?.defaultSports.map(\.rawValue)
            ?? PlanSport.defaults.map(\.rawValue)
        let weeklyStructure = UserDefaults.standard.string(forKey: "plan.weeklyStructure")
        let recoveryContext = CoachRecoveryContext(
            readiness: readiness,
            fatigue_score: fatigueScore,
            sleep_hours: sleepHours,
            sleep_quality: latestRecovery?.sleepQuality.rawValue,
            soreness: latestRecovery?.soreness.rawValue
        )
        let athleteProfile = OnboardingStore.loadPersistedAthleteProfile()
        let weeklyTrainingVolume = CoachWeeklyTrainingVolume(
            completed_sessions_7d: recentSessions.count + recentHealthSessions.count,
            hard_sessions_7d: hardSessionsCompleted,
            run_distance_km_7d: Int(weeklyRunDistance.rounded()),
            strength_sessions_7d: strengthSessionsCompleted,
            load_score_7d: (loadScore * 10).rounded() / 10
        )
        let recentCompletedWorkouts = mergedRecentCompletedWorkouts(
            sessions: recentSessions,
            healthSessions: recentHealthSessions
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        return CoachTrainingContext(
            today_date: isoFormatter.string(from: .now),
            day: formatter.string(from: .now),
            readiness: readiness,
            last_workout: lastWorkout,
            weekly_run_distance_km: Int(weeklyRunDistance.rounded()),
            strength_sessions_completed: strengthSessionsCompleted,
            fatigue_score: fatigueScore,
            sleep_hours: sleepHours,
            goal: goal,
            today_plan: todayPlan,
            next_planned_session: nextPlanned,
            weekly_structure: weeklyStructure?.isEmpty == true ? nil : weeklyStructure,
            planned_sessions_summary: plannedSessions.prefix(5).map(plannedWorkoutSummary),
            completed_sessions_summary: recentSessions.prefix(5).map(lastWorkoutSummary),
            health_workouts_summary: recentHealthSessions.prefix(5).map(lastHealthWorkoutSummary),
            preferred_sports: preferredSports,
            recent_completed_workouts: recentCompletedWorkouts,
            planned_sessions_this_week: plannedSessionsThisWeek.prefix(5).map(plannedWorkoutSummary),
            most_recent_hard_session: mostRecentHardSession,
            weekly_training_volume: weeklyTrainingVolume,
            recovery_context: recoveryContext,
            athlete_profile: athleteProfile
        )
    }

    nonisolated private static func lastWorkoutSummary(for session: Session) -> String {
        let details = session.detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        if details.isEmpty {
            return session.displayTitle.lowercased()
        }
        return "\(session.displayTitle.lowercased()) — \(details)"
    }

    nonisolated private static func lastHealthWorkoutSummary(for session: HealthSession) -> String {
        let detail = session.distanceKm.map { String(format: "%.1f km", $0) } ?? "\(session.durationMinutes) min"
        return "\(session.type.displayName.lowercased()) — \(detail) · \(session.intensity.displayName)"
    }

    nonisolated private static func plannedWorkoutSummary(for session: Session) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let detail = [session.displayTitle, session.subtype, session.durationMinutes.map { "\($0) min" }]
            .compactMap { $0 }
            .joined(separator: " · ")
        return "\(formatter.string(from: session.date)) — \(detail)"
    }

    private static func mergedRecentCompletedWorkouts(
        sessions: [Session],
        healthSessions: [HealthSession]
    ) -> [String] {
        let combined = sessions.map { ($0.date, lastWorkoutSummary(for: $0)) }
            + healthSessions.map { ($0.date, lastHealthWorkoutSummary(for: $0)) }

        return combined
            .sorted { $0.0 > $1.0 }
            .prefix(6)
            .map(\.1)
    }

    private static func estimatedDistanceKm(for durationMinutes: Int?) -> Double {
        Double(durationMinutes ?? 0) / 6.0
    }

    private static func computeSorenessScore(from soreness: Int) -> Int {
        switch soreness {
        case 1:
            return 1
        case 2:
            return 2
        case 3:
            return 4
        default:
            return 2
        }
    }

    private static func estimatedSleepHours(for recoveryLog: RecoveryLog) -> Double {
        switch recoveryLog.sleepQuality {
        case .poor:
            return 5.8
        case .ok:
            return 7.0
        case .good:
            return 8.1
        }
    }
}
#endif
