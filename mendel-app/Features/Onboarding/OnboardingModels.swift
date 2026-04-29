#if !WIDGET_EXTENSION
//
// OnboardingModels.swift
// Typed onboarding profile, derived coaching signals, and personalization output.
//

import Foundation

enum OnboardingPrimaryIdentity: String, Codable, CaseIterable, Hashable {
    case mainlyRun = "i mainly run"
    case mainlyLift = "i mainly lift"
    case balanceBoth = "i try to balance both"
    case generalFitness = "i train for general fitness"
    case returning = "i'm getting back into training"
}

enum OnboardingGoal: String, Codable, CaseIterable, Hashable {
    case runFaster = "run faster"
    case buildMuscle = "build muscle"
    case improveEndurance = "improve endurance"
    case loseFat = "lose fat"
    case lookAthletic = "look athletic"
    case feelHealthier = "feel healthier"
    case performBetterInSport = "perform better in sport"
    case stayConsistent = "stay consistent"
    case trainForEvent = "train for an event"
}

enum OnboardingPriority: String, Codable, CaseIterable, Hashable {
    case performance = "performance"
    case physique = "physique"
    case consistency = "consistency"
    case energy = "energy"
    case health = "health"
    case balance = "balancing everything"
}

enum OnboardingEventGoal: String, Codable, CaseIterable, Hashable {
    case fiveK = "5k"
    case tenK = "10k"
    case halfMarathon = "half marathon"
    case marathon = "marathon"
    case ultra = "ultra"
    case hyrox = "hyrox"
    case teamSportSeason = "team sport season"
    case somethingElse = "something else"
    case none = "no event right now"
}

enum OnboardingTrainingModality: String, Codable, CaseIterable, Hashable {
    case running = "running"
    case gym = "gym"
    case walking = "walking"
    case cycling = "cycling"
    case intervals = "intervals"
    case longRuns = "long runs"
    case mobility = "mobility"
    case sportPractice = "sport practice"
    case nothingConsistent = "nothing consistent yet"
}

enum OnboardingObstacle: String, Codable, CaseIterable, Hashable {
    case poorPlanning = "poor planning"
    case tooMuchTooSoon = "i do too much too soon"
    case recoveryFallsApart = "recovery falls apart"
    case workStress = "work / school stress"
    case lowMotivation = "low motivation"
    case inconsistency = "inconsistency"
    case unclearDailyPlan = "i don't know what to do each day"
    case loseMomentum = "i lose momentum after missing one session"
}

enum OnboardingWhy: String, Codable, CaseIterable, Hashable {
    case feelProud = "i want to feel proud of myself"
    case trustBody = "i want to trust my body"
    case lookLikeITain = "i want to look like i train"
    case performHigher = "i want to perform at a higher level"
    case moreEnergy = "i want more energy in daily life"
    case tiredOfStartingOver = "i'm tired of starting over"
    case other = "other"
}

enum OnboardingCoachReminder: String, Codable, CaseIterable, Hashable {
    case consistencyBeatsIntensity = "consistency beats intensity"
    case protectLongGame = "protect the long game"
    case nextRightSession = "do the next right session"
    case noPerfectNeeded = "you do not need perfect"
    case rememberWhyStarted = "remember why you started"
    case custom = "custom"
}

enum OnboardingOutcomeIdentity: String, Codable, CaseIterable, Hashable {
    case leanAndFast = "lean and fast"
    case strongAndAthletic = "strong and athletic"
    case balancedHybrid = "balanced hybrid"
    case durableAndHealthy = "durable and healthy"
    case notSureYet = "not sure yet"
}

enum OnboardingProgressDefinition: String, Codable, CaseIterable, Hashable {
    case betterPace = "better pace / race fitness"
    case moreMuscle = "more muscle"
    case lowerBodyFat = "lower body fat"
    case moreEnergy = "more energy"
    case fewerMissedWeeks = "fewer missed weeks"
    case clearerStructure = "clearer structure"
    case betterRecovery = "better recovery"
    case allAroundImprovement = "all-around improvement"
}

enum OnboardingRecoveryProfile: String, Codable, CaseIterable, Hashable {
    case veryWell = "very well"
    case fairlyWell = "fairly well"
    case depends = "it depends"
    case notGreat = "not great"
    case runDown = "i often feel run down"
}

enum OnboardingCoachPushStyle: String, Codable, CaseIterable, Hashable {
    case challengeHard = "challenge me hard"
    case intelligentPush = "push me, but intelligently"
    case steadyRealistic = "keep me steady and realistic"
    case cautiousRecovery = "be cautious with recovery"
    case adaptive = "adapt based on how i'm doing"
}

