#if !WIDGET_EXTENSION
//
// Recommendation.swift
// Recommendation and coaching data models.
//

import Foundation

struct Recommendation: Equatable {
    let state: TrainingState
    let context: String
    let steps: [String]
}

enum TrainingState: String, Equatable {
    case train = "TRAIN"
    case recover = "RECOVER"
    case rest = "REST"
}

struct WeeklySummary {
    let strengthSessions: Int
    let enduranceSessions: Int
    let recoverySessions: Int
    let totalLoadScore: Double
    let strengthBalance: Double
    let enduranceBalance: Double

    static func compute(sessions: [Session]) -> WeeklySummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let week = sessions.filter { $0.date >= cutoff }
        let strength = week.filter { $0.bodyLoad == .strength }
        let endurance = week.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }
        let total = week.reduce(0.0) { $0 + $1.loadScore }
        let strengthLoad = strength.reduce(0.0) { $0 + $1.loadScore }
        let enduranceLoad = endurance.reduce(0.0) { $0 + $1.loadScore }
        let maxLoad = max(strengthLoad + enduranceLoad, 1)

        return WeeklySummary(
            strengthSessions: strength.count,
            enduranceSessions: endurance.count,
            recoverySessions: 0,
            totalLoadScore: total,
            strengthBalance: min(strengthLoad / maxLoad, 1.0),
            enduranceBalance: min(enduranceLoad / maxLoad, 1.0)
        )
    }
}

struct HealthSession {
    let date: Date
    let type: SessionType
    let intensity: IntensityLevel
    let durationMinutes: Int
    let distanceKm: Double?

    var loadScore: Double {
        let multiplier = Double(intensity.rawValue)
        switch type {
        case .strength:
            return min(Double(durationMinutes) / 60 * multiplier * 2, 5)
        case .run:
            return min((distanceKm ?? Double(durationMinutes) / 6) * multiplier * 0.3, 5)
        case .sport:
            return min(Double(durationMinutes) / 60 * multiplier, 5)
        }
    }
}
#endif
