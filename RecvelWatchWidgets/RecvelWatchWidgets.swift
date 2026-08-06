import SwiftUI
import WidgetKit

private struct WatchHealthEntry: TimelineEntry {
    let date: Date
    let snapshot: RecvelSharedSnapshot
}

private struct WatchHealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchHealthEntry {
        WatchHealthEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchHealthEntry) -> Void) {
        completion(WatchHealthEntry(date: .now, snapshot: context.isPreview ? .preview : RecvelSharedSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchHealthEntry>) -> Void) {
        let entry = WatchHealthEntry(date: .now, snapshot: RecvelSharedSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1_800))))
    }
}

private struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchHealthEntry
    private let color = Color(red: 0.361, green: 0.902, blue: 0.659)
    private var recoveryTitle: String {
        RecvelL10n.text("score.recovery.title", language: entry.snapshot.displayLanguage)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(entry.snapshot.recovery ?? 0), in: 0...100) {
                Image(systemName: "heart.fill")
            } currentValueLabel: {
                Text(entry.snapshot.recovery.map(String.init) ?? "--")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            .widgetAccentable()
        case .accessoryCorner:
            Text(entry.snapshot.recovery.map(String.init) ?? "--")
                .font(.title.bold().monospacedDigit())
                .widgetLabel { Label(recoveryTitle, systemImage: "heart.fill") }
        case .accessoryInline:
            Label(
                "R \(entry.snapshot.recovery.map(String.init) ?? "--") · S \(entry.snapshot.sleep.map(String.init) ?? "--")",
                systemImage: "heart.fill"
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        default:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                    Text(recoveryTitle)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(entry.snapshot.recovery.map(String.init) ?? "--")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                    Text(entry.snapshot.sleep.map(String.init) ?? "--")
                    Text("·").foregroundStyle(.secondary)
                    Image(systemName: "flame.fill")
                    Text(entry.snapshot.strain.map(String.init) ?? "--")
                }
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(RecvelL10n.text("score.sleep.title", language: entry.snapshot.displayLanguage)) \(entry.snapshot.sleep.map(String.init) ?? "--"), \(RecvelL10n.text("score.load.title", language: entry.snapshot.displayLanguage)) \(entry.snapshot.strain.map(String.init) ?? "--")"
                )
                Text(entry.snapshot.nextAction)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct RecvelWatchReadinessWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecvelWatchReadiness", provider: WatchHealthProvider()) { entry in
            WatchComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "recvel://today"))
        }
        .configurationDisplayName("widget.readiness.name")
        .description("widget.readiness.description")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

@main
struct RecvelWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecvelWatchReadinessWidget()
    }
}
