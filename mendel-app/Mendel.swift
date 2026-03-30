// =============================================================
// MENDEL — COMBINED SOURCE FILE
// Drop this single file into your Xcode project (main app target).
// Do NOT add this file to the MendelWidget target.
// Requires iOS 17+, SwiftData, WidgetKit, HealthKit, StoreKit.
// =============================================================

import SwiftUI
import SwiftData
import Foundation
import HealthKit
import StoreKit
import WidgetKit
import UserNotifications

// =============================================================
// MARK: - MODELS
// =============================================================

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

enum BodyLoad {
    case strength, endurance, mixed
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

    var bodyLoad: BodyLoad {
        switch type {
        case .strength: return .strength
        case .run:      return .endurance
        case .sport:    return intensity == .hard ? .endurance : .mixed
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
        self.id           = UUID()
        self.date         = date
        self.sleepQuality = sleepQuality
        self.soreness     = soreness
    }
}

enum DeepLinkHandler {
    static func handle(url: URL, state: MendelAppState) {
        guard url.scheme == "mendel" else { return }
        switch url.host {
        case "today":  state.selectedTab = .today
        case "log":    state.selectedTab = .log
        case "week":   state.selectedTab = .week
        case "coach":  state.selectedTab = .coach
        default:        state.selectedTab = .today
        }
    }
}

// =============================================================
// MARK: - DECISION ENGINE
// =============================================================

struct Recommendation: Equatable {
    let state:   TrainingState
    let context: String
    let steps:   [String]
}

enum TrainingState: String, Equatable {
    case train   = "TRAIN"
    case recover = "RECOVER"
    case rest    = "REST"
}

struct WeeklySummary {
    let strengthSessions:  Int
    let enduranceSessions: Int
    let recoverySessions:  Int
    let totalLoadScore:    Double
    let strengthBalance:   Double
    let enduranceBalance:  Double

    static func compute(sessions: [Session]) -> WeeklySummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let week   = sessions.filter { $0.date >= cutoff }
        let str    = week.filter { $0.bodyLoad == .strength }
        let end    = week.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }
        let total  = week.reduce(0.0) { $0 + $1.loadScore }
        let strLoad = str.reduce(0.0) { $0 + $1.loadScore }
        let endLoad = end.reduce(0.0) { $0 + $1.loadScore }
        let maxLoad = max(strLoad + endLoad, 1)
        return WeeklySummary(
            strengthSessions:  str.count,
            enduranceSessions: end.count,
            recoverySessions:  0,
            totalLoadScore:    total,
            strengthBalance:   min(strLoad / maxLoad, 1.0),
            enduranceBalance:  min(endLoad / maxLoad, 1.0)
        )
    }
}

struct HealthSession {
    let date:            Date
    let type:            SessionType
    let intensity:       IntensityLevel
    let durationMinutes: Int
    let distanceKm:      Double?

    var loadScore: Double {
        let m = Double(intensity.rawValue)
        switch type {
        case .strength: return min(Double(durationMinutes) / 60 * m * 2, 5)
        case .run:      return min((distanceKm ?? Double(durationMinutes) / 6) * m * 0.3, 5)
        case .sport:    return min(Double(durationMinutes) / 60 * m, 5)
        }
    }
}

struct DecisionEngine {

    static func recommend(
        sessions: [Session],
        healthSessions: [HealthSession] = [],
        latestRecovery: RecoveryLog? = nil,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil
    ) -> Recommendation {

        let window  = 5
        let cutoff  = Calendar.current.date(byAdding: .day, value: -window, to: .now)!
        let manual  = sessions.filter { $0.date >= cutoff }
        let health  = healthSessions.filter { $0.date >= cutoff }

        let manualLoad  = manual.reduce(0.0) { $0 + $1.loadScore }
        let manualDays  = Set(manual.map { Calendar.current.startOfDay(for: $0.date) })
        let dedupedHLoad = health
            .filter { !manualDays.contains(Calendar.current.startOfDay(for: $0.date)) }
            .reduce(0.0) { $0 + $1.loadScore }
        let totalLoad   = manualLoad + dedupedHLoad

        let strLoad = manual.filter { $0.bodyLoad == .strength }.reduce(0.0) { $0 + $1.loadScore }
            + health.filter { $0.type == .strength }.reduce(0.0) { $0 + $1.loadScore }
        let endLoad = manual.filter { $0.bodyLoad == .endurance || $0.bodyLoad == .mixed }.reduce(0.0) { $0 + $1.loadScore }
            + health.filter { $0.type == .run || $0.type == .sport }.reduce(0.0) { $0 + $1.loadScore }

        let soreness     = latestRecovery?.soreness     ?? .low
        let sleepQuality = latestRecovery?.sleepQuality ?? .ok
        let hrvLow       = hrv.map { $0 < 30 } ?? false
        let rhrElevated  = restingHeartRate.map { $0 > 70 } ?? false

        if hrvLow && rhrElevated && totalLoad > 6 {
            return Recommendation(state: .recover,
                context: "your HRV is low and resting HR is elevated. your nervous system needs a break.",
                steps: ["full rest or gentle walk only", "prioritise sleep — aim for 8+ hours", "no training today"])
        }
        if soreness == .high {
            return Recommendation(state: .recover,
                context: "high soreness. your body is in repair mode.",
                steps: ["walk 20 min, easy pace", "light mobility: hips, calves, shoulders", "eat well, hydrate, sleep early"])
        }
        if totalLoad > 14 {
            return Recommendation(state: .recover,
                context: "high load this week — \(String(format: "%.0f", totalLoad)) points. give it a day.",
                steps: ["walk or full rest", "mobility work, 10–15 min", "prioritise sleep tonight"])
        }
        if totalLoad > 8 && sleepQuality == .poor {
            return Recommendation(state: .rest,
                context: "high load and poor sleep don't mix. rest today.",
                steps: ["full rest — no training", "nap if possible", "in bed early, phone off"])
        }
        if hrvLow && totalLoad > 5 {
            return Recommendation(state: .train,
                context: "HRV is a bit low. train easy today — don't push intensity.",
                steps: ["easy walk or zone 2 run: 20–30 min", "keep heart rate below 140 bpm", "skip heavy lifting today"])
        }
        if totalLoad < 4 {
            return Recommendation(state: .train,
                context: "you're fresh. good day to put in work.",
                steps: suggestFocus(strLoad: strLoad, endLoad: endLoad))
        }
        if strLoad > 0 && endLoad < strLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(state: .train,
                context: "strength-heavy week. balance it with some cardio.",
                steps: ["easy run: 4–6 km, conversational pace", "zone 2 — keep heart rate below 145 bpm", "stretch after"])
        }
        if endLoad > 0 && strLoad < endLoad * 0.3 && (manual.count + health.count) >= 2 {
            return Recommendation(state: .train,
                context: "cardio-heavy week. time to add strength.",
                steps: ["upper body strength: 3–4 exercises, 3–4 sets", "moderate intensity — not max effort", "compound movements: press, row, pull"])
        }
        if totalLoad >= 4 && totalLoad <= 8 && soreness == .medium {
            return Recommendation(state: .train,
                context: "moderate load. keep intensity controlled.",
                steps: ["train, stay below RPE 7", "shorten the session if needed", "stretch and walk after"])
        }
        return Recommendation(state: .train,
            context: "load is balanced. you're good to go.",
            steps: suggestFocus(strLoad: strLoad, endLoad: endLoad))
    }

    private static func suggestFocus(strLoad: Double, endLoad: Double) -> [String] {
        if strLoad > endLoad * 1.5 {
            return ["run or row: 30–45 min, moderate effort", "keep heart rate conversational", "cool down + light stretch"]
        } else if endLoad > strLoad * 1.5 {
            return ["strength: full body or lower body focus", "3–5 sets, 5–8 reps, compound movements", "leave 1–2 reps in the tank"]
        } else {
            return ["strength: 45–60 min, your choice of split", "or run: 5–8 km at moderate pace", "listen to your body on intensity"]
        }
    }
}

