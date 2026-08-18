import XCTest
@testable import Recvel

final class NutritionAssistantTests: XCTestCase {
    func testSafetyFlagsCaptureClinicalContraindications() {
        var answers = NutritionPlanAnswers()
        answers.pregnantOrLactating = true
        answers.eatingDisorderHistory = true
        answers.menstrualCycle = .irregular
        answers.conditions = [.kidneyDisease, .diabetes, .hypertension]
        answers.medications = [.warfarin, .levothyroxine, .metformin, .statins]

        XCTAssertEqual(
            Set(answers.safetyFlags),
            [
                "pregnancy",
                "eatingDisorder",
                "menstrualIrregular",
                "kidneyDisease",
                "diabetes",
                "hypertension",
                "warfarin",
                "levothyroxine",
                "metformin",
                "statins"
            ]
        )
    }

    func testSafetyFlagsStayEmptyWhenHealthy() {
        var answers = NutritionPlanAnswers()
        answers.conditions = [.none]
        answers.medications = [.none]
        XCTAssertTrue(answers.safetyFlags.isEmpty)
    }

    func testWeightCyclingFlagsWithoutInventedPsychologicalChips() {
        var answers = NutritionPlanAnswers()
        answers.weightLossHistory = .many
        answers.barriers = [.time]
        XCTAssertTrue(answers.safetyFlags.contains("weightCycling"))
        XCTAssertFalse(answers.safetyFlags.contains("emotionalEating"))
    }

    func testScoffCutoffIsTwoOrMoreYesAnswers() {
        var answers = NutritionPlanAnswers()
        answers.scoffSick = true
        answers.scoffControl = false
        answers.scoffOneStone = false
        answers.scoffFat = false
        answers.scoffFood = false
        XCTAssertEqual(answers.scoffScore, 1)
        XCTAssertFalse(answers.scoffPositive)

        answers.scoffControl = true
        XCTAssertEqual(answers.scoffScore, 2)
        XCTAssertTrue(answers.scoffPositive)
        XCTAssertTrue(answers.safetyFlags.contains("scoffPositive"))
    }

    func testWeeklyBingeAndDrivenExerciseSurfaceAsFlags() {
        var answers = NutritionPlanAnswers()
        answers.bingeFrequency = .weeklyOrMore
        answers.drivenExercise = true
        XCTAssertTrue(answers.safetyFlags.contains("weeklyBinge"))
        XCTAssertTrue(answers.safetyFlags.contains("drivenExercise"))
    }

    func testScoffUnansweredDoesNotCountAsPositive() {
        let answers = NutritionPlanAnswers()
        XCTAssertFalse(answers.scoffAnswered)
        XCTAssertFalse(answers.scoffPositive)
        XCTAssertFalse(answers.safetyFlags.contains("scoffPositive"))
        XCTAssertFalse(answers.filledAdvancedPlan)
    }

    func testAdvancedPlanIsOptionalAndDoesNotInventFlags() {
        var answers = NutritionPlanAnswers()
        answers.conditions = [.none]
        answers.medications = [.none]
        XCTAssertFalse(answers.filledAdvancedPlan)
        XCTAssertTrue(answers.safetyFlags.isEmpty)
    }

    func testAnyAdvancedFieldMarksTheOptionalSectionAsFilled() {
        var answers = NutritionPlanAnswers()
        answers.weightLossHistory = .once
        XCTAssertTrue(answers.filledAdvancedPlan)
        XCTAssertFalse(answers.safetyFlags.contains("weightCycling"))
    }

