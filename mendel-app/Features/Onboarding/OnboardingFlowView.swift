#if !WIDGET_EXTENSION
//
// OnboardingFlowView.swift
// Premium, paced onboarding flow for KESTO.
//

import SwiftUI
struct OnboardingFlowView: View {
    @Environment(OnboardingStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var viewModel: OnboardingViewModel
    @FocusState private var isTextInputFocused: Bool

    init(store: OnboardingStore) {
        _viewModel = State(initialValue: OnboardingViewModel(store: store))
    }

    var body: some View {
        ZStack {
            KestoTheme.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome

                ScrollView {
                    currentStepBody
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MendelSpacing.xl)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .background(
                    LinearGradient(
                        colors: [KestoTheme.Colors.paper.opacity(0.05), KestoTheme.Colors.paper, KestoTheme.Colors.paper],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.48, dampingFraction: 0.92), value: viewModel.currentStep)
        .task(id: viewModel.currentStep) {
            viewModel.onAppearForCurrentStep()
        }
    }

    private var topChrome: some View {
        VStack(spacing: 14) {
            HStack {
                if viewModel.canGoBack {
                    Button(action: {
                        isTextInputFocused = false
                        viewModel.goBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MendelColors.ink)
                            .frame(width: 36, height: 36)
                            .background(KestoTheme.Colors.white.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()

                Text("KESTO")
                    .font(MendelType.label())
                    .foregroundStyle(MendelColors.inkSoft)
                    .tracking(2.4)
            }

            ProgressView(value: viewModel.progressValue)
                .tint(MendelColors.ink)
                .scaleEffect(x: 1, y: 0.45, anchor: .center)
        }
        .padding(.horizontal, MendelSpacing.xl)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var currentStepBody: some View {
        switch viewModel.currentStep {
        case .opening:
            IntroStepView(
                eyebrow: "Built to endure",
                title: "build something\nthat lasts.",
                body: "Training works better when it fits your real life.",
                accent: .forest
            )
        case .structureStatement:
            StatementStepView(
                title: "you do not need\nmore motivation.\n\nyou need better structure.",
                body: "Kesto is built for training that can survive a real week."
            )
        case .primaryIdentity:
            SingleChoiceStepView(
                title: "What best describes you right now?",
                subtitle: "This sets the first lens for your coach.",
                options: OnboardingPrimaryIdentity.allCases,
                selection: binding(\.primaryIdentity)
            )
        case .goals:
            MultiChoiceStepView(
                title: "What are you working toward?",
                subtitle: "Pick up to three.",
                options: OnboardingGoal.allCases,
                selectedValues: viewModel.profile.goals,
                action: viewModel.toggleGoal
            )
        case .topPriority:
            SingleChoiceStepView(
                title: "What matters most right now?",
                subtitle: "This helps KESTO decide what to protect first.",
                options: OnboardingPriority.allCases,
                selection: binding(\.topPriority)
            )
        case .eventGoal:
            VStack(alignment: .leading, spacing: 20) {
                SingleChoiceStepView(
                    title: "Are you preparing for something specific?",
                    subtitle: "Event context changes how we pace the plan.",
                    options: OnboardingEventGoal.allCases,
                    selection: binding(\.eventGoal)
                )

                if viewModel.profile.eventGoal == .somethingElse {
                    InlineTextArea(
                        title: "What is it?",
                        placeholder: "Type the event or season",
                        text: binding(\.customEventName)
                    )
                }
            }
        case .availableDays:
            NumberChoiceStepView(
                title: "How many days per week can you train realistically?",
                subtitle: "Realistic beats idealized.",
                values: Array(2...7),
                selection: binding(\.availableDays)
            )
        case .trainingModalities:
            MultiChoiceStepView(
                title: "What do your weeks usually include?",
                subtitle: "Pick what is actually true most weeks.",
                options: OnboardingTrainingModality.allCases,
                selectedValues: viewModel.profile.trainingModalities,
                action: viewModel.toggleTrainingModality
            )
        case .obstacles:
            SingleChoiceStepView(
                title: "What usually throws your training off?",
                subtitle: "We want the first plan to respect the real friction.",
                options: OnboardingObstacle.allCases,
                selection: obstacleBinding
            )
        case .whyInterstitial:
            StatementStepView(
                title: "your why matters.",
                body: "Goals can carry you for a few weeks.\nMeaning carries you longer.",
                accent: .ember
            )
        case .deeperWhy:
            VStack(alignment: .leading, spacing: 20) {
                SingleChoiceStepView(
                    title: "Why is this important to you?",
                    subtitle: "This is what your coach should remember when motivation gets thin.",
                    options: OnboardingWhy.allCases,
                    selection: binding(\.deeperWhy)
                )

                if viewModel.profile.deeperWhy == .other {
                    InlineTextArea(
                        title: "Write it in your own words",
                        placeholder: "Keep it honest",
                        text: binding(\.deeperWhyCustomText)
                    )
                }
            }
        case .coachReminder:
            VStack(alignment: .leading, spacing: 20) {
                SingleChoiceStepView(
                    title: "When things get hard, what do you want KESTO to remind you?",
                    subtitle: "Your coach can bring this back at the right moment.",
                    options: OnboardingCoachReminder.allCases,
                    selection: binding(\.coachReminder)
                )

                if viewModel.profile.coachReminder == .custom {
                    InlineTextArea(
                        title: "Your line",
                        placeholder: "Write the reminder you need",
                        text: binding(\.coachReminderCustomText)
                    )
                }
            }
        case .outcomeIdentity:
            SingleChoiceStepView(
                title: "What outcome feels most like you?",
                subtitle: "This captures the kind of athlete you want to become.",
                options: OnboardingOutcomeIdentity.allCases,
                selection: binding(\.desiredOutcomeIdentity)
            )
        case .progressDefinition:
            MultiChoiceStepView(
                title: "What would progress look like in 3–6 months?",
                subtitle: "Pick the signals that should matter.",
                options: OnboardingProgressDefinition.allCases,
                selectedValues: viewModel.profile.progressDefinition,
                action: viewModel.toggleProgressDefinition
            )
        case .recoveryProfile:
            SingleChoiceStepView(
                title: "How do you usually recover from hard training?",
                subtitle: "This affects how much pressure KESTO adds early.",
                options: OnboardingRecoveryProfile.allCases,
                selection: binding(\.recoveryProfile)
            )
        case .coachPushStyle:
            SingleChoiceStepView(
                title: "How should your coach push you?",
                subtitle: "We can be sharp without being reckless.",
                options: OnboardingCoachPushStyle.allCases,
                selection: binding(\.preferredCoachPushStyle)
            )
        case .coachTone:
            SingleChoiceStepView(
                title: "What tone helps you most?",
                subtitle: "This shapes the voice you hear in the app.",
                options: OnboardingCoachTone.allCases,
                selection: binding(\.preferredCoachTone)
            )
        case .runningPlan:
            SingleChoiceStepView(
                title: "Do you already follow a running plan?",
                subtitle: "We should know whether to replace structure or work around it.",
                options: OnboardingRunningPlanStatus.allCases,
                selection: binding(\.followsRunningPlan)
            )
        case .weeklyStructure:
            SingleChoiceStepView(
                title: "Do you want KESTO to help build your weekly structure?",
                subtitle: "Choose how hands-on the system should be.",
                options: OnboardingWeeklyStructurePreference.allCases,
                selection: binding(\.wantsWeeklyStructure)
            )
        case .firstHelpArea:
            SingleChoiceStepView(
                title: "What do you want help with first?",
                subtitle: "We will bias the opening guidance toward this.",
                options: OnboardingHelpArea.allCases,
                selection: binding(\.firstHelpArea)
            )
        case .balanceInterstitial:
            BalanceInterstitialStep()
        case .commitmentIntro:
            StatementStepView(
                title: "make this real.",
                body: "You do not need to promise perfection.\nJust honesty, patience, and repetition.",
                accent: .forest
            )
        case .signature:
            SignatureStepView(
                title: "sign your commitment.",
                subtitle: "This is a symbolic promise to yourself.\nWe will never use your signature for external documents or identity imitation.",
                points: $viewModel.signaturePoints,
                onSigned: viewModel.saveSignature
            )
        case .commitmentLocked:
            LockedInStep(
                title: "locked in.",
                subtitle: "Your plan will be built around your goals, your training reality, and your why.",
                whyLine: viewModel.profile.deeperWhyText
            )
        case .buildProfile:
            BuildProgressStepView(
                title: "Preparing your system",
                subtitle: "One moment. We are shaping the first version around what you told us.",
                states: viewModel.buildStates,
                progress: viewModel.buildProgress
            )
        case .personalizedPreview:
            PersonalizedPreviewStep(personalization: viewModel.personalization)
        case .account:
            AccountStepView()
        case .notifications:
            PermissionStepView(
                title: "Let KESTO keep the week in motion",
                body: "Use notifications for planned-session reminders, recovery prompts, and coach check-ins that arrive with some taste.",
                bullets: [
                    "Reminders for planned sessions",
                    "Recovery prompts when the week needs restraint",
                    "Coach check-ins tied to your setup"
                ],
                status: notifications.isAuthorized ? "already enabled" : nil,
                accent: .forest
            )
        case .health:
            PermissionStepView(
                title: "Bring in your training context",
                body: "Apple Health can import workouts, sharpen recovery context, and reduce manual logging.",
                bullets: [
                    "Import training data",
                    "Improve coach context",
                    "Reduce manual logging"
                ],
                status: healthKit.isAuthorized ? "already connected" : nil,
                accent: .ember
            )
        case .paywall:
            PaywallStepView(price: purchaseManager.formattedPrice, hasPremium: purchaseManager.hasPremiumAccess)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            switch viewModel.currentStep {
            case .notifications:
                actionButton(title: notifications.isAuthorized ? "Continue" : "Enable notifications") {
                    if !notifications.isAuthorized {
                        OnboardingAnalytics.log(.notificationsPrompted)
                        Task { await notifications.requestAuthorization() }
                    }
                    viewModel.continueForward()
                }
            case .health:
                actionButton(title: healthKit.isAuthorized ? "Continue" : "Connect Apple Health") {
                    if !healthKit.isAuthorized {
                        OnboardingAnalytics.log(.healthPrompted)
                        Task { await healthKit.requestAuthorization() }
                    }
                    viewModel.continueForward()
                }
            case .account:
                actionButton(title: "Continue on this device") {
                    OnboardingAnalytics.log(.accountContinue)
                    viewModel.continueForward()
                }

                Text("Account creation is not wired in this build yet. Your setup is still saved locally and ready to use.")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MendelSpacing.xl)
            case .paywall:
                if purchaseManager.hasPremiumAccess {
                    actionButton(title: "Enter KESTO") {
                        viewModel.finishOnboarding()
                    }
                } else {
                    actionButton(title: "Unlock for \(purchaseManager.formattedPrice)") {
                        OnboardingAnalytics.log(.paywallPurchased)
                        Task {
                            await purchaseManager.purchase()
                            if purchaseManager.hasPremiumAccess {
                                viewModel.finishOnboarding()
                            }
                        }
                    }

                    Button("Continue with free version") {
                        viewModel.finishOnboarding()
                    }
                    .buttonStyle(.plain)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                }
            default:
                actionButton(title: ctaTitle) {
                    isTextInputFocused = false
                    viewModel.continueForward()
                }
                .disabled(!viewModel.canContinue)
                .opacity(viewModel.canContinue ? 1 : 0.4)
            }
        }
        .padding(.horizontal, MendelSpacing.xl)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var ctaTitle: String {
        switch viewModel.currentStep {
        case .opening:
            return "Begin"
        case .signature:
            return "Continue"
        case .buildProfile:
            return viewModel.personalizationReady ? "Continue" : "Preparing…"
        case .commitmentLocked:
            return "Continue"
        case .personalizedPreview:
            return "Continue"
        default:
            return "Continue"
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MendelType.bodyMedium())
                .foregroundStyle(KestoTheme.Colors.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MendelColors.ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<OnboardingProfile, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.profile[keyPath: keyPath] },
            set: { newValue in
                viewModel.updateProfile { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var obstacleBinding: Binding<OnboardingObstacle?> {
        Binding(
            get: { viewModel.profile.obstacles.first },
            set: { newValue in
                guard let newValue else { return }
                viewModel.selectObstacle(newValue)
            }
        )
    }
}

private struct IntroStepView: View {
    let eyebrow: String
    let title: String
    let bodyText: String
    let accent: Accent

    enum Accent {
        case ember
        case forest

        var color: Color {
            switch self {
            case .ember:
                return KestoTheme.Colors.ember
            case .forest:
                return KestoTheme.Colors.forest
            }
        }
    }

    init(eyebrow: String, title: String, body: String, accent: Accent) {
        self.eyebrow = eyebrow
        self.title = title
        self.bodyText = body
        self.accent = accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 60)

            Text(eyebrow.uppercased())
                .font(MendelType.label())
                .foregroundStyle(accent.color)
                .tracking(2.6)

            Text(title)
                .font(.system(size: 50, weight: .bold, design: .serif))
                .foregroundStyle(MendelColors.ink)
                .lineSpacing(6)

            Text(bodyText)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .frame(maxWidth: 320, alignment: .leading)
                .lineSpacing(5)

            Spacer(minLength: 180)
        }
    }
}

private struct StatementStepView: View {
    let title: String
    let bodyText: String
    var accent: IntroStepView.Accent = .ember

    init(title: String, body: String, accent: IntroStepView.Accent = .ember) {
        self.title = title
        self.bodyText = body
        self.accent = accent
    }

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer(minLength: 80)

            Capsule()
                .fill(accent.color)
                .frame(width: 48, height: 4)

            Text(title)
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)
                .lineSpacing(6)

            Text(bodyText)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(5)
                .frame(maxWidth: 330, alignment: .leading)

            Spacer(minLength: 200)
        }
    }

    var body: some View { bodyView }
}

private struct SingleChoiceStepView<Option: CaseIterable & Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let subtitle: String
    let options: [Option]
    @Binding var selection: Option?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    SelectionRow(
                        title: option.rawValue,
                        isSelected: selection == option,
                        action: { selection = option }
                    )
                }
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)
        }
    }
}