// =============================================================
// MARK: - APP STATE
// =============================================================

enum MendelTab: String, CaseIterable {
    case today = "Today"
    case log   = "Log"
    case week  = "Week"
    case coach = "Coach"
}

@Observable
final class MendelAppState {
    var selectedTab: MendelTab = .today
    var recommendation: Recommendation = Recommendation(state: .train, context: "loading…", steps: [])
    var weeklySummary: WeeklySummary = WeeklySummary(strengthSessions: 0, enduranceSessions: 0, recoverySessions: 0, totalLoadScore: 0, strengthBalance: 0, enduranceBalance: 0)
    var healthPromptDismissed = false

    func refresh(sessions: [Session], recoveryLogs: [RecoveryLog], hk: HealthKitManager) {
        let latest = recoveryLogs.sorted { $0.date > $1.date }.first
        recommendation = DecisionEngine.recommend(
            sessions: sessions,
            healthSessions: hk.toEngineSessions(),
            latestRecovery: latest,
            restingHeartRate: hk.restingHeartRate,
            hrv: hk.hrv
        )
        weeklySummary = WeeklySummary.compute(sessions: sessions)
        syncWidget()
    }

    func syncWidget() {
        let shared = SharedRecommendation(
            state:     recommendation.state.rawValue,
            context:   recommendation.context,
            steps:     recommendation.steps,
            updatedAt: .now
        )
        SharedStore.save(shared)
        WidgetCenter.shared.reloadTimelines(ofKind: MendelWidgetKind.today)
    }
}

// =============================================================
// MARK: - CLAUDE SERVICE
// =============================================================

actor ClaudeService {
    private let apiKey   = "YOUR_ANTHROPIC_API_KEY"
    private let model    = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }

    private struct ResponseBody: Codable {
        struct Content: Codable {
            let type: String
            let text: String?
        }
        let content: [Content]
    }

    func send(messages: [Message], context: CoachContext) async throws -> String {
        let system = buildSystemPrompt(context: context)
        let body   = RequestBody(model: model, max_tokens: 400, system: system, messages: messages)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ClaudeError.badResponse }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    private func buildSystemPrompt(context: CoachContext) -> String {
        """
        You are Mendel, a calm and direct hybrid athlete coach.
        Context: today=\(context.todayState), weeklyLoad=\(String(format:"%.1f",context.weeklyLoad)), strength=\(context.strengthSessions), endurance=\(context.enduranceSessions), soreness=\(context.soreness), sleep=\(context.sleepQuality).
        Tone: calm, direct, specific. No hype. No exclamation marks. Max 3 sentences.
        """
    }

    enum ClaudeError: Error { case badResponse }
}

struct CoachContext {
    let todayState: String
    let weeklyLoad: Double
    let strengthSessions: Int
    let enduranceSessions: Int
    let soreness: String
    let sleepQuality: String
}

// =============================================================
// MARK: - HEALTHKIT MANAGER
// =============================================================

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()
    var isAuthorized:       Bool    = false
    var authorizationDenied: Bool   = false
    var restingHeartRate:   Double? = nil
    var hrv:                Double? = nil
    var stepsToday:         Int     = 0
    var recentWorkouts:     [HKWorkout] = []

    private let readTypes: Set<HKObjectType> = {
        var t = Set<HKObjectType>()
        if let v = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { t.insert(v) }
        if let v = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { t.insert(v) }
        if let v = HKObjectType.quantityType(forIdentifier: .stepCount) { t.insert(v) }
        if let v = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(v) }
        t.insert(HKObjectType.workoutType())
        return t
    }()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            await MainActor.run { isAuthorized = true }
            await fetchAll()
        } catch {
            await MainActor.run { authorizationDenied = true }
        }
    }

    func fetchAll() async {
        async let rhr  = fetchRHR()
        async let h    = fetchHRV()
        async let s    = fetchStepsToday()
        async let w    = fetchRecentWorkouts(days: 7)
        restingHeartRate = await rhr
        hrv              = await h
        stepsToday       = await s
        recentWorkouts   = await w
    }

    private func fetchRHR() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, s, _ in
                guard let sample = s?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                cont.resume(returning: sample.quantity.doubleValue(for: .init(from: "count/min")))
            }
            store.execute(q)
        }
    }

    private func fetchHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, s, _ in
                guard let sample = s?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                cont.resume(returning: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            }
            store.execute(q)
        }
    }

    private func fetchStepsToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let pred = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: .now)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            store.execute(q)
        }
    }

    private func fetchRecentWorkouts(days: Int) async -> [HKWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let pred   = HKQuery.predicateForSamples(withStart: cutoff, end: .now)
        let sort   = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: 20, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: (s as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
    }

    func toEngineSessions() -> [HealthSession] {
        recentWorkouts.compactMap { w in
            HealthSession(
                date:            w.endDate,
                type:            mapType(w.workoutActivityType),
                intensity:       inferIntensity(w),
                durationMinutes: Int(w.duration / 60),
                distanceKm:      w.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
            )
        }
    }

    private func mapType(_ t: HKWorkoutActivityType) -> SessionType {
        switch t {
        case .running, .cycling, .rowing, .swimming, .hiking, .walking: return .run
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining, .highIntensityIntervalTraining: return .strength
        default: return .sport
        }
    }

    private func inferIntensity(_ w: HKWorkout) -> IntensityLevel {
        let min = w.duration / 60
        if min > 75 { return .hard }
        if min > 35 { return .moderate }
        return .easy
    }
}

