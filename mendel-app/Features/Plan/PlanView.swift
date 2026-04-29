#if !WIDGET_EXTENSION
//
// PlanView.swift
// Structured training plan editor in the refreshed KESTO language.
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @Query(sort: \Session.date, order: .forward) private var sessions: [Session]
    @Environment(MendelAppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @AppStorage("plan.goal") private var goalRawValue = TrainingGoal.generalHealth.rawValue
    @AppStorage("plan.sports") private var sportsRawValue = PlanSport.defaults.joinedRawValue
    @AppStorage("plan.sessionsPerWeek") private var sessionsPerWeek = 3
    @AppStorage("plan.weeklyStructure") private var weeklyStructure = ""

    @State private var saved = false
    @State private var reviewProposal: PlanAdjustmentProposal?

    private var goalValue: TrainingGoal {
        TrainingGoal(rawValue: goalRawValue) ?? .generalHealth
    }

    private var selectedSportsValue: [PlanSport] {
        PlanSport.decodeList(from: sportsRawValue)
    }

    private var goalBinding: Binding<TrainingGoal> {
        Binding(
            get: { TrainingGoal(rawValue: goalRawValue) ?? .generalHealth },
            set: { goalRawValue = $0.rawValue }
        )
    }

    private var selectedSportsBinding: Binding<[PlanSport]> {
        Binding(
            get: { PlanSport.decodeList(from: sportsRawValue) },
            set: { sportsRawValue = $0.joinedRawValue }
        )
    }

    private var plannedSessions: [Session] {
        sessions
            .filter { $0.sessionStatus == .planned }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        KestoScreen {
            KestoSectionHeader(
                eyebrow: "Plan",
                title: "Build the next block",
                subtitle: "Shape a simple week with clean structure, clear intent, and room for recovery."
            )

            HStack(alignment: .top, spacing: KestoTheme.Spacing.md) {
                KestoStatCard(
                    title: "Current split",
                    value: "\(sessionsPerWeek)x",
                    detail: "Sessions per week in the current plan template.",
                    tone: .neutral
                )

                KestoStatCard(
                    title: "Upcoming",
                    value: "\(plannedSessions.count)",
                    detail: plannedSessions.isEmpty ? "No planned sessions yet." : "Sessions already on the calendar.",
                    tone: plannedSessions.isEmpty ? .ember : .forest
                )
            }

            PlanSetupCard(
                goal: goalBinding,
                selectedSports: selectedSportsBinding,
                sessionsPerWeek: $sessionsPerWeek,
                weeklyStructure: $weeklyStructure,
                onGenerate: generatePlan
            )

            if let proposal = appState.suggestedPlanAdjustment {
                CoachPlanProposalCard(
                    titleLabel: "Coach adjustment",
                    proposal: proposal,
                    acceptTitle: "apply update",
                    onAccept: { apply(proposal, clearsGlobalProposal: true) },
                    onDismiss: { appState.dismissSuggestedPlanAdjustment() }
                )
            }

            if let reviewProposal {
                CoachPlanProposalCard(
                    titleLabel: "Coach-built plan",
                    proposal: reviewProposal,
                    acceptTitle: "write to calendar",
                    onAccept: { apply(reviewProposal, clearsGlobalProposal: false) },
                    onDismiss: { self.reviewProposal = nil }
                )
            }

            KestoSectionHeader(
                eyebrow: "Overview",
                title: "Weekly split",
                subtitle: "A lightweight editorial view of what is already scheduled."
            )

            if plannedSessions.isEmpty {
                PlanEmptyState()
            } else {
                KestoCard(style: .elevated) {
                    VStack(spacing: KestoTheme.Spacing.lg) {
                        ForEach(Array(plannedSessions.prefix(7).enumerated()), id: \.element.id) { _, session in
                            PlannedSessionRow(session: session)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if saved {
                PlanSavedToast().transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: saved)
    }

    private func generatePlan() {
        reviewProposal = CoachPlanningService.makeGeneratedPlanProposal(
            existingPlannedSessions: plannedSessions,
            goal: goalValue,
            sports: selectedSportsValue.isEmpty ? goalValue.defaultSports : selectedSportsValue,
            sessionsPerWeek: sessionsPerWeek,
            weeklyStructure: weeklyStructure
        )
    }

    private func apply(_ proposal: PlanAdjustmentProposal, clearsGlobalProposal: Bool) {
        CoachPlanningService.apply(proposal, sessions: sessions, modelContext: modelContext)
        if clearsGlobalProposal {
            appState.clearDismissedPlanAdjustmentFingerprint()
            appState.suggestedPlanAdjustment = nil
        }
        reviewProposal = nil
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
    }
}

private struct PlanSetupCard: View {
    @Binding var goal: TrainingGoal
    @Binding var selectedSports: [PlanSport]
    @Binding var sessionsPerWeek: Int
    @Binding var weeklyStructure: String
    let onGenerate: () -> Void

    var body: some View {
        KestoCard(style: .elevated) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Editor",
                    title: "Plan settings",
                    subtitle: "Choose the goal, sports, and weekly shape before writing sessions into the calendar."
                )

                VStack(alignment: .leading, spacing: KestoTheme.Spacing.xs) {
                    SectionLabel(text: "Goal")
                    Picker("", selection: $goal) {
                        ForEach(TrainingGoal.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, KestoTheme.Spacing.inlinePadding)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kestoCard(.inline, padding: 0)
                }

                VStack(alignment: .leading, spacing: KestoTheme.Spacing.xs) {
                    SectionLabel(text: "Sports")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(PlanSport.allCases, id: \.self) { option in
                            Button {
                                if selectedSports.contains(option) {
                                    selectedSports.removeAll { $0 == option }
                                } else {
                                    selectedSports.append(option)
                                }
                            } label: {
                                Text(option.displayName)
                                    .font(KestoTheme.Typography.buttonSmall)
                                    .foregroundStyle(selectedSports.contains(option) ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous)
                                            .fill(selectedSports.contains(option) ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: KestoTheme.Radius.inline, style: .continuous)
                                                    .stroke(selectedSports.contains(option) ? KestoTheme.Colors.ink : KestoTheme.Colors.border, lineWidth: 0.9)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: KestoTheme.Spacing.xs) {
                    SectionLabel(text: "Sessions per week")
                    Stepper(value: $sessionsPerWeek, in: 1...7) {
                        Text("\(sessionsPerWeek) sessions")
                            .font(KestoTheme.Typography.bodyStrong)
                            .foregroundStyle(KestoTheme.Colors.ink)
                    }
                    .padding(.horizontal, KestoTheme.Spacing.inlinePadding)
                    .padding(.vertical, 12)
                    .kestoCard(.inline, padding: 0)
                }

                FormField(
                    label: "Weekly structure (optional)",
                    placeholder: "Mon run, Wed strength, Sat long",
                    value: $weeklyStructure
                )

                KestoPrimaryButton(title: "Generate plan") {
                    onGenerate()
                }
            }
        }
    }
}

private struct PlanEmptyState: View {
    var body: some View {
        KestoEmptyState(
            title: "No planned sessions yet",
            detail: "Choose a goal, your sports, and a weekly structure to write a calm, usable plan into the calendar.",
            symbol: "calendar.badge.plus"
        )
    }
}

private struct PlannedSessionRow: View {
    let session: Session

    var body: some View {
        KestoListRow(title: session.displayTitle, subtitle: session.detailText) {
            Image(systemName: session.displayCategory.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KestoTheme.Colors.ink)
        } trailing: {
            Text(dayLabel)
                .font(KestoTheme.Typography.label)
                .foregroundStyle(KestoTheme.Colors.slateSoft)
        }
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.date)
    }
}

private struct PlanSavedToast: View {
    var body: some View {
        Text("Plan saved")
            .font(KestoTheme.Typography.buttonSmall)
            .foregroundStyle(KestoTheme.Colors.whiteWarm)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(KestoTheme.Colors.ink, in: Capsule())
            .padding(.top, 16)
    }
}
#endif
