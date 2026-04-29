#if !WIDGET_EXTENSION
//
// CoachMessage.swift
// Minimal coach chat models.
//

import Foundation

struct CoachWeeklyTrainingVolume: Codable {
    let completed_sessions_7d: Int
    let hard_sessions_7d: Int
    let run_distance_km_7d: Int
    let strength_sessions_7d: Int
    let load_score_7d: Double

    init(
        completed_sessions_7d: Int = 0,
        hard_sessions_7d: Int = 0,
        run_distance_km_7d: Int = 0,
        strength_sessions_7d: Int = 0,
        load_score_7d: Double = 0
    ) {
        self.completed_sessions_7d = completed_sessions_7d
        self.hard_sessions_7d = hard_sessions_7d
        self.run_distance_km_7d = run_distance_km_7d
        self.strength_sessions_7d = strength_sessions_7d
        self.load_score_7d = load_score_7d
    }
}

struct CoachRecoveryContext: Codable {
    let readiness: String
    let fatigue_score: Int
    let sleep_hours: Double
    let sleep_quality: String?
    let soreness: String?

    init(
        readiness: String = "medium",
        fatigue_score: Int = 5,
        sleep_hours: Double = 7.2,
        sleep_quality: String? = nil,
        soreness: String? = nil
    ) {
        self.readiness = readiness
        self.fatigue_score = fatigue_score
        self.sleep_hours = sleep_hours
        self.sleep_quality = sleep_quality
        self.soreness = soreness
    }
}

struct CoachMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: CoachMessageRole
    let content: String
    let delivery: CoachMessageDelivery

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        content: String,
        delivery: CoachMessageDelivery = .sent
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.delivery = delivery
    }
}

enum CoachMessageRole: String, Codable, Hashable {
    case user
    case assistant
}

enum CoachMessageDelivery: String, Codable, Hashable {
    case sent
    case sending
    case failed
}

enum CoachChatState: Equatable {
    case idle
    case sending
    case serverUnavailable(CoachChatFailurePresentation)
    case invalidResponse(CoachChatFailurePresentation)
    case authIssue(CoachChatFailurePresentation)
    case offline(CoachChatFailurePresentation)
}

struct CoachChatFailurePresentation: Equatable {
    let title: String
    let detail: String
}

struct CoachChatRequest: Encodable {
    let message: String
    let userId: String?
    let history: [CoachChatHistoryItem]
    let context: CoachChatContext
}

struct CoachChatHistoryItem: Encodable {
    let role: CoachMessageRole
    let content: String
}

struct CoachChatContext: Encodable {
    let training: CoachTrainingContext
    let profile: CoachChatProfileContext?
    let onboarding: CoachChatOnboardingContext?
    let plan: CoachChatPlanContext?
}

struct CoachChatProfileContext: Codable {
    let goalSummary: String?
    let preferredSports: [String]?
}

struct CoachChatOnboardingContext: Codable {
    let primaryGoal: String?
    let experienceLevel: String?
}

struct CoachChatPlanContext: Codable {
    let summary: String?
    let nextSession: String?
}

struct CoachChatResponse: Decodable {
    let reply: String
}

struct CoachChatErrorResponse: Decodable {
    let error: CoachChatErrorDetail
    let request_id: String?
}

struct CoachChatErrorDetail: Decodable {
    let code: String
    let message: String
}

struct CoachTrainingContext: Codable {
    let today_date: String
    let day: String
    let readiness: String
    let last_workout: String
    let weekly_run_distance_km: Int
    let strength_sessions_completed: Int
    let fatigue_score: Int
    let sleep_hours: Double
    let goal: String
    let today_plan: String?
    let next_planned_session: String?
    let weekly_structure: String?
    let planned_sessions_summary: [String]?
    let completed_sessions_summary: [String]?
    let health_workouts_summary: [String]?
    let preferred_sports: [String]
    let recent_completed_workouts: [String]
    let planned_sessions_this_week: [String]
    let most_recent_hard_session: String?
    let weekly_training_volume: CoachWeeklyTrainingVolume
    let recovery_context: CoachRecoveryContext
    let athlete_profile: CoachAthleteProfile?

    init(
        today_date: String = "2026-04-15",
        day: String = "Wednesday",
        readiness: String = "medium",
        last_workout: String = "8 km easy run",
        weekly_run_distance_km: Int = 24,
        strength_sessions_completed: Int = 2,
        fatigue_score: Int = 5,
        sleep_hours: Double = 7.2,
        goal: String = "build durable hybrid fitness",
        today_plan: String? = nil,
        next_planned_session: String? = nil,
        weekly_structure: String? = nil,
        planned_sessions_summary: [String]? = nil,
        completed_sessions_summary: [String]? = nil,
        health_workouts_summary: [String]? = nil,
        preferred_sports: [String] = ["running", "gym", "mobility"],
        recent_completed_workouts: [String] = ["running — 8.0 km easy"],
        planned_sessions_this_week: [String] = [],
        most_recent_hard_session: String? = nil,
        weekly_training_volume: CoachWeeklyTrainingVolume = CoachWeeklyTrainingVolume(),
        recovery_context: CoachRecoveryContext = CoachRecoveryContext(),
        athlete_profile: CoachAthleteProfile? = nil
    ) {
        self.today_date = today_date
        self.day = day
        self.readiness = readiness
        self.last_workout = last_workout
        self.weekly_run_distance_km = weekly_run_distance_km
        self.strength_sessions_completed = strength_sessions_completed
        self.fatigue_score = fatigue_score
        self.sleep_hours = sleep_hours
        self.goal = goal
        self.today_plan = today_plan
        self.next_planned_session = next_planned_session
        self.weekly_structure = weekly_structure
        self.planned_sessions_summary = planned_sessions_summary
        self.completed_sessions_summary = completed_sessions_summary
        self.health_workouts_summary = health_workouts_summary
        self.preferred_sports = preferred_sports
        self.recent_completed_workouts = recent_completed_workouts
        self.planned_sessions_this_week = planned_sessions_this_week
        self.most_recent_hard_session = most_recent_hard_session
        self.weekly_training_volume = weekly_training_volume
        self.recovery_context = recovery_context
        self.athlete_profile = athlete_profile
    }
}
#endif
