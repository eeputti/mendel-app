#if !WIDGET_EXTENSION
//
// CoachPlanningComponents.swift
// Shared coach-first dashboard and proposal surfaces.
//

import SwiftUI

struct CoachCompactWeekCard: View {
    let days: [Date]
    let sessionsByDay: [Date: [Session]]
    let syncedCountByDay: [Date: Int]
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "This week")
                    Spacer()
                    Text("open calendar")
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.inkSoft)
                }

                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { day in
                        let normalized = calendar.startOfDay(for: day)
                        let sessions = sessionsByDay[normalized] ?? []
                        let syncedCount = syncedCountByDay[normalized] ?? 0

                        VStack(spacing: 8) {
                            Text(shortWeekday(for: day))
                                .font(MendelType.label())
                                .foregroundStyle(MendelColors.inkSoft)
                                .tracking(0.6)
                            Text(dayNumber(for: day))
                                .font(MendelType.bodyMedium())
                                .foregroundStyle(calendar.isDateInToday(day) ? MendelColors.bg : MendelColors.ink)
                                .frame(width: 34, height: 34)
                                .background(dayBackground(for: day), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            HStack(spacing: 3) {
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
                                if syncedCount > 0 {
                                    Circle()
                                        .fill(KestoTheme.Colors.forest.opacity(0.65))
                                        .frame(width: 6, height: 6)
                                }
                                if sessions.isEmpty && syncedCount == 0 {
                                    Capsule()
                                        .fill(MendelColors.inkFaint)
                                        .frame(width: 10, height: 4)
                                }
                            }
                            .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .kestoCard(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func dayBackground(for date: Date) -> Color {
        if calendar.isDateInToday(date) {
            return KestoTheme.Colors.slate
        }
        if let sessions = sessionsByDay[calendar.startOfDay(for: date)], !sessions.isEmpty {
            return KestoTheme.Colors.bone.opacity(0.85)
        }
        return KestoTheme.Colors.bone.opacity(0.4)
    }
}

struct CoachPlanProposalCard: View {
    let titleLabel: String
    let proposal: PlanAdjustmentProposal
    let acceptTitle: String
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: titleLabel)

            Text(proposal.headline)
                .font(MendelType.sectionTitle())
                .foregroundStyle(MendelColors.ink)

            Text(proposal.reason)
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(proposal.changes) { change in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.title)
                            .font(MendelType.bodyMedium())
                            .foregroundStyle(MendelColors.ink)
                        Text(change.detail)
                            .font(MendelType.caption())
                            .foregroundStyle(MendelColors.inkSoft)
                            .lineSpacing(3)
                    }
                }
            }

            HStack(spacing: 10) {
                GhostButton(title: "dismiss", action: onDismiss)
                PrimaryButton(title: acceptTitle, action: onAccept)
            }
        }
        .kestoCard(.secondary)
    }
}
#endif