// =============================================================
// MARK: - PURCHASE MANAGER
// =============================================================

@Observable
final class PurchaseManager {
    var isUnlocked: Bool    = false
    var isLoading:  Bool    = false
    var error:      String? = nil

    private var product: Product? = nil
    private var transactionListener: Task<Void, Never>? = nil

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await restoreIfNeeded() }
    }

    deinit { transactionListener?.cancel() }

    func purchase() async {
        guard let product else { error = "product unavailable."; return }
        isLoading = true; error = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let v):
                let tx = try checkVerified(v)
                await tx.finish()
                isUnlocked = true
            case .userCancelled: break
            case .pending: error = "purchase is pending."
            @unknown default: break
            }
        } catch { self.error = "purchase failed." }
        isLoading = false
    }

    func restore() async {
        isLoading = true; error = nil
        do { try await AppStore.sync(); await restoreIfNeeded() }
        catch { self.error = "couldn't restore." }
        isLoading = false
    }

    var formattedPrice: String { product?.displayPrice ?? "€14.99" }

    private func loadProduct() async {
        do { let p = try await Product.products(for: ["com.dipworks.mendel.unlock"]); product = p.first }
        catch { self.error = "couldn't load product." }
    }

    private func restoreIfNeeded() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == "com.dipworks.mendel.unlock", tx.revocationDate == nil {
                isUnlocked = true; return
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result, tx.productID == "com.dipworks.mendel.unlock" {
                    await tx.finish()
                    await MainActor.run { self.isUnlocked = true }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreErr.unverified
        case .verified(let v): return v
        }
    }
    enum StoreErr: Error { case unverified }
}

// =============================================================
// MARK: - NOTIFICATION MANAGER
// =============================================================

enum NotificationID {
    static let dailyLog      = "mendel.daily.log"
    static let morningBrief  = "mendel.morning.brief"
    static let recoveryNudge = "mendel.recovery.nudge"
}

@Observable
final class NotificationManager {
    var isAuthorized:       Bool = false
    var authorizationDenied: Bool = false
    private let center = UNUserNotificationCenter.current()

    init() { Task { await checkStatus() } }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted; authorizationDenied = !granted }
            if granted { await scheduleAll() }
        } catch { await MainActor.run { authorizationDenied = true } }
    }

    func checkStatus() async {
        let s = await center.notificationSettings()
        await MainActor.run { isAuthorized = s.authorizationStatus == .authorized }
    }

    func scheduleAll(recommendation: SharedRecommendation? = nil) async {
        await center.removeAllPendingNotificationRequests()
        await scheduleMorning(recommendation: recommendation)
        await scheduleEvening()
        await scheduleRecovery(recommendation: recommendation)
    }

    private func scheduleMorning(recommendation: SharedRecommendation?) async {
        let c = UNMutableNotificationContent()
        c.sound = .default; c.interruptionLevel = .passive
        if let rec = recommendation {
            c.title = "today: \(rec.state.lowercased())"
            c.body  = rec.steps.prefix(2).joined(separator: " · ")
        } else {
            c.title = "good morning"; c.body = "open mendel to see today's recommendation."
        }
        c.userInfo = ["deeplink": "mendel://today"]
        var comps = DateComponents(); comps.hour = 8; comps.minute = 0
        let req = UNNotificationRequest(identifier: NotificationID.morningBrief,
            content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        try? await center.add(req)
    }

    func scheduleEvening(hasLoggedToday: Bool = false) async {
        guard !hasLoggedToday else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog]); return
        }
        let c = UNMutableNotificationContent()
        c.sound = .default; c.interruptionLevel = .passive
        c.title = "log today's session"; c.body = "keep your data clean. it takes 20 seconds."
        c.userInfo = ["deeplink": "mendel://log"]
        var comps = DateComponents(); comps.hour = 20; comps.minute = 30
        let req = UNNotificationRequest(identifier: NotificationID.dailyLog,
            content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        try? await center.add(req)
    }

    private func scheduleRecovery(recommendation: SharedRecommendation?) async {
        guard let rec = recommendation, rec.state == "RECOVER" || rec.state == "REST" else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.recoveryNudge]); return
        }
        let c = UNMutableNotificationContent()
        c.sound = .default; c.interruptionLevel = .passive
        c.title = rec.state == "REST" ? "rest day" : "recovery day"
        c.body  = rec.steps.first ?? "keep it easy today."
        c.userInfo = ["deeplink": "mendel://today"]
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 12; comps.minute = 0
        let req = UNNotificationRequest(identifier: NotificationID.recoveryNudge,
            content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        try? await center.add(req)
    }

    func didLogSession() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyLog])
    }
}

final class MendelNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        if let deeplink = response.notification.request.content.userInfo["deeplink"] as? String,
           let url = URL(string: deeplink) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .mendelDeepLink, object: url)
            }
        }
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let mendelDeepLink = Notification.Name("mendel.deeplink")
}

// =============================================================
// MARK: - DESIGN SYSTEM
// =============================================================

enum MendelColors {
    static let bg       = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let white    = Color.white
    static let ink      = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let inkSoft  = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.35)
    static let inkFaint = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.12)
    static let stone    = Color(red: 0.77, green: 0.66, blue: 0.51)
}

enum MendelType {
    static func stateWord()   -> Font { .system(size: 72, weight: .heavy) }
    static func screenTitle() -> Font { .system(size: 22, weight: .bold) }
    static func body()        -> Font { .system(size: 17, weight: .regular) }
    static func bodyMedium()  -> Font { .system(size: 15, weight: .medium) }
    static func caption()     -> Font { .system(size: 13, weight: .regular) }
    static func label()       -> Font { .system(size: 11, weight: .semibold) }
    static func chatText()    -> Font { .system(size: 14, weight: .regular) }
}

enum MendelSpacing {
    static let xs: CGFloat = 4;  static let sm: CGFloat = 8
    static let md: CGFloat = 16; static let lg: CGFloat = 24
    static let xl: CGFloat = 32; static let xxl: CGFloat = 48
}

enum MendelRadius {
    static let sm: CGFloat = 10; static let md: CGFloat = 16
    static let lg: CGFloat = 24; static let pill: CGFloat = 100
}

// =============================================================
// MARK: - COMPONENTS
// =============================================================

