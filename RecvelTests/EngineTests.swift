import XCTest
@testable import Recvel

final class EngineTests: XCTestCase {
    private var originalLanguage: AppLanguage = .system

    override func setUp() {
        super.setUp()
        originalLanguage = RecvelLanguageStore.load()
        RecvelLanguageStore.save(.esMX)
    }

    override func tearDown() {
        RecvelLanguageStore.save(originalLanguage)
        super.tearDown()
    }

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

        XCTAssertTrue(advice.title.localizedCaseInsensitiveContains("sueño"))
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

        XCTAssertTrue(emptyPlan.tomorrowReason.localizedCaseInsensitiveContains("proteína"))
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
        // La etiqueta pasa por el catalogo de strings desde que las zonas de
        // cardio se localizaron; antes era un literal sin acento en el codigo.
        // Se compara contra la clave resuelta para que el test no se rompa al
        // traducir ni al corregir la ortografia.
        XCTAssertEqual(focus.primaryLabel, RecvelL10n.text("training.cardio.zone.highAerobic"))
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

    // MARK: - 1RM estimado (progresion de fuerza)

    func testOneRepMaxAveragesEpleyAndBrzyckiInReliableRange() {
        // 100 kg x 5 reps: Epley 116.67, Brzycki 112.5 -> promedio 114.58.
        let e = OneRepMaxEstimator.estimate(weightKg: 100, reps: 5)
        XCTAssertEqual(try XCTUnwrap(e), 114.58, accuracy: 0.05)
        // 80 kg x 8 reps.
        let e2 = OneRepMaxEstimator.estimate(weightKg: 80, reps: 8)
        XCTAssertEqual(try XCTUnwrap(e2), 100.32, accuracy: 0.1)
    }

    func testOneRepMaxAtOneRepIsTheWeightItself() {
        XCTAssertEqual(OneRepMaxEstimator.estimate(weightKg: 120, reps: 1), 120)
    }

    func testOneRepMaxRefusesUnreliableOrEmptyInput() {
        XCTAssertNil(OneRepMaxEstimator.estimate(weightKg: 100, reps: 11), "Sobre 10 reps las formulas pierden fiabilidad")
        XCTAssertNil(OneRepMaxEstimator.estimate(weightKg: 100, reps: 15))
        XCTAssertNil(OneRepMaxEstimator.estimate(weightKg: 0, reps: 5), "Sin peso no hay 1RM")
        XCTAssertNil(OneRepMaxEstimator.estimate(weightKg: 100, reps: 0))
    }

    func testOneRepMaxIsMonotonicWithReps() {
        // A igual peso, mas reps => 1RM estimado mayor (dentro del rango fiable).
        let a = try? XCTUnwrap(OneRepMaxEstimator.estimate(weightKg: 100, reps: 3))
        let b = try? XCTUnwrap(OneRepMaxEstimator.estimate(weightKg: 100, reps: 8))
        XCTAssertNotNil(a); XCTAssertNotNil(b)
        if let a, let b { XCTAssertGreaterThan(b, a) }
    }

    func testWorkoutFeelingEffortScoreIsMonotonic() {
        let ordered: [WorkoutFeeling] = [.easy, .comfortable, .solid, .hard, .maximal]
        let scores = ordered.map(\.effortScore1to10)
        XCTAssertEqual(scores, scores.sorted(), "El esfuerzo 1-10 debe crecer de facil a al-limite")
        XCTAssertEqual(scores.first, 2)
        XCTAssertEqual(scores.last, 10)
    }

    func testWorkoutFeelingMapsFromImportedEffortScore() {
        XCTAssertEqual(WorkoutFeeling.fromEffortScore(1), .easy)
        XCTAssertEqual(WorkoutFeeling.fromEffortScore(4), .comfortable)
        XCTAssertEqual(WorkoutFeeling.fromEffortScore(6), .solid)
        XCTAssertEqual(WorkoutFeeling.fromEffortScore(8), .hard)
        XCTAssertEqual(WorkoutFeeling.fromEffortScore(10), .maximal)
    }

    // MARK: - Agenda semanal: split, deporte y retro-compat

    func testWeeklyRoutineDecodesLegacyJSONWithDefaults() throws {
        // JSON de la version MVP: sin splitType, cardioSport ni minutesPerDay.
        // Swift codifica [Int: DayAssignment] como objeto ({} cuando está vacío).
        let legacy = """
        {"goal":"strength","minutesPerSession":50,"onboarded":true,"days":{}}
        """.data(using: .utf8)!
        let routine = try JSONDecoder().decode(WeeklyRoutine.self, from: legacy)
        XCTAssertEqual(routine.goal, .strength)
        XCTAssertEqual(routine.minutesPerSession, 50)
        XCTAssertTrue(routine.onboarded)
        XCTAssertEqual(routine.splitType, .fullBody, "Default retro-compatible")
        XCTAssertNil(routine.cardioSport)
        XCTAssertTrue(routine.minutesPerDay.isEmpty)
        XCTAssertEqual(routine.experience, .intermediate)
        XCTAssertEqual(routine.objective, .general)
        XCTAssertEqual(routine.phase, .base)
        XCTAssertTrue(routine.sessionDetails.isEmpty)
        XCTAssertFalse(routine.dailyChallengesEnabled)
        XCTAssertTrue(routine.dailyChallenges.isEmpty)
    }

    func testDailyChallengeUpperDayProducesLowerFocus() {
        let engine = DailyChallengeEngine()
        let templateID = UUID()
        let challenges = engine.generateChallenges(
            days: [2: .template(templateID), 3: .rest, 4: .rest, 5: .rest, 6: .rest, 7: .rest, 1: .rest],
            splitType: .upperLower,
            cardioSport: nil,
            templateFocus: [templateID: "Tren superior"]
        )
        let monday = challenges[2]
        XCTAssertNotNil(monday)
        XCTAssertEqual(monday?.kind, .strengthOpposite)
        XCTAssertTrue(monday?.focus.localizedCaseInsensitiveContains("inferior") == true)
        // "Sentadilla" en singular: alineado al nombre exacto de ExerciseLibrary
        // para que el challenge tenga thumbnail (test de cobertura lo garantiza).
        XCTAssertTrue(monday?.exercisesText.localizedCaseInsensitiveContains("Sentadilla") == true)
    }

    func testDailyChallengeLowerDayProducesUpperFocus() {
        let engine = DailyChallengeEngine()
        let templateID = UUID()
        let challenges = engine.generateChallenges(
            days: [2: .template(templateID)],
            splitType: .upperLower,
            cardioSport: nil,
            templateFocus: [templateID: "Tren inferior"]
        )
        XCTAssertTrue(challenges[2]?.focus.localizedCaseInsensitiveContains("superior") == true)
    }

    func testDailyChallengeRestDayIsLightWithExplicitFocus() {
        let engine = DailyChallengeEngine()
        let challenges = engine.generateChallenges(
            days: [2: .rest],
            splitType: .fullBody,
            cardioSport: nil,
            templateFocus: [:]
        )
        let rest = challenges[2]
        // El dia de descanso ofrece fortalecimiento ligero (mantenimiento) o
        // movilidad; ambos cortos y con foco explicito.
        XCTAssertTrue(rest?.kind == .maintenance || rest?.kind == .mobility)
        XCTAssertFalse(rest?.focus.isEmpty == true)
        XCTAssertLessThanOrEqual(rest?.durationMinutes ?? 99, 15)
    }

    func testDailyChallengeAntiOverlapAvoidsSameBucketAsStrengthDay() {
        let engine = DailyChallengeEngine()
        let upperID = UUID()
        let challenges = engine.generateChallenges(
            days: [
                2: .template(upperID),
                3: .rest
            ],
            splitType: .upperLower,
            cardioSport: nil,
            templateFocus: [upperID: "Tren superior"]
        )
        // Día de descanso adyacente no debe empujar upper/push/chest.
        let restFocus = ChallengeMuscleBucket.classify(challenges[3]?.focus)
        XCTAssertFalse(ChallengeMuscleBucket.upper.conflicting.contains(restFocus) && restFocus != .other)
    }

    func testDailyChallengeMobilityDayCanStillHaveChallenge() {
        let engine = DailyChallengeEngine()
        let challenges = engine.generateChallenges(
            days: [2: .mobility],
            splitType: .fullBody,
            cardioSport: nil,
            templateFocus: [:]
        )
        XCTAssertNotNil(challenges[2])
        XCTAssertTrue(challenges[2]?.kind == .walk || challenges[2]?.kind == .mobility)
    }

    func testMobilityAndCardioRoutinesAreConcrete() {
        let engine = DailyChallengeEngine()
        let mobility = engine.mobilityRoutine(focusHint: "Hombros")
        XCTAssertFalse(mobility.exercisesText.isEmpty)
        XCTAssertGreaterThan(mobility.durationMinutes, 0)

        let cardio = engine.cardioRoutine(sport: .running, durationMinutes: 25)
        XCTAssertEqual(cardio.focus, "Correr")
        XCTAssertTrue(cardio.exercisesText.contains("25 min"))
    }

    func testWeeklyRoutineRoundTripsDailyChallengeFields() throws {
        let challenge = DailyChallengeDay(
            title: "Challenge lower",
            kind: .strengthOpposite,
            focus: "Tren inferior",
            exercisesText: "Sentadillas | 30",
            durationMinutes: 12
        )
        let routine = WeeklyRoutine(
            onboarded: true,
            dailyChallengesEnabled: true,
            dailyChallenges: [2: challenge]
        )
        let data = try JSONEncoder().encode(routine)
        let back = try JSONDecoder().decode(WeeklyRoutine.self, from: data)
        XCTAssertTrue(back.dailyChallengesEnabled)
        XCTAssertEqual(back.dailyChallenges[2]?.focus, "Tren inferior")
        XCTAssertEqual(back.dailyChallenges[2]?.kind, .strengthOpposite)
    }

    func testWeeklyRoutineRoundTripsSharedTemplateLinks() throws {
        let cardioID = UUID()
        let challengeID = UUID()
        let routine = WeeklyRoutine(
            onboarded: true,
            days: [2: .cardio("running")],
            sessionTemplateIDs: [2: cardioID],
            dailyChallengeTemplateIDs: [2: challengeID]
        )

        let back = try JSONDecoder().decode(WeeklyRoutine.self, from: JSONEncoder().encode(routine))

        XCTAssertEqual(back.templateID(forWeekday: 2), cardioID)
        XCTAssertEqual(back.dailyChallengeTemplateIDs[2], challengeID)
    }

    func testTemplateCodecSupportsSingleRepAndTimedRoutines() {
        let parsed = TemplateCodec.parse("Sentadillas | 30\nCaminata | 12 min\nEstiramiento | 45s")

        XCTAssertEqual(parsed[0].sets, 1)
        XCTAssertEqual(parsed[0].reps, 30)
        XCTAssertEqual(parsed[1].durationSeconds, 720)
        XCTAssertEqual(parsed[2].durationSeconds, 45)

        let roundTrip = TemplateCodec.parse(TemplateCodec.serialize(parsed))
        XCTAssertEqual(roundTrip.map(\.durationSeconds), parsed.map(\.durationSeconds))
        XCTAssertEqual(roundTrip.map(\.reps), parsed.map(\.reps))
    }

