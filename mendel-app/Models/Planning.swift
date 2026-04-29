#if !WIDGET_EXTENSION
//
// Planning.swift
// Shared training-plan domain reused by the coach and plan surfaces.
//

import Foundation

enum TrainingGoal: String, CaseIterable {
    case cooper = "cooper"
    case marathon = "marathon"
    case halfMarathon = "half marathon"
    case hybridFitness = "hybrid fitness"
    case tennisPerformance = "tennis performance"
    case generalHealth = "general health"
    case strengthEnduranceBalance = "strength + endurance balance"

    var displayName: String { rawValue.capitalized }

    var defaultSports: [PlanSport] {
        switch self {
        case .cooper, .marathon, .halfMarathon:
            return [.running, .gym]
        case .hybridFitness, .strengthEnduranceBalance:
            return [.running, .gym, .mobility]
        case .tennisPerformance:
            return [.tennis, .gym, .mobility]
        case .generalHealth:
            return [.walking, .gym, .mobility]
        }
    }
}

enum PlanSport: String, CaseIterable {
    case running = "running"
    case gym = "gym"
    case tennis = "tennis"
    case cycling = "cycling"
    case swimming = "swimming"
    case rowing = "rowing"
    case walking = "walking"
    case mobility = "mobility"
    case yoga = "yoga"

    static let defaults: [PlanSport] = [.running, .gym, .mobility]

    var displayName: String { rawValue.capitalized }

    var workoutCategory: WorkoutCategory {
        switch self {
        case .running:
            return .running
        case .gym:
            return .strength
        case .tennis:
            return .tennis
        case .cycling:
            return .cycling
        case .swimming:
            return .other
        case .rowing:
            return .rowing
        case .walking:
            return .walking
        case .mobility, .yoga:
            return .mobility
        }
    }

    static func decodeList(from rawValue: String) -> [PlanSport] {
        rawValue
            .split(separator: ",")
            .compactMap { PlanSport(rawValue: String($0)) }
    }
}

extension Array where Element == PlanSport {
    var joinedRawValue: String {
        map(\.rawValue).joined(separator: ",")
    }
}

struct PlannedWorkoutDraft: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let category: WorkoutCategory
    let subtype: String
    let durationMinutes: Int
    let perceivedEffort: Int?
    let notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        category: WorkoutCategory,
        subtype: String,
        durationMinutes: Int,
        perceivedEffort: Int?,
        notes: String?
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.subtype = subtype
        self.durationMinutes = durationMinutes
        self.perceivedEffort = perceivedEffort
        self.notes = notes
    }
}

enum TrainingPlanGenerator {
    static func generate(
        goal: TrainingGoal,
        sports: [PlanSport],
        sessionsPerWeek: Int,
        weeklyStructure: String
    ) -> [PlannedWorkoutDraft] {
        let desiredCount = max(1, min(sessionsPerWeek, 7))
        let templates = templatesForGoal(goal, sports: sports)
        let dates = scheduledDates(count: desiredCount, weeklyStructure: weeklyStructure)

        return (0..<desiredCount).map { index in
            let template = templates[index % templates.count]
            return PlannedWorkoutDraft(
                date: dates[index],
                category: template.category,
                subtype: template.subtype,
                durationMinutes: template.durationMinutes,
                perceivedEffort: template.perceivedEffort,
                notes: template.notes
            )
        }
    }

