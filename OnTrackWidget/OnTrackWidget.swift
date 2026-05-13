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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("READINESS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if entry.snapshot?.isStale == true {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.snapshot.map { "\($0.score)" } ?? "—")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(entry.snapshot?.ringColor ?? .white)
                Text(entry.snapshot.map { _ in "/100" } ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)

            if entry.snapshot?.isStale == true {
                Text("Open OnTrack to refresh")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            } else if let next = entry.snapshot?.nextIncompleteItemName, !next.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Up next")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(next)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } else {
                Text(entry.snapshot.map { "Recovery \($0.tier)" } ?? "Open OnTrack")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .widgetURL(deepLink)
    }
}

struct ReadinessHomeWidget: Widget {
    let kind: String = "ReadinessHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessHomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.08, green: 0.12, blue: 0.15)
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
