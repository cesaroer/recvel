import XCTest
@testable import Recvel

final class EngineTests: XCTestCase {
    func testBaselineRejectsLargeOutlier() throws {
        let engine = BaselineEngine()
        let values = [49.0, 50, 51, 52, 500]

        XCTAssertEqual(engine.median(values), 51)
        XCTAssertEqual(engine.robustValues(values), [49, 50, 51, 52])
        let deviation = try XCTUnwrap(engine.deviation(current: 56, values: values))
        XCTAssertEqual(deviation, 56 / 50.5 - 1, accuracy: 0.0001)
    }

    func testPersonalBandHandlesNegativeMedianWithoutCrashing() throws {
        let engine = BaselineEngine()

        XCTAssertNil(engine.personalBand([1, 2]))
        XCTAssertNil(engine.personalBand([.nan, .infinity, 1]))

        let negativeBand = try XCTUnwrap(engine.personalBand([-5, -4, -3, -2, -1]))
        XCTAssertLessThanOrEqual(negativeBand.lowerBound, negativeBand.upperBound)
        XCTAssertGreaterThanOrEqual(negativeBand.lowerBound, 0)
        XCTAssertGreaterThanOrEqual(negativeBand.upperBound, 0)

        let nearZeroBand = try XCTUnwrap(engine.personalBand([-0.2, -0.1, 0, 0.05, 0.1]))
        XCTAssertLessThanOrEqual(nearZeroBand.lowerBound, nearZeroBand.upperBound)
        XCTAssertEqual(nearZeroBand.lowerBound, 0, accuracy: 0.0001)

        let positiveBand = try XCTUnwrap(engine.personalBand([48, 50, 51, 52, 54]))
        XCTAssertLessThan(positiveBand.lowerBound, positiveBand.upperBound)
        XCTAssertGreaterThan(positiveBand.lowerBound, 0)
    }

    func testScoresAreDeterministicWithCompleteData() {
        let engine = ScoreEngine()
        let scoresA = engine.scores(for: .demo, history: DailyHealthSnapshot.demoWeek)
        let scoresB = engine.scores(for: .demo, history: DailyHealthSnapshot.demoWeek)

        XCTAssertEqual(scoresA.map(\.value), scoresB.map(\.value))
        XCTAssertEqual(scoresA.count, ScoreKind.allCases.count)
        XCTAssertTrue(scoresA.allSatisfy { 0...100 ~= $0.value })
        XCTAssertTrue(scoresA.allSatisfy { $0.confidence == .low || $0.confidence == .medium })
    }

    func testMissingSignalsNeverInventHighConfidence() {
        let scores = ScoreEngine().scores(for: .empty)

        XCTAssertEqual(scores.first { $0.kind == .strain }?.value, 0)
        XCTAssertEqual(scores.first { $0.kind == .sleep }?.confidence, .low)
        XCTAssertTrue(scores.allSatisfy { $0.confidence == .low })
    }