private struct NumberChoiceStepView: View {
    let title: String
    let subtitle: String
    let values: [Int]
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(MendelColors.ink)
                Text(subtitle)
                    .font(MendelType.body())
                    .foregroundStyle(MendelColors.inkSoft)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(selection == value ? KestoTheme.Colors.paper : MendelColors.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: MendelRadius.md, style: .continuous)
                                    .fill(selection == value ? MendelColors.ink : KestoTheme.Colors.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: MendelRadius.md, style: .continuous)
                                    .stroke(selection == value ? MendelColors.ink : MendelColors.inkFaint, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MultiChoiceStepView<Option: CaseIterable & Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let subtitle: String
    let options: [Option]
    let selectedValues: [Option]
    let action: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(MendelColors.ink)
                Text(subtitle)
                    .font(MendelType.body())
                    .foregroundStyle(MendelColors.inkSoft)
            }

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    SelectionRow(
                        title: option.rawValue,
                        isSelected: selectedValues.contains(option),
                        action: { action(option) }
                    )
                }
            }
        }
    }
}

private struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MendelType.bodyMedium())
                        .foregroundStyle(MendelColors.ink)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? MendelColors.ink : Color.clear)
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? MendelColors.ink : MendelColors.inkFaint, lineWidth: 1)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(KestoTheme.Colors.paper)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: MendelRadius.md, style: .continuous)
                    .fill(isSelected ? KestoTheme.Colors.bone.opacity(0.75) : KestoTheme.Colors.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md, style: .continuous)
                    .stroke(isSelected ? MendelColors.ink.opacity(0.16) : MendelColors.inkFaint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InlineTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
                .tracking(1.4)

            TextField(placeholder, text: $text, axis: .vertical)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.ink)
                .padding(18)
                .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 1)
                )
                .lineLimit(3...5)
        }
    }
}

