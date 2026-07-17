import Foundation

struct DetailAdvice: Equatable {
    let eyebrow: String
    let title: String
    let detail: String
    let metric: String
    let metricLabel: String
    let reasons: [String]
}

struct SleepOpportunityPlan: Equatable {
    let windDownStart: Date
    let bedtime: Date
    let wakeTime: Date
    let caffeineCutoff: Date
    let opportunityHours: Double
    let averageSleepHours: Double?
    let gapHours: Double
    let latencyMinutes: Double
}

struct InsightEngine {
    private let baselineEngine = BaselineEngine()

    func briefing(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        scores: [WellnessScore],
        wakeMinutes: Int = 420
    ) -> DailyBrief {
        let recentSleep = history.suffix(7).compactMap(\.sleepHours)
        let averageSleep = recentSleep.isEmpty ? (snapshot.sleepHours ?? 7.5) : recentSleep.reduce(0, +) / Double(recentSleep.count)
        let debt = min(max(8.0 - averageSleep, 0) * 0.65, 1.5)
        let strain = scores.first { $0.kind == .strain }?.value ?? 0
        let recovery = scores.first { $0.kind == .recovery }?.value ?? 50
        let sleepNeed = min(8.0 + debt + (strain > 75 ? 0.25 : 0), 9.75)
        let currentLoad = Double(strain) / 100 * 21
        let targetLoad = 5.5 + Double(recovery) / 100 * 11.5

        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let wake = calendar.date(byAdding: .minute, value: wakeMinutes, to: startOfTomorrow) ?? .now
        // Alinea la cama a N ciclos (~90 min) mas cercanos a la necesidad del motor + buffer tipico para dormirte.
        let cyclePick = SleepCyclePlanner.preferredOption(wakeTime: wake, targetAsleepHours: sleepNeed)

        let focus: (String, String)
        switch recovery {
        case 75...:
            focus = ("Aprovecha la capacidad", "Buen dia para una sesion de calidad. Detente cerca de tu carga objetivo.")
        case 50..<75:
            focus = ("Construye sin vaciarte", "Prioriza volumen moderado y deja margen para recuperar esta noche.")
        default:
            focus = ("Recupera primero", "Movimiento suave, hidratacion y una noche consistente tendran mas valor hoy.")
        }

        return DailyBrief(
            sleepNeedHours: sleepNeed,
            sleepDebtHours: debt,
            bedtime: cyclePick.bedtime,
            currentLoad: currentLoad,
            targetLoad: targetLoad,
            focusTitle: focus.0,
            focusDetail: focus.1,
            suggestedSleepCycles: cyclePick.cycleCount,
            suggestedCycleCaption: cyclePick.caption
        )
    }

    func primaryInsight(from scores: [WellnessScore]) -> String {
        guard let recovery = scores.first(where: { $0.kind == .recovery }) else {
            return "Conecta Apple Health para comenzar tu baseline personal."
        }
        switch recovery.value {
        case 75...: return "Tus senales permiten una carga exigente, siempre que como te sientes coincida con los datos."
        case 50..<75: return "Tu capacidad es intermedia. Acumula carga de forma gradual y protege la ventana de sueno."
        default: return "Tus senales sugieren bajar intensidad. Observa la tendencia y prioriza recuperacion basica."
        }
    }

    func sleepOpportunityPlan(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        wakeMinutes: Int,
        preferredHours: Double,
        now: Date = .now
    ) -> SleepOpportunityPlan {
        let recent = Array(history.sorted { $0.date < $1.date }.suffix(7)).compactMap(\.sleepHours)
        let average = recent.isEmpty ? snapshot.sleepHours : recent.reduce(0, +) / Double(recent.count)
        let minimumGoal = max(preferredHours, 7)
        let gap = max(minimumGoal - (average ?? minimumGoal), 0)
        let opportunity = min(max(minimumGoal + min(gap * 0.5, 1), 7), 9.75)
        let latency = min(max(snapshot.sleepDetails?.latencyMinutes ?? 20, 10), 45)

        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let wake = calendar.date(byAdding: .minute, value: wakeMinutes, to: tomorrow) ?? tomorrow
        // Conserva la oportunidad (deuda/meta); la hora de cama se redondea al ciclo mas cercano.
        let buffer = Int(latency.rounded())
        let cyclePick = SleepCyclePlanner.preferredOption(
            wakeTime: wake,
            targetAsleepHours: opportunity,
            fallAsleepBufferMinutes: buffer
        )

        return SleepOpportunityPlan(
            windDownStart: cyclePick.bedtime.addingTimeInterval(-45 * 60),
            bedtime: cyclePick.bedtime,
            wakeTime: wake,
            caffeineCutoff: cyclePick.bedtime.addingTimeInterval(-6 * 3600),
            opportunityHours: opportunity,
            averageSleepHours: average,
            gapHours: gap,
            latencyMinutes: latency
        )
    }

