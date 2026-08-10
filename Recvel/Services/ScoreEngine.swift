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

        // Temperatura de muñeca DORMIDO frente a la habitual. Apple solo la mide
        // durmiendo, asi que no hay lectura diurna con la que contaminarla.
        //
        // Evidencia: en 47 000 usuarios de Fitbit, una desviacion sostenida por
        // encima de ~0.5 C sobre la linea base personal precedio a enfermedad
        // confirmada en 1-2 dias en cerca del 75 % de los casos (Cell, 2021).
        //
        // Limite reconocido: la temperatura de piel es una salida
        // termorreguladora con muchos confusores (ambiente, ciclo menstrual,
        // alcohol, hora del ejercicio), y las desviaciones sostenidas son mas
        // fiables que las de una sola noche. Por eso entra con peso bajo y solo
        // como señal de contexto, nunca como deteccion de enfermedad.
        let temperatureDeviation = baselineEngine.deviation(
            current: snapshot.wristTemperature,
            values: historyWithoutToday.compactMap(\.wristTemperature),
            lowerIsBetter: true
        )

        let sleep = sleepScore(snapshot.sleepDetails, fallbackHours: snapshot.sleepHours)
        let recoveryFactors: [(Double?, Double)] = [
            (hrvDeviation.map { 62 + $0 * 115 }, 0.31),
            (rhrDeviation.map { 62 + $0 * 120 }, 0.22),
            (snapshot.sleepHours.map { _ in Double(sleep) }, 0.25),
            (respiratoryDeviation.map { 65 + $0 * 70 }, 0.12),
            // Amplificacion x20: en piel las variaciones relativas son diminutas
            // —0.5 C sobre 33 C es apenas 1.5 %— y con un factor menor el efecto
            // quedaba por debajo del redondeo del score, es decir, decorativo.
            // Con x20 y peso 0.10, el umbral de 0.5 C del estudio de Fitbit
            // mueve el score de forma visible pero acotada.
            (temperatureDeviation.map { 62 + min(max($0 * 20, -1), 1) * 60 }, 0.10)
        ]
        let autonomicRecovery = weightedScore(recoveryFactors, fallback: 58)

        // Ajuste por carga de los dias previos. Ver `priorLoadAdjustment`.
        let priorLoad = priorLoadAdjustment(
            history: historyWithoutToday,
            before: snapshot.date,
            hrvDeviation: hrvDeviation,
            rhrDeviation: rhrDeviation
        )
        let sustained = sustainedSuppressionAdjustment(history: historyWithoutToday, before: snapshot.date)
        let recovery = clamp(autonomicRecovery + priorLoad + sustained)

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
                summary: recoverySummary(
                    hrvDeviation: hrvDeviation,
                    rhrDeviation: rhrDeviation,
                    alcoholGrams: snapshot.dietaryAlcoholGrams
                )
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

    /// Penalizacion maxima por supresion sostenida.
    static let maxSustainedSuppressionPenalty = 7.0

    /// Ajuste por HRV sostenidamente por debajo de la linea base.
    ///
    /// **Es informacion que un dia suelto NO contiene.** La lectura de hoy dice
    /// como amaneciste; una racha de dias por debajo dice otra cosa distinta, y
    /// es la señal que la literatura de monitoreo asocia con sobrecarga no
    /// funcional: supresion sostenida (>7 dias bajo linea base) y HRV que no
    /// responde a los dias de descanso.
    ///
    /// Deliberadamente NO se promedia la HRV para el score diario. Promediar da
    /// tendencias mas estables (Plews y Buchheit: las correlaciones con
    /// rendimiento solo aparecen con medias de 3-4 dias), pero **empeora la
    /// clasificacion de respuestas individuales a corto plazo**, que es justo lo
    /// que un score diario tiene que hacer. Asi que el dia manda en el score y
    /// la racha entra por separado, como aqui.
    func sustainedSuppressionAdjustment(history: [DailyHealthSnapshot], before date: Date) -> Int {
        let previous = history
            .filter { $0.date < date }
            .sorted { $0.date > $1.date }
        // Se necesitan al menos 5 dias recientes y una base de 14 para afirmar
        // que hay racha. Con menos, no se afirma nada.
        let recent = Array(previous.prefix(5)).compactMap(\.hrv)
        guard recent.count >= 4 else { return 0 }
        let baselineValues = previous.dropFirst(5).compactMap(\.hrv)
        guard baselineValues.count >= 9, let baseline = baselineEngine.median(baselineEngine.robustValues(baselineValues)),
              baseline > 0 else { return 0 }

        // Cuantos de los dias recientes quedaron claramente por debajo.
        let belowCount = recent.filter { ($0 - baseline) / baseline < -0.05 }.count
        guard belowCount >= 4 else { return 0 }

        let meanRecent = recent.reduce(0, +) / Double(recent.count)
        let drop = min(max((baseline - meanRecent) / baseline, 0) / 0.15, 1)
        return -Int((Self.maxSustainedSuppressionPenalty * drop).rounded())
    }

    /// Ajustes de contexto que el score de Recuperación aplica HOY, con las
    /// mismas entradas que usa `scores(for:history:)`. Existen para que la
    /// pantalla de insights pueda mostrar exactamente lo que se restó, no una
    /// reconstrucción aproximada.
    func recoveryAdjustments(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot]
    ) -> (priorLoad: Int, sustainedSuppression: Int) {
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
        let priorLoad = priorLoadAdjustment(
            history: historyWithoutToday,
            before: snapshot.date,
            hrvDeviation: hrvDeviation,
            rhrDeviation: rhrDeviation
        )
        let sustained = sustainedSuppressionAdjustment(history: historyWithoutToday, before: snapshot.date)
        return (priorLoad, sustained)
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
            ),
            temperatureFactor(for: snapshot, history: history)
        ]
    }

    /// La temperatura de muñeca necesita su propia escala: sobre ~36 °C una
    /// desviación de 0.4 °C es apenas un 1 % relativo, así que el `factor()`
    /// genérico (que normaliza a ±18 %) la dejaría siempre en neutro. Se usa
    /// la misma amplificación ×20 que aplica el score.
    private func temperatureFactor(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot]
    ) -> RecoveryFactor {
        let baseline = baselineEngine.median(history.compactMap(\.wristTemperature))
        let contribution: Double
        if let current = snapshot.wristTemperature, let baseline, baseline > 0 {
            let delta = (current - baseline) / baseline
            // Mas caliente que tu base = en contra (lowerIsBetter).
            contribution = -min(max(delta * 20, -1), 1)
        } else {
            contribution = 0
        }
        return RecoveryFactor(
            name: RecvelL10n.text("Temperatura de muneca"),
            value: snapshot.wristTemperature.map { String(format: "%.1f °C", $0) } ?? RecvelL10n.text("common.noData"),
            baseline: baseline.map {
                RecvelL10n.text("metric.usualValue", values: ["value": String(format: "%.1f °C", $0)])
            },
            contribution: contribution,
            icon: "thermometer.medium"
        )
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
        // Reparto de pesos: la REGULARIDAD sube y la duracion baja.
        //
        // En UK Biobank (60 977 personas, mas de 10 millones de horas de
        // acelerometro) el indice de regularidad del sueño resulto mejor
        // predictor de mortalidad por cualquier causa que la duracion, con un
        // ajuste del modelo superior. Tenerla en 0.15 frente a 0.55 de duracion
        // contradecia esa evidencia.
        //
        // No se iguala del todo por honestidad: aquello mide mortalidad a años,
        // no recuperacion diaria, y extrapolar de uno a otro seria ir mas alla
        // de lo que el estudio sostiene. La duracion sigue pesando mas porque
        // es lo que cambia dia a dia.
        let factors: [(Double?, Double)] = [
            (duration, 0.42),
            (details.consistencyMinutes.map { max(100 - $0 * 0.9, 35) }, 0.28),
            (details.efficiency.map { min($0 / 90, 1.05) * 100 }, 0.20),
            (details.latencyMinutes.map { max(100 - max($0 - 12, 0) * 2.2, 35) }, 0.10)
        ]
        return weightedScore(factors, fallback: duration.map { Int($0) } ?? 50)
    }

    private func confidence(for snapshot: DailyHealthSnapshot, historyCount: Int) -> DataConfidence {
        guard snapshot.availableSignalCount >= 3 else { return .low }
        return baselineEngine.confidence(sampleCount: historyCount)
    }

    /// Resumen de Recovery.
    ///
    /// El alcohol registrado NO resta en el score: su efecto fisiologico ya esta
    /// dentro de la HRV y la FC en reposo de esa misma noche. En 21 000 adultos
    /// con wearable, beber subio la FC nocturna y bajo la HRV de forma
    /// dosis-dependiente (PLOS Digital Health, 2025); un estudio controlado con
    /// smartwatch midio 63.6 -> 66.6 lpm de FC nocturna. Restarlo aparte seria
    /// contar dos veces el mismo fenomeno.
    ///
    /// Lo que si aporta es EXPLICAR una lectura baja. Y se dice como asociacion,
    /// nunca como causa: es un dato que el usuario registro, no una medicion.
    private func recoverySummary(
        hrvDeviation: Double?,
        rhrDeviation: Double?,
        alcoholGrams: Double? = nil
    ) -> String {
        let signalsBelow = (hrvDeviation.map { $0 < -0.06 } ?? false)
            || (rhrDeviation.map { $0 < -0.06 } ?? false)
        // Umbral en una bebida estandar (~14 g), que es la dosis a partir de la
        // cual los estudios ya observan cambio.
        if signalsBelow, let alcoholGrams, alcoholGrams >= 14 {
            return RecvelL10n.text("recovery.summary.alcoholContext")
        }
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