struct MendelTabBar: View {
    @Environment(MendelAppState.self) private var appState
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MendelTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { appState.selectedTab = tab }
                } label: {
                    VStack(spacing: 5) {
                        Circle().frame(width: 6, height: 6)
                            .foregroundStyle(appState.selectedTab == tab ? MendelColors.ink : MendelColors.inkFaint)
                        Text(tab.rawValue)
                            .font(MendelType.label()).tracking(0.5).textCase(.uppercase)
                            .foregroundStyle(appState.selectedTab == tab ? MendelColors.ink : MendelColors.inkSoft)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Rectangle().fill(MendelColors.bg.opacity(0.96))
            .overlay(alignment: .top) { Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5) })
        .padding(.bottom, 20)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(1.0)
    }
}

struct LoadBar: View {
    let label: String; let value: Double; let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Text(label.uppercased()).font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(0.5).frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(MendelColors.inkFaint).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(MendelColors.ink)
                        .frame(width: geo.size.width * max(value, 0), height: 3)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }.frame(height: 3)
            Text(detail).font(MendelType.label()).foregroundStyle(MendelColors.inkFaint).frame(width: 24, alignment: .trailing)
        }
    }
}

struct PrimaryButton: View {
    let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.bg)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(MendelColors.ink, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Capsule().stroke(MendelColors.inkFaint, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct EffortSelector: View {
    @Binding var level: Int
    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button { level = i } label: {
                    ZStack {
                        Circle().strokeBorder(i <= level ? MendelColors.ink : MendelColors.inkFaint, lineWidth: 1.5)
                            .background(Circle().fill(i <= level ? MendelColors.ink : .clear))
                            .frame(width: 30, height: 30)
                        Text("\(i)").font(MendelType.label())
                            .foregroundStyle(i <= level ? MendelColors.bg : MendelColors.inkSoft)
                    }
                }.buttonStyle(.plain).animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
}

struct PillSelector<T: Hashable>: View {
    let options: [T]; let label: (T) -> String; @Binding var selected: T?
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button { selected = option } label: {
                    Text(label(option)).font(MendelType.caption())
                        .foregroundStyle(selected == option ? MendelColors.bg : MendelColors.ink)
                        .padding(.vertical, 8).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: MendelRadius.sm)
                            .fill(selected == option ? MendelColors.ink : MendelColors.white)
                            .overlay(RoundedRectangle(cornerRadius: MendelRadius.sm)
                                .stroke(selected == option ? MendelColors.ink : MendelColors.inkFaint, lineWidth: 0.5)))
                }.buttonStyle(.plain).animation(.easeInOut(duration: 0.12), value: selected)
            }
        }
    }
}

struct FormField: View {
    let label: String; let placeholder: String; @Binding var value: String
    var keyboardType: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            TextField(placeholder, text: $value)
                .font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(MendelColors.bg, in: RoundedRectangle(cornerRadius: MendelRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: MendelRadius.sm).stroke(MendelColors.inkFaint, lineWidth: 0.5))
                .keyboardType(keyboardType)
        }
    }
}

// =============================================================
// MARK: - PAYWALL VIEW
// =============================================================

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var store
    @State private var appeared = false

    private let features: [(icon: String, title: String, detail: String)] = [
        ("bubble.left",    "coach — unlimited",  "ask anything, anytime"),
        ("chart.bar",      "weekly planning",    "structured 7-day build"),
        ("arrow.up.right", "load trends",        "track progress over time"),
        ("sparkles",       "smarter engine",     "recommendations that learn"),
    ]

    var body: some View {
        ZStack {
            MendelColors.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MendelColors.inkSoft).frame(width: 30, height: 30)
                            .background(MendelColors.inkFaint, in: Circle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, MendelSpacing.xl).padding(.top, 20)

                Spacer()

                VStack(spacing: 8) {
                    Text("mendel").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MendelColors.inkSoft).tracking(2.0).textCase(.uppercase)
                    Text("unlock\neverything")
                        .font(.system(size: 52, weight: .heavy)).foregroundStyle(MendelColors.ink)
                        .tracking(-2).multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)
                    Text("one payment. no subscription. yours forever.")
                        .font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                        .multilineTextAlignment(.center).padding(.top, 4)
                        .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.12), value: appeared)
                }.padding(.horizontal, MendelSpacing.xl)

                Spacer().frame(height: 48)

                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9).fill(MendelColors.inkFaint.opacity(0.6)).frame(width: 36, height: 36)
                                Image(systemName: f.icon).font(.system(size: 14, weight: .light)).foregroundStyle(MendelColors.ink)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                                Text(f.detail).font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(MendelColors.stone)
                        }.padding(.horizontal, 16).padding(.vertical, 14)
                        if idx < features.count - 1 { Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5).padding(.leading, 52) }
                    }
                }
                .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
                .padding(.horizontal, MendelSpacing.xl)

                Spacer()

                VStack(spacing: 12) {
                    if let err = store.error { Text(err).font(MendelType.caption()).foregroundStyle(Color.red.opacity(0.7)) }
                    Button { Task { await store.purchase() } } label: {
                        ZStack {
                            if store.isLoading { ProgressView().tint(MendelColors.bg) }
                            else { Text("unlock for \(store.formattedPrice)").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.bg) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(MendelColors.ink, in: Capsule())
                    }.buttonStyle(.plain).disabled(store.isLoading)
                    Button { Task { await store.restore() } } label: {
                        Text("restore purchase").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                    }.buttonStyle(.plain).disabled(store.isLoading)
                }.padding(.horizontal, MendelSpacing.xl).padding(.bottom, 48)
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation { appeared = true } } }
        .onChange(of: store.isUnlocked) { if store.isUnlocked { dismiss() } }
    }
}

// =============================================================
// MARK: - HEALTHKIT VIEWS
// =============================================================

struct HealthKitPromptCard: View {
    @Environment(HealthKitManager.self) private var hk
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "heart").font(.system(size: 16, weight: .light)).foregroundStyle(MendelColors.stone)
                Text("connect health").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
            }
            Text("mendel reads your workouts, heart rate, and HRV from Apple Health to improve recommendations.")
                .font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft).lineSpacing(3)
            HStack(spacing: 10) {
                GhostButton(title: "not now") { }
                PrimaryButton(title: "connect") { Task { await hk.requestAuthorization() } }
            }
        }
        .padding(18)
        .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
    }
}

struct RecoverySignalRow: View {
    @Environment(HealthKitManager.self) private var hk
    var body: some View {
        HStack(spacing: 20) {
            SignalPill(label: "RHR",   value: hk.restingHeartRate.map { "\(Int($0)) bpm" } ?? "—")
            SignalPill(label: "HRV",   value: hk.hrv.map { "\(Int($0)) ms" } ?? "—")
            SignalPill(label: "Steps", value: hk.stepsToday > 0 ? "\(hk.stepsToday.formatted())" : "—")
        }
    }
}

