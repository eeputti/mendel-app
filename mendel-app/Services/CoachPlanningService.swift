#if !WIDGET_EXTENSION
//
// CoachPlanningService.swift
// Reuses the current plan model while keeping coach changes reviewable.
//

import Foundation
import SwiftData

struct PlanAdjustmentProposal: Identifiable {
    let id: UUID
    let fingerprint: String
    let headline: String
    let reason: String
    let changes: [PlanAdjustmentChange]
    fileprivate let operations: [PlanAdjustmentOperation]

    fileprivate init(
        id: UUID = UUID(),
        fingerprint: String,
        headline: String,
        reason: String,
        changes: [PlanAdjustmentChange],
        operations: [PlanAdjustmentOperation]
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.headline = headline
        self.reason = reason
        self.changes = changes
        self.operations = operations
    }
}

struct PlanAdjustmentChange: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private enum PlanAdjustmentOperation {
    case update(sessionID: UUID, draft: PlannedWorkoutDraft)
    case create(draft: PlannedWorkoutDraft)
    case delete(sessionID: UUID)
}

enum CoachPlanningService {
    static func makeGeneratedPlanProposal(
        existingPlannedSessions: [Session],
        goal: TrainingGoal,
        sports: [PlanSport],
        sessionsPerWeek: Int,
        weeklyStructure: String
    ) -> PlanAdjustmentProposal {
        let drafts = TrainingPlanGenerator.generate(
            goal: goal,
            sports: sports.isEmpty ? goal.defaultSports : sports,
            sessionsPerWeek: sessionsPerWeek,
            weeklyStructure: weeklyStructure
        )

        return proposalForReplacingPlan(
            existingPlannedSessions: existingPlannedSessions,
            newDrafts: drafts,
            headline: "Review your coach-built week",
            reason: "\(goal.displayName) · \(sessionsPerWeek) sessions · review before updating your calendar"
        )
    }

    @MainActor
    static func detectAdjustmentProposal(
        sessions: [Session],
        healthSessions: [HealthSession]
    ) -> PlanAdjustmentProposal? {
        let calendar = Calendar.current
        let now = Date.now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekStart = weekInterval?.start ?? calendar.startOfDay(for: now)
        let weekEnd = weekInterval?.end ?? calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now

        let plannedSessions = sessions
            .filter {
                $0.sessionStatus == .planned &&
                $0.date >= weekStart &&
                $0.date < weekEnd
            }
            .sorted { $0.date < $1.date }

        guard !plannedSessions.isEmpty else { return nil }

        let actualSessions = (
            sessions.filter { $0.sessionStatus == .completed }.map(ActualTrainingSession.init(session:))
            + healthSessions.map(ActualTrainingSession.init(healthSession:))
        )
        .sorted { $0.date > $1.date }

        guard let recentActual = actualSessions.first(where: { now.timeIntervalSince($0.date) <= 36 * 60 * 60 }) else {
            return nil
        }

        guard recentActual.intensity == .hard else { return nil }

        let nextHardSession = plannedSessions.first {
            $0.date > recentActual.date &&
            $0.date < calendar.date(byAdding: .day, value: 3, to: recentActual.date) ?? weekEnd &&
            ($0.intensity == .hard || ($0.perceivedEffort ?? 0) >= 4)
        }

        guard let sessionToAdjust = nextHardSession ?? plannedSessions.first else { return nil }

        let recoveryDraft = PlannedWorkoutDraft(
            date: sessionToAdjust.date,
            category: .mobility,
            subtype: "recovery",
            durationMinutes: 20,
            perceivedEffort: 1,
            notes: "Coach-adjusted after unexpected hard training"
        )

        var operations: [PlanAdjustmentOperation] = [
            .update(sessionID: sessionToAdjust.id, draft: recoveryDraft)
        ]
        var changes = [
            PlanAdjustmentChange(
                title: "Lighten \(dayLabel(for: sessionToAdjust.date))",
                detail: "Swap \(sessionSummary(sessionToAdjust)) for recovery mobility so the recent hard effort has room to land."
            )
        ]

        if let lighterSession = plannedSessions.first(where: {
            $0.id != sessionToAdjust.id &&
            $0.intensity != .hard &&
            $0.displayCategory != .mobility &&
            $0.displayCategory != .recovery
        }), let newDate = nextAvailablePlanDate(after: sessionToAdjust.date, plannedSessions: plannedSessions, now: now) {
            let movedDraft = PlannedWorkoutDraft(
                date: newDate,
                category: lighterSession.displayCategory,
                subtype: lighterSession.subtype ?? "easy",
                durationMinutes: lighterSession.durationMinutes ?? 35,
                perceivedEffort: lighterSession.perceivedEffort,
                notes: lighterSession.notes
            )
            operations.append(.update(sessionID: lighterSession.id, draft: movedDraft))
            changes.append(
                PlanAdjustmentChange(
                    title: "Reschedule the lighter work",
                    detail: "Move \(sessionSummary(lighterSession)) to \(dayLabel(for: newDate)) to keep the week balanced."
                )
            )
        }

        let reason = "\(recentActual.summary) came in hard enough that the rest of the week should absorb it instead of stacking more intensity immediately."

        return PlanAdjustmentProposal(
            fingerprint: fingerprint(for: reason, changes: changes),
            headline: "Coach adjustment ready",
            reason: reason,
            changes: changes,
            operations: operations
        )
    }

