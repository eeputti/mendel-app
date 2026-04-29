#if !WIDGET_EXTENSION
//
// OnboardingStore.swift
// Local persistence, resume support, and plan seeding for onboarding.
//

import Foundation
import Observation

@Observable
final class OnboardingStore {
    var profile: OnboardingProfile
    var derivedProfile: DerivedCoachingProfile
    var personalization: OnboardingPersonalizationResult?
    var currentStepID: String
    var authSupportAvailable = false

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let snapshot = "onboarding.snapshot.v1"
        static let completion = "onboarding.completed.v1"
        static let planGoal = "plan.goal"
        static let planSports = "plan.sports"
        static let planSessionsPerWeek = "plan.sessionsPerWeek"
        static let planWeeklyStructure = "plan.weeklyStructure"
    }

    static func loadPersistedAthleteProfile(defaults: UserDefaults = .standard) -> CoachAthleteProfile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = defaults.data(forKey: Keys.snapshot),
              let snapshot = try? decoder.decode(OnboardingSnapshot.self, from: data) else {
            return nil
        }

        return snapshot.profile.makeCoachAthleteProfile(derived: snapshot.derivedProfile)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder.outputFormatting = [.sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        if let data = defaults.data(forKey: Keys.snapshot),
           let snapshot = try? decoder.decode(OnboardingSnapshot.self, from: data) {
            profile = snapshot.profile
            derivedProfile = snapshot.derivedProfile
            personalization = snapshot.personalization
            currentStepID = snapshot.currentStepID
        } else {
            profile = OnboardingProfile()
            derivedProfile = .empty
            personalization = nil
            currentStepID = OnboardingStep.opening.id
        }
    }

    var isCompleted: Bool {
        defaults.bool(forKey: Keys.completion)
    }

    func updateProfile(_ mutate: (inout OnboardingProfile) -> Void) {
        mutate(&profile)
        derivedProfile = deriveCoachingProfile(from: profile)
        persist()
    }

    func setCurrentStepID(_ id: String) {
        currentStepID = id
        persist()
    }

    func setPersonalization(_ result: OnboardingPersonalizationResult) {
        personalization = result
        persist()
    }

    func markComplete() {
        updateProfile { $0.onboardingCompletedAt = .now }
        defaults.set(true, forKey: Keys.completion)
        seedPlanSettingsFromOnboarding()
        persist()
    }

    func reset() {
        profile = OnboardingProfile()
        derivedProfile = .empty
        personalization = nil
        currentStepID = OnboardingStep.opening.id
        defaults.removeObject(forKey: Keys.completion)
        persist()
    }

    func seedPlanSettingsFromOnboarding() {
        let goal = mappedTrainingGoal()
        defaults.set(goal.rawValue, forKey: Keys.planGoal)
        defaults.set(mappedPlanSports().joinedRawValue, forKey: Keys.planSports)
        defaults.set(profile.availableDays ?? 4, forKey: Keys.planSessionsPerWeek)
        defaults.set(mappedWeeklyStructureString(), forKey: Keys.planWeeklyStructure)
    }

    private func mappedTrainingGoal() -> TrainingGoal {
        if let event = profile.eventGoal {
            switch event {
            case .marathon:
                return .marathon
            case .halfMarathon:
                return .halfMarathon
            case .fiveK, .tenK:
                return .cooper
            default:
                break
            }
        }

        if profile.goals.contains(.buildMuscle), profile.goals.contains(.improveEndurance) {
            return .strengthEnduranceBalance
        }

        switch profile.primaryIdentity {
        case .mainlyRun:
            return .halfMarathon
        case .mainlyLift, .balanceBoth:
            return .hybridFitness
        case .generalFitness, .returning, nil:
            return .generalHealth
        }
    }

    private func mappedPlanSports() -> [PlanSport] {
        var sports: [PlanSport] = []
        for modality in profile.trainingModalities {
            switch modality {
            case .running, .intervals, .longRuns:
                appendUnique(.running, to: &sports)
            case .gym:
                appendUnique(.gym, to: &sports)
            case .walking:
                appendUnique(.walking, to: &sports)
            case .cycling:
                appendUnique(.cycling, to: &sports)
            case .mobility:
                appendUnique(.mobility, to: &sports)
            case .sportPractice:
                appendUnique(.tennis, to: &sports)
            case .nothingConsistent:
                break
            }
        }

        if sports.isEmpty {
            sports = mappedTrainingGoal().defaultSports
        }

        return sports
    }

    private func mappedWeeklyStructureString() -> String {
        let days = profile.availableDays ?? 4
        switch days {
        case 0...2:
            return "Tue strength, Sat run"
        case 3:
            return "Mon strength, Wed run, Sat long"
        case 4:
            return "Mon strength, Tue easy, Thu strength, Sat long"
        case 5:
            return "Mon easy, Tue strength, Thu quality, Sat long, Sun recovery"
        default:
            return "Mon easy, Tue strength, Wed quality, Fri strength, Sat long, Sun mobility"
        }
    }

    private func persist() {
        let snapshot = OnboardingSnapshot(
            profile: profile,
            derivedProfile: derivedProfile,
            personalization: personalization,
            currentStepID: currentStepID
        )

        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.snapshot)
    }

    private func appendUnique(_ sport: PlanSport, to sports: inout [PlanSport]) {
        if !sports.contains(sport) {
            sports.append(sport)
        }
    }
}

private struct OnboardingSnapshot: Codable {
    let profile: OnboardingProfile
    let derivedProfile: DerivedCoachingProfile
    let personalization: OnboardingPersonalizationResult?
    let currentStepID: String
}
#endif