private struct SignalPill: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(MendelType.label()).foregroundStyle(MendelColors.inkFaint).tracking(0.8)
            Text(value).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
        }
    }
}

struct WorkoutsImportBanner: View {
    @Environment(HealthKitManager.self) private var hk
    let onImport: ([HealthSession]) -> Void
    var body: some View {
        if hk.recentWorkouts.count > 0 {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle").font(.system(size: 16, weight: .light)).foregroundStyle(MendelColors.stone)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(hk.recentWorkouts.count) workouts in Health").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                    Text("import to update your load score").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                }
                Spacer()
                Button { onImport(hk.toEngineSessions()) } label: {
                    Text("import").font(MendelType.label()).foregroundStyle(MendelColors.bg).tracking(0.4)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(MendelColors.ink, in: Capsule())
                }.buttonStyle(.plain)
            }
            .padding(16)
            .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
        }
    }
}

// =============================================================
// MARK: - NOTIFICATION SETTINGS VIEW
// =============================================================

struct NotificationSettingsView: View {
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notif.morningBrief")    private var morningOn   = true
    @AppStorage("notif.eveningReminder") private var eveningOn   = true
    @AppStorage("notif.recoveryNudge")   private var recoveryOn  = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("notifications").font(MendelType.screenTitle()).foregroundStyle(MendelColors.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MendelColors.inkSoft).frame(width: 28, height: 28)
                        .background(MendelColors.inkFaint, in: Circle())
                }.buttonStyle(.plain)
            }.padding(.horizontal, MendelSpacing.xl).padding(.top, 28).padding(.bottom, 8)

            Text("calm reminders. never noise.").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                .padding(.horizontal, MendelSpacing.xl).padding(.bottom, 28)

            if !notifications.isAuthorized {
                VStack(alignment: .leading, spacing: 12) {
                    Text("enable notifications").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                    PrimaryButton(title: "allow") { Task { await notifications.requestAuthorization() } }
                }
                .padding(16)
                .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
                .padding(.horizontal, MendelSpacing.xl).padding(.bottom, 20)
            }

            VStack(spacing: 1) {
                NotifRow(icon: "sun.horizon", title: "morning brief",    detail: "today's recommendation at 8:00", isOn: $morningOn)
                NotifRow(icon: "moon",        title: "log reminder",     detail: "reminder to log at 20:30",       isOn: $eveningOn)
                NotifRow(icon: "heart",       title: "recovery check-in",detail: "midday nudge on rest days",      isOn: $recoveryOn)
            }
            .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
            .padding(.horizontal, MendelSpacing.xl)

            Spacer()
        }
        .background(MendelColors.bg)
        .onChange(of: morningOn)  { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
        .onChange(of: eveningOn)  { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
        .onChange(of: recoveryOn) { Task { await notifications.scheduleAll(recommendation: SharedStore.load()) } }
    }
}

private struct NotifRow: View {
    let icon: String; let title: String; let detail: String; @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(MendelColors.inkFaint.opacity(0.6)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .light)).foregroundStyle(MendelColors.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                Text(detail).font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(MendelColors.ink)
        }.padding(.horizontal, 16).padding(.vertical, 14).background(MendelColors.white)
    }
}

struct NotificationPromptCard: View {
    @Environment(NotificationManager.self) private var notifications
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell").font(.system(size: 15, weight: .light)).foregroundStyle(MendelColors.stone)
                Text("daily brief").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
            }
            Text("get today's recommendation at 8am and a log reminder in the evening.")
                .font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft).lineSpacing(3)
            HStack(spacing: 10) {
                GhostButton(title: "not now") { }
                PrimaryButton(title: "turn on") { Task { await notifications.requestAuthorization() } }
            }
        }
        .padding(16)
        .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
    }
}

// =============================================================
// MARK: - LOG VIEW
// =============================================================

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MendelAppState.self) private var appState
    @Environment(NotificationManager.self) private var notifications
    @State private var selectedType:    SessionType? = nil
    @State private var showingRecovery = false
    @State private var saved           = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("log").font(MendelType.screenTitle()).foregroundStyle(MendelColors.ink).padding(.top, 28)
                Text("what did you do?").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                    .padding(.top, 4).padding(.bottom, 28)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(SessionType.allCases, id: \.self) { type in
                        ActivityTypeCard(type: type, isSelected: selectedType == type) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedType = selectedType == type ? nil : type
                                if selectedType != nil { showingRecovery = false }
                            }
                        }
                    }
                    RecoveryTypeCard(isSelected: showingRecovery) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingRecovery.toggle()
                            if showingRecovery { selectedType = nil }
                        }
                    }
                }

                Spacer().frame(height: 20)

                if let type = selectedType {
                    SessionForm(type: type, onSave: {
                        notifications.didLogSession()
                        saved = true; selectedType = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }).transition(.move(edge: .top).combined(with: .opacity))
                }
                if showingRecovery {
                    RecoveryForm(onSave: {
                        saved = true; showingRecovery = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }).transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer().frame(height: 100)
            }.padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden).background(MendelColors.bg)
        .overlay(alignment: .top) { if saved { SavedToast().transition(.move(edge: .top).combined(with: .opacity)) } }
        .animation(.easeInOut(duration: 0.25), value: saved)
    }
}

private struct ActivityTypeCard: View {
    let type: SessionType; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: type.icon).font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text(type.displayName).font(MendelType.bodyMedium())
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text(type == .strength ? "sets · reps · weight" : type == .run ? "distance · time" : "duration · type")
                    .font(MendelType.label()).foregroundStyle(isSelected ? MendelColors.bg.opacity(0.5) : MendelColors.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(RoundedRectangle(cornerRadius: MendelRadius.md)
                .fill(isSelected ? MendelColors.ink : MendelColors.white)
                .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5)))
        }.buttonStyle(.plain)
    }
}

private struct RecoveryTypeCard: View {
    let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "moon").font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text("Recovery").font(MendelType.bodyMedium())
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text("sleep · soreness").font(MendelType.label())
                    .foregroundStyle(isSelected ? MendelColors.bg.opacity(0.5) : MendelColors.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(RoundedRectangle(cornerRadius: MendelRadius.md)
                .fill(isSelected ? MendelColors.ink : MendelColors.white)
                .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5)))
        }.buttonStyle(.plain)
    }
}

