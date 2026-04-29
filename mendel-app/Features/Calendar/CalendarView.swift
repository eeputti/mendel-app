#if !WIDGET_EXTENSION
//
// CalendarView.swift
// Month and week calendar with editable training details.
//

import SwiftUI
import SwiftData
import HealthKit

struct CalendarView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(MendelAppState.self) private var appState
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(\.modelContext) private var modelContext

    @State private var displayMode: CalendarDisplayMode = .month
    @State private var displayedDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editingSession: Session?

    private let calendar = Calendar.current

    var body: some View {
        KestoScreen {
            HStack(alignment: .top) {
                KestoSectionHeader(
                    eyebrow: "Calendar",
                    title: "Training archive",
                    subtitle: subtitle
                )
                Spacer()
                HStack(spacing: 8) {
                    calendarButton(systemName: "chevron.left") {
                        shiftDisplayedDate(by: -1)
                    }
                    calendarButton(systemName: "chevron.right") {
                        shiftDisplayedDate(by: 1)
                    }
                }
            }

            KestoCard(style: .muted, padding: KestoTheme.Spacing.md) {
                Picker("Calendar mode", selection: $displayMode) {
                    ForEach(CalendarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let proposal = appState.suggestedPlanAdjustment {
                CoachPlanProposalCard(
                    titleLabel: "Coach adjustment",
                    proposal: proposal,
                    acceptTitle: "apply update",
                    onAccept: {
                        CoachPlanningService.apply(proposal, sessions: sessions, modelContext: modelContext)
                        appState.clearDismissedPlanAdjustmentFingerprint()
                        appState.suggestedPlanAdjustment = nil
                    },
                    onDismiss: { appState.dismissSuggestedPlanAdjustment() }
                )
            }

            if displayMode == .month {
                CalendarMonthCard(
                    month: calendar.startOfMonth(for: displayedDate),
                    selectedDate: $selectedDate,
                    sessionsByDay: sessionsByDay,
                    healthWorkoutsByDay: healthWorkoutsByDay
                )
            } else {
                CalendarWeekCard(
                    weekStart: calendar.startOfWeek(for: displayedDate),
                    selectedDate: $selectedDate,
                    sessionsByDay: sessionsByDay,
                    healthWorkoutsByDay: healthWorkoutsByDay
                )
            }

            CalendarDaySummary(
                date: selectedDate,
                sessions: sessionsForSelectedDay,
                healthWorkouts: healthWorkoutsForSelectedDay,
                onEdit: { editingSession = $0 },
                onDelete: delete
            )
        }
        .sheet(item: $editingSession) { session in
            KestoBottomSheet(title: "Edit workout", subtitle: "Update date, details, or status") {
                KestoCard(style: .elevated) {
                    SessionEditorView(session: session, showsStatus: true) {
                        editingSession = nil
                    }
                }

                KestoSecondaryButton(title: "Delete workout") {
                    delete(session)
                    editingSession = nil
                }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            displayedDate = selectedDate
        }
        .onChange(of: displayMode) {
            displayedDate = selectedDate
        }
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = displayMode == .month ? "MMMM yyyy" : "'Week of' d MMM"
        return formatter.string(from: displayedDate)
    }

    private var sessionsByDay: [Date: [Session]] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    }

    private var healthWorkoutsByDay: [Date: [HKWorkout]] {
        Dictionary(grouping: healthKit.recentWorkouts) { calendar.startOfDay(for: $0.endDate) }
    }

    private var sessionsForSelectedDay: [Session] {
        (sessionsByDay[calendar.startOfDay(for: selectedDate)] ?? []).sorted { $0.date < $1.date }
    }

    private var healthWorkoutsForSelectedDay: [HKWorkout] {
        (healthWorkoutsByDay[calendar.startOfDay(for: selectedDate)] ?? []).sorted { $0.endDate < $1.endDate }
    }

    private func shiftDisplayedDate(by value: Int) {
        let component: Calendar.Component = displayMode == .month ? .month : .weekOfYear
        guard let nextDate = calendar.date(byAdding: component, value: value, to: displayedDate) else { return }
        displayedDate = nextDate
        let normalized = calendar.startOfDay(for: nextDate)
        if displayMode == .month {
            if calendar.isDate(selectedDate, equalTo: nextDate, toGranularity: .month) {
                return
            }
            selectedDate = normalized
        } else if !calendar.isDate(selectedDate, equalTo: nextDate, toGranularity: .weekOfYear) {
            selectedDate = normalized
        }
    }

    private func delete(_ session: Session) {
        modelContext.delete(session)
        try? modelContext.save()
    }

    private func calendarButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KestoTheme.Colors.ink)
                .frame(width: 36, height: 36)
                .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum CalendarDisplayMode: CaseIterable {
    case month
    case week

    var displayName: String {
        switch self {
        case .month:
            return "Month"
        case .week:
            return "Week"
        }
    }
}

private struct CalendarMonthCard: View {
    let month: Date
    @Binding var selectedDate: Date
    let sessionsByDay: [Date: [Session]]
    let healthWorkoutsByDay: [Date: [HKWorkout]]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        VStack(spacing: KestoTheme.Spacing.sm) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(calendar.monthGridDates(for: month), id: \.self) { day in
                    CalendarDayButton(
                        day: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isInPrimaryRange: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        manualSessions: sessionsByDay[calendar.startOfDay(for: day)] ?? [],
                        healthCount: healthWorkoutsByDay[calendar.startOfDay(for: day)]?.count ?? 0
                    ) {
                        selectedDate = calendar.startOfDay(for: day)
                    }
                }
            }
        }
        .kestoCard(.secondary)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
}

