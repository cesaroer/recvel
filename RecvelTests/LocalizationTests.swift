import XCTest
@testable import Recvel

final class LocalizationTests: XCTestCase {
    func testAutomaticLanguageUsesEnglishOnlyForEnglishSystems() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["es-MX"]), .esMX)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .esMX)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .esMX)
    }

    func testLanguagePreferencePersistsWithoutChangingRawIdentifiers() throws {
        let suite = "LocalizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        RecvelLanguageStore.save(.english, defaults: defaults)

        XCTAssertEqual(RecvelLanguageStore.load(defaults: defaults), .english)
        XCTAssertEqual(ScoreKind.strain.rawValue, "Strain")
        XCTAssertEqual(NutritionGoal.maintain.rawValue, "Mantener")
    }

    func testSemanticCopyResolvesInBothLanguages() {
        XCTAssertEqual(RecvelL10n.text("score.load.title", language: .esMX), "Carga")
        XCTAssertEqual(RecvelL10n.text("score.load.title", language: .english), "Load")
        XCTAssertEqual(RecvelL10n.text("bioage.title", language: .esMX), "Edad fisiológica")
        XCTAssertEqual(RecvelL10n.text("bioage.title", language: .english), "Physiological age")
        XCTAssertEqual(RecvelL10n.text("recovery.factors.title", language: .esMX), "Lo que influye en tu Recuperación")
        XCTAssertEqual(RecvelL10n.text("recovery.factors.title", language: .english), "What influences your Recovery")
        XCTAssertEqual(RecvelL10n.text("home.trainingWeek.title", language: .esMX), "Entrenamientos de la semana")

        let message = CopyMessage(key: "score.sleep.summary", values: ["hours": "7.5"])
        XCTAssertTrue(message.localized(language: .esMX).contains("7.5"))
        XCTAssertTrue(message.localized(language: .english).contains("7.5"))
    }

    func testEveryBuiltInJournalTagHasSpanishAndEnglishPresentation() {
        let originalLanguage = RecvelLanguageStore.load()
        defer { RecvelLanguageStore.save(originalLanguage) }

        for definition in JournalCatalog.builtIns {
            RecvelLanguageStore.save(.esMX)
            XCTAssertFalse(definition.localizedTitle.hasPrefix("journal.tag."), definition.id)
            XCTAssertFalse(definition.localizedSubtitle.hasPrefix("journal.tag."), definition.id)

            RecvelLanguageStore.save(.english)
            XCTAssertFalse(definition.localizedTitle.hasPrefix("journal.tag."), definition.id)
            XCTAssertFalse(definition.localizedSubtitle.hasPrefix("journal.tag."), definition.id)
        }
    }

    func testTrainingAdviceLocalizesWithoutChangingItsDecision() {
        let originalLanguage = RecvelLanguageStore.load()
        defer { RecvelLanguageStore.save(originalLanguage) }
        let planner = WeeklyRoutinePlanner()

        RecvelLanguageStore.save(.esMX)
        let spanish = planner.todayAdvice(recovery: 55, assignment: .cardio("Carrera"))
        RecvelLanguageStore.save(.english)
        let english = planner.todayAdvice(recovery: 55, assignment: .cardio("Run"))

        XCTAssertTrue(spanish.contains("reducir"))
        XCTAssertTrue(english.contains("reducing"))
    }

    func testScoresKeepTheSameNumbersAcrossLanguages() {
        let originalLanguage = RecvelLanguageStore.load()
        defer { RecvelLanguageStore.save(originalLanguage) }

        RecvelLanguageStore.save(.esMX)
        let spanish = ScoreEngine().scores(for: .demo, history: DailyHealthSnapshot.demoWeek)
        RecvelLanguageStore.save(.english)
        let english = ScoreEngine().scores(for: .demo, history: DailyHealthSnapshot.demoWeek)

        XCTAssertEqual(spanish.map(\.kind), english.map(\.kind))
        XCTAssertEqual(spanish.map(\.value), english.map(\.value))
        XCTAssertEqual(spanish.map(\.confidence), english.map(\.confidence))
        XCTAssertNotEqual(spanish.first?.summary, english.first?.summary)
    }

    @MainActor
    func testNutritionTargetsStayStableWhileRecommendationsTranslate() {
        let originalLanguage = RecvelLanguageStore.load()
        defer { RecvelLanguageStore.save(originalLanguage) }
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let profile = NutritionProfile(setupCompleted: true)
        let engine = NutritionPlanEngine()

        RecvelLanguageStore.save(.esMX)
        let spanishTargets = engine.targets(for: profile, now: now)
        let spanishPlan = engine.plan(for: profile, meals: [], context: .empty, now: now)
        RecvelLanguageStore.save(.english)
        let englishTargets = engine.targets(for: profile, now: now)
        let englishPlan = engine.plan(for: profile, meals: [], context: .empty, now: now)

        XCTAssertEqual(spanishTargets, englishTargets)
        XCTAssertNotEqual(spanishPlan.status, englishPlan.status)
        XCTAssertNotEqual(spanishPlan.nextMeal.detail, englishPlan.nextMeal.detail)
    }

    func testVersionOneSnapshotMigratesToSemanticIdentifiers() throws {
        let legacy: [String: Any] = [
            "version": 1,
            "dataMode": "Apple Health",
            "recovery": 73,
            "strain": 61,
            "sleep": 82,
            "energy": 70,
            "stressLabel": "Normal",
            "confidence": "Alta",
            "nextAction": "Protege tu ventana de sueno esta noche."
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let snapshot = try XCTUnwrap(RecvelSharedSnapshotStore.decoded(data))

        XCTAssertEqual(snapshot.version, RecvelSharedSnapshot.schemaVersion)
        XCTAssertEqual(snapshot.dataModeID, "common.appleHealth")
        XCTAssertEqual(snapshot.stressLevelID, "stress.level.normal")
        XCTAssertEqual(snapshot.confidenceID, "common.high")
        XCTAssertEqual(snapshot.nextActionID, "shared.action.sleep")
        XCTAssertEqual(snapshot.recovery, 73)
    }
}