private struct BalanceInterstitialStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("good training is not just hard.\n\nit is correctly balanced.")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text("Progress depends on the rhythm between stress, recovery, adaptation, and consistency.")
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(5)

            HStack(alignment: .bottom, spacing: 12) {
                BalanceBar(title: "stress", height: 88, color: KestoTheme.Colors.ember)
                BalanceBar(title: "recovery", height: 64, color: KestoTheme.Colors.forest)
                BalanceBar(title: "adapt", height: 76, color: KestoTheme.Colors.slate)
                BalanceBar(title: "repeat", height: 96, color: MendelColors.ink)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 1)
            )
        }
    }
}

private struct BalanceBar: View {
    let title: String
    let height: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.88))
                .frame(width: 56, height: height)

            Text(title)
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SignatureStepView: View {
    let title: String
    let subtitle: String
    @Binding var points: [CGPoint]
    let onSigned: ([CGPoint]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text(subtitle)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)

            SignatureCanvas(points: $points, onChanged: onSigned)
                .frame(height: 280)
                .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 1)
                )

            HStack {
                Text("symbolic only")
                    .font(MendelType.label())
                    .foregroundStyle(KestoTheme.Colors.forest)
                Spacer()
                Button("Clear") {
                    points = []
                    onSigned([])
                }
                .buttonStyle(.plain)
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
            }
        }
    }
}