    @MainActor
    func testWorkoutTemplateStoresRoutineKindAndDuration() {
        let template = WorkoutTemplate(
            name: "Cardio suave",
            focus: "Correr",
            exercisesText: "Correr | 25 min",
            kind: .cardio,
            sourceID: "test.cardio",
            durationMinutes: 25
        )

        XCTAssertEqual(template.kind, .cardio)
        XCTAssertEqual(template.sourceID, "test.cardio")
        XCTAssertEqual(template.durationMinutes, 25)
    }

    func testWeeklyRoutineRoundTripsNewFields() throws {
        let routine = WeeklyRoutine(
            goal: .mixed, minutesPerSession: 45, onboarded: true, days: [:],
            splitType: .pushPullLegs, cardioSport: .football, minutesPerDay: [2: 60],
            experience: .competitive,
            objective: .sportPerformance,
            phase: .peak,
            sessionDetails: [
                2: ScheduledSessionDetails(
                    startMinute: 7 * 60,
                    flexibility: .fixed,
                    durationMinutes: 75,
                    targetRPE: 8,
                    cardioIntent: .intervals,
                    focusOverride: "Velocidad"
                )
            ]
        )
        let data = try JSONEncoder().encode(routine)
        let back = try JSONDecoder().decode(WeeklyRoutine.self, from: data)
        XCTAssertEqual(back.splitType, .pushPullLegs)
        XCTAssertEqual(back.cardioSport, .football)
        XCTAssertEqual(back.minutes(forWeekday: 2), 75)
        XCTAssertEqual(back.minutes(forWeekday: 4), 45, "Fallback al global cuando no hay override")
        XCTAssertEqual(back.experience, .competitive)
        XCTAssertEqual(back.objective, .sportPerformance)
        XCTAssertEqual(back.phase, .peak)
        XCTAssertEqual(back.details(forWeekday: 2).targetRPE, 8)
        XCTAssertEqual(back.details(forWeekday: 2).focusOverride, "Velocidad")
    }

    func testWeeklyRoutineCalculatesPlannedSessionRPELoad() {
        let routine = WeeklyRoutine(
            onboarded: true,
            days: [2: .cardio(sport: .running), 4: .cardio(sport: .football), 6: .rest],
            sessionDetails: [
                2: ScheduledSessionDetails(durationMinutes: 60, targetRPE: 5),
                4: ScheduledSessionDetails(durationMinutes: 90, targetRPE: 8)
            ]
        )
        XCTAssertEqual(routine.plannedMinutes, 150)
        XCTAssertEqual(routine.plannedLoad, 1_020)
        XCTAssertEqual(routine.highIntensitySessionCount, 1)
    }

    func testTrainingReadinessScorePenalizesSoreness() {
        let ready = TrainingReadinessContext(energy: 5, soreness: 1, motivation: 5, hasPainOrLimitation: false)
        let fatigued = TrainingReadinessContext(energy: 2, soreness: 5, motivation: 2, hasPainOrLimitation: false)
        XCTAssertGreaterThan(ready.score, fatigued.score)
        XCTAssertEqual(ready.score, 100)
    }

    func testCardioSportTransportsThroughDayAssignment() {
        let assignment = DayAssignment.cardio(sport: .football)
        guard case .cardio(let name) = assignment else { return XCTFail("Debe ser cardio") }
        XCTAssertEqual(DayAssignment.sport(fromCardioName: name), .football)
        // Un string legado no es un deporte y se muestra tal cual.
        XCTAssertNil(DayAssignment.sport(fromCardioName: "Carrera"))
    }

    func testSuggestedWeekUsesChosenSportForCardioDays() {
        let plan = WeeklyRoutinePlanner().suggestedWeek(
            goal: .cardio,
            trainingWeekdays: [2, 4, 6],
            templateIDs: [],
            splitType: .fullBody,
            cardioSport: .football
        )
        let cardioDays = plan.values.filter {
            if case .cardio(let n) = $0 { return DayAssignment.sport(fromCardioName: n) == .football }
            return false
        }
        XCTAssertEqual(cardioDays.count, 3, "Los 3 días de cardio usan el deporte elegido")
        XCTAssertEqual(plan.values.filter { $0 == .rest }.count, 4)
    }

    func testSuggestedWeekStrengthUsesTemplatesAndRestsElsewhere() {
        let ids = [UUID(), UUID()]
        let plan = WeeklyRoutinePlanner().suggestedWeek(
            goal: .strength, trainingWeekdays: [2, 4, 6], templateIDs: ids, splitType: .upperLower
        )
        XCTAssertEqual(WeeklyRoutinePlanner().weeklyStrengthDays(in: plan), 3)
        XCTAssertEqual(plan.values.filter { $0 == .rest }.count, 4)
    }

    func testSplitFocusRotationMatchesScience() {
        // Full body = 1 foco (todo el cuerpo); PPL = 3; upper/lower = 2.
        XCTAssertEqual(SplitType.fullBody.focusRotation.count, 1)
        XCTAssertEqual(SplitType.upperLower.focusRotation.count, 2)
        XCTAssertEqual(SplitType.pushPullLegs.focusRotation.count, 3)
        XCTAssertTrue(SplitType.custom.focusRotation.isEmpty)
        let planner = WeeklyRoutinePlanner()
        XCTAssertEqual(planner.focusLabel(splitType: .pushPullLegs, strengthDayIndex: 0), "Empuje")
        XCTAssertEqual(planner.focusLabel(splitType: .pushPullLegs, strengthDayIndex: 3), "Empuje", "Cicla")
    }

    // MARK: - Coaching de entrenamiento (dia siguiente)

    private func makeLastWorkout(hoursAgo: Double, effort: Int?, group: String, strength: Bool = true) -> LastWorkoutContext {
        LastWorkoutContext(
            endedAt: Date.now.addingTimeInterval(-hoursAgo * 3600),
            effortScore: effort,
            muscleGroup: group,
            wasStrength: strength
        )
    }