private struct CalendarWeekCard: View {
    let weekStart: Date
    @Binding var selectedDate: Date
    let sessionsByDay: [Date: [Session]]
    let healthWorkoutsByDay: [Date: [HKWorkout]]

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            ForEach(weekDates, id: \.self) { day in
                Button {
                    selectedDate = calendar.startOfDay(for: day)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weekdayLabel(for: day))
                                .font(MendelType.label())
                                .foregroundStyle(MendelColors.inkSoft)
                            Text(dayLabel(for: day))
                                .font(MendelType.bodyMedium())
                                .foregroundStyle(MendelColors.ink)
                        }
                        Spacer()
                        CalendarDayMarkers(
                            sessions: sessionsByDay[calendar.startOfDay(for: day)] ?? [],
                            healthCount: healthWorkoutsByDay[calendar.startOfDay(for: day)]?.count ?? 0
                        )
                    }
                    .padding(14)
                    .background(background(for: day), in: RoundedRectangle(cornerRadius: MendelRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MendelRadius.sm, style: .continuous)
                            .stroke(border(for: day), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .kestoCard(.secondary)
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func background(for day: Date) -> Color {
        if calendar.isDate(day, inSameDayAs: selectedDate) {
            return KestoTheme.Colors.bone.opacity(0.9)
        }
        if calendar.isDateInToday(day) {
            return KestoTheme.Colors.bone.opacity(0.55)
        }
        return KestoTheme.Colors.bone.opacity(0.3)
    }

    private func border(for day: Date) -> Color {
        calendar.isDate(day, inSameDayAs: selectedDate) ? MendelColors.inkSoft : MendelColors.inkFaint
    }
}

private struct CalendarDayButton: View {
    let day: Date
    let isSelected: Bool
    let isInPrimaryRange: Bool
    let manualSessions: [Session]
    let healthCount: Int
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("\(calendar.component(.day, from: day))")
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(isInPrimaryRange ? MendelColors.ink : MendelColors.inkSoft)

                CalendarDayMarkers(sessions: manualSessions, healthCount: healthCount)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(background, in: RoundedRectangle(cornerRadius: MendelRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.sm, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if isSelected {
            return KestoTheme.Colors.bone.opacity(0.9)
        }
        if calendar.isDateInToday(day) {
            return KestoTheme.Colors.bone.opacity(0.55)
        }
        return KestoTheme.Colors.bone.opacity(0.25)
    }

    private var borderColor: Color {
        if isSelected {
            return MendelColors.inkSoft
        }
        return isInPrimaryRange ? MendelColors.inkFaint : MendelColors.inkFaint.opacity(0.4)
    }
}

private struct CalendarDayMarkers: View {
    let sessions: [Session]
    let healthCount: Int

    var body: some View {
        HStack(spacing: 4) {
            if sessions.isEmpty && healthCount == 0 {
                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            } else {
                if sessions.contains(where: { $0.sessionStatus == .completed }) {
                    Circle()
                        .fill(MendelColors.ink)
                        .frame(width: 6, height: 6)
                }
                if sessions.contains(where: { $0.sessionStatus == .planned }) {
                    Circle()
                        .stroke(MendelColors.ink, lineWidth: 1)
                        .frame(width: 6, height: 6)
                }
                if sessions.contains(where: { $0.sessionStatus == .skipped }) {
                    Circle()
                        .fill(MendelColors.inkSoft)
                        .frame(width: 6, height: 6)
                }
                if healthCount > 0 {
                    Circle()
                        .fill(MendelColors.stone)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 8)
    }
}

private struct CalendarDaySummary: View {
    let date: Date
    let sessions: [Session]
    let healthWorkouts: [HKWorkout]
    let onEdit: (Session) -> Void
    let onDelete: (Session) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summaryTitle)
                .font(MendelType.sectionTitle())
                .foregroundStyle(MendelColors.ink)

            Text(summarySubtitle)
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .padding(.top, KestoTheme.Spacing.xxs)
                .padding(.bottom, KestoTheme.Spacing.md)

            if sessions.isEmpty && healthWorkouts.isEmpty {
                Text("no workouts for this day yet.")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        CalendarSessionRow(session: session, onEdit: onEdit, onDelete: onDelete)
                        if index < sessions.count - 1 || !healthWorkouts.isEmpty {
                            divider
                        }
                    }

                    ForEach(Array(healthWorkouts.enumerated()), id: \.offset) { index, workout in
                        CalendarHealthWorkoutRow(workout: workout)
                        if index < healthWorkouts.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
        .kestoCard(.secondary)
    }

    private var summaryTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }

    private var summarySubtitle: String {
        let count = sessions.count + healthWorkouts.count
        return count == 1 ? "1 activity" : "\(count) activities"
    }

    private var divider: some View {
        Rectangle()
            .fill(MendelColors.inkFaint)
            .frame(height: 0.5)
            .padding(.leading, 44)
    }
}

private struct CalendarSessionRow: View {
    let session: Session
    let onEdit: (Session) -> Void
    let onDelete: (Session) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: session.displayCategory.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(MendelColors.ink)
                    .frame(width: 28, height: 28)
                    .background(MendelColors.inkFaint.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(session.displayTitle)
                            .font(MendelType.bodyMedium())
                            .foregroundStyle(MendelColors.ink)
                        SessionStatusBadge(status: session.sessionStatus)
                    }
                    Text(session.detailText)
                        .font(MendelType.caption())
                        .foregroundStyle(MendelColors.inkSoft)
                }
                Spacer()
                Text(timeString(from: session.date))
                    .font(MendelType.label())
                    .foregroundStyle(MendelColors.inkFaint)
            }

            HStack(spacing: 10) {
                Button("Edit") {
                    onEdit(session)
                }
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.ink)

                Button("Delete") {
                    onDelete(session)
                }
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
            }
            .buttonStyle(.plain)
            .padding(.leading, 40)
        }
        .padding(.vertical, 12)
    }
}

