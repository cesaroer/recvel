import XCTest
@testable import Recvel

/// Ciclo de vida de los planes generados: politica de borradores, prefill y
/// prompt de ajuste. Los `GeneratedPlanRecord` se instancian sin ModelContext
/// (mismo patron que el resto de @Model en estos tests).
final class NutritionPlanLibraryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RecvelLanguageStore.save(.esMX)
    }

    override func tearDown() {
        RecvelLanguageStore.save(.esMX)
        super.tearDown()
    }

    private func record(saved: Bool, createdAt: Date = .now, answersJSON: String = "{}") -> GeneratedPlanRecord {
        let record = GeneratedPlanRecord(modelName: "m", planJSON: "{}", answersJSON: answersJSON)
        record.createdAt = createdAt
        if saved { record.savedAt = createdAt }
        return record
    }

    func testPurgeableDraftsKeepsSavedPlans() {
        let draft = record(saved: false)
        let saved = record(saved: true)
        let legacy = record(saved: false, createdAt: Date(timeIntervalSince1970: 0))

        let purgeable = NutritionPlanDraftPolicy.purgeableDrafts(in: [draft, saved, legacy])

        XCTAssertEqual(purgeable.count, 2)
        XCTAssertTrue(purgeable.contains { $0 === draft })
        XCTAssertTrue(purgeable.contains { $0 === legacy })
        XCTAssertFalse(purgeable.contains { $0 === saved })
    }

    func testSalvageAnswersPrefersNewestRecordAndSkipsWhenStoreFilled() {
        let old = record(saved: false, createdAt: Date(timeIntervalSince1970: 1_000), answersJSON: "{\"old\":true}")
        let new = record(saved: true, createdAt: Date(timeIntervalSince1970: 2_000), answersJSON: "{\"new\":true}")

        let salvaged = NutritionPlanDraftPolicy.answersJSONToSalvage(
            records: [old, new],
            storeHasAnswers: false
        )
        XCTAssertEqual(salvaged, "{\"new\":true}")

        // Un store con datos ya es mas nuevo que cualquier registro.
        XCTAssertNil(NutritionPlanDraftPolicy.answersJSONToSalvage(
            records: [old, new],
            storeHasAnswers: true
        ))

        XCTAssertNil(NutritionPlanDraftPolicy.answersJSONToSalvage(records: [], storeHasAnswers: false))
    }

    func testAnswersStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "test.planAnswers.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: "test.planAnswers") }

        XCTAssertFalse(NutritionPlanAnswersStore.hasAnswers(defaults: defaults))
        XCTAssertNil(NutritionPlanAnswersStore.load(defaults: defaults))

        var answers = NutritionPlanAnswers()
        answers.pregnantOrLactating = true
        answers.planDays = 5
        NutritionPlanAnswersStore.save(answers, defaults: defaults)

        XCTAssertTrue(NutritionPlanAnswersStore.hasAnswers(defaults: defaults))
        let loaded = NutritionPlanAnswersStore.load(defaults: defaults)
        XCTAssertEqual(loaded?.pregnantOrLactating, true)
        XCTAssertEqual(loaded?.planDays, 5)
    }

    func testDefaultNameUsesTargetsAndDateInBothLanguages() {
        let targets = GeneratedNutritionPlan.MacroTargets(
            calories: 2200, protein: 150, carbohydrates: 230, fat: 70, hydrationLiters: 2.5
        )
        let date = Date(timeIntervalSince1970: 1_786_557_600)

        RecvelLanguageStore.save(.esMX)
        let spanish = NutritionPlanDraftPolicy.defaultName(
            targets: targets, date: date, locale: Locale(identifier: "es_MX")
        )
        XCTAssertTrue(spanish.hasPrefix("Plan 2200 kcal"), spanish)

        RecvelLanguageStore.save(.english)
        let english = NutritionPlanDraftPolicy.defaultName(
            targets: targets, date: date, locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(english.hasPrefix("2200 kcal plan"), english)
    }

    func testDisplayNamePrefersUserNameOverDefault() {
        let named = record(saved: true)
        named.name = "Semana de volumen"
        XCTAssertEqual(NutritionPlanDraftPolicy.displayName(for: named), "Semana de volumen")

        // Sin nombre y sin plan decodificable ("{}" no cumple el esquema):
        // cae a la fecha, nunca a un string vacio.
        let anonymous = record(saved: true)
        XCTAssertFalse(NutritionPlanDraftPolicy.displayName(for: anonymous).isEmpty)
    }

    func testAdjustmentPromptSectionInjectsFeedbackAndPreviousPlan() {
        let lines = GeminiPlanService.adjustmentPromptSection(
            feedback: "menos cena y mas proteina",
            previousPlanJSON: "{\"summary\":\"x\"}"
        )
        let joined = lines.joined(separator: "\n")
        XCTAssertTrue(joined.contains("menos cena y mas proteina"))
        XCTAssertTrue(joined.contains("PLAN ANTERIOR: {\"summary\":\"x\"}"))
        XCTAssertTrue(joined.contains("precautions"))
    }

    func testAdjustmentPromptSectionIsEmptyWithoutFeedback() {
        XCTAssertTrue(GeminiPlanService.adjustmentPromptSection(feedback: nil, previousPlanJSON: "{}").isEmpty)
        XCTAssertTrue(GeminiPlanService.adjustmentPromptSection(feedback: "   ", previousPlanJSON: "{}").isEmpty)
    }

    func testUITestSeedDecodesAndIsSaved() {
        let seed = GeneratedPlanRecord.uiTestSeed()
        XCTAssertTrue(seed.isSaved)
        let plan = seed.plan
        XCTAssertNotNil(plan)
        XCTAssertEqual(plan?.days.count, 1)
        XCTAssertEqual(plan?.days.first?.meals.count, 3)
        XCTAssertEqual(plan?.targets.calories, 2200)
    }
}
