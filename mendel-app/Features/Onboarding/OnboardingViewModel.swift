#if !WIDGET_EXTENSION
//
// OnboardingViewModel.swift
// Step orchestration, validation, and personalization pipeline.
//

import Foundation
import Observation
import SwiftUI
import UIKit

enum OnboardingStep: String, CaseIterable, Identifiable {
    case opening
    case structureStatement
    case primaryIdentity
    case goals
    case topPriority
    case eventGoal
    case availableDays
    case trainingModalities
    case obstacles
    case whyInterstitial
    case deeperWhy
    case coachReminder
    case outcomeIdentity
    case progressDefinition
    case recoveryProfile
    case coachPushStyle
    case coachTone
    case runningPlan
    case weeklyStructure
    case firstHelpArea
    case balanceInterstitial
    case commitmentIntro
    case signature
    case commitmentLocked
    case buildProfile
    case personalizedPreview
    case account
    case notifications
    case health
    case paywall

    var id: String { rawValue }
}

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep
    var signaturePoints: [CGPoint] = []
    var isPreparingPersonalization = false
    var personalizationReady = false
    var buildProgress: Double = 0
    var buildStates: [BuildItemState] = BuildItemState.makeInitialStates()

    private let store: OnboardingStore
    private let personalizationService: OnboardingPersonalizationService
    private let profileSyncService = OnboardingProfileSyncService()

    init(
        store: OnboardingStore,
        personalizationService: OnboardingPersonalizationService? = nil
    ) {
        self.store = store
        self.personalizationService = personalizationService ?? OnboardingPersonalizationService()
        self.currentStep = OnboardingStep(rawValue: store.currentStepID) ?? .opening
    }

    var profile: OnboardingProfile { store.profile }
    var derivedProfile: DerivedCoachingProfile { store.derivedProfile }
    var personalization: OnboardingPersonalizationResult {
        store.personalization ?? .fallback(profile: profile, derived: derivedProfile)
    }

    var orderedSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .opening,
            .structureStatement,
            .primaryIdentity,
            .goals,
            .topPriority
        ]

        if profile.goals.contains(.trainForEvent) {
            steps.append(.eventGoal)
        }

        steps += [
            .availableDays,
            .trainingModalities,
            .obstacles,
            .whyInterstitial,
            .deeperWhy,
            .coachReminder,
            .outcomeIdentity,
            .progressDefinition,
            .recoveryProfile,
            .coachPushStyle,
            .coachTone,
            .runningPlan,
            .weeklyStructure,
            .firstHelpArea,
            .balanceInterstitial,
            .commitmentIntro,
            .signature,
            .commitmentLocked,
            .buildProfile,
            .personalizedPreview,
            .account,
            .notifications,
            .health
        ]

        steps.append(.paywall)

        return steps
    }

    var progressValue: Double {
        let steps = orderedSteps
        guard let index = steps.firstIndex(of: currentStep) else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    var canGoBack: Bool {
        currentStep != orderedSteps.first
    }

    var canContinue: Bool {
        switch currentStep {
        case .opening, .structureStatement, .whyInterstitial, .balanceInterstitial, .commitmentIntro, .commitmentLocked, .account, .notifications, .health, .paywall:
            return true
        case .primaryIdentity:
            return profile.primaryIdentity != nil
        case .goals:
            return !profile.goals.isEmpty && profile.goals.count <= 3
        case .topPriority:
            return profile.topPriority != nil
        case .eventGoal:
            guard let eventGoal = profile.eventGoal else { return false }
            if eventGoal == .somethingElse {
                return !profile.customEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        case .availableDays:
            return profile.availableDays != nil
        case .trainingModalities:
            return !profile.trainingModalities.isEmpty
        case .obstacles:
            return !profile.obstacles.isEmpty
        case .deeperWhy:
            guard let why = profile.deeperWhy else { return false }
            return why != .other || !profile.deeperWhyCustomText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .coachReminder:
            guard let reminder = profile.coachReminder else { return false }
            return reminder != .custom || !profile.coachReminderCustomText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .outcomeIdentity:
            return profile.desiredOutcomeIdentity != nil
        case .progressDefinition:
            return !profile.progressDefinition.isEmpty
        case .recoveryProfile:
            return profile.recoveryProfile != nil
        case .coachPushStyle:
            return profile.preferredCoachPushStyle != nil
        case .coachTone:
            return profile.preferredCoachTone != nil
        case .runningPlan:
            return profile.followsRunningPlan != nil
        case .weeklyStructure:
            return profile.wantsWeeklyStructure != nil
        case .firstHelpArea:
            return profile.firstHelpArea != nil
        case .signature:
            return profile.commitmentSigned
        case .buildProfile:
            return personalizationReady
        case .personalizedPreview:
            return true
        }
    }

    func updateProfile(_ mutate: (inout OnboardingProfile) -> Void) {
        store.updateProfile(mutate)
    }

    func onAppearForCurrentStep() {
        store.setCurrentStepID(currentStep.id)
        OnboardingAnalytics.log(.viewedStep, metadata: ["step": currentStep.id])

        if currentStep == .buildProfile {
            Task { await preparePersonalizationIfNeeded() }
        }
    }

    func continueForward() {
        guard canContinue else { return }
        OnboardingAnalytics.log(.tappedContinue, metadata: ["step": currentStep.id])
        Haptics.selection()
        guard let index = orderedSteps.firstIndex(of: currentStep), index + 1 < orderedSteps.count else {
            finishOnboarding()
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            currentStep = orderedSteps[index + 1]
            store.setCurrentStepID(currentStep.id)
        }
    }

    func goBack() {
        guard canGoBack, let index = orderedSteps.firstIndex(of: currentStep), index > 0 else { return }
        OnboardingAnalytics.log(.tappedBack, metadata: ["step": currentStep.id])
        withAnimation(.spring(response: 0.42, dampingFraction: 0.95)) {
            currentStep = orderedSteps[index - 1]
            store.setCurrentStepID(currentStep.id)
        }
    }

    func toggleGoal(_ goal: OnboardingGoal) {
        updateSelection(goal, limit: 3, in: \.goals)
    }

    func toggleTrainingModality(_ modality: OnboardingTrainingModality) {
        updateSelection(modality, limit: 8, in: \.trainingModalities)
    }

    func selectObstacle(_ obstacle: OnboardingObstacle) {
        updateProfile { $0.obstacles = [obstacle] }
        OnboardingAnalytics.log(.selectedOption, metadata: ["step": currentStep.id, "value": obstacle.rawValue])
    }

    func toggleProgressDefinition(_ item: OnboardingProgressDefinition) {
        updateSelection(item, limit: 8, in: \.progressDefinition)
    }

    func saveSignature(strokes: [CGPoint]) {
        signaturePoints = strokes
        guard !strokes.isEmpty else {
            updateProfile {
                $0.commitmentSigned = false
                $0.commitmentSignatureAssetURL = nil
            }
            return
        }

        let url = SignatureAssetStore.shared.saveSignature(points: strokes)
        updateProfile {
            $0.commitmentSigned = true
            $0.commitmentSignatureAssetURL = url?.absoluteString
        }
        Haptics.success()
        OnboardingAnalytics.log(.commitmentSigned)
    }

    func preparePersonalizationIfNeeded() async {
        guard !personalizationReady, !isPreparingPersonalization else { return }

        isPreparingPersonalization = true
        buildProgress = 0
        buildStates = BuildItemState.makeInitialStates()
        OnboardingAnalytics.log(.personalizationStarted)

        let stepDelay: UInt64 = 250_000_000
        for index in buildStates.indices {
            buildStates[index].status = .active
            buildProgress = Double(index) / Double(max(buildStates.count, 1))
            try? await Task.sleep(nanoseconds: stepDelay)
            buildStates[index].status = .done
            buildProgress = Double(index + 1) / Double(buildStates.count)
        }

        do {
            let result = try await personalizationService.buildPersonalization(
                profile: profile,
                derivedProfile: derivedProfile
            )
            store.setPersonalization(result)
        } catch {
            store.setPersonalization(.fallback(profile: profile, derived: derivedProfile))
        }

        personalizationReady = true
        isPreparingPersonalization = false
        Haptics.success()
        OnboardingAnalytics.log(.personalizationCompleted)
    }

    func finishOnboarding() {
        store.markComplete()
        Task {
            await profileSyncService.syncIfPossible(profile: profile, derivedProfile: derivedProfile)
        }
        OnboardingAnalytics.log(.completedOnboarding)
    }

    private func updateSelection<Value: Hashable>(
        _ value: Value,
        limit: Int,
        in keyPath: WritableKeyPath<OnboardingProfile, [Value]>
    ) {
        store.updateProfile { profile in
            var values = profile[keyPath: keyPath]
            if let index = values.firstIndex(of: value) {
                values.remove(at: index)
            } else if values.count < limit {
                values.append(value)
            }
            profile[keyPath: keyPath] = values
        }

        OnboardingAnalytics.log(.selectedOption, metadata: ["step": currentStep.id, "value": String(describing: value)])
    }
}

struct BuildItemState: Identifiable {
    enum Status {
        case pending
        case active
        case done
    }

    let id = UUID()
    let title: String
    var status: Status

    static func makeInitialStates() -> [BuildItemState] {
        [
            BuildItemState(title: "configuring your goals", status: .pending),
            BuildItemState(title: "tuning your coach style", status: .pending),
            BuildItemState(title: "mapping your weekly rhythm", status: .pending),
            BuildItemState(title: "setting your first priorities", status: .pending),
            BuildItemState(title: "preparing your starting guidance", status: .pending)
        ]
    }
}

enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
#endif
