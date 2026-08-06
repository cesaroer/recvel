import ActivityKit
import SwiftUI
import WidgetKit

private struct HealthEntry: TimelineEntry {
    let date: Date
    let snapshot: RecvelSharedSnapshot
}

private struct HealthTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        completion(HealthEntry(date: .now, snapshot: context.isPreview ? .preview : RecvelSharedSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        let entry = HealthEntry(date: .now, snapshot: RecvelSharedSnapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private enum WidgetPalette {
    // High-contrast full-color palette. Secondary text remains readable after
    // WidgetKit reduces luminance for Always-On Display and Lock Screen.
    static let primaryText = Color(red: 0.969, green: 0.980, blue: 0.988)   // #F7FAFC
    static let secondaryText = Color(red: 0.757, green: 0.792, blue: 0.835) // #C1CAD5
    static let tertiaryText = Color(red: 0.561, green: 0.608, blue: 0.659)  // #8F9BA8
    static let recovery = Color(red: 0.361, green: 0.902, blue: 0.659)      // #5CE6A8
    static let strain = Color(red: 1.000, green: 0.667, blue: 0.400)        // #FFAA66
    static let sleep = Color(red: 0.769, green: 0.604, blue: 1.000)         // #C49AFF
    static let energy = Color(red: 1.000, green: 0.820, blue: 0.400)        // #FFD166
    static let cardio = Color(red: 0.353, green: 0.851, blue: 1.000)        // #5AD9FF
    static let heart = Color(red: 1.000, green: 0.420, blue: 0.596)         // #FF6B98
    static let oxygen = Color(red: 0.471, green: 0.663, blue: 1.000)        // #78A9FF
    static let background = Color(red: 0.035, green: 0.047, blue: 0.067)    // #090C11
    static let backgroundRaised = Color(red: 0.075, green: 0.094, blue: 0.118) // #13181E
}

private struct ScoreRing: View {
    let value: Int?
    let color: Color
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: Double(value ?? 0) / 100)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            Text(value.map(String.init) ?? "--")
                .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
    }
}

private struct ReadinessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HealthEntry

    private var language: AppLanguage { entry.snapshot.displayLanguage }
    private func text(_ key: String) -> String { RecvelL10n.text(key, language: language) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircle
        case .accessoryRectangular:
            accessoryRectangle
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetPalette.recovery)
                    .widgetAccentable()
                Text(text("score.recovery.title").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetPalette.recovery)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(entry.snapshot.updatedAt, style: .time)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetPalette.tertiaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 10) {
                ScoreRing(value: entry.snapshot.recovery, color: WidgetPalette.recovery, size: 54, lineWidth: 5.5)
                VStack(alignment: .leading, spacing: 6) {
                    miniScore(text("score.sleep.title"), entry.snapshot.sleep, WidgetPalette.sleep)
                    miniScore(text("score.load.title"), entry.snapshot.strain, WidgetPalette.strain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(entry.snapshot.nextAction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .widgetSurface()
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text("widget.today"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(WidgetPalette.recovery)
                    .widgetAccentable()
                ScoreRing(value: entry.snapshot.recovery, color: WidgetPalette.recovery, size: 68, lineWidth: 6.5)
                Text(text("score.recovery.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.primaryText)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    metricColumn(text("score.sleep.title"), entry.snapshot.sleep, WidgetPalette.sleep)
                    metricColumn(text("score.load.title"), entry.snapshot.strain, WidgetPalette.strain)
                    metricColumn(text("score.energy.title"), entry.snapshot.energy, WidgetPalette.energy)
                }
                Divider().overlay(WidgetPalette.secondaryText.opacity(0.24))
                Text(entry.snapshot.nextAction)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text("\(text("common.confidence")) \(entry.snapshot.confidence) · \(entry.snapshot.dataMode)")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .widgetSurface()
    }

    private var accessoryCircle: some View {
        Gauge(value: Double(entry.snapshot.recovery ?? 0), in: 0...100) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text(entry.snapshot.recovery.map(String.init) ?? "--")
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetPalette.recovery)
    }

    private var accessoryRectangle: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text(text("score.recovery.title"))
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
            .font(.caption2)
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(text("score.sleep.title")) \(entry.snapshot.sleep.map(String.init) ?? "--"), \(text("score.load.title")) \(entry.snapshot.strain.map(String.init) ?? "--")"
            )
            Text(entry.snapshot.nextAction)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func miniScore(_ title: String, _ value: Int?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .widgetAccentable()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(1)
        }
    }

    private func metricColumn(_ title: String, _ value: Int?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .widgetAccentable()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HealthEntry

    private var language: AppLanguage { entry.snapshot.displayLanguage }
    private func text(_ key: String) -> String { RecvelL10n.text(key, language: language) }

    private var metrics: [(String, String, String, Color)] {
        [
            ("HRV", entry.snapshot.hrvMilliseconds.map { "\(Int($0.rounded()))" } ?? "--", "waveform.path.ecg", WidgetPalette.recovery),
            ("RHR", entry.snapshot.restingHeartRate.map { "\(Int($0.rounded()))" } ?? "--", "heart", WidgetPalette.heart),
            (text("score.sleep.title"), entry.snapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "--", "moon.fill", WidgetPalette.sleep),
            (text("Pasos"), entry.snapshot.steps.map(compactSteps) ?? "--", "figure.walk", WidgetPalette.cardio),
            ("kcal", entry.snapshot.activeEnergy.map { "\(Int($0.rounded()))" } ?? "--", "bolt.fill", WidgetPalette.energy),
            ("VO₂", entry.snapshot.vo2Max.map { String(format: "%.0f", $0) } ?? "--", "lungs.fill", WidgetPalette.oxygen)
        ]
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangle
        case .systemLarge:
            large
        default:
            medium
        }
    }

    private var accessoryRectangle: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(text("widget.stress")) · \(entry.snapshot.stressLabel)")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(text("score.calm.title")) \(entry.snapshot.stressCalm.map(String.init) ?? "--")")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 8
            ) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    metricCell(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .widgetSurface()
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 10
            ) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    metricCell(metric, large: true)
                }
            }
            Spacer(minLength: 0)
            Text(entry.snapshot.nextAction)
                .font(.caption.weight(.medium))
                .foregroundStyle(WidgetPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .widgetSurface()
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("FISIO")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(WidgetPalette.cardio)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(text("widget.signals"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(entry.snapshot.stressCalm.map(String.init) ?? "--")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(WidgetPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.snapshot.stressLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private func metricCell(_ metric: (String, String, String, Color), large: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: metric.2)
                .font(.system(size: large ? 12 : 11, weight: .semibold))
                .foregroundStyle(metric.3)
                .widgetAccentable()
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(metric.0)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
                Text(metric.1)
                    .font(.system(size: large ? 14 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetPalette.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, large ? 6 : 4)
        .padding(.horizontal, large ? 8 : 5)
        .background(WidgetPalette.backgroundRaised.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactSteps(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return value.formatted(.number.locale(RecvelL10n.locale))
    }
}

private extension View {
    func widgetSurface() -> some View {
        containerBackground(for: .widget) {
            ZStack {
                WidgetPalette.background
                LinearGradient(
                    colors: [WidgetPalette.backgroundRaised, WidgetPalette.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Live Activity helpers

private enum FastingIslandLayout {
    /// Rango estable para timers: evita `Date.now...` (cambia cada render y desborda).
    static func progressRange(start: Date, target: Date) -> ClosedRange<Date> {
        if target > start { return start...target }
        return start...start.addingTimeInterval(1)
    }

    static func countdownRange(target: Date) -> ClosedRange<Date> {
        let now = Date.now
        if target > now { return now...target }
        // Objetivo ya pasado: rango minimo para no crashear ClosedRange.
        return target...target.addingTimeInterval(1)
    }
}

private struct IslandCountdown: View {
    let target: Date
    var font: Font = .caption2.monospacedDigit().weight(.semibold)
    var maxWidth: CGFloat? = nil

    var body: some View {
        Text(timerInterval: FastingIslandLayout.countdownRange(target: target), countsDown: true)
            .font(font)
            .foregroundStyle(WidgetPalette.primaryText)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: maxWidth, alignment: .trailing)
    }
}

/// Anillo que se llena hacia el objetivo (sin cronometro numerico).
private struct IslandProgressRing: View {
    let start: Date
    let target: Date
    var size: CGFloat = 20

    var body: some View {
        ProgressView(
            timerInterval: FastingIslandLayout.progressRange(start: start, target: target),
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(WidgetPalette.recovery)
        .labelsHidden()
        .frame(width: size, height: size)
        .accessibilityLabel(Text("widget.fasting.progress"))
    }
}

struct RecvelReadinessWidget: Widget {
    let kind = "RecvelReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            ReadinessWidgetView(entry: entry)
                .widgetURL(URL(string: "recvel://today"))
        }
        .configurationDisplayName("widget.readiness.name")
        .description("widget.readiness.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct RecvelMetricsWidget: Widget {
    let kind = "RecvelMetricsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            MetricsWidgetView(entry: entry)
                .widgetURL(URL(string: "recvel://today"))
        }
        .configurationDisplayName("widget.metrics.name")
        .description("widget.metrics.description")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct RecvelFastingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecvelFastingAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WidgetPalette.recovery)
                        Text("widget.fasting")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetPalette.primaryText)
                            .lineLimit(1)
                    }
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandCountdown(
                        target: context.attributes.targetDate,
                        font: .caption.monospacedDigit().weight(.semibold),
                        maxWidth: 72
                    )
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.protocolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(
                            timerInterval: FastingIslandLayout.progressRange(
                                start: context.attributes.startDate,
                                target: context.attributes.targetDate
                            ),
                            countsDown: false
                        )
                        .tint(WidgetPalette.recovery)
                        .frame(height: 6)

                        HStack(spacing: 8) {
                            Text(context.state.phaseName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(WidgetPalette.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                            Text(context.state.status)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(WidgetPalette.recovery)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetPalette.recovery)
                    .frame(minWidth: 18, maxWidth: 22)
            } compactTrailing: {
                // Vista contraida: circulo que se llena (sin cronometro que baja).
                IslandProgressRing(
                    start: context.attributes.startDate,
                    target: context.attributes.targetDate,
                    size: 18
                )
            } minimal: {
                IslandProgressRing(
                    start: context.attributes.startDate,
                    target: context.attributes.targetDate,
                    size: 16
                )
            }
            .widgetURL(URL(string: "recvel://fasting"))
            .keylineTint(WidgetPalette.recovery)
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<RecvelFastingAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label {
                    Text(context.attributes.protocolName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetPalette.primaryText)

                Spacer(minLength: 0)

                Text(context.state.status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetPalette.recovery)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProgressView(
                timerInterval: FastingIslandLayout.progressRange(
                    start: context.attributes.startDate,
                    target: context.attributes.targetDate
                ),
                countsDown: false
            )
            .tint(WidgetPalette.recovery)
            .frame(height: 8)

            HStack(spacing: 8) {
                Text(context.attributes.startDate, style: .time)
                    .lineLimit(1)
                Text("→")
                    .foregroundStyle(WidgetPalette.tertiaryText)
                Text(context.attributes.targetDate, style: .time)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(context.state.phaseName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(WidgetPalette.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(WidgetPalette.background)
        .activitySystemActionForegroundColor(WidgetPalette.primaryText)
        .widgetURL(URL(string: "recvel://fasting"))
    }
}

@main
struct RecvelWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecvelReadinessWidget()
        RecvelMetricsWidget()
        RecvelFastingLiveActivity()
    }
}
