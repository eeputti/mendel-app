#if !WIDGET_EXTENSION
//
// CoachView.swift
// Calm, premium coaching chat surface.
//

import SwiftUI
import SwiftData

struct CoachView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \RecoveryLog.date, order: .reverse) private var recoveryLogs: [RecoveryLog]
    @Environment(PurchaseManager.self) private var store
    @Environment(HealthKitManager.self) private var healthKit
    @StateObject private var viewModel = CoachViewModel()
    @State private var showPaywall = false

    var body: some View {
        KestoScreen {
            KestoSectionHeader(
                eyebrow: "Coach",
                title: "Coach chat",
                subtitle: "A serious, quieter place to think through training, recovery, and what comes next."
            )

            if store.hasPremiumAccess {
                CoachContextSummaryCard(trainingContext: coachTrainingContext)
                CoachChatCard(viewModel: viewModel, trainingContext: coachTrainingContext)
            } else {
                lockedContent
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(store)
        }
    }

    private var coachTrainingContext: CoachTrainingContext {
        CoachContextBuilder.makeContext(
            sessions: sessions,
            recoveryLogs: recoveryLogs,
            healthSessions: healthKit.toEngineSessions()
        )
    }

    private var lockedContent: some View {
        KestoCard(style: .elevated) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                KestoSectionHeader(
                    eyebrow: "Premium",
                    title: "Unlock coach",
                    subtitle: "One-time purchase. No subscription."
                )
                KestoPrimaryButton(title: "Unlock") {
                    showPaywall = true
                }
            }
        }
    }
}

private struct CoachContextSummaryCard: View {
    let trainingContext: CoachTrainingContext

    var body: some View {
        KestoCard(style: .muted) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Context",
                    title: "Recent signal",
                    subtitle: "A quick frame for the conversation before you type."
                )

                HStack(spacing: 10) {
                    KestoChip("\(trainingContext.weekly_training_volume.completed_sessions_7d) recent sessions", icon: "figure.run")
                    KestoChip("\(trainingContext.planned_sessions_this_week.count) planned ahead", icon: "calendar")
                }

                Text(trainingSummary)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
                    .lineSpacing(3)
            }
        }
    }

    private var trainingSummary: String {
        if trainingContext.weekly_training_volume.completed_sessions_7d == 0 {
            return "There is not much recent training context yet, so the coach will lean more on your stated intent."
        }
        return "Recent load score is \(formatted(trainingContext.weekly_training_volume.load_score_7d)). Readiness trend is \(trainingContext.readiness.lowercased())."
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct CoachChatCard: View {
    @ObservedObject var viewModel: CoachViewModel
    let trainingContext: CoachTrainingContext
    private let starterPrompts = [
        "what should i do today?",
        "am i overtraining?",
        "should i run or rest?",
        "adjust my week",
        "can i do gym tomorrow?",
        "build next week"
    ]

    var body: some View {
        KestoCard(style: .elevated) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
                KestoSectionHeader(
                    eyebrow: "Conversation",
                    title: "Ask coach",
                    subtitle: "Plain answers, grounded in your recent training."
                )

                if viewModel.messages.isEmpty {
                    VStack(alignment: .leading, spacing: KestoTheme.Spacing.md) {
                        Text("Ask about training, recovery, your next week, or whether today should stay light.")
                            .font(KestoTheme.Typography.body)
                            .foregroundStyle(KestoTheme.Colors.ink)
                            .lineSpacing(3)

                        starterPromptChips
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            CoachChatBubble(message: message)
                        }

                        if viewModel.isSendingMessage {
                            CoachThinkingRow()
                        }
                    }
                }

                if let failure = viewModel.currentFailure {
                    CoachChatStatusCard(
                        failure: failure,
                        retryTitle: viewModel.isOffline ? "try again" : "retry"
                    ) {
                        Task { await viewModel.retryFailedMessage(trainingContext: trainingContext) }
                    }
                }

                composer
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: KestoTheme.Spacing.sm) {
            TextField(
                "",
                text: Binding(
                    get: { viewModel.draftMessage },
                    set: { viewModel.updateDraft($0) }
                ),
                prompt: Text("Ask about training, recovery, or your week")
                    .foregroundStyle(KestoTheme.Colors.slateSoft),
                axis: .vertical
            )
            .font(KestoTheme.Typography.body)
            .foregroundStyle(KestoTheme.Colors.ink)
            .lineLimit(1...5)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
            )

            HStack(spacing: KestoTheme.Spacing.sm) {
                if viewModel.isSendingMessage {
                    Label {
                        Text("Coach is thinking")
                            .font(KestoTheme.Typography.detail)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                            .tint(KestoTheme.Colors.slateSoft)
                    }
                } else if viewModel.isOffline {
                    Text("No connection.")
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                } else {
                    Text("Conversation stays open.")
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.slateSoft)
                }

                Spacer()

                Button {
                    Task { await viewModel.sendMessage(trainingContext: trainingContext) }
                } label: {
                    Text(viewModel.isSendingMessage ? "Sending" : "Send")
                        .font(KestoTheme.Typography.bodyStrong)
                        .foregroundStyle(viewModel.canSendDraft ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.slateSoft)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(viewModel.canSendDraft ? KestoTheme.Colors.ink : KestoTheme.Colors.bone.opacity(0.55), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSendDraft)
            }
        }
    }

    private var starterPromptChips: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(starterPrompts, id: \.self) { prompt in
                Button {
                    viewModel.updateDraft(prompt)
                    Task { await viewModel.sendMessage(trainingContext: trainingContext) }
                } label: {
                    KestoChip(prompt, tone: .neutral)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSendingMessage)
                .opacity(viewModel.isSendingMessage ? 0.6 : 1)
            }
        }
    }
}