    func recoveryAdvice(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        recoveryScore: Int,
        strainScore: Int
    ) -> DetailAdvice {
        let prior = history.filter { !Calendar.current.isDate($0.date, inSameDayAs: snapshot.date) }
        let typicalHRV = baselineEngine.median(prior.compactMap(\.hrv))
        let typicalRHR = baselineEngine.median(prior.compactMap(\.restingHeartRate))
        let hrvLow = zip(snapshot.hrv, typicalHRV).map { $0.0 < $0.1 * 0.90 } ?? false
        let rhrHigh = zip(snapshot.restingHeartRate, typicalRHR).map { $0.0 > $0.1 * 1.06 } ?? false
        let shortSleep = (snapshot.sleepHours ?? 8) < 7
        let targetLoad = 5.5 + Double(recoveryScore) / 100 * 11.5

        let reasons = [
            snapshot.sleepHours.map { String(format: "Sueno %.1f h", $0) },
            snapshot.hrv.map { value in typicalHRV.map { "HRV \(Int(value)) vs \(Int($0)) ms" } ?? "HRV \(Int(value)) ms" },
            snapshot.restingHeartRate.map { value in typicalRHR.map { "FC \(Int(value)) vs \(Int($0)) bpm" } ?? "FC \(Int(value)) bpm" }
        ].compactMap { $0 }

        if shortSleep {
            return DetailAdvice(
                eyebrow: "MEJOR PALANCA DE RECOVERY",
                title: "Amplia tu oportunidad de sueno",
                detail: "La duracion fue la senal mas clara para actuar hoy. Conserva una hora de despertar estable y protege una ventana mas larga esta noche.",
                metric: snapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "< 7 h",
                metricLabel: "ultima noche",
                reasons: reasons
            )
        }

        if recoveryScore < 50 || (hrvLow && rhrHigh) {
            return DetailAdvice(
                eyebrow: "MEJOR PALANCA DE RECOVERY",
                title: "Deja margen fisiologico hoy",
                detail: "Mas de una senal se alejo de tu rango. Mantener la intensidad opcional baja y observar la tendencia manana aporta mas que perseguir un score.",
                metric: String(format: "%.1f", targetLoad),
                metricLabel: "tope orientativo /21",
                reasons: reasons
            )
        }

        if strainScore > 78 {
            return DetailAdvice(
                eyebrow: "MEJOR PALANCA DE RECOVERY",
                title: "La carga de hoy ya es suficiente",
                detail: "Tu carga acumulada es alta. El siguiente paso util es proteger comida, hidratacion habitual y la ventana de sueno, no sumar intensidad por completar un numero.",
                metric: "\(strainScore)%",
                metricLabel: "carga relativa",
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: "MEJOR PALANCA DE RECOVERY",
            title: "Mantiene la rutina que funciona",
            detail: "Tus senales estan cerca de su rango. Entrena segun sensaciones, termina cerca de tu objetivo de carga y conserva horarios de sueno regulares.",
            metric: "\(recoveryScore)%",
            metricLabel: "capacidad estimada",
            reasons: reasons
        )
    }

    func strainAdvice(
        strainScore: Int,
        recoveryScore: Int,
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot]
    ) -> DetailAdvice {
        let current = Double(strainScore) / 100 * 21
        let lower = Double(max(recoveryScore - 25, 20)) / 100 * 21
        let upper = Double(min(recoveryScore - 5, 95)) / 100 * 21
        let weeklyMinutes = history.suffix(7).compactMap(\.workoutMinutes).reduce(0, +)
        let highZoneMinutes = snapshot.workouts.flatMap(\.zones)
            .filter { $0.zone >= 4 }
            .reduce(0) { $0 + $1.minutes }
        let reasons = [
            "Recovery \(recoveryScore)%",
            "Semana \(Int(weeklyMinutes)) min",
            highZoneMinutes > 0 ? "Z4-Z5 \(Int(highZoneMinutes)) min" : nil
        ].compactMap { $0 }

        if current > upper {
            return DetailAdvice(
                eyebrow: "SIGUIENTE MEJOR ACCION",
                title: "Objetivo de carga cubierto",
                detail: "No necesitas compensar nada mas hoy. Distribuir la actividad durante la semana suele ser mas util que concentrarla en una sola sesion.",
                metric: String(format: "+%.1f", current - upper),
                metricLabel: "sobre el rango",
                reasons: reasons
            )
        }

        if recoveryScore < 50 {
            return DetailAdvice(
                eyebrow: "SIGUIENTE MEJOR ACCION",
                title: "Prioriza movimiento facil",
                detail: "Tu Recovery reduce el margen recomendado. Si tus sensaciones coinciden, elige actividad conversacional o movilidad y evita usar el objetivo como obligacion.",
                metric: String(format: "%.1f", max(lower - current, 0)),
                metricLabel: "hasta rango bajo",
                reasons: reasons
            )
        }

        if current < lower {
            return DetailAdvice(
                eyebrow: "SIGUIENTE MEJOR ACCION",
                title: "Aun tienes margen de carga",
                detail: "Puedes sumar una sesion gradual si te sientes bien. Mantente dentro del rango y deja que dolor, enfermedad o fatiga percibida tengan prioridad sobre el score.",
                metric: String(format: "%.1f", upper - current),
                metricLabel: "margen hasta el tope",
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: "SIGUIENTE MEJOR ACCION",
            title: "Estas dentro del rango",
            detail: "La carga actual ya coincide con tu capacidad estimada. Mantener o cerrar suave es una decision completa; no hace falta llegar al limite superior.",
            metric: String(format: "%.1f", current),
            metricLabel: "carga actual /21",
            reasons: reasons
        )
    }

    func energyAdvice(score: Int, scores: [WellnessScore], snapshot: DailyHealthSnapshot? = nil) -> DetailAdvice {
        let value: (ScoreKind) -> Int = { kind in scores.first { $0.kind == kind }?.value ?? 0 }
        var reasons = [
            "Recovery \(value(.recovery))%",
            "Sleep \(value(.sleep))%",
            "Strain \(value(.strain))%"
        ]
        // Luz diurna: ya la medimos. La exposicion diurna ancla el ritmo
        // circadiano y se asocia con mejor alerta diurna (Wright et al.,
        // Curr Biol 2013; Figueiro et al.). Solo la citamos cuando hay dato.
        if let daylight = snapshot?.daylightMinutes {
            reasons.append(String(format: "Luz diurna %.0f min", daylight))
        }
        if let caffeine = snapshot?.dietaryCaffeineMg, caffeine > 0 {
            reasons.append(String(format: "Cafeina %.0f mg", caffeine))
        }

        if score < 40 {
            return DetailAdvice(
                eyebrow: "RITMO RECOMENDADO",
                title: "Protege el margen restante",
                detail: daylightHint(
                    lowEnergy: true,
                    daylight: snapshot?.daylightMinutes,
                    fallback: "Reduce esfuerzo opcional intenso y concentra lo importante en menos bloques. La proxima noche y una carga moderada son las palancas que Recvel puede observar."
                ),
                metric: "\(score)%",
                metricLabel: "margen estimado",
                reasons: reasons
            )
        }

        if score < 70 {
            return DetailAdvice(
                eyebrow: "RITMO RECOMENDADO",
                title: "Trabaja a un ritmo sostenible",
                detail: daylightHint(
                    lowEnergy: false,
                    daylight: snapshot?.daylightMinutes,
                    fallback: "Tienes capacidad intermedia. Alterna tareas exigentes con periodos de menor demanda y evita elevar Strain solo porque el dia aun no termina."
                ),
                metric: "\(score)%",
                metricLabel: "margen estimado",
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: "RITMO RECOMENDADO",
            title: "Hay capacidad disponible",
            detail: "Tus senales permiten priorizar una tarea o sesion exigente. Conserva margen hasta el rango de Strain y reevalua si tus sensaciones no coinciden.",
            metric: "\(score)%",
            metricLabel: "margen estimado",
            reasons: reasons
        )
    }

    /// Si la luz diurna del dia es baja frente a un umbral conservador (~30 min),
    /// anade un recordatorio circadiano. No inventamos un deficit: solo
    /// contextualizamos un dato que ya tenemos.
    private func daylightHint(lowEnergy: Bool, daylight: Double?, fallback: String) -> String {
        guard let daylight, daylight < 30 else { return fallback }
        let tip = "Hoy registraste poca luz diurna (\(Int(daylight)) min). Un paseo corto con luz natural suele ayudar a la alerta sin subir tanto la carga."
        return lowEnergy ? "\(fallback) \(tip)" : "\(fallback) \(tip)"
    }
}

private func zip(_ lhs: Double?, _ rhs: Double?) -> (Double, Double)? {
    guard let lhs, let rhs else { return nil }
    return (lhs, rhs)
}
