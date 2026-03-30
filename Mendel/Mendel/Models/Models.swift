import Foundation
import SwiftData

// MARK: - Session Types

enum SessionType: String, Codable, CaseIterable {
    case strength = "strength"
    case run      = "run"
    case sport    = "sport"

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .run:      return "Run"
        case .sport:    return "Sport"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "figure.strengthtraining.traditional"
        case .run:      return "figure.run"
        case .sport:    return "figure.tennis"
        }
    }
}

enum IntensityLevel: Int, Codable, CaseIterable {
    case easy     = 1
    case moderate = 2
    case hard     = 3

    var displayName: String {
        switch self {
        case .easy:     return "easy"
        case .moderate: return "moderate"
        case .hard:     return "hard"
        }
    }

    var rpe: String {
        switch self {
        case .easy:     return "RPE 1–4"
        case .moderate: return "RPE 5–7"
        case .hard:     return "RPE 8–10"
        }
    }
}

enum SleepQuality: String, Codable, CaseIterable {
    case poor = "poor"
    case ok   = "ok"
    case good = "good"

    var score: Int {
        switch self {
        case .poor: return 1
        case .ok:   return 2
        case .good: return 3
        }
    }
}

enum SorenessLevel: String, Codable, CaseIterable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var score: Int {
        switch self {
        case .low:    return 1
        case .medium: return 2
        case .high:   return 3
        }
    }
}

// MARK: - SwiftData Models

@Model
final class Session {
    var id: UUID
    var date: Date
    var type: SessionType
    var intensity: IntensityLevel

    // Strength specific
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var exerciseName: String?

    // Run specific
    var distanceKm: Double?
    var durationMinutes: Int?

    // Sport specific
    var sportName: String?

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
        sportName: String? = nil
    ) {
        self.id               = UUID()
        self.date             = date
        self.type             = type
        self.intensity        = intensity
        self.sets             = sets
        self.reps             = reps
        self.weight           = weight
        self.exerciseName     = exerciseName
        self.distanceKm       = distanceKm
        self.durationMinutes  = durationMinutes
        self.sportName        = sportName
    }

    // Load score used by the decision engine
    var loadScore: Double {
        let multiplier = Double(intensity.rawValue)
        switch type {
        case .strength:
            let vol = Double((sets ?? 3) * (reps ?? 8))
            return min((vol / 24.0) * multiplier, 5.0)
        case .run:
            return min((distanceKm ?? 5) * multiplier * 0.3, 5.0)
        case .sport:
            return min(Double(durationMinutes ?? 60) / 60.0 * multiplier, 5.0)
        }
    }

    // Which body region is taxed
    var bodyLoad: BodyLoad {
        switch type {
        case .strength: return .strength
        case .run:      return .endurance
        case .sport:    return intensity == .hard ? .endurance : .mixed
        }
    }
}

enum BodyLoad {
    case strength, endurance, mixed
}

@Model
final class RecoveryLog {
    var id: UUID
    var date: Date
    var sleepQuality: SleepQuality
    var soreness: SorenessLevel

    init(date: Date = .now, sleepQuality: SleepQuality, soreness: SorenessLevel) {
        self.id           = UUID()
        self.date         = date
        self.sleepQuality = sleepQuality
        self.soreness     = soreness
    }
}