private struct SessionForm: View {
    @Environment(\.modelContext) private var modelContext
    let type: SessionType; let onSave: () -> Void
    @State private var exerciseName = ""; @State private var sets = ""; @State private var reps = ""
    @State private var weight = ""; @State private var effort = 0; @State private var distanceKm = ""
    @State private var durationMin = ""; @State private var sportName = ""; @State private var sportDuration = ""
    @State private var intensity: IntensityLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5).padding(.vertical, 4)
            switch type {
            case .strength:
                FormField(label: "Exercise (optional)", placeholder: "squat, bench…", value: $exerciseName)
                HStack(spacing: 10) {
                    FormField(label: "Sets", placeholder: "3", value: $sets, keyboardType: .numberPad)
                    FormField(label: "Reps", placeholder: "8", value: $reps, keyboardType: .numberPad)
                    FormField(label: "kg",   placeholder: "80", value: $weight, keyboardType: .decimalPad)
                }
                VStack(alignment: .leading, spacing: 8) { SectionLabel(text: "Effort (RPE)"); EffortSelector(level: $effort) }
            case .run:
                HStack(spacing: 10) {
                    FormField(label: "Distance (km)", placeholder: "8.0", value: $distanceKm, keyboardType: .decimalPad)
                    FormField(label: "Time (min)",    placeholder: "40",  value: $durationMin, keyboardType: .numberPad)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Intensity")
                    PillSelector(options: IntensityLevel.allCases, label: { $0.displayName }, selected: $intensity)
                }
            case .sport:
                FormField(label: "Sport", placeholder: "tennis, basketball…", value: $sportName)
                FormField(label: "Duration (min)", placeholder: "90", value: $sportDuration, keyboardType: .numberPad)
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Intensity")
                    PillSelector(options: IntensityLevel.allCases, label: { $0.displayName }, selected: $intensity)
                }
            }
            PrimaryButton(title: "save") {
                let resolved: IntensityLevel = intensity ?? (effort >= 4 ? .hard : effort >= 2 ? .moderate : .easy)
                let session = Session(type: type, intensity: resolved,
                    sets: Int(sets), reps: Int(reps), weight: Double(weight),
                    exerciseName: exerciseName.isEmpty ? nil : exerciseName,
                    distanceKm: Double(distanceKm),
                    durationMinutes: Int(durationMin.isEmpty ? sportDuration : durationMin),
                    sportName: sportName.isEmpty ? nil : sportName)
                modelContext.insert(session); try? modelContext.save(); onSave()
            }
        }.padding(.vertical, 4)
    }
}

private struct RecoveryForm: View {
    @Environment(\.modelContext) private var modelContext
    let onSave: () -> Void
    @State private var sleepQuality: SleepQuality? = nil
    @State private var soreness:     SorenessLevel? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sleep quality")
                PillSelector(options: SleepQuality.allCases, label: { $0.rawValue }, selected: $sleepQuality)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Soreness")
                PillSelector(options: SorenessLevel.allCases, label: { $0.rawValue }, selected: $soreness)
            }
            PrimaryButton(title: "save") {
                guard let sleep = sleepQuality, let sore = soreness else { return }
                modelContext.insert(RecoveryLog(sleepQuality: sleep, soreness: sore))
                try? modelContext.save(); onSave()
            }
        }.padding(.vertical, 4)
    }
}

private struct SavedToast: View {
    var body: some View {
        Text("logged").font(MendelType.label()).foregroundStyle(MendelColors.bg).tracking(0.8).textCase(.uppercase)
            .padding(.horizontal, 20).padding(.vertical, 10).background(MendelColors.ink, in: Capsule()).padding(.top, 60)
    }
}

// =============================================================
// MARK: - WEEK VIEW
// =============================================================

struct WeekView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(MendelAppState.self) private var appState

    private var weekDays: [Date] {
        let cal = Calendar.current; let today = Date.now
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMon, to: cal.startOfDay(for: today))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var recentSessions: [Session] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return sessions.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("this week").font(MendelType.screenTitle()).foregroundStyle(MendelColors.ink).padding(.top, 28)
                Text(weekRangeString).font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                    .padding(.top, 4).padding(.bottom, 20)

                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        DayCell(day: day, sessions: sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) })
                            .frame(maxWidth: .infinity)
                    }
                }.padding(.bottom, 32)

                SectionLabel(text: "Balance").padding(.bottom, 16)
                VStack(spacing: 12) {
                    BalanceRow(name: "Strength",  sessions: appState.weeklySummary.strengthSessions,  value: appState.weeklySummary.strengthBalance)
                    BalanceRow(name: "Endurance", sessions: appState.weeklySummary.enduranceSessions, value: appState.weeklySummary.enduranceBalance)
                }.padding(.bottom, 32)

                if !recentSessions.isEmpty {
                    SectionLabel(text: "Sessions").padding(.bottom, 14)
                    VStack(spacing: 0) {
                        ForEach(recentSessions) { s in
                            SessionRow(session: s)
                            if s.id != recentSessions.last?.id {
                                Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5).padding(.leading, 48)
                            }
                        }
                    }
                }
                Spacer().frame(height: 100)
            }.padding(.horizontal, MendelSpacing.xl)
        }.scrollIndicators(.hidden).background(MendelColors.bg)
    }

    private var weekRangeString: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }
}

private struct DayCell: View {
    let day: Date; let sessions: [Session]
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    var body: some View {
        VStack(spacing: 6) {
            Text(String(DateFormatter().then { $0.dateFormat = "EEE" }.string(from: day).prefix(1)))
                .font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(0.5).textCase(.uppercase)
            ZStack {
                Circle().fill(isToday && sessions.isEmpty ? MendelColors.ink : sessions.isEmpty ? MendelColors.inkFaint.opacity(0.4) : MendelColors.inkFaint).frame(width: 32, height: 32)
                if isToday && sessions.isEmpty { Circle().fill(MendelColors.bg).frame(width: 6, height: 6) }
                else if !sessions.isEmpty {
                    Text(sessions.first?.type == .strength ? "S" : sessions.first?.type == .run ? "R" : "T")
                        .font(MendelType.label()).foregroundStyle(MendelColors.ink)
                }
            }
        }
    }
}

extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter { block(self); return self }
}

private struct BalanceRow: View {
    let name: String; let sessions: Int; let value: Double
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                Spacer()
                Text(sessions == 1 ? "1 session" : "\(sessions) sessions").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(MendelColors.inkFaint).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(MendelColors.ink)
                        .frame(width: geo.size.width * max(value, 0), height: 4)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }.frame(height: 4)
        }
    }
}

