#if !WIDGET_EXTENSION
//
// SessionEditorView.swift
// Shared workout editor for logging and calendar editing.
//

import SwiftUI
import SwiftData

struct SessionEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let session: Session?
    let showsStatus: Bool
    let defaultDate: Date
    let defaultStatus: SessionStatus
    let onSave: () -> Void

    @State private var date: Date
    @State private var category: WorkoutCategory
    @State private var subtype: String
    @State private var durationMinutes: String
    @State private var notes: String
    @State private var perceivedEffort: Int
    @State private var status: SessionStatus

    init(
        session: Session? = nil,
        showsStatus: Bool = false,
        defaultDate: Date = .now,
        defaultStatus: SessionStatus = .completed,
        onSave: @escaping () -> Void
    ) {
        self.session = session
        self.showsStatus = showsStatus
        self.defaultDate = defaultDate
        self.defaultStatus = defaultStatus
        self.onSave = onSave

        _date = State(initialValue: session?.date ?? defaultDate)
        _category = State(initialValue: session?.displayCategory ?? .running)
        _subtype = State(initialValue: session?.subtype ?? "")
        _durationMinutes = State(initialValue: session?.durationMinutes.map(String.init) ?? "")
        _notes = State(initialValue: session?.notes ?? "")
        _perceivedEffort = State(initialValue: session?.perceivedEffort ?? 0)
        _status = State(initialValue: session?.sessionStatus ?? defaultStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KestoTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Workout date")
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(8)
                .background(KestoTheme.Colors.whiteWarm, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(KestoTheme.Colors.border, lineWidth: 0.9)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Workout type")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(WorkoutCategory.allCases, id: \.self) { option in
                        Button {
                            category = option
                            if !option.suggestedSubtypes.contains(subtype.lowercased()) {
                                subtype = ""
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 14, weight: .light))
                                Text(option.displayName)
                                    .font(KestoTheme.Typography.buttonSmall)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(category == option ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: MendelRadius.sm)
                                    .fill(category == option ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: MendelRadius.sm)
                                            .stroke(category == option ? KestoTheme.Colors.ink : KestoTheme.Colors.border, lineWidth: 0.9)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !category.suggestedSubtypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Session type")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(category.suggestedSubtypes, id: \.self) { option in
                                Button {
                                    subtype = option
                                } label: {
                                    Text(option)
                                        .font(KestoTheme.Typography.buttonSmall)
                                        .foregroundStyle(subtype.caseInsensitiveCompare(option) == .orderedSame ? KestoTheme.Colors.whiteWarm : KestoTheme.Colors.ink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: MendelRadius.sm)
                                                .fill(subtype.caseInsensitiveCompare(option) == .orderedSame ? KestoTheme.Colors.ink : KestoTheme.Colors.whiteWarm)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: MendelRadius.sm)
                                                        .stroke(
                                                            subtype.caseInsensitiveCompare(option) == .orderedSame ? KestoTheme.Colors.ink : KestoTheme.Colors.border,
                                                            lineWidth: 0.9
                                                        )
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    FormField(
                        label: "Custom session type (optional)",
                        placeholder: category.suggestedSubtypes.joined(separator: ", "),
                        value: $subtype
                    )
                }
            }

            HStack(alignment: .top, spacing: 10) {
                FormField(
                    label: "Duration (min)",
                    placeholder: "45",
                    value: $durationMinutes,
                    keyboardType: .numberPad
                )
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Feel (optional)")
                    EffortSelector(level: $perceivedEffort)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            FormField(label: "Notes (optional)", placeholder: "how it felt, what you did…", value: $notes)

            if showsStatus {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Status")
                    PillSelector(options: SessionStatus.allCases, label: { $0.displayName }, selected: Binding(
                        get: { Optional(status) },
                        set: { status = $0 ?? status }
                    ))
                }
            }

            KestoPrimaryButton(title: session == nil ? "Save workout" : "Save changes") {
                saveSession()
            }
        }
    }

    private func saveSession() {
        let resolvedIntensity = IntensityLevel.fromPerceivedEffort(perceivedEffort > 0 ? perceivedEffort : nil)

        if let session {
            session.date = date
            session.category = category
            session.type = category.defaultSessionType
            session.subtype = subtype.nilIfEmpty
            session.durationMinutes = Int(durationMinutes)
            session.notes = notes.nilIfEmpty
            session.perceivedEffort = perceivedEffort > 0 ? perceivedEffort : nil
            session.intensity = resolvedIntensity
            session.status = status
        } else {
            let newSession = Session(
                date: date,
                type: category.defaultSessionType,
                intensity: resolvedIntensity,
                durationMinutes: Int(durationMinutes),
                category: category,
                subtype: subtype.nilIfEmpty,
                notes: notes.nilIfEmpty,
                perceivedEffort: perceivedEffort > 0 ? perceivedEffort : nil,
                status: status
            )
            modelContext.insert(newSession)
        }

        try? modelContext.save()
        onSave()
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
