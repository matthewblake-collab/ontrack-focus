import WidgetKit
import SwiftUI

// MARK: - Entry + Provider

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let snapshot: ReadinessSnapshot?
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: Date(), snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        let snap = ReadinessSnapshot.load() ?? previewSnapshot
        completion(ReadinessEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let snap = ReadinessSnapshot.load()
        let entry = ReadinessEntry(date: Date(), snapshot: snap)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var previewSnapshot: ReadinessSnapshot {
        ReadinessSnapshot(
            score: 75,
            computedAt: Date(),
            nextIncompleteItemName: "Morning walk",
            breakdown: ["sleep": 2400, "hrv": 1600, "rhr": 900, "checkin": 1500, "attendance": 800, "workout": 500]
        )
    }
}

// MARK: - Home Widget (systemSmall)

struct ReadinessHomeWidgetView: View {
    let entry: ReadinessEntry
    private let deepLink = URL(string: "ontrack://readiness")!

    private var score: Int { entry.snapshot?.score ?? 0 }

    private var tierColor: Color {
        switch score {
        case 80...: return Color(red: 0.2, green: 0.85, blue: 0.5)
        case 60..<80: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return Color(red: 0.95, green: 0.3, blue: 0.35)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Ring + score
            ZStack {
                Circle()
                    .fill(tierColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(tierColor.opacity(0.25), lineWidth: 7)
                    .frame(width: 68, height: 68)
                Circle()
                    .trim(from: 0, to: entry.snapshot != nil ? CGFloat(score) / 100.0 : 0)
                    .stroke(tierColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tierColor.opacity(0.6), radius: 6)
                Text(entry.snapshot != nil ? "\(score)" : "—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Text("READINESS")
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(tierColor.opacity(0.7))

            if entry.snapshot?.isStale == true {
                Text("Open app to refresh")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else if let next = entry.snapshot?.nextIncompleteItemName, !next.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UP NEXT")
                        .font(.system(size: 7, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(tierColor.opacity(0.55))
                    Text(next)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } else if entry.snapshot != nil {
                Text(score >= 80 ? "Looking good" : score >= 60 ? "Recovery moderate" : "Recovery low")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text("Open OnTrack")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .widgetURL(deepLink)
    }
}

struct ReadinessHomeWidget: Widget {
    let kind: String = "ReadinessHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessHomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    let score = entry.snapshot?.score ?? 0
                    let tierColor: Color = {
                        switch score {
                        case 80...: return Color(red: 0.2, green: 0.85, blue: 0.5)
                        case 60..<80: return Color(red: 1.0, green: 0.6, blue: 0.2)
                        default: return Color(red: 0.95, green: 0.3, blue: 0.35)
                        }
                    }()
                    ZStack {
                        Color(red: 0.05, green: 0.08, blue: 0.10)
                        RadialGradient(
                            colors: [tierColor.opacity(0.22), Color.clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 130
                        )
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(tierColor.opacity(0.25), lineWidth: 8)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(tierColor.opacity(0.85), lineWidth: 1.5)
                    }
                }
        }
        .configurationDisplayName("Readiness")
        .description("Daily readiness score + next item.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Lock Widget (accessoryCircular + accessoryRectangular)

struct ReadinessLockCircularView: View {
    let entry: ReadinessEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .trim(from: 0, to: CGFloat(entry.snapshot?.score ?? 0) / 100.0)
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Text(entry.snapshot.map { "\($0.score)" } ?? "—")
                .font(.system(size: 16, weight: .bold))
        }
        .widgetURL(URL(string: "ontrack://readiness"))
    }
}

struct ReadinessLockRectangularView: View {
    let entry: ReadinessEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Readiness")
                .font(.system(size: 11, weight: .semibold))
            Text(entry.snapshot.map { "\($0.score) / 100" } ?? "—")
                .font(.system(size: 16, weight: .bold))
            if let next = entry.snapshot?.nextIncompleteItemName, !next.isEmpty {
                Text(next).font(.system(size: 10)).lineLimit(1)
            } else if let snap = entry.snapshot {
                Text("Recovery \(snap.tier)").font(.system(size: 10))
            }
        }
        .widgetURL(URL(string: "ontrack://readiness"))
    }
}

struct ReadinessLockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadinessEntry

    var body: some View {
        switch family {
        case .accessoryCircular: ReadinessLockCircularView(entry: entry)
        case .accessoryRectangular: ReadinessLockRectangularView(entry: entry)
        default: ReadinessLockCircularView(entry: entry)
        }
    }
}

struct ReadinessLockWidget: Widget {
    let kind: String = "ReadinessLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessLockWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Readiness (Lock)")
        .description("Compact readiness on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
