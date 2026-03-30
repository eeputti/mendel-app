import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct MendelTodayWidget: Widget {
    let kind = MendelWidgetKind.today

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MendelProvider()) { entry in
            MendelWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.97, green: 0.97, blue: 0.96), for: .widget)
        }
        .configurationDisplayName("Mendel")
        .description("See your training recommendation at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry View (dispatches to size-specific views)

struct MendelWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MendelEntry

    var body: some View {
        // Deep link into the app — opens Today tab
        Link(destination: URL(string: "mendel://today")!) {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .accessoryRectangular:
                LockScreenWidgetView(entry: entry)
            case .accessoryInline:
                InlineLockScreenView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - Bundle

@main
struct MendelWidgetBundle: WidgetBundle {
    var body: some Widget {
        MendelTodayWidget()
    }
}
