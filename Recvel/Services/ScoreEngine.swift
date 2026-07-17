import Foundation

struct ScoreEngine {
    private let baselineEngine = BaselineEngine()

    func scores(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot] = []
    ) -> [WellnessScore] {
        let historyWithoutToday = history.filter { !Calendar.current.isDate($0.date, inSameDayAs: snapshot.date) }
        let hrvDeviation = baselineEngine.deviation(
            current: snapshot.hrv,
            values: historyWithoutToday.compactMap(\.hrv)
        )
        let rhrDeviation = baselineEngine.deviation(
            current: snapshot.restingHeartRate,
            values: historyWithoutToday.compactMap(\.restingHeartRate),
            lowerIsBetter: true
        )
        let respiratoryDeviation = baselineEngine.deviation(
            current: snapshot.respiratoryRate,
            values: historyWithoutToday.compactMap(\.respiratoryRate),
            lowerIsBetter: true
        )

        let sleep = sleepScore(snapshot.sleepDetails, fallbackHours: snapshot.sleepHours)
        let recoveryFactors: [(Double?, Double)] = [
            (hrvDeviation.map { 62 + $0 * 115 }, 0.34),
            (rhrDeviation.map { 62 + $0 * 120 }, 0.24),
            (snapshot.sleepHours.map { _ in Double(sleep) }, 0.28),
            (respiratoryDeviation.map { 65 + $0 * 70 }, 0.14)
        ]
        let recovery = weightedScore(recoveryFactors, fallback: 58)

        let sleepHours = snapshot.sleepHours

        let energyBaseline = baselineEngine.median(historyWithoutToday.compactMap(\.activeEnergy)) ?? 650
        let activeRatio = (snapshot.activeEnergy ?? 0) / max(energyBaseline, 1)
        let workoutLoad = min((snapshot.workoutMinutes ?? 0) / 75, 1)
        let cardiovascularLoad = snapshot.workouts.reduce(0) { $0 + $1.cardiovascularLoad }
        let zoneLoad = cardiovascularLoad > 0 ? min(cardiovascularLoad / 12, 1) : workoutLoad
        let strain = clamp(Int((activeRatio * 68) + (zoneLoad * 32)))
        let energy = clamp(Int(Double(recovery) * 0.68 + Double(sleep) * 0.42 - Double(strain) * 0.18))

        let confidence = confidence(for: snapshot, historyCount: historyWithoutToday.count)
        return [
            WellnessScore(
                kind: .recovery,
                value: recovery,
                confidence: confidence,
                summary: recoverySummary(hrvDeviation: hrvDeviation, rhrDeviation: rhrDeviation)
            ),
            WellnessScore(
                kind: .strain,
                value: strain,
                confidence: confidence,
                summary: "Carga acumulada de actividad y workouts"
            ),
            WellnessScore(
                kind: .sleep,
                value: sleep,
                confidence: sleepHours == nil ? .low : confidence,
                summary: sleepHours.map { String(format: "%.1f h de sueno registradas", $0) } ?? "Sin sueno disponible"
            ),
            WellnessScore(
                kind: .energy,
                value: energy,
                confidence: confidence,
                summary: "Balance entre recuperacion, sueno y carga"
            )
        ]
    }

    func factors(for snapshot: DailyHealthSnapshot, history: [DailyHealthSnapshot]) -> [RecoveryFactor] {
        let baselineHRV = baselineEngine.median(history.compactMap(\.hrv))
        let baselineRHR = baselineEngine.median(history.compactMap(\.restingHeartRate))
        let baselineRespiratory = baselineEngine.median(history.compactMap(\.respiratoryRate))

        return [
            factor(
                name: "Variabilidad cardiaca",
                current: snapshot.hrv,
                baseline: baselineHRV,
                unit: "ms",
                icon: "waveform.path.ecg",
                lowerIsBetter: false
            ),
            factor(
                name: "FC en reposo",
                current: snapshot.restingHeartRate,
                baseline: baselineRHR,
                unit: "bpm",
                icon: "heart.fill",
                lowerIsBetter: true
            ),
            factor(
                name: "Sueno",
                current: snapshot.sleepHours,
                baseline: 8,
                unit: "h",
                icon: "moon.fill",
                lowerIsBetter: false
            ),
            factor(
                name: "Respiracion",
                current: snapshot.respiratoryRate,
                baseline: baselineRespiratory,
                unit: "rpm",
                icon: "lungs.fill",
                lowerIsBetter: true
            )
        ]
    }

    private func factor(
        name: String,
        current: Double?,
        baseline: Double?,
        unit: String,
        icon: String,
        lowerIsBetter: Bool
    ) -> RecoveryFactor {
        let contribution: Double
        if let current, let baseline, baseline > 0 {
            let delta = (current - baseline) / baseline
            contribution = min(max(lowerIsBetter ? -delta : delta, -0.18), 0.18) / 0.18
        } else {
            contribution = 0
        }
        return RecoveryFactor(
            name: name,
            value: current.map { format($0, unit: unit) } ?? "Sin dato",
            baseline: baseline.map { "Tipico \(format($0, unit: unit))" },
            contribution: contribution,
            icon: icon
        )
    }

    private func format(_ value: Double, unit: String) -> String {
        unit == "h" ? String(format: "%.1f %@", value, unit) : "\(Int(value.rounded())) \(unit)"
    }

    private func weightedScore(_ factors: [(Double?, Double)], fallback: Int) -> Int {
        let available = factors.compactMap { value, weight in value.map { ($0, weight) } }
        let totalWeight = available.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return fallback }
        let value = available.reduce(0) { $0 + $1.0 * $1.1 } / totalWeight
        return clamp(Int(value.rounded()))
    }

    private func sleepScore(_ details: SleepSummary?, fallbackHours: Double?) -> Int {
        let duration = fallbackHours.map { min($0 / 8.0, 1.05) * 100 }
        guard let details else { return duration.map { clamp(Int($0)) } ?? 50 }
        let factors: [(Double?, Double)] = [
            (duration, 0.55),
            (details.efficiency.map { min($0 / 90, 1.05) * 100 }, 0.20),
            (details.consistencyMinutes.map { max(100 - $0 * 0.9, 35) }, 0.15),
            (details.latencyMinutes.map { max(100 - max($0 - 12, 0) * 2.2, 35) }, 0.10)
        ]
        return weightedScore(factors, fallback: duration.map { Int($0) } ?? 50)
    }

    private func confidence(for snapshot: DailyHealthSnapshot, historyCount: Int) -> DataConfidence {
        guard snapshot.availableSignalCount >= 3 else { return .low }
        return baselineEngine.confidence(sampleCount: historyCount)
    }

    private func recoverySummary(hrvDeviation: Double?, rhrDeviation: Double?) -> String {
        if let hrvDeviation, hrvDeviation > 0.06 { return "HRV por encima de tu rango habitual" }
        if let rhrDeviation, rhrDeviation < -0.06 { return "FC en reposo por encima de lo habitual" }
        if hrvDeviation == nil && rhrDeviation == nil { return "Construyendo tu baseline personal" }
        return "Senales cercanas a tu rango personal"
    }

    private func clamp(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }
}