private struct SignatureCanvas: View {
    @Binding var points: [CGPoint]
    let onChanged: ([CGPoint]) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .fill(KestoTheme.Colors.white)

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(MendelColors.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(MendelColors.inkFaint)
                            .frame(width: min(geometry.size.width * 0.55, 220), height: 1)
                            .padding(.trailing, 22)
                            .padding(.bottom, 34)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0.5)
                    .onChanged { value in
                        let point = value.location
                        points.append(point)
                        onChanged(points)
                    }
            )
        }
    }
}

private struct LockedInStep: View {
    let title: String
    let subtitle: String
    let whyLine: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text(subtitle)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)

            if let whyLine {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHY TO KEEP")
                        .font(MendelType.label())
                        .foregroundStyle(KestoTheme.Colors.ember)
                        .tracking(1.6)
                    Text(whyLine)
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundStyle(MendelColors.ink)
                }
                .padding(24)
                .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 1)
                )
            }
        }
    }
}

private struct BuildProgressStepView: View {
    let title: String
    let subtitle: String
    let states: [BuildItemState]
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text(subtitle)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(states) { item in
                    HStack(spacing: 12) {
                        statusDot(for: item.status)
                        Text(item.title)
                            .font(MendelType.body())
                            .foregroundStyle(MendelColors.ink)
                    }
                }
            }
            .padding(24)
            .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                    .tint(MendelColors.ink)
                Text("\(Int(progress * 100))% ready")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
        }
    }

    private func statusDot(for status: BuildItemState.Status) -> some View {
        Circle()
            .fill(color(for: status))
            .frame(width: 10, height: 10)
    }

    private func color(for status: BuildItemState.Status) -> Color {
        switch status {
        case .pending:
            return MendelColors.inkFaint
        case .active:
            return KestoTheme.Colors.ember
        case .done:
            return KestoTheme.Colors.forest
        }
    }
}