    static func apply(
        _ proposal: PlanAdjustmentProposal,
        sessions: [Session],
        modelContext: ModelContext
    ) {
        for operation in proposal.operations {
            switch operation {
            case let .update(sessionID, draft):
                guard let session = sessions.first(where: { $0.id == sessionID }) else { continue }
                apply(draft: draft, to: session)
            case let .create(draft):
                modelContext.insert(makeSession(from: draft))
            case let .delete(sessionID):
                guard let session = sessions.first(where: { $0.id == sessionID }) else { continue }
                modelContext.delete(session)
            }
        }

        try? modelContext.save()
    }

    private static func proposalForReplacingPlan(
        existingPlannedSessions: [Session],
        newDrafts: [PlannedWorkoutDraft],
        headline: String,
        reason: String
    ) -> PlanAdjustmentProposal {
        let existing = existingPlannedSessions.sorted { $0.date < $1.date }
        let drafts = newDrafts.sorted { $0.date < $1.date }
        let sharedCount = min(existing.count, drafts.count)

        var operations: [PlanAdjustmentOperation] = []
        var changes: [PlanAdjustmentChange] = []

        for index in 0..<sharedCount {
            let session = existing[index]
            let draft = drafts[index]
            operations.append(.update(sessionID: session.id, draft: draft))
            changes.append(
                PlanAdjustmentChange(
                    title: "Refresh \(dayLabel(for: draft.date))",
                    detail: "Set it to \(draftSummary(draft))."
                )
            )
        }

        if drafts.count > existing.count {
            for draft in drafts.dropFirst(sharedCount) {
                operations.append(.create(draft: draft))
                changes.append(
                    PlanAdjustmentChange(
                        title: "Add \(dayLabel(for: draft.date))",
                        detail: "Schedule \(draftSummary(draft))."
                    )
                )
            }
        }

        if existing.count > drafts.count {
            for session in existing.dropFirst(sharedCount) {
                operations.append(.delete(sessionID: session.id))
                changes.append(
                    PlanAdjustmentChange(
                        title: "Remove extra planned session",
                        detail: "Clear \(sessionSummary(session)) from \(dayLabel(for: session.date))."
                    )
                )
            }
        }

        return PlanAdjustmentProposal(
            fingerprint: fingerprint(for: reason, changes: changes),
            headline: headline,
            reason: reason,
            changes: changes,
            operations: operations
        )
    }

    private static func apply(draft: PlannedWorkoutDraft, to session: Session) {
        session.date = draft.date
        session.category = draft.category
        session.type = draft.category.defaultSessionType
        session.subtype = draft.subtype.isEmpty ? nil : draft.subtype
        session.durationMinutes = draft.durationMinutes
        session.notes = draft.notes
        session.perceivedEffort = draft.perceivedEffort
        session.intensity = IntensityLevel.fromPerceivedEffort(draft.perceivedEffort)
        session.status = .planned
    }

    private static func makeSession(from draft: PlannedWorkoutDraft) -> Session {
        Session(
            date: draft.date,
            type: draft.category.defaultSessionType,
            intensity: IntensityLevel.fromPerceivedEffort(draft.perceivedEffort),
            durationMinutes: draft.durationMinutes,
            category: draft.category,
            subtype: draft.subtype.isEmpty ? nil : draft.subtype,
            notes: draft.notes,
            perceivedEffort: draft.perceivedEffort,
            status: .planned
        )
    }

    private static func nextAvailablePlanDate(after date: Date, plannedSessions: [Session], now: Date) -> Date? {
        let calendar = Calendar.current
        let reservedDays = Set(plannedSessions.map { calendar.startOfDay(for: $0.date) })

        for offset in 1...4 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: max(date, now)) else { continue }
            let normalized = calendar.startOfDay(for: candidate)
            if !reservedDays.contains(normalized) {
                return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: normalized) ?? normalized
            }
        }

        return nil
    }

    private static func draftSummary(_ draft: PlannedWorkoutDraft) -> String {
        [draft.category.displayName, draft.subtype, "\(draft.durationMinutes) min", draft.perceivedEffort.map { "feel \($0)/5" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static func sessionSummary(_ session: Session) -> String {
        [session.displayTitle, session.subtype, session.durationMinutes.map { "\($0) min" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static func fingerprint(for reason: String, changes: [PlanAdjustmentChange]) -> String {
        ([reason] + changes.map(\.title) + changes.map(\.detail)).joined(separator: "|")
    }

    private static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

private struct ActualTrainingSession {
    let date: Date
    let intensity: IntensityLevel
    let summary: String

    init(session: Session) {
        self.date = session.date
        self.intensity = session.intensity
        self.summary = [session.displayTitle, session.detailText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    init(healthSession: HealthSession) {
        self.date = healthSession.date
        self.intensity = healthSession.intensity
        self.summary = [
            healthSession.type.displayName,
            healthSession.distanceKm.map { String(format: "%.1f km", $0) } ?? "\(healthSession.durationMinutes) min",
            healthSession.intensity.displayName
        ]
        .joined(separator: " · ")
    }
}
#endif
