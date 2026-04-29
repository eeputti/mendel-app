// =============================================================
// MENDEL WIDGET — COMBINED SOURCE FILE
// Compile this file only in the widget extension target.
// The main app target in this project compiles every Swift file in this folder,
// so we gate the widget entry point behind a widget-only Swift flag.
//
// For the widget extension target, add `WIDGET_EXTENSION` to:
// Build Settings > Swift Compiler - Custom Flags >
// Active Compilation Conditions
//
// Keep MendelShared.swift in both targets.
// =============================================================

#if WIDGET_EXTENSION

import WidgetKit
import SwiftUI

// =============================================================
// MARK: - TIMELINE ENTRY & PROVIDER
// =============================================================

struct MendelEntry: TimelineEntry {
    let date:           Date
    let recommendation: SharedRecommendation

    static let fallback = MendelEntry(date: .now, recommendation: .placeholder)
}

struct MendelProvider: TimelineProvider {
    func placeholder(in context: Context) -> MendelEntry {
        .fallback
    }

    func getSnapshot(in context: Context, completion: @escaping (MendelEntry) -> Void) {
        completion(.fallback)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MendelEntry>) -> Void) {
        let entry = MendelEntry(date: .now, recommendation: SharedStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)
            ?? .now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// =============================================================
// MARK: - WIDGET COLORS
// =============================================================

private extension Color {
    static let mBg    = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let mInk   = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let mSoft  = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.38)
    static let mFaint = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.18)
}

// =============================================================
// MARK: - WIDGET VIEWS
// =============================================================

struct SmallWidgetView: View {
    let entry: MendelEntry
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.mBg
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Widget.brandLabel).font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.mSoft).tracking(1.2).textCase(.uppercase)
                Spacer()
                Text(displayState).font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.mInk).tracking(-1.5).minimumScaleFactor(0.7)
                Text(displayContext).font(.system(size: 11))
                    .foregroundStyle(Color.mSoft).lineLimit(2).lineSpacing(2)
            }.padding(14)
        }.clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var displayState: String { normalizedRecommendation.state }
    private var displayContext: String { normalizedRecommendation.context }
    private var normalizedRecommendation: SharedRecommendation { entry.recommendation.normalizedForWidget }
}

struct MediumWidgetView: View {
    let entry: MendelEntry
    var body: some View {
        ZStack {
            Color.mBg
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppStrings.Widget.brandLabel).font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.mSoft).tracking(1.2).textCase(.uppercase)
                    Spacer()
                    Text(displayState).font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(Color.mInk).tracking(-2).minimumScaleFactor(0.6).lineLimit(1)
                    Text(updatedTime).font(.system(size: 9)).foregroundStyle(Color.mFaint)
                }
                .frame(maxHeight: .infinity, alignment: .leading).padding(.leading, 16).padding(.vertical, 14)

                Spacer()
                Rectangle().fill(Color.mFaint).frame(width: 0.5).padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(displaySteps.prefix(2).enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("→").font(.system(size: 11)).foregroundStyle(Color.mFaint)
                            Text(step).font(.system(size: 12)).foregroundStyle(Color.mInk)
                                .lineSpacing(2).lineLimit(2).minimumScaleFactor(0.85)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center).padding(.horizontal, 14).padding(.vertical, 14)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var updatedTime: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "updated \(f.string(from: normalizedRecommendation.updatedAt))"
    }
    private var displayState: String { normalizedRecommendation.state }
    private var displaySteps: [String] { normalizedRecommendation.steps }
    private var normalizedRecommendation: SharedRecommendation { entry.recommendation.normalizedForWidget }
}

struct LargeWidgetView: View {
    let entry: MendelEntry
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.mBg
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(AppStrings.Widget.brandLabel).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.mSoft).tracking(1.2).textCase(.uppercase)
                    Spacer()
                    Text(dayString).font(.system(size: 10)).foregroundStyle(Color.mFaint)
                }.padding(.bottom, 12)

                Text(displayState).font(.system(size: 54, weight: .heavy))
                    .foregroundStyle(Color.mInk).tracking(-2.5).minimumScaleFactor(0.6).lineLimit(1)
                Text(displayContext).font(.system(size: 12))
                    .foregroundStyle(Color.mSoft).lineSpacing(3).lineLimit(2).padding(.top, 6)

                Rectangle().fill(Color.mFaint).frame(height: 0.5).padding(.vertical, 16)

                Text("DO THIS").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.mFaint).tracking(1.0).padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(displaySteps.enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("→").font(.system(size: 12)).foregroundStyle(Color.mFaint)
                            Text(step).font(.system(size: 13)).foregroundStyle(Color.mInk)
                                .lineSpacing(2).minimumScaleFactor(0.85)
                        }
                    }
                }
                Spacer()
                Text(AppStrings.Widget.openPrompt).font(.system(size: 10)).foregroundStyle(Color.mFaint).padding(.top, 16)
            }.padding(18)
        }.clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var dayString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: .now).lowercased()
    }
    private var displayState: String { normalizedRecommendation.state }
    private var displayContext: String { normalizedRecommendation.context }
    private var displaySteps: [String] { normalizedRecommendation.steps }
    private var normalizedRecommendation: SharedRecommendation { entry.recommendation.normalizedForWidget }
}

struct LockScreenWidgetView: View {
    let entry: MendelEntry
    var body: some View {
        HStack(spacing: 8) {
            Text(displayState).font(.system(size: 15, weight: .heavy)).tracking(-0.3)
            Text("·").foregroundStyle(.secondary)
            Text(displayContext).font(.system(size: 11))
                .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private var displayState: String { normalizedRecommendation.state }
    private var displayContext: String { normalizedRecommendation.context }
    private var normalizedRecommendation: SharedRecommendation { entry.recommendation.normalizedForWidget }
}

// =============================================================
// MARK: - ENTRY VIEW + WIDGET DEFINITION + BUNDLE
// =============================================================

struct MendelWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MendelEntry
    private let destinationURL = URL(string: AppStrings.DeepLinks.today)

    var body: some View {
        Group {
            switch family {
            case .systemSmall:           SmallWidgetView(entry: entry)
            case .systemMedium:          MediumWidgetView(entry: entry)
            case .systemLarge:           LargeWidgetView(entry: entry)
            case .accessoryRectangular:  LockScreenWidgetView(entry: entry)
            default:                     SmallWidgetView(entry: entry)
            }
        }
        .widgetURL(destinationURL)
    }
}

struct MendelTodayWidget: Widget {
    let kind = MendelWidgetKind.today

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MendelProvider()) { entry in
            MendelWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.97, green: 0.97, blue: 0.96), for: .widget)
        }
        .configurationDisplayName(AppStrings.Widget.displayName)
        .description("See your training recommendation at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@main
struct MendelWidgetBundle: WidgetBundle {
    var body: some Widget { MendelTodayWidget() }
}

private extension SharedRecommendation {
    var normalizedForWidget: SharedRecommendation {
        SharedRecommendation(
            state: state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SharedRecommendation.placeholder.state : state,
            context: context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SharedRecommendation.placeholder.context : context,
            steps: steps.isEmpty ? SharedRecommendation.placeholder.steps : steps,
            updatedAt: updatedAt
        )
    }
}
#endif
