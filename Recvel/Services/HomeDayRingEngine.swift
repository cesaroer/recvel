import Foundation
import SwiftUI

/// Metrics available as concentric day indicators on Home (max 2 selected).
enum HomeDayRingMetric: String, CaseIterable, Identifiable, Codable {
    case sleep
    case recovery
    case strain
    case stress
    case steps
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .recovery: "Recovery"
        case .strain: "Strain"
        case .stress: "Stress"
        case .steps: "Pasos"
        case .activity: "Actividad"
        }
    }

    var shortTitle: String {
        switch self {
        case .sleep: "Sueno"
        case .recovery: "Recup."
        case .strain: "Strain"
        case .stress: "Stress"
        case .steps: "Pasos"
        case .activity: "Energia"
        }
    }

    var color: Color {
        switch self {
        case .sleep: ScoreKind.sleep.color
        case .recovery: ScoreKind.recovery.color
        case .strain: ScoreKind.strain.color
        case .stress: Color(red: 0.35, green: 0.78, blue: 0.98)
        case .steps: Color(red: 0.45, green: 0.85, blue: 0.55)
        case .activity: ScoreKind.energy.color
        }
    }

    /// Chip order matching Bevel calendar: Strain → Recovery → Sleep → Stress → Energy → Pasos.
    static let chipOrder: [HomeDayRingMetric] = [
        .strain, .recovery, .sleep, .stress, .activity, .steps
    ]

    /// Sleep + Stress: prior product default was Sleep/Stress/Strain; keep the two wellness signals.
    static let defaults: [HomeDayRingMetric] = [.sleep, .stress]
    static let maxSelected = 2
    static let storageKey = "home.ringMetrics"
    static let defaultStorageValue = "sleep,stress"
}

struct HomeDayRingValue: Equatable, Identifiable {
    let metric: HomeDayRingMetric
    /// 0...1 when data exists; `nil` means muted empty track (no invented score).
    let progress: Double?
    /// Display value for legend (e.g. "72", "8.4k"); `nil` when unavailable.
    let displayValue: String?

    var id: String { metric.rawValue }
    var hasData: Bool { progress != nil }
}

enum HomeDayRingEngine {
    static let stepsGoal = 10_000
    static let activityEnergyGoal = 500.0

    /// Parses AppStorage CSV and caps at `maxSelected`, falling back to defaults if empty/invalid.
    /// Old 3-metric selections (e.g. sleep,stress,strain) are trimmed to the first two.
    static func selection(from raw: String) -> [HomeDayRingMetric] {
        let parsed = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .compactMap(HomeDayRingMetric.init(rawValue:))
        return capped(parsed.isEmpty ? HomeDayRingMetric.defaults : parsed)
    }

    static func encode(_ metrics: [HomeDayRingMetric]) -> String {
        capped(metrics).map(\.rawValue).joined(separator: ",")
    }

    /// Rewrites persisted CSV when an older max-3 value is still stored.
    static func migratedStorageValue(from raw: String) -> String {
        encode(selection(from: raw))
    }

    /// Keeps order, drops duplicates, caps at `maxSelected`.
    static func capped(_ metrics: [HomeDayRingMetric]) -> [HomeDayRingMetric] {
        var seen = Set<HomeDayRingMetric>()
        var result: [HomeDayRingMetric] = []
        for metric in metrics {
            guard !seen.contains(metric) else { continue }
            seen.insert(metric)
            result.append(metric)
            if result.count == HomeDayRingMetric.maxSelected { break }
        }
        return result
    }

    /// Toggles a metric in the selection while enforcing the max-2 cap.
    static func toggling(_ metric: HomeDayRingMetric, in current: [HomeDayRingMetric]) -> [HomeDayRingMetric] {
        if current.contains(metric) {
            return current.filter { $0 != metric }
        }
        guard current.count < HomeDayRingMetric.maxSelected else { return current }
        return current + [metric]
    }

    static func ringValues(
        for snapshot: DailyHealthSnapshot?,
        history: [DailyHealthSnapshot],
        selected: [HomeDayRingMetric],
        isToday _: Bool,
        scoreEngine: ScoreEngine = ScoreEngine(),
        stressEngine: StressEngine = StressEngine()
    ) -> [HomeDayRingValue] {
        let metrics = capped(selected.isEmpty ? HomeDayRingMetric.defaults : selected)
        guard let snapshot else {
            return metrics.map { HomeDayRingValue(metric: $0, progress: nil, displayValue: nil) }
        }

        let scores = scoreEngine.scores(for: snapshot, history: history)
        // Stress for today = running/current assessment of today's snapshot;
        // historical days = day-final signals for that snapshot (same `assess` API).
        let stress = stressEngine.assess(snapshot: snapshot, history: history)
        let calmScore = stressEngine.presentation(for: stress).calmScore

        return metrics.map { metric in
            value(
                for: metric,
                snapshot: snapshot,
                scores: scores,
                calmScore: calmScore
            )
        }
    }