private struct PersonalizedPreviewStep: View {
    let personalization: OnboardingPersonalizationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("your starting focus")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            VStack(alignment: .leading, spacing: 18) {
                previewBlock(title: "starting focus", lines: personalization.startingFocus)
                previewBlock(title: "coach style", lines: [personalization.coachStyleLine])
                previewBlock(title: "why to remember", lines: [personalization.whyLine])
            }
            .padding(24)
            .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 1)
            )

            Text(personalization.firstWeekRecommendation)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)
        }
    }

    private func previewBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(MendelType.label())
                .foregroundStyle(KestoTheme.Colors.ember)
                .tracking(1.4)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(MendelType.body())
                    .foregroundStyle(MendelColors.ink)
            }
        }
    }
}

private struct AccountStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("save your system.")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text("An account lets KESTO keep your plan, coach memory, and training history intact across devices.")
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)

            VStack(spacing: 12) {
                accountRow(title: "Sign in with Apple", subtitle: "Recommended once auth is wired")
                accountRow(title: "Continue with Google", subtitle: "Optional secondary provider")
            }

            Text("This build does not include live account auth yet, so onboarding will continue on-device.")
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
        }
    }

    private func accountRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
                Text(subtitle)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
            Spacer()
            Text("Soon")
                .font(MendelType.label())
                .foregroundStyle(KestoTheme.Colors.forest)
        }
        .padding(18)
        .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MendelRadius.md)
                .stroke(MendelColors.inkFaint, lineWidth: 1)
        )
    }
}

private struct PermissionStepView: View {
    let title: String
    let bodyText: String
    let bullets: [String]
    let status: String?
    let accent: IntroStepView.Accent

    init(title: String, body: String, bullets: [String], status: String?, accent: IntroStepView.Accent) {
        self.title = title
        self.bodyText = body
        self.bullets = bullets
        self.status = status
        self.accent = accent
    }

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text(bodyText)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(bullet)
                            .font(MendelType.body())
                            .foregroundStyle(MendelColors.ink)
                    }
                }
            }
            .padding(24)
            .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 1)
            )

            if let status {
                Text(status)
                    .font(MendelType.caption())
                    .foregroundStyle(KestoTheme.Colors.forest)
            }
        }
    }

    var body: some View { bodyView }
}

private struct PaywallStepView: View {
    let price: String
    let hasPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(hasPremium ? "premium is already unlocked." : "unlock your tailored system.")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(MendelColors.ink)

            Text(hasPremium ? "Everything below is already available to you." : "Unlock personalized coach guidance, adaptive weekly structure, and calmer, sharper recommendations from the start.")
                .font(MendelType.body())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 14) {
                paywallItem("Personalized coach guidance")
                paywallItem("Adaptive weekly structure")
                paywallItem("Goal-aware recommendations")
                paywallItem("Training and recovery balance")
                paywallItem("Saved progress and insight")
            }
            .padding(24)
            .background(KestoTheme.Colors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 1)
            )

            if !hasPremium {
                Text("One-time unlock: \(price)")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
        }
        .onAppear {
            OnboardingAnalytics.log(.paywallViewed)
        }
    }

    private func paywallItem(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KestoTheme.Colors.forest)
            Text(text)
                .font(MendelType.body())
                .foregroundStyle(MendelColors.ink)
        }
    }
}
#endif
