import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var recoveryLogs: [RecoveryLog]

    @State private var appeared = false

    var recommendation: Recommendation { appState.recommendation }
    var summary: WeeklySummary        { appState.weeklySummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Date
                Text(dateString)
                    .font(MendelType.label())
                    .foregroundStyle(MendelColors.inkSoft)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)

                // State word
                Text(recommendation.state.rawValue)
                    .font(MendelType.stateWord())
                    .foregroundStyle(MendelColors.ink)
                    .tracking(-3)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)

                // Context line
                Text(recommendation.context)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .lineSpacing(4)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)

                // Divider
                Rectangle()
                    .fill(MendelColors.inkFaint)
                    .frame(width: 32, height: 1)
                    .padding(.vertical, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                // Steps label
                SectionLabel(text: "do this")
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.18), value: appeared)

                // Steps list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recommendation.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("→")
                                .font(MendelType.caption())
                                .foregroundStyle(MendelColors.inkFaint)
                                .padding(.top, 1)
                            Text(step)
                                .font(MendelType.body())
                                .foregroundStyle(MendelColors.ink)
                                .lineSpacing(3)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(
                            .easeOut(duration: 0.4).delay(0.22 + Double(idx) * 0.06),
                            value: appeared
                        )
                    }
                }

                Spacer().frame(height: 36)

                // Load bars
                VStack(spacing: 10) {
                    LoadBar(
                        label: "Strength",
                        value: summary.strengthBalance,
                        detail: "\(summary.strengthSessions)×"
                    )
                    LoadBar(
                        label: "Endurance",
                        value: summary.enduranceBalance,
                        detail: "\(summary.enduranceSessions)×"
                    )
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)

                Spacer().frame(height: 24)

                // Log button
                PrimaryButton(title: "+ log activity") {
                    appState.selectedTab = .log
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.42), value: appeared)

                Spacer().frame(height: 100) // space for tab bar
            }
            .padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(MendelColors.bg)
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            }
        }
        .onChange(of: recommendation.state) {
            // Re-animate on state change
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { appeared = true }
            }
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: .now)
    }
}
