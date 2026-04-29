#if !WIDGET_EXTENSION
//
// HealthKitManager.swift
// Health data reads used by recommendations.
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()
    private var authorizationRequestInFlight = false
    var isAuthorized = false
    var authorizationDenied = false
    var restingHeartRate: Double?
    var hrv: Double?
    var stepsToday = 0
    var recentWorkouts: [HKWorkout] = []

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let value = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(value) }
        if let value = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(value) }
        if let value = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(value) }
        if let value = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(value) }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    func requestAuthorization() async {
        guard !authorizationRequestInFlight, !isAuthorized else { return }
        guard HKHealthStore.isHealthDataAvailable(), !readTypes.isEmpty else {
            authorizationDenied = true
            return
        }

        authorizationRequestInFlight = true
        defer { authorizationRequestInFlight = false }

        do {
            try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            isAuthorized = true
            authorizationDenied = false
            await fetchAll()
        } catch {
            isAuthorized = false
            authorizationDenied = true
        }
    }

    func fetchAll() async {
        async let restingHeartRate = fetchRHR()
        async let hrv = fetchHRV()
        async let steps = fetchStepsToday()
        async let workouts = fetchRecentWorkouts(days: 7)

        self.restingHeartRate = await restingHeartRate
        self.hrv = await hrv
        self.stepsToday = await steps
        self.recentWorkouts = await workouts
    }

    func toEngineSessions() -> [HealthSession] {
        Self.engineSessions(from: recentWorkouts)
    }

    static func engineSessions(from workouts: [HKWorkout]) -> [HealthSession] {
        workouts.compactMap { workout in
            HealthSession(
                date: workout.endDate,
                type: mapType(workout.workoutActivityType),
                intensity: inferIntensity(workout),
                durationMinutes: Int(workout.duration / 60),
                distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
            )
        }
    }

    private func fetchRHR() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: .init(from: "count/min")))
            }
            store.execute(query)
        }
    }

    private func fetchHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            }
            store.execute(query)
        }
    }

    private func fetchStepsToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            store.execute(query)
        }
    }

    private func fetchRecentWorkouts(days: Int) async -> [HKWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: .now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func mapType(_ type: HKWorkoutActivityType) -> SessionType {
        switch type {
        case .running, .cycling, .rowing, .swimming, .hiking, .walking:
            return .run
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining, .highIntensityIntervalTraining:
            return .strength
        default:
            return .sport
        }
    }

    private static func inferIntensity(_ workout: HKWorkout) -> IntensityLevel {
        let minutes = workout.duration / 60
        if minutes > 75 { return .hard }
        if minutes > 35 { return .moderate }
        return .easy
    }
}
#endif