private struct SessionRow: View {
    let session: Session
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(MendelColors.inkFaint.opacity(0.5)).frame(width: 34, height: 34)
                Image(systemName: session.type.icon).font(.system(size: 14, weight: .light)).foregroundStyle(MendelColors.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.type.displayName).font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                Text(sessionDetail).font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(0.2)
            }
            Spacer()
            Text(DateFormatter().then { $0.dateFormat = "EEE" }.string(from: session.date))
                .font(MendelType.label()).foregroundStyle(MendelColors.inkFaint)
        }.padding(.vertical, 14)
    }

    private var sessionDetail: String {
        switch session.type {
        case .strength:
            return [session.exerciseName, session.sets.map { "\($0) sets" }, "RPE \(session.intensity.rawValue * 3)"].compactMap{$0}.joined(separator: " · ")
        case .run:
            return [session.distanceKm.map { String(format: "%.1f km", $0) }, session.durationMinutes.map { "\($0) min" }, session.intensity.displayName].compactMap{$0}.joined(separator: " · ")
        case .sport:
            return [session.sportName ?? "sport", session.durationMinutes.map { "\($0) min" }, session.intensity.displayName].compactMap{$0}.joined(separator: " · ")
        }
    }
}

// =============================================================
// MARK: - COACH VIEW
// =============================================================

struct ChatMessage: Identifiable {
    let id = UUID(); let role: String; let text: String
    var isUser: Bool { role == "user" }
}

struct CoachView: View {
    @Environment(MendelAppState.self)      private var appState
    @Environment(PurchaseManager.self)     private var store
    @Environment(HealthKitManager.self)    private var hk
    @Query private var recoveryLogs: [RecoveryLog]
    @State private var messages:    [ChatMessage] = []
    @State private var inputText    = ""
    @State private var isLoading    = false
    @State private var showChips    = true
    @State private var showPaywall  = false
    private let claude = ClaudeService()
    private let chips  = ["what should I do tomorrow?","am I overtraining?","build me next week","how do I balance strength and running?"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("coach").font(MendelType.screenTitle()).foregroundStyle(MendelColors.ink)
                    Text("ask anything").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                }
                Spacer()
                if !store.isUnlocked {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "lock").font(.system(size: 10, weight: .medium))
                            Text("unlock").font(MendelType.label()).tracking(0.3)
                        }
                        .foregroundStyle(MendelColors.stone)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().stroke(MendelColors.stone.opacity(0.4), lineWidth: 0.5))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, MendelSpacing.xl).padding(.top, 28).padding(.bottom, 16)

            Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if messages.isEmpty {
                            CoachGreeting(appState: appState, summary: appState.weeklySummary)
                        }
                        ForEach(messages) { msg in CoachBubble(message: msg).id(msg.id) }
                        if isLoading { CoachTyping().id("loading") }
                        Spacer().frame(height: 8).id("bottom")
                    }.padding(.horizontal, MendelSpacing.xl).padding(.top, 20)
                }.scrollIndicators(.hidden)
                .onChange(of: messages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }

            if showChips {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { chip in
                            Button {
                                store.isUnlocked ? send(text: chip) : (showPaywall = true)
                            } label: {
                                Text(chip).font(MendelType.caption()).foregroundStyle(MendelColors.ink)
                                    .padding(.vertical, 9).padding(.horizontal, 16)
                                    .background(Capsule().stroke(MendelColors.inkFaint, lineWidth: 0.5)
                                        .background(Capsule().fill(MendelColors.white)))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, MendelSpacing.xl).padding(.vertical, 12)
                }.background(MendelColors.bg)
            }

            if !store.isUnlocked {
                Button { showPaywall = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "lock").font(.system(size: 14, weight: .light)).foregroundStyle(MendelColors.stone)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("unlock coach").font(MendelType.bodyMedium()).foregroundStyle(MendelColors.ink)
                            Text("one-time purchase. no subscription.").font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(MendelColors.inkFaint)
                    }
                    .padding(16)
                    .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: MendelRadius.md).stroke(MendelColors.inkFaint, lineWidth: 0.5))
                    .padding(.horizontal, MendelSpacing.xl)
                }.buttonStyle(.plain)
            }

            Rectangle().fill(MendelColors.inkFaint).frame(height: 0.5)
            HStack(spacing: 10) {
                TextField("ask something…", text: $inputText, axis: .vertical)
                    .font(MendelType.body()).foregroundStyle(MendelColors.ink).lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(MendelColors.inkFaint.opacity(0.5), in: Capsule())
                    .onSubmit { if !inputText.isEmpty { store.isUnlocked ? send(text: inputText) : (showPaywall = true) } }
                Button {
                    if !inputText.isEmpty { store.isUnlocked ? send(text: inputText) : (showPaywall = true) }
                } label: {
                    ZStack {
                        Circle().fill(inputText.isEmpty ? MendelColors.inkFaint : MendelColors.ink).frame(width: 36, height: 36)
                        Image(systemName: "arrow.up").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(inputText.isEmpty ? MendelColors.inkSoft : MendelColors.bg)
                    }
                }.buttonStyle(.plain).disabled(inputText.isEmpty || isLoading)
            }.padding(.horizontal, MendelSpacing.xl).padding(.vertical, 12).padding(.bottom, 100).background(MendelColors.bg)
        }
        .background(MendelColors.bg)
        .sheet(isPresented: $showPaywall) { PaywallView().environment(store) }
    }

    private func send(text: String) {
        guard !text.isEmpty, !isLoading else { return }
        messages.append(ChatMessage(role: "user", text: text)); inputText = ""; showChips = false; isLoading = true
        Task {
            do {
                let history = messages.map { ClaudeService.Message(role: $0.role, content: $0.text) }
                let lr = recoveryLogs.sorted { $0.date > $1.date }.first
                let ctx = CoachContext(todayState: appState.recommendation.state.rawValue.lowercased(),
                    weeklyLoad: appState.weeklySummary.totalLoadScore,
                    strengthSessions: appState.weeklySummary.strengthSessions,
                    enduranceSessions: appState.weeklySummary.enduranceSessions,
                    soreness: lr?.soreness.rawValue ?? "unknown",
                    sleepQuality: lr?.sleepQuality.rawValue ?? "unknown")
                let reply = try await claude.send(messages: history, context: ctx)
                await MainActor.run { messages.append(ChatMessage(role: "assistant", text: reply)); isLoading = false }
            } catch {
                await MainActor.run { messages.append(ChatMessage(role: "assistant", text: "couldn't reach the coach right now.")); isLoading = false }
            }
        }
    }
}

