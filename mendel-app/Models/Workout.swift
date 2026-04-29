#if !WIDGET_EXTENSION
//
// Workout.swift
// Core training and recovery models.
//

import Foundation
import SwiftData

enum SessionType: String, Codable, CaseIterable {
    case strength = "strength"
    case run = "run"
    case sport = "sport"

    var displayName: String {
        switch self {
        case .strength:
            return "Strength"
        case .run:
            return "Run"
        case .sport:
            return "Sport"
        }
    }

    var icon: String {
        switch self {
        case .strength:
            return "figure.strengthtraining.traditional"
        case .run:
            return "figure.run"
        case .sport:
            return "figure.tennis"
        }
    }
}

enum WorkoutCategory: String, Codable, CaseIterable {
    case running = "running"
    case strength = "strength"
    case tennis = "tennis"
    case cycling = "cycling"
    case rowing = "rowing"
    case walking = "walking"
    case mobility = "mobility"
    case recovery = "recovery"
    case other = "other"

    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .strength:
            return "Strength"
        case .tennis:
            return "Tennis"
        case .cycling:
            return "Cycling"
        case .rowing:
            return "Rowing"
        case .walking:
            return "Walking"
        case .mobility:
            return "Mobility"
        case .recovery:
            return "Recovery"
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .running:
            return "figure.run"
        case .strength:
            return "figure.strengthtraining.traditional"
        case .tennis:
            return "figure.tennis"
        case .cycling:
            return "figure.outdoor.cycle"
        case .rowing:
            return "figure.rower"
        case .walking:
            return "figure.walk"
        case .mobility:
            return "figure.flexibility"
        case .recovery:
            return "heart.text.square"
        case .other:
            return "bolt.heart"
        }
    }

    var suggestedSubtypes: [String] {
        switch self {
        case .running:
            return ["easy", "intervals", "threshold", "long"]
        case .strength:
            return ["upper body", "lower body", "full body"]
        case .tennis:
            return ["match", "easy", "intervals"]
        case .cycling, .rowing:
            return ["easy", "intervals", "long"]
        case .walking:
            return ["easy", "recovery"]
        case .mobility:
            return ["easy", "full body"]
        case .recovery:
            return ["easy", "recovery"]
        case .other:
            return ["easy", "long"]
        }
    }

    var defaultSessionType: SessionType {
        switch self {
        case .strength:
            return .strength
        case .running, .cycling, .rowing, .walking:
            return .run
        case .tennis, .mobility, .recovery, .other:
            return .sport
        }
    }

    static func legacyFallback(for type: SessionType) -> WorkoutCategory {
        switch type {
        case .strength:
            return .strength
        case .run:
            return .running
        case .sport:
            return .other
        }
    }
}

enum IntensityLevel: Int, Codable, CaseIterable {
    case easy = 1
    case moderate = 2
    case hard = 3

    var displayName: String {
        switch self {
        case .easy:
            return "easy"
        case .moderate:
            return "moderate"
        case .hard:
            return "hard"
        }
    }

    var rpe: String {
        switch self {
        case .easy:
            return "RPE 1–4"
        case .moderate:
            return "RPE 5–7"
        case .hard:
            return "RPE 8–10"
        }
    }
}

enum SessionStatus: String, Codable, CaseIterable {
    case planned = "planned"
    case completed = "completed"
    case skipped = "skipped"

    var displayName: String {
        rawValue.capitalized
    }
}

enum SleepQuality: String, Codable, CaseIterable {
    case poor = "poor"
    case ok = "ok"
    case good = "good"

    var score: Int {
        switch self {
        case .poor:
            return 1
        case .ok:
            return 2
        case .good:
            return 3
        }
    }
}

enum SorenessLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var score: Int {
        switch self {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }
}

enum BodyLoad {
    case strength
    case endurance
    case mixed
}

@Model
final class Session {
    var id: UUID
    var date: Date
    var type: SessionType
    var intensity: IntensityLevel
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var exerciseName: String?
    var distanceKm: Double?
    var durationMinutes: Int?
    var sportName: String?
    var category: WorkoutCategory?
    var subtype: String?
    var notes: String?
    var perceivedEffort: Int?
    var status: SessionStatus?

    init(
        date: Date = .now,
        type: SessionType,
        intensity: IntensityLevel,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        exerciseName: String? = nil,
        distanceKm: Double? = nil,
        durationMinutes: Int? = nil,
        sportName: String? = nil,
        category: WorkoutCategory? = nil,
        subtype: String? = nil,
        notes: String? = nil,
        perceivedEffort: Int? = nil,
        status: SessionStatus? = .completed
    ) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.intensity = intensity
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.exerciseName = exerciseName
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.sportName = sportName
        self.category = category
        self.subtype = subtype
        self.notes = notes
        self.perceivedEffort = perceivedEffort
        self.status = status
    }

    var loadScore: Double {
        guard sessionStatus == .completed else { return 0 }
        let multiplier = Double(intensity.rawValue)
        switch displayCategory {
        case .strength:
            let vol = Double((sets ?? 3) * (reps ?? 8))
            return min((vol / 24.0) * multiplier, 5.0)
        case .running:
            return min((distanceKm ?? 5) * multiplier * 0.3, 5.0)
        case .mobility, .recovery:
            return min(Double(durationMinutes ?? 20) / 60.0 * 0.5, 1.0)
        case .tennis, .cycling, .rowing, .walking, .other:
            return min(Double(durationMinutes ?? 60) / 60.0 * multiplier, 5.0)
        }
    }

    var bodyLoad: BodyLoad {
        switch displayCategory {
        case .strength:
            return .strength
        case .running, .cycling, .rowing, .walking:
            return .endurance
        case .tennis, .mobility, .recovery, .other:
            return displayCategory == .tennis && intensity == .hard ? .endurance : .mixed
        }
    }

    var displayCategory: WorkoutCategory {
        category ?? WorkoutCategory.legacyFallback(for: type)
    }

    var sessionStatus: SessionStatus {
        status ?? .completed
    }

    var displayTitle: String {
        if category == nil {
            switch type {
            case .strength, .run:
                return type.displayName
            case .sport:
                return sportName?.capitalized ?? type.displayName
            }
        }
        return displayCategory.displayName
    }

    var detailText: String {
        let parts = [
            subtype,
            durationMinutes.map { "\($0) min" },
            perceivedEffort.map { "feel \($0)/5" },
            notes.flatMap { $0.isEmpty ? nil : $0 }
        ]
        let compact = parts.compactMap { $0 }
        if !compact.isEmpty {
            return compact.joined(separator: " · ")
        }

        switch type {
        case .strength:
            return [exerciseName, sets.map { "\($0) sets" }, reps.map { "\($0) reps" }, intensity.displayName]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .run:
            return [distanceKm.map { String(format: "%.1f km", $0) }, durationMinutes.map { "\($0) min" }, intensity.displayName]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .sport:
            return [sportName, durationMinutes.map { "\($0) min" }, intensity.displayName]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
}

@Model
final class RecoveryLog {
    var id: UUID
    var date: Date
    var sleepQuality: SleepQuality
    var soreness: SorenessLevel

    init(date: Date = .now, sleepQuality: SleepQuality, soreness: SorenessLevel) {
        self.id = UUID()
        self.date = date
        self.sleepQuality = sleepQuality
        self.soreness = soreness
    }
}

extension IntensityLevel {
    static func fromPerceivedEffort(_ value: Int?) -> IntensityLevel {
        switch value ?? 0 {
        case 4...5:
            return .hard
        case 2...3:
            return .moderate
        default:
            return .easy
        }
    }
}
#endif
