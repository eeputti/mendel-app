import SwiftUI

// MARK: - Notification Settings View
// Accessible from the Today screen (settings icon) or after first launch prompt.

struct NotificationSettingsView: View {

    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @AppStorage("notif.morningBrief")   private var morningBriefOn   = true
    @AppStorage("notif.eveningReminder") private var eveningReminderOn = true
    @AppStorage("notif.recoveryNudge")  private var recoveryNudgeOn  = true
    @AppStorage("notif.morningHour")    private var morningHour       = 8
    @AppStorage("notif.eveningHour")    private var eveningHour       = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("notifications")
                    .font(MendelType.screenTitle())
                    .foregroundStyle(MendelColors.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MendelColors.inkSoft)
                        .frame(width: 28, height: 28)
                        .background(MendelColors.inkFaint, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MendelSpacing.xl)
            .padding(.top, 28)
            .padding(.bottom, 8)

            Text("calm reminders. never noise.")
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .padding(.horizontal, MendelSpacing.xl)
                .padding(.bottom, 28)

            if !notifications.isAuthorized {
                NotificationPermissionCard()
                    .padding(.horizontal, MendelSpacing.xl)
                    .padding(.bottom, 20)
            }

            ScrollView {
                VStack(spacing: 1) {

                    NotifRow(
                        icon:     "sun.horizon",
                        title:    "morning brief",
                        detail:   "today's recommendation at \(morningHour):00",
                        isOn:     $morningBriefOn
                    )

                    NotifRow(
                        icon:     "moon",
                        title:    "log reminder",
                        detail:   "reminder to log if you haven't by \(eveningHour):30",
                        isOn:     $eveningReminderOn
                    )

                    NotifRow(
                        icon:     "heart",
                        title:    "recovery check-in",
                        detail:   "midday reminder on rest and recover days",
                        isOn:     $recoveryNudgeOn
                    )
                }
                .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                )
                .padding(.horizontal, MendelSpacing.xl)

                Spacer().frame(height: 28)

                // Time pickers
                VStack(spacing: 1) {
                    TimePickerRow(label: "morning brief time", hour: $morningHour)
                    TimePickerRow(label: "evening reminder time", hour: $eveningHour)
                }
                .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                )
                .padding(.horizontal, MendelSpacing.xl)

                Spacer().frame(height: 28)

                Text("mendel will never send more than 2 notifications per day.")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MendelSpacing.xl)

                Spacer().frame(height: 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(MendelColors.bg)
        .onChange(of: morningBriefOn)    { reschedule() }
        .onChange(of: eveningReminderOn) { reschedule() }
        .onChange(of: recoveryNudgeOn)   { reschedule() }
        .onChange(of: morningHour)       { reschedule() }
        .onChange(of: eveningHour)       { reschedule() }
    }

    private func reschedule() {
        guard notifications.isAuthorized else { return }
        Task { await notifications.scheduleAll(recommendation: SharedStore.load()) }
    }
}

// MARK: - Notification Row

private struct NotifRow: View {
    let icon:   String
    let title:  String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(MendelColors.inkFaint.opacity(0.6))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(MendelColors.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
                Text(detail)
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MendelColors.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MendelColors.white)
    }
}

// MARK: - Time Picker Row

private struct TimePickerRow: View {
    let label: String
    @Binding var hour: Int

    // Build a Date from the stored hour for the DatePicker
    private var binding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour, minute: 0, second: 0, of: .now
                ) ?? .now
            },
            set: { newDate in
                hour = Calendar.current.component(.hour, from: newDate)
            }
        )
    }

    var body: some View {
        HStack {
            Text(label)
                .font(MendelType.bodyMedium())
                .foregroundStyle(MendelColors.ink)
            Spacer()
            DatePicker(
                "",
                selection: binding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(MendelColors.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MendelColors.white)
    }
}

// MARK: - Permission Card

private struct NotificationPermissionCard: View {
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(MendelColors.stone)
                Text("enable notifications")
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(MendelColors.ink)
            }
            Text("mendel needs permission to send you daily reminders. you control which ones.")
                .font(MendelType.caption())
                .foregroundStyle(MendelColors.inkSoft)
                .lineSpacing(3)

            PrimaryButton(title: "allow notifications") {
                Task { await notifications.requestAuthorization() }
            }
        }
        .padding(16)
        .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: MendelRadius.md)
                .stroke(MendelColors.inkFaint, lineWidth: 0.5)
        )
    }
}