private struct CoachGreeting: View {
    let appState: MendelAppState; let summary: WeeklySummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MENDEL").font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(0.8)
            Text(summary.strengthSessions == 0 && summary.enduranceSessions == 0
                 ? "no sessions logged yet. log your first session and i'll give you personalised advice."
                 : "you've done \(summary.strengthSessions) strength and \(summary.enduranceSessions) endurance sessions this week. today: \(appState.recommendation.state.rawValue.lowercased()). what do you want to know?")
                .font(MendelType.chatText()).foregroundStyle(MendelColors.ink).lineSpacing(3)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(MendelColors.white)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(MendelColors.inkFaint, lineWidth: 0.5)))
        }
    }
}

private struct CoachBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if !message.isUser { Text("MENDEL").font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(0.8) }
                Text(message.text).font(MendelType.chatText())
                    .foregroundStyle(message.isUser ? MendelColors.bg : MendelColors.ink).lineSpacing(3).padding(14)
                    .background(Group {
                        if message.isUser { RoundedRectangle(cornerRadius: 18).fill(MendelColors.ink) }
                        else { RoundedRectangle(cornerRadius: 18).fill(MendelColors.white).overlay(RoundedRectangle(cornerRadius: 18).stroke(MendelColors.inkFaint, lineWidth: 0.5)) }
                    })
            }
            if !message.isUser { Spacer(minLength: 60) }
        }.frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

private struct CoachTyping: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(MendelColors.inkSoft).frame(width: 6, height: 6).opacity(phase == i ? 1 : 0.3)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(MendelColors.white)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(MendelColors.inkFaint, lineWidth: 0.5)))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in withAnimation { phase = (phase + 1) % 3 } } }
    }
}

// =============================================================
// MARK: - TODAY VIEW
// =============================================================

struct TodayView: View {
    @Environment(MendelAppState.self)      private var appState
    @Environment(HealthKitManager.self)    private var hk
    @Environment(PurchaseManager.self)     private var store
    @Environment(NotificationManager.self) private var notifications
    @State private var appeared        = false
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(dateString).font(MendelType.label()).foregroundStyle(MendelColors.inkSoft).tracking(1.0).textCase(.uppercase)
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "bell").font(.system(size: 13, weight: .light)).foregroundStyle(MendelColors.inkSoft)
                            .frame(width: 30, height: 30).background(MendelColors.inkFaint.opacity(0.5), in: Circle())
                    }.buttonStyle(.plain)
                }.padding(.top, 28).opacity(appeared ? 1 : 0)

                Text(appState.recommendation.state.rawValue)
                    .font(MendelType.stateWord()).foregroundStyle(MendelColors.ink).tracking(-3).padding(.top, 6)
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)

                Text(appState.recommendation.context)
                    .font(MendelType.caption()).foregroundStyle(MendelColors.inkSoft).lineSpacing(4).padding(.top, 8)
                    .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)

                if store.isUnlocked && hk.isAuthorized {
                    RecoverySignalRow().padding(.top, 16).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.13), value: appeared)
                }

                Rectangle().fill(MendelColors.inkFaint).frame(width: 32, height: 1).padding(.vertical, 24)
                    .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                SectionLabel(text: "do this").padding(.bottom, 14).opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.18), value: appeared)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(appState.recommendation.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("→").font(MendelType.caption()).foregroundStyle(MendelColors.inkFaint).padding(.top, 1)
                            Text(step).font(MendelType.body()).foregroundStyle(MendelColors.ink).lineSpacing(3)
                        }
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.4).delay(0.22 + Double(idx) * 0.06), value: appeared)
                    }
                }

                Spacer().frame(height: 32)

                if hk.isAuthorized && !hk.recentWorkouts.isEmpty {
                    WorkoutsImportBanner { _ in }.padding(.bottom, 16).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                }
                if !hk.isAuthorized && !hk.authorizationDenied {
                    HealthKitPromptCard().padding(.bottom, 16).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                }
                if !notifications.isAuthorized && !notifications.authorizationDenied {
                    NotificationPromptCard().padding(.bottom, 16).opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.33), value: appeared)
                }

                VStack(spacing: 10) {
                    LoadBar(label: "Strength",  value: appState.weeklySummary.strengthBalance,  detail: "\(appState.weeklySummary.strengthSessions)×")
                    LoadBar(label: "Endurance", value: appState.weeklySummary.enduranceBalance, detail: "\(appState.weeklySummary.enduranceSessions)×")
                }.opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)

                Spacer().frame(height: 24)

                PrimaryButton(title: "+ log activity") { appState.selectedTab = .log }
                    .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)

                Spacer().frame(height: 100)
            }.padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden).background(MendelColors.bg)
        .sheet(isPresented: $showingSettings) { NotificationSettingsView().environment(notifications) }
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
        }
        .onChange(of: appState.recommendation.state) {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation { appeared = true } }
        }
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f.string(from: .now)
    }
}

// =============================================================
// MARK: - ROOT VIEW
// =============================================================

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions:     [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appState             = MendelAppState()
    @State private var purchaseManager      = PurchaseManager()
    @State private var healthKit            = HealthKitManager()
    @State private var notificationManager  = NotificationManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .today: TodayView()
                case .log:   LogView()
                case .week:  WeekView()
                case .coach: CoachView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            MendelTabBar()
        }
        .environment(appState)
        .environment(purchaseManager)
        .environment(healthKit)
        .environment(notificationManager)
        .ignoresSafeArea(edges: .bottom)
        .background(MendelColors.bg)
        .onOpenURL { url in DeepLinkHandler.handle(url: url, state: appState) }
        .onReceive(NotificationCenter.default.publisher(for: .mendelDeepLink)) { note in
            if let url = note.object as? URL { DeepLinkHandler.handle(url: url, state: appState) }
        }
        .onChange(of: sessions.count)                     { recompute() }
        .onChange(of: recoveryLogs.count)                 { recompute() }
        .onChange(of: healthKit.recentWorkouts.count)     { recompute() }
        .onChange(of: healthKit.hrv)                      { recompute() }
        .onChange(of: healthKit.restingHeartRate)         { recompute() }
        .onAppear { recompute(); Task { await healthKit.requestAuthorization() } }
    }

    private func recompute() {
        appState.refresh(sessions: sessions, recoveryLogs: recoveryLogs, hk: healthKit)
        Task { await notificationManager.scheduleAll(recommendation: SharedStore.load()) }
    }
}

// =============================================================
// MARK: - APP ENTRY POINT
// =============================================================

private let notifDelegate = MendelNotificationDelegate()

@main
struct MendelApp: App {
    init() { UNUserNotificationCenter.current().delegate = notifDelegate }
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [Session.self, RecoveryLog.self])
        }
    }
}
