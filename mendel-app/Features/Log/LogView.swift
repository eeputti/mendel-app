#if !WIDGET_EXTENSION
//
// LogView.swift
// Quick add flows for workouts and recovery.
//

import SwiftUI
import SwiftData

struct LogView: View {
    @Environment(NotificationManager.self) private var notifications
    @State private var showingWorkout = true
    @State private var showingRecovery = false
    @State private var saved = false

    var body: some View {
        KestoScreen {
            KestoSectionHeader(
                eyebrow: "Quick Add",
                title: "Log training",
                subtitle: "Fast entry for workouts and recovery, with the same calmer KESTO rhythm."
            )

            HStack(spacing: 10) {
                EntryTypeCard(
                    title: "Workout",
                    subtitle: "Date, type, duration",
                    icon: "figure.run",
                    isSelected: showingWorkout
                ) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showingWorkout = true
                        showingRecovery = false
                    }
                }

                EntryTypeCard(
                    title: "Recovery",
                    subtitle: "Sleep and soreness",
                    icon: "moon",
                    isSelected: showingRecovery
                ) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showingWorkout = false
                        showingRecovery = true
                    }
                }
            }

            if showingWorkout {
                KestoCard(style: .elevated) {
                    SessionEditorView {
                        notifications.didLogSession()
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showingRecovery {
                KestoCard(style: .elevated) {
                    RecoveryForm {
                        saved = true
                        showingRecovery = false
                        showingWorkout = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if saved {
                SavedToast().transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: saved)
    }
}

private struct EntryTypeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                Text(title)
                    .font(KestoTheme.Typography.bodyStrong)
                    .foregroundStyle(isSelected ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                Text(subtitle)
                    .font(KestoTheme.Typography.detail)
                    .foregroundStyle(isSelected ? KestoTheme.Colors.whiteWarm.opacity(0.7) : KestoTheme.Colors.slateSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: KestoTheme.Radius.card, style: .continuous)
                    .fill(isSelected ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                    .overlay(
                        RoundedRectangle(cornerRadius: KestoTheme.Radius.card, style: .continuous)
                            .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RecoveryForm: View {
    @Environment(\.modelContext) private var modelContext
    let onSave: () -> Void
    @State private var sleepQuality: SleepQuality?
    @State private var soreness: SorenessLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sleep quality")
                PillSelector(options: SleepQuality.allCases, label: { $0.rawValue }, selected: $sleepQuality)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Soreness")
                PillSelector(options: SorenessLevel.allCases, label: { $0.rawValue }, selected: $soreness)
            }

            KestoPrimaryButton(title: "Save recovery") {
                guard let sleepQuality, let soreness else { return }
                modelContext.insert(RecoveryLog(sleepQuality: sleepQuality, soreness: soreness))
                try? modelContext.save()
                onSave()
            }
        }
    }
}

private struct SavedToast: View {
    var body: some View {
        Text("Logged")
            .font(KestoTheme.Typography.buttonSmall)
            .foregroundStyle(KestoTheme.Colors.whiteWarm)
            .tracking(0.8)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(KestoTheme.Colors.ink, in: Capsule())
            .padding(.top, 60)
    }
}
#endif