    private static func templatesForGoal(_ goal: TrainingGoal, sports: [PlanSport]) -> [PlannedWorkoutDraft] {
        let mappedSports = sports.map(\.workoutCategory)
        let firstEndurance = mappedSports.first(where: { $0 != .strength && $0 != .mobility }) ?? .running

        switch goal {
        case .cooper:
            return [
                template(firstEndurance, "intervals", 30, 4, "short quality session"),
                template(.strength, "full body", 40, 3, nil),
                template(.running, "easy", 35, 2, nil)
            ]
        case .marathon:
            return [
                template(.running, "easy", 45, 2, nil),
                template(.strength, "lower body", 40, 3, nil),
                template(.running, "threshold", 40, 4, nil),
                template(.running, "long", 80, 3, "steady effort")
            ]
        case .halfMarathon:
            return [
                template(.running, "easy", 40, 2, nil),
                template(.strength, "full body", 40, 3, nil),
                template(.running, "threshold", 35, 4, nil),
                template(.running, "long", 65, 3, nil)
            ]
        case .hybridFitness:
            return [
                template(.strength, "full body", 45, 3, nil),
                template(firstEndurance, "easy", 35, 2, nil),
                template(.strength, "lower body", 45, 3, nil),
                template(.mobility, "easy", 20, 1, nil)
            ]
        case .tennisPerformance:
            return [
                template(.tennis, "match", 90, 4, nil),
                template(.strength, "lower body", 40, 3, nil),
                template(.tennis, "easy", 60, 2, "focus on rhythm"),
                template(.mobility, "easy", 20, 1, nil)
            ]
        case .generalHealth:
            return [
                template(.walking, "easy", 30, 1, nil),
                template(.strength, "full body", 35, 3, nil),
                template(.mobility, "easy", 20, 1, nil)
            ]
        case .strengthEnduranceBalance:
            return [
                template(.strength, "upper body", 40, 3, nil),
                template(firstEndurance, "easy", 40, 2, nil),
                template(.strength, "lower body", 40, 3, nil),
                template(.running, "long", 60, 3, nil)
            ]
        }
    }

    private static func template(
        _ category: WorkoutCategory,
        _ subtype: String,
        _ durationMinutes: Int,
        _ perceivedEffort: Int?,
        _ notes: String?
    ) -> PlannedWorkoutDraft {
        PlannedWorkoutDraft(
            date: .now,
            category: category,
            subtype: subtype,
            durationMinutes: durationMinutes,
            perceivedEffort: perceivedEffort,
            notes: notes
        )
    }

    private static func scheduledDates(count: Int, weeklyStructure: String) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let preferredWeekdays = parseWeekdays(from: weeklyStructure)
        var used = Set<Date>()
        var dates: [Date] = []

        for weekday in preferredWeekdays {
            if let date = nextDate(for: weekday, from: today), used.insert(date).inserted {
                dates.append(date)
            }
            if dates.count == count {
                return dates.sorted()
            }
        }

        let fallbackOffsets = fallbackDayOffsets(for: count)
        for offset in fallbackOffsets {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let normalized = calendar.startOfDay(for: date)
            if used.insert(normalized).inserted {
                dates.append(normalized)
            }
            if dates.count == count {
                break
            }
        }

        return dates.sorted().map { calendar.date(bySettingHour: 7, minute: 0, second: 0, of: $0) ?? $0 }
    }

    private static func parseWeekdays(from value: String) -> [Int] {
        let lowercased = value.lowercased()
        let orderedTokens: [(String, Int)] = [
            ("mon", 2), ("monday", 2),
            ("tue", 3), ("tuesday", 3),
            ("wed", 4), ("wednesday", 4),
            ("thu", 5), ("thursday", 5),
            ("fri", 6), ("friday", 6),
            ("sat", 7), ("saturday", 7),
            ("sun", 1), ("sunday", 1)
        ]

        var matches: [(Int, Int)] = []
        for (token, weekday) in orderedTokens {
            if let range = lowercased.range(of: token) {
                matches.append((lowercased.distance(from: lowercased.startIndex, to: range.lowerBound), weekday))
            }
        }

        return matches
            .sorted { $0.0 < $1.0 }
            .map(\.1)
            .reduce(into: []) { result, weekday in
                if !result.contains(weekday) {
                    result.append(weekday)
                }
            }
    }

    private static func nextDate(for weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if calendar.component(.weekday, from: candidate) == weekday {
                return calendar.startOfDay(for: candidate)
            }
        }
        return nil
    }

    private static func fallbackDayOffsets(for count: Int) -> [Int] {
        switch count {
        case 1:
            return [1]
        case 2:
            return [1, 4]
        case 3:
            return [0, 2, 5]
        case 4:
            return [0, 2, 4, 6]
        case 5:
            return [0, 1, 3, 5, 6]
        case 6:
            return [0, 1, 2, 4, 5, 6]
        default:
            return Array(0...6)
        }
    }
}
#endif