private struct SessionStatusBadge: View {
    let status: SessionStatus

    var body: some View {
        Text(status.displayName)
            .font(MendelType.label())
            .foregroundStyle(status == .planned ? MendelColors.inkSoft : MendelColors.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .stroke(status == .planned ? MendelColors.inkSoft : MendelColors.inkFaint, lineWidth: 0.5)
            )
    }
}

private struct CalendarHealthWorkoutRow: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(MendelColors.stone)
                .frame(width: 28, height: 28)
                .background(MendelColors.inkFaint.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityTypeLabel)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
                Text(workout.detailText)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
            Spacer()
            Text(timeString(from: workout.endDate))
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkFaint)
        }
        .padding(.vertical, 12)
    }
}

private extension HKWorkout {
    var activityTypeLabel: String {
        switch workoutActivityType {
        case .running:
            return "Run"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining:
            return "Strength"
        case .cycling:
            return "Ride"
        case .walking, .hiking:
            return "Walk"
        default:
            return "Health workout"
        }
    }

    var detailText: String {
        let minutes = Int(duration / 60)
        let distanceText: String?
        if let totalDistance {
            let distanceKm = totalDistance.doubleValue(for: .meterUnit(with: .kilo))
            distanceText = String(format: "%.1f km", distanceKm)
        } else {
            distanceText = nil
        }
        return [distanceText, minutes > 0 ? "\(minutes) min" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    func monthGridDates(for month: Date) -> [Date] {
        guard let interval = dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let weekday = component(.weekday, from: firstDay)
        let leadingDays = (weekday - firstWeekday + 7) % 7
        let gridStart = date(byAdding: .day, value: -leadingDays, to: firstDay) ?? firstDay
        return (0..<42).compactMap { date(byAdding: .day, value: $0, to: gridStart) }
    }
}

private func timeString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}
#endif
