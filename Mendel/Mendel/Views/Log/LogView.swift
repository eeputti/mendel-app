import SwiftUI
import SwiftData

// MARK: - Log Screen

struct LogView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self)  private var appState

    @State private var selectedType: SessionType? = nil
    @State private var showingRecovery = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("log")
                    .font(MendelType.screenTitle())
                    .foregroundStyle(MendelColors.ink)
                    .padding(.top, 28)

                Text("what did you do?")
                    .font(MendelType.caption())
                    .foregroundStyle(MendelColors.inkSoft)
                    .padding(.top, 4)
                    .padding(.bottom, 28)

                // Type grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(SessionType.allCases, id: \.self) { type in
                        ActivityTypeCard(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                    }

                    // Recovery card (separate model)
                    RecoveryTypeCard(isSelected: showingRecovery) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingRecovery.toggle()
                            if showingRecovery { selectedType = nil }
                        }
                    }
                }

                Spacer().frame(height: 20)

                // Dynamic form
                if let type = selectedType {
                    SessionForm(type: type, onSave: {
                        saved = true
                        selectedType = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    })
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showingRecovery {
                    RecoveryForm(onSave: {
                        saved = true
                        showingRecovery = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    })
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, MendelSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(MendelColors.bg)
        .overlay(alignment: .top) {
            if saved {
                SavedToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: saved)
    }
}

// MARK: - Activity Type Card

struct ActivityTypeCard: View {
    let type: SessionType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text(type.displayName)
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text(typeSubtitle(type))
                    .font(MendelType.label())
                    .foregroundStyle(isSelected ? MendelColors.bg.opacity(0.5) : MendelColors.inkSoft)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .fill(isSelected ? MendelColors.ink : MendelColors.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendelRadius.md)
                            .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func typeSubtitle(_ t: SessionType) -> String {
        switch t {
        case .strength: return "sets · reps · weight"
        case .run:      return "distance · time"
        case .sport:    return "duration · type"
        }
    }
}

// MARK: - Recovery Type Card

struct RecoveryTypeCard: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "moon")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text("Recovery")
                    .font(MendelType.bodyMedium())
                    .foregroundStyle(isSelected ? MendelColors.bg : MendelColors.ink)
                Text("sleep · soreness")
                    .font(MendelType.label())
                    .foregroundStyle(isSelected ? MendelColors.bg.opacity(0.5) : MendelColors.inkSoft)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: MendelRadius.md)
                    .fill(isSelected ? MendelColors.ink : MendelColors.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendelRadius.md)
                            .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Form

struct SessionForm: View {

    @Environment(\.modelContext) private var modelContext

    let type: SessionType
    let onSave: () -> Void

    // Strength fields
    @State private var exerciseName = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var effort = 0

    // Run fields
    @State private var distanceKm = ""
    @State private var durationMin = ""

    // Sport fields
    @State private var sportName = ""
    @State private var sportDuration = ""

    // Shared
    @State private var intensity: IntensityLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Rectangle()
                .fill(MendelColors.inkFaint)
                .frame(height: 0.5)
                .padding(.vertical, 4)

            switch type {
            case .strength:
                FormField(label: "Exercise (optional)", placeholder: "squat, bench, deadlift…", value: $exerciseName)
                HStack(spacing: 10) {
                    FormField(label: "Sets", placeholder: "3", value: $sets, keyboardType: .numberPad)
                    FormField(label: "Reps", placeholder: "8", value: $reps, keyboardType: .numberPad)
                    FormField(label: "kg", placeholder: "80", value: $weight, keyboardType: .decimalPad)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Effort (RPE)")
                    EffortSelector(level: $effort)
                }

            case .run:
                HStack(spacing: 10) {
                    FormField(label: "Distance (km)", placeholder: "8.0", value: $distanceKm, keyboardType: .decimalPad)
                    FormField(label: "Time (min)", placeholder: "40", value: $durationMin, keyboardType: .numberPad)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Intensity")
                    PillSelector(
                        options: IntensityLevel.allCases,
                        label: { $0.displayName },
                        selected: $intensity
                    )
                }

            case .sport:
                FormField(label: "Sport", placeholder: "tennis, basketball…", value: $sportName)
                FormField(label: "Duration (min)", placeholder: "90", value: $sportDuration, keyboardType: .numberPad)
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Intensity")
                    PillSelector(
                        options: IntensityLevel.allCases,
                        label: { $0.displayName },
                        selected: $intensity
                    )
                }
            }

            PrimaryButton(title: "save") {
                saveSession()
            }
        }
        .padding(.vertical, 4)
    }

    private func saveSession() {
        let resolvedIntensity: IntensityLevel = intensity ?? {
            if effort >= 4 { return .hard }
            if effort >= 2 { return .moderate }
            return .easy
        }()

        let session = Session(
            type:            type,
            intensity:       resolvedIntensity,
            sets:            Int(sets),
            reps:            Int(reps),
            weight:          Double(weight),
            exerciseName:    exerciseName.isEmpty ? nil : exerciseName,
            distanceKm:      Double(distanceKm),
            durationMinutes: Int(durationMin.isEmpty ? sportDuration : durationMin),
            sportName:       sportName.isEmpty ? nil : sportName
        )

        modelContext.insert(session)
        try? modelContext.save()
        onSave()
    }
}

// MARK: - Recovery Form

struct RecoveryForm: View {

    @Environment(\.modelContext) private var modelContext
    let onSave: () -> Void

    @State private var sleepQuality: SleepQuality? = nil
    @State private var soreness: SorenessLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Rectangle()
                .fill(MendelColors.inkFaint)
                .frame(height: 0.5)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sleep quality")
                PillSelector(
                    options: SleepQuality.allCases,
                    label: { $0.rawValue },
                    selected: $sleepQuality
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Soreness")
                PillSelector(
                    options: SorenessLevel.allCases,
                    label: { $0.rawValue },
                    selected: $soreness
                )
            }

            PrimaryButton(title: "save") {
                guard let sleep = sleepQuality, let sore = soreness else { return }
                let log = RecoveryLog(sleepQuality: sleep, soreness: sore)
                modelContext.insert(log)
                try? modelContext.save()
                onSave()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Saved Toast

struct SavedToast: View {
    var body: some View {
        Text("logged")
            .font(MendelType.label())
            .foregroundStyle(MendelColors.bg)
            .tracking(0.8)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(MendelColors.ink, in: Capsule())
            .padding(.top, 60)
    }
}
