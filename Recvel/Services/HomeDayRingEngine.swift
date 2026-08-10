import Foundation
import SwiftUI

/// Metricas disponibles como indicador del dia en Home.
///
/// Decision de producto (6 ago 2026): UNA sola metrica activa, como el
/// calendario de Bevel (`CalendarAndJournal.mp4`). Antes se permitian dos
/// anillos concentricos; el resultado era ruidoso y ningun competidor lo hace.
/// El almacenamiento sigue siendo CSV para migrar selecciones viejas: se toma
/// la primera.
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
        case .sleep: RecvelL10n.text("score.sleep.title")
        case .recovery: RecvelL10n.text("score.recovery.title")
        case .strain: RecvelL10n.text("score.load.title")
        case .stress: RecvelL10n.text("score.stress.title")
        case .steps: RecvelL10n.text("metric.steps")
        case .activity: RecvelL10n.text("metric.activity")
        }
    }

    var shortTitle: String {
        switch self {
        case .sleep: RecvelL10n.text("score.sleep.title")
        case .recovery: RecvelL10n.text("score.recovery.short")
        case .strain: RecvelL10n.text("score.load.title")
        case .stress: RecvelL10n.text("score.stress.short")
        case .steps: RecvelL10n.text("metric.steps")
        case .activity: RecvelL10n.text("score.energy.title")
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

    /// Recuperacion: el hero de la app; en Bevel el tab por defecto es Strain,
    /// pero aqui la metrica central del producto es Recovery.
    static let defaults: [HomeDayRingMetric] = [.recovery]
    static let maxSelected = 1
    static let storageKey = "home.ringMetrics"
    static let defaultStorageValue = "recovery"
}

struct HomeDayRingValue: Equatable, Identifiable {
    let metric: HomeDayRingMetric
    /// 0...1 when data exists; `nil` means muted empty track (no invented score).
    let progress: Double?
    /// Display value for legend (e.g. "72", "8.4k"); `nil` when unavailable.
    let displayValue: String?
    /// Color del anillo para ESTE dia. En Bevel el color codifica la banda del
    /// valor (estres tenso amarillo, calmado turquesa), no solo la metrica.
    let bandColor: Color

    var id: String { metric.rawValue }
    var hasData: Bool { progress != nil }

    init(metric: HomeDayRingMetric, progress: Double?, displayValue: String?, bandColor: Color? = nil) {
        self.metric = metric
        self.progress = progress
        self.displayValue = displayValue
        self.bandColor = bandColor ?? metric.color
    }
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

    /// Seleccion unica estilo Bevel: tocar otra metrica la sustituye; tocar la
    /// activa no la apaga (siempre hay exactamente una).
    static func toggling(_ metric: HomeDayRingMetric, in current: [HomeDayRingMetric]) -> [HomeDayRingMetric] {
        [metric]
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
        let stressScore = stressEngine.presentation(for: stress).score

        return metrics.map { metric in
            value(
                for: metric,
                snapshot: snapshot,
                scores: scores,
                stressScore: stressScore
            )
        }
    }

    static func progress(fromScore value: Int?) -> Double? {
        guard let value else { return nil }
        return min(max(Double(value) / 100, 0), 1)
    }

    /// Banda por valor, calcada de las zonas de Bevel (0-33 / 34-66 / 67+)
    /// para las metricas tipo score. Verde = bien, ambar = medio, naranja =
    /// atencion. Carga, pasos y energia conservan el color de la metrica: son
    /// cantidades, no juicios.
    static func bandColor(for metric: HomeDayRingMetric, score: Int?) -> Color {
        guard let score else { return metric.color }
        switch metric {
        case .recovery, .sleep:
            if score >= 67 { return metric == .recovery ? ScoreKind.recovery.color : metric.color }
            if score >= 34 { return ScoreKind.energy.color }
            return ScoreKind.strain.color
        case .stress:
            // Estres directo: BAJO es bueno (turquesa calma), alto es carga.
            if score <= 33 { return metric.color }
            if score <= 66 { return ScoreKind.energy.color }
            return ScoreKind.strain.color
        case .strain, .steps, .activity:
            return metric.color
        }
    }

    private static func value(
        for metric: HomeDayRingMetric,
        snapshot: DailyHealthSnapshot,
        scores: [WellnessScore],
        stressScore: Int?
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
                displayValue: score.map(String.init),
                bandColor: bandColor(for: metric, score: score)
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
                displayValue: score.map(String.init),
                bandColor: bandColor(for: metric, score: score)
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
            guard let stressScore else {
                return HomeDayRingValue(metric: metric, progress: nil, displayValue: nil)
            }
            return HomeDayRingValue(
                metric: metric,
                progress: progress(fromScore: stressScore),
                displayValue: String(stressScore),
                bandColor: bandColor(for: metric, score: stressScore)
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