    func testCoachingFlagsSameMuscleWithin48h() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Pecho",
            recovery: 70,
            lastWorkout: makeLastWorkout(hoursAgo: 24, effort: 6, group: "Pecho"),
            consecutiveTrainingDays: 2,
            plannedBedtime: nil,
            proposedStart: nil
        )
        XCTAssertTrue(tips.contains { $0.kind == .muscleReadiness }, "Mismo grupo <48h debe avisar")
        XCTAssertTrue(tips.allSatisfy { !$0.evidence.isEmpty }, "Todo tip lleva evidencia")
    }

    func testCoachingAllowsDifferentMuscleSameDay() {
        // Entrenó tren superior hace 6h (madrugada); hoy toca inferior.
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Tren inferior",
            recovery: 68,
            lastWorkout: makeLastWorkout(hoursAgo: 6, effort: 6, group: "Tren superior"),
            consecutiveTrainingDays: 1,
            plannedBedtime: nil,
            proposedStart: nil
        )
        let readiness = tips.first { $0.kind == .muscleReadiness }
        XCTAssertNotNil(readiness)
        XCTAssertTrue(readiness?.detail.localizedCaseInsensitiveContains("otra zona") == true
            || readiness?.title.localizedCaseInsensitiveContains("otra zona") == true)
    }

    func testCoachingSuggestsDeloadAfterManyConsecutiveDays() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Full body",
            recovery: 45,
            lastWorkout: makeLastWorkout(hoursAgo: 20, effort: 7, group: "Full body"),
            consecutiveTrainingDays: 7,
            plannedBedtime: nil,
            proposedStart: nil
        )
        XCTAssertTrue(tips.contains { $0.kind == .deload }, "7 días seguidos + recovery baja => deload")
    }

    func testCoachingModeratesAfterHardSessionWithLowRecovery() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Piernas",
            recovery: 48,
            lastWorkout: makeLastWorkout(hoursAgo: 30, effort: 9, group: "Espalda"),
            consecutiveTrainingDays: 2,
            plannedBedtime: nil,
            proposedStart: nil
        )
        XCTAssertTrue(tips.contains { $0.kind == .recovery }, "Esfuerzo alto + recovery baja => moderar")
    }

    func testCoachingTimingWarnsWhenTrainingTooCloseToBedtime() {
        let cal = Calendar.current
        let bedtime = cal.date(bySettingHour: 22, minute: 30, second: 0, of: .now)!
        // Empieza 22:00 -> termina ~23:00 -> a 90 min... no: termina a <1h de dormir.
        let start = cal.date(bySettingHour: 22, minute: 0, second: 0, of: .now)!
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "HIIT",
            recovery: 65,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: bedtime,
            proposedStart: start
        )
        let timing = tips.first { $0.kind == .timing }
        XCTAssertNotNil(timing, "Entreno que termina <1h antes de dormir debe avisar")
        XCTAssertGreaterThan(timing?.suggestedShiftMinutes ?? 0, 0)
    }

    func testCoachingNoTimingWarningWhenWellBeforeBed() {
        let cal = Calendar.current
        let bedtime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
        let start = cal.date(bySettingHour: 17, minute: 0, second: 0, of: .now)! // termina ~18:00, 5h antes
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Correr",
            recovery: 65,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: bedtime,
            proposedStart: start
        )
        XCTAssertFalse(tips.contains { $0.kind == .timing }, "≥4h antes de dormir no hay conflicto")
    }

    func testCoachingPositiveWhenRecoveryHighAndNoFlags() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Tren superior",
            recovery: 82,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: nil,
            proposedStart: nil
        )
        XCTAssertEqual(tips.first?.kind, .positive)
    }

    func testCoachingReducesDurationAndRPEWhenReadinessIsLow() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Tren inferior",
            recovery: 62,
            lastWorkout: nil,
            consecutiveTrainingDays: 2,
            plannedBedtime: nil,
            proposedStart: nil,
            plannedDurationMinutes: 80,
            targetRPE: 8,
            readiness: TrainingReadinessContext(
                energy: 2,
                soreness: 5,
                motivation: 2,
                hasPainOrLimitation: false
            )
        )
        let tip = tips.first { $0.kind == .readiness }
        XCTAssertTrue(tip?.detail.contains("60 min") == true)
        XCTAssertTrue(tip?.detail.contains("RPE 6/10") == true)
    }

    func testCoachingPrioritizesPainWithoutPushingSession() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Full body",
            recovery: 88,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: nil,
            proposedStart: nil,
            readiness: TrainingReadinessContext(
                energy: 5,
                soreness: 1,
                motivation: 5,
                hasPainOrLimitation: true
            )
        )
        XCTAssertEqual(tips.first?.kind, .readiness)
        XCTAssertTrue(tips.first?.detail.localizedCaseInsensitiveContains("evita forzar") == true)
    }

    func testFixedLateScheduleModeratesInsteadOfMoving() {
        let calendar = Calendar.current
        let bedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
        let start = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: .now)!
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Intervalos",
            recovery: 70,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: bedtime,
            proposedStart: start,
            plannedDurationMinutes: 75,
            targetRPE: 8,
            scheduleFlexibility: .fixed
        )
        let timing = tips.first { $0.kind == .timing }
        XCTAssertNotNil(timing)
        XCTAssertEqual(timing?.suggestedShiftMinutes, 0)
        XCTAssertTrue(timing?.title.localizedCaseInsensitiveContains("modera") == true)
    }

    func testConsecutiveTrainingDaysCountsStreak() {
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!
        // Hoy, ayer, antier => 3.
        let dates = (0...2).compactMap { cal.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(TrainingCoachingEngine().consecutiveTrainingDays(workoutDates: dates, now: now), 3)
        // Con un hueco: hoy y hace 3 días => racha de 1.
        let gapped = [now, cal.date(byAdding: .day, value: -3, to: now)!]
        XCTAssertEqual(TrainingCoachingEngine().consecutiveTrainingDays(workoutDates: gapped, now: now), 1)
        XCTAssertEqual(TrainingCoachingEngine().consecutiveTrainingDays(workoutDates: [], now: now), 0)
    }

    // MARK: - Progresion por ejercicio

    func testExerciseProgressionSummarizesAndSortsBySets() {
        let s1 = UUID(); let s2 = UUID()
        let logs = [
            ExerciseSetLog(sessionID: s1, date: Date.now.addingTimeInterval(-86400), exerciseName: "Press de banca", muscleGroup: "Pecho", setIndex: 0, weightKg: 80, reps: 5, estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: 80, reps: 5)),
            ExerciseSetLog(sessionID: s2, date: Date.now, exerciseName: "Press de banca", muscleGroup: "Pecho", setIndex: 0, weightKg: 85, reps: 5, estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: 85, reps: 5)),
            ExerciseSetLog(sessionID: s2, date: Date.now, exerciseName: "Sentadilla", muscleGroup: "Piernas", setIndex: 0, weightKg: 100, reps: 5, estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: 100, reps: 5))
        ]
        let summaries = ExerciseProgression.summaries(from: logs)
        XCTAssertEqual(summaries.count, 2)
        let bench = summaries.first { $0.exerciseName == "Press de banca" }
        XCTAssertEqual(bench?.sessionCount, 2, "Dos sesiones distintas")
        XCTAssertEqual(bench?.latestTopSet, 85, "El top set de la sesión más reciente")
    }

    func testExerciseProgressionSeriesUsesBestPerSession() {
        let s1 = UUID()
        let logs = [
            ExerciseSetLog(sessionID: s1, date: Date.now, exerciseName: "Sentadilla", muscleGroup: "Piernas", setIndex: 0, weightKg: 90, reps: 5, estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: 90, reps: 5)),
            ExerciseSetLog(sessionID: s1, date: Date.now, exerciseName: "Sentadilla", muscleGroup: "Piernas", setIndex: 1, weightKg: 100, reps: 3, estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: 100, reps: 3))
        ]
        let weightDesc = ExerciseProgression.descriptors(exerciseName: "Sentadilla", setLogs: logs)[0]
        let weightSeries = ExerciseProgression.series(for: weightDesc, exerciseName: "Sentadilla", setLogs: logs)
        XCTAssertEqual(weightSeries.count, 1)
        XCTAssertEqual(weightSeries.first?.value, 100, "Top set de la sesión")

        let e1rmDesc = ExerciseProgression.descriptors(exerciseName: "Sentadilla", setLogs: logs)[1]
        let e1rmSeries = ExerciseProgression.series(for: e1rmDesc, exerciseName: "Sentadilla", setLogs: logs)
        // 100x3 da mayor e1RM que 90x5.
        XCTAssertEqual(e1rmSeries.count, 1)
        XCTAssertGreaterThan(e1rmSeries.first?.value ?? 0, 100)
    }

    // MARK: - Plan semanal pro: tipos de sesion, biblioteca y expectativas

    func testSessionDetailsDecodeLegacyJSONWithoutProFields() throws {
        // JSON guardado antes de los campos pro (contactos, contraste, zona, %1RM).
        let legacy = """
        {"startMinute":1080,"flexibility":"preferred","durationMinutes":50,"targetRPE":7}
        """.data(using: .utf8)!
        let details = try JSONDecoder().decode(ScheduledSessionDetails.self, from: legacy)
        XCTAssertEqual(details.durationMinutes, 50)
        XCTAssertEqual(details.targetRPE, 7)
        XCTAssertNil(details.jumpContacts)
        XCTAssertNil(details.contrastSets)
        XCTAssertNil(details.speedReps)
        XCTAssertNil(details.targetZone)
        XCTAssertNil(details.mainLiftPercent1RM)
        XCTAssertNil(details.sessionNote)
    }

    func testWeeklyRoutineRoundTripsPlanFields() throws {
        let routine = WeeklyRoutine(
            onboarded: true,
            days: [2: .plyometrics, 4: .mobility],
            planName: "Bloque de potencia",
            advancedConfig: true,
            personalRecords: ["squat": 140.0],
            planWeeks: 6
        )
        let data = try JSONEncoder().encode(routine)
        let back = try JSONDecoder().decode(WeeklyRoutine.self, from: data)
        XCTAssertEqual(back.displayName, "Bloque de potencia")
        XCTAssertTrue(back.advancedConfig)
        XCTAssertEqual(back.personalRecords["squat"], 140.0)
        XCTAssertEqual(back.planWeeks, 6)
        XCTAssertEqual(back.days[2], .plyometrics)
        XCTAssertEqual(back.days[4], .mobility)
    }

    func testWeeklyRoutineLegacyJSONDecodesWithPlanDefaults() throws {
        let legacy = """
        {"goal":"mixed","minutesPerSession":45,"onboarded":true,"days":{}}
        """.data(using: .utf8)!
        let routine = try JSONDecoder().decode(WeeklyRoutine.self, from: legacy)
        XCTAssertNil(routine.planName)
        XCTAssertEqual(routine.displayName, "Plan semanal", "Fallback de nombre")
        XCTAssertFalse(routine.advancedConfig)
        XCTAssertTrue(routine.personalRecords.isEmpty)
        XCTAssertNil(routine.planWeeks)
    }

    func testDayAssignmentPerformanceTypesRoundTrip() throws {
        let days: [Int: DayAssignment] = [
            2: .plyometrics, 3: .speed, 4: .contrast,
            5: .technique, 6: .mobility, 7: .recovery, 1: .rest
        ]
        let data = try JSONEncoder().encode(days)
        let back = try JSONDecoder().decode([Int: DayAssignment].self, from: data)
        XCTAssertEqual(back, days)
        XCTAssertTrue(DayAssignment.plyometrics.isHighNeuralDemand)
        XCTAssertTrue(DayAssignment.contrast.isHighNeuralDemand)
        XCTAssertFalse(DayAssignment.mobility.isHighNeuralDemand)
        XCTAssertTrue(DayAssignment.recovery.isRecoveryOriented)
    }

    func testPlanLibraryUpsertDeleteAndDeleteAll() {
        let suite = UserDefaults(suiteName: "test.planLibrary.\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }
        XCTAssertTrue(WeeklyPlanLibraryStore.load(defaults: suite).isEmpty)

        let routineA = WeeklyRoutine(onboarded: true, days: [2: .template(UUID())])
        let planA = WeeklyPlan(name: "Fuerza A", routine: routineA)
        let planB = WeeklyPlan(name: "Descarga", routine: WeeklyRoutine(onboarded: true, days: [4: .mobility]))
        WeeklyPlanLibraryStore.upsert(planA, defaults: suite)
        WeeklyPlanLibraryStore.upsert(planB, defaults: suite)
        XCTAssertEqual(WeeklyPlanLibraryStore.load(defaults: suite).count, 2)

        // Upsert con el mismo id reemplaza, no duplica.
        var renamed = planA
        renamed.name = "Fuerza A2"
        WeeklyPlanLibraryStore.upsert(renamed, defaults: suite)
        let loaded = WeeklyPlanLibraryStore.load(defaults: suite)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains { $0.name == "Fuerza A2" })

        WeeklyPlanLibraryStore.delete(id: planB.id, defaults: suite)
        XCTAssertEqual(WeeklyPlanLibraryStore.load(defaults: suite).count, 1)

        WeeklyPlanLibraryStore.deleteAll(defaults: suite)
        XCTAssertTrue(WeeklyPlanLibraryStore.load(defaults: suite).isEmpty)
    }

    func testDefaultSplitFollowsStrengthDayCount() {
        XCTAssertEqual(WeeklyRoutinePlanner.defaultSplit(forStrengthDays: 2), .fullBody)
        XCTAssertEqual(WeeklyRoutinePlanner.defaultSplit(forStrengthDays: 3), .fullBody)
        XCTAssertEqual(WeeklyRoutinePlanner.defaultSplit(forStrengthDays: 4), .upperLower)
        XCTAssertEqual(WeeklyRoutinePlanner.defaultSplit(forStrengthDays: 6), .pushPullLegs)
    }

    func testSuggestedWeekIncludeMobilityConvertsLastCardioDay() {
        let plan = WeeklyRoutinePlanner().suggestedWeek(
            goal: .mixed,
            trainingWeekdays: [2, 3, 5, 6],
            templateIDs: [UUID()],
            splitType: .fullBody,
            cardioSport: .running,
            includeMobility: true
        )
        XCTAssertEqual(plan.values.filter { $0 == .mobility }.count, 1, "Un día de movilidad")
        // En mixto 4 días: 2 fuerza + 2 cardio; la movilidad reemplaza el último cardio.
        let cardioDays = plan.values.filter {
            if case .cardio = $0 { return true }
            return false
        }
        XCTAssertEqual(cardioDays.count, 1)
    }

    func testSuggestedWeekIncludeMobilityOnStrengthOnlyWeek() {
        let plan = WeeklyRoutinePlanner().suggestedWeek(
            goal: .strength,
            trainingWeekdays: [2, 4],
            templateIDs: [UUID()],
            splitType: .fullBody,
            includeMobility: true
        )
        XCTAssertEqual(plan.values.filter { $0 == .mobility }.count, 1)
        // Sin cardio: la movilidad cae en un día libre posterior al último entreno.
        XCTAssertEqual(plan.values.filter { $0 == .rest }.count, 4)
    }

    func testCoachingMovesNeuralSessionWhenRecoveryIsLow() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Pliometría",
            recovery: 40,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: nil,
            proposedStart: nil,
            plannedKind: .plyometrics
        )
        let tip = tips.first { $0.kind == .readiness }
        XCTAssertNotNil(tip, "Plio con recovery baja debe sugerir mover/adaptar")
        XCTAssertTrue(tip?.title.localizedCaseInsensitiveContains("fresco") == true)
        XCTAssertTrue(tips.allSatisfy { !$0.evidence.isEmpty })
    }

    func testCoachingKeepsNeuralSessionWhenFresh() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: "Velocidad",
            recovery: 85,
            lastWorkout: nil,
            consecutiveTrainingDays: 1,
            plannedBedtime: nil,
            proposedStart: nil,
            plannedKind: .speed
        )
        XCTAssertFalse(tips.contains { $0.kind == .readiness && $0.symbol.contains("bolt") },
                       "Con recovery alta no hay aviso de sesión neuronal")
    }

    func testCoachingReinforcesRecoveryDayAfterStreak() {
        let tips = TrainingCoachingEngine().tips(
            todayFocus: nil,
            recovery: 60,
            lastWorkout: nil,
            consecutiveTrainingDays: 4,
            plannedBedtime: nil,
            proposedStart: nil,
            plannedKind: .mobility
        )
        XCTAssertTrue(tips.contains { $0.kind == .positive }, "Día de movilidad tras racha = refuerzo positivo")
    }

    func testPlanExpectationsFlagMissingRestAndHardWeek() {
        let expectation = PlanExpectationEngine.expectations(for: PlanExpectationInput(
            objective: .hypertrophy,
            experience: .starting,
            phase: .base,
            trainingDays: 7,
            performanceDays: 2,
            mobilityRecoveryDays: 0,
            weeklyMinutes: 350,
            hardSessions: 4,
            restDays: 0
        ))
        XCTAssertTrue(expectation.cautions.contains { $0.localizedCaseInsensitiveContains("descanso") })
        XCTAssertTrue(expectation.cautions.contains { $0.contains("RPE 8+") })
        XCTAssertTrue(expectation.cautions.contains { $0.localizedCaseInsensitiveContains("base tecnica") })
        XCTAssertFalse(expectation.bullets.isEmpty, "Siempre hay expectativas del objetivo")
    }

    func testPlanExpectationsBalancedPlanHasNoCautions() {
        let expectation = PlanExpectationEngine.expectations(for: PlanExpectationInput(
            objective: .general,
            experience: .intermediate,
            phase: .base,
            trainingDays: 4,
            performanceDays: 0,
            mobilityRecoveryDays: 1,
            weeklyMinutes: 200,
            hardSessions: 1,
            restDays: 3
        ))
        XCTAssertTrue(expectation.cautions.isEmpty)
        XCTAssertTrue(expectation.bullets.contains { $0.contains("200 min") })
    }

    // MARK: - Catalogo de rutinas pre-hechas

    func testPresetCatalogExercisesExistInLibrary() {
        for preset in PresetRoutineCatalog.all {
            for day in preset.dayTemplates {
                let parsed = TemplateCodec.parse(day.exercisesText)
                XCTAssertFalse(parsed.isEmpty, "\(preset.id)/\(day.focus) debe tener ejercicios")
                for exercise in parsed {
                    XCTAssertNotNil(
                        ExerciseLibrary.item(named: exercise.name),
                        "'\(exercise.name)' de \(preset.id) no existe en ExerciseLibrary"
                    )
                }
            }
        }
    }

    func testPresetCatalogSurvivesCodecRoundtrip() {
        for preset in PresetRoutineCatalog.all {
            for day in preset.dayTemplates {
                let parsed = TemplateCodec.parse(day.exercisesText)
                let reparsed = TemplateCodec.parse(TemplateCodec.serialize(parsed))
                XCTAssertEqual(parsed.count, reparsed.count, "\(preset.id)/\(day.focus) pierde ejercicios en roundtrip")
                for (a, b) in zip(parsed, reparsed) {
                    XCTAssertEqual(a.name, b.name)
                    XCTAssertEqual(a.sets, b.sets)
                    XCTAssertEqual(a.reps, b.reps)
                }
            }
        }
    }

    func testPresetCatalogRotationMatchesSplit() {
        for preset in PresetRoutineCatalog.all {
            let rotation = preset.splitType.focusRotation.count
            switch preset.splitType {
            case .fullBody:
                // Full body admite variantes A/B que rotan por indice.
                XCTAssertTrue((1...3).contains(preset.dayTemplates.count), preset.id)
            default:
                XCTAssertEqual(preset.dayTemplates.count, rotation, "\(preset.id): rotacion incompleta para su split")
            }
            XCTAssertFalse(preset.badge.isEmpty)
            XCTAssertFalse(preset.rationale.isEmpty)
        }
    }

    func testPresetCatalogIDsAreUniqueAndCustomIsEmpty() {
        let ids = PresetRoutineCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "IDs de preset duplicados")
        XCTAssertTrue(PresetRoutineCatalog.presets(for: .custom).isEmpty)
        // Cada split no-custom tiene al menos un preset.
        for split in SplitType.allCases where split != .custom {
            XCTAssertFalse(PresetRoutineCatalog.presets(for: split).isEmpty, "\(split.rawValue) sin presets")
        }
    }

    func testPresetHypertrophyPresetsUseModerateRepRanges() {
        // Los presets de hipertrofia deben vivir mayormente en 8-15 reps.
        for preset in PresetRoutineCatalog.all where preset.objective == .hypertrophy {
            let reps = preset.dayTemplates.flatMap { TemplateCodec.parse($0.exercisesText) }.map(\.reps)
            let inRange = reps.filter { (6...30).contains($0) }.count
            XCTAssertGreaterThanOrEqual(
                Double(inRange) / Double(max(reps.count, 1)), 0.8,
                "\(preset.id): un preset de hipertrofia no deberia ser mayormente <6 reps"
            )
        }
    }

    // MARK: - Coach de rutina (RoutineAssessmentEngine)

    private func week(strength: [Int], cardio: [Int] = []) -> [Int: DayAssignment] {
        var days: [Int: DayAssignment] = [:]
        for d in 1...7 { days[d] = .rest }
        for d in strength { days[d] = .template(UUID()) }
        for d in cardio { days[d] = .cardio("running") }
        return days
    }

    func testCoachFlagsZeroRestDaysAsUnsustainable() {
        let input = RoutineAssessmentInput(
            days: week(strength: [1, 2, 3, 4], cardio: [5, 6, 7]),
            splitType: .upperLower, goal: .mixed, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .unsustainable)
        XCTAssertTrue(result.headline.hasPrefix("Coach:"))
        XCTAssertFalse(result.evidence.isEmpty)
    }

    func testCoachCautionsSingleRestWithSixSessions() {
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 3, 5, 6], cardio: [4, 7]),
            splitType: .upperLower, goal: .mixed, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .caution)
        XCTAssertTrue(result.headline.localizedCaseInsensitiveContains("descanso"))
    }

    func testCoachCautionsBroSplitWithFewDays() {
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 4, 6]),
            splitType: .broSplit, goal: .strength, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .caution)
        XCTAssertTrue(result.detail.localizedCaseInsensitiveContains("2 veces por semana")
            || result.evidence.localizedCaseInsensitiveContains("volumen"))
    }

    func testCoachCautionsIncompleteRotation() {
        // PPL (3 focos) con solo 2 dias de fuerza: la rotacion no cierra.
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 5]),
            splitType: .pushPullLegs, goal: .strength, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .caution)
        XCTAssertTrue(result.headline.localizedCaseInsensitiveContains("rotacion"))
    }

    func testCoachBlessesBalancedWeekWithVariationReminder() {
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 4, 6], cardio: [3]),
            splitType: .fullBody, goal: .mixed, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .balanced)
        XCTAssertTrue(result.detail.localizedCaseInsensitiveContains("4-6 semanas"))
    }

    func testCoachRemindsVariationWhenPlanIsStale() {
        let created = Calendar.current.date(byAdding: .weekOfYear, value: -7, to: .now)
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 4, 6], cardio: [3]),
            splitType: .fullBody, goal: .mixed, planCreatedAt: created
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .balanced)
        XCTAssertTrue(result.headline.localizedCaseInsensitiveContains("variar"),
                      "Plan de 7 semanas debe recordar variar el estimulo")
    }

    func testCoachCautionsFourConsecutiveFullBodyDays() {
        let input = RoutineAssessmentInput(
            days: week(strength: [2, 3, 4, 5]),
            splitType: .fullBody, goal: .strength, planCreatedAt: nil
        )
        let result = RoutineAssessmentEngine.assess(input)
        XCTAssertEqual(result.verdict, .caution)
        XCTAssertTrue(result.detail.localizedCaseInsensitiveContains("48"))
    }

    func testCoachNeverMentionsInjuries() {
        // Regla AI_CONTEXT: cero lenguaje de lesiones en cualquier veredicto.
        let inputs: [RoutineAssessmentInput] = [
            RoutineAssessmentInput(days: week(strength: [1,2,3,4], cardio: [5,6,7]), splitType: .upperLower, goal: .mixed, planCreatedAt: nil),
            RoutineAssessmentInput(days: week(strength: [2,4,6]), splitType: .broSplit, goal: .strength, planCreatedAt: nil),
            RoutineAssessmentInput(days: week(strength: [2,4,6], cardio: [3]), splitType: .fullBody, goal: .mixed, planCreatedAt: nil)
        ]
        for input in inputs {
            let r = RoutineAssessmentEngine.assess(input)
            for text in [r.headline, r.detail, r.evidence] {
                XCTAssertFalse(text.localizedCaseInsensitiveContains("lesion"), "El coach no habla de lesiones: \(text)")
            }
        }
    }

    func testCanonicalTrainingDaysAreSpacedAndCounted() {
        for n in 2...6 {
            let days = WeeklyPlanOnboardingView.canonicalDays(for: n)
            XCTAssertEqual(days.count, n, "canonicalDays(\(n)) debe proponer \(n) dias")
            XCTAssertTrue(days.allSatisfy { (1...7).contains($0) })
        }
        // Con 3 dias o menos no debe haber dias consecutivos (48-72 h).
        for n in 2...3 {
            let days = WeeklyPlanOnboardingView.canonicalDays(for: n).sorted()
            for (a, b) in zip(days, days.dropFirst()) {
                XCTAssertGreaterThan(b - a, 1, "Con \(n) dias no deberia haber consecutivos")
            }
        }
    }

    // MARK: - Cobertura de libreria para el Desafio diario y rutinas ligeras

    /// Guardia: TODO ejercicio que emite el motor (challenges de cada tipo de
    /// dia, rutinas de movilidad de cada bucket y cardio de cada deporte) debe
    /// existir en `ExerciseLibrary` — si no, la UI cae a thumbnails genericos.
    func testDailyChallengeEmissionsExistInExerciseLibrary() {
        let engine = DailyChallengeEngine()
        var texts: [String] = []

        // Challenges para una semana representativa con todos los tipos de dia.
        let templateID = UUID()
        let week: [Int: DayAssignment] = [
            1: .rest,
            2: .template(templateID),
            3: .cardio("running"),
            4: .mobility,
            5: .template(templateID),
            6: .plyometrics,
            7: .rest
        ]
        let challenges = engine.generateChallenges(
            days: week,
            splitType: .upperLower,
            cardioSport: .running,
            templateFocus: [templateID: "Tren superior"]
        )
        texts += challenges.values.map(\.exercisesText)

        // Tambien con foco inferior para forzar el challenge de tren superior.
        let lowerID = UUID()
        let lowerWeek: [Int: DayAssignment] = [2: .template(lowerID), 5: .rest]
        texts += engine.generateChallenges(
            days: lowerWeek,
            splitType: .upperLower,
            cardioSport: nil,
            templateFocus: [lowerID: "Tren inferior"]
        ).values.map(\.exercisesText)

        // Rutinas de movilidad de todos los focos posibles.
        for hint in ["Tren superior", "Tren inferior", "Hombros", "Full body", nil] {
            texts.append(engine.mobilityRoutine(focusHint: hint).exercisesText)
        }

        // Cardio de todos los deportes.
        for sport in CardioSport.allCases {
            texts.append(engine.cardioRoutine(sport: sport, durationMinutes: 30).exercisesText)
        }

        // TODAS las variantes predefinidas del desafio (la rotacion por weekday
        // no garantiza cubrirlas via generateChallenges).
        texts += DailyChallengeEngine.lowerChallengeVariants
        texts += DailyChallengeEngine.upperChallengeVariants
        texts += DailyChallengeEngine.maintenancePacks.flatMap(\.variants)

        for text in texts {
            for exercise in TemplateCodec.parse(text) {
                XCTAssertNotNil(
                    ExerciseLibrary.item(named: exercise.name),
                    "'\(exercise.name)' emitido por DailyChallengeEngine no existe en ExerciseLibrary"
                )
            }
        }
    }

    // MARK: - Mecanica de ejercicios

    /// Cada ejercicio de la biblioteca debe tener mecanica: es lo que abre el
    /// boton "Ver mecanica" dentro de la sesion activa.
    func testEveryLibraryExerciseHasMechanics() {
        for item in ExerciseLibrary.items {
            XCTAssertNotNil(
                ExerciseMechanicsCatalog.mechanics(for: item.name),
                "'\(item.name)' no tiene mecanica en ExerciseMechanicsCatalog"
            )
        }
    }

    /// Al reves: el catalogo no debe describir ejercicios que ya no existen.
    func testMechanicsCatalogHasNoOrphanEntries() {
        for entry in ExerciseMechanicsCatalog.entries {
            XCTAssertNotNil(
                ExerciseLibrary.item(named: entry.exercise),
                "'\(entry.exercise)' tiene mecanica pero no existe en ExerciseLibrary"
            )
            XCTAssertFalse(entry.steps.isEmpty, "'\(entry.exercise)' no tiene pasos de ejecucion")
        }
    }

    /// Los fotogramas declarados deben existir en el bundle; si no, la vista
    /// mostraria un hueco en vez de la demostracion.
    func testMechanicsMediaFramesExistInBundle() {
        let bundle = Bundle(for: type(of: self))
        let appBundle = Bundle.main
        for entry in ExerciseMechanicsCatalog.entries where entry.mediaSlug != nil {
            for frame in entry.frameNames {
                let found = bundle.url(forResource: frame, withExtension: "jpg") != nil
                    || appBundle.url(forResource: frame, withExtension: "jpg") != nil
                XCTAssertTrue(found, "Falta el recurso \(frame).jpg de '\(entry.exercise)'")
            }
        }
    }

    // MARK: - Estres: promedio del dia vs ahora

    /// El hero y el entrypoint muestran el PROMEDIO del dia; el valor actual es
    /// la ultima hora medida y vive aparte. Este test fija esa separacion.
    func testStressDayProfileSeparatesAverageFromCurrent() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 12))!
        func hour(_ h: Int, _ value: Double, dayOffset: Int = 0) -> ActivationPoint {
            let base = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let date = calendar.date(bySettingHour: h, minute: 0, second: 0, of: base)!
            return ActivationPoint(date: date, value: value)
        }

        // Ayer no debe contaminar el promedio de hoy.
        let series = [
            hour(9, 2.0, dayOffset: -1),
            hour(8, 0.2),
            hour(10, 1.0),
            hour(12, 0.6)
        ]
        let profile = StressEngine().dayProfile(activation: series, now: today, calendar: calendar)

        XCTAssertEqual(profile.hours, 3)
        XCTAssertTrue(profile.hasEnoughData)
        // Promedio de 0.2, 1.0 y 0.6 = 0.6 -> indice 30.
        XCTAssertEqual(profile.average, 30)
        // El actual es la ULTIMA hora (12 h), no la mayor ni el promedio.
        XCTAssertEqual(profile.current, StressEngine.pressureIndex(0.6))
        XCTAssertEqual(profile.highest, StressEngine.pressureIndex(1.0))
        XCTAssertEqual(profile.lowest, StressEngine.pressureIndex(0.2))
        XCTAssertNotEqual(profile.average, profile.highest, "Promedio y pico no pueden ser lo mismo")
    }

    /// Con menos de 3 horas medidas no se afirma un promedio del dia: la UI cae
    /// al indice del dia en vez de inventar una media con dos puntos.
    func testStressDayProfileNeedsThreeHours() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 12))!
        let series = [
            ActivationPoint(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!, value: 0.5),
            ActivationPoint(date: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!, value: 0.7)
        ]
        let profile = StressEngine().dayProfile(activation: series, now: today, calendar: calendar)
        XCTAssertEqual(profile.hours, 2)
        XCTAssertFalse(profile.hasEnoughData)
        // Pero el valor ACTUAL si existe: la tarjeta "Estres ahora" debe poder
        // mostrarse en la madrugada, cuando el promedio del dia aun no aplica.
        XCTAssertNotNil(profile.current)
        XCTAssertNotNil(profile.highest)
        XCTAssertNotNil(profile.lowest)

        // Con una sola lectura sigue habiendo "ahora".
        let single = StressEngine().dayProfile(
            activation: [ActivationPoint(date: today, value: 0.9)],
            now: today,
            calendar: calendar
        )
        XCTAssertNotNil(single.current)
        XCTAssertFalse(single.hasEnoughData)

        let empty = StressEngine().dayProfile(activation: [], now: today, calendar: calendar)
        XCTAssertNil(empty.average)
        XCTAssertNil(empty.current)
        XCTAssertFalse(empty.hasEnoughData)
    }

    /// El indice esta acotado y las bandas usan los mismos cortes que el
    /// indice de estres del dia (para que el color no se contradiga).
    func testStressPressureIndexAndBands() {
        XCTAssertEqual(StressEngine.pressureIndex(0), 0)
        XCTAssertEqual(StressEngine.pressureIndex(2.0), 100)
        XCTAssertEqual(StressEngine.pressureIndex(3.0), 100, "Se satura, nunca pasa de 100")
        XCTAssertEqual(StressEngine.pressureIndex(1.0), 50)

        XCTAssertEqual(StressDayProfile.band(for: 10), .great)
        XCTAssertEqual(StressDayProfile.band(for: 45), .normal)
        XCTAssertEqual(StressDayProfile.band(for: 70), .attention)
        XCTAssertEqual(StressDayProfile.band(for: 90), .overload)
    }

    // MARK: - Reporte de la mañana

    private func morningSnapshot(daysAgo: Int, hrv: Double, rhr: Double, sleepHours: Double) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date(timeIntervalSince1970: 1_784_000_000))!,
            hrv: hrv,
            restingHeartRate: rhr,
            sleepHours: sleepHours,
            activeEnergy: 500,
            steps: 8_000,
            respiratoryRate: 14,
            workoutMinutes: 30
        )
    }

    /// El reporte se abre solo una vez al dia, y solo dentro de la ventana
    /// matutina: a las 8 de la noche ya no es un reporte de la mañana.
    func testMorningReportAutoPresentWindow() {
        let calendar = Calendar(identifier: .gregorian)
        func date(_ hour: Int, _ minute: Int = 0, day: Int = 15) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
        }
        let wake = 7 * 60

        // Justo al despertar: si.
        XCTAssertTrue(MorningReportEngine.shouldAutoPresent(
            now: date(7, 5), wakeMinutes: wake, lastShownKey: "", hasData: true, calendar: calendar
        ))
        // Antes de despertar: no, la noche aun no termina.
        XCTAssertFalse(MorningReportEngine.shouldAutoPresent(
            now: date(5, 30), wakeMinutes: wake, lastShownKey: "", hasData: true, calendar: calendar
        ))
        // Pasada la ventana (7:00 + 6 h): no.
        XCTAssertFalse(MorningReportEngine.shouldAutoPresent(
            now: date(20), wakeMinutes: wake, lastShownKey: "", hasData: true, calendar: calendar
        ))
        // Ya visto hoy: no se repite.
        let today = MorningReportEngine.dayKey(for: date(9), calendar: calendar)
        XCTAssertFalse(MorningReportEngine.shouldAutoPresent(
            now: date(9), wakeMinutes: wake, lastShownKey: today, hasData: true, calendar: calendar
        ))
        // Visto ayer: al dia siguiente vuelve a abrirse.
        let yesterday = MorningReportEngine.dayKey(for: date(9, 0, day: 14), calendar: calendar)
        XCTAssertTrue(MorningReportEngine.shouldAutoPresent(
            now: date(9), wakeMinutes: wake, lastShownKey: yesterday, hasData: true, calendar: calendar
        ))
        // Sin datos NO se abre: un reporte vacio no es un reporte.
        XCTAssertFalse(MorningReportEngine.shouldAutoPresent(
            now: date(9), wakeMinutes: wake, lastShownKey: "", hasData: false, calendar: calendar
        ))
    }

    /// El reporte no inventa: toma el factor que MAS resta y respeta el gate de
    /// noches del banco de sueño.
    func testMorningReportUsesWeakestFactorAndRespectsSleepBankGate() {
        let snapshot = morningSnapshot(daysAgo: 0, hrv: 42, rhr: 58, sleepHours: 6.2)
        let history = (1...5).map { morningSnapshot(daysAgo: $0, hrv: 60, rhr: 55, sleepHours: 7.8) }
        let scores = ScoreEngine().scores(for: snapshot, history: history)
        let brief = InsightEngine().briefing(snapshot: snapshot, history: history, scores: scores)

        let factors = [
            RecoveryFactor(name: "Sueño", value: "6.2 h", baseline: "7.5-8.2 h", contribution: -0.30, icon: "moon"),
            RecoveryFactor(name: "HRV", value: "42 ms", baseline: "55-65 ms", contribution: -0.12, icon: "waveform"),
            RecoveryFactor(name: "FC reposo", value: "58 lpm", baseline: "54-58", contribution: 0.05, icon: "heart")
        ]

        // Con 2 noches el banco no afirma nada.
        let thinBank = SleepBankEngine.Result(balanceHours: -3, nights: 2, goalHours: 8, nightly: [])
        let thin = MorningReportEngine.report(
            snapshot: snapshot, history: history, scores: scores,
            factors: factors, brief: brief, sleepBank: thinBank
        )
        XCTAssertEqual(thin.weakestFactorName, "Sueño")
        XCTAssertEqual(thin.weakestFactorBaseline, "7.5-8.2 h")
        XCTAssertNil(thin.sleep.bankBalanceHours, "Con menos de 3 noches el banco no debe mostrar saldo")
        XCTAssertEqual(thin.sleep.bankNights, 2)

        // Con 5 noches si.
        let fullBank = SleepBankEngine.Result(balanceHours: -4.5, nights: 5, goalHours: 8, nightly: [])
        let full = MorningReportEngine.report(
            snapshot: snapshot, history: history, scores: scores,
            factors: factors, brief: brief, sleepBank: fullBank
        )
        XCTAssertEqual(full.sleep.bankBalanceHours ?? 0, -4.5, accuracy: 0.001)

        // Si todos los factores suman, no se señala ninguno como culpable.
        let positive = MorningReportEngine.report(
            snapshot: snapshot, history: history, scores: scores,
            factors: [RecoveryFactor(name: "HRV", value: "70 ms", baseline: "55-65", contribution: 0.2, icon: "waveform")],
            brief: brief, sleepBank: fullBank
        )
        XCTAssertNil(positive.weakestFactorName)
    }

    /// Los tres anillos y la mini-grafica salen de datos reales, no de relleno.
    func testMorningReportRingsAndSleepTrendUseRealData() {
        let snapshot = morningSnapshot(daysAgo: 0, hrv: 55, rhr: 56, sleepHours: 7.0)
        let history = (1...9).map { morningSnapshot(daysAgo: $0, hrv: 58, rhr: 55, sleepHours: 7.5) }
        let scores = ScoreEngine().scores(for: snapshot, history: history)
        let brief = InsightEngine().briefing(snapshot: snapshot, history: history, scores: scores)
        let report = MorningReportEngine.report(
            snapshot: snapshot, history: history, scores: scores, factors: [],
            brief: brief, sleepBank: SleepBankEngine().assess(history: history, goalHours: 8)
        )

        // Los anillos muestran los MISMOS scores que Home.
        XCTAssertEqual(report.recoveryValue, scores.first { $0.kind == .recovery }?.value)
        XCTAssertEqual(report.sleepValue, scores.first { $0.kind == .sleep }?.value)
        XCTAssertEqual(report.strainValue, scores.first { $0.kind == .strain }?.value)

        // La serie del sparkline: como maximo 7 noches, en orden cronologico,
        // y la ultima es la de hoy.
        XCTAssertLessThanOrEqual(report.sleepTrendHours.count, 7)
        XCTAssertTrue(report.hasSleepTrend)
        XCTAssertEqual(report.sleepTrendHours.last ?? 0, 7.0, accuracy: 0.001)

        // El anillo de carga es porcentaje del objetivo y puede pasar de 100.
        XCTAssertEqual(
            report.loadPercentOfTarget,
            Int((brief.currentLoad / brief.targetLoad * 100).rounded())
        )

        // Sin noches suficientes no se dibuja la mini-grafica.
        let thin = MorningReportEngine.report(
            snapshot: snapshot, history: [], scores: scores, factors: [],
            brief: brief, sleepBank: SleepBankEngine().assess(history: [], goalHours: 8)
        )
        XCTAssertFalse(thin.hasSleepTrend)
    }

    /// El panel de señales solo muestra lo medido, con su rango personal, y
    /// normaliza SpO2 (HealthKit la entrega como fraccion o como porcentaje).
    func testMorningReportSignalsNormalizeAndSkipMissingData() {
        let base = Date(timeIntervalSince1970: 1_784_000_000)
        func day(_ offset: Int, spo2: Double?, hrv: Double?) -> DailyHealthSnapshot {
            DailyHealthSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: base)!,
                hrv: hrv,
                restingHeartRate: 55,
                sleepHours: 7.5,
                activeEnergy: 500,
                steps: 8_000,
                respiratoryRate: nil,
                workoutMinutes: 30,
                oxygenSaturation: spo2
            )
        }
        let history = (1...10).map { day($0, spo2: 0.95 + Double($0) * 0.004, hrv: 55) }
        let today = day(0, spo2: 0.97, hrv: 58)

        let signals = MorningReportEngine.signals(snapshot: today, history: history)
        let names = signals.map(\.name)

        // Respiracion no se midio: no debe aparecer inventada.
        XCTAssertFalse(names.contains("Respiración"))
        XCTAssertTrue(names.contains("HRV"))

        // SpO2 se muestra como porcentaje, no como 1 %.
        let spo2 = signals.first { $0.name == "SpO₂" }
        XCTAssertEqual(spo2?.value, "97")
        // Y su rango personal nunca puede pasar de 100 %.
        if let range = spo2?.range, let upper = range.split(separator: "–").last.flatMap({ Double($0) }) {
            XCTAssertLessThanOrEqual(upper, 100)
        } else {
            XCTFail("SpO2 deberia traer rango personal con 10 noches")
        }

        // La posicion en la banda esta acotada a 0...1.
        for signal in signals {
            if let position = signal.bandPosition {
                XCTAssertGreaterThanOrEqual(position, 0)
                XCTAssertLessThanOrEqual(position, 1)
            }
        }
    }

    /// El margen de carga nunca es negativo y refleja el objetivo del briefing.
    func testMorningReportStrainRoomMatchesBrief() {
        let snapshot = morningSnapshot(daysAgo: 0, hrv: 60, rhr: 55, sleepHours: 7.5)
        let history = (1...5).map { morningSnapshot(daysAgo: $0, hrv: 60, rhr: 55, sleepHours: 7.5) }
        let scores = ScoreEngine().scores(for: snapshot, history: history)
        let brief = InsightEngine().briefing(snapshot: snapshot, history: history, scores: scores)
        let report = MorningReportEngine.report(
            snapshot: snapshot, history: history, scores: scores, factors: [],
            brief: brief, sleepBank: SleepBankEngine().assess(history: history, goalHours: 8)
        )
        XCTAssertEqual(report.remainingLoad, brief.remainingLoad, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(report.remainingLoad, 0)
        XCTAssertEqual(report.targetLoad, brief.targetLoad, accuracy: 0.001)
    }

    // MARK: - Reproductor y mapa muscular

    /// El fundido debe sostenerse en los extremos y viajar suave entre ellos:
    /// con dos fotogramas es lo unico que evita el parpadeo.
    func testMechanicsPlayerBlendHoldsAtBothEnds() {
        let cycle = ExerciseMechanicsPlayer.cycleDuration
        let hold = ExerciseMechanicsPlayer.holdDuration

        XCTAssertEqual(ExerciseMechanicsPlayer.blend(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(ExerciseMechanicsPlayer.blend(at: hold * 0.9), 0, accuracy: 0.0001)
        XCTAssertEqual(ExerciseMechanicsPlayer.blend(at: cycle / 2), 1, accuracy: 0.0001)
        XCTAssertEqual(ExerciseMechanicsPlayer.blend(at: cycle / 2 + hold * 0.9), 1, accuracy: 0.0001)
        // Cierra el ciclo de vuelta en el fotograma inicial.
        XCTAssertEqual(ExerciseMechanicsPlayer.blend(at: cycle - 0.001), 0, accuracy: 0.01)

        // Monotona en el tramo de transicion (sin saltos ni rebotes).
        let travelStart = hold
        let travelEnd = cycle / 2
        var previous = -1.0
        for step in 0...20 {
            let t = travelStart + (travelEnd - travelStart) * Double(step) / 20
            let value = ExerciseMechanicsPlayer.blend(at: t)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    /// Un ciclo lento: si baja de 3 s vuelve a parecer parpadeo.
    func testMechanicsPlayerCycleIsSlowEnoughToRead() {
        XCTAssertGreaterThanOrEqual(ExerciseMechanicsPlayer.cycleDuration, 3.0)
        XCTAssertGreaterThan(ExerciseMechanicsPlayer.holdDuration, 0.5)
        XCTAssertLessThan(ExerciseMechanicsPlayer.holdDuration, ExerciseMechanicsPlayer.cycleDuration / 2)
    }

    /// Todo ejercicio con mecanica deberia decir que musculos trabaja (salvo los
    /// que no entrenan un musculo concreto, como la respiracion).
    func testMuscleMapCoversLibraryExceptNonMuscularWork() {
        let exempt: Set<String> = ["Respiracion diafragmatica", "Otro"]
        for item in ExerciseLibrary.items where !exempt.contains(item.name) {
            XCTAssertNotNil(
                MuscleMapCatalog.focus(for: item.name),
                "'\(item.name)' no tiene musculos asignados en MuscleMapCatalog"
            )
        }
        for name in exempt {
            XCTAssertNil(MuscleMapCatalog.focus(for: name))
        }
    }

    func testMuscleMapTableHasNoOrphanEntries() {
        for name in MuscleMapCatalog.table.keys {
            XCTAssertNotNil(
                ExerciseLibrary.item(named: name),
                "'\(name)' tiene musculos pero no existe en ExerciseLibrary"
            )
        }
    }

    /// Las laminas por musculo deben existir en el bundle; si falta una, el
    /// mapa se dibujaria sin el musculo en rojo y nadie lo notaria.
    func testMuscleMapAssetsExistInBundle() {
        let bundle = Bundle(for: type(of: self))
        func markup(_ name: String) -> String? {
            MuscleMapRenderer.svgMarkup(named: name, bundle: bundle)
                ?? MuscleMapRenderer.svgMarkup(named: name, bundle: .main)
        }
        XCTAssertNotNil(markup("body_front"))
        XCTAssertNotNil(markup("body_back"))
        for muscle in TargetMuscle.allCases {
            for id in muscle.overlayIDs {
                XCTAssertNotNil(markup("muscle_\(id)_main"), "Falta la lamina del musculo \(id) (\(muscle))")
            }
        }
    }

    /// Sin viewBox el SVG no escala y el mapa sale en blanco: hay que inyectarlo.
    func testMuscleMapSvgGetsViewBoxWhenMissing() {
        let markup = MuscleMapRenderer.normalized("<svg width=\"200\" height=\"369\" id=\"x\"><path/></svg>")
        XCTAssertTrue(markup.contains("viewBox=\"0 0 200 369\""))
        XCTAssertTrue(markup.contains("preserveAspectRatio"))

        // No se toca lo que ya trae viewBox.
        let already = "<svg viewBox=\"0 0 10 10\"><path/></svg>"
        XCTAssertEqual(MuscleMapRenderer.normalized(already), already)

        // Y los assets reales quedan escalables.
        let bundle = MuscleMapRenderer.svgMarkup(named: "body_front", bundle: Bundle(for: type(of: self))) != nil
            ? Bundle(for: type(of: self))
            : Bundle.main
        for name in ["body_front", "body_back", "muscle_10_main"] {
            let svg = MuscleMapRenderer.svgMarkup(named: name, bundle: bundle)
            XCTAssertNotNil(svg)
            XCTAssertTrue(svg?.contains("viewBox") == true, "\(name) sin viewBox: no escalaria")
        }
    }

    /// El compositor debe pintar en la vista frontal solo los musculos frontales
    /// (si no, el cuadriceps aparecia sobre la espalda).
    func testMuscleMapRendererPlacesMusclesOnTheRightSide() {
        // Las laminas viajan en el bundle de la app, no en el de tests.
        let bundle = MuscleMapRenderer.svgMarkup(named: "body_front", bundle: Bundle(for: type(of: self))) != nil
            ? Bundle(for: type(of: self))
            : Bundle.main
        let focus = MuscleFocus(primary: [.quads], secondary: [.glutes])
        let front = MuscleMapRenderer.html(focus: focus, side: .front, bundle: bundle)
        let back = MuscleMapRenderer.html(focus: focus, side: .back, bundle: bundle)

        // El rojo primario solo debe salir donde vive el cuadriceps.
        XCTAssertTrue(front.contains(MuscleMapRenderer.primaryColor))
        XCTAssertFalse(front.contains(MuscleMapRenderer.secondaryColor))
        XCTAssertTrue(back.contains(MuscleMapRenderer.secondaryColor))
        XCTAssertFalse(back.contains(MuscleMapRenderer.primaryColor))
        // Y el rojo quemado del asset original nunca debe sobrevivir.
        XCTAssertFalse(front.contains("#fc0000"))
        XCTAssertFalse(back.contains("#fc0000"))
    }

    func testExerciseLibraryHasCardioAndMobilityGroups() {
        let groups = Set(ExerciseLibrary.items.map(\.group))
        XCTAssertTrue(groups.contains("Cardio"), "Falta el grupo Cardio")
        XCTAssertTrue(groups.contains("Movilidad"), "Falta el grupo Movilidad")
        XCTAssertNotNil(ExerciseLibrary.item(named: "Step-ups"))
        XCTAssertNotNil(ExerciseLibrary.item(named: "Desplantes"))
    }

    // MARK: - Movilidad como recuperacion activa (descanso)

    func testCoachTreatsMobilityAsRestEquivalent() {
        // 5 dias de fuerza + 2 de movilidad: la movilidad ES la ventana de
        // recuperacion, no debe disparar "no veo dias de descanso".
        var days: [Int: DayAssignment] = [:]
        for d in 1...7 { days[d] = .rest }
        for d in [2, 3, 5, 6, 7] { days[d] = .template(UUID()) }
        days[1] = .mobility
        days[4] = .mobility
        let result = RoutineAssessmentEngine.assess(RoutineAssessmentInput(
            days: days, splitType: .broSplit, goal: .strength, planCreatedAt: nil
        ))
        XCTAssertNotEqual(result.verdict, .unsustainable, "Movilidad cuenta como recuperacion activa")
    }

    func testCoachStillFlagsSevenEffortDays() {
        // 7 dias de esfuerzo real (fuerza+cardio) sin descanso ni movilidad:
        // sigue siendo no sostenible.
        var days: [Int: DayAssignment] = [:]
        for d in [1, 2, 3, 4] { days[d] = .template(UUID()) }
        for d in [5, 6, 7] { days[d] = .cardio("running") }
        let result = RoutineAssessmentEngine.assess(RoutineAssessmentInput(
            days: days, splitType: .upperLower, goal: .mixed, planCreatedAt: nil
        ))
        XCTAssertEqual(result.verdict, .unsustainable)
    }

    func testIsRestEquivalentClassification() {
        XCTAssertTrue(RoutineAssessmentEngine.isRestEquivalent(.rest))
        XCTAssertTrue(RoutineAssessmentEngine.isRestEquivalent(.mobility))
        XCTAssertTrue(RoutineAssessmentEngine.isRestEquivalent(.recovery))
        XCTAssertFalse(RoutineAssessmentEngine.isRestEquivalent(.cardio("running")))
        XCTAssertFalse(RoutineAssessmentEngine.isRestEquivalent(.template(UUID())))
        XCTAssertFalse(RoutineAssessmentEngine.isRestEquivalent(.plyometrics))
    }

    func testChallengeDraftSourceIDIsStableSlug() {
        XCTAssertEqual(
            PlanGeneratedTemplates.challengeSourceID(focus: "Tren inferior"),
            "generated.challenge.tren.inferior"
        )
        XCTAssertEqual(
            PlanGeneratedTemplates.challengeSourceID(focus: "Movilidad general"),
            "generated.challenge.movilidad.general"
        )
        // Acentos normalizados: el slug no depende de tildes.
        XCTAssertEqual(
            PlanGeneratedTemplates.challengeSourceID(focus: "Recuperación"),
            "generated.challenge.recuperacion"
        )
    }

    func testRestDayChallengeRotatesMaintenanceAndMobility() {
        let engine = DailyChallengeEngine()
        // Semana solo con descansos: los challenges de descanso deben rotar
        // entre fortalecimiento (McGill/manana) y movilidad segun el weekday.
        var days: [Int: DayAssignment] = [:]
        for d in 1...7 { days[d] = .rest }
        let challenges = engine.generateChallenges(
            days: days, splitType: .fullBody, cardioSport: nil, templateFocus: [:]
        )
        let kinds = Set(challenges.values.map(\.kind))
        XCTAssertTrue(kinds.contains(.maintenance), "Debe haber dias de fortalecimiento de mantenimiento")
        XCTAssertTrue(kinds.contains(.mobility), "Debe seguir habiendo dias de movilidad")
        // Los de mantenimiento son fuerza: no vienen de los presets de movilidad.
        for challenge in challenges.values where challenge.kind == .maintenance {
            XCTAssertFalse(challenge.exercisesText.localizedCaseInsensitiveContains("Estiramiento"),
                           "Mantenimiento es fortalecimiento, no estiramiento")
        }
    }
    // MARK: - Catalogo de alimentos (regresion de la migracion a FoodCatalog)

    /// El catalogo salio de `NutritionEstimator` a `FoodCatalog` para que las
    /// recetas puedan componer platillos sumando alimentos reales. Estos valores
    /// estan CONGELADOS: cambiar un macro alteraria estimaciones que el usuario
    /// ya tiene guardadas en su historial.
    func testFoodCatalogKeepsOriginalMacrosFrozen() throws {
        let chicken = try XCTUnwrap(FoodCatalog.item(id: "chicken_breast"))
        XCTAssertEqual(chicken.calories, 180)
        XCTAssertEqual(chicken.protein, 31)
        XCTAssertEqual(chicken.carbs, 0)
        XCTAssertEqual(chicken.fat, 5)

        let beans = try XCTUnwrap(FoodCatalog.item(id: "beans"))
        XCTAssertEqual(beans.calories, 125)
        XCTAssertEqual(beans.protein, 8)

        let egg = try XCTUnwrap(FoodCatalog.item(id: "egg"))
        XCTAssertEqual(egg.calories, 78)
        XCTAssertEqual(egg.protein, 6)
    }

    /// La estimacion por texto debe dar exactamente lo mismo que antes de mover
    /// el catalogo. Es el guard de que la migracion fue mecanica.
    func testTextEstimationIsUnchangedAfterCatalogMigration() throws {
        let estimator = NutritionEstimator()

        let simple = try XCTUnwrap(estimator.estimate(from: "pollo con arroz"))
        XCTAssertEqual(simple.calories, 385)   // 180 + 205
        XCTAssertEqual(simple.protein, 35)     // 31 + 4
        XCTAssertEqual(simple.carbohydrates, 45)
        XCTAssertEqual(simple.confidence, .medium, "dos alimentos reconocidos")

        let scaled = try XCTUnwrap(estimator.estimate(from: "2 huevos"))
        XCTAssertEqual(scaled.calories, 156)   // 78 x 2
        XCTAssertEqual(scaled.protein, 12)

        let unknown = try XCTUnwrap(estimator.estimate(from: "algo que no existe"))
        XCTAssertEqual(unknown.confidence, .low, "sin alimentos reconocidos, confianza baja")
    }

    /// Todo alimento debe tener id unico y limites de porcion coherentes: el
    /// escalador de recetas depende de ambos.
    func testFoodCatalogIsInternallyConsistent() {
        let ids = FoodCatalog.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "hay ids duplicados en el catalogo")

        for food in FoodCatalog.items {
            XCTAssertFalse(food.tokens.isEmpty, "\(food.id) no tiene tokens y nunca se reconoceria")
            XCTAssertLessThan(food.minServings, food.maxServings, "\(food.id) tiene limites invertidos")
            XCTAssertGreaterThan(food.servingStep, 0, "\(food.id) tiene paso de porcion no positivo")
            XCTAssertTrue(food.nameKey.hasPrefix("food.name."), "\(food.id) no usa clave de localizacion")
        }
    }

    /// Los nombres de alimento se muestran en la UI de recetas, asi que tienen
    /// que estar traducidos: una clave sin traducir se ve como "food.name.tofu".
    func testFoodNamesAreLocalizedInBothLanguages() {
        defer { RecvelLanguageStore.save(.esMX) }
        for language in [AppLanguage.esMX, .english] {
            RecvelLanguageStore.save(language)
            for food in FoodCatalog.items {
                let name = RecvelL10n.text(food.nameKey)
                XCTAssertNotEqual(name, food.nameKey,
                                  "\(food.nameKey) sin traducir en \(language.rawValue)")
            }
        }
    }
    // MARK: - Recetas y escalado de porciones

    /// Una receta que apunte a un alimento inexistente no fallaria al compilar,
    /// solo se veria incompleta en pantalla. Este test lo convierte en error.
    func testEveryRecipeIngredientResolvesInFoodCatalog() {
        for recipe in MealRecipeCatalog.entries {
            XCTAssertFalse(recipe.components.isEmpty, "\(recipe.id) no tiene ingredientes")
            for component in recipe.components {
                XCTAssertNotNil(FoodCatalog.item(id: component.foodID),
                                "\(recipe.id) apunta a un alimento inexistente: \(component.foodID)")
            }
            XCTAssertFalse(recipe.stepKeys.isEmpty, "\(recipe.id) no tiene pasos")
        }
    }

    /// El banner y la pantalla no pueden contradecirse: cada platillo que el
    /// motor sabe nombrar debe tener receta. La excepcion documentada es
    /// `balancedPlate`, que es una instruccion ("a tu gusto"), no un platillo.
    func testEveryEngineDishHasARecipeExceptTheGenericFallback() {
        let engineKeys = [
            "nutrition.food.chickenBeansVegetables",
            "nutrition.food.tofuBeansRice",
            "nutrition.food.eggsBeansTortillas",
            "nutrition.food.yogurtFruit",
            "nutrition.food.eggsYogurtFruit",
            "nutrition.food.eggsBeansFruit",
            "nutrition.food.oatsSoySeeds",
            "nutrition.food.legumeBowl"
        ]
        for key in engineKeys {
            XCTAssertNotNil(MealRecipeCatalog.recipe(titleKey: key), "sin receta para \(key)")
        }
        XCTAssertNil(MealRecipeCatalog.recipe(titleKey: "nutrition.food.balancedPlate"),
                     "balancedPlate no debe tener receta: es una instruccion, no un platillo")
    }

    /// La garantia central: los totales son la SUMA de los ingredientes ya
    /// escalados, con tolerancia cero. Si alguna vez se interpolan o se copia el
    /// objetivo, este test cae.
    func testScaledMealTotalsAreExactlyTheSumOfItsIngredients() throws {
        let recipe = try XCTUnwrap(MealRecipeCatalog.recipe(id: "chicken-beans-vegetables"))
        let targets = NutritionPlanEngine().targets(for: NutritionProfile(setupCompleted: true), now: .now)
        let meal = MealPortionScaler.scale(
            recipe: recipe,
            mealType: .lunch,
            gap: MacroGap(calories: 1_500, protein: 80),
            targets: targets,
            remainingMeals: [.lunch, .dinner]
        )

        XCTAssertEqual(meal.totals.calories, meal.ingredients.reduce(0) { $0 + $1.calories })
        XCTAssertEqual(meal.totals.protein, meal.ingredients.reduce(0) { $0 + $1.protein })
        XCTAssertEqual(meal.totals.carbohydrates, meal.ingredients.reduce(0) { $0 + $1.carbohydrates })
        XCTAssertEqual(meal.totals.fat, meal.ingredients.reduce(0) { $0 + $1.fat })
    }

    /// Escalar al hueco del DIA daria un desayuno de 2 000 kcal a las 8 a.m.
    /// El reparto entre comidas es lo que lo evita.
    func testBreakfastDoesNotTryToCoverTheWholeDay() {
        let targets = NutritionPlanEngine().targets(for: NutritionProfile(setupCompleted: true), now: .now)
        let hugeGap = MacroGap(calories: targets.calories, protein: targets.protein)
        let target = MealPortionScaler.target(
            for: .breakfast,
            gap: hugeGap,
            targets: targets,
            remainingMeals: [.breakfast, .lunch, .dinner]
        )

        XCTAssertLessThanOrEqual(target.calories, Int(Double(targets.calories) * MealPortionScaler.maxCalorieShare))
        XCTAssertLessThanOrEqual(target.protein, MealPortionScaler.maxMealProtein)
        XCTAssertLessThan(target.calories, targets.calories / 2, "un desayuno no cubre medio dia")
    }

    /// Con el rango ya cubierto no se propone porcion cero ni saltarse la
    /// comida: la guia de copy prohibe culpabilizar por comer.
    func testSatisfiedGapStillProposesARealPortion() throws {
        let recipe = try XCTUnwrap(MealRecipeCatalog.recipe(id: "yogurt-fruit"))
        let targets = NutritionPlanEngine().targets(for: NutritionProfile(setupCompleted: true), now: .now)
        let meal = MealPortionScaler.scale(
            recipe: recipe,
            mealType: .snack,
            gap: MacroGap(calories: -400, protein: -20),
            targets: targets,
            remainingMeals: [.snack]
        )

        XCTAssertGreaterThan(meal.totals.calories, 0, "nunca una porcion vacia")
        XCTAssertTrue(meal.ingredients.allSatisfy { $0.servings > 0 })
        XCTAssertTrue(meal.caveatKeys.contains("recipe.caveat.aboveRange"))
    }

    /// Las alergias son exclusion dura: la pantalla lista ingredientes y ofrece
    /// registrarlos, asi que no basta con bajar el orden.
    func testAllergiesExcludeRecipesHard() {
        let dairyFree = MealRecipeCatalog.recipes(
            for: .breakfast, dietStyle: .vegetarian, excludingAllergens: ["lacteos"]
        )
        XCTAssertFalse(dairyFree.contains { $0.id == "eggs-yogurt-fruit" },
                       "yogurt griego tiene alergeno lacteo")

        let eggFree = MealRecipeCatalog.recipes(
            for: .breakfast, dietStyle: .vegetarian, excludingAllergens: ["huevo"]
        )
        XCTAssertFalse(eggFree.contains { $0.id == "eggs-beans-fruit" })

        // Sin alergias declaradas no se filtra nada.
        let all = MealRecipeCatalog.recipes(for: .breakfast, dietStyle: .vegetarian)
        XCTAssertFalse(all.isEmpty)
    }

    /// Cantidades que alguien pueda cocinar: nadie mide "1.37 tazas".
    func testPortionsAreRoundedToCookableAmounts() {
        XCTAssertEqual(MealPortionScaler.rounded(1.37, step: 0.5), 1.5)
        XCTAssertEqual(MealPortionScaler.rounded(2.2, step: 1), 2)
        XCTAssertEqual(MealPortionScaler.rounded(0.1, step: 0.5), 0.5, "nunca cero")
        XCTAssertEqual(ScaledIngredient.fraction(1.5), "1½")
        XCTAssertEqual(ScaledIngredient.fraction(0.5), "½")
        XCTAssertEqual(ScaledIngredient.fraction(2.0), "2")
    }

    /// Los macros del platillo no pueden depender del idioma.
    func testScaledMealMacrosAreIdenticalAcrossLanguages() throws {
        defer { RecvelLanguageStore.save(.esMX) }
        let recipe = try XCTUnwrap(MealRecipeCatalog.recipe(id: "tofu-beans-rice"))
        let targets = NutritionPlanEngine().targets(for: NutritionProfile(setupCompleted: true), now: .now)
        let gap = MacroGap(calories: 1_200, protein: 70)

        RecvelLanguageStore.save(.esMX)
        let spanish = MealPortionScaler.scale(recipe: recipe, mealType: .lunch, gap: gap,
                                              targets: targets, remainingMeals: [.lunch, .dinner])
        RecvelLanguageStore.save(.english)
        let english = MealPortionScaler.scale(recipe: recipe, mealType: .lunch, gap: gap,
                                              targets: targets, remainingMeals: [.lunch, .dinner])

        XCTAssertEqual(spanish.totals, english.totals)
    }

    /// Los pasos y resumenes se muestran en pantalla: sin traducir se verian
    /// como "recipe.tofuBeansRice.step.1".
    func testRecipeCopyIsLocalizedInBothLanguages() {
        defer { RecvelLanguageStore.save(.esMX) }
        for language in [AppLanguage.esMX, .english] {
            RecvelLanguageStore.save(language)
            for recipe in MealRecipeCatalog.entries {
                XCTAssertNotEqual(RecvelL10n.text(recipe.summaryKey), recipe.summaryKey,
                                  "\(recipe.summaryKey) sin traducir en \(language.rawValue)")
                for step in recipe.stepKeys {
                    XCTAssertNotEqual(RecvelL10n.text(step), step,
                                      "\(step) sin traducir en \(language.rawValue)")
                }
            }
        }
    }
    // MARK: - Recovery y carga previa

    /// Un dia duro ayer debe bajar Recovery hoy, aunque las señales autonomicas
    /// no lo hayan registrado todavia (en el estudio de rugby solo 4/6 mostraron
    /// FC elevada y 2/6 HRV reducida pese al efecto de grupo).
    func testHardPreviousDayLowersRecoveryWhenSignalsLookNormal() {
        let engine = ScoreEngine()
        let calendar = Calendar.current
        let today = Date()

        // Señales de hoy en su valor habitual: la HRV no acuso el golpe.
        func day(_ offset: Int, energy: Double, minutes: Double) -> DailyHealthSnapshot {
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: offset, to: today) ?? today,
                hrv: 58, restingHeartRate: 52, sleepHours: 7.5,
                activeEnergy: energy, steps: 8_000, respiratoryRate: 14,
                workoutMinutes: minutes
            )
        }

        let baseline = (2...9).map { day(-$0, energy: 600, minutes: 30) }
        let restedYesterday = baseline + [day(-1, energy: 600, minutes: 30)]
        let hardYesterday = baseline + [day(-1, energy: 1_600, minutes: 110)]
        let todaySnapshot = day(0, energy: 500, minutes: 0)

        let rested = engine.scores(for: todaySnapshot, history: restedYesterday)
            .first { $0.kind == .recovery }?.value ?? 0
        let hard = engine.scores(for: todaySnapshot, history: hardYesterday)
            .first { $0.kind == .recovery }?.value ?? 0

        XCTAssertLessThan(hard, rested, "un dia duro ayer deberia pesar hoy")
        XCTAssertGreaterThanOrEqual(rested - hard, 1)
    }

    /// El ajuste es MODESTO a proposito: HRV y FC en reposo ya reflejan el costo
    /// de ayer, asi que restar la carga entera contaria dos veces lo mismo.
    func testPriorLoadAdjustmentIsBounded() {
        let engine = ScoreEngine()
        let calendar = Calendar.current
        let today = Date()
        let brutal = (1...3).map { offset in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -offset, to: today) ?? today,
                hrv: 58, restingHeartRate: 52, sleepHours: 7.5,
                activeEnergy: 5_000, steps: 20_000, respiratoryRate: 14,
                workoutMinutes: 300
            )
        }
        let adjustment = engine.priorLoadAdjustment(
            history: brutal, before: today, hrvDeviation: 0, rhrDeviation: 0
        )
        XCTAssertLessThanOrEqual(abs(Double(adjustment)), ScoreEngine.maxPriorLoadPenalty)
        XCTAssertLessThan(adjustment, 0)
    }

    /// Si la HRV y la FC en reposo YA cayeron, el ajuste se atenua: el costo de
    /// ayer ya esta contado en esas desviaciones.
    func testPriorLoadDoesNotDoubleCountWhenSignalsAlreadyDropped() {
        let engine = ScoreEngine()
        let calendar = Calendar.current
        let today = Date()
        let hard = (1...3).map { offset in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -offset, to: today) ?? today,
                hrv: 58, restingHeartRate: 52, sleepHours: 7.5,
                activeEnergy: 2_000, steps: 14_000, respiratoryRate: 14,
                workoutMinutes: 150
            )
        }

        let signalsBlind = engine.priorLoadAdjustment(
            history: hard, before: today, hrvDeviation: 0, rhrDeviation: 0
        )
        let signalsAlreadyDropped = engine.priorLoadAdjustment(
            history: hard, before: today, hrvDeviation: -0.8, rhrDeviation: -0.8
        )

        XCTAssertLessThan(signalsBlind, 0)
        XCTAssertGreaterThan(signalsAlreadyDropped, signalsBlind,
                             "con las señales ya caidas el ajuste debe atenuarse")
    }

    /// Sin historial no hay nada que ajustar, y un dia tranquilo no penaliza.
    func testCalmPreviousDaysDoNotPenalizeRecovery() {
        let engine = ScoreEngine()
        let today = Date()
        XCTAssertEqual(
            engine.priorLoadAdjustment(history: [], before: today, hrvDeviation: 0, rhrDeviation: 0),
            0
        )

        let calendar = Calendar.current
        let calm = (1...3).map { offset in
            DailyHealthSnapshot(
                date: calendar.date(byAdding: .day, value: -offset, to: today) ?? today,
                hrv: 58, restingHeartRate: 52, sleepHours: 8,
                activeEnergy: 300, steps: 4_000, respiratoryRate: 14,
                workoutMinutes: 0
            )
        }
        XCTAssertEqual(
            engine.priorLoadAdjustment(history: calm, before: today, hrvDeviation: 0, rhrDeviation: 0),
            0,
            "un dia tranquilo no debe restar"
        )
    }
}
