import SwiftUI
import WidgetKit

// MARK: - Color helpers (widget can't use MendelColors directly)
// These mirror the main app's design system.

private extension Color {
    static let mBg      = Color(red: 0.97, green: 0.97, blue: 0.96)  // #F8F7F5
    static let mInk     = Color(red: 0.06, green: 0.06, blue: 0.06)  // #0F0F0F
    static let mSoft    = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.38)
    static let mFaint   = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.12)
    static let mStone   = Color(red: 0.77, green: 0.66, blue: 0.51)  // #C4A882
    static let mWhite   = Color.white
}

// MARK: - State accent color

private func stateColor(_ state: String) -> Color {
    switch state {
    case "RECOVER": return .mStone
    case "REST":    return .mSoft
    default:        return .mInk
    }
}

// MARK: - Small Widget  (2×2)
// Just the state word + one-line context. Instantly scannable.

struct SmallWidgetView: View {
    let entry: MendelEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.mBg

            VStack(alignment: .leading, spacing: 4) {
                // Mendel wordmark
                Text("mendel")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mSoft)
                    .tracking(1.2)

                Spacer()

                // State word
                Text(entry.recommendation.stateDisplay)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.mInk)
                    .tracking(-1.5)
                    .minimumScaleFactor(0.7)

                // Context — one line only
                Text(entry.recommendation.context)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.mSoft)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Medium Widget  (4×2)
// State word on left + 2 steps on right.

struct MediumWidgetView: View {
    let entry: MendelEntry

    var body: some View {
        ZStack {
            Color.mBg

            HStack(alignment: .center, spacing: 0) {

                // Left: state
                VStack(alignment: .leading, spacing: 6) {
                    Text("mendel")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.mSoft)
                        .tracking(1.2)

                    Spacer()

                    Text(entry.recommendation.stateDisplay)
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(Color.mInk)
                        .tracking(-2)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(formattedTime)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.mFaint)
                }
                .frame(maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.vertical, 14)

                Spacer()

                // Divider
                Rectangle()
                    .fill(Color.mFaint)
                    .frame(width: 0.5)
                    .padding(.vertical, 14)

                // Right: steps
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.recommendation.steps.prefix(2).enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("→")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mFaint)
                            Text(step)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.mInk)
                                .lineSpacing(2)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "updated \(f.string(from: entry.recommendation.updatedAt))"
    }
}

// MARK: - Large Widget  (4×4)
// Full state word + context + all steps + week load bar.

struct LargeWidgetView: View {
    let entry: MendelEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.mBg

            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    Text("mendel")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.mSoft)
                        .tracking(1.2)
                    Spacer()
                    Text(dayString)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.mFaint)
                }
                .padding(.bottom, 12)

                // State
                Text(entry.recommendation.stateDisplay)
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Color.mInk)
                    .tracking(-2.5)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Context
                Text(entry.recommendation.context)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.mSoft)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .padding(.top, 6)

                // Divider
                Rectangle()
                    .fill(Color.mFaint)
                    .frame(height: 0.5)
                    .padding(.vertical, 16)

                // Steps label
                Text("DO THIS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.mFaint)
                    .tracking(1.0)
                    .padding(.bottom, 10)

                // All steps
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.recommendation.steps.enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("→")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.mFaint)
                            Text(step)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.mInk)
                                .lineSpacing(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }

                Spacer()

                // Footer
                Text("tap to open mendel")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.mFaint)
                    .tracking(0.3)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: .now).lowercased()
    }
}

// MARK: - Lock Screen Widget  (accessoryRectangular)
// Ultra-minimal — state word only. Fits on lock screen / StandBy.

struct LockScreenWidgetView: View {
    let entry: MendelEntry

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.recommendation.stateDisplay)
                .font(.system(size: 16, weight: .heavy))
                .tracking(-0.5)
            Text("·")
                .foregroundStyle(.secondary)
            Text(entry.recommendation.context)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Inline Lock Screen  (accessoryInline)

struct InlineLockScreenView: View {
    let entry: MendelEntry

    var body: some View {
        Label {
            Text(entry.recommendation.stateDisplay)
                .font(.system(size: 12, weight: .bold))
        } icon: {
            Image(systemName: entry.recommendation.state == "TRAIN"
                  ? "figure.run"
                  : entry.recommendation.state == "RECOVER"
                  ? "heart"
                  : "moon")
        }
    }
}