    static func progress(fromScore value: Int?) -> Double? {
        guard let value else { return nil }
        return min(max(Double(value) / 100, 0), 1)
    }

    private static func value(
        for metric: HomeDayRingMetric,
        snapshot: DailyHealthSnapshot,
        scores: [WellnessScore],
        calmScore: Int?
    ) -> HomeDayRingValue {
        switch metric {
        case .sleep:
            guard snapshot.sleepHours != nil else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            let score = scores.first { $0.kind == .sleep }?.value
            return HomeDayRingValue(
                metric: metric,
                progress: progress(fromScore: score),
                displayValue: score.map(String.init)
            )
        case .recovery:
            let hasSignal = snapshot.hrv != nil
                || snapshot.restingHeartRate != nil
                || snapshot.sleepHours != nil
                || snapshot.respiratoryRate != nil
            guard hasSignal else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            let score = scores.first { $0.kind == .recovery }?.value
            return HomeDayRingValue(
                metric: metric,
                progress: progress(fromScore: score),
                displayValue: score.map(String.init)
            )
        case .strain:
            let hasLoad = snapshot.activeEnergy != nil
                || snapshot.workoutMinutes != nil
                || !snapshot.workouts.isEmpty
            guard hasLoad else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            let score = scores.first { $0.kind == .strain }?.value
            return HomeDayRingValue(
                metric: metric,
                progress: progress(fromScore: score),
                displayValue: score.map { String(format: "%.1f", Double($0) / 100 * 21) }
            )
        case .stress:
            guard let calmScore else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            return HomeDayRingValue(
                metric: metric,
                progress: progress(fromScore: calmScore),
                displayValue: String(calmScore)
            )
        case .steps:
            guard let steps = snapshot.steps else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            let progress = min(max(Double(steps) / Double(stepsGoal), 0), 1)
            let display: String
            if steps >= 1000 {
                display = String(format: "%.1fk", Double(steps) / 1000)
            } else {
                display = "\(steps)"
            }
            return HomeDayRingValue(metric: metric, progress: progress, displayValue: display)
        case .activity:
            guard let energy = snapshot.activeEnergy else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            let progress = min(max(energy / activityEnergyGoal, 0), 1)
            return HomeDayRingValue(
                metric: metric,
                progress: progress,
                displayValue: "\(Int(energy.rounded()))"
            )
        }
    }
}

/// Concise weekly workout summary for Home (calendar week).
struct HomeWeekWorkoutSummary {
    let sessionCount: Int
    let totalMinutes: Double
    let totalEnergy: Double
    let keySessions: [WorkoutSummary]

    var hasSessions: Bool { sessionCount > 0 }
}

enum HomeWeekWorkoutEngine {
    static func summarize(
        history: [DailyHealthSnapshot],
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        keyLimit: Int = 3
    ) -> HomeWeekWorkoutSummary {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return HomeWeekWorkoutSummary(sessionCount: 0, totalMinutes: 0, totalEnergy: 0, keySessions: [])
        }
        let days = history.filter {
            let start = calendar.startOfDay(for: $0.date)
            return start >= interval.start && start < interval.end
        }
        let workouts = days.flatMap(\.workouts).sorted { $0.startDate > $1.startDate }
        let minutesFromWorkouts = workouts.reduce(0) { $0 + $1.durationMinutes }
        let minutesFromAggregate = days.reduce(0.0) { partial, day in
            // Avoid double-counting when detailed workouts already sum duration.
            day.workouts.isEmpty ? partial + (day.workoutMinutes ?? 0) : partial
        }
        let energy = workouts.compactMap(\.activeEnergy).reduce(0, +)
        let sessionCount: Int
        if workouts.isEmpty {
            sessionCount = days.filter { ($0.workoutMinutes ?? 0) > 0 }.count
        } else {
            sessionCount = workouts.count
        }
        return HomeWeekWorkoutSummary(
            sessionCount: sessionCount,
            totalMinutes: minutesFromWorkouts + minutesFromAggregate,
            totalEnergy: energy,
            keySessions: Array(workouts.prefix(keyLimit))
        )
    }
}
