#if !WIDGET_EXTENSION
//
// WeekView.swift
// Weekly summary screen.
//

import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(MendelAppState.self) private var appState

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = Date.now
        let daysFromMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var recentSessions: [Session] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return sessions.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("this week")
                    .font(MendelType.screenTitle())
                    .foregroundStyle(MendelColors.ink)
                    .padding(.top, 28)
                Text(weekRangeString)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        DayCell(day: day, sessions: sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) })
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 32)

                SectionLabel(text: "Balance")
                    .padding(.bottom, 16)
                VStack(spacing: 12) {
                    BalanceRow(name: "Strength", sessions: appState.weeklySummary.strengthSessions, value: appState.weeklySummary.strengthBalance)
                    BalanceRow(name: "Endurance", sessions: appState.weeklySummary.enduranceSessions, value: appState.weeklySummary.enduranceBalance)
                }
                .padding(.bottom, 32)

                if !recentSessions.isEmpty {
                    SectionLabel(text: "Sessions")
                        .padding(.bottom, 14)
                    VStack(spacing: 0) {
                        ForEach(recentSessions) { session in
                            SessionRow(session: session)
                            if session.id != recentSessions.last?.id {
                                Rectangle()
                                    .fill(MendelColors.inkFaint)
                                    .frame(height: 0.5)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(MendelColors.bg)
    }

    private var weekRangeString: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }
}

private struct DayCell: View {
    let day: Date
    let sessions: [Session]

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(String(DateFormatter().then { $0.dateFormat = "EEE" }.string(from: day).prefix(1)))
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
                .tracking(0.5)
                .textCase(.uppercase)
            ZStack {
                Circle()
                    .fill(isToday && sessions.isEmpty ? MendelColors.ink : sessions.isEmpty ? MendelColors.inkFaint.opacity(0.4) : MendelColors.inkFaint)
                    .frame(width: 32, height: 32)
                if isToday && sessions.isEmpty {
                    Circle()
                        .fill(MendelColors.bg)
                        .frame(width: 6, height: 6)
                } else if !sessions.isEmpty {
                    Text(sessions.first?.type == .strength ? "S" : sessions.first?.type == .run ? "R" : "T")
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.ink)
                }
            }
        }
    }
}

private struct BalanceRow: View {
    let name: String
    let sessions: Int
    let value: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(name)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
                Spacer()
                Text(sessions == 1 ? "1 session" : "\(sessions) sessions")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.inkFaint)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.ink)
                        .frame(width: geometry.size.width * max(value, 0), height: 4)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(MendelColors.inkFaint.opacity(0.5))
                    .frame(width: 34, height: 34)
                Image(systemName: session.type.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(MendelColors.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.type.displayName)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
                Text(sessionDetail)
                    .font(MendelType.label())
                    .foregroundStyle(MendelColors.inkSoft)
                    .tracking(0.2)
            }
            Spacer()
            Text(DateFormatter().then { $0.dateFormat = "EEE" }.string(from: session.date))
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkFaint)
        }
        .padding(.vertical, 14)
    }

    private var sessionDetail: String {
        switch session.type {
        case .strength:
            return [session.exerciseName, session.sets.map { "\($0) sets" }, "RPE \(session.intensity.rawValue * 3)"]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .run:
            return [session.distanceKm.map { String(format: "%.1f km", $0) }, session.durationMinutes.map { "\($0) min" }, session.intensity.displayName]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .sport:
            return [session.sportName ?? "sport", session.durationMinutes.map { "\($0) min" }, session.intensity.displayName]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
}
#endif
