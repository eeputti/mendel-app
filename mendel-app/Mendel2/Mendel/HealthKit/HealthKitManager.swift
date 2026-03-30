import HealthKit
import Foundation

// MARK: - HealthKit Manager

@Observable
final class HealthKitManager {

    private let store = HKHealthStore()

    var isAuthorized: Bool = false
    var authorizationDenied: Bool = false

    // Latest values surfaced to the engine
    var restingHeartRate: Double? = nil    // bpm
    var hrv: Double? = nil                  // ms, SDNN
    var stepsToday: Int = 0
    var recentWorkouts: [HKWorkout] = []

    // MARK: - Types we read

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate)   { types.insert(rhr) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount)        { types.insert(steps) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)    { types.insert(sleep) }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchAll()
        } catch {
            authorizationDenied = true
        }
    }

    // MARK: - Fetch All

    func fetchAll() async {
        async let rhr     = fetchRestingHeartRate()
        async let hrvVal  = fetchHRV()
        async let steps   = fetchStepsToday()
        async let workouts = fetchRecentWorkouts(days: 7)

        restingHeartRate = await rhr
        hrv              = await hrvVal
        stepsToday       = await steps
        recentWorkouts   = await workouts
    }

    // MARK: - Individual Fetches

    private func fetchRestingHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                cont.resume(returning: sample.quantity.doubleValue(for: .init(from: "count/min")))
            }
            store.execute(query)
        }
    }

    private func fetchHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                cont.resume(returning: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            }
            store.execute(query)
        }
    }

    private func fetchStepsToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let pred  = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(count))
            }
            store.execute(query)
        }
    }

    private func fetchRecentWorkouts(days: Int) async -> [HKWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let pred   = HKQuery.predicateForSamples(withStart: cutoff, end: .now)
        let sort   = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Convert HKWorkout → Session (for engine)

    /// Maps HealthKit workouts to Mendel Session-compatible structs.
    /// Used to pre-populate load even without manual logging.
    func toEngineSessions() -> [HealthSession] {
        recentWorkouts.compactMap { workout in
            let duration = workout.duration / 60  // minutes
            let type = mapWorkoutType(workout.workoutActivityType)
            let intensity = inferIntensity(workout: workout)
            return HealthSession(
                date:            workout.endDate,
                type:            type,
                intensity:       intensity,
                durationMinutes: Int(duration),
                distanceKm:      workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
            )
        }
    }

    private func mapWorkoutType(_ type: HKWorkoutActivityType) -> SessionType {
        switch type {
        case .running, .cycling, .rowing, .swimming, .hiking, .walking:
            return .run
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining, .highIntensityIntervalTraining:
            return .strength
        default:
            return .sport
        }
    }

    private func inferIntensity(workout: HKWorkout) -> IntensityLevel {
        // Use average heart rate if available (via metadata or associated samples)
        // Fallback: duration-based heuristic
        let minutes = workout.duration / 60
        if minutes > 75 { return .hard }
        if minutes > 35 { return .moderate }
        return .easy
    }
}

// MARK: - Lightweight session struct (bridge to engine)

struct HealthSession {
    let date: Date
    let type: SessionType
    let intensity: IntensityLevel
    let durationMinutes: Int
    let distanceKm: Double?

    var loadScore: Double {
        let m = Double(intensity.rawValue)
        switch type {
        case .strength: return min(Double(durationMinutes) / 60 * m * 2, 5)
        case .run:      return min((distanceKm ?? Double(durationMinutes) / 6) * m * 0.3, 5)
        case .sport:    return min(Double(durationMinutes) / 60 * m, 5)
        }
    }
}