private struct CoachChatBubble: View {
    let message: CoachMessage

    var body: some View {
        VStack(alignment: bubbleAlignment, spacing: 7) {
            Text(message.role == .user ? "YOU" : "COACH")
                .font(KestoTheme.Typography.label)
                .foregroundStyle(KestoTheme.Colors.slateSoft)
                .tracking(1.1)

            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(KestoTheme.Typography.body)
                    .foregroundStyle(KestoTheme.Colors.ink)
                    .lineSpacing(3)

                switch message.delivery {
                case .sending:
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(KestoTheme.Colors.slateSoft)
                        Text("sending")
                            .font(KestoTheme.Typography.detail)
                            .foregroundStyle(KestoTheme.Colors.slateSoft)
                    }
                case .failed:
                    Text("not sent yet")
                        .font(KestoTheme.Typography.detail)
                        .foregroundStyle(KestoTheme.Colors.ember)
                case .sent:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: 290, alignment: .leading)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bubbleBorder, lineWidth: 0.9)
            )
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var bubbleAlignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleColor: Color {
        switch (message.role, message.delivery) {
        case (.user, .failed):
            return KestoTheme.Colors.emberSoft
        case (.user, _):
            return KestoTheme.Colors.bone.opacity(0.5)
        case (.assistant, _):
            return KestoTheme.Colors.whiteWarm
        }
    }

    private var bubbleBorder: Color {
        message.delivery == .failed ? KestoTheme.Colors.ember.opacity(0.22) : KestoTheme.Colors.border
    }
}

private struct CoachThinkingRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(KestoTheme.Colors.slateSoft)

            Text("Coach is thinking.")
                .font(KestoTheme.Typography.detail)
                .foregroundStyle(KestoTheme.Colors.slateSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KestoTheme.Colors.whiteWarm, in: Capsule())
        .overlay(
            Capsule()
                .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
        )
    }
}

private struct CoachChatStatusCard: View {
    let failure: CoachChatFailurePresentation
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        KestoCard(style: .tinted, padding: KestoTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: KestoTheme.Spacing.xs) {
                Text(failure.title)
                    .font(KestoTheme.Typography.bodyStrong)
                    .foregroundStyle(KestoTheme.Colors.ink)

                Text(failure.detail)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(KestoTheme.Colors.slateSoft)
                    .lineSpacing(3)

                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(KestoTheme.Typography.buttonSmall)
                        .foregroundStyle(KestoTheme.Colors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(KestoTheme.Colors.whiteWarm, in: Capsule())
                        .overlay(Capsule().stroke(KestoTheme.Colors.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 0
    var verticalSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + horizontalSpacing + size.width > maxWidth {
                totalHeight += rowHeight + verticalSpacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? horizontalSpacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        if !subviews.isEmpty {
            totalHeight += rowHeight
        }

        return CGSize(width: proposal.width ?? rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif
