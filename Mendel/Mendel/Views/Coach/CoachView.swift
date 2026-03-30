import SwiftUI
import SwiftData

// MARK: - Coach Screen

struct CoachView: View {

    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showChips = true

    private let claude = ClaudeService()

    private let chips = [
        "what should I do tomorrow?",
        "am I overtraining?",
        "build me next week",
        "how do I balance strength and running?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("coach")
                    .font(MendelType.screenTitle())
                    .foregroundStyle(MendelColors.ink)
                Text("ask anything")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
            .padding(.horizontal, MendelSpacing.xl)
            .padding(.top, 28)
            .padding(.bottom, 16)

            Rectangle()
                .fill(MendelColors.inkFaint)
                .frame(height: 0.5)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Greeting
                        if messages.isEmpty {
                            GreetingBubble(appState: appState, summary: appState.weeklySummary)
                        }

                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        if isLoading {
                            LoadingBubble()
                                .id("loading")
                        }

                        Spacer().frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, MendelSpacing.xl)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: isLoading) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            // Prompt chips
            if showChips {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.self) { chip in
                            ChipButton(text: chip) {
                                send(text: chip)
                            }
                        }
                    }
                    .padding(.horizontal, MendelSpacing.xl)
                    .padding(.vertical, 12)
                }
                .background(MendelColors.bg)
            }

            // Input row
            Rectangle()
                .fill(MendelColors.inkFaint)
                .frame(height: 0.5)

            HStack(spacing: 10) {
                TextField("ask something…", text: $inputText, axis: .vertical)
                    .font(MendelType.body())
                    .foregroundStyle(MendelColors.ink)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MendelColors.inkFaint.opacity(0.5), in: Capsule())
                    .onSubmit { if !inputText.isEmpty { send(text: inputText) } }

                Button {
                    if !inputText.isEmpty { send(text: inputText) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(inputText.isEmpty ? MendelColors.inkFaint : MendelColors.ink)
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(inputText.isEmpty ? MendelColors.inkSoft : MendelColors.bg)
                    }
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.horizontal, MendelSpacing.xl)
            .padding(.vertical, 12)
            .padding(.bottom, 100) // tab bar
            .background(MendelColors.bg)
        }
        .background(MendelColors.bg)
    }

    // MARK: - Send

    private func send(text: String) {
        guard !text.isEmpty, !isLoading else { return }

        let userMsg = ChatMessage(role: "user", text: text)
        messages.append(userMsg)
        inputText = ""
        showChips = false
        isLoading = true

        Task {
            do {
                let history = messages.map {
                    ClaudeService.Message(role: $0.role, content: $0.text)
                }
                let ctx = buildContext()
                let reply = try await claude.send(messages: history, context: ctx)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", text: reply))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(
                        role: "assistant",
                        text: "couldn't reach the coach right now. check your connection."
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func buildContext() -> CoachContext {
        let s  = appState.weeklySummary
        let lr = recoveryLogs.sorted { $0.date > $1.date }.first
        return CoachContext(
            todayState:       appState.recommendation.state.rawValue.lowercased(),
            weeklyLoad:       s.totalLoadScore,
            strengthSessions: s.strengthSessions,
            enduranceSessions:s.enduranceSessions,
            soreness:         lr?.soreness.rawValue ?? "unknown",
            sleepQuality:     lr?.sleepQuality.rawValue ?? "unknown"
        )
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
    var isUser: Bool { role == "user" }
}

// MARK: - Bubble Views

struct GreetingBubble: View {
    let appState: AppState
    let summary: WeeklySummary

    private var greetingText: String {
        let s = summary.strengthSessions
        let e = summary.enduranceSessions
        if s == 0 && e == 0 {
            return "no sessions logged yet. log your first session and I'll give you personalised advice."
        }
        return "you've done \(s) strength and \(e) endurance session\(e == 1 ? "" : "s") this week. today's recommendation: \(appState.recommendation.state.rawValue.lowercased()). what do you want to know?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mendel".uppercased())
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkSoft)
                .tracking(0.8)
            Text(greetingText)
                .font(MendelType.chatText())
                .foregroundStyle(MendelColors.ink)
                .lineSpacing(3)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(MendelColors.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                        )
                )
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if !message.isUser {
                    Text("Mendel".uppercased())
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.inkSoft)
                        .tracking(0.8)
                }
                Text(message.text)
                    .font(MendelType.chatText())
                    .foregroundStyle(message.isUser ? MendelColors.bg : MendelColors.ink)
                    .lineSpacing(3)
                    .padding(14)
                    .background(
                        Group {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(MendelColors.ink)
                            } else {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(MendelColors.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                                    )
                            }
                        }
                    )
            }
            if !message.isUser { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

struct LoadingBubble: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(MendelColors.inkSoft)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MendelColors.white)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MendelColors.inkFaint, lineWidth: 0.5))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation { phase = 1 }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

struct ChipButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                        .background(Capsule().fill(MendelColors.white))
                )
        }
        .buttonStyle(.plain)
    }
}