    func testStressBandsUsePersonalHRVAndRestingHeartRateBaseline() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let history = (1...21).map { offset in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -offset, to: now)!,
                hrv: 50,
                restingHeartRate: 55,
                sleepHours: 7.5,
                activeEnergy: 500,
                steps: 8_000,
                respiratoryRate: 14,
                workoutMinutes: 30
            )
        }
        let overloaded = DailyHealthSnapshot(
            date: now,
            hrv: 35,
            restingHeartRate: 70,
            sleepHours: 6,
            activeEnergy: 400,
            steps: 4_000,
            respiratoryRate: 15,
            workoutMinutes: nil
        )
        let great = DailyHealthSnapshot(
            date: now,
            hrv: 65,
            restingHeartRate: 45,
            sleepHours: 8,
            activeEnergy: 500,
            steps: 8_000,
            respiratoryRate: 14,
            workoutMinutes: 30
        )

        let engine = StressEngine()
        let high = engine.assess(snapshot: overloaded, history: history)
        let low = engine.assess(snapshot: great, history: history)

        XCTAssertEqual(high.level, .overload)
        XCTAssertEqual(high.confidence, .high)
        XCTAssertEqual(low.level, .great)
        XCTAssertLessThan(low.score ?? 100, high.score ?? 0)
    }

    func testStressRequiresPersonalHistoryAndNeverInventsScore() {
        let result = StressEngine().assess(snapshot: .demo, history: [])

        XCTAssertNil(result.score)
        XCTAssertEqual(result.level, .unavailable)
        XCTAssertEqual(result.confidence, .low)
    }

    // MARK: - Presentacion del stress (calm score)

    func testStressPresentationInvertsIndexToCalmScore() {
        let engine = StressEngine()

        let relaxed = StressAssessment(score: 10, level: .great, confidence: .high, summary: "", drivers: [], baselineDays: 21)
        let strained = StressAssessment(score: 85, level: .overload, confidence: .high, summary: "", drivers: [], baselineDays: 21)
        let unavailable = StressAssessment(score: nil, level: .unavailable, confidence: .low, summary: "", drivers: [], baselineDays: 0)

        let relaxedPresentation = engine.presentation(for: relaxed)
        let strainedPresentation = engine.presentation(for: strained)
        let unavailablePresentation = engine.presentation(for: unavailable)

        // "Excelente" debe acercarse a 100, no a 0 (pedido explicito del usuario).
        XCTAssertEqual(relaxedPresentation.calmScore, 90)
        XCTAssertEqual(relaxedPresentation.displayValue, "90")
        XCTAssertEqual(relaxedPresentation.headline, "Excelente")
        XCTAssertEqual(strainedPresentation.calmScore, 15)
        XCTAssertGreaterThan(relaxedPresentation.ringProgress, strainedPresentation.ringProgress)

        XCTAssertNil(unavailablePresentation.calmScore)
        XCTAssertEqual(unavailablePresentation.displayValue, "--")
        XCTAssertEqual(unavailablePresentation.ringProgress, 0)
    }

    func testStressBarIntensityThresholds() {
        let engine = StressEngine()
        XCTAssertEqual(engine.barIntensity(0.5), .low)
        XCTAssertEqual(engine.barIntensity(0.8), .medium)
        XCTAssertEqual(engine.barIntensity(1.0), .medium)
        XCTAssertEqual(engine.barIntensity(1.8), .high)
        XCTAssertEqual(engine.barIntensity(2.5), .high)
    }

    // MARK: - Hints de posibles factores

    private func stressHintsFixture(
        habitsToday: [String] = [],
        habitsYesterday: [String] = [],
        emotionToday: StressEmotion? = nil,
        sleepHours: Double? = 7.5,
        hrvImpact: Double = 0
    ) -> [StressHint] {
        let assessment = StressAssessment(
            score: 50,
            level: .normal,
            confidence: .medium,
            summary: "",
            drivers: [StressDriver(name: "HRV (SDNN)", value: "45 ms", baseline: "Tipico 50 ms", impact: hrvImpact)],
            baselineDays: 10
        )
        let snapshot = DailyHealthSnapshot(
            date: .now,
            hrv: 45,
            restingHeartRate: 55,
            sleepHours: sleepHours,
            activeEnergy: 400,
            steps: 6_000,
            respiratoryRate: 14,
            workoutMinutes: 20
        )
        return StressEngine().stressHints(
            assessment: assessment,
            snapshot: snapshot,
            habitsToday: habitsToday,
            habitsYesterday: habitsYesterday,
            emotionToday: emotionToday
        )
    }

    func testStressHintsFlagAlcoholWhenHRVLow() {
        let hints = stressHintsFixture(habitsYesterday: ["Alcohol"], hrvImpact: -0.1)
        let alcohol = hints.first { $0.id == "alcohol" }
        XCTAssertNotNil(alcohol)
        XCTAssertEqual(alcohol?.kind, .habit)
        XCTAssertTrue(alcohol?.text.contains("por debajo de tu rango") ?? false, "Con HRV baja el hint debe mencionar la senal")
    }

    func testStressHintsReflectSelfReportedEmotionWithoutInference() {
        // Con emocion tensa auto-reportada: hint gentil que ofrece respiracion.
        let withEmotion = stressHintsFixture(emotionToday: .worried)
        let emotionHint = withEmotion.first { $0.kind == .emotion }
        XCTAssertNotNil(emotionHint)
        XCTAssertTrue(emotionHint?.offersBreathing ?? false)
        XCTAssertTrue(emotionHint?.text.contains("Registraste") ?? false, "Debe ser user-reported, no inferido")

        // Sin registro del usuario: JAMAS inferir emociones desde HRV.
        let withoutEmotion = stressHintsFixture(hrvImpact: -0.3)
        XCTAssertFalse(withoutEmotion.contains { $0.kind == .emotion })

        // Emocion positiva no genera hint de tension.
        let calmEmotion = stressHintsFixture(emotionToday: .calm)
        XCTAssertFalse(calmEmotion.contains { $0.kind == .emotion })
    }

    func testEmotionDayAdviceUsesAverageNotHRV() {
        let engine = StressEngine()
        let tense = engine.emotionDayAdvice(emotions: [.anxious, .worried, .irritable])
        XCTAssertEqual(tense?.kind, .emotion)
        XCTAssertTrue(tense?.offersBreathing ?? false)
        XCTAssertTrue(tense?.text.contains("promedio") ?? false)

        let positive = engine.emotionDayAdvice(emotions: [.calm, .content, .motivated])
        XCTAssertEqual(positive?.kind, .positive)
        XCTAssertTrue(positive?.text.contains("positivo") ?? false)

        XCTAssertNil(engine.emotionDayAdvice(emotions: []))
        guard let avg = StressEngine.averageEmotionValence([.calm, .anxious]) else {
            return XCTFail("Expected average valence")
        }
        XCTAssertEqual(avg, 0, accuracy: 0.01)
    }

    func testEmotionDayCapConstantIsSix() {
        XCTAssertEqual(CheckInLimits.maxPerDay, 6)
    }

    func testFastingFeelingAdviceSuggestsEndingForDizzyOrHeadache() {
        let engine = StressEngine()
        let dizzy = engine.fastingFeelingAdvice(moods: [.great, .dizzy])
        XCTAssertNotNil(dizzy)
        XCTAssertTrue(dizzy?.suggestsEnding ?? false)
        XCTAssertTrue(dizzy?.detail.localizedCaseInsensitiveContains("hidrat") ?? false)

        let repeatedTired = engine.fastingFeelingAdvice(moods: [.tired, .irritable])
        XCTAssertTrue(repeatedTired?.suggestsEnding ?? false)

        let good = engine.fastingFeelingAdvice(moods: [.great, .energized])
        XCTAssertFalse(good?.suggestsEnding ?? true)
        XCTAssertNil(engine.fastingFeelingAdvice(moods: []))
    }

    func testStressHintsPraiseMeditation() {
        let hints = stressHintsFixture(habitsToday: ["Meditacion"])
        XCTAssertTrue(hints.contains { $0.kind == .positive })
    }

    func testStressHintsMatchHabitNameVariants() {
        // JournalView guarda "Cafeina por la tarde"; otras vistas "Cafeina tarde".
        let variantA = stressHintsFixture(habitsToday: ["Cafeina por la tarde"])
        let variantB = stressHintsFixture(habitsToday: ["Cafeina tarde"])
        XCTAssertTrue(variantA.contains { $0.id == "caffeine" })
        XCTAssertTrue(variantB.contains { $0.id == "caffeine" })
    }

    func testStressHintsEmptyWhenNoSignals() {
        XCTAssertTrue(stressHintsFixture().isEmpty)
    }

    func testBioAgeBetaMapsVO2ToPublishedCardiorespiratoryReference() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1981, month: 7, day: 14)))
        let snapshot = DailyHealthSnapshot(
            date: now,
            hrv: 55,
            restingHeartRate: 54,
            sleepHours: 7.5,
            activeEnergy: 500,
            steps: 8_000,
            respiratoryRate: 14,
            workoutMinutes: 30,
            vo2Max: 46.5,
            vo2MaxDate: now
        )

        let estimate = BioAgeEngine().estimate(
            birthDate: birthDate,
            sex: .male,
            snapshot: snapshot,
            history: [snapshot],
            now: now
        )

        XCTAssertEqual(estimate.chronologicalYears, 45)
        // VO2 46.5 cae entre las medianas FRIEND treadmill de 30-39 (42.4) y
        // 20-29 (48.0), asi que la edad equivalente debe quedar en ese tramo.
        // Antes de julio 2026 la tabla estaba sesgada hacia abajo y devolvia 20
        // (el tope), lo que producia un delta absurdo de -25 anos.
        let years = try XCTUnwrap(estimate.estimatedYears)
        XCTAssertGreaterThan(years, 25, "46.5 no alcanza la mediana de un 20-29 (48.0)")
        XCTAssertLessThan(years, 35, "46.5 supera la mediana de un 30-39 (42.4)")
        XCTAssertEqual(years, 27.68, accuracy: 0.05)
        XCTAssertEqual(estimate.confidence, .low, "Una sola estimacion no debe producir confianza alta")
    }

    func testBioAgeReferenceMatchesPublishedFriendMedians() {
        // Guardia contra regresiones: si estas medianas cambian, alguien edito
        // la tabla FRIEND. Fuente: Kaminsky et al., Mayo Clin Proc 2015
        // (treadmill, tabla completa verificada en PMC4919021).
        let engine = BioAgeEngine()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now

        // Un hombre cuyo VO2 iguala la mediana de su decada debe recibir la
        // edad central de esa decada.
        for (age, median) in [(25, 48.0), (35, 42.4), (45, 37.8), (55, 32.6), (65, 28.2), (75, 24.4)] {
            guard let birth = calendar.date(byAdding: .year, value: -age, to: now) else { continue }
            let snapshot = DailyHealthSnapshot(
                date: now, hrv: 55, restingHeartRate: 54, sleepHours: 7.5,
                activeEnergy: 500, steps: 8_000, respiratoryRate: 14,
                workoutMinutes: 30, vo2Max: median, vo2MaxDate: now
            )
            let estimate = engine.estimate(birthDate: birth, sex: .male, snapshot: snapshot, history: [snapshot], now: now)
            XCTAssertEqual(
                estimate.estimatedYears ?? 0, Double(age), accuracy: 0.5,
                "VO2 \(median) es la mediana FRIEND de \(age) anos"
            )
        }
    }

    func testBioAgeBetaDoesNotGuessWithoutReferenceSex() {
        let estimate = BioAgeEngine().estimate(
            birthDate: Calendar.current.date(byAdding: .year, value: -40, to: .now),
            sex: .unspecified,
            snapshot: .demo,
            history: DailyHealthSnapshot.demoWeek
        )

        XCTAssertNil(estimate.estimatedYears)
        XCTAssertEqual(estimate.confidence, .low)
    }

    func testHeartRateSamplesProduceFiveWeightedZones() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = [100.0, 130, 150, 170, 190].enumerated().map { index, bpm in
            HeartRateObservation(date: start.addingTimeInterval(Double(index * 30)), beatsPerMinute: bpm)
        }
        let engine = TrainingLoadEngine()
        let zones = engine.zones(observations: samples, estimatedMaximumHeartRate: 200)

        XCTAssertEqual(zones.map(\.zone), [1, 2, 3, 4, 5])
        XCTAssertEqual(zones[0].minutes, 0.5, accuracy: 0.001)
        XCTAssertEqual(zones[4].minutes, 5.0 / 60.0, accuracy: 0.001)
        XCTAssertGreaterThan(engine.cardiovascularLoad(zones: zones), 0)
    }

    func testBriefingConvertsRecentSleepDeficitIntoUsefulTarget() {
        let calendar = Calendar(identifier: .gregorian)
        let history = (1...7).map { day in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -day, to: .now) ?? .now,
                hrv: 50,
                restingHeartRate: 55,
                sleepHours: 6,
                activeEnergy: 500,
                steps: 7_000,
                respiratoryRate: 14,
                workoutMinutes: 30
            )
        }
        let scores = ScoreEngine().scores(for: .demo, history: history)
        let brief = InsightEngine().briefing(snapshot: .demo, history: history, scores: scores)

        XCTAssertEqual(brief.sleepDebtHours, 1.3, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(brief.sleepNeedHours, 9.3)
        XCTAssertGreaterThan(brief.targetLoad, 5.5)
        XCTAssertEqual(brief.suggestedSleepCycles, 6)
        XCTAssertTrue(brief.suggestedCycleCaption.contains("6 ciclos"))
    }

    func testSleepCyclePlannerIsDeterministicAndPrefersNearestNeed() {
        let calendar = Calendar(identifier: .gregorian)
        let wake = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 7, minute: 0))!

        let five = SleepCyclePlanner.option(wakeTime: wake, cycles: 5)
        XCTAssertEqual(five.asleepHours, 7.5, accuracy: 0.0001)
        XCTAssertEqual(five.bedtime, wake.addingTimeInterval(-(7.5 * 3600 + 15 * 60)))
        XCTAssertEqual(five.caption, "5 ciclos · ~7.5 h + 15 min para dormirte")

        let nearEight = SleepCyclePlanner.preferredOption(wakeTime: wake, targetAsleepHours: 8.0)
        XCTAssertEqual(nearEight.cycleCount, 5)

        let nearNine = SleepCyclePlanner.preferredOption(wakeTime: wake, targetAsleepHours: 9.2)
        XCTAssertEqual(nearNine.cycleCount, 6)

        let tieBreak = SleepCyclePlanner.preferredOption(wakeTime: wake, targetAsleepHours: 8.25)
        XCTAssertEqual(tieBreak.cycleCount, 6)

        let again = SleepCyclePlanner.preferredOption(wakeTime: wake, targetAsleepHours: 8.25)
        XCTAssertEqual(again, tieBreak)
    }

    func testSleepOpportunityTurnsRecentGapIntoConcreteTimes() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 12))!
        let history = (1...7).map { day in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -day, to: now)!,
                hrv: 50,
                restingHeartRate: 55,
                sleepHours: 6.5,
                activeEnergy: 500,
                steps: 7_000,
                respiratoryRate: 14,
                workoutMinutes: 30
            )
        }

        let plan = InsightEngine().sleepOpportunityPlan(
            snapshot: .demo,
            history: history,
            wakeMinutes: 7 * 60,
            preferredHours: 8,
            now: now
        )

        XCTAssertGreaterThan(plan.opportunityHours, 8)
        XCTAssertLessThan(plan.bedtime, plan.wakeTime)
        XCTAssertLessThan(plan.windDownStart, plan.bedtime)
        XCTAssertEqual(plan.bedtime.timeIntervalSince(plan.caffeineCutoff), 6 * 3600, accuracy: 1)
    }

    func testSleepWindDownSchedulerBuildsSoftDailySlotsWithoutSpam() {
        let calendar = Calendar(identifier: .gregorian)
        let bedtime = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 0))!

        let defaultSlots = SleepWindDownScheduler.reminderSlots(bedtime: bedtime)
        XCTAssertEqual(defaultSlots.count, 3)
        XCTAssertEqual(defaultSlots.map(\.kind), [.routineStart, .inBed, .lightsOut])
        XCTAssertEqual(
            defaultSlots[0].fireDate,
            bedtime.addingTimeInterval(-45 * 60)
        )
        XCTAssertEqual(defaultSlots[1].fireDate, bedtime)
        XCTAssertEqual(
            defaultSlots[2].fireDate,
            bedtime.addingTimeInterval(8 * 60)
        )

        let withRoutine = SleepWindDownScheduler.reminderSlots(
            bedtime: bedtime,
            routineOffsetsBeforeBed: [30, 60]
        )
        XCTAssertEqual(withRoutine.first?.kind, .routineStart)
        XCTAssertEqual(
            withRoutine.first?.fireDate,
            bedtime.addingTimeInterval(-60 * 60)
        )

        let tight = SleepWindDownScheduler.reminderSlots(
            bedtime: bedtime,
            routineOffsetsBeforeBed: [10],
            windDownMinutes: 10,
            lightsOutDelayMinutes: 5,
            minGapMinutes: 20
        )
        XCTAssertLessThanOrEqual(tight.count, 2)
        XCTAssertTrue(tight.contains { $0.kind == .lightsOut || $0.kind == .inBed })

        XCTAssertEqual(
            SleepWindDownScheduler.stepFireDate(bedtime: bedtime, minutesBeforeBed: 30),
            bedtime.addingTimeInterval(-30 * 60)
        )
        XCTAssertEqual(SleepWindDownScheduler.minutesOfDay(from: bedtime, calendar: calendar), 23 * 60)
    }

    func testSleepWindDownSchedulerChainsRoutineStepsBackwardsFromBedtime() {
        let calendar = Calendar(identifier: .gregorian)
        let bedtime = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 0))!

        // Estiramientos 15 + respiracion 15 → 30 y 15 min antes (no colisionan).
        let two = SleepWindDownScheduler.chainedOffsetsBeforeBed(durationsInOrder: [15, 15])
        XCTAssertEqual(two, [30, 15])
        XCTAssertEqual(
            SleepWindDownScheduler.stepFireDate(bedtime: bedtime, minutesBeforeBed: two[0]),
            bedtime.addingTimeInterval(-30 * 60)
        )
        XCTAssertEqual(
            SleepWindDownScheduler.stepFireDate(bedtime: bedtime, minutesBeforeBed: two[1]),
            bedtime.addingTimeInterval(-15 * 60)
        )

        // Tres pasos: no comparten el mismo offset.
        let three = SleepWindDownScheduler.chainedOffsetsBeforeBed(durationsInOrder: [15, 15, 10])
        XCTAssertEqual(three, [40, 25, 10])
        XCTAssertEqual(Set(three).count, 3)

        // Presets tipicos estiramientos + respiracion.
        let stretch = SleepWindDownScheduler.presets.first { $0.id == "stretch" }!
        let breathe = SleepWindDownScheduler.presets.first { $0.id == "breathe" }!
        XCTAssertEqual(stretch.durationMinutes, 15)
        XCTAssertEqual(breathe.durationMinutes, 15)
        let stacked = SleepWindDownScheduler.chainedOffsetsBeforeBed(
            durationsInOrder: [stretch.durationMinutes, breathe.durationMinutes]
        )
        XCTAssertEqual(stacked, [30, 15])

        // El aviso de rutina usa el inicio de la cadena (30), no ambos a 15.
        let slots = SleepWindDownScheduler.reminderSlots(
            bedtime: bedtime,
            routineDurationsInOrder: [15, 15]
        )
        XCTAssertEqual(slots.first?.kind, .routineStart)
        XCTAssertEqual(slots.first?.fireDate, bedtime.addingTimeInterval(-45 * 60))
        // Con wind-down default 45 > 30, el slot de rutina queda en -45;
        // los pasos individuales siguen en -30 y -15.
        XCTAssertEqual(SleepWindDownScheduler.earliestOffsetBeforeBed(durationsInOrder: [15, 15]), 30)

        let longRoutine = SleepWindDownScheduler.reminderSlots(
            bedtime: bedtime,
            routineDurationsInOrder: [20, 20, 20]
        )
        XCTAssertEqual(
            longRoutine.first?.fireDate,
            bedtime.addingTimeInterval(-60 * 60)
        )
    }

    func testRecoveryAdviceSelectsSleepAsActionableWeakSignal() {
        let shortNight = DailyHealthSnapshot(
            date: .now,
            hrv: 52,
            restingHeartRate: 56,
            sleepHours: 6.2,
            activeEnergy: 450,
            steps: 6_500,
            respiratoryRate: 14,
            workoutMinutes: 25
        )

        let advice = InsightEngine().recoveryAdvice(
            snapshot: shortNight,
            history: DailyHealthSnapshot.demoWeek,
            recoveryScore: 44,
            strainScore: 62
        )

        XCTAssertTrue(advice.title.contains("sueno"))
        XCTAssertEqual(advice.metric, "6.2 h")
        XCTAssertFalse(advice.reasons.isEmpty)
    }

    @MainActor
    func testNutritionTargetsAreDeterministicForProfile() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 12)))
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1996, month: 7, day: 13)))
        let profile = NutritionProfile(
            birthDate: birthDate,
            heightCm: 170,
            weightKg: 70,
            sexOptional: NutritionSex.unspecified.rawValue,
            goal: NutritionGoal.maintain.rawValue,
            weeklyWorkouts: WeeklyWorkoutRange.medium.rawValue,
            setupCompleted: true
        )

        let targets = NutritionPlanEngine().targets(for: profile, now: now)

        XCTAssertEqual(targets.calories, 2_300)
        XCTAssertEqual(targets.calorieLower, 2_180)
        XCTAssertEqual(targets.calorieUpper, 2_420)
        XCTAssertEqual(targets.protein, 112)
        XCTAssertEqual(targets.carbohydrates, 337)
        XCTAssertEqual(targets.fat, 56)
    }

    @MainActor
    func testTomorrowPlanChangesWhenProteinGapIsResolved() throws {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let profile = NutritionProfile(setupCompleted: true)
        let engine = NutritionPlanEngine()
        let emptyPlan = engine.plan(for: profile, meals: [], context: .empty, now: now)
        let proteinMeal = MealLog(
            createdAt: now,
            title: "Comida alta en proteina",
            calories: 900,
            protein: 140,
            carbohydrates: 80,
            fat: 30
        )
        let filledPlan = engine.plan(for: profile, meals: [proteinMeal], context: .empty, now: now)

        XCTAssertTrue(emptyPlan.tomorrowReason.contains("proteina"))
        XCTAssertNotEqual(emptyPlan.tomorrowReason, filledPlan.tomorrowReason)
        XCTAssertEqual(filledPlan.tomorrow.count, 3)
    }

    @MainActor
    func testHighStrainChangesNextMealTowardCarbohydrateAndProtein() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let profile = NutritionProfile(setupCompleted: true)
        let meal = MealLog(
            createdAt: now,
            title: "Proteina sin carbohidratos",
            calories: 800,
            protein: 130,
            carbohydrates: 0,
            fat: 30
        )
        let engine = NutritionPlanEngine()
        let normal = engine.plan(for: profile, meals: [meal], context: .empty, now: now)
        let highStrain = engine.plan(
            for: profile,
            meals: [meal],
            context: NutritionHealthContext(recovery: 70, sleep: 75, strain: 82, plannedWorkout: true),
            now: now
        )

        XCTAssertNotEqual(normal.nextMeal.title, highStrain.nextMeal.title)
        XCTAssertTrue(highStrain.nextMeal.title.contains("Carbohidrato"))
    }

    func testExperimentalNutritionAPIModeDefaultsToOff() {
        XCTAssertFalse(NutritionFeatureFlags.experimentalAPIEnabledByDefault)
    }

    // MARK: - Fitness

    @MainActor
    func testFitnessBuildsThirtyDayWindowAndMergesManualActivity() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 12)))
        let snapshot = DailyHealthSnapshot(
            date: now,
            hrv: 55,
            restingHeartRate: 54,
            sleepHours: 7.5,
            activeEnergy: 500,
            steps: 8_000,
            respiratoryRate: 14,
            workoutMinutes: 30
        )
        let manual = FitnessActivityLog(
            startDate: now,
            activityName: "Fuerza",
            category: "Fuerza",
            durationMinutes: 45,
            perceivedEffort: 7,
            totalVolumeKg: 3_200,
            muscleGroup: "Piernas"
        )

        let points = FitnessEngine().points(history: [snapshot], manualActivities: [manual], now: now)

        XCTAssertEqual(points.count, 30)
        let today = try XCTUnwrap(points.last)
        XCTAssertEqual(today.minutes, 75, accuracy: 0.001)
        XCTAssertEqual(today.activityCount, 2)
        XCTAssertGreaterThan(today.cardiovascularLoad, 10)
        XCTAssertGreaterThan(today.strain, 0)
    }

    func testFitnessFocusAndHeartRateRecoveryUseMeasuredWorkoutSignals() {
        let engine = FitnessEngine()
        let focus = engine.focus(history: [.demo])

        XCTAssertEqual(focus.lowAerobic, 17, accuracy: 0.001)
        XCTAssertEqual(focus.highAerobic, 30, accuracy: 0.001)
        XCTAssertEqual(focus.anaerobic, 5, accuracy: 0.001)
        XCTAssertEqual(focus.primaryLabel, "Aerobico alto")
        XCTAssertEqual(engine.latestHeartRateRecovery(history: [.demo]), 31)
    }

    @MainActor
    func testWorkoutTemplateCountsOnlyNonemptyExerciseLines() {
        let template = WorkoutTemplate(
            name: "Full body",
            focus: "Fuerza general",
            exercisesText: "Sentadilla\n\n Press banca \nPeso muerto"
        )

        XCTAssertEqual(template.exerciseCount, 3)
    }

    // MARK: - Ayuno intermitente

    func testFastingPhaseBoundariesMatchDocumentedRanges() {
        let engine = FastingEngine()
        XCTAssertEqual(engine.currentPhase(elapsedHours: 0).name, "Digestion")
        XCTAssertEqual(engine.currentPhase(elapsedHours: 3.9).name, "Digestion")
        XCTAssertEqual(engine.currentPhase(elapsedHours: 4).name, "Uso de glucogeno")
        XCTAssertEqual(engine.currentPhase(elapsedHours: 12).name, "Transicion a grasa")
        XCTAssertEqual(engine.currentPhase(elapsedHours: 18).name, "Glucogeno hepatico bajo")
        XCTAssertEqual(engine.currentPhase(elapsedHours: 30).name, "Autofagia (evidencia limitada)")
    }

    func testFastingAutophagyPhaseKeepsHedgedLanguage() {
        // Regla de producto (Calorie_AI_Research.md 12.4): nunca afirmar autofagia como hecho.
        let engine = FastingEngine()
        let phase = engine.currentPhase(elapsedHours: 26)
        XCTAssertTrue(phase.detail.lowercased().contains("evidencia"))
        XCTAssertTrue(phase.detail.lowercased().contains("no es concluyente"))
    }

    func testFastingProgressClampsToOne() {
        let engine = FastingEngine()
        XCTAssertEqual(engine.progress(elapsedHours: 8, targetHours: 16), 0.5, accuracy: 0.0001)
        XCTAssertEqual(engine.progress(elapsedHours: 20, targetHours: 16), 1.0)
        XCTAssertEqual(engine.progress(elapsedHours: 5, targetHours: 0), 0)
    }

    func testFastingSafetyBlocksDocumentedContraindications() {
        // Contraindicaciones duras: Calorie_AI_Research.md 12.2.
        let engine = FastingEngine()
        var answers = FastingSafetyAnswers()
        answers.under18 = true
        answers.pregnantOrNursing = true
        guard case .blocked(let reasons) = engine.safetyResult(answers) else {
            return XCTFail("Debe bloquear ante contraindicaciones duras")
        }
        XCTAssertEqual(reasons.count, 2)
    }

    func testFastingSafetyCautionForOlderAdultOrMedication() {
        let engine = FastingEngine()
        var answers = FastingSafetyAnswers()
        answers.olderAdultOrHeartConditionOrMedication = true
        guard case .caution = engine.safetyResult(answers) else {
            return XCTFail("Debe advertir, no bloquear, para adulto mayor/medicamentos")
        }
    }

    func testFastingSafetyClearWhenNoRiskFlags() {
        let engine = FastingEngine()
        XCTAssertEqual(engine.safetyResult(FastingSafetyAnswers()), .clear)
    }

    func testFastingStatsSummarizeCompletedSessions() {
        let engine = FastingEngine()
        let calendar = Calendar.current
        let now = Date.now
        let completed: [(start: Date, hours: Double)] = [
            (calendar.date(byAdding: .day, value: -1, to: now)!, 16),
            (calendar.date(byAdding: .day, value: -3, to: now)!, 14),
            (calendar.date(byAdding: .day, value: -20, to: now)!, 20)
        ]
        let stats = engine.stats(completed: completed, now: now)
        XCTAssertEqual(stats.totalCompleted, 3)
        XCTAssertEqual(stats.thisWeekCount, 2, "Solo los ayunos de los ultimos 7 dias cuentan para la semana")
        XCTAssertEqual(stats.averageHours, (16 + 14 + 20) / 3, accuracy: 0.001)
        XCTAssertEqual(stats.longestHours, 20)
    }

    func testFastingStatsEmptyStateIsZeroNotInvented() {
        let stats = FastingEngine().stats(completed: [])
        XCTAssertEqual(stats.totalCompleted, 0)
        XCTAssertEqual(stats.averageHours, 0)
        XCTAssertEqual(stats.longestHours, 0)
    }

    func testFastingDailyHoursAttributesToStartDay() {
        let engine = FastingEngine()
        let calendar = Calendar.current
        let now = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let data = engine.dailyFastingHours(
            sessions: [(yesterday, 16), (yesterday, 2)],
            days: 7,
            now: now
        )
        XCTAssertEqual(data.count, 7)
        let yesterdayEntry = data.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        XCTAssertEqual(yesterdayEntry?.hours ?? 0, 18, accuracy: 0.001, "Dos ayunos del mismo dia se suman")
        XCTAssertEqual(data.last.map { calendar.isDateInToday($0.date) }, true, "El ultimo punto debe ser hoy")
    }

    func testFastingRecoveryImpactRequiresMinimumSamples() {
        let engine = FastingEngine()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: -offset, to: today)! }
        func overnightFast(endingOn offset: Int) -> (start: Date, end: Date) {
            // 20:00 del dia anterior a 12:00 del dia (16 h, cubre las 3:00)
            let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day(offset))!
            return (end.addingTimeInterval(-16 * 3600), end)
        }

        // Solo 2 dias con ayuno: insuficiente, delta nil.
        let insufficient = engine.recoveryImpact(
            fasts: [overnightFast(endingOn: 1), overnightFast(endingOn: 2)],
            recoveryByDay: (1...6).map { (day($0), 70) }
        )
        XCTAssertNil(insufficient.delta)

        // 3 dias con ayuno (recovery 80) vs 3 sin (recovery 60): delta +20.
        let fasts = [overnightFast(endingOn: 1), overnightFast(endingOn: 2), overnightFast(endingOn: 3)]
        let records: [(date: Date, recovery: Int)] =
            (1...3).map { (day($0), 80) } + (4...6).map { (day($0), 60) }
        let impact = engine.recoveryImpact(fasts: fasts, recoveryByDay: records)
        XCTAssertEqual(impact.delta ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(impact.fastingDays, 3)
        XCTAssertEqual(impact.otherDays, 3)
    }

    func testFastingRecoveryImpactIgnoresShortFasts() {
        let engine = FastingEngine()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
        // Ayuno de solo 6 h: no califica (minimo 14 h).
        let impact = engine.recoveryImpact(
            fasts: [(end.addingTimeInterval(-6 * 3600), end)],
            recoveryByDay: [(today, 80)]
        )
        XCTAssertEqual(impact.fastingDays, 0, "Un ayuno corto no debe contar como dia de ayuno")
    }

    func testFastingContextualTipIsDeterministicPerMinute() {
        let engine = FastingEngine()
        let moment = Date(timeIntervalSince1970: 1_700_000_000)
        let first = engine.contextualTip(isActive: true, hasCompletedSessions: false, elapsedHours: 5, now: moment)
        let second = engine.contextualTip(isActive: true, hasCompletedSessions: false, elapsedHours: 5, now: moment)
        XCTAssertEqual(first, second, "El tip no debe ser aleatorio dentro del mismo minuto")
    }

    func testFastingElapsedHoursUsesEndDateWhenFinished() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = FastingSession(
            startDate: start,
            endDate: start.addingTimeInterval(16 * 3600),
            protocolRaw: FastingProtocol.sixteen8.rawValue,
            targetHours: 16
        )
        XCTAssertEqual(session.elapsedHours(), 16, accuracy: 0.001)
        XCTAssertFalse(session.isActive)
    }

    func testMentalCalendarStatesAndStreakSkipOpenToday() {
        XCTAssertEqual(MentalJournalEngine.state(morning: false, evening: false), .none)
        XCTAssertEqual(MentalJournalEngine.state(morning: true, evening: false), .partial)
        XCTAssertEqual(MentalJournalEngine.state(morning: true, evening: true), .complete)

        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        XCTAssertEqual(
            MentalJournalEngine.completionStreak(
                completedDays: [yesterday, twoDaysAgo],
                now: now,
                calendar: calendar
            ),
            2
        )
    }

    func testJournalAssociationRequiresFiveYesAndFiveNo() {
        let insufficient = JournalImpactEngine.association(
            pairs: Array(repeating: (true, 80), count: 5) + Array(repeating: (false, 60), count: 4)
        )
        XCTAssertNil(insufficient.delta)
        let ready = JournalImpactEngine.association(
            pairs: Array(repeating: (true, 80), count: 5) + Array(repeating: (false, 60), count: 5)
        )
        XCTAssertEqual(ready.delta, 20)
    }

    func testSleepDisciplineDistinguishesNoDataFromMissed() {
        let planned = Date(timeIntervalSince1970: 1_784_000_000)
        let noData = SleepDisciplineEngine.evaluate(
            nightDate: planned,
            plannedBedtime: planned,
            plannedWakeTime: planned.addingTimeInterval(8 * 3600),
            targetAsleepHours: 7.5,
            actualSleepStart: nil,
            actualSleepEnd: nil,
            actualAsleepHours: nil
        )
        XCTAssertEqual(noData.status, .noData)
        XCTAssertNil(noData.points)

        let missed = SleepDisciplineEngine.evaluate(
            nightDate: planned,
            plannedBedtime: planned,
            plannedWakeTime: planned.addingTimeInterval(8 * 3600),
            targetAsleepHours: 7.5,
            actualSleepStart: planned.addingTimeInterval(95 * 60),
            actualSleepEnd: planned.addingTimeInterval(8 * 3600),
            actualAsleepHours: 6.2
        )
        XCTAssertEqual(missed.status, .missed)
        XCTAssertNotNil(missed.points)
    }

    func testSleepDisciplineNeedsFiveMeasuredNightsForScore() {
        let planned = Date(timeIntervalSince1970: 1_784_000_000)
        let night = SleepDisciplineEngine.evaluate(
            nightDate: planned,
            plannedBedtime: planned,
            plannedWakeTime: planned.addingTimeInterval(8 * 3600),
            targetAsleepHours: 7.5,
            actualSleepStart: planned.addingTimeInterval(10 * 60),
            actualSleepEnd: planned.addingTimeInterval(8 * 3600),
            actualAsleepHours: 7.5
        )
        XCTAssertNil(SleepDisciplineEngine.summary(Array(repeating: night, count: 4)).score)
        XCTAssertEqual(SleepDisciplineEngine.summary(Array(repeating: night, count: 5)).score, 100)
    }

    // MARK: - Home day rings

    func testHomeRingSelectionDefaultsAndCapsAtTwo() {
        XCTAssertEqual(
            HomeDayRingEngine.selection(from: ""),
            HomeDayRingMetric.defaults
        )
        XCTAssertEqual(HomeDayRingMetric.defaults, [.sleep, .stress])
        XCTAssertEqual(HomeDayRingMetric.maxSelected, 2)

        // Legacy max-3 AppStorage values trim to the first two.
        let legacy = HomeDayRingEngine.selection(from: "sleep,stress,strain")
        XCTAssertEqual(legacy, [.sleep, .stress])
        XCTAssertEqual(
            HomeDayRingEngine.migratedStorageValue(from: "sleep,stress,strain"),
            "sleep,stress"
        )

        let capped = HomeDayRingEngine.selection(from: "sleep,recovery,strain,stress,steps")
        XCTAssertEqual(capped.count, HomeDayRingMetric.maxSelected)
        XCTAssertEqual(capped, [.sleep, .recovery])

        let encoded = HomeDayRingEngine.encode([.steps, .activity, .sleep, .recovery])
        XCTAssertEqual(encoded, "steps,activity")
    }

    func testHomeRingToggleEnforcesMaxTwo() {
        var selected: [HomeDayRingMetric] = [.sleep, .stress]
        XCTAssertEqual(HomeDayRingEngine.toggling(.recovery, in: selected), selected)

        selected = HomeDayRingEngine.toggling(.stress, in: selected)
        XCTAssertEqual(selected, [.sleep])

        selected = HomeDayRingEngine.toggling(.recovery, in: selected)
        XCTAssertEqual(selected, [.sleep, .recovery])
    }

    func testHomeRingMissingDataProducesMutedProgress() {
        let empty = DailyHealthSnapshot.empty
        let values = HomeDayRingEngine.ringValues(
            for: empty,
            history: [],
            selected: [.sleep, .stress, .strain, .steps, .activity],
            isToday: true
        )
        XCTAssertTrue(values.allSatisfy { $0.progress == nil })
        XCTAssertEqual(values.count, 2, "Selection must stay capped at 2")
    }

    func testHomeRingUsesScoresWhenSignalsExist() {
        let values = HomeDayRingEngine.ringValues(
            for: .demo,
            history: DailyHealthSnapshot.demoWeek,
            selected: [.sleep, .strain, .steps],
            isToday: true
        )
        XCTAssertEqual(values.count, 2)
        XCTAssertNotNil(values[0].progress)
        XCTAssertNotNil(values[1].progress)
        XCTAssertEqual(values[0].metric, .sleep)
        XCTAssertEqual(values[1].metric, .strain)
    }

    func testHomeRingStressTodayUsesCurrentAssessmentVsHistorical() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let history: [DailyHealthSnapshot] = (3...10).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyHealthSnapshot(
                date: date,
                hrv: 55,
                restingHeartRate: 52,
                sleepHours: 7.2,
                activeEnergy: 500,
                steps: 7000,
                respiratoryRate: 14,
                workoutMinutes: 20
            )
        }

        let calmToday = DailyHealthSnapshot(
            date: today,
            hrv: 70,
            restingHeartRate: 48,
            sleepHours: 8,
            activeEnergy: 400,
            steps: 5000,
            respiratoryRate: 13,
            workoutMinutes: 10
        )
        let strainedYesterday = DailyHealthSnapshot(
            date: yesterday,
            hrv: 35,
            restingHeartRate: 62,
            sleepHours: 5.5,
            activeEnergy: 900,
            steps: 12_000,
            respiratoryRate: 16,
            workoutMinutes: 80
        )

        let fullHistory = history + [strainedYesterday, calmToday]
        let todayRings = HomeDayRingEngine.ringValues(
            for: calmToday,
            history: fullHistory,
            selected: [.stress],
            isToday: true
        )
        let yesterdayRings = HomeDayRingEngine.ringValues(
            for: strainedYesterday,
            history: fullHistory,
            selected: [.stress],
            isToday: false
        )

        XCTAssertNotNil(todayRings.first?.progress)
        XCTAssertNotNil(yesterdayRings.first?.progress)
        // Calm today should present a higher calm-score progress than a strained past day.
        XCTAssertGreaterThan(todayRings[0].progress ?? 0, yesterdayRings[0].progress ?? 1)
    }

    func testHomeWeekWorkoutSummaryCountsCalendarWeekSessions() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let monday = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: now)?.start)

        func workout(on dayOffset: Int, hour: Int, minutes: Double, name: String) -> WorkoutSummary {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
            let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
            return WorkoutSummary(
                id: UUID(),
                startDate: start,
                endDate: start.addingTimeInterval(minutes * 60),
                activityName: name,
                durationMinutes: minutes,
                activeEnergy: minutes * 8,
                averageHeartRate: 140,
                maximumHeartRate: 170,
                heartRateRecoveryOneMinute: 28,
                zones: [],
                cardiovascularLoad: 8,
                sourceName: "test"
            )
        }

        let midWeek = calendar.date(byAdding: .day, value: 2, to: monday)!
        let priorWeek = calendar.date(byAdding: .day, value: -2, to: monday)!
        let snapshots = [
            DailyHealthSnapshot(
                date: midWeek,
                hrv: 50,
                restingHeartRate: 55,
                sleepHours: 7,
                activeEnergy: 600,
                steps: 8000,
                respiratoryRate: 14,
                workoutMinutes: 90,
                workouts: [
                    workout(on: 2, hour: 9, minutes: 40, name: "Carrera"),
                    workout(on: 2, hour: 18, minutes: 50, name: "Fuerza")
                ]
            ),
            DailyHealthSnapshot(
                date: priorWeek,
                hrv: 50,
                restingHeartRate: 55,
                sleepHours: 7,
                activeEnergy: 600,
                steps: 8000,
                respiratoryRate: 14,
                workoutMinutes: 60,
                workouts: [workout(on: -2, hour: 10, minutes: 60, name: "Ciclismo")]
            )
        ]

        let summary = HomeWeekWorkoutEngine.summarize(history: snapshots, now: now, calendar: calendar)
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.totalMinutes, 90, accuracy: 0.01)
        XCTAssertEqual(summary.keySessions.map(\.activityName), ["Fuerza", "Carrera"])
    }

    // MARK: - Journal Pro

    func testJournalDayUsesWakeToWakeBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Mexico_City"))
        let beforeWake = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 5, minute: 59)))
        let atWake = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 7)))
        let expectedPrevious = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let expectedCurrent = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))

        XCTAssertEqual(JournalDayEngine.journalDay(for: beforeWake, wakeMinutes: 420, calendar: calendar), expectedPrevious)
        XCTAssertEqual(JournalDayEngine.journalDay(for: atWake, wakeMinutes: 420, calendar: calendar), expectedCurrent)
    }

    func testJournalSensitiveCatalogIsOptIn() {
        let sensitive = JournalCatalog.builtIns.filter(\.sensitive)
        XCTAssertFalse(sensitive.isEmpty)
        XCTAssertTrue(sensitive.allSatisfy { !$0.defaultEnabled })
    }

    func testJournalAutomaticThresholdsUseMeasuredValues() throws {
        let definition = try XCTUnwrap(JournalCatalog.builtIns.first { $0.id == "auto.steps" })
        let tag = JournalResolvedTag(definition: definition, configuration: nil)
        let snapshot = DailyHealthSnapshot(
            date: .now, hrv: 50, restingHeartRate: 55, sleepHours: 7,
            activeEnergy: 400, steps: 12_000, respiratoryRate: 14, workoutMinutes: 20
        )
        let signal = JournalAutoEntryEngine.signals(snapshot: snapshot, score: nil, meals: [], stress: nil, tags: [tag]).first

        XCTAssertEqual(signal?.tagID, "auto.steps")
        XCTAssertEqual(signal?.answer, true)
        XCTAssertEqual(signal?.value, 12_000)
    }

    func testJournalActivityMarksAutoOnlyDays() throws {
        let day = Calendar.current.startOfDay(for: .now)
        let snapshot = DailyHealthSnapshot(
            date: day,
            hrv: 62,
            restingHeartRate: 52,
            sleepHours: 7.4,
            activeEnergy: 520,
            steps: 8_400,
            respiratoryRate: 14,
            workoutMinutes: 35
        )
        XCTAssertTrue(JournalActivityEngine.hasAutomaticHealthData(snapshot))
        XCTAssertTrue(JournalActivityEngine.dayHasActivity(manualAnswerCount: 0, hasAutomaticData: true))

        let empty = DailyHealthSnapshot.empty
        XCTAssertFalse(JournalActivityEngine.hasAutomaticHealthData(empty))
        XCTAssertFalse(JournalActivityEngine.dayHasActivity(manualAnswerCount: 0, hasAutomaticData: false))
    }

    func testJournalCompletionIncludesAutomaticOnlyDays() throws {
        let day = Calendar.current.startOfDay(for: .now)
        let alcohol = try XCTUnwrap(JournalCatalog.builtIns.first { $0.id == "alcohol" })
        let manualTag = JournalResolvedTag(definition: alcohol, configuration: nil)

        let autoOnly = JournalActivityEngine.completionState(
            manualTags: [manualTag],
            logs: [],
            day: day,
            hasAutomaticData: true
        )
        XCTAssertEqual(autoOnly, .partial)

        let none = JournalActivityEngine.completionState(
            manualTags: [manualTag],
            logs: [],
            day: day,
            hasAutomaticData: false
        )
        XCTAssertEqual(none, .none)

        let log = HabitLog(date: day, habit: alcohol.title, answer: true, tagID: alcohol.id)
        let complete = JournalActivityEngine.completionState(
            manualTags: [manualTag],
            logs: [log],
            day: day,
            hasAutomaticData: false
        )
        XCTAssertEqual(complete, .complete)
    }

    func testJournalRecvelAutomaticExtrasFromHealthSnapshot() throws {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let tags = JournalCatalog.builtIns
            .filter { $0.source == .automatic }
            .map { JournalResolvedTag(definition: $0, configuration: nil) }
        let snapshot = DailyHealthSnapshot(
            date: day,
            hrv: 58,
            restingHeartRate: 54,
            sleepHours: 7.2,
            activeEnergy: 610,
            steps: 9_100,
            respiratoryRate: 14,
            workoutMinutes: 40,
            vo2Max: 47.2,
            vo2MaxDate: day,
            mindfulMinutes: 12
        )
        let score = DailyScoreRecord(date: day, recovery: 72, sleep: 80, strain: 40)
        let signals = JournalAutoEntryEngine.signals(
            snapshot: snapshot,
            score: score,
            meals: [],
            stress: nil,
            tags: tags,
            fastingCompleted: true,
            calendar: calendar
        )
        let ids = Set(signals.map(\.tagID))
        XCTAssertTrue(ids.contains("auto.sleep"))
        XCTAssertTrue(ids.contains("auto.recovery"))
        XCTAssertTrue(ids.contains("auto.hrv"))
        XCTAssertTrue(ids.contains("auto.rhr"))
        XCTAssertTrue(ids.contains("auto.vo2"))
        XCTAssertTrue(ids.contains("auto.fasting"))
        XCTAssertTrue(ids.contains("auto.mindful"))
    }

    // MARK: - PhenoAge and biomarker reports

    func testPublishedPhenoAgeEquationIsDeterministic() throws {
        let input = PhenoAgeInput(
            chronologicalAge: 42,
            albuminGL: 45,
            creatinineUmolL: 80,
            glucoseMmolL: 5,
            crpMgL: 1,
            lymphocytePercent: 30,
            mcvFL: 90,
            rdwPercent: 13,
            alkalinePhosphataseUL: 70,
            whiteBloodCellCount: 6
        )

        let result = try PhenoAgeEngine().calculate(input)
        XCTAssertEqual(result.years, 37.1431, accuracy: 0.001)
        XCTAssertEqual(result.mortalityScore, 0.0147078, accuracy: 0.000001)
    }

    func testPhenoAgePanelNormalizesCommonUSUnits() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let birth = try XCTUnwrap(calendar.date(from: DateComponents(year: 1984, month: 7, day: 15)))
        let samples = [
            BiomarkerSample(kind: .albumin, value: 4.5, unit: "g/dL", observedAt: now),
            BiomarkerSample(kind: .creatinine, value: 0.905, unit: "mg/dL", observedAt: now),
            BiomarkerSample(kind: .glucose, value: 90.09, unit: "mg/dL", observedAt: now),
            BiomarkerSample(kind: .crp, value: 0.1, unit: "mg/dL", observedAt: now),
            BiomarkerSample(kind: .lymphocytePercent, value: 30, unit: "%", observedAt: now),
            BiomarkerSample(kind: .mcv, value: 90, unit: "fL", observedAt: now),
            BiomarkerSample(kind: .rdw, value: 13, unit: "%", observedAt: now),
            BiomarkerSample(kind: .alkalinePhosphatase, value: 70, unit: "U/L", observedAt: now),
            BiomarkerSample(kind: .whiteBloodCellCount, value: 6, unit: "K/uL", observedAt: now)
        ]

        let panel = try PhenoAgePanelResolver().resolve(samples: samples, birthDate: birth, now: now)
        XCTAssertEqual(panel.input.albuminGL, 45, accuracy: 0.001)
        XCTAssertEqual(panel.input.creatinineUmolL, 80.002, accuracy: 0.01)
        XCTAssertEqual(panel.input.glucoseMmolL, 5, accuracy: 0.001)
        XCTAssertEqual(panel.input.crpMgL, 1, accuracy: 0.001)
    }

    func testPhenoAgeRejectsIncompleteAndOldPanels() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let birth = try XCTUnwrap(calendar.date(from: DateComponents(year: 1980, month: 1, day: 1)))
        let oldDate = try XCTUnwrap(calendar.date(byAdding: .month, value: -7, to: now))
        let oldAlbumin = BiomarkerSample(kind: .albumin, value: 45, unit: "g/L", observedAt: oldDate)

        XCTAssertThrowsError(try PhenoAgePanelResolver().resolve(samples: [oldAlbumin], birthDate: birth, now: now)) { error in
            guard case PhenoAgeError.incompletePanel(let missing) = error else { return XCTFail("Expected incomplete panel") }
            XCTAssertTrue(missing.contains(.albumin))
            XCTAssertEqual(missing.count, 9)
        }
    }

    func testBioAgeWearableConfidenceRequiresTwentyCoveredDays() {
        let now = Date(timeIntervalSince1970: 1_784_100_000)
        let calendar = Calendar(identifier: .gregorian)
        let history = (0..<19).map { offset in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -offset, to: now)!,
                hrv: 55, restingHeartRate: 52, sleepHours: 7.5,
                activeEnergy: 500, steps: 8_000, respiratoryRate: 14,
                workoutMinutes: 30, vo2Max: 45, vo2MaxDate: now
            )
        }
        let cardio = BioAgeEstimate(chronologicalYears: 40, estimatedYears: 35, confidence: .medium, summary: "", factors: [])
        let medium = BioAgeReportEngine().report(cardio: cardio, history: history, laboratorySamples: [], birthDate: nil, now: now)
        let high = BioAgeReportEngine().report(
            cardio: cardio,
            history: history + [DailyHealthSnapshot(date: calendar.date(byAdding: .day, value: -19, to: now)!, hrv: 54, restingHeartRate: 53, sleepHours: 7, activeEnergy: 450, steps: 7_500, respiratoryRate: 14, workoutMinutes: 25, vo2Max: 45, vo2MaxDate: now)],
            laboratorySamples: [], birthDate: nil, now: now
        )

        XCTAssertEqual(medium.confidence, .medium)
        XCTAssertEqual(high.confidence, .high)
    }

    // MARK: - Sleep Bank

    func testSleepBankAccumulatesDebtAgainstGoal() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        // 5 noches de 6 h con meta de 8 h => -10 h de deuda.
        let history: [DailyHealthSnapshot] = (1...5).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return DailyHealthSnapshot(
                date: date, hrv: 55, restingHeartRate: 55, sleepHours: 6,
                activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
            )
        }
        let result = SleepBankEngine().assess(history: history, goalHours: 8, now: now)
        XCTAssertEqual(result.balanceHours, -10, accuracy: 0.01)
        XCTAssertEqual(result.nights, 5)
        XCTAssertFalse(result.isSurplus)
        XCTAssertTrue(result.hasEnoughData)
    }

    func testSleepBankReportsSurplusAndIgnoresNightsOutsideWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        var history: [DailyHealthSnapshot] = (1...3).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return DailyHealthSnapshot(
                date: date, hrv: 55, restingHeartRate: 55, sleepHours: 9,
                activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
            )
        }
        // Noche muy vieja: fuera de la ventana de 14 dias, no debe contar.
        if let old = calendar.date(byAdding: .day, value: -40, to: now) {
            history.append(DailyHealthSnapshot(
                date: old, hrv: 55, restingHeartRate: 55, sleepHours: 2,
                activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
            ))
        }
        let result = SleepBankEngine().assess(history: history, goalHours: 8, now: now)
        XCTAssertEqual(result.balanceHours, 3, accuracy: 0.01, "3 noches de +1 h; la de hace 40 dias se ignora")
        XCTAssertEqual(result.nights, 3)
        XCTAssertTrue(result.isSurplus)
    }

    func testSleepBankWithoutEnoughNightsDoesNotClaim() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        let history: [DailyHealthSnapshot] = [1].compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return DailyHealthSnapshot(
                date: date, hrv: 55, restingHeartRate: 55, sleepHours: 6,
                activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
            )
        }
        let result = SleepBankEngine().assess(history: history, goalHours: 8, now: now)
        XCTAssertFalse(result.hasEnoughData, "Con una sola noche no afirmamos un balance")
    }

    // MARK: - Clasificacion de aptitud (FRIEND)

    func testFitnessClassificationMatchesPublishedPercentiles() {
        let engine = FitnessClassificationEngine()
        // Hombre 25 anos: P50 = 48.0, P90 = 61.8 segun FRIEND treadmill.
        let median = engine.classify(vo2Max: 48.0, age: 25, sex: .male)
        XCTAssertEqual(median?.percentile ?? 0, 50, accuracy: 0.5)
        XCTAssertEqual(median?.fitnessClass, .good, "El P50 exacto es el piso de 'Buena forma'")

        let elite = engine.classify(vo2Max: 61.8, age: 25, sex: .male)
        XCTAssertEqual(elite?.percentile ?? 0, 90, accuracy: 0.5)
        XCTAssertEqual(elite?.fitnessClass, .elite)

        // Mujer 45 anos: P25 = 22.1, P75 = 32.4.
        let low = engine.classify(vo2Max: 22.1, age: 45, sex: .female)
        XCTAssertEqual(low?.percentile ?? 0, 25, accuracy: 0.5)
        XCTAssertEqual(low?.fitnessClass, .average)

        let high = engine.classify(vo2Max: 32.4, age: 45, sex: .female)
        XCTAssertEqual(high?.percentile ?? 0, 75, accuracy: 0.5)
        XCTAssertEqual(high?.fitnessClass, .high)
    }

    func testFitnessClassificationRefusesToGuessWithoutInputs() {
        let engine = FitnessClassificationEngine()
        XCTAssertNil(engine.classify(vo2Max: nil, age: 30, sex: .male), "Sin VO2 no clasificamos")
        XCTAssertNil(engine.classify(vo2Max: 45, age: nil, sex: .male), "Sin edad no hay grupo de referencia")
        XCTAssertNil(engine.classify(vo2Max: 45, age: 30, sex: .unspecified), "Sin sexo de referencia no clasificamos")
        XCTAssertNil(engine.classify(vo2Max: 45, age: 15, sex: .male), "FRIEND no publica datos bajo 20 anos")
        XCTAssertNil(engine.classify(vo2Max: 45, age: 85, sex: .male), "FRIEND no publica datos sobre 79 anos")
    }

    func testFitnessClassificationConfidenceNeedsRecentRepeatedSamples() {
        let engine = FitnessClassificationEngine()
        let single = engine.classify(vo2Max: 48, age: 25, sex: .male, vo2SampleCount: 1, vo2AgeDays: 0)
        XCTAssertEqual(single?.confidence, .low, "Una sola lectura estimada no da confianza media")
        let repeated = engine.classify(vo2Max: 48, age: 25, sex: .male, vo2SampleCount: 5, vo2AgeDays: 10)
        XCTAssertEqual(repeated?.confidence, .medium)
        let stale = engine.classify(vo2Max: 48, age: 25, sex: .male, vo2SampleCount: 5, vo2AgeDays: 200)
        XCTAssertEqual(stale?.confidence, .low, "Una lectura vieja no sostiene confianza media")
    }

    func testFitnessClassificationSuggestsNextTarget() {
        let engine = FitnessClassificationEngine()
        // Hombre 25 en P50 (48.0): el siguiente escalon es 'Alto rendimiento' (P75 = 55.2).
        let result = engine.classify(vo2Max: 48.0, age: 25, sex: .male)
        XCTAssertEqual(result?.nextClass, .high)
        XCTAssertEqual(result?.vo2ForNextClass ?? 0, 55.2, accuracy: 0.1)

        // En la cima no hay siguiente.
        let top = engine.classify(vo2Max: 70, age: 25, sex: .male)
        XCTAssertEqual(top?.fitnessClass, .elite)
        XCTAssertNil(top?.nextClass)
    }

    // MARK: - Trends Analysis

    func testMetricTrendEngineComparesWindowAgainstPreviousWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        // Ventana previa (dias -6..-4) = 10; ventana reciente (dias -2..0) = 14.
        var points: [MetricPoint] = []
        for offset in 4...6 {
            if let date = calendar.date(byAdding: .day, value: -offset, to: now) {
                points.append(MetricPoint(date: date, value: 10))
            }
        }
        for offset in 0...2 {
            if let date = calendar.date(byAdding: .day, value: -offset, to: now) {
                points.append(MetricPoint(date: date, value: 14))
            }
        }
        let change = MetricTrendEngine().change(points, days: 3, now: now)
        XCTAssertEqual(change ?? 0, 4, accuracy: 0.01)
    }

    func testMetricTrendEngineReturnsNilWithoutBothWindows() {
        let now = Date.now
        let points = [MetricPoint(date: now, value: 10)]
        XCTAssertNil(MetricTrendEngine().change(points, days: 7, now: now), "Sin ventana previa no hay cambio que reportar")
    }

    func testMetricTrendDirectionRespectsHigherIsBetter() {
        let engine = MetricTrendEngine()
        // Subir HRV es bueno; subir FC en reposo no.
        XCTAssertEqual(engine.direction(change: 5, higherIsBetter: true, tolerance: 1), .improving)
        XCTAssertEqual(engine.direction(change: 5, higherIsBetter: false, tolerance: 1), .declining)
        XCTAssertEqual(engine.direction(change: 0.2, higherIsBetter: true, tolerance: 1), .steady, "Bajo la tolerancia es ruido, no tendencia")
        XCTAssertEqual(engine.direction(change: nil, higherIsBetter: true, tolerance: 1), .unknown)
    }

    // MARK: - Sleep coaching

    func testSleepCoachingFlagsShortSleepWithEvidence() {
        let snapshot = DailyHealthSnapshot(
            date: .now, hrv: 55, restingHeartRate: 55, sleepHours: 5.5,
            activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
        )
        let bank = SleepBankEngine.Result(balanceHours: 0, nights: 5, goalHours: 8, nightly: [])
        let tips = SleepCoachingEngine().tips(score: 60, snapshot: snapshot, history: [snapshot], bank: bank)
        let duration = tips.first { $0.kind == .duration }
        XCTAssertNotNil(duration, "5.5 h debe disparar un consejo de duracion")
        XCTAssertFalse(duration?.evidence.isEmpty ?? true, "Todo consejo debe citar su evidencia")
    }

    func testSleepCoachingFlagsAccumulatedDebt() {
        let snapshot = DailyHealthSnapshot(
            date: .now, hrv: 55, restingHeartRate: 55, sleepHours: 7.5,
            activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
        )
        let bank = SleepBankEngine.Result(balanceHours: -6, nights: 10, goalHours: 8, nightly: [])
        let tips = SleepCoachingEngine().tips(score: 70, snapshot: snapshot, history: [snapshot], bank: bank)
        XCTAssertTrue(tips.contains { $0.detail.localizedCaseInsensitiveContains("deuda") || $0.title.localizedCaseInsensitiveContains("deuda") })
    }

    func testSleepCoachingPraisesStrongNightWhenNoIssues() {
        let snapshot = DailyHealthSnapshot(
            date: .now, hrv: 55, restingHeartRate: 55, sleepHours: 8.2,
            activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
        )
        let bank = SleepBankEngine.Result(balanceHours: 1, nights: 10, goalHours: 8, nightly: [])
        let tips = SleepCoachingEngine().tips(score: 90, snapshot: snapshot, history: [snapshot], bank: bank)
        XCTAssertEqual(tips.first?.kind, .positive)
    }

    /// Guardia del bug: la serie del chip "Sleep Bank" acumulaba TODO el
    /// historial mientras la tarjeta usa una ventana de 14 dias, asi que la
    /// app mostraba dos numeros distintos para la misma metrica.
    func testSleepBankRollingWindowMatchesCardValue() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now
        // Offsets 0...29 como genera HealthDataProvider (incluye hoy).
        // Las 10 noches mas recientes son de 8 h (neutras) y el resto de 7 h,
        // asi la ventana de 14 dias cubre 10 neutras + 4 de deuda = -4 h.
        let history: [DailyHealthSnapshot] = (0...29).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let hours: Double = offset >= 10 ? 7 : 8
            return DailyHealthSnapshot(
                date: date, hrv: 55, restingHeartRate: 55, sleepHours: hours,
                activeEnergy: 400, steps: 6_000, respiratoryRate: 14, workoutMinutes: 0
            )
        }.sorted { $0.date < $1.date }

        let card = SleepBankEngine().assess(history: history, goalHours: 8, now: now)
        XCTAssertEqual(card.nights, 14, "La ventana debe cubrir 14 noches")
        XCTAssertEqual(card.balanceHours, -4, accuracy: 0.01)
        // Un acumulado total daria -20 h: 16 h de diferencia con la tarjeta.
        let naiveTotal = history.compactMap(\.sleepHours).reduce(0) { $0 + ($1 - 8) }
        XCTAssertEqual(naiveTotal, -20, accuracy: 0.01)
        XCTAssertNotEqual(card.balanceHours, naiveTotal, "La ventana rodante NO debe ser el acumulado total")
    }
}
