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
            focus = (text("brief.focus.high.title"), text("brief.focus.high.detail"))
        case 50..<75:
            focus = (text("insight.recovery.moderate.title"), text("insight.recovery.moderate.detail"))
        default:
            focus = (text("brief.focus.low.title"), text("brief.focus.low.detail"))
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
            return text("insight.connectHealth")
        }
        switch recovery.value {
        case 75...: return text("insight.primary.high")
        case 50..<75: return text("insight.primary.moderate")
        default: return text("insight.primary.low")
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
            snapshot.sleepHours.map { text("reason.sleep", ["value": String(format: "%.1f", $0)]) },
            snapshot.hrv.map { value in typicalHRV.map { "HRV \(Int(value)) vs \(Int($0)) ms" } ?? "HRV \(Int(value)) ms" },
            snapshot.restingHeartRate.map { value in typicalRHR.map { "RHR \(Int(value)) vs \(Int($0)) \(RecvelL10n.text("unit.heartRate"))" } ?? "RHR \(Int(value)) \(RecvelL10n.text("unit.heartRate"))" }
        ].compactMap { $0 }

        if shortSleep {
            return DetailAdvice(
                eyebrow: text("advice.recovery.eyebrow"),
                title: text("advice.recovery.sleep.title"),
                detail: text("advice.recovery.sleep.detail"),
                metric: snapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "< 7 h",
                metricLabel: text("advice.metric.lastNight"),
                reasons: reasons
            )
        }

        if recoveryScore < 50 || (hrvLow && rhrHigh) {
            return DetailAdvice(
                eyebrow: text("advice.recovery.eyebrow"),
                title: text("advice.recovery.margin.title"),
                detail: text("advice.recovery.margin.detail"),
                metric: String(format: "%.1f", targetLoad),
                metricLabel: text("advice.metric.guidanceCap"),
                reasons: reasons
            )
        }

        if strainScore > 78 {
            return DetailAdvice(
                eyebrow: text("advice.recovery.eyebrow"),
                title: text("advice.recovery.load.title"),
                detail: text("advice.recovery.load.detail"),
                metric: "\(strainScore)%",
                metricLabel: text("advice.metric.relativeLoad"),
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: text("advice.recovery.eyebrow"),
            title: text("advice.recovery.routine.title"),
            detail: text("advice.recovery.routine.detail"),
            metric: "\(recoveryScore)%",
            metricLabel: text("advice.metric.estimatedCapacity"),
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
            "\(RecvelL10n.text("score.recovery.title")) \(recoveryScore)%",
            text("reason.weekMinutes", ["value": "\(Int(weeklyMinutes))"]),
            highZoneMinutes > 0 ? "Z4-Z5 \(Int(highZoneMinutes)) min" : nil
        ].compactMap { $0 }

        if current > upper {
            return DetailAdvice(
                eyebrow: text("advice.nextAction"),
                title: text("advice.load.covered.title"),
                detail: text("advice.load.covered.detail"),
                metric: String(format: "+%.1f", current - upper),
                metricLabel: text("advice.metric.aboveRange"),
                reasons: reasons
            )
        }

        if recoveryScore < 50 {
            return DetailAdvice(
                eyebrow: text("advice.nextAction"),
                title: text("advice.load.easy.title"),
                detail: text("advice.load.easy.detail"),
                metric: String(format: "%.1f", max(lower - current, 0)),
                metricLabel: text("advice.metric.toLowerRange"),
                reasons: reasons
            )
        }

        if current < lower {
            return DetailAdvice(
                eyebrow: text("advice.nextAction"),
                title: text("advice.load.margin.title"),
                detail: text("advice.load.margin.detail"),
                metric: String(format: "%.1f", upper - current),
                metricLabel: text("advice.metric.toUpperRange"),
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: text("advice.nextAction"),
            title: text("advice.load.inRange.title"),
            detail: text("advice.load.inRange.detail"),
            metric: String(format: "%.1f", current),
            metricLabel: text("advice.metric.currentLoad"),
            reasons: reasons
        )
    }

    func energyAdvice(score: Int, scores: [WellnessScore], snapshot: DailyHealthSnapshot? = nil) -> DetailAdvice {
        let value: (ScoreKind) -> Int = { kind in scores.first { $0.kind == kind }?.value ?? 0 }
        var reasons = [
            "\(RecvelL10n.text("score.recovery.title")) \(value(.recovery))%",
            "\(RecvelL10n.text("score.sleep.title")) \(value(.sleep))%",
            "\(RecvelL10n.text("score.load.title")) \(value(.strain))%"
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
                eyebrow: text("advice.energy.eyebrow"),
                title: text("advice.energy.low.title"),
                detail: daylightHint(
                    lowEnergy: true,
                    daylight: snapshot?.daylightMinutes,
                    fallback: text("advice.energy.low.detail")
                ),
                metric: "\(score)%",
                metricLabel: text("advice.metric.estimatedMargin"),
                reasons: reasons
            )
        }

        if score < 70 {
            return DetailAdvice(
                eyebrow: text("advice.energy.eyebrow"),
                title: text("advice.energy.moderate.title"),
                detail: daylightHint(
                    lowEnergy: false,
                    daylight: snapshot?.daylightMinutes,
                    fallback: text("advice.energy.moderate.detail")
                ),
                metric: "\(score)%",
                metricLabel: text("advice.metric.estimatedMargin"),
                reasons: reasons
            )
        }

        return DetailAdvice(
            eyebrow: text("advice.energy.eyebrow"),
            title: text("advice.energy.high.title"),
            detail: text("advice.energy.high.detail"),
            metric: "\(score)%",
            metricLabel: text("advice.metric.estimatedMargin"),
            reasons: reasons
        )
    }

    /// Si la luz diurna del dia es baja frente a un umbral conservador (~30 min),
    /// anade un recordatorio circadiano. No inventamos un deficit: solo
    /// contextualizamos un dato que ya tenemos.
    private func daylightHint(lowEnergy: Bool, daylight: Double?, fallback: String) -> String {
        guard let daylight, daylight < 30 else { return fallback }
        let tip = text("advice.daylight.low", ["value": "\(Int(daylight))"])
        return lowEnergy ? "\(fallback) \(tip)" : "\(fallback) \(tip)"
    }

    private func text(_ key: String, _ values: [String: String] = [:]) -> String {
        RecvelL10n.text(key, values: values)
    }
}

private func zip(_ lhs: Double?, _ rhs: Double?) -> (Double, Double)? {
    guard let lhs, let rhs else { return nil }
    return (lhs, rhs)
}