enum OnboardingCoachTone: String, Codable, CaseIterable, Hashable {
    case direct = "direct"
    case calm = "calm"
    case analytical = "analytical"
    case supportive = "supportive"
    case disciplined = "disciplined"
}

enum OnboardingRunningPlanStatus: String, Codable, CaseIterable, Hashable {
    case yes = "yes"
    case no = "no"
    case loosely = "loosely"
    case onlyForEvent = "only when training for something"
}

enum OnboardingWeeklyStructurePreference: String, Codable, CaseIterable, Hashable {
    case buildIt = "yes, build it for me"
    case flexible = "yes, but keep it flexible"
    case guide = "mostly just guide me"
    case notYet = "not yet"
}

enum OnboardingHelpArea: String, Codable, CaseIterable, Hashable {
    case weeklyPlan = "weekly plan"
    case trainingBalance = "training balance"
    case recovery = "recovery"
    case runningProgression = "running progression"
    case muscleWithoutLosingEndurance = "building muscle without losing endurance"
    case stayingConsistent = "staying consistent"
}

enum OnboardingAggressiveness: String, Codable {
    case assertive
    case measured
    case conservative
}

enum OnboardingRecoveryCautionLevel: String, Codable {
    case low
    case medium
    case high
}

enum OnboardingStructurePreference: String, Codable {
    case highlyStructured
    case guidedFlexible
    case lightTouch
}

struct OnboardingProfile: Codable, Equatable {
    var primaryIdentity: OnboardingPrimaryIdentity?
    var goals: [OnboardingGoal]
    var topPriority: OnboardingPriority?
    var eventGoal: OnboardingEventGoal?
    var customEventName: String
    var availableDays: Int?
    var trainingModalities: [OnboardingTrainingModality]
    var obstacles: [OnboardingObstacle]
    var deeperWhy: OnboardingWhy?
    var deeperWhyCustomText: String
    var coachReminder: OnboardingCoachReminder?
    var coachReminderCustomText: String
    var desiredOutcomeIdentity: OnboardingOutcomeIdentity?
    var progressDefinition: [OnboardingProgressDefinition]
    var recoveryProfile: OnboardingRecoveryProfile?
    var preferredCoachPushStyle: OnboardingCoachPushStyle?
    var preferredCoachTone: OnboardingCoachTone?
    var followsRunningPlan: OnboardingRunningPlanStatus?
    var wantsWeeklyStructure: OnboardingWeeklyStructurePreference?
    var firstHelpArea: OnboardingHelpArea?
    var commitmentSigned: Bool
    var commitmentSignatureAssetURL: String?
    var onboardingCompletedAt: Date?

