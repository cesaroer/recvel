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

    /// La generacion real necesita red y API key, asi que el ciclo de vida se
    /// prueba con un plan guardado sembrado por `-uiTestSeedSavedNutritionPlan`:
    /// la seccion existe, abre el visor del plan y el borrado la vacia.
    @MainActor
    func testSavedPlanOpensViewerAndDeleteRemovesSection() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-uiTestSeedSavedNutritionPlan",
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

        // La seccion vive bajo "Plan de mañana": bajar hasta encontrarla.
        let section = app.descendants(matching: .any)["nutrition.savedPlans"]
        for _ in 0..<6 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 8))

        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Plan de prueba")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        row.tap()

        // Visor: directo al resultado, con hero y sin cuestionario.
        XCTAssertTrue(app.descendants(matching: .any)["planflow.result"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["planflow.plan"].exists)

        // Atras en el visor = salir (plan guardado: sin dialogo de descarte).
        app.buttons.matching(NSPredicate(format: "label == %@", "Atrás")).firstMatch.tap()
        for _ in 0..<6 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 8))

        // Menu de la fila -> Eliminar -> confirmar -> la seccion desaparece.
        let menuButton = app.descendants(matching: .any)
            .matching(identifier: "nutrition.savedPlans")
            .descendants(matching: .button)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Acciones de"))
            .firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 4))
        menuButton.tap()
        let delete = app.buttons["Eliminar"]
        XCTAssertTrue(delete.waitForExistence(timeout: 4))
        delete.tap()
        let confirm = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()

        XCTAssertFalse(section.waitForExistence(timeout: 3))
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
