import SwiftUI

// MARK: - HealthKit Permission Card
// Shown on first launch inside TodayView if not yet authorized.

struct HealthKitPromptCard: View {

    @Environment(HealthKitManager.self) private var hk
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "heart")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(MendelColors.stone)
                Text("connect health")
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
            }

            Text("mendel reads your workouts, heart rate, and HRV from Apple Health to improve recommendations automatically.")
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(3)

            HStack(spacing: 10) {
                GhostButton(title: "not now") { /* dismiss, user can enable later in settings */ }
                PrimaryButton(title: "connect") {
                    requesting = true
                    Task {
                        await hk.requestAuthorization()
                        requesting = false
                    }
                }
            }
        }
        .padding(18)
        .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MendelRadius.md)
                .stroke(MendelColors.inkFaint, lineWidth: 0.5)
        )
    }
}

// MARK: - Recovery Signal Row
// Shows HRV / RHR inside TodayView as subtle context (unlocked users only).

struct RecoverySignalRow: View {

    @Environment(HealthKitManager.self) private var hk

    var body: some View {
        HStack(spacing: 20) {
            SignalPill(
                label: "RHR",
                value: hk.restingHeartRate.map { "\(Int($0)) bpm" } ?? "—"
            )
            SignalPill(
                label: "HRV",
                value: hk.hrv.map { "\(Int($0)) ms" } ?? "—"
            )
            SignalPill(
                label: "Steps",
                value: hk.stepsToday > 0 ? "\(hk.stepsToday.formatted())" : "—"
            )
        }
    }
}

private struct SignalPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(MendelType.label())
                .foregroundStyle(MendelColors.inkFaint)
                .tracking(0.8)
            Text(value)
                .font(MendelType.bodyMedium())
                .foregroundStyle(MendelColors.ink)
        }
    }
}

// MARK: - HealthKit Workouts Import Banner
// Shows when HK workouts exist but haven't been imported as sessions yet.

struct WorkoutsImportBanner: View {

    @Environment(HealthKitManager.self) private var hk
    let onImport: ([HealthSession]) -> Void

    var pendingCount: Int { hk.recentWorkouts.count }

    var body: some View {
        if pendingCount > 0 {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(MendelColors.stone)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pendingCount) workouts in Health")
                        .font(MendelType.bodyMedium())
                        .foregroundStyle(MendelColors.ink)
                    Text("import to update your load score")
                        .font(MendelType.caption())
                        .foregroundStyle(MendelColors.inkSoft)
                }
                Spacer()
                Button {
                    onImport(hk.toEngineSessions())
                } label: {
                    Text("import")
                        .font(MendelType.label())
                        .foregroundStyle(MendelColors.bg)
                        .tracking(0.4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(MendelColors.ink, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .stroke(MendelColors.inkFaint, lineWidth: 0.5)
            )
        }
    }
}
