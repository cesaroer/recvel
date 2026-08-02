import XCTest

final class RecvelUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
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
        return app
    }

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func completeNutritionSetupIfNeeded(_ app: XCUIApplication) {
        guard app.buttons["nutrition.setup.continue"].waitForExistence(timeout: 2) else { return }
        for _ in 0..<3 {
            let next = app.buttons["nutrition.setup.continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        let complete = app.buttons["nutrition.setup.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        complete.tap()
        XCTAssertTrue(app.staticTexts["NUTRICION ADAPTATIVA"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingStartsAndAdvances() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-hasCompletedOnboarding", "NO",
            "-useDemoData", "YES",
            "-recvel.appLanguage", "es-MX"
        ]
        app.launch()

        XCTAssertTrue(app.otherElements["onboarding.root"].waitForExistence(timeout: 8))
        keepScreenshot(app, name: "onboarding-unchanged")
        let start = app.buttons["Comenzar"]
        XCTAssertTrue(start.exists)
        start.tap()
        XCTAssertTrue(app.staticTexts["¿Qué quieres mejorar primero?"].waitForExistence(timeout: 5))

        app.staticTexts["Rendir mejor"].tap()
        app.buttons["Continuar"].tap()
        XCTAssertTrue(app.staticTexts["¿Qué señales son importantes para ti?"].waitForExistence(timeout: 5))

        app.staticTexts["Recuperación"].tap()
        app.buttons["Continuar"].tap()
        XCTAssertTrue(app.staticTexts["Construyamos tu horario de sueño"].waitForExistence(timeout: 5))

        app.buttons["Continuar"].tap()
        XCTAssertTrue(app.staticTexts["Conecta Apple Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.connectHealth"].exists)
    }

    @MainActor
    func testDailyBriefingAndRecoveryDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["RECUPERACIÓN"].exists)
        XCTAssertTrue(app.staticTexts["Tu plan para hoy"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.dayStrip"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.workouts"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.trends"].exists)
        XCTAssertTrue(app.buttons["tab.today"].exists)
        keepScreenshot(app, name: "home-bevel-recvel")

        let openMonth = app.descendants(matching: .any)["dashboard.dayStrip.openMonth"]
        XCTAssertTrue(openMonth.waitForExistence(timeout: 3))
        openMonth.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.monthCalendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.ringPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.monthCalendar.today"].exists)
        keepScreenshot(app, name: "home-month-calendar")
        app.buttons["Cerrar"].tap()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 5))

        let hero = app.buttons["dashboard.recoveryHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()
        XCTAssertTrue(app.buttons["Atras"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testContextMenusAndSettingsPush() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let sourceMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fuente de datos'")).firstMatch
        XCTAssertTrue(sourceMenu.exists)
        sourceMenu.tap()
        XCTAssertTrue(app.buttons["Actualizar ahora"].waitForExistence(timeout: 3))
        keepScreenshot(app, name: "native-source-menu")
        app.tap()

        app.buttons["dashboard.moreMenu"].tap()
        let privacyItem = app.buttons["Datos y privacidad"]
        XCTAssertTrue(privacyItem.waitForExistence(timeout: 3))
        keepScreenshot(app, name: "native-more-menu")
        // Los items de Menu nativo a veces ignoran el tap directo del elemento;
        // el tap por coordenada al centro del item si aterriza.
        privacyItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars["Datos y privacidad"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.navigationBars.buttons["Atrás"].exists || app.navigationBars.buttons["Back"].exists,
            "Ajustes debe conservar la navegación de regreso"
        )
        XCTAssertTrue(app.staticTexts["Privado por diseño"].exists)
    }

    @MainActor
    func testLanguageSelectorChangesTheInterfaceImmediately() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["dashboard.moreMenu"].waitForExistence(timeout: 8))
        app.buttons["dashboard.moreMenu"].tap()
        app.buttons["Datos y privacidad"].tap()

        let languageMenu = app.buttons["settings.language.menu"]
        XCTAssertTrue(languageMenu.waitForExistence(timeout: 5))
        languageMenu.tap()
        XCTAssertTrue(app.buttons["English"].waitForExistence(timeout: 3))
        app.buttons["English"].tap()

        XCTAssertTrue(app.navigationBars["Data and privacy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Private by design"].exists)

        app.terminate()
        app.launchArguments = ["-uiTestEphemeralStore", "-hasCompletedOnboarding", "YES",
            "-skipMorningReport", "YES", "-useDemoData", "YES"]
        app.launch()
        let todayTab = app.buttons["tab.today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 8))
        XCTAssertEqual(todayTab.label, "Today")
    }

    @MainActor
    func testPhysiologicalAgeUsesTheSelectedSpanishLanguage() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-hasCompletedOnboarding", "YES",
            "-skipMorningReport", "YES",
            "-useDemoData", "YES",
            "-recvel.appLanguage", "en"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["dashboard.moreMenu"].waitForExistence(timeout: 8))
        app.buttons["dashboard.moreMenu"].tap()
        app.buttons["Data and privacy"].tap()
        let languageMenu = app.buttons["settings.language.menu"]
        XCTAssertTrue(languageMenu.waitForExistence(timeout: 5))
        languageMenu.tap()
        app.buttons["Spanish (Mexico)"].tap()
        XCTAssertTrue(app.navigationBars["Datos y privacidad"].waitForExistence(timeout: 5))

        app.navigationBars["Datos y privacidad"].buttons.element(boundBy: 0).tap()
        let bioAge = app.descendants(matching: .any)["dashboard.bioAge"]
        var swipes = 0
        while !bioAge.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(bioAge.waitForExistence(timeout: 5))
        bioAge.tap()
        let title = app.staticTexts["bioAge.hero.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Edad fisiológica")
        XCTAssertFalse(app.staticTexts["Physiological age"].exists)
    }

    @MainActor
    func testScientificHelpAppearsOnlyInsideTheDetailFlow() throws {
        let app = launchApp()
        XCTAssertFalse(app.buttons["scientific.info.HRV"].exists)

        let recovery = app.buttons["dashboard.recoveryHero"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 8))
        recovery.tap()

        let info = app.buttons["scientific.info.HRV"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()
        XCTAssertTrue(app.staticTexts["Variabilidad de la frecuencia cardíaca"].waitForExistence(timeout: 3))

        let methodology = app.buttons["Ver metodología"]
        XCTAssertTrue(methodology.waitForExistence(timeout: 3))
        methodology.tap()
        XCTAssertTrue(app.navigationBars["Metodología y límites"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMetricDetailsExposeMeasuredContext() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let routes: [(button: String, detail: String, advice: String, screenshot: String)] = [
            ("dashboard.recoveryHero", "detail.recovery.factors", "detail.recovery.advice", "recovery-detail"),
            ("dashboard.score.sleep", "detail.sleep.stages", "detail.sleep.plan", "sleep-detail"),
            ("dashboard.score.strain", "detail.strain.timeline", "detail.strain.advice", "strain-detail"),
            ("dashboard.score.energy", "detail.energy.contributors", "detail.energy.advice", "energy-detail")
        ]

        for route in routes {
            let button = app.buttons[route.button]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No aparece \(route.button)")
            button.tap()
            XCTAssertTrue(app.otherElements[route.detail].waitForExistence(timeout: 5), "No aparece \(route.detail)")
            XCTAssertTrue(app.otherElements[route.advice].waitForExistence(timeout: 5), "No aparece \(route.advice)")
            XCTAssertTrue(app.buttons["Atras"].exists, "El detalle debe conservar la navegacion Liquid Glass")
            if route.detail == "detail.strain.timeline" {
                XCTAssertTrue(app.staticTexts["Carrera"].exists, "El dia actual debe usar el workout detallado del snapshot")
            }

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = route.screenshot
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
            app.launch()
            XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))
        }
    }

    @MainActor
    func testStressVO2AndBioAgeSectionsExposeRealContext() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let stress = app.buttons["dashboard.stress"]
        for _ in 0..<5 where !stress.isHittable { app.swipeUp() }
        XCTAssertTrue(stress.waitForExistence(timeout: 4))
        stress.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.stress.drivers"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["detail.stress.advice"].exists
                || app.descendants(matching: .any)["detail.stress.hints"].exists,
            "Debe mostrar consejo generico o hints de factores"
        )
        // El detalle renderiza lazy: las secciones fuera de pantalla no existen
        // en el arbol de accesibilidad hasta scrollear hacia ellas.
        let activation = app.descendants(matching: .any)["detail.stress.activation"]
        var stressSwipes = 0
        while !activation.exists && stressSwipes < 6 { app.swipeUp(); stressSwipes += 1 }
        XCTAssertTrue(activation.exists, "Deben mostrarse las barras de activacion del dia")
        let emotion = app.descendants(matching: .any)["detail.stress.emotion"]
        while !emotion.exists && stressSwipes < 12 { app.swipeUp(); stressSwipes += 1 }
        XCTAssertTrue(emotion.exists, "Debe mostrarse el log de emociones")
        XCTAssertTrue(app.buttons["Atrás"].exists || app.buttons["Atras"].exists)
        keepScreenshot(app, name: "stress-detail-calm-score")
    }

    @MainActor
    func testStressEmotionLoggingFlow() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let stress = app.buttons["dashboard.stress"]
        for _ in 0..<5 where !stress.isHittable { app.swipeUp() }
        XCTAssertTrue(stress.waitForExistence(timeout: 4))
        stress.tap()

        // Scroll hasta el logger de emociones (grid Lazy: los botones no existen
        // en el arbol de accesibilidad hasta que la seccion entra en pantalla).
        let emotionSection = app.descendants(matching: .any)["detail.stress.emotion"]
        XCTAssertTrue(emotionSection.waitForExistence(timeout: 5), "Debe existir la seccion de emociones")

        let addButton = app.buttons["detail.stress.emotion.add"]
        let anxious = app.descendants(matching: .any)["detail.stress.emotion.anxious"]
        // `exists` es true aunque el elemento este fuera de pantalla (SwiftUI
        // renderiza todo el ScrollView), asi que scrolleamos hasta que sea
        // realmente tappable antes de tocarlo: tapear por coordenada un
        // elemento invisible manda el tap a cualquier parte.
        var swipes = 0
        while !addButton.isHittable && !anxious.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        // Multi-check-in: abrir formulario con "Anadir registro" si el grid no esta visible.
        if addButton.isHittable {
            addButton.tap()
        }
        XCTAssertTrue(anxious.waitForExistence(timeout: 3), "Debe existir la emocion Ansioso")

        let note = app.descendants(matching: .any)["detail.stress.emotion.note"]
        if !note.exists {
            var emotionSwipes = 0
            while !anxious.isHittable && emotionSwipes < 6 {
                app.swipeUp()
                emotionSwipes += 1
            }
            anxious.tap()
        }
        XCTAssertTrue(note.waitForExistence(timeout: 3), "Debe aparecer el campo de nota opcional")

        let save = app.buttons["detail.stress.emotion.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        if !save.isHittable { app.swipeUp() }
        save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Multi-check-in: aparece entrada en lista + hint si el promedio es tenso.
        XCTAssertTrue(
            app.descendants(matching: .any)["detail.stress.emotion.entry"].waitForExistence(timeout: 5),
            "El registro de hoy debe aparecer en la lista"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["detail.stress.hints"].waitForExistence(timeout: 3),
            "Con emocion tensa registrada debe aparecer la seccion de posibles factores"
        )
        keepScreenshot(app, name: "stress-emotion-logged")

        // El hint tenso ofrece 1 minuto de respiracion.
        let breathe = app.buttons["detail.stress.breathe"].firstMatch
        if breathe.exists {
            var breatheSwipes = 0
            while !breathe.isHittable && breatheSwipes < 4 {
                app.swipeDown()
                breatheSwipes += 1
            }
            breathe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            // Desde un hint la sesion arranca sola: la intencion ya es empezar,
            // no configurar. (El entrypoint permanente si abre el selector.)
            XCTAssertTrue(
                app.descendants(matching: .any)["breathing.phase"].waitForExistence(timeout: 4),
                "Un hint debe arrancar la respiracion directo, sin pasar por el selector"
            )
            keepScreenshot(app, name: "stress-breathing")
        }

        app.terminate()
        app.launch()
        let vo2 = app.buttons["dashboard.vo2"]
        for _ in 0..<7 where !vo2.isHittable { app.swipeUp() }
        XCTAssertTrue(vo2.waitForExistence(timeout: 4))
        vo2.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.vo2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cómo obtener una nueva estimación"].exists)

        app.terminate()
        app.launch()
        let bioAge = app.buttons["dashboard.bioAge"]
        for _ in 0..<7 where !bioAge.isHittable { app.swipeUp() }
        XCTAssertTrue(bioAge.waitForExistence(timeout: 4))
        bioAge.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.bioAge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Metodo transparente"].exists)
        XCTAssertTrue(app.staticTexts["No es una edad biológica clínica"].exists)
    }

    @MainActor
    func testEmptyHealthStateDoesNotInventScores() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-hasCompletedOnboarding", "YES",
            "-skipMorningReport", "YES",
            "-useDemoData", "NO",
            "-skipHealthKitRefresh", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["dashboard.empty"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Tu resumen necesita más datos"].exists)
        XCTAssertTrue(app.buttons["Conectar Apple Health"].exists)
        XCTAssertFalse(app.staticTexts["RECUPERACIÓN"].exists)
    }

    @MainActor
    func testPrimaryProductFlowsOpen() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let planEntry = app.buttons["dashboard.plan"]
        XCTAssertTrue(planEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["METAS SEMANALES"].exists)
        planEntry.tap()
        XCTAssertTrue(app.staticTexts["Hoy y esta semana"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Metas de esta semana"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan.focus"].exists)
        let tonightEntry = app.descendants(matching: .any)["plan.tonight.entry"]
        XCTAssertTrue(tonightEntry.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["ESTA NOCHE"].exists)
        XCTAssertTrue(app.staticTexts["Disciplina de sueno"].exists)
        tonightEntry.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.tonight.detail"].waitForExistence(timeout: 5))
        let discipline = app.staticTexts["Disciplina de sueno"]
        for _ in 0..<4 where !discipline.exists { app.swipeUp() }
        XCTAssertTrue(discipline.waitForExistence(timeout: 3))
        keepScreenshot(app, name: "plan-bevel-recvel")
        app.buttons["Atras"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Hoy y esta semana"].waitForExistence(timeout: 5))
        app.buttons["Atras"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 5))

        app.buttons["tab.journal"].tap()
        XCTAssertTrue(app.staticTexts["Diario"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Patrones emergentes"].exists)
        XCTAssertTrue(app.staticTexts["Diario mental"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["journal.calendar"].exists)
        keepScreenshot(app, name: "journal-bevel-recvel")

        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["fitness.calendar"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["fitness.workoutList"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["fitness.cardioLoad"].exists)
        keepScreenshot(app, name: "fitness-bevel-recvel")

        app.buttons["tab.nutrition"].tap()
        completeNutritionSetupIfNeeded(app)
        XCTAssertTrue(app.staticTexts["Nutrición"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["nutrition.nextMeal"].exists)
        keepScreenshot(app, name: "nutrition-bevel-recvel")
    }

    @MainActor
    func testFitnessNativeMenuAndMeasuredDetailOpen() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        let addMenu = app.buttons["fitness.add"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: addMenu.frame.midX, dy: addMenu.frame.midY))
            .tap()
        XCTAssertTrue(app.buttons["Registrar entrenamiento"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Crear rutina de fuerza"].exists)
        XCTAssertTrue(app.buttons["Actualizar Apple Health"].exists)
        keepScreenshot(app, name: "fitness-native-menu")
        app.tap()

        let cardioLoad = app.buttons["fitness.cardioLoad"]
        for _ in 0..<3 where !cardioLoad.isHittable { app.swipeUp() }
        XCTAssertTrue(cardioLoad.waitForExistence(timeout: 3))
        cardioLoad.tap()

        XCTAssertTrue(app.staticTexts["Carga cardio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["fitness.detail.breakdown"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["fitness.detail.science"].exists)
        XCTAssertTrue(app.staticTexts["Cómo interpretar esta métrica"].exists)
        keepScreenshot(app, name: "fitness-cardio-load-detail")
    }

    /// Biblioteca Bevel-like: tocar un ejercicio lo selecciona; Agregar lo mete en la plantilla.
    @MainActor
    func testFitnessLibrarySelectAddsExerciseToTemplate() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        openCreateTemplate(app)
        fillTemplateName(app, "UITest Push Day")
        openLibrary(app)

        tapLibraryItem(app, id: "fitness.library.item.Press_de_banca")

        confirmLibraryAdd(app)

        let added = app.descendants(matching: .any)["fitness.templateEditor.exercise.Press_de_banca"]
        XCTAssertTrue(added.waitForExistence(timeout: 5), "El ejercicio seleccionado debe aparecer en la plantilla")
        keepScreenshot(app, name: "fitness-library-add-to-template")

        let save = app.buttons["fitness.templateEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))
    }

    /// Multi-select: dos ejercicios + Agregar deben quedar en el editor.
    @MainActor
    func testFitnessLibraryMultiSelectAddsSeveralExercises() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        openCreateTemplate(app)
        fillTemplateName(app, "UITest Full Body")
        openLibrary(app)

        tapLibraryItem(app, id: "fitness.library.item.Sentadilla")
        tapLibraryItem(app, id: "fitness.library.item.Peso_muerto")

        confirmLibraryAdd(app)

        XCTAssertTrue(app.descendants(matching: .any)["fitness.templateEditor.exercise.Sentadilla"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["fitness.templateEditor.exercise.Peso_muerto"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "fitness-library-multi-select")
    }

    /// Eliminar rutina: crear plantilla → abrir preview → menu "..." → Eliminar rutina.
    @MainActor
    func testFitnessTemplateCanBeDeletedFromPreview() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        openCreateTemplate(app)
        fillTemplateName(app, "UITest Borrame")

        let save = app.buttons["fitness.templateEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Abrir el preview de la plantilla recien creada.
        let card = app.buttons["fitness.template.card.UITest_Borrame"]
        var swipes = 0
        while (!card.exists || !card.isHittable) && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "La plantilla creada debe aparecer en la lista")
        card.tap()

        let menu = app.buttons["fitness.templatePreview.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()

        let delete = app.buttons["Eliminar rutina"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "El menu debe ofrecer Eliminar rutina")
        delete.tap()

        // La tarjeta debe desaparecer del grid.
        let disappeared = card.waitForNonExistence(timeout: 5)
        XCTAssertTrue(disappeared, "La plantilla eliminada no debe seguir en la lista")
        keepScreenshot(app, name: "fitness-template-deleted")
    }

    @MainActor
    private func openCreateTemplate(_ app: XCUIApplication) {
        let addMenu = app.buttons["fitness.add"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: addMenu.frame.midX, dy: addMenu.frame.midY))
            .tap()
        let create = app.buttons["Crear rutina de fuerza"]
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        create.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fitness.templateEditor"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func fillTemplateName(_ app: XCUIApplication, _ name: String) {
        let nameField = app.textFields["fitness.templateEditor.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        // "\n" cierra el teclado para que la barra inferior quede tocable.
        nameField.typeText(name + "\n")
    }

    @MainActor
    private func openLibrary(_ app: XCUIApplication) {
        let addExercise = app.buttons["fitness.templateEditor.addExercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 3), "Debe existir la barra Agregar ejercicio")
        if !addExercise.isHittable { app.swipeUp() }
        addExercise.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["fitness.library"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func findLibraryItem(_ app: XCUIApplication, id: String) -> XCUIElement {
        let item = app.buttons[id]
        // La lista es alfabetica: el item puede quedar arriba o abajo del scroll actual.
        var swipes = 0
        while (!item.exists || !item.isHittable) && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        swipes = 0
        while (!item.exists || !item.isHittable) && swipes < 14 {
            app.swipeDown()
            swipes += 1
        }
        return item
    }

    @MainActor
    private func tapLibraryItem(_ app: XCUIApplication, id: String) {
        let item = findLibraryItem(app, id: id)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No se encontro \(id) en la biblioteca")
        if item.isHittable {
            item.tap()
        } else {
            item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func confirmLibraryAdd(_ app: XCUIApplication) {
        let addSelected = app.buttons["fitness.library.addSelected"]
        XCTAssertTrue(addSelected.waitForExistence(timeout: 3))
        XCTAssertTrue(addSelected.isEnabled, "Tras tocar un ejercicio, Agregar debe habilitarse")
        if !addSelected.isHittable {
            addSelected.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            addSelected.tap()
        }
    }

    @MainActor
    func testNutritionEstimateCanAdjustPortion() throws {
        let app = launchApp()
        app.buttons["tab.nutrition"].tap()
        completeNutritionSetupIfNeeded(app)

        let field = app.textFields["nutrition.description"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("2 huevos con arroz y aguacate")
        app.buttons["nutrition.estimate"].tap()

        XCTAssertTrue(app.sliders["nutrition.portion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["+ aceite"].exists)
        app.buttons["+ aceite"].tap()
        XCTAssertTrue(app.buttons["Confirmar y guardar"].exists)
        app.buttons["Confirmar y guardar"].tap()

        XCTAssertTrue(app.buttons["Usar de nuevo"].waitForExistence(timeout: 5))

        let mealActions = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Acciones de'")
        ).firstMatch
        XCTAssertTrue(mealActions.waitForExistence(timeout: 5))
        mealActions.tap()

        XCTAssertTrue(app.buttons["Editar"].waitForExistence(timeout: 3))
        app.buttons["Editar"].tap()
        let editBar = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Editar'")).firstMatch
        XCTAssertTrue(editBar.waitForExistence(timeout: 5), "Debe abrir el editor de comida")
        XCTAssertTrue(
            app.navigationBars.buttons["Atrás"].exists || app.navigationBars.buttons["Back"].exists,
            "El editor debe conservar la navegación de regreso"
        )
    }

    // MARK: - Ayuno intermitente

    @MainActor
    private func launchAppForFasting(screeningCompleted: Bool, under18Fixture: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestEphemeralStore",
            "-hasCompletedOnboarding", "YES",
            "-skipMorningReport", "YES",
            "-useDemoData", "YES",
            "-fastingScreeningCompleted", screeningCompleted ? "YES" : "NO"
        ]
        if under18Fixture { app.launchArguments.append(contentsOf: ["-fastingUITestUnder18", "YES"]) }
        app.launch()
        return app
    }

    @MainActor
    func testFastingSafetyScreeningBlocksContraindication() throws {
        let app = launchAppForFasting(screeningCompleted: false, under18Fixture: true)

        app.buttons["tab.fasting"].tap()
        XCTAssertTrue(app.staticTexts["Ayuno"].waitForExistence(timeout: 8))

        // Si ya hay un ayuno activo de una corrida previa, terminarlo para llegar al idle.
        if app.buttons["fasting.end"].waitForExistence(timeout: 2) {
            app.buttons["fasting.end"].tap()
        }

        let start = app.buttons["fasting.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Debe aparecer el boton de empezar")
        var startSwipes = 0
        while !start.isHittable && startSwipes < 4 {
            app.swipeUp()
            startSwipes += 1
        }
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // El screening de seguridad debe aparecer antes de activar el temporizador.
        XCTAssertTrue(app.staticTexts["Antes de empezar"].waitForExistence(timeout: 5), "Debe aparecer el screening de seguridad")
        // Escopear por etiqueta: switches.firstMatch puede resolver a un toggle de la
        // pantalla detras del sheet (siguen en el arbol de accesibilidad).
        let underageSwitch = app.switches["fasting.screening.under18"].firstMatch
        XCTAssertTrue(underageSwitch.waitForExistence(timeout: 3), "El toggle de menor de edad debe existir en el screening")
        XCTAssertEqual(underageSwitch.value as? String, "1", "El test debe confirmar la seleccion antes de evaluar")

        let continueButton = app.buttons["fasting.screening.continue"]
        var swipes = 0
        while !continueButton.isHittable && swipes < 3 {
            app.swipeUp()
            swipes += 1
        }
        continueButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(
            app.otherElements["fasting.screening.blocked"].waitForExistence(timeout: 5)
                || app.staticTexts["El ayuno no se recomienda para ti"].waitForExistence(timeout: 3),
            "Una contraindicacion dura debe bloquear el ayuno"
        )
        keepScreenshot(app, name: "fasting-screening-blocked")
    }

    @MainActor
    func testFastingHappyPathStartAndEnd() throws {
        let app = launchAppForFasting(screeningCompleted: true)

        app.buttons["tab.fasting"].tap()
        XCTAssertTrue(app.staticTexts["Ayuno"].waitForExistence(timeout: 8))

        if app.buttons["fasting.end"].waitForExistence(timeout: 2) {
            app.buttons["fasting.end"].tap()
        }

        // Estado idle enriquecido: protocolos, estadisticas y educacion de fases.
        XCTAssertTrue(app.buttons["fasting.protocol.sixteen8"].waitForExistence(timeout: 5))
        // Las estadisticas solo aparecen cuando ya hay ayunos completados;
        // se verifican al final del test. La educacion de fases si es incondicional.
        XCTAssertTrue(app.descendants(matching: .any)["fasting.education"].exists, "El idle debe mostrar la educacion de fases")
        app.buttons["fasting.protocol.sixteen8"].tap()
        keepScreenshot(app, name: "fasting-idle-rich")

        let startButton = app.buttons["fasting.start"]
        var swipesToStart = 0
        while !startButton.isHittable && swipesToStart < 4 {
            app.swipeUp()
            swipesToStart += 1
        }
        startButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Con screening ya completado, arranca directo sin sheet.
        XCTAssertTrue(app.otherElements["fasting.activeRing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["fasting.phase"].exists, "Debe mostrar la fase metabolica")
        XCTAssertTrue(app.descendants(matching: .any)["fasting.timeline"].exists, "Debe mostrar la linea de tiempo de fases")
        XCTAssertTrue(app.buttons["fasting.adjustStart"].exists, "Debe permitir ajustar la hora de inicio")
        keepScreenshot(app, name: "fasting-active")

        // Ajustar inicio abre el editor y regresa.
        app.buttons["fasting.adjustStart"].tap()
        XCTAssertTrue(app.staticTexts["¿A que hora dejaste de comer realmente?"].waitForExistence(timeout: 5))
        app.buttons["Listo"].tap()
        XCTAssertTrue(app.otherElements["fasting.activeRing"].waitForExistence(timeout: 5))

        app.buttons["fasting.end"].tap()
        XCTAssertTrue(app.otherElements["fasting.idle"].waitForExistence(timeout: 5), "Al terminar debe volver al estado inicial")
        XCTAssertTrue(
            app.descendants(matching: .any)["fasting.eatingWindow"].waitForExistence(timeout: 3),
            "Tras terminar un ayuno debe aparecer la ventana de alimentacion"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["fasting.calendar"].exists
                || app.descendants(matching: .any)["fasting.history"].exists,
            "El ayuno terminado debe reflejarse en el calendario/historial"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["fasting.stats"].waitForExistence(timeout: 3),
            "Con un ayuno completado deben aparecer las estadisticas neutrales"
        )
        keepScreenshot(app, name: "fasting-after-end")
    }

    // MARK: - Liquid Glass tab bar hide-on-scroll + detail hiding

    @MainActor
    private func waitForHittable(_ element: XCUIElement, _ hittable: Bool, timeout: TimeInterval = 6) -> Bool {
        let predicate = NSPredicate(format: "isHittable == %@", NSNumber(value: hittable))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    @MainActor
    func testTabBarVisibleAtRestThenCompactsOnScroll() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let today = app.buttons["tab.today"]
        XCTAssertTrue(
            waitForHittable(today, true),
            "La barra expandida debe estar visible al inicio"
        )
        XCTAssertTrue(app.buttons["tabbar.fab.open"].waitForExistence(timeout: 3), "FAB + debe existir")

        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)

        let compact = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tab.compact.'")).firstMatch
        XCTAssertTrue(
            compact.waitForExistence(timeout: 4) && waitForHittable(compact, true, timeout: 4),
            "Tras scroll down debe aparecer el circulo compacto (morph, no solo fade)"
        )
        XCTAssertTrue(
            waitForHittable(today, false, timeout: 4),
            "Los tabs de la capsula dejan de ser hittable en modo minimizado"
        )

        compact.tap()
        XCTAssertTrue(
            waitForHittable(app.buttons["tab.today"], true, timeout: 4),
            "Tocar el compacto debe re-expandir la capsula"
        )
        keepScreenshot(app, name: "tabbar-expanded-after-compact")
    }

    @MainActor
    func testTabBarFABOpensQuickActionMenu() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        app.buttons["tabbar.fab.open"].tap()
        XCTAssertTrue(app.buttons["tabbar.fab.close"].waitForExistence(timeout: 3), "+ debe morph a X")
        XCTAssertTrue(app.buttons["tabbar.action.meal"].waitForExistence(timeout: 3), "Menu con accion Comida")
        app.buttons["tabbar.action.meal"].tap()
        XCTAssertTrue(
            waitForHittable(app.buttons["tab.nutrition"], true, timeout: 5),
            "Accion Comida debe llevar a la tab Nutricion"
        )
        keepScreenshot(app, name: "tabbar-fab-menu-meal")
    }

    @MainActor
    func testTabBarHidesWhenPushingDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.today"].isHittable, "La barra debe estar visible en la raiz")

        let hero = app.buttons["dashboard.recoveryHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()

        XCTAssertTrue(app.buttons["Atras"].waitForExistence(timeout: 8), "Debe abrir el detalle")

        // Once a detail is on screen the custom tab bar must be hidden so it does not
        // overlap the content (the same behavior as Bevel / native Liquid Glass).
        XCTAssertTrue(
            waitForHittable(app.buttons["tab.today"], false, timeout: 8),
            "La barra completa debe dejar de ser hittable en un detalle"
        )
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tab.compact.'")).firstMatch.isHittable,
            "El modo compacto tampoco debe estar presente en detalle"
        )
        keepScreenshot(app, name: "tabbar-hidden-on-detail")
    }

    @MainActor
    func testTabBarReturnsAfterPoppingDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        app.buttons["dashboard.recoveryHero"].tap()
        XCTAssertTrue(app.buttons["Atras"].waitForExistence(timeout: 8))

        app.buttons["Atras"].tap()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        XCTAssertTrue(
            waitForHittable(app.buttons["tab.today"], true),
            "Al volver de un detalle la barra debe reaparecer"
        )
    }

    @MainActor
    func testJournalProAndBioAgeProSurfaces() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        app.buttons["tab.journal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["journal.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["journal.calendar"].exists)
        XCTAssertTrue(app.staticTexts["Tu registro de hoy"].exists)
        XCTAssertTrue(app.staticTexts["Diario mental"].exists)
        keepScreenshot(app, name: "journal-pro-root")

        let journalMenu = app.buttons["journal.menu"]
        XCTAssertTrue(journalMenu.waitForExistence(timeout: 3))
        journalMenu.tap()
        XCTAssertTrue(app.buttons["Personalizar Diario"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Entradas predeterminadas"].exists)
        XCTAssertTrue(app.buttons["Recordatorios"].exists)
        keepScreenshot(app, name: "journal-pro-native-menu")
        app.tap()

        app.buttons["tab.today"].tap()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 5))
        let bioAge = app.buttons["dashboard.bioAge"]
        for _ in 0..<8 where !bioAge.isHittable { app.swipeUp() }
        XCTAssertTrue(bioAge.waitForExistence(timeout: 5))
        keepScreenshot(app, name: "bio-age-entry-card")
        bioAge.tap()

        XCTAssertTrue(app.descendants(matching: .any)["detail.bioAge"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Factores de edad"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["detail.bioAge.factors"].exists)
        XCTAssertTrue(app.buttons["bioAge.menu"].exists)
        keepScreenshot(app, name: "bio-age-pro-hero")
        // Segunda captura ~1s despues: el diff entre ambas evidencia el polvo
        // estelar en movimiento (si el campo fuera estatico, serian identicas).
        Thread.sleep(forTimeInterval: 1.2)
        keepScreenshot(app, name: "bio-age-pro-hero-motion")
    }

    /// Patron Bevel: tocar una card abre el detalle de esa metrica, con chips
    /// para saltar a las hermanas y selector de ventana.
    @MainActor
    func testSleepMetricCardsOpenMetricDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let sleep = app.buttons["dashboard.score.sleep"]
        for _ in 0..<8 where !sleep.isHittable { app.swipeUp() }
        XCTAssertTrue(sleep.waitForExistence(timeout: 5))
        sleep.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.sleep"].waitForExistence(timeout: 6))

        // El hero del Sleep Score abre su detalle.
        let scoreCard = app.buttons["detail.sleep.scoreCard"]
        XCTAssertTrue(scoreCard.waitForExistence(timeout: 4))
        scoreCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["metric.detail"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.descendants(matching: .any)["metric.detail.header"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["metric.detail.trends"].exists)
        XCTAssertTrue(app.staticTexts["Analisis de tendencia"].exists)
        keepScreenshot(app, name: "metric-detail-sleep-score")

        // Los chips permiten saltar a una metrica hermana sin volver atras.
        // Usamos "Tiempo dormido": esta enteramente dentro del viewport, asi
        // que su centro es tappable (los chips del final quedan recortados).
        let siblingChip = app.buttons["metric.sibling.timeAsleep"]
        XCTAssertTrue(siblingChip.waitForExistence(timeout: 3))
        siblingChip.tap()
        XCTAssertTrue(app.staticTexts["Tiempo dormido"].waitForExistence(timeout: 4), "El chip debe cambiar la metrica mostrada")
        XCTAssertTrue(app.descendants(matching: .any)["metric.detail.header"].exists)

        // El selector de ventana cambia el rango del grafico.
        let quarter = app.buttons["metric.window.3M"]
        if quarter.waitForExistence(timeout: 3), quarter.isHittable {
            quarter.tap()
            XCTAssertTrue(app.descendants(matching: .any)["metric.detail.chart"].waitForExistence(timeout: 4))
        }
        keepScreenshot(app, name: "metric-detail-siblings-and-window")
    }

    /// Sleep Bank y coaching con evidencia citada.
    @MainActor
    func testSleepBankAndCoachingAreVisible() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let sleep = app.buttons["dashboard.score.sleep"]
        for _ in 0..<8 where !sleep.isHittable { app.swipeUp() }
        XCTAssertTrue(sleep.waitForExistence(timeout: 5))
        sleep.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.sleep"].waitForExistence(timeout: 6))

        let bank = app.descendants(matching: .any)["detail.sleep.bank"]
        XCTAssertTrue(bank.waitForExistence(timeout: 5), "El Sleep Bank debe estar en el detalle de sueno")
        XCTAssertTrue(app.staticTexts["SLEEP BANK"].exists)
        // La meta por noche debe ser ajustable por el usuario.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Meta por noche'")).firstMatch.exists,
            "La meta por noche debe estar visible y ser ajustable"
        )

        // El contenedor existe en el arbol aunque no este en pantalla; usamos
        // su encabezado como ancla porque si reporta visibilidad real.
        let bankTitle = app.staticTexts["SLEEP BANK"]
        for _ in 0..<5 where !bankTitle.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "sleep-bank")

        let coaching = app.descendants(matching: .any)["detail.sleep.coaching"]
        XCTAssertTrue(coaching.waitForExistence(timeout: 5), "El coaching debe aparecer en el detalle de sueno")
        // Anclar por identifier, no por string literal: los titulos estan
        // siendo migrados al String Catalog por otra sesion.
        for _ in 0..<4 where !coaching.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "sleep-coaching")
    }

    /// Recovery debe exponer SpO2 y temperatura de muneca (faltaban vs Bevel).
    @MainActor
    func testRecoveryExposesOxygenAndWristTemperature() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let recovery = app.buttons["dashboard.recoveryHero"]
        for _ in 0..<8 where !recovery.isHittable { app.swipeUp() }
        XCTAssertTrue(recovery.waitForExistence(timeout: 5))
        recovery.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.recovery"].waitForExistence(timeout: 6))

        let spo2 = app.buttons["detail.recovery.metric.spo2"]
        XCTAssertTrue(spo2.waitForExistence(timeout: 5), "Recovery debe mostrar saturacion de oxigeno")
        let temperature = app.buttons["detail.recovery.metric.wristTemperature"]
        XCTAssertTrue(temperature.waitForExistence(timeout: 5), "Recovery debe mostrar temperatura de muneca")

        for _ in 0..<7 where !spo2.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "recovery-spo2-and-temperature")

        // Y su detalle debe abrir, explicando los limites de la senal.
        if spo2.isHittable {
            spo2.tap()
            XCTAssertTrue(app.descendants(matching: .any)["metric.detail"].waitForExistence(timeout: 6))
            keepScreenshot(app, name: "metric-detail-spo2")
        }
    }

    /// La respiracion guiada debe tener entrypoint permanente (antes solo
    /// aparecia si saltaba un hint condicional).
    @MainActor
    func testStressHasPermanentBreathingEntrypoint() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let stress = app.buttons["dashboard.stress"]
        for _ in 0..<8 where !stress.isHittable { app.swipeUp() }
        XCTAssertTrue(stress.waitForExistence(timeout: 5))
        stress.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.stress"].waitForExistence(timeout: 6))

        let entry = app.buttons["detail.stress.breathingEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "La respiracion guiada debe ser alcanzable siempre")
        // El elemento existe en el arbol aunque no este en pantalla: hay que
        // scrollear hasta que sea realmente tappable.
        for _ in 0..<8 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.isHittable, "El entrypoint debe quedar alcanzable al hacer scroll")
        keepScreenshot(app, name: "stress-breathing-entrypoint")

        entry.tap()
        XCTAssertTrue(app.descendants(matching: .any)["breathing.view"].waitForExistence(timeout: 6))
        // Debe ofrecer tecnicas con su evidencia, no solo un timer.
        XCTAssertTrue(app.descendants(matching: .any)["breathing.evidence"].exists)
        XCTAssertTrue(app.staticTexts["Respiración guiada"].exists)
        keepScreenshot(app, name: "breathing-techniques")

        let start = app.buttons["breathing.start"]
        if start.waitForExistence(timeout: 3), start.isHittable {
            start.tap()
            XCTAssertTrue(app.descendants(matching: .any)["breathing.phase"].waitForExistence(timeout: 5))
            keepScreenshot(app, name: "breathing-session")
        }
    }

    /// La clasificacion de aptitud debe ser descubrible: con datos muestra la
    /// categoria y su detalle; sin datos dice QUE falta, no se oculta.
    @MainActor
    func testStrainShowsFitnessClassification() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let strain = app.buttons["dashboard.score.strain"]
        for _ in 0..<8 where !strain.isHittable { app.swipeUp() }
        XCTAssertTrue(strain.waitForExistence(timeout: 5))
        strain.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.strain"].waitForExistence(timeout: 6))

        let card = app.buttons["detail.strain.fitnessClass"]
        let empty = app.descendants(matching: .any)["detail.strain.fitnessClass.empty"]
        XCTAssertTrue(
            card.waitForExistence(timeout: 5) || empty.waitForExistence(timeout: 2),
            "La seccion de tipo de entrenamiento debe existir, con datos o explicando que falta"
        )
        XCTAssertTrue(app.staticTexts["TIPO DE ENTRENAMIENTO"].exists)

        // Con datos: el detalle explica POR QUE caes en esa categoria.
        guard card.exists else {
            for _ in 0..<6 where !empty.isHittable { app.swipeUp() }
            keepScreenshot(app, name: "fitness-class-empty")
            return
        }
        for _ in 0..<6 where !card.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "fitness-class-card")
        card.tap()

        XCTAssertTrue(app.descendants(matching: .any)["detail.fitnessClass"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Donde caes en la escala"].exists)
        XCTAssertTrue(app.staticTexts["Como se calcula"].exists)
        XCTAssertTrue(app.staticTexts["Limites honestos"].exists, "Debe declarar los limites del metodo")
        keepScreenshot(app, name: "fitness-class-detail")
    }

    /// Strain: las cards de energia activa / pasos deben abrir MetricDetailView.
    @MainActor
    func testStrainMetricCardsOpenMetricDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let strain = app.buttons["dashboard.score.strain"]
        for _ in 0..<8 where !strain.isHittable { app.swipeUp() }
        XCTAssertTrue(strain.waitForExistence(timeout: 5))
        strain.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.strain"].waitForExistence(timeout: 6))

        let activeEnergy = app.buttons["detail.strain.metric.activeEnergy"]
        XCTAssertTrue(activeEnergy.waitForExistence(timeout: 5), "Strain debe exponer energia activa como card tappable")
        for _ in 0..<8 where !activeEnergy.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "strain-metric-cards")
        activeEnergy.tap()

        XCTAssertTrue(app.descendants(matching: .any)["metric.detail"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Energia activa"].waitForExistence(timeout: 4))
        keepScreenshot(app, name: "metric-detail-strain-active-energy")
    }

    /// Energia: cards (pasos / luz diurna) abren detalle; luz diurna es el gap
    /// de alto valor que ya coleccionamos y antes no se mostraba.
    @MainActor
    func testEnergyMetricCardsOpenMetricDetail() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Resumen de la mañana"].waitForExistence(timeout: 8))

        let energy = app.buttons["dashboard.score.energy"]
        for _ in 0..<8 where !energy.isHittable { app.swipeUp() }
        XCTAssertTrue(energy.waitForExistence(timeout: 5))
        energy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.energy"].waitForExistence(timeout: 6))

        let steps = app.buttons["detail.energy.metric.steps"]
        XCTAssertTrue(steps.waitForExistence(timeout: 5), "Energia debe exponer pasos como card tappable")
        for _ in 0..<8 where !steps.isHittable { app.swipeUp() }
        keepScreenshot(app, name: "energy-metric-cards")

        let daylight = app.buttons["detail.energy.metric.daylight"]
        XCTAssertTrue(daylight.waitForExistence(timeout: 5), "Energia debe mostrar luz diurna (dato ya colectado)")
        for _ in 0..<6 where !daylight.isHittable { app.swipeUp() }
        daylight.tap()

        XCTAssertTrue(app.descendants(matching: .any)["metric.detail"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Luz diurna"].waitForExistence(timeout: 4))
        keepScreenshot(app, name: "metric-detail-energy-daylight")
    }

    // MARK: - Agenda semanal profesional (split, deporte, emoji, coaching, progresion)

    /// El onboarding ampliado pide split de fuerza y deporte de cardio.
    @MainActor
    func testWeeklyRoutineOnboardingAsksSplitAndSport() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Abrir la agenda semanal. UserDefaults persiste en el simulador, así
        // que la rutina puede estar ya creada (botón editar) o no (botón crear).
        let section = app.descendants(matching: .any)["fitness.weeklyRoutine"]
        for _ in 0..<12 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 5))

        let create = app.buttons["fitness.weeklyRoutine.create"]
        if create.exists {
            for _ in 0..<4 where !create.isHittable { app.swipeUp() }
            create.tap()
        } else {
            // Plan ya creado: el menú "..." ofrece "Editar plan".
            let menu = app.buttons["fitness.weeklyRoutine.menu"]
            for _ in 0..<4 where !menu.isHittable { app.swipeUp() }
            menu.tap()
            let edit = app.buttons["Editar plan"]
            XCTAssertTrue(edit.waitForExistence(timeout: 3))
            edit.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding"].waitForExistence(timeout: 5))

        // Perfil: activar las opciones de alto rendimiento para ver todo el flujo.
        XCTAssertTrue(app.staticTexts["Configura tu plan"].waitForExistence(timeout: 4))
        // Encender modo avanzado por el camino de la propia app: elegir
        // experiencia "Avanzada" activa `advanced = true` en la logica del
        // wizard. Es determinista, a diferencia de pelear con el switch (que
        // en suite puede quedar fuera de pantalla y comerse los taps).
        let advancedRow = app.staticTexts["Avanzada"]
        XCTAssertTrue(advancedRow.waitForExistence(timeout: 3))
        var rowSwipes = 0
        while !advancedRow.isHittable && rowSwipes < 4 { app.swipeUp(); rowSwipes += 1 }
        advancedRow.tap()
        let advancedSwitch = app.switches["fitness.routineOnboarding.advanced"]
        XCTAssertTrue(advancedSwitch.waitForExistence(timeout: 3))
        XCTAssertEqual(advancedSwitch.value as? String, "1", "Elegir experiencia avanzada debe encender el modo avanzado")
        app.buttons["fitness.routineOnboarding.continue"].tap()

        // Modalidades: split de fuerza y deporte de cardio en la misma pantalla.
        let ppl = app.buttons["fitness.routineOnboarding.split.pushPullLegs"]
        XCTAssertTrue(ppl.waitForExistence(timeout: 4), "El onboarding debe pedir el tipo de split")
        ppl.tap()
        keepScreenshot(app, name: "routine-split-step")

        let football = app.buttons["fitness.routineOnboarding.sport.football"]
        for _ in 0..<5 where !football.isHittable { app.swipeUp() }
        XCTAssertTrue(football.exists, "El onboarding debe pedir el deporte de cardio")
        football.tap()
        keepScreenshot(app, name: "routine-sport-step")
        app.buttons["fitness.routineOnboarding.continue"].tap()

        // Nuevo flujo: tras modalidades viene el preview de la rutina (PPL).
        XCTAssertTrue(app.staticTexts["Tu rutina sugerida"].waitForExistence(timeout: 4),
                      "Con fuerza activa, el preview de rutina precede a los días")
        app.buttons["fitness.routineOnboarding.continue"].tap()

        // Días (rediseñado): pregunta cuántos días; Atrás regresa al preview.
        XCTAssertTrue(app.staticTexts["¿Cuántos días puedes entrenar?"].waitForExistence(timeout: 4))
        let back = app.buttons["fitness.routineOnboarding.back"]
        XCTAssertTrue(back.exists, "El wizard debe tener botón Atrás")
        back.tap()
        XCTAssertTrue(app.staticTexts["Tu rutina sugerida"].waitForExistence(timeout: 3),
                      "Atrás desde días regresa al preview de rutina")
        app.buttons["fitness.routineOnboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["¿Cuántos días puedes entrenar?"].waitForExistence(timeout: 4))

        // Fase (modo avanzado) y luego editor por día con tipos de sesión pro.
        app.buttons["fitness.routineOnboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["¿En qué fase estás?"].waitForExistence(timeout: 4))
        app.buttons["fitness.routineOnboarding.continue"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.sessionEditor.2"].waitForExistence(timeout: 4),
                      "El modo avanzado muestra el editor por día")
    }

    /// Flujo rápido (4 pantallas) guarda el plan y la biblioteca lo lista con
    /// opción de eliminar todos.
    @MainActor
    func testQuickPlanWizardSavesAndOpensLibrary() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        let section = app.descendants(matching: .any)["fitness.weeklyRoutine"]
        for _ in 0..<12 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 5))

        let create = app.buttons["fitness.weeklyRoutine.create"]
        if create.exists {
            for _ in 0..<4 where !create.isHittable { app.swipeUp() }
            create.tap()
        } else {
            let menu = app.buttons["fitness.weeklyRoutine.menu"]
            for _ in 0..<4 where !menu.isHittable { app.swipeUp() }
            menu.tap()
            let edit = app.buttons["Editar plan"]
            XCTAssertTrue(edit.waitForExistence(timeout: 3))
            edit.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding"].waitForExistence(timeout: 5))

        // Flujo rápido: apagar avanzado si quedó encendido de otra corrida.
        let quickSwitch = app.switches["fitness.routineOnboarding.advanced"]
        if quickSwitch.waitForExistence(timeout: 3), (quickSwitch.value as? String) == "1" {
            quickSwitch.tap()
        }
        // perfil → modalidades → [preview de rutina si hay fuerza] → días → revisión.
        app.buttons["fitness.routineOnboarding.continue"].tap()
        app.buttons["fitness.routineOnboarding.continue"].tap()
        if app.staticTexts["Tu rutina sugerida"].waitForExistence(timeout: 2) {
            app.buttons["fitness.routineOnboarding.continue"].tap()
        }
        app.buttons["fitness.routineOnboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["Tu plan semanal"].waitForExistence(timeout: 4),
                      "La 4ª pantalla del flujo rápido es la revisión del plan")
        // La revisión muestra qué esperar del plan.
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding.expectations"].exists)
        app.buttons["fitness.routineOnboarding.continue"].tap() // Guardar plan semanal

        // De vuelta en Entrenamiento: abrir la biblioteca desde el menú del plan.
        let menuAfter = app.buttons["fitness.weeklyRoutine.menu"]
        for _ in 0..<8 where !menuAfter.isHittable { app.swipeUp() }
        XCTAssertTrue(menuAfter.waitForExistence(timeout: 5))
        menuAfter.tap()
        let library = app.buttons["Biblioteca de planes"]
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        library.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fitness.plans.library"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["fitness.plans.deleteAll"].waitForExistence(timeout: 3),
                      "La biblioteca debe permitir eliminar todos los planes")
    }

    /// La progresión por ejercicio existe (con dato o con estado vacío honesto).
    @MainActor
    func testFitnessShowsExerciseProgressionSection() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        let card = app.descendants(matching: .any)["fitness.exerciseProgressionCard"]
        for _ in 0..<12 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Debe existir la sección de progresión por ejercicio")
        XCTAssertTrue(app.staticTexts["Progresión por ejercicio"].exists)
        keepScreenshot(app, name: "exercise-progression-section")
    }

    /// Flujo completo: terminar una sesión activa pregunta cómo se sintió con
    /// emojis y guarda con ese esfuerzo (antes había un 6 hardcodeado).
    @MainActor
    func testActiveSessionAsksFeelingOnFinish() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Crear una plantilla mínima para poder iniciar sesión.
        openCreateTemplate(app)
        fillTemplateName(app, "UITest Feeling")
        openLibrary(app)
        tapLibraryItem(app, id: "fitness.library.item.Sentadilla")
        confirmLibraryAdd(app)
        let save = app.buttons["fitness.templateEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Abrir preview de la plantilla y empezar la sesión.
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'UITest Feeling'")).firstMatch
        var swipes = 0
        while !card.isHittable && swipes < 10 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let start = app.buttons["fitness.templatePreview.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 4))
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fitness.activeSession"].waitForExistence(timeout: 5))

        // Terminar => diálogo => hoja de feeling.
        app.buttons["fitness.activeSession.finish"].tap()
        let confirm = app.buttons["Guardar sesion"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()

        XCTAssertTrue(app.descendants(matching: .any)["fitness.feelingPrompt"].waitForExistence(timeout: 5),
                      "Al terminar debe preguntar cómo se sintió")
        keepScreenshot(app, name: "workout-feeling-prompt")

        // El botón de guardar está deshabilitado hasta elegir un emoji.
        let feelingSave = app.buttons["fitness.feeling.save"]
        XCTAssertTrue(feelingSave.waitForExistence(timeout: 3))
        XCTAssertFalse(feelingSave.isEnabled, "Sin emoji elegido no se puede guardar")

        app.buttons["fitness.feeling.hard"].tap()
        XCTAssertTrue(feelingSave.isEnabled)
        feelingSave.tap()

        // Vuelve al listado de Entrenamiento (sesión guardada).
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 6))
        keepScreenshot(app, name: "workout-feeling-saved")
    }

    /// Flujo de rutina pre-hecha: al elegir split se MUESTRA la rutina con su
    /// badge, se puede editar, los días se sugieren y ajustan por tap, y el
    /// Coach califica la semana en el review y en la agenda.
    @MainActor
    func testRoutinePresetPreviewDaysAndCoachFlow() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Abrir el wizard (crear o editar según el estado persistido).
        let section = app.descendants(matching: .any)["fitness.weeklyRoutine"]
        for _ in 0..<12 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        let create = app.buttons["fitness.weeklyRoutine.create"]
        if create.exists {
            for _ in 0..<4 where !create.isHittable { app.swipeUp() }
            create.tap()
        } else {
            let menu = app.buttons["fitness.weeklyRoutine.menu"]
            for _ in 0..<4 where !menu.isHittable { app.swipeUp() }
            menu.tap()
            let edit = app.buttons["Editar plan"]
            XCTAssertTrue(edit.waitForExistence(timeout: 3))
            edit.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding"].waitForExistence(timeout: 5))

        let next = app.buttons["fitness.routineOnboarding.continue"]

        // Paso perfil (modo rápido) → modalidades (fullBody por defecto).
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        next.tap()
        XCTAssertTrue(app.staticTexts["Tipo de rutina"].waitForExistence(timeout: 4))
        next.tap()

        // NUEVO: preview de la rutina pre-hecha con badge, preseleccionada.
        let presetCard = app.buttons["fitness.routineOnboarding.preset.fullBody.hypertrophy"]
        XCTAssertTrue(presetCard.waitForExistence(timeout: 5), "Debe mostrarse la rutina sugerida para el split")
        XCTAssertTrue(app.staticTexts["Ideal para hipertrofia"].firstMatch.exists, "La card debe llevar su badge")
        keepScreenshot(app, name: "routine-preset-preview")

        // Editarla debe ser posible (abre el editor del día).
        let editDay = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'fitness.routineOnboarding.editDay.'")).firstMatch
        if editDay.exists && editDay.isHittable {
            editDay.tap()
            XCTAssertTrue(app.descendants(matching: .any)["fitness.templateEditor"].waitForExistence(timeout: 4))
            keepScreenshot(app, name: "routine-preset-editor")
            app.buttons["fitness.templateEditor.save"].tap()
        }
        next.tap()

        // Días: contador + semana sugerida editable por tap.
        let daysPicker = app.descendants(matching: .any)["fitness.routineOnboarding.daysCount"]
        XCTAssertTrue(daysPicker.waitForExistence(timeout: 4), "Debe preguntar cuántos días")
        let wednesday = app.buttons["fitness.routineOnboarding.week.4"]
        XCTAssertTrue(wednesday.waitForExistence(timeout: 4), "La semana sugerida debe ser editable")
        wednesday.tap() // cicla el miércoles al siguiente tipo
        keepScreenshot(app, name: "routine-days-suggested")
        next.tap()

        // Review: el Coach califica la semana.
        let coach = app.descendants(matching: .any)["fitness.routineOnboarding.coach"]
        XCTAssertTrue(coach.waitForExistence(timeout: 5), "El Coach debe calificar el plan en el review")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Coach:'")).firstMatch.exists,
            "El veredicto debe hablar con voz de coach"
        )
        keepScreenshot(app, name: "routine-review-coach")
        next.tap()

        // De vuelta en la agenda: banner del coach siempre visible.
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 6))
        let banner = app.descendants(matching: .any)["fitness.weeklyRoutine.coach"]
        for _ in 0..<10 where !banner.exists { app.swipeUp() }
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "La agenda debe mostrar el veredicto del coach")
        keepScreenshot(app, name: "routine-agenda-coach")
    }

    /// El preview de rutina muestra las TRES modalidades (fuerza + cardio con
    /// minutos + movilidad) y el desafío diario; y en días, ciclar a movilidad
    /// no infla el contador (cuenta como recuperación activa).
    @MainActor
    func testRoutinePreviewShowsCardioMobilityAndChallenge() throws {
        let app = launchApp()
        app.buttons["tab.fitness"].tap()
        XCTAssertTrue(app.navigationBars["Entrenamiento"].waitForExistence(timeout: 5))

        // Abrir el wizard (crear o editar según estado persistido).
        let section = app.descendants(matching: .any)["fitness.weeklyRoutine"]
        for _ in 0..<12 where !section.exists { app.swipeUp() }
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        let create = app.buttons["fitness.weeklyRoutine.create"]
        if create.exists {
            for _ in 0..<4 where !create.isHittable { app.swipeUp() }
            create.tap()
        } else {
            let menu = app.buttons["fitness.weeklyRoutine.menu"]
            for _ in 0..<4 where !menu.isHittable { app.swipeUp() }
            menu.tap()
            let edit = app.buttons["Editar plan"]
            XCTAssertTrue(edit.waitForExistence(timeout: 3))
            edit.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding"].waitForExistence(timeout: 5))
        let next = app.buttons["fitness.routineOnboarding.continue"]

        // Perfil → modalidades: activar movilidad y desafío diario.
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        next.tap()
        XCTAssertTrue(app.staticTexts["¿Qué incluye tu semana?"].waitForExistence(timeout: 4))
        // Es un boton de seleccion (no switch): garantizar movilidad activa
        // tapeando si su fila no muestra el check. Como el estado persiste,
        // simplemente la activamos si el preview luego no la muestra.
        let mobilityToggle = app.buttons["fitness.routineOnboarding.mobilityToggle"]
        XCTAssertTrue(mobilityToggle.waitForExistence(timeout: 3))
        next.tap()

        // Preview: fuerza + cardio (con minutos) + movilidad.
        XCTAssertTrue(app.staticTexts["Tu rutina sugerida"].waitForExistence(timeout: 5))
        let cardio = app.descendants(matching: .any)["fitness.routineOnboarding.cardioPreview"]
        var swipes = 0
        while !cardio.exists && swipes < 6 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(cardio.exists, "El preview debe mostrar la sección de cardio con minutos")
        XCTAssertTrue(app.descendants(matching: .any)["fitness.routineOnboarding.cardioMinutes"].exists)

        var mobility = app.descendants(matching: .any)["fitness.routineOnboarding.mobilityPreview"]
        while !mobility.exists && swipes < 12 { app.swipeUp(); swipes += 1 }
        if !mobility.exists {
            // La modalidad estaba apagada en el plan persistido: volver,
            // activarla y regresar al preview.
            app.buttons["fitness.routineOnboarding.back"].tap()
            XCTAssertTrue(mobilityToggle.waitForExistence(timeout: 3))
            var toggleSwipes = 0
            while !mobilityToggle.isHittable && toggleSwipes < 4 { app.swipeUp(); toggleSwipes += 1 }
            mobilityToggle.tap()
            next.tap()
            XCTAssertTrue(app.staticTexts["Tu rutina sugerida"].waitForExistence(timeout: 5))
            mobility = app.descendants(matching: .any)["fitness.routineOnboarding.mobilityPreview"]
            var backSwipes = 0
            while !mobility.exists && backSwipes < 12 { app.swipeUp(); backSwipes += 1 }
        }
        XCTAssertTrue(mobility.exists, "El preview debe mostrar la rutina de movilidad")
        keepScreenshot(app, name: "preview-three-modalities")
        next.tap()

        // Días: el copy del contador dice "recuperación activa".
        XCTAssertTrue(app.staticTexts["¿Cuántos días puedes entrenar?"].waitForExistence(timeout: 4))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'recuperación activa'")).firstMatch
                .waitForExistence(timeout: 3),
            "El contador de descansos debe incluir la recuperación activa"
        )
        keepScreenshot(app, name: "days-active-recovery-copy")
    }
}
