import XCTest

final class NutritionAssistantUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartOpensThePlanQuestionnaireFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-hasCompletedOnboarding", "YES",
            "-skipMorningReport", "YES",
            "-useDemoData", "YES",
            "-recvel.appLanguage", "es-MX"
        ]
        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["tab.nutrition"].waitForExistence(timeout: 8))
        app.buttons["tab.nutrition"].tap()
        completeNutritionSetupIfNeeded(app)

        XCTAssertTrue(app.buttons["nutrition.planEntry"].waitForExistence(timeout: 8))
        app.buttons["nutrition.planEntry"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["nutrition.assistant"].waitForExistence(timeout: 8))
        let start = app.buttons["nutrition.assistant.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertTrue(start.label.localizedCaseInsensitiveContains("Empezar"))
        start.tap()

        let flow = app.descendants(matching: .any)["planflow.root"]
        XCTAssertTrue(flow.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["planflow.apiKey"].waitForExistence(timeout: 4)
                || app.descendants(matching: .any)["planflow.questionnaire.planflow.health.eyebrow"].waitForExistence(timeout: 4)
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["tabbar"].isHittable,
            "La barra de tabs no debe interferir con el flujo del plan"
        )
    }

    @MainActor
    private func completeNutritionSetupIfNeeded(_ app: XCUIApplication) {
        guard app.buttons["nutrition.setup.continue"].waitForExistence(timeout: 2) else { return }
        for _ in 0..<3 {
            let next = app.buttons["nutrition.setup.continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 6))
            next.tap()
        }
        let complete = app.buttons["nutrition.setup.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 6))
        complete.tap()
    }
}