    func testLegacyAnswersJSONStillDecodesWithoutHistory() throws {
        let json = """
        {"conditions":["none"],"medications":["none"],"occupation":"sedentary"}
        """
        let answers = try JSONDecoder().decode(
            NutritionPlanAnswers.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(answers.conditions, [.none])
        XCTAssertNil(answers.weightLossHistory)
        XCTAssertTrue(answers.barriers.isEmpty)
    }

    func testGeminiFeaturedPicksFlashLiteAndPro() {
        let models = [
            GeminiModelInfo(id: "gemini-2.0-flash", displayName: "Flash", summary: "", inputTokenLimit: 1),
            GeminiModelInfo(id: "gemini-2.5-flash-lite-preview-06-17", displayName: "Lite preview", summary: "", inputTokenLimit: 1),
            GeminiModelInfo(id: "gemini-2.5-flash-lite", displayName: "Lite", summary: "", inputTokenLimit: 1),
            GeminiModelInfo(id: "gemini-2.5-pro", displayName: "Pro", summary: "", inputTokenLimit: 1),
            GeminiModelInfo(id: "gemini-2.5-flash", displayName: "Flash 2.5", summary: "", inputTokenLimit: 1)
        ]
        let featured = GeminiModelInfo.featured(from: models)
        XCTAssertEqual(featured.map(\.id), ["gemini-2.5-flash-lite", "gemini-2.5-pro"])
        XCTAssertEqual(GeminiModelInfo.defaultSelection(from: models)?.id, "gemini-2.5-flash-lite")
        XCTAssertEqual(models[2].shortLabel, "2.5 Flash Lite")
        XCTAssertEqual(models[3].shortLabel, "2.5 Pro")
    }

    func testContextBuilderSendsRecentWorkoutsAndSkipsOldOnes() {
        let calendar = Calendar.current
        let recent = FitnessActivityLog(
            startDate: calendar.date(byAdding: .day, value: -12, to: .now) ?? .now,
            activityName: "Fuerza",
            category: "strength",
            durationMinutes: 62,
            perceivedEffort: 7
        )
        let old = FitnessActivityLog(
            startDate: calendar.date(byAdding: .day, value: -120, to: .now) ?? .now,
            activityName: "Sesion vieja",
            category: "strength",
            durationMinutes: 40,
            perceivedEffort: 5
        )
        let habit = HabitLog(
            date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now,
            habit: "alcohol",
            answer: true,
            tagID: "alcohol"
        )
        let habit2 = HabitLog(
            date: calendar.date(byAdding: .day, value: -4, to: .now) ?? .now,
            habit: "alcohol",
            answer: false,
            tagID: "alcohol"
        )
        let context = PlanContextBuilder.make(
            history: [],
            scores: [],
            workouts: [recent, old],
            habits: [habit, habit2],
            journal: [],
            meals: [],
            emotions: [],
            readiness: [],
            routine: WeeklyRoutine()
        )
        let text = context.lines.joined(separator: "\n")
        XCTAssertTrue(text.contains("Fuerza"))
        XCTAssertFalse(text.contains("Sesion vieja"))
        XCTAssertTrue(text.contains("alcohol 1/2"))
    }

    func testGeminiFilterKeepsTextModelsAndDropsSpecialists() {
        XCTAssertTrue(
            GeminiPlanService.isUsableTextModel(
                id: "models/gemini-2.5-flash",
                methods: ["generateContent", "countTokens"]
            )
        )
        XCTAssertTrue(
            GeminiPlanService.isUsableTextModel(
                id: "gemini-2.0-pro",
                methods: ["generateContent"]
            )
        )
        XCTAssertFalse(
            GeminiPlanService.isUsableTextModel(
                id: "models/text-embedding-004",
                methods: ["embedContent"]
            )
        )
        XCTAssertFalse(
            GeminiPlanService.isUsableTextModel(
                id: "models/gemini-embedding-001",
                methods: ["embedContent", "generateContent"]
            )
        )
        XCTAssertFalse(
            GeminiPlanService.isUsableTextModel(
                id: "gemini-2.0-flash-preview-image-generation",
                methods: ["generateContent"]
            )
        )
        XCTAssertFalse(
            GeminiPlanService.isUsableTextModel(
                id: "models/aqa",
                methods: ["generateAnswer", "generateContent"]
            )
        )
        XCTAssertFalse(
            GeminiPlanService.isUsableTextModel(
                id: "models/veo-2.0",
                methods: ["generateContent"]
            )
        )
    }
}
