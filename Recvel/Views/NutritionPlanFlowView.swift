import SwiftData
import SwiftUI

// MARK: - Flujo del plan de nutricion con IA
//
// Recorrido: API key (si falta) -> 3 pasos + modelo en chips + Plan avanzado
// opcional -> generacion -> plan + chat. Gemini recibe wearables, entrenos,
// journal y comidas que la app ya tiene.
//
// Mantiene la estetica clara de `NutritionAssistantView`: es la misma
// superficie de producto, con el orbe como protagonista en la generacion.
struct NutritionPlanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var profiles: [NutritionProfile]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]
    @Query(sort: \GeneratedPlanRecord.createdAt, order: .reverse) private var planRecords: [GeneratedPlanRecord]
    @Query(sort: \FitnessActivityLog.startDate, order: .reverse) private var activityLogs: [FitnessActivityLog]
    @Query(sort: \HabitLog.date, order: .reverse) private var habitLogs: [HabitLog]
    @Query(sort: \MentalJournalEntry.date, order: .reverse) private var journalEntries: [MentalJournalEntry]
    @Query(sort: \MealLog.createdAt, order: .reverse) private var mealLogs: [MealLog]
    @Query(sort: \EmotionLog.date, order: .reverse) private var emotionLogs: [EmotionLog]
    @Query(sort: \TrainingReadinessCheckIn.date, order: .reverse) private var readinessLogs: [TrainingReadinessCheckIn]

    @StateObject private var health = HealthDataProvider()

    private enum Stage {
        case apiKey
        case questionnaire
        case generating
        case result
    }

    private enum QuestionStep: Int, CaseIterable {
        case health, activity, preferences

        var eyebrowKey: String {
            switch self {
            case .health: "planflow.health.eyebrow"
            case .activity: "planflow.activity.eyebrow"
            case .preferences: "planflow.prefs.eyebrow"
            }
        }

        var titleKey: String {
            switch self {
            case .health: "planflow.health.title"
            case .activity: "planflow.activity.title"
            case .preferences: "planflow.prefs.title"
            }
        }

        var detailKey: String {
            switch self {
            case .health: "planflow.health.detail"
            case .activity: "planflow.activity.detail"
            case .preferences: "planflow.prefs.detail"
            }
        }
    }

    @State private var stage: Stage = .apiKey
    @State private var apiKeyInput = ""
    @State private var revealAPIKey = false
    @State private var resolvedAPIKey: String?
    @State private var models: [GeminiModelInfo] = []
    @State private var selectedModel: GeminiModelInfo?
    @State private var isLoadingModels = false
    @State private var flowError: String?
    @State private var answers = NutritionPlanAnswers()
    @State private var questionIndex = 0
    @State private var showAdvancedPlan = false
    @State private var showAllModels = false
    @State private var plan: GeneratedNutritionPlan?
    @State private var activeRecord: GeneratedPlanRecord?
    @State private var chatMessages: [PlanChatMessage] = []
    @State private var chatInput = ""
    @State private var isChatting = false
    @State private var appeared = false
    @State private var showSaveAlert = false
    @State private var saveNameInput = ""
    @State private var showAdjustAlert = false
    @State private var adjustInput = ""
    @State private var showExitConfirm = false
    /// Feedback del ultimo "Ajustar", para que Reintentar tras un error no
    /// pierda lo que el usuario pidio cambiar.
    @State private var lastFeedback: String?

    /// Plan guardado que se reabre como visor: arranca en `.result` con su
    /// chat, sin pasar por cuestionario ni picker de modelo. nil = flujo
    /// normal de generacion.
    private let initialRecord: GeneratedPlanRecord?

    init(record: GeneratedPlanRecord? = nil) {
        self.initialRecord = record
    }

    private let service = GeminiPlanService()
    private static let apiKeyAccount = "nutrition.gemini.apiKey"

    /// Modelo para chat y regeneracion: el elegido en el picker o, al reabrir
    /// un guardado (donde el picker nunca corrio), el que genero ese plan.
    private var activeModelID: String? { selectedModel?.id ?? initialRecord?.modelName }

    // MARK: Paleta (la misma del asistente)

    private static let ink = Color(red: 0.09, green: 0.09, blue: 0.13)
    private static let inkSoft = Color(red: 0.42, green: 0.43, blue: 0.50)
    private static let accent = Color(red: 0.38, green: 0.34, blue: 0.84)
    private static let control = Color.black.opacity(0.05)
    private static let hairline = Color.black.opacity(0.08)

    private var profile: NutritionProfile? {
        profiles.first { $0.setupCompleted } ?? profiles.first
    }

    /// Duraciones ofrecidas en chips (dias).
    private static let planDayOptions = [1, 3, 5, 7]

    private func dayCountLabel(_ count: Int) -> String {
        count == 1
            ? RecvelL10n.text("planflow.duration.one")
            : RecvelL10n.text("planflow.duration.days", values: ["count": "\(count)"])
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                content
            }
        }
        .environment(\.colorScheme, .light)
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            // La purga corre siempre: solo toca borradores (savedAt nil), que
            // por definicion no son el registro reabierto.
            purgeDraftsSalvagingAnswers()
            if let record = initialRecord {
                plan = record.plan
                activeRecord = record
                chatMessages = record.chatMessages
                if let stored = record.answers { answers = stored }
                resolvedAPIKey = KeychainStore.get(Self.apiKeyAccount)
                stage = .result
                // Best-effort: si la lista carga, "Generar otro" puede usar el
                // picker; si no, `activeModelID` cae al modelo del registro.
                Task { await loadModels() }
                return
            }
            prefillAnswersFromLastPlan()
            inferFromAppData()
            if answers.filledAdvancedPlan { showAdvancedPlan = true }
            Task { await health.refresh(); inferFromAppData() }
            if let saved = KeychainStore.get(Self.apiKeyAccount), !saved.isEmpty {
                resolvedAPIKey = saved
                stage = .questionnaire
                Task { await loadModels() }
            }
        }
        // Red de seguridad del descarte: cubre el pop por gesto del
        // NavigationStack, que no pasa por el dialogo del xmark.
        .onDisappear { discardDraft() }
        .alert(RecvelL10n.text("planflow.save.title"), isPresented: $showSaveAlert) {
            TextField(RecvelL10n.text("planflow.save.namePlaceholder"), text: $saveNameInput)
            Button(RecvelL10n.text("planflow.save.confirm")) { saveCurrentPlan() }
            Button(RecvelL10n.text("common.cancel"), role: .cancel) {}
        }
        .alert(RecvelL10n.text("planflow.adjust.title"), isPresented: $showAdjustAlert) {
            TextField(RecvelL10n.text("planflow.adjust.placeholder"), text: $adjustInput)
            // "Regenerar" y no "Aplicar": el ajuste es una generacion completa
            // nueva contra la API del usuario, y el copy no lo esconde.
            Button(RecvelL10n.text("planflow.adjust.confirm")) {
                let text = adjustInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                Task { await startGeneration(feedback: text) }
            }
            Button(RecvelL10n.text("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            RecvelL10n.text("planflow.exit.title"),
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button(RecvelL10n.text("planflow.exit.discard"), role: .destructive) {
                Haptics.warning()
                discardDraft()
                dismiss()
            }
            Button(RecvelL10n.text("common.cancel"), role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("planflow.root")
    }

    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.99, green: 0.99, blue: 1.0), location: 0),
                .init(color: Color(red: 0.95, green: 0.95, blue: 0.99), location: 0.45),
                .init(color: Color(red: 0.91, green: 0.91, blue: 0.98), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Barra superior

    private var topBar: some View {
        ZStack {
            if let progress = topBarProgress {
                HStack(spacing: 6) {
                    ForEach(0..<progress.total, id: \.self) { index in
                        Capsule()
                            .fill(index <= progress.current ? Self.accent : Color.black.opacity(0.10))
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: 160)
            }

            HStack {
                circleButton(icon: backIcon, label: RecvelL10n.text("common.back")) {
                    Haptics.soft()
                    goBack()
                }
                Spacer()
                circleButton(icon: "xmark", label: RecvelL10n.text("common.close")) {
                    Haptics.soft()
                    attemptClose()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var backIcon: String { "chevron.left" }

    /// Progreso visible solo en el cuestionario; las etapas de conexion son
    /// transitorias y el resultado ya no es un paso.
    private var topBarProgress: (current: Int, total: Int)? {
        guard stage == .questionnaire else { return nil }
        return (questionIndex, QuestionStep.allCases.count)
    }

    private func goBack() {
        switch stage {
        case .apiKey:
            dismiss()
        case .questionnaire:
            if questionIndex > 0 { withAnimation(reduceMotion ? nil : .snappy) { questionIndex -= 1 } }
            else if KeychainStore.get(Self.apiKeyAccount) == nil { stage = .apiKey }
            else { dismiss() }
        case .generating:
            break
        case .result:
            // Visor de un plan guardado: atras = salir (no hay cuestionario
            // detras). En el flujo normal regresa al ultimo paso, listo para
            // regenerar; el borrador NO se descarta aqui (se sobrescribira al
            // regenerar, o lo resolvera el cierre).
            if initialRecord != nil {
                attemptClose()
            } else {
                stage = .questionnaire
                questionIndex = QuestionStep.allCases.count - 1
            }
        }
    }

    /// Cierre con conciencia del borrador: si hay un plan sin guardar se
    /// pregunta antes de tirarlo; si no, cierra directo.
    private func attemptClose() {
        if let record = activeRecord, !record.isSaved {
            showExitConfirm = true
        } else {
            dismiss()
        }
    }

    private func discardDraft() {
        guard let record = activeRecord, !record.isSaved else { return }
        modelContext.delete(record)
        try? modelContext.save()
        activeRecord = nil
    }

    /// Purga al abrir el flujo: rescata primero las respuestas mas recientes
    /// hacia `NutritionPlanAnswersStore` (cubre registros pre-migracion, que
    /// eran la unica fuente del prefill) y borra todo borrador restante.
    private func purgeDraftsSalvagingAnswers() {
        if let salvage = NutritionPlanDraftPolicy.answersJSONToSalvage(
            records: Array(planRecords),
            storeHasAnswers: NutritionPlanAnswersStore.hasAnswers()
        ) {
            NutritionPlanAnswersStore.saveJSON(salvage)
        }
        let drafts = NutritionPlanDraftPolicy.purgeableDrafts(in: Array(planRecords))
        guard !drafts.isEmpty else { return }
        drafts.forEach(modelContext.delete)
        try? modelContext.save()
    }

    // MARK: - Contenido por etapa

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .apiKey: apiKeyStage
        case .questionnaire: questionnaireStage
        case .generating: generatingStage
        case .result: resultStage
        }
    }

    // MARK: - 1. API key

    private var apiKeyStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stageHeader(
                        eyebrow: RecvelL10n.text("planflow.api.eyebrow"),
                        title: RecvelL10n.text("planflow.api.title"),
                        detail: RecvelL10n.text("planflow.api.detail")
                    )

                    HStack {
                        Group {
                            if revealAPIKey {
                                TextField(RecvelL10n.text("planflow.api.placeholder"), text: $apiKeyInput)
                            } else {
                                SecureField(RecvelL10n.text("planflow.api.placeholder"), text: $apiKeyInput)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .snappyTextInput()

                        Button {
                            Haptics.selection()
                            revealAPIKey.toggle()
                        } label: {
                            Image(systemName: revealAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(Self.inkSoft)
                        }
                        .accessibilityLabel(RecvelL10n.text(revealAPIKey ? "settings.nutrition.api.hide" : "settings.nutrition.api.show"))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Self.hairline, lineWidth: 1)
                    }

                    Label(RecvelL10n.text("planflow.api.privacy"), systemImage: "lock.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Self.inkSoft)

                    if let flowError {
                        errorBanner(flowError)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)

            bottomButton(
                title: isLoadingModels
                    ? RecvelL10n.text("planflow.api.validating")
                    : RecvelL10n.text("planflow.continue"),
                enabled: !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingModels
            ) {
                saveKeyAndContinue()
            }
        }
        .accessibilityIdentifier("planflow.apiKey")
    }

    private func saveKeyAndContinue() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        Haptics.medium()
        isLoadingModels = true
        flowError = nil
        resolvedAPIKey = key
        Task {
            await loadModels()
            if isLoadingModels == false, flowError == nil {
                // Solo persiste la llave que demostro funcionar: una llave
                // invalida guardada dejaba el flujo atascado en el listado.
                KeychainStore.set(key, forKey: Self.apiKeyAccount)
            }
        }
    }

    @MainActor
    private func loadModels() async {
        guard let key = resolvedAPIKey else { return }
        isLoadingModels = true
        flowError = nil
        do {
            let fetched = try await service.fetchModels(apiKey: key)
            models = fetched
            selectedModel = GeminiModelInfo.defaultSelection(from: fetched)
            isLoadingModels = false
            if stage == .apiKey {
                withAnimation(reduceMotion ? nil : .snappy) { stage = .questionnaire }
            }
        } catch {
            isLoadingModels = false
            flowError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - 3. Cuestionario

    private var questionnaireStage: some View {
        let step = QuestionStep.allCases[questionIndex]
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stageHeader(
                        eyebrow: RecvelL10n.text(step.eyebrowKey),
                        title: RecvelL10n.text(step.titleKey),
                        detail: RecvelL10n.text(step.detailKey)
                    )
                    questionContent(step)
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            let isLast = questionIndex == QuestionStep.allCases.count - 1
            bottomButton(
                title: isLast ? RecvelL10n.text("planflow.generate") : RecvelL10n.text("planflow.continue"),
                enabled: canAdvance(step) && (!isLast || (selectedModel != nil && !isLoadingModels))
            ) {
                if isLast { Task { await startGeneration() } }
                else {
                    Haptics.medium()
                    Keyboard.dismiss()
                    withAnimation(reduceMotion ? nil : .snappy) { questionIndex += 1 }
                }
            }
        }
        .accessibilityIdentifier("planflow.questionnaire.\(step.eyebrowKey)")
    }

    /// Salud exige condiciones y medicamentos (el resto trae default razonable).
    /// Plan avanzado nunca bloquea: es cribado opcional.
    private func canAdvance(_ step: QuestionStep) -> Bool {
        switch step {
        case .health:
            return !answers.conditions.isEmpty && !answers.medications.isEmpty
        case .activity, .preferences:
            return true
        }
    }

    @ViewBuilder
    private func questionContent(_ step: QuestionStep) -> some View {
        switch step {
        case .health: healthStep
        case .activity: activityStep
        case .preferences: preferencesStep
        }
    }

    // Paso 1 — salud y medicamentos. Embarazo y ciclo solo si el perfil
    // dice "Mujer". El cribado de TCA no va aqui: es Plan avanzado.
    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldLabel("planflow.health.conditions")
            FlowChips(
                items: PlanMedicalCondition.allCases.filter { $0 != .none },
                isSelected: { answers.conditions.contains($0) },
                toggle: { toggleCondition($0) },
                title: { $0.displayName }
            )
            noneExclusiveCard(
                title: RecvelL10n.text("planflow.none.conditions"),
                detail: RecvelL10n.text("planflow.none.conditions.detail"),
                selected: answers.conditions == [.none]
            ) {
                toggleCondition(.none)
            }

            if NutritionSex(rawValue: profile?.sexOptional ?? "") == .female {
                toggleRow(title: RecvelL10n.text("planflow.health.pregnancy"), isOn: $answers.pregnantOrLactating)

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("planflow.health.cycle")
                    HStack(spacing: 8) {
                        ForEach(PlanMenstrualCycle.allCases) { option in
                            selectableChip(
                                title: option.displayName,
                                selected: answers.menstrualCycle == option
                            ) { answers.menstrualCycle = option }
                        }
                    }
                }
            }

            fieldLabel("planflow.meds.eyebrow")
            FlowChips(
                items: PlanMedication.allCases.filter { $0 != .none },
                isSelected: { answers.medications.contains($0) },
                toggle: { toggleMedication($0) },
                title: { $0.displayName }
            )
            noneExclusiveCard(
                title: RecvelL10n.text("planflow.none.meds"),
                detail: RecvelL10n.text("planflow.none.meds.detail"),
                selected: answers.medications == [.none]
            ) {
                toggleMedication(.none)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("planflow.meds.other")
                flowTextField(
                    placeholder: RecvelL10n.text("planflow.meds.otherPlaceholder"),
                    text: $answers.otherMedications
                )
            }

            Label(RecvelL10n.text("planflow.health.safetyNote"), systemImage: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Self.inkSoft)
        }
    }

    private func yesNoRow(title: String, value: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Self.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                selectableChip(
                    title: RecvelL10n.text("planflow.yes"),
                    selected: value.wrappedValue == true
                ) { value.wrappedValue = true }
                selectableChip(
                    title: RecvelL10n.text("planflow.no"),
                    selected: value.wrappedValue == false
                ) { value.wrappedValue = false }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Self.hairline, lineWidth: 1)
        }
    }

    private func toggleCondition(_ condition: PlanMedicalCondition) {
        Haptics.selection()
        if condition == .none {
            answers.conditions = [.none]
            return
        }
        answers.conditions.removeAll { $0 == .none }
        if let index = answers.conditions.firstIndex(of: condition) {
            answers.conditions.remove(at: index)
        } else {
            answers.conditions.append(condition)
        }
    }

    private func toggleMedication(_ medication: PlanMedication) {
        Haptics.selection()
        if medication == .none {
            answers.medications = [.none]
            return
        }
        answers.medications.removeAll { $0 == .none }
        if let index = answers.medications.firstIndex(of: medication) {
            answers.medications.remove(at: index)
        } else {
            answers.medications.append(medication)
        }
    }

    // Paso 2 — NEAT: la mayor varianza del TDEE (hasta 2,000 kcal/dia).
    private var activityStep: some View {
        VStack(spacing: 10) {
            ForEach(PlanOccupation.allCases) { option in
                optionCard(
                    title: option.displayName,
                    detail: option.detail,
                    icon: option.icon,
                    selected: answers.occupation == option
                ) { answers.occupation = option }
            }
        }
    }

    // Paso 3 — adherencia (Dansinger 2005). SCOFF, atracon, ejercicio
    // compensatorio e historial de peso viven en Plan avanzado: son cribado
    // clinico, no hacen falta para un primer plan.
    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            modelPicker

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.prefs.duration")
                HStack(spacing: 8) {
                    ForEach(Self.planDayOptions, id: \.self) { count in
                        selectableChip(
                            title: dayCountLabel(count),
                            selected: answers.planDays == count
                        ) { answers.planDays = count }
                    }
                }
                Text(RecvelL10n.text("planflow.prefs.duration.detail"))
                    .font(.system(size: 12))
                    .foregroundStyle(Self.inkSoft)
            }

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.prefs.repeat")
                VStack(spacing: 10) {
                    ForEach(PlanMealRepeat.allCases) { option in
                        optionCard(
                            title: option.displayName,
                            detail: option.detail,
                            icon: option == .none ? "sparkles" : "repeat",
                            selected: answers.mealRepeat == option
                        ) { answers.mealRepeat = option }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.prefs.budget")
                VStack(spacing: 10) {
                    ForEach(PlanBudget.allCases) { option in
                        optionCard(
                            title: option.displayName,
                            detail: option.detail,
                            icon: "banknote.fill",
                            selected: answers.budget == option
                        ) { answers.budget = option }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("planflow.prefs.cuisine")
                flowTextField(
                    placeholder: RecvelL10n.text("planflow.prefs.cuisinePlaceholder"),
                    text: $answers.cuisine
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.prefs.cooking")
                FlowChips(
                    items: PlanCookingTime.allCases,
                    isSelected: { answers.cookingTime == $0 },
                    toggle: { answers.cookingTime = $0; Haptics.selection() },
                    title: { $0.displayName }
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("planflow.prefs.supplements")
                flowTextField(
                    placeholder: RecvelL10n.text("planflow.prefs.supplementsPlaceholder"),
                    text: $answers.supplements
                )
            }

            toggleRow(title: RecvelL10n.text("planflow.prefs.openToSupplements"), isOn: $answers.openToSupplements)

            advancedPlanSection
        }
    }

    /// Flash Lite + Pro por defecto; el resto solo si pulsa Ver mas.
    private var modelPicker: some View {
        let featured = GeminiModelInfo.featured(from: models)
        let extra = models.filter { model in featured.contains(where: { $0.id == model.id }) == false }
        return VStack(alignment: .leading, spacing: 10) {
            fieldLabel("planflow.models.eyebrow")
            if isLoadingModels && models.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(Self.ink)
                    Text(RecvelL10n.text("planflow.models.loading"))
                        .font(.system(size: 13))
                        .foregroundStyle(Self.inkSoft)
                }
            } else if models.isEmpty, let flowError {
                errorBanner(flowError)
                retryButton { Task { await loadModels() } }
            } else {
                NutritionFlowLayout(spacing: 8) {
                    ForEach(featured) { model in
                        selectableChip(title: model.shortLabel, selected: selectedModel?.id == model.id) {
                            selectedModel = model
                        }
                        .accessibilityIdentifier("planflow.model.\(model.id)")
                    }
                    if !extra.isEmpty {
                        selectableChip(
                            title: RecvelL10n.text(showAllModels ? "planflow.models.less" : "planflow.models.more"),
                            selected: showAllModels
                        ) {
                            withAnimation(reduceMotion ? nil : .snappy) { showAllModels.toggle() }
                        }
                        .accessibilityIdentifier("planflow.models.more")
                    }
                }
                if showAllModels, !extra.isEmpty {
                    FlowChips(
                        items: extra,
                        isSelected: { selectedModel?.id == $0.id },
                        toggle: { selectedModel = $0 },
                        title: { $0.shortLabel }
                    )
                }
            }
        }
        .accessibilityIdentifier("planflow.models")
    }

    private var advancedPlanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy) { showAdvancedPlan.toggle() }
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showAdvancedPlan ? .white : Self.accent)
                        .frame(width: 38, height: 38)
                        .background(
                            showAdvancedPlan ? Self.accent : Self.accent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(RecvelL10n.text("planflow.advanced.title"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Self.ink)
                        Text(RecvelL10n.text("planflow.advanced.detail"))
                            .font(.system(size: 12))
                            .foregroundStyle(Self.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: showAdvancedPlan ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Self.inkSoft)
                }
                .padding(13)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(showAdvancedPlan ? Self.accent.opacity(0.5) : Self.hairline, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("planflow.advanced.toggle")

            if showAdvancedPlan {
                advancedPlanFields
            }
        }
    }

    /// SCOFF (Morgan BMJ 1999; corte ≥2) + frecuencia de atracon (DSM-5 BED)
    /// + ejercicio compensatorio (Academy SOP 2022) + historial de cycling
    /// (Carraca 2018). Opcional; no diagnostica.
    private var advancedPlanFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.advanced.history")
                ForEach(PlanWeightLossHistory.allCases) { option in
                    optionCard(
                        title: option.displayName,
                        detail: option.detail,
                        icon: option.icon,
                        selected: answers.weightLossHistory == option
                    ) { answers.weightLossHistory = option }
                }
            }

            toggleRow(title: RecvelL10n.text("planflow.eating.diagnosed"), isOn: $answers.eatingDisorderHistory)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.scoff.label")
                yesNoRow(title: RecvelL10n.text("planflow.scoff.sick"), value: $answers.scoffSick)
                yesNoRow(title: RecvelL10n.text("planflow.scoff.control"), value: $answers.scoffControl)
                yesNoRow(title: RecvelL10n.text("planflow.scoff.oneStone"), value: $answers.scoffOneStone)
                yesNoRow(title: RecvelL10n.text("planflow.scoff.fat"), value: $answers.scoffFat)
                yesNoRow(title: RecvelL10n.text("planflow.scoff.food"), value: $answers.scoffFood)
            }

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("planflow.binge.label")
                ForEach(PlanBingeFrequency.allCases) { option in
                    optionCard(
                        title: option.displayName,
                        detail: option.detail,
                        icon: "fork.knife",
                        selected: answers.bingeFrequency == option
                    ) { answers.bingeFrequency = option }
                }
            }

            yesNoRow(title: RecvelL10n.text("planflow.eating.drivenExercise"), value: $answers.drivenExercise)

            Label(RecvelL10n.text("planflow.eating.disclaimer"), systemImage: "stethoscope")
                .font(.system(size: 12))
                .foregroundStyle(Self.inkSoft)
        }
    }

    // MARK: - 4. Generacion

    private var generatingStage: some View {
        VStack(spacing: 22) {
            Spacer()
            AssistantOrb(diameter: 120)

            if let flowError {
                errorBanner(flowError)
                // Reintentar conserva el feedback de "Ajustar" si lo hubo.
                retryButton { Task { await startGeneration(feedback: lastFeedback) } }
            } else {
                VStack(spacing: 8) {
                    Text(RecvelL10n.text("planflow.generating.title"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Self.ink)
                    Text(RecvelL10n.text(
                        "planflow.generating.detail",
                        values: ["model": selectedModel?.displayName ?? activeModelID ?? ""]
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(Self.inkSoft)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("planflow.generating")
    }

    @MainActor
    private func startGeneration(feedback: String? = nil) async {
        guard let key = resolvedAPIKey, let modelID = activeModelID else { return }
        guard let profile else {
            flowError = RecvelL10n.text("planflow.error.noProfile")
            withAnimation(reduceMotion ? nil : .snappy) { stage = .generating }
            return
        }
        Haptics.medium()
        flowError = nil
        lastFeedback = feedback
        withAnimation(reduceMotion ? nil : .snappy) { stage = .generating }
        do {
            let generated = try await service.generatePlan(
                apiKey: key,
                model: modelID,
                profile: profile,
                answers: answers,
                health: healthContext,
                feedback: feedback,
                // El plan vigente solo viaja como referente cuando hay ajuste;
                // "Generar otro" es una generacion limpia.
                previousPlan: feedback != nil ? plan : nil
            )
            plan = generated
            persistPlan(generated, modelName: modelID)
            withAnimation(reduceMotion ? nil : .snappy) { stage = .result }
        } catch {
            flowError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var healthContext: PlanHealthContext {
        PlanContextBuilder.make(
            history: health.history,
            scores: scoreRecords,
            workouts: activityLogs,
            habits: habitLogs,
            journal: journalEntries,
            meals: mealLogs,
            emotions: emotionLogs,
            readiness: readinessLogs,
            routine: WeeklyRoutineStore.load()
        )
    }

    private func persistPlan(_ generated: GeneratedNutritionPlan, modelName: String) {
        guard let planData = try? JSONEncoder().encode(generated),
              let planJSON = String(data: planData, encoding: .utf8),
              let answersData = try? JSONEncoder().encode(answers),
              let answersJSON = String(data: answersData, encoding: .utf8) else { return }
        // Las respuestas viven fuera de SwiftData: el prefill del proximo
        // cuestionario no depende de que este plan sobreviva.
        NutritionPlanAnswersStore.saveJSON(answersJSON)

        // El borrador de la sesion se reutiliza entre regeneraciones. Un plan
        // GUARDADO nunca se sobrescribe: regenerar/ajustar desde un guardado
        // reabierto abre un borrador nuevo y deja el original intacto.
        if let record = activeRecord, !record.isSaved {
            record.planJSON = planJSON
            record.answersJSON = answersJSON
            record.modelName = modelName
            record.createdAt = .now
            record.chatJSON = "[]"
        } else {
            let record = GeneratedPlanRecord(modelName: modelName, planJSON: planJSON, answersJSON: answersJSON)
            modelContext.insert(record)
            activeRecord = record
        }
        // El chat anterior hablaba de otro plan; arrastrarlo confundiria a la
        // persona y al modelo por igual.
        chatMessages = []
        try? modelContext.save()
    }

    /// Rellena el cuestionario con las respuestas de la ultima generacion: el
    /// usuario solo confirma en vez de contestar de cero. Primero el store
    /// (sobrevive a la purga de borradores); el registro mas reciente queda de
    /// fallback para datos creados antes del store.
    private func prefillAnswersFromLastPlan() {
        if let stored = NutritionPlanAnswersStore.load() {
            answers = stored
            return
        }
        guard let last = planRecords.first, let stored = last.answers else { return }
        answers = stored
    }

    /// Hora/duracion de entreno y cafeina ya viven en la app. Se mandan a
    /// Gemini sin ocupar un paso del cuestionario (ISSN Timing 2017, Drake 2013).
    private func inferFromAppData() {
        let routine = WeeklyRoutineStore.load()
        let planned = (1...7).compactMap { weekday -> ScheduledSessionDetails? in
            guard let assignment = routine.days[weekday], assignment != .rest else { return nil }
            return routine.details(forWeekday: weekday)
        }
        if !planned.isEmpty {
            let avgMinutes = planned.reduce(0) { $0 + $1.durationMinutes } / planned.count
            answers.trainingDuration = avgMinutes < 45 ? .under45 : (avgMinutes <= 75 ? .from45to75 : .over75)
            let hours = planned.compactMap { details -> Int? in
                guard let start = details.startDate(on: .now) else { return nil }
                return Calendar.current.component(.hour, from: start)
            }
            if let hour = hours.min() {
                switch hour {
                case 5..<11: answers.trainingTime = .morning
                case 11..<14: answers.trainingTime = .midday
                case 14..<18: answers.trainingTime = .afternoon
                default: answers.trainingTime = .evening
                }
            }
        }

        let caffeine = health.history.compactMap(\.dietaryCaffeineMg)
        if !caffeine.isEmpty {
            let average = caffeine.reduce(0, +) / Double(caffeine.count)
            answers.caffeine = average < 30 ? .none : (average < 200 ? .moderate : .high)
        }
    }

    // MARK: - 5. Resultado + chat

    private var resultStage: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let plan {
                            planHero(plan)
                            resultActionBar
                            dayPager(plan)
                            dayContent(plan)
                            extrasSections(plan)
                            Label(RecvelL10n.text("planflow.result.disclaimer"), systemImage: "stethoscope")
                                .font(.system(size: 11))
                                .foregroundStyle(Self.inkSoft)
                                .padding(.horizontal, 6)
                        }
                        ForEach(chatMessages) { message in
                            chatBubble(message)
                                .id(message.id)
                        }
                        if isChatting {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small).tint(Self.inkSoft)
                                Text(RecvelL10n.text("planflow.chat.thinking"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Self.inkSoft)
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chatMessages.count) { _, _ in
                    guard let last = chatMessages.last else { return }
                    withAnimation(reduceMotion ? nil : .snappy) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            chatInputBar
        }
        .accessibilityIdentifier("planflow.result")
    }

    // MARK: Acciones sobre el plan

    /// Guardar / Ajustar / Generar otro, pegadas al hero: son decisiones
    /// sobre ESTE plan y se toman con las metas a la vista.
    private var resultActionBar: some View {
        HStack(spacing: 8) {
            if let record = activeRecord, record.isSaved {
                // Ya guardado: el mismo boton pasa a confirmar el estado y a
                // ofrecer renombrar (mismo alert, precargado con su nombre).
                actionPill(icon: "checkmark", titleKey: "planflow.result.saved", filled: true) {
                    Haptics.soft()
                    saveNameInput = record.name ?? defaultNameForCurrentPlan
                    showSaveAlert = true
                }
                .accessibilityLabel(RecvelL10n.text("planflow.result.rename"))
                .accessibilityIdentifier("planflow.result.save")
            } else {
                actionPill(icon: "bookmark.fill", titleKey: "planflow.result.save", filled: true) {
                    Haptics.soft()
                    saveNameInput = defaultNameForCurrentPlan
                    showSaveAlert = true
                }
                .accessibilityIdentifier("planflow.result.save")
            }

            actionPill(icon: "slider.horizontal.3", titleKey: "planflow.result.adjust", filled: false) {
                Haptics.soft()
                adjustInput = ""
                showAdjustAlert = true
            }
            .accessibilityIdentifier("planflow.result.adjust")

            actionPill(icon: "arrow.clockwise", titleKey: "planflow.result.regenerate", filled: false) {
                Task { await startGeneration() }
            }
            .accessibilityIdentifier("planflow.result.regenerate")
        }
    }

    private func actionPill(
        icon: String,
        titleKey: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(RecvelL10n.text(titleKey))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(filled ? .white : Self.ink)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                filled ? Self.ink : Color.white.opacity(0.75),
                in: Capsule(style: .continuous)
            )
            .overlay {
                if !filled {
                    Capsule(style: .continuous).strokeBorder(Self.hairline, lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var defaultNameForCurrentPlan: String {
        guard let plan else { return "" }
        return NutritionPlanDraftPolicy.defaultName(targets: plan.targets, date: .now)
    }

    private func saveCurrentPlan() {
        guard let record = activeRecord else { return }
        Haptics.success()
        let trimmed = saveNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Campo vacio = sin nombre propio: la fila mostrara el nombre por
        // defecto calculado, que sigue a las metas si el plan cambia.
        record.name = trimmed.isEmpty ? nil : trimmed
        if record.savedAt == nil { record.savedAt = .now }
        try? modelContext.save()
    }

    // MARK: Hero

    /// Cabecera del plan: gradiente del acento (la "portada"), resumen y
    /// metas diarias. Es lo unico con color lleno; el resto son tarjetas
    /// blancas para que la lectura no compita.
    private func planHero(_ plan: GeneratedNutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(RecvelL10n.text("planflow.result.eyebrow").uppercased())
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.1)
                if plan.days.count > 1 {
                    Text("·")
                        .font(.system(size: 11, weight: .black))
                    Text(dayCountLabel(plan.days.count).uppercased())
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.1)
                }
            }
            .foregroundStyle(.white.opacity(0.85))

            Text(plan.summary)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Color.white.opacity(0.22))

            HStack(spacing: 0) {
                heroStat(value: "\(plan.targets.calories)", unit: "kcal")
                heroStat(value: "\(plan.targets.protein)g", unit: RecvelL10n.text("nutrition.macro.protein"))
                heroStat(value: "\(plan.targets.carbohydrates)g", unit: RecvelL10n.text("nutrition.macro.carbs"))
                heroStat(value: "\(plan.targets.fat)g", unit: RecvelL10n.text("nutrition.macro.fat"))
            }

            Label(
                "\(RecvelL10n.text("planflow.result.hydration")): \(String(format: "%.1f", plan.targets.hydrationLiters)) \(RecvelL10n.text("planflow.result.liters"))",
                systemImage: "drop.fill"
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Self.accent, Color(red: 0.26, green: 0.22, blue: 0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: Self.accent.opacity(0.35), radius: 18, y: 10)
        .accessibilityIdentifier("planflow.plan")
    }

    private func heroStat(value: String, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pager de dias

    @State private var selectedDayIndex = 0
    @State private var expandedSections: Set<String> = []

    private func dayPager(_ plan: GeneratedNutritionPlan) -> some View {
        Group {
            if plan.days.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                            let selected = index == selectedDayIndex
                            Button {
                                Haptics.selection()
                                withAnimation(reduceMotion ? nil : .snappy) { selectedDayIndex = index }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(RecvelL10n.text("planflow.result.day", values: ["count": "\(day.day)"]))
                                        .font(.system(size: 13, weight: .bold))
                                    if !day.label.isEmpty {
                                        Text(day.label)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundStyle(selected ? .white : Self.ink)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    selected ? Self.accent : Color.white.opacity(0.65),
                                    in: Capsule(style: .continuous)
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(selected ? Color.clear : Self.hairline, lineWidth: 1)
                                }
                                .contentShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("planflow.day.\(day.day)")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: Contenido del dia elegido

    private func dayContent(_ plan: GeneratedNutritionPlan) -> some View {
        let index = min(selectedDayIndex, max(plan.days.count - 1, 0))
        let day = plan.days[index]
        return VStack(alignment: .leading, spacing: 12) {
            if let note = day.note, !note.isEmpty {
                Label(note, systemImage: "repeat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            ForEach(day.meals) { meal in
                mealCard(meal)
            }
        }
    }

    /// Tarjeta de comida rica: icono por tipo, hora y kcal arriba, platillo,
    /// porciones y chips de macros con el color de cada macro.
    private func mealCard(_ meal: GeneratedNutritionPlan.Meal) -> some View {
        let style = mealStyle(for: meal.mealType)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: style.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(style.tint)
                    .frame(width: 38, height: 38)
                    .background(style.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.mealType.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.7)
                        .foregroundStyle(style.tint)
                    if !meal.time.isEmpty {
                        Text(meal.time)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Self.inkSoft)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(meal.calories)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Self.ink)
                    Text("kcal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Self.inkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(meal.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Self.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meal.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Self.inkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                macroChip(value: meal.protein, label: "P", color: Self.macroProtein)
                macroChip(value: meal.carbohydrates, label: "C", color: Self.macroCarbs)
                macroChip(value: meal.fat, label: "G", color: Self.macroFat)
                Spacer()
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Self.hairline, lineWidth: 1)
        }
        .shadow(color: Self.ink.opacity(0.05), radius: 8, y: 3)
    }

    private static let macroProtein = Color(red: 0.231, green: 0.510, blue: 0.965)
    private static let macroCarbs = Color(red: 0.851, green: 0.467, blue: 0.024)
    private static let macroFat = Color(red: 0.925, green: 0.282, blue: 0.600)

    private func macroChip(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(value)g")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Self.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10), in: Capsule(style: .continuous))
    }

    /// Icono y tinte por tipo de comida, igual que en el timeline de Nutricion.
    private func mealStyle(for mealType: String) -> (icon: String, tint: Color) {
        switch MealType(rawValue: mealType) {
        case .breakfast: ("sunrise.fill", Color(red: 0.984, green: 0.749, blue: 0.141))
        case .lunch: ("sun.max.fill", Color(red: 0.925, green: 0.435, blue: 0.196))
        case .dinner: ("moon.fill", Color(red: 0.38, green: 0.34, blue: 0.84))
        case .snack: ("takeoutbag.and.cup.and.straw.fill", Color(red: 0.204, green: 0.635, blue: 0.635))
        case nil: ("fork.knife", Self.inkSoft)
        }
    }

    // MARK: Secciones colapsables (compras, suplementos, precauciones, ciencia)

    private func extrasSections(_ plan: GeneratedNutritionPlan) -> some View {
        VStack(spacing: 10) {
            if !plan.shoppingList.isEmpty {
                collapsibleSection(
                    key: "planflow.result.shopping",
                    icon: "cart.fill",
                    tint: Color(red: 0.204, green: 0.635, blue: 0.635),
                    items: plan.shoppingList
                )
            }
            if !plan.supplementGuidance.isEmpty {
                collapsibleSection(
                    key: "planflow.result.supplements",
                    icon: "pills.fill",
                    tint: Self.accent,
                    items: plan.supplementGuidance
                )
            }
            if !plan.precautions.isEmpty {
                collapsibleSection(
                    key: "planflow.result.precautions",
                    icon: "exclamationmark.shield.fill",
                    tint: .orange,
                    items: plan.precautions
                )
            }
            if !plan.scienceBasis.isEmpty {
                collapsibleSection(
                    key: "planflow.result.science",
                    icon: "books.vertical.fill",
                    tint: Self.inkSoft,
                    items: plan.scienceBasis
                )
            }
        }
    }

    private func collapsibleSection(key: String, icon: String, tint: Color, items: [String]) -> some View {
        let expanded = expandedSections.contains(key)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy) {
                    if expanded { expandedSections.remove(key) } else { expandedSections.insert(key) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    Text(RecvelL10n.text(key))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Self.ink)
                    Spacer()
                    Text("\(items.count)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(Self.inkSoft)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Self.inkSoft)
                }
                .padding(13)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(items, id: \.self) { item in
                        bulletRow(item, icon: "checkmark.circle", tint: tint)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
                .padding(.top, 2)
            }
        }
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Self.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("planflow.section.\(key)")
    }

    private var chatInputBar: some View {
        HStack(spacing: 10) {
            TextField(RecvelL10n.text("planflow.chat.placeholder"), text: $chatInput, axis: .vertical)
                .lineLimit(1...4)
                .snappyTextInput()
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.75), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous).strokeBorder(Self.hairline, lineWidth: 1)
                }
                .accessibilityIdentifier("planflow.chat.input")

            Button {
                sendChat()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChatting
                            ? Self.ink.opacity(0.25) : Self.ink,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChatting)
            .accessibilityLabel(RecvelL10n.text("planflow.chat.send"))
            .accessibilityIdentifier("planflow.chat.send")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
    }

    private func sendChat() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let key = resolvedAPIKey, let modelID = activeModelID, let plan else { return }
        Haptics.soft()
        let userMessage = PlanChatMessage(role: .user, text: text)
        chatMessages.append(userMessage)
        chatInput = ""
        isChatting = true
        persistChat()
        Task {
            do {
                // El historial que se manda excluye el mensaje recien agregado:
                // viaja como `message` aparte.
                let history = Array(chatMessages.dropLast())
                let reply = try await service.sendChatMessage(
                    apiKey: key,
                    model: modelID,
                    plan: plan,
                    history: history,
                    message: text
                )
                await MainActor.run {
                    chatMessages.append(PlanChatMessage(role: .model, text: reply))
                    isChatting = false
                    persistChat()
                }
            } catch {
                await MainActor.run {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    chatMessages.append(PlanChatMessage(role: .model, text: message))
                    isChatting = false
                    persistChat()
                }
            }
        }
    }

    private func persistChat() {
        guard let record = activeRecord else { return }
        record.chatJSON = {
            guard let data = try? JSONEncoder().encode(chatMessages) else { return record.chatJSON }
            return String(data: data, encoding: .utf8) ?? record.chatJSON
        }()
        try? modelContext.save()
    }

    private func chatBubble(_ message: PlanChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(message.role == .user ? .white : Self.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    message.role == .user ? Self.accent : Color.white.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    if message.role == .model {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Self.hairline, lineWidth: 1)
                    }
                }
            if message.role == .model { Spacer(minLength: 40) }
        }
    }

    // MARK: - Piezas compartidas

    private func stageHeader(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .black))
                .kerning(1.1)
                .foregroundStyle(Self.accent)
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Self.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Self.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bottomButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Self.ink : Self.ink.opacity(0.25), in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("planflow.continue")
    }

    private func circleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Self.ink.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(Self.control, in: Circle())
                .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(RecvelL10n.text(key))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Self.ink)
    }

    private func selectableChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : Self.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    selected ? Self.accent : Color.white.opacity(0.65),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(selected ? Color.clear : Self.hairline, lineWidth: 1)
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func noneExclusiveCard(title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        optionCard(title: title, detail: detail, icon: "xmark.circle", selected: selected, action: action)
    }

    private func optionCard(title: String, detail: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? .white : Self.accent)
                    .frame(width: 38, height: 38)
                    .background(selected ? Self.accent : Self.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Self.ink)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Self.inkSoft)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Self.accent : Color.black.opacity(0.25))
            }
            .padding(13)
            .background(
                selected ? Self.accent.opacity(0.08) : Color.white.opacity(0.65),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Self.accent.opacity(0.5) : Self.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Self.ink)
        }
        .tint(Self.accent)
        .onChange(of: isOn.wrappedValue) { _, _ in Haptics.selection() }
        .padding(14)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Self.hairline, lineWidth: 1)
        }
    }

    private func flowTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .snappyTextInput()
            .padding(13)
            .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Self.hairline, lineWidth: 1)
            }
    }

    private func bulletRow(_ text: String, icon: String, tint: Color? = nil) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint ?? Self.accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Self.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Self.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func retryButton(action: @escaping () -> Void) -> some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Label(RecvelL10n.text("planflow.retry"), systemImage: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Self.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chips fluidos

/// Chips de seleccion multi/single que fluyen en renglones, con el mismo
/// tratamiento en todo el cuestionario.
private struct FlowChips<Item: Identifiable>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let toggle: (Item) -> Void
    let title: (Item) -> String

    private var ink: Color { Color(red: 0.09, green: 0.09, blue: 0.13) }
    private var accent: Color { Color(red: 0.38, green: 0.34, blue: 0.84) }

    var body: some View {
        NutritionFlowLayout(spacing: 8) {
            ForEach(items) { item in
                let selected = isSelected(item)
                Button {
                    toggle(item)
                } label: {
                    Text(title(item))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .white : ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            selected ? accent : Color.white.opacity(0.65),
                            in: Capsule(style: .continuous)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(selected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1)
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
