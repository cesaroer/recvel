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
        let autonomicRecovery = weightedScore(recoveryFactors, fallback: 58)

        // Ajuste por carga de los dias previos. Ver `priorLoadAdjustment`.
        let priorLoad = priorLoadAdjustment(
            history: historyWithoutToday,
            before: snapshot.date,
            hrvDeviation: hrvDeviation,
            rhrDeviation: rhrDeviation
        )
        let recovery = clamp(autonomicRecovery + priorLoad)

        let sleepHours = snapshot.sleepHours

        let energyBaseline = baselineEngine.median(historyWithoutToday.compactMap(\.activeEnergy)) ?? 650
        let activeRatio = (snapshot.activeEnergy ?? 0) / max(energyBaseline, 1)
        let workoutLoad = min((snapshot.workoutMinutes ?? 0) / 75, 1)
        let cardiovascularLoad = snapshot.workouts.reduce(0) { $0 + $1.cardiovascularLoad }
        let baseZoneLoad = cardiovascularLoad > 0 ? min(cardiovascularLoad / 12, 1) : workoutLoad
        // Input opcional ponderado: si algún workout trae esfuerzo de Apple
        // Health (HKWorkoutEffortScore), lo mezclamos ligeramente con la carga
        // por zonas de FC. Peso modesto (30%) para no dejar que una señal
        // estimada domine sobre la medida. Sin esfuerzo, no cambia nada.
        let effortScores = snapshot.workouts.compactMap(\.effortScore)
        let zoneLoad: Double
        if let maxEffort = effortScores.max() {
            let effortLoad = min(maxEffort / 10, 1)
            zoneLoad = baseZoneLoad * 0.7 + effortLoad * 0.3
        } else {
            zoneLoad = baseZoneLoad
        }
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
                summary: RecvelL10n.text("score.load.summary")
            ),
            WellnessScore(
                kind: .sleep,
                value: sleep,
                confidence: sleepHours == nil ? .low : confidence,
                summary: sleepHours.map {
                    RecvelL10n.text("score.sleep.summary", values: ["hours": String(format: "%.1f", $0)])
                } ?? RecvelL10n.text("score.sleep.unavailable")
            ),
            WellnessScore(
                kind: .energy,
                value: energy,
                confidence: confidence,
                summary: RecvelL10n.text("score.energy.summary")
            )
        ]
    }

    // MARK: - Carga previa

    /// Penalizacion maxima por carga previa. Deliberadamente pequeña: ver abajo.
    static let maxPriorLoadPenalty = 9.0

    /// Ajuste de Recovery por lo entrenado en los dias anteriores.
    ///
    /// **Por que es modesto y no una resta directa de la carga.** HRV y FC en
    /// reposo YA reflejan el costo del entrenamiento de ayer: es exactamente lo
    /// que se mide en jugadores de rugby a las 20 h de una sesion intensa (FC en
    /// reposo d = 2.1, p = 0.02; HRV ln SDNN y ln rMSSD d = 0.7 — Academy Rugby
    /// Union, n = 10, PMC6026827). Restar la carga completa encima de esas
    /// desviaciones contaria dos veces el mismo fenomeno.
    ///
    /// **Por que entonces existe.** En ese mismo estudio la sensibilidad
    /// individual fue limitada: solo 4/6 mostraron FC en reposo elevada y 2/6
    /// HRV reducida pese al efecto de grupo. O sea, una carga alta puede NO
    /// aparecer en las señales autonomicas de una persona concreta. Este ajuste
    /// cubre justo ese hueco, y por eso **se atenua cuando las señales ya
    /// registraron el golpe**: si la HRV ya cayo, no hace falta insistir.
    ///
    /// **Por que NO se usa acute:chronic workload ratio (ACWR).** Tiene
    /// acoplamiento matematico (la carga aguda esta contenida en la cronica) y
    /// un ensayo controlado aleatorizado de 2021 con 482 futbolistas juveniles
    /// de elite no encontro ninguna diferencia en lesiones al planificar con el.
    /// Ademas el proyecto prohibe hablar de riesgo de lesion, que es el marco en
    /// el que ACWR siempre se presenta.
    ///
    /// La ventana es de 3 dias con peso decreciente, coherente con supresiones
    /// de HRV descritas de 24-72 h segun intensidad.
    func priorLoadAdjustment(
        history: [DailyHealthSnapshot],
        before date: Date,
        hrvDeviation: Double?,
        rhrDeviation: Double?
    ) -> Int {
        let calendar = Calendar.current
        let previousDays = history
            .filter { $0.date < date }
            .sorted { $0.date > $1.date }
            .prefix(3)
        guard !previousDays.isEmpty else { return 0 }

        // Peso decreciente: ayer pesa el doble que anteayer.
        let weights = [1.0, 0.55, 0.3]
        var weighted = 0.0
        var totalWeight = 0.0
        for (index, day) in previousDays.enumerated() {
            guard let load = dayLoad(day, history: history) else { continue }
            let daysBack = max(calendar.dateComponents([.day], from: day.date, to: date).day ?? index + 1, 1)
            guard daysBack <= 3 else { continue }
            let weight = weights[min(daysBack - 1, weights.count - 1)]
            weighted += load * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0 }

        // 0 = carga habitual o menor; 1 = muy por encima de lo habitual.
        let excess = min(max((weighted / totalWeight) - 0.6, 0) / 0.4, 1)
        guard excess > 0 else { return 0 }

        // Cuanto de ese golpe YA se ve en las señales. Con las dos desviaciones
        // claramente negativas, el ajuste desaparece: seria contar doble.
        let hrvDrop = hrvDeviation.map { min(max(-$0, 0), 1) } ?? 0
        let rhrDrop = rhrDeviation.map { min(max(-$0, 0), 1) } ?? 0
        let alreadyVisible = min((hrvDrop + rhrDrop) / 1.2, 1)

        let penalty = Self.maxPriorLoadPenalty * excess * (1 - alreadyVisible)
        return -Int(penalty.rounded())
    }

    /// Carga de un dia, normalizada 0-1 contra la energia activa habitual.
    /// Reusa la misma señal que alimenta el score de Carga.
    private func dayLoad(_ day: DailyHealthSnapshot, history: [DailyHealthSnapshot]) -> Double? {
        let baseline = baselineEngine.median(history.compactMap(\.activeEnergy)) ?? 650
        let energyRatio = (day.activeEnergy ?? 0) / max(baseline, 1)
        let zoneLoad = day.workouts.reduce(0) { $0 + $1.cardiovascularLoad }
        let minutes = (day.workoutMinutes ?? 0) / 75
        let workout = zoneLoad > 0 ? min(zoneLoad / 12, 1) : min(minutes, 1)
        guard day.activeEnergy != nil || day.workoutMinutes != nil || zoneLoad > 0 else { return nil }
        return min(energyRatio * 0.6 + workout * 0.6, 1.6)
    }

    func factors(for snapshot: DailyHealthSnapshot, history: [DailyHealthSnapshot]) -> [RecoveryFactor] {
        let baselineHRV = baselineEngine.median(history.compactMap(\.hrv))
        let baselineRHR = baselineEngine.median(history.compactMap(\.restingHeartRate))
        let baselineRespiratory = baselineEngine.median(history.compactMap(\.respiratoryRate))

        return [
            factor(
                name: RecvelL10n.text("term.hrv.name"),
                current: snapshot.hrv,
                baseline: baselineHRV,
                unit: "ms",
                icon: "waveform.path.ecg",
                lowerIsBetter: false
            ),
            factor(
                name: RecvelL10n.text("term.rhr.name"),
                current: snapshot.restingHeartRate,
                baseline: baselineRHR,
                unit: RecvelL10n.text("unit.heartRate"),
                icon: "heart.fill",
                lowerIsBetter: true
            ),
            factor(
                name: RecvelL10n.text("score.sleep.title"),
                current: snapshot.sleepHours,
                baseline: 8,
                unit: "h",
                icon: "moon.fill",
                lowerIsBetter: false
            ),
            factor(
                name: RecvelL10n.text("metric.respiration"),
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
            value: current.map { format($0, unit: unit) } ?? RecvelL10n.text("common.noData"),
            baseline: baseline.map {
                RecvelL10n.text("metric.usualValue", values: ["value": format($0, unit: unit)])
            },
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
        if let hrvDeviation, hrvDeviation > 0.06 { return RecvelL10n.text("recovery.summary.hrvAbove") }
        if let rhrDeviation, rhrDeviation < -0.06 { return RecvelL10n.text("recovery.summary.rhrAbove") }
        if hrvDeviation == nil && rhrDeviation == nil { return RecvelL10n.text("recovery.summary.building") }
        return RecvelL10n.text("recovery.summary.usual")
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
