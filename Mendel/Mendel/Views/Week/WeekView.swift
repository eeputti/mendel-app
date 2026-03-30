import SwiftUI
import SwiftData

struct WeekView: View {

    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \RecoveryLog.date, order: .reverse) private var recoveryLogs: [RecoveryLog]
    @Environment(AppState.self) private var appState

    private var summary: WeeklySummary { appState.weeklySummary }

    // Current week Mon–Sun
    private var weekDays: [Date] {
        let cal = Calendar.current
        let today = Date.now
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon… shift so Mon=0
        let daysFromMon = (weekday + 5) % 7
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

                Text("this week")
                    .font(MendelType.screenTitle())
                    .foregroundStyle(MendelColors.ink)
                    .padding(.top, 28)

                Text(weekRangeString)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .padding(.top, 4)
                    .padding(.bottom, 28)

                // Day strip
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        DayCell(day: day, sessions: sessionsOn(day: day))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 32)

                // Balance
                SectionLabel(text: "Balance")
                    .padding(.bottom, 16)

                VStack(spacing: 12) {
                    BalanceRow(
                        name: "Strength",
                        sessions: summary.strengthSessions,
                        value: summary.strengthBalance
                    )
                    BalanceRow(
                        name: "Endurance",
                        sessions: summary.enduranceSessions,
                        value: summary.enduranceBalance
                    )
                }
                .padding(.bottom, 32)

                // Session list
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
                } else {
                    VStack(spacing: 8) {
                        Text("no sessions yet this week")
                            .font(MendelType.body())
                            .foregroundStyle(MendelColors.inkSoft)
                        Text("start logging to see your balance.")
                            .font(MendelType.caption())
                            .foregroundStyle(MendelColors.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(MendelColors.bg)
    }

    private func sessionsOn(day: Date) -> [Session] {
        sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var weekRangeString: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }
}

// MARK: - Day Cell

struct DayCell: View {

    let day: Date
    let sessions: [Session]

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: day).prefix(1))
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayLabel)
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
                .tracking(0.5)
                .textCase(.uppercase)

            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)
                if sessions.isEmpty && !isToday {
                    // empty
                } else if isToday {
                    Circle()
                        .fill(MendelColors.ink)
                        .frame(width: 6, height: 6)
                } else {
                    Text(sessionInitial)
                        .font(MendelType.label())
                        .foregroundStyle(sessionTextColor)
                }
            }
        }
    }

    private var circleColor: Color {
        if isToday && sessions.isEmpty { return MendelColors.ink }
        if sessions.isEmpty { return MendelColors.inkFaint.opacity(0.4) }
        return MendelColors.inkFaint
    }

    private var sessionInitial: String {
        switch sessions.first?.type {
        case .strength: return "S"
        case .run:      return "R"
        case .sport:    return "T"
        case nil:       return "—"
        }
    }

    private var sessionTextColor: Color {
        sessions.isEmpty ? .clear : MendelColors.ink
    }
}

// MARK: - Balance Row

struct BalanceRow: View {
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.inkFaint)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MendelColors.ink)
                        .frame(width: geo.size.width * max(value, 0), height: 4)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
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

            Text(dayString)
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkFaint)
        }
        .padding(.vertical, 14)
    }

    private var sessionDetail: String {
        switch session.type {
        case .strength:
            let parts = [
                session.exerciseName,
                session.sets.map { "\($0) sets" },
                "RPE \(session.intensity.rawValue * 3)"
            ].compactMap { $0 }
            return parts.joined(separator: " · ")
        case .run:
            let dist = session.distanceKm.map { String(format: "%.1f km", $0) } ?? ""
            let dur  = session.durationMinutes.map { "\($0) min" } ?? ""
            return [dist, dur, session.intensity.displayName].filter { !$0.isEmpty }.joined(separator: " · ")
        case .sport:
            let name = session.sportName ?? "sport"
            let dur  = session.durationMinutes.map { "\($0) min" } ?? ""
            return [name, dur, session.intensity.displayName].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private var dayString: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: session.date)
    }
}