    init(
        primaryIdentity: OnboardingPrimaryIdentity? = nil,
        goals: [OnboardingGoal] = [],
        topPriority: OnboardingPriority? = nil,
        eventGoal: OnboardingEventGoal? = nil,
        customEventName: String = "",
        availableDays: Int? = nil,
        trainingModalities: [OnboardingTrainingModality] = [],
        obstacles: [OnboardingObstacle] = [],
        deeperWhy: OnboardingWhy? = nil,
        deeperWhyCustomText: String = "",
        coachReminder: OnboardingCoachReminder? = nil,
        coachReminderCustomText: String = "",
        desiredOutcomeIdentity: OnboardingOutcomeIdentity? = nil,
        progressDefinition: [OnboardingProgressDefinition] = [],
        recoveryProfile: OnboardingRecoveryProfile? = nil,
        preferredCoachPushStyle: OnboardingCoachPushStyle? = nil,
        preferredCoachTone: OnboardingCoachTone? = nil,
        followsRunningPlan: OnboardingRunningPlanStatus? = nil,
        wantsWeeklyStructure: OnboardingWeeklyStructurePreference? = nil,
        firstHelpArea: OnboardingHelpArea? = nil,
        commitmentSigned: Bool = false,
        commitmentSignatureAssetURL: String? = nil,
        onboardingCompletedAt: Date? = nil
    ) {
        self.primaryIdentity = primaryIdentity
        self.goals = goals
        self.topPriority = topPriority
        self.eventGoal = eventGoal
        self.customEventName = customEventName
        self.availableDays = availableDays
        self.trainingModalities = trainingModalities
        self.obstacles = obstacles
        self.deeperWhy = deeperWhy
        self.deeperWhyCustomText = deeperWhyCustomText
        self.coachReminder = coachReminder
        self.coachReminderCustomText = coachReminderCustomText
        self.desiredOutcomeIdentity = desiredOutcomeIdentity
        self.progressDefinition = progressDefinition
        self.recoveryProfile = recoveryProfile
        self.preferredCoachPushStyle = preferredCoachPushStyle
        self.preferredCoachTone = preferredCoachTone
        self.followsRunningPlan = followsRunningPlan
        self.wantsWeeklyStructure = wantsWeeklyStructure
        self.firstHelpArea = firstHelpArea
        self.commitmentSigned = commitmentSigned
        self.commitmentSignatureAssetURL = commitmentSignatureAssetURL
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    var deeperWhyText: String? {
        if deeperWhy == .other {
            return normalizedOptionalText(deeperWhyCustomText)
        }
        return deeperWhy?.rawValue
    }

    var coachReminderText: String? {
        if coachReminder == .custom {
            return normalizedOptionalText(coachReminderCustomText)
        }
        return coachReminder?.rawValue
    }

    var normalizedEventGoal: String? {
        if eventGoal == .somethingElse {
            return normalizedOptionalText(customEventName) ?? eventGoal?.rawValue
        }
        guard eventGoal != .none else { return nil }
        return eventGoal?.rawValue
    }

    var isComplete: Bool {
        primaryIdentity != nil &&
        !goals.isEmpty &&
        topPriority != nil &&
        availableDays != nil &&
        !trainingModalities.isEmpty &&
        !obstacles.isEmpty &&
        deeperWhyText != nil &&
        coachReminderText != nil &&
        desiredOutcomeIdentity != nil &&
        !progressDefinition.isEmpty &&
        recoveryProfile != nil &&
        preferredCoachPushStyle != nil &&
        preferredCoachTone != nil &&
        followsRunningPlan != nil &&
        wantsWeeklyStructure != nil &&
        firstHelpArea != nil &&
        commitmentSigned
    }
}

struct DerivedCoachingProfile: Codable, Equatable {
    var coachPersonaSummary: String
    var recommendationAggressiveness: OnboardingAggressiveness
    var recoveryCautionLevel: OnboardingRecoveryCautionLevel
    var structurePreference: OnboardingStructurePreference
    var motivationProfile: String
    var primarySuccessMetric: String

    static let empty = DerivedCoachingProfile(
        coachPersonaSummary: "",
        recommendationAggressiveness: .measured,
        recoveryCautionLevel: .medium,
        structurePreference: .guidedFlexible,
        motivationProfile: "",
        primarySuccessMetric: ""
    )
}

struct OnboardingPersonalizationResult: Codable, Equatable {
    var coachProfileSummary: String
    var startingFocus: [String]
    var welcomeMessage: String
    var firstWeekRecommendation: String
    var coachStyleLine: String
    var whyLine: String

    static func fallback(profile: OnboardingProfile, derived: DerivedCoachingProfile) -> OnboardingPersonalizationResult {
        let whyLine = profile.deeperWhyText ?? "build something that lasts"
        let tone = profile.preferredCoachTone?.rawValue ?? "calm"
        let focuses = fallbackStartingFocus(profile: profile)

        return OnboardingPersonalizationResult(
            coachProfileSummary: derived.coachPersonaSummary,
            startingFocus: focuses,
            welcomeMessage: "We start with a week you can actually repeat.",
            firstWeekRecommendation: fallbackWeekRecommendation(profile: profile),
            coachStyleLine: "\(tone) + \(derived.structurePreference.displayLabel)",
            whyLine: whyLine
        )
    }

    private static func fallbackStartingFocus(profile: OnboardingProfile) -> [String] {
        var values: [String] = []

        if profile.firstHelpArea == .weeklyPlan || profile.wantsWeeklyStructure == .buildIt {
            values.append("build a repeatable week")
        }
        if profile.recoveryProfile == .runDown || profile.preferredCoachPushStyle == .cautiousRecovery {
            values.append("protect recovery")
        }
        if profile.primaryIdentity == .balanceBoth || profile.desiredOutcomeIdentity == .balancedHybrid {
            values.append("develop hybrid balance")
        }
        if values.isEmpty {
            values.append("set a clear first rhythm")
        }

        return Array(values.prefix(3))
    }