struct TrainingLoadEngine {
    func zones(
        observations: [HeartRateObservation],
        estimatedMaximumHeartRate: Double
    ) -> [HeartRateZoneDuration] {
        guard !observations.isEmpty, estimatedMaximumHeartRate > 0 else { return [] }
        let sorted = observations.sorted { $0.date < $1.date }
        var seconds = Array(repeating: 0.0, count: 5)

        for index in sorted.indices {
            let nextDate = index < sorted.index(before: sorted.endIndex)
                ? sorted[sorted.index(after: index)].date
                : sorted[index].date.addingTimeInterval(5)
            let duration = min(max(nextDate.timeIntervalSince(sorted[index].date), 1), 30)
            let ratio = sorted[index].beatsPerMinute / estimatedMaximumHeartRate
            let zone: Int
            switch ratio {
            case ..<0.60: zone = 1
            case ..<0.70: zone = 2
            case ..<0.80: zone = 3
            case ..<0.90: zone = 4
            default: zone = 5
            }
            seconds[zone - 1] += duration
        }

        return seconds.enumerated().map {
            HeartRateZoneDuration(zone: $0.offset + 1, minutes: $0.element / 60)
        }
    }

    func cardiovascularLoad(zones: [HeartRateZoneDuration]) -> Double {
        zones.reduce(0) { result, zone in
            result + zone.minutes * Double(zone.zone)
        } / 10
    }
}