    private static func fallbackWeekRecommendation(profile: OnboardingProfile) -> String {
        let days = profile.availableDays ?? 4
        switch days {
        case 0...3:
            return "Keep the opening week compact. Fewer sessions, better timing."
        case 4...5:
            return "Aim for balance. Two anchor sessions, enough easy work to recover."
        default:
            return "Use ambition carefully. The first week should still leave room to absorb training."
        }
    }
}

struct CoachAthleteProfile: Codable, Equatable {
    let primary_identity: String?
    let goals: [String]
    let top_priority: String?
    let event_goal: String?
    let available_days: Int?
    let training_modalities: [String]
    let obstacles: [String]
    let deeper_why: String?
    let coach_reminder: String?
    let desired_outcome_identity: String?
    let progress_definition: [String]
    let recovery_profile: String?
    let preferred_coach_push_style: String?
    let preferred_coach_tone: String?
    let follows_running_plan: String?
    let wants_weekly_structure: String?
    let first_help_area: String?
    let coach_persona_summary: String
    let recommendation_aggressiveness: String
    let recovery_caution_level: String
    let structure_preference: String
    let motivation_profile: String
    let primary_success_metric: String
}

extension OnboardingProfile {
    func makeCoachAthleteProfile(derived: DerivedCoachingProfile) -> CoachAthleteProfile {
        CoachAthleteProfile(
            primary_identity: primaryIdentity?.rawValue,
            goals: goals.map(\.rawValue),
            top_priority: topPriority?.rawValue,
            event_goal: normalizedEventGoal,
            available_days: availableDays,
            training_modalities: trainingModalities.map(\.rawValue),
            obstacles: obstacles.map(\.rawValue),
            deeper_why: deeperWhyText,
            coach_reminder: coachReminderText,
            desired_outcome_identity: desiredOutcomeIdentity?.rawValue,
            progress_definition: progressDefinition.map(\.rawValue),
            recovery_profile: recoveryProfile?.rawValue,
            preferred_coach_push_style: preferredCoachPushStyle?.rawValue,
            preferred_coach_tone: preferredCoachTone?.rawValue,
            follows_running_plan: followsRunningPlan?.rawValue,
            wants_weekly_structure: wantsWeeklyStructure?.rawValue,
            first_help_area: firstHelpArea?.rawValue,
            coach_persona_summary: derived.coachPersonaSummary,
            recommendation_aggressiveness: derived.recommendationAggressiveness.rawValue,
            recovery_caution_level: derived.recoveryCautionLevel.rawValue,
            structure_preference: derived.structurePreference.rawValue,
            motivation_profile: derived.motivationProfile,
            primary_success_metric: derived.primarySuccessMetric
        )
    }
}

extension OnboardingStructurePreference {
    var displayLabel: String {
        switch self {
        case .highlyStructured:
            return "structured"
        case .guidedFlexible:
            return "flexible"
        case .lightTouch:
            return "light touch"
        }
    }
}

func deriveCoachingProfile(from profile: OnboardingProfile) -> DerivedCoachingProfile {
    let aggressiveness: OnboardingAggressiveness = {
        if profile.preferredCoachPushStyle == .challengeHard, (profile.availableDays ?? 0) >= 5 {
            return .assertive
        }
        if profile.recoveryProfile == .runDown || profile.preferredCoachPushStyle == .cautiousRecovery {
            return .conservative
        }
        return .measured
    }()

    let recoveryCaution: OnboardingRecoveryCautionLevel = {
        switch profile.recoveryProfile {
        case .runDown, .notGreat:
            return .high
        case .depends:
            return .medium
        default:
            return profile.preferredCoachPushStyle == .cautiousRecovery ? .high : .low
        }
    }()

    let structurePreference: OnboardingStructurePreference = {
        switch profile.wantsWeeklyStructure {
        case .buildIt:
            return .highlyStructured
        case .flexible:
            return .guidedFlexible
        case .guide:
            return .lightTouch
        case .notYet, nil:
            return .lightTouch
        }
    }()

    let persona = [
        profile.preferredCoachTone?.rawValue,
        profile.preferredCoachPushStyle?.rawValue,
        profile.desiredOutcomeIdentity?.rawValue
    ]
    .compactMap { $0 }
    .joined(separator: " · ")

    let motivation = profile.deeperWhyText ?? profile.topPriority?.rawValue ?? "long-term progress"
    let successMetric = profile.progressDefinition.first?.rawValue
        ?? profile.topPriority?.rawValue
        ?? "consistency"

    return DerivedCoachingProfile(
        coachPersonaSummary: persona.isEmpty ? "calm, intelligent hybrid guidance" : persona,
        recommendationAggressiveness: aggressiveness,
        recoveryCautionLevel: recoveryCaution,
        structurePreference: structurePreference,
        motivationProfile: motivation,
        primarySuccessMetric: successMetric
    )
}

private func normalizedOptionalText(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
#endif
