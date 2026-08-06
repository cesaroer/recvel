import SwiftData
import SwiftUI

// MARK: - Planificador semanal profesional
// "Una app de planeacion deportiva dentro de la app": biblioteca de planes
// semanales, asistente rapido (4 pantallas) o avanzado (alto rendimiento),
// tipos de sesion mas alla del gym (movilidad, recuperacion/fisioterapia,
// pliometria, aceleracion, contraste, tecnica) y expectativas con base
// cientifica. Metodo y limites: TRAINING_PLANNER_PRO.md.

// MARK: - Biblioteca de planes semanales

/// Plan semanal guardable y reaplicable (patron "Saved Plans" de Apple
/// Fitness+ / biblioteca de TrainingPeaks). La agenda activa sigue en
/// `WeeklyRoutineStore`; la biblioteca guarda copias con nombre.
struct WeeklyPlan: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = .now
    var routine: WeeklyRoutine

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, routine: WeeklyRoutine) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.routine = routine
    }
}

enum WeeklyPlanLibraryStore {
    static let key = "fitness.weeklyPlanLibrary"

    static func load(defaults: UserDefaults = .standard) -> [WeeklyPlan] {
        guard let data = defaults.data(forKey: key),
              let plans = try? JSONDecoder().decode([WeeklyPlan].self, from: data) else {
            return []
        }
        return plans.sorted { $0.createdAt > $1.createdAt }
    }

    static func saveAll(_ plans: [WeeklyPlan], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: key)
        }
    }

    /// Inserta o reemplaza (mismo id). Devuelve la lista resultante.
    @discardableResult
    static func upsert(_ plan: WeeklyPlan, defaults: UserDefaults = .standard) -> [WeeklyPlan] {
        var plans = load(defaults: defaults)
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        saveAll(plans, defaults: defaults)
        return load(defaults: defaults)
    }

    static func delete(id: UUID, defaults: UserDefaults = .standard) {
        saveAll(load(defaults: defaults).filter { $0.id != id }, defaults: defaults)
    }

    static func deleteAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - Motor de expectativas del plan ("que esperar de este plan")

struct PlanExpectation: Equatable {
    var bullets: [String] = []
    var cautions: [String] = []
}

struct PlanExpectationInput {
    var objective: TrainingObjective
    var experience: AthleteExperience
    var phase: TrainingProgramPhase
    var trainingDays: Int
    var performanceDays: Int
    var mobilityRecoveryDays: Int
    var weeklyMinutes: Int
    var hardSessions: Int
    var restDays: Int
}

/// Redacta expectativas prudentes segun objetivo, nivel y composicion de la
/// semana. Lenguaje de rango y constancia, nunca promesas de resultado ni
/// predicciones de lesion (regla AI_CONTEXT.md).
enum PlanExpectationEngine {
    static func expectations(for input: PlanExpectationInput) -> PlanExpectation {
        var result = PlanExpectation()

        switch input.objective {
        case .hypertrophy:
            result.bullets.append("Con volumen progresivo por grupo muscular (2-3 veces por semana), la hipertrofia medible suele aparecer tras 8-12 semanas de constancia; el split solo reparte ese volumen.")
        case .maximalStrength:
            result.bullets.append("Las primeras ganancias de fuerza (semanas 1-6) son sobre todo neurales; la fuerza maxima sigue mejorando con semanas de carga progresiva y periodizada.")
        case .endurance:
            result.bullets.append("La base aerobica se construye con minutos constantes a intensidad baja; las mejoras de resistencia suelen notarse en 6-12 semanas.")
        case .sportPerformance:
            result.bullets.append("La calidad manda: las sesiones de velocidad y potencia rinden mas frescas y al inicio de la sesion, nunca arrastrando fatiga.")
        case .general:
            result.bullets.append("Los lineamientos internacionales sugieren 150-300 min semanales de actividad moderada y fuerza 2 dias; tu plan suma \(input.weeklyMinutes) min.")
        }

        switch input.experience {
        case .starting:
            result.bullets.append("Prioridad a tecnica y constancia: las primeras 4-6 semanas construyen el habito y los patrones de movimiento.")
        case .advanced, .competitive:
            result.bullets.append("Considera una semana de descarga cada 3-5 semanas de carga para sostener el progreso.")
        case .intermediate:
            break
        }

        if input.phase == .deload {
            result.bullets.append("Semana de descarga: bajar el volumen ~40-50% manteniendo algo de intensidad ayuda a consolidar adaptaciones.")
        }
        if input.performanceDays > 0 {
            result.bullets.append("Tus \(input.performanceDays) sesion(es) de potencia rinden mas tras descanso o sesiones ligeras; evita colocarlas en racha de dias duros.")
        }
        if input.mobilityRecoveryDays > 0 {
            result.bullets.append("Incluir movilidad o recuperacion mejora la adherencia y hace la semana mas sostenible.")
        }

        if input.restDays == 0 {
            result.cautions.append("No hay dias de descanso programados: considera al menos uno (o recuperacion activa) cada semana.")
        }
        if input.hardSessions >= 3 {
            result.cautions.append("\(input.hardSessions) sesiones a RPE 8+ por semana son dificiles de sostener: alterna dias duros y suaves.")
        }
        if input.experience == .starting && input.performanceDays > 0 {
            result.cautions.append("La pliometria y el contraste piden base tecnica: en nivel inicial conviene dominar primero fuerza y tecnica.")
        }
        if input.objective != .general && input.weeklyMinutes < 120 {
            result.cautions.append("Tu plan suma \(input.weeklyMinutes) min semanales, por debajo de lo habitual para ver cambios; si puedes, acercate a 150+.")
        }
        return result
    }
}

// MARK: - Editor compartido de detalle de sesion

/// Controles de una sesion planeada: horario, duracion, RPE y parametros
/// especificos del tipo (contactos de salto, sets de contraste, distancia de
/// sprints, zona FC, %1RM, nota). Lo reusan el asistente y el editor de dia.
struct SessionDetailEditor: View {
    let weekday: Int
    let assignment: DayAssignment
    let templates: [WorkoutTemplate]
    var showProControls: Bool = true
    @Binding var details: ScheduledSessionDetails
    let onChangeAssignment: (DayAssignment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Calendar.current.weekdaySymbols[weekday - 1])
                        .font(.headline)
                    assignmentMenu
                }
                Spacer()
                if assignment != .rest {
                    Text("\(details.plannedLoad) u.")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if assignment != .rest {
                Picker("Flexibilidad", selection: $details.flexibility) {
                    ForEach(ScheduleFlexibility.allCases) { option in Text(option.title).tag(option) }
                }
                .pickerStyle(.segmented)

                if details.flexibility != .flexible {
                    DatePicker("Hora de inicio", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }

                sliderRow(
                    title: "Duración",
                    value: "\(details.durationMinutes) min",
                    tint: assignment.tintColor,
                    binding: intBinding(\.durationMinutes),
                    range: 15...180, step: 5
                )

                sliderRow(
                    title: "RPE objetivo",
                    value: "\(details.targetRPE)/10",
                    tint: details.targetRPE >= 8 ? ScoreKind.strain.color : assignment.tintColor,
                    binding: intBinding(\.targetRPE),
                    range: 1...10, step: 1
                )

                typeSpecificControls
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.sessionEditor.\(weekday)")
    }

    private var assignmentMenu: some View {
        Menu {
            if !templates.isEmpty {
                Menu("Plantillas") {
                    ForEach(templates) { template in
                        Button {
                            onChangeAssignment(assignment(for: template))
                            details.templateID = template.id
                            details.focusOverride = template.focus
                            details.exercisesText = template.exercisesText
                            if let minutes = template.durationMinutes { details.durationMinutes = minutes }
                        } label: {
                            Label(template.name, systemImage: template.kind.icon)
                        }
                    }
                }
            } else {
                Button { choose(.cardio("Fuerza libre")) } label: {
                    Label("Fuerza", systemImage: "dumbbell")
                }
            }
            Menu("Cardio (deporte)") {
                ForEach(CardioSport.allCases) { sport in
                    Button(sport.label) { choose(.cardio(sport: sport)) }
                }
            }
            Button { choose(.mobility) } label: {
                Label("Flexibilidad y movilidad", systemImage: DayAssignment.mobility.icon)
            }
            Button { choose(.recovery) } label: {
                Label("Recuperación / fisioterapia", systemImage: DayAssignment.recovery.icon)
            }
            Divider()
            ForEach(DayAssignment.performanceCases, id: \.shortLabel) { kind in
                Button { choose(kind) } label: {
                    Label(kind.displayLabel, systemImage: kind.icon)
                }
            }
            Divider()
            Button { choose(.rest) } label: {
                Label("Descanso", systemImage: DayAssignment.rest.icon)
            }
        } label: {
            Label(assignment.displayLabel, systemImage: assignment.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(assignment.tintColor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hapticMenuLabel()
        .accessibilityIdentifier("plan.sessionEditor.\(weekday).typeMenu")
    }

    private func assignment(for template: WorkoutTemplate) -> DayAssignment {
        switch template.kind {
        case .strength: .template(template.id)
        case .cardio: .cardio(template.focus)
        case .mobility, .dailyChallenge: .mobility
        case .recovery: .recovery
        case .performance: .technique
        }
    }

    private func choose(_ assignment: DayAssignment) {
        details.templateID = nil
        details.exercisesText = nil
        onChangeAssignment(assignment)
    }

    @ViewBuilder
    private var typeSpecificControls: some View {
        switch assignment {
        case .cardio:
            Picker("Intención", selection: cardioIntentBinding) {
                ForEach(CardioIntent.allCases) { intent in Text(intent.title).tag(Optional(intent)) }
            }
            .pickerStyle(.menu)
            if showProControls {
                Stepper(
                    "Zona FC objetivo: Z\(details.targetZone ?? 2)",
                    value: optionalIntBinding(\.targetZone, fallback: 2),
                    in: 1...5
                )
                .font(.subheadline.weight(.semibold))
            }
        case .plyometrics:
            Stepper(
                "Contactos de salto: \(details.jumpContacts ?? 40)",
                value: optionalIntBinding(\.jumpContacts, fallback: 40),
                in: 10...150, step: 5
            )
            .font(.subheadline.weight(.semibold))
            Text("El volumen de pliometría se mide en contactos; 40-80 es un rango habitual por sesión.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .contrast:
            Stepper(
                "Giant sets: \(details.contrastSets ?? 3)",
                value: optionalIntBinding(\.contrastSets, fallback: 3),
                in: 2...4
            )
            .font(.subheadline.weight(.semibold))
            Text("Pesado ~80% + pliometría + velocidad + asistido, con 2-5 min de descanso entre sets.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .speed:
            Stepper(
                "Repeticiones: \(details.speedReps ?? 6)",
                value: optionalIntBinding(\.speedReps, fallback: 6),
                in: 2...12
            )
            .font(.subheadline.weight(.semibold))
            Stepper(
                "Distancia: \(details.speedDistanceMeters ?? 30) m",
                value: optionalIntBinding(\.speedDistanceMeters, fallback: 30),
                in: 10...60, step: 5
            )
            .font(.subheadline.weight(.semibold))
        case .template:
            if showProControls {
                Toggle("Guiar por %1RM", isOn: percentToggleBinding)
                    .font(.subheadline.weight(.semibold))
                    .tint(.cyan)
                if details.mainLiftPercent1RM != nil {
                    sliderRow(
                        title: "%1RM principal",
                        value: "\(details.mainLiftPercent1RM ?? 75)%",
                        tint: .cyan,
                        binding: Binding(
                            get: { Double(details.mainLiftPercent1RM ?? 75) },
                            set: { details.mainLiftPercent1RM = Int($0) }
                        ),
                        range: 50...100, step: 5
                    )
                }
                focusField
            }
        case .recovery, .mobility, .technique, .rest:
            EmptyView()
        }

        if showProControls, assignment != .rest {
            TextField("Nota de sesión (ejercicios, indicaciones)", text: noteBinding)
                .font(.caption)
                .textInputAutocapitalization(.sentences)
                .padding(.vertical, 6)
        }
    }

    private var focusField: some View {
        TextField("Foco personalizado (opcional)", text: focusBinding)
            .font(.caption)
            .textInputAutocapitalization(.sentences)
            .padding(.vertical, 6)
    }

    private func sliderRow(title: String, value: String, tint: Color, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(tint)
            }
            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { details.startDate(on: .now) ?? .now },
            set: { value in
                let calendar = Calendar.current
                details.startMinute = calendar.component(.hour, from: value) * 60 + calendar.component(.minute, from: value)
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<ScheduledSessionDetails, Int>) -> Binding<Double> {
        Binding(
            get: { Double(details[keyPath: keyPath]) },
            set: { details[keyPath: keyPath] = Int($0) }
        )
    }

    private func optionalIntBinding(_ keyPath: WritableKeyPath<ScheduledSessionDetails, Int?>, fallback: Int) -> Binding<Int> {
        Binding(
            get: { details[keyPath: keyPath] ?? fallback },
            set: { details[keyPath: keyPath] = $0 }
        )
    }

    private var cardioIntentBinding: Binding<CardioIntent?> {
        Binding(
            get: { details.cardioIntent },
            set: { details.cardioIntent = $0 }
        )
    }

    private var percentToggleBinding: Binding<Bool> {
        Binding(
            get: { details.mainLiftPercent1RM != nil },
            set: { details.mainLiftPercent1RM = $0 ? 75 : nil }
        )
    }

    private var focusBinding: Binding<String> {
        Binding(
            get: { details.focusOverride ?? "" },
            set: { details.focusOverride = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { details.sessionNote ?? "" },
            set: { details.sessionNote = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Asistente de plan semanal (rapido o avanzado)

/// Wizard del plan semanal. Modo rapido: perfil, modalidades, dias, revision
/// (4 pantallas, estilo Apple Fitness+). Modo avanzado: suma fase, editor por
/// dia con tipos de alto rendimiento y marcas 1RM. Boton "Atras" siempre
/// disponible para corregir pasos previos.
struct WeeklyPlanOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [WorkoutTemplate]
    /// Plan de biblioteca que se esta editando (nil = agenda activa o nuevo).
    var editingPlan: WeeklyPlan?

    private enum PlanStep: Hashable { case profile, modalities, routinePreview, days, phase, sessions, records, review }
    private enum QuickIntensity: String, CaseIterable, Identifiable {
        case easy, moderate, hard
        var id: String { rawValue }
        var title: String {
            switch self {
            case .easy: "Suave"
            case .moderate: "Moderada"
            case .hard: "Exigente"
            }
        }
        var rpe: Int {
            switch self {
            case .easy: 4
            case .moderate: 6
            case .hard: 8
            }
        }
    }

    @State private var stepIndex = 0
    @State private var advanced = false
    @State private var experience: AthleteExperience = .intermediate
    @State private var objective: TrainingObjective = .general
    @State private var phase: TrainingProgramPhase = .base
    @State private var includesEvent = false
    @State private var eventDate: Date?
    @State private var includeStrength = true
    @State private var includeCardio = true
    @State private var includeMobility = false
    @State private var includeDailyChallenge = false
    @State private var splitType: SplitType = .fullBody
    @State private var cardioSport: CardioSport = .running
    @State private var selectedDays: Set<Int> = [2, 4, 6]
    /// Contador del paso de dias ("¿cuantos dias puedes entrenar?").
    @State private var daysCount = 3
    /// true en cuanto el usuario edita la semana chip por chip: el contador ya
    /// no pisa sus elecciones.
    @State private var didCustomizeDays = false
    @State private var minutes = 45
    @State private var quickIntensity: QuickIntensity = .moderate
    @State private var assignmentOverrides: [Int: DayAssignment] = [:]
    @State private var sessionDetails: [Int: ScheduledSessionDetails] = [:]
    @State private var recordTexts: [String: String] = [:]
    @State private var planName = ""
    @State private var planWeeks = 4
    @State private var didLoadExisting = false
    /// Preset de rutina elegido en el preview (nil = aun no elige).
    @State private var selectedPresetID: String?
    /// Minutos del cardio del plan (el "cuanto tiempo de ese ejercicio").
    @State private var cardioMinutesDraft = 30

    /// Ediciones del usuario sobre el preset (focus -> exercisesText).
    /// Solo se materializan a WorkoutTemplate al guardar el plan.
    @State private var presetDrafts: [String: String] = [:]
    @Environment(\.modelContext) private var modelContext
    @State private var editingPlanID: UUID?
    @State private var editingCreatedAt: Date?

    private let dayOrder = [2, 3, 4, 5, 6, 7, 1]
    private var dayNames: [String] {
        let s = Calendar.current.shortWeekdaySymbols
        return dayOrder.map { s[$0 - 1] }
    }

    init(templates: [WorkoutTemplate], editingPlan: WeeklyPlan? = nil) {
        self.templates = templates
        self.editingPlan = editingPlan
    }

    private var steps: [PlanStep] {
        var result: [PlanStep] = [.profile, .modalities]
        // Al elegir split, el siguiente paso MUESTRA la rutina pre-hecha para
        // aceptarla o editarla antes de armar la semana.
        // El preview muestra fuerza, cardio y movilidad: aparece si hay
        // CUALQUIER modalidad activa, no solo fuerza.
        if includeStrength || includeCardio || includeMobility { result.append(.routinePreview) }
        result.append(.days)
        if advanced {
            result.append(.phase)
            result.append(.sessions)
            if includeStrength { result.append(.records) }
        }
        result.append(.review)
        return result
    }

    private var currentStep: PlanStep { steps[min(stepIndex, steps.count - 1)] }
    private var isLastStep: Bool { stepIndex >= steps.count - 1 }

    private var derivedGoal: WeeklyGoal {
        if includeStrength && includeCardio { return .mixed }
        if includeStrength { return .strength }
        return .cardio
    }

    private var canContinue: Bool {
        switch currentStep {
        case .modalities: includeStrength || includeCardio || includeMobility
        case .routinePreview: !includeStrength || splitType == .custom || selectedPresetID != nil
        case .days: !selectedDays.isEmpty
        default: true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 18) {
                    progress
                    WidthLockedScrollView {
                        Group {
                            switch currentStep {
                            case .profile: profileStep
                            case .modalities: modalitiesStep
                            case .routinePreview: routinePreviewStep
                            case .days: daysStep
                            case .phase: phaseStep
                            case .sessions: sessionsStep
                            case .records: recordsStep
                            case .review: reviewStep
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Spacer(minLength: 0)
                    primaryButton
                }
                .padding(20)
            }
            .navigationTitle("Tu plan semanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if stepIndex > 0 {
                        Button {
                            Haptics.soft()
                            withAnimation(.snappy(duration: 0.25)) { stepIndex -= 1 }
                        } label: {
                            Label("Atrás", systemImage: "chevron.left")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("fitness.routineOnboarding.back")
                    } else {
                        Button {
                            Haptics.soft()
                            dismiss()
                        } label: {
                            Text("Cerrar")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Cerrar")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if stepIndex > 0 {
                        Button {
                            Haptics.soft()
                            dismiss()
                        } label: {
                            Text("Cerrar")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("fitness.routineOnboarding")
        .onAppear(perform: loadExisting)
    }

    // MARK: Pasos

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configura tu plan")
                .font(.title3.weight(.bold))
            Text("La experiencia y el objetivo cambian cómo se presenta la carga; nada se impone automáticamente.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Experiencia").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(AthleteExperience.allCases) { option in
                selectionRow(
                    title: option.title,
                    detail: option.detail,
                    symbol: option == .competitive ? "trophy.fill" : "figure.run",
                    selected: experience == option
                ) {
                    experience = option
                    if option == .advanced || option == .competitive { advanced = true }
                }
            }

            Text("Objetivo principal").font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.top, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TrainingObjective.allCases) { option in
                    Button {
                        Haptics.selection()
                        objective = option
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: option.symbol).foregroundStyle(.cyan)
                            Text(option.title).font(.caption.weight(.semibold)).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .padding(12)
                        .liquidGlass(cornerRadius: 14, tint: objective == option ? .cyan : nil)
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $advanced) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opciones de alto rendimiento")
                        .font(.subheadline.weight(.semibold))
                    Text("Fase, tipos de sesión pro (pliometría, velocidad, contraste, técnica), marcas 1RM y control fino por día.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.cyan)
            .padding(14)
            .liquidGlass(cornerRadius: 14, tint: advanced ? .cyan : nil)
            .accessibilityIdentifier("fitness.routineOnboarding.advanced")
        }
    }

    private var modalitiesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("¿Qué incluye tu semana?")
                .font(.title3.weight(.bold))
            Text("Puedes combinar modalidades; el plan las reparte entre tus días.")
                .font(.caption)
                .foregroundStyle(.secondary)

            modalityToggle("Fuerza", subtitle: "Rutinas con series, repeticiones y kilos.", icon: "dumbbell", isOn: $includeStrength)
            if includeStrength {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tipo de rutina").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(SplitType.allCases) { option in
                        Button {
                            Haptics.selection()
                            if splitType != option {
                                splitType = option
                                // El preset anterior pertenece a otro split.
                                selectedPresetID = nil
                                presetDrafts = [:]
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.icon)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 36, height: 36)
                                    .platformGlass(tint: .cyan, shape: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title).font(.subheadline.weight(.bold))
                                    Text(option.subtitle).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if splitType == option {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan)
                                }
                            }
                            .padding(13)
                            .liquidGlass(cornerRadius: 14, tint: splitType == option ? .cyan : nil)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.routineOnboarding.split.\(option.rawValue)")
                    }
                }
            }

            modalityToggle("Cardio", subtitle: "Elige el deporte, no un 'cardio' genérico.", icon: "figure.run", isOn: $includeCardio)
            if includeCardio {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(CardioSport.allCases) { sport in
                        let on = cardioSport == sport
                        Button {
                            Haptics.selection()
                            cardioSport = sport
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: sport.icon).font(.title3).foregroundStyle(on ? .cyan : .secondary)
                                Text(sport.label).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(on ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(on ? Color.cyan.opacity(0.6) : .clear, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.routineOnboarding.sport.\(sport.rawValue)")
                    }
                }
            }

            modalityToggle("Movilidad y recuperación", subtitle: "Un día ligero de flexibilidad o fisioterapia. Cuenta como recuperación activa, no como día de esfuerzo.", icon: "figure.mind.and.body", isOn: $includeMobility)
                .accessibilityIdentifier("fitness.routineOnboarding.mobilityToggle")

            modalityToggle(
                "Desafío diario",
                subtitle: "Mini-rutina ligera distinta al estímulo del día. Editable y optativa.",
                icon: "flame",
                isOn: $includeDailyChallenge
            )
            .accessibilityIdentifier("fitness.routineOnboarding.dailyChallenge")

            if advanced {
                Label("En el paso «Diseña cada sesión» podrás asignar pliometría, velocidad, contraste, técnica o recuperación a días concretos.", systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func modalityToggle(_ title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            Haptics.selection()
            isOn.wrappedValue.toggle()
            assignmentOverrides = [:]
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .platformGlass(tint: .cyan, shape: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.bold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn.wrappedValue ? .cyan : .secondary)
            }
            .padding(13)
            .liquidGlass(cornerRadius: 14, tint: isOn.wrappedValue ? .cyan : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Que tipo de dia se muestra/cicla en la semana sugerida.
    private enum PlannedDayKind: CaseIterable { case strength, cardio, mobility, rest }

    /// Dias canonicos espaciados para respetar ~48-72 h entre sesiones del
    /// mismo estimulo (L=2 ... D=1).
    static func canonicalDays(for count: Int) -> Set<Int> {
        switch count {
        case ...2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }

    /// Dias de esfuerzo real (fuerza/cardio/plyo...). La movilidad y la
    /// recuperacion cuentan como descanso: no exigen esfuerzo detectable.
    private func effortDays(in plan: [Int: DayAssignment]) -> Int {
        (1...7).filter { !RoutineAssessmentEngine.isRestEquivalent(plan[$0] ?? .rest) }.count
    }

    private var daysStep: some View {
        let plan = suggestedPlan()
        let restDays = (1...7).filter { RoutineAssessmentEngine.isRestEquivalent(plan[$0] ?? .rest) }.count
        let coach = RoutineAssessmentEngine.assess(RoutineAssessmentInput(
            days: plan, splitType: splitType, goal: derivedGoal, planCreatedAt: nil, planWeeks: planWeeks
        ))
        return VStack(alignment: .leading, spacing: 16) {
            Text("¿Cuántos días puedes entrenar?")
                .font(.title3.weight(.bold))
            Picker("Días", selection: Binding(
                get: { daysCount },
                set: { newValue in
                    Haptics.selection()
                    daysCount = newValue
                    // El contador propone; si el usuario ya personalizo la
                    // semana, no pisamos sus elecciones.
                    if !didCustomizeDays {
                        selectedDays = Self.canonicalDays(for: newValue)
                        assignmentOverrides = [:]
                    }
                }
            )) {
                ForEach(2...6, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("fitness.routineOnboarding.daysCount")

            if !advanced {
                HStack {
                    Text("Duración por sesión").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(minutes) min").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.cyan)
                }
                Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }), in: 20...120, step: 5)
                    .tint(.cyan)

                Text("Intensidad general").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Picker("Intensidad", selection: $quickIntensity) {
                    ForEach(QuickIntensity.allCases) { option in Text(option.title).tag(option) }
                }
                .pickerStyle(.segmented)
                Text("Equivale a un esfuerzo percibido (RPE) de \(quickIntensity.rpe)/10 en cada sesión.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label("Duración, intensidad y horario se ajustan por día en el paso de sesiones.", systemImage: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tu semana sugerida")
                    .font(.subheadline.weight(.bold))
                Text("Tócala para ajustar: cada toque cambia el día entre \(cycleDescription).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(Array(dayOrder.enumerated()), id: \.offset) { index, day in
                        let assignment = plan[day] ?? .rest
                        Button {
                            Haptics.selection()
                            cycleDay(day, current: assignment)
                        } label: {
                            VStack(spacing: 5) {
                                Text(dayNames[index])
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Image(systemName: assignment.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(color(for: assignment))
                                    .frame(width: 34, height: 34)
                                    .background(color(for: assignment).opacity(0.14), in: Circle())
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.routineOnboarding.week.\(day)")
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: "moon.zzz")
                        .font(.caption2)
                    Text("\(restDays) \(restDays == 1 ? "día" : "días") de descanso o recuperación activa")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(restDays == 0 ? ScoreKind.strain.color : .secondary)
            }

            // Mini-coach en vivo mientras arma la semana.
            if coach.verdict != .balanced {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: coach.symbol)
                        .font(.caption)
                        .foregroundStyle(coach.verdict == .unsustainable ? ScoreKind.strain.color : ScoreKind.energy.color)
                    Text(coach.headline)
                        .font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityIdentifier("fitness.routineOnboarding.daysCoach")
            }
        }
    }

    /// Tipos disponibles en el ciclo segun las modalidades activas.
    private var availableDayKinds: [PlannedDayKind] {
        var kinds: [PlannedDayKind] = []
        if includeStrength { kinds.append(.strength) }
        if includeCardio { kinds.append(.cardio) }
        if includeMobility { kinds.append(.mobility) }
        kinds.append(.rest)
        return kinds
    }

    private var cycleDescription: String {
        availableDayKinds.map {
            switch $0 {
            case .strength: "fuerza"
            case .cardio: "cardio"
            case .mobility: "movilidad"
            case .rest: "descanso"
            }
        }.joined(separator: " → ")
    }

    private func kind(of assignment: DayAssignment) -> PlannedDayKind {
        switch assignment {
        case .rest: .rest
        case .mobility, .recovery: .mobility
        case .template, .contrast: .strength
        case .plyometrics, .speed, .technique: .cardio
        case .cardio(let name): name == "Fuerza libre" ? .strength : .cardio
        }
    }

    /// Color del chip por tipo de dia (paleta de la agenda semanal).
    private func color(for assignment: DayAssignment) -> Color {
        switch kind(of: assignment) {
        case .rest: .secondary
        case .strength: .cyan
        case .cardio: ScoreKind.strain.color
        case .mobility: ScoreKind.recovery.color
        }
    }

    /// Cicla un dia al siguiente tipo disponible y lo materializa via
    /// selectedDays + assignmentOverrides (las fuentes de verdad existentes).
    private func cycleDay(_ day: Int, current: DayAssignment) {
        let kinds = availableDayKinds
        let currentKind = kind(of: current)
        let currentIndex = kinds.firstIndex(of: currentKind) ?? kinds.count - 1
        let next = kinds[(currentIndex + 1) % kinds.count]
        didCustomizeDays = true

        switch next {
        case .rest:
            selectedDays.remove(day)
            assignmentOverrides[day] = nil
        case .strength:
            selectedDays.insert(day)
            assignmentOverrides[day] = strengthOverride(forDay: day)
        case .cardio:
            selectedDays.insert(day)
            assignmentOverrides[day] = .cardio(sport: cardioSport)
        case .mobility:
            selectedDays.insert(day)
            assignmentOverrides[day] = .mobility
        }
        // El contador refleja solo dias de ESFUERZO: movilidad/recuperacion
        // cuentan como descanso (peticion explicita del usuario).
        daysCount = max(min(effortDays(in: suggestedPlan()), 6), 2)
    }

    /// Override determinista de fuerza para un dia: rota las plantillas del
    /// usuario por orden de dia; sin plantillas cae a "Fuerza libre" (el
    /// save() del preset lo re-mapea a las plantillas materializadas).
    private func strengthOverride(forDay day: Int) -> DayAssignment {
        let strengthTemplates = templates.filter { $0.kind == .strength }
        guard !strengthTemplates.isEmpty else { return .cardio("Fuerza libre") }
        let strengthDaysSorted = dayOrder.filter { d in
            if d == day { return true }
            guard let override = assignmentOverrides[d] else { return false }
            return kind(of: override) == .strength
        }
        let index = strengthDaysSorted.firstIndex(of: day) ?? 0
        return .template(strengthTemplates[index % strengthTemplates.count].id)
    }

    private var routinePreviewStep: some View {
        PresetPickerSection(
            splitType: splitType,
            selectedPresetID: $selectedPresetID,
            presetDrafts: $presetDrafts,
            showStrength: includeStrength,
            cardioSection: includeCardio
                ? CardioPreviewConfig(sport: cardioSport, minutes: $cardioMinutesDraft)
                : nil,
            showMobility: includeMobility,
            challengeSamples: includeDailyChallenge ? challengePreviewSamples() : []
        )
    }

    /// 2-3 challenges de ejemplo para el preview (regla anti-overlap visible).
    private func challengePreviewSamples() -> [DailyChallengeDay] {
        let all = previewChallenges()
        return dayOrder.compactMap { all[$0] }.reduce(into: [DailyChallengeDay]()) { result, day in
            if result.count < 3 && !result.contains(where: { $0.title == day.title }) {
                result.append(day)
            }
        }
    }

    private var phaseStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("¿En qué fase estás?")
                .font(.title3.weight(.bold))
            Text("La fase da contexto a tus semanas y facilita programar descargas o una competencia.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(TrainingProgramPhase.allCases) { option in
                selectionRow(title: option.title, detail: option.detail, symbol: "chart.line.uptrend.xyaxis", selected: phase == option) {
                    phase = option
                }
            }
            Toggle("Tengo una competencia o evento", isOn: $includesEvent)
                .font(.subheadline.weight(.semibold))
                .tint(.cyan)
                .padding(.top, 4)
            if includesEvent {
                DatePicker("Fecha del evento", selection: Binding(
                    get: { eventDate ?? Calendar.current.date(byAdding: .month, value: 2, to: .now) ?? .now },
                    set: { eventDate = $0 }
                ), in: Date.now..., displayedComponents: .date)
                .datePickerStyle(.compact)
            }
        }
    }

    private var sessionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diseña cada sesión")
                .font(.title3.weight(.bold))
            Text("Cambia el tipo de sesión en cada día y ajusta su intención. RPE 1 es muy fácil; RPE 10 es el máximo esfuerzo percibido.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(dayOrder.filter { selectedDays.contains($0) }, id: \.self) { day in
                SessionDetailEditor(
                    weekday: day,
                    assignment: suggestedPlan()[day] ?? .rest,
                    templates: templates,
                    details: detailValueBinding(for: day),
                    onChangeAssignment: { newValue in
                        Haptics.selection()
                        assignmentOverrides[day] = newValue
                    }
                )
                if day != dayOrder.filter({ selectedDays.contains($0) }).last {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
    }

    private var recordsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tus marcas (opcional)")
                .font(.title3.weight(.bold))
            Text("Si conoces tu 1RM — lo máximo que cargas una sola vez — las sesiones de fuerza pueden guiarse por %1RM. Si no, Recvel lo estima desde tus series.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(MainLift.allCases) { lift in
                HStack {
                    Text(lift.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    TextField("kg", text: recordBinding(for: lift))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .liquidGlass(cornerRadius: 10)
                    Text("kg").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Déjalos vacíos si no los sabes: nunca inventamos marcas.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var reviewStep: some View {
        let plan = suggestedPlan()
        let summary = planSummary(plan)
        let expectation = PlanExpectationEngine.expectations(for: PlanExpectationInput(
            objective: objective,
            experience: experience,
            phase: phase,
            trainingDays: summary.trainingDays,
            performanceDays: summary.performanceDays,
            mobilityRecoveryDays: summary.mobilityRecoveryDays,
            weeklyMinutes: summary.weeklyMinutes,
            hardSessions: summary.hardSessions,
            restDays: summary.restDays
        ))
        let coach = RoutineAssessmentEngine.assess(RoutineAssessmentInput(
            days: plan,
            splitType: splitType,
            goal: derivedGoal,
            planCreatedAt: editingCreatedAt,
            planWeeks: planWeeks
        ))
        return VStack(alignment: .leading, spacing: 16) {
            Text("Tu plan semanal")
                .font(.title3.weight(.bold))

            RoutineCoachCard(assessment: coach)
                .accessibilityIdentifier("fitness.routineOnboarding.coach")

            VStack(alignment: .leading, spacing: 10) {
                TextField("Nombre del plan", text: $planName)
                    .font(.subheadline.weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .liquidGlass(cornerRadius: 12)
                Stepper("Duración del bloque: \(planWeeks) semanas", value: $planWeeks, in: 2...12)
                    .font(.caption.weight(.semibold))
            }

            HStack(spacing: 0) {
                summaryMetric(value: "\(summary.trainingDays)", label: "sesiones")
                summaryMetric(value: "\(summary.weeklyMinutes)", label: "min")
                summaryMetric(value: "\(summary.weeklyLoad)", label: "carga")
                summaryMetric(value: "\(summary.hardSessions)", label: "RPE 8+")
            }

            if goalHint != nil {
                Label(goalHint!, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(dayOrder, id: \.self) { day in
                    let assignment = plan[day] ?? .rest
                    HStack(spacing: 10) {
                        Image(systemName: assignment.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(assignment.tintColor)
                            .frame(width: 26, height: 26)
                            .background(assignment.tintColor.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Calendar.current.weekdaySymbols[day - 1])
                                .font(.subheadline.weight(.semibold))
                            if assignment != .rest {
                                Text(sessionSummaryLine(for: day, assignment: assignment))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if includeDailyChallenge, let challenge = previewChallenges()[day] {
                                Text("Desafío · \(challenge.focus)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(ScoreKind.strain.color)
                            }
                        }
                        Spacer()
                        Text(assignment.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                    if day != dayOrder.last {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }

            if !expectation.bullets.isEmpty || !expectation.cautions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Qué esperar de este plan", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                    ForEach(expectation.bullets, id: \.self) { bullet in
                        Label(bullet, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(expectation.cautions, id: \.self) { caution in
                        Label(caution, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(ScoreKind.energy.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .liquidGlass(cornerRadius: 14, tint: .cyan)
                .accessibilityIdentifier("fitness.routineOnboarding.expectations")
            }

            Text("La carga prevista usa sRPE (minutos × RPE). Recvel ajusta consejos según tu respuesta real; nunca sustituye la valoración de un profesional.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var goalHint: String? {
        guard includeStrength else { return nil }
        let rotation = splitType.focusRotation
        guard rotation.count > 1 else { return nil }
        let strengthDays = derivedGoal == .strength ? selectedDays.count : (selectedDays.count + 1) / 2
        if strengthDays < rotation.count {
            return "Con \(strengthDays) días de fuerza no alcanzas a rotar todo el split cada semana."
        }
        return "Rotación sugerida: \(rotation.joined(separator: " · "))"
    }

    // MARK: Componentes

    private func selectionRow(title: String, detail: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(.cyan).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .cyan : .secondary)
            }
            .padding(13)
            .liquidGlass(cornerRadius: 14, tint: selected ? .cyan : nil)
        }
        .buttonStyle(.plain)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= stepIndex ? Color.cyan : Color.white.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if !isLastStep {
                Haptics.medium()
                withAnimation(.snappy(duration: 0.25)) { stepIndex += 1 }
            } else {
                save()
            }
        } label: {
            Text(isLastStep ? "Guardar plan semanal" : "Continuar")
                .font(.headline)
                .primaryCapsuleChrome(tint: .cyan, minHeight: 52)
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.5)
        .accessibilityIdentifier("fitness.routineOnboarding.continue")
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.bold).monospacedDigit())
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Datos del plan

    private struct PlanSummary {
        var trainingDays = 0
        var performanceDays = 0
        var mobilityRecoveryDays = 0
        var weeklyMinutes = 0
        var weeklyLoad = 0
        var hardSessions = 0
        var restDays = 0
    }

    private func planSummary(_ plan: [Int: DayAssignment]) -> PlanSummary {
        var summary = PlanSummary()
        for (day, assignment) in plan where assignment != .rest {
            let detail = details(for: day)
            // Movilidad/recuperacion NO cuentan como dia de entrenamiento:
            // son recuperacion activa (cuentan en mobilityRecoveryDays y en
            // los minutos, pero no inflan las "sesiones" de esfuerzo).
            if assignment.isRecoveryOriented {
                summary.mobilityRecoveryDays += 1
                summary.weeklyMinutes += detail.durationMinutes
                continue
            }
            summary.trainingDays += 1
            summary.weeklyMinutes += detail.durationMinutes
            summary.weeklyLoad += detail.plannedLoad
            if detail.targetRPE >= 8 { summary.hardSessions += 1 }
            if assignment.isHighNeuralDemand { summary.performanceDays += 1 }
        }
        summary.restDays = 7 - summary.trainingDays - summary.mobilityRecoveryDays
        return summary
    }

    private func suggestedPlan() -> [Int: DayAssignment] {
        var plan: [Int: DayAssignment]
        if !includeStrength && !includeCardio {
            plan = [:]
            for day in 1...7 { plan[day] = selectedDays.contains(day) ? .mobility : .rest }
        } else {
            plan = WeeklyRoutinePlanner().suggestedWeek(
                goal: derivedGoal,
                trainingWeekdays: Array(selectedDays),
                templateIDs: templates.filter { $0.kind == .strength }.map(\.id),
                splitType: splitType,
                cardioSport: includeCardio ? cardioSport : nil,
                includeMobility: includeMobility
            )
        }
        return plan.merging(assignmentOverrides) { _, override in override }
    }

    private func details(for day: Int) -> ScheduledSessionDetails {
        if let existing = sessionDetails[day] { return existing }
        let assignment = suggestedPlan()[day] ?? .rest
        return ScheduledSessionDetails(
            startMinute: nil,
            flexibility: .flexible,
            durationMinutes: advanced ? max(assignment.defaultDurationMinutes, 15) : minutes,
            targetRPE: advanced
                ? (phase == .deload ? max(assignment.defaultTargetRPE - 2, 2) : assignment.defaultTargetRPE)
                : quickIntensity.rpe,
            cardioIntent: .easy
        )
    }

    private func detailValueBinding(for day: Int) -> Binding<ScheduledSessionDetails> {
        Binding(
            get: { details(for: day) },
            set: { sessionDetails[day] = $0 }
        )
    }

    private func recordBinding(for lift: MainLift) -> Binding<String> {
        Binding(
            get: { recordTexts[lift.rawValue] ?? "" },
            set: { recordTexts[lift.rawValue] = $0 }
        )
    }

    /// Draft del desafio para un foco, consultado en vivo al contexto.
    private func fetchChallengeDraft(focus: String) -> WorkoutTemplate? {
        let sourceID = PlanGeneratedTemplates.challengeSourceID(focus: focus)
        var descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.sourceID == sourceID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Plantilla de movilidad del plan, consultada en vivo al contexto.
    private func fetchPlanMobilityTemplate() -> WorkoutTemplate? {
        let sourceID = PlanGeneratedTemplates.mobilitySourceID
        var descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.sourceID == sourceID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func previewChallenges() -> [Int: DailyChallengeDay] {
        guard includeDailyChallenge else { return [:] }
        let plan = suggestedPlan()
        let templateFocus = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.focus) })
        return DailyChallengeEngine().generateChallenges(
            days: plan,
            splitType: splitType,
            cardioSport: includeCardio ? cardioSport : nil,
            templateFocus: templateFocus,
            sessionDetails: sessionDetails
        )
    }

    /// Completa movilidad/cardio del plan con rutina concreta (Alcance B).
    private func enrichSessionDetails(
        _ detail: ScheduledSessionDetails,
        assignment: DayAssignment,
        day: Int,
        plan: [Int: DayAssignment]
    ) -> ScheduledSessionDetails {
        var updated = detail
        let engine = DailyChallengeEngine()
        switch assignment {
        case .mobility, .recovery:
            if (updated.exercisesText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let routine = engine.mobilityRoutine(focusHint: updated.focusOverride)
                updated.focusOverride = updated.focusOverride ?? routine.focus
                // La plantilla de movilidad del plan (editable en el preview
                // con el editor de Plantillas) manda sobre el default del engine.
                // Se consulta el contexto (no el array capturado al abrir el
                // wizard) porque pudo crearse DURANTE esta sesion del wizard.
                if let planTemplate = fetchPlanMobilityTemplate(),
                   !planTemplate.exercisesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updated.exercisesText = planTemplate.exercisesText
                    updated.durationMinutes = max(updated.durationMinutes, planTemplate.durationMinutes ?? routine.durationMinutes)
                } else {
                    updated.exercisesText = routine.exercisesText
                }
                updated.durationMinutes = max(updated.durationMinutes, routine.durationMinutes)
                updated.targetRPE = min(updated.targetRPE, 3)
            }
        case .cardio:
            if (updated.exercisesText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let sport = includeCardio ? cardioSport : nil
                // Los minutos del preview ("cuanto tiempo de ese ejercicio")
                // mandan sobre la duracion generica de la sesion.
                let routine = engine.cardioRoutine(sport: sport, durationMinutes: cardioMinutesDraft)
                updated.focusOverride = updated.focusOverride ?? routine.focus
                updated.exercisesText = routine.exercisesText
                updated.durationMinutes = routine.durationMinutes
            }
        default:
            break
        }
        return updated
    }

    private func generatedTemplateDescriptor(
        for assignment: DayAssignment,
        details: ScheduledSessionDetails
    ) -> (kind: WorkoutTemplateKind, focus: String, exercisesText: String) {
        let custom = (details.exercisesText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch assignment {
        case .cardio(let raw):
            let sport = DayAssignment.sport(fromCardioName: raw)?.label ?? raw
            return (.cardio, details.focusOverride ?? sport, custom.isEmpty ? "\(sport) | \(details.durationMinutes) min" : custom)
        case .mobility:
            return (.mobility, details.focusOverride ?? "Movilidad general", custom.isEmpty ? DailyChallengeEngine().mobilityRoutine().exercisesText : custom)
        case .recovery:
            return (.recovery, details.focusOverride ?? "Recuperación activa", custom.isEmpty ? DailyChallengeEngine().mobilityRoutine().exercisesText : custom)
        case .plyometrics:
            return (.performance, details.focusOverride ?? "Potencia", custom.isEmpty ? "Saltos tecnicos | 1x\(details.jumpContacts ?? 40)" : custom)
        case .speed:
            return (.performance, details.focusOverride ?? "Velocidad", custom.isEmpty ? "Sprint \(details.speedDistanceMeters ?? 30) m | 1x\(details.speedReps ?? 6)" : custom)
        case .contrast:
            return (.performance, details.focusOverride ?? "Contraste", custom.isEmpty ? "Bloque de contraste | \(details.contrastSets ?? 3)x4" : custom)
        case .technique:
            return (.performance, details.focusOverride ?? "Técnica", custom.isEmpty ? "Práctica técnica | \(details.durationMinutes) min" : custom)
        case .template, .rest:
            return (.strength, details.focusOverride ?? "Fuerza general", custom)
        }
    }

    private func sessionSummaryLine(for day: Int, assignment: DayAssignment) -> String {
        let detail = details(for: day)
        var parts: [String] = []
        if let start = detail.startDate(on: .now) {
            parts.append(start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)))
        } else {
            parts.append("Flexible")
        }
        parts.append("\(detail.durationMinutes) min")
        parts.append("RPE \(detail.targetRPE)")
        if let contacts = details(for: day).jumpContacts, assignment == .plyometrics {
            parts.append("\(contacts) contactos")
        }
        if let sets = detail.contrastSets, assignment == .contrast {
            parts.append("\(sets) giant sets")
        }
        if assignment == .speed, let reps = detail.speedReps, let meters = detail.speedDistanceMeters {
            parts.append("\(reps) × \(meters) m")
        }
        if let zone = detail.targetZone, case .cardio = assignment {
            parts.append("Z\(zone)")
        }
        if let percent = detail.mainLiftPercent1RM, case .template = assignment {
            parts.append("\(percent)% 1RM")
        }
        return parts.joined(separator: " · ")
    }

    private func save() {
        Haptics.success()
        var plan = suggestedPlan()
        // Ya no se siembra el catalogo entero aqui: eso creaba las 24 plantillas
        // del catalogo aunque el usuario solo eligiera una rutina, y contradecia
        // al comentario de abajo. `upsert` crea lo que falte del preset elegido.
        var availableTemplates = templates

        // Materializar el preset elegido: SOLO al guardar se crean o
        // actualizan WorkoutTemplate (dedupe por nombre exacto), y los dias de
        // fuerza del plan se re-mapean a la rotacion del preset para que la
        // semana use ESTAS plantillas y no todas las del usuario.
        if includeStrength,
           let preset = PresetRoutineCatalog.all.first(where: { $0.id == selectedPresetID }) {
            var rotationIDs: [UUID] = []
            for day in preset.dayTemplates {
                let templateName = "\(preset.name) - \(day.focus)"
                let sourceID = "preset.\(preset.id).\(day.focus)"
                let text = presetDrafts[day.focus]
                    ?? availableTemplates.first(where: { $0.sourceID == sourceID })?.exercisesText
                    ?? day.exercisesText
                let template = ScheduledTemplateMaterializer.upsert(
                    sourceID: sourceID,
                    name: templateName,
                    focus: day.muscleGroup,
                    exercisesText: text,
                    kind: .strength,
                    durationMinutes: nil,
                    in: modelContext,
                    templates: &availableTemplates
                )
                rotationIDs.append(template.id)
            }
            try? modelContext.save()

            var strengthIndex = 0
            for day in dayOrder {
                guard let assignment = plan[day], Self.isStrengthAssignment(assignment) else { continue }
                plan[day] = .template(rotationIDs[strengthIndex % rotationIDs.count])
                strengthIndex += 1
            }

            // Repara bibliotecas ya contaminadas por la siembra masiva previa:
            // tira las plantillas de OTROS presets que el usuario nunca toco.
            // Las editadas se respetan (ver `isPristine`).
            WorkoutTemplateCatalogSeeder.pruneUnusedPresetTemplates(
                keeping: preset.id,
                in: modelContext,
                templates: availableTemplates
            )
        }
        let configuredDetails = Dictionary(uniqueKeysWithValues: (1...7).map { day -> (Int, ScheduledSessionDetails) in
            var detail = details(for: day)
            let assignment = plan[day] ?? .rest
            detail = enrichSessionDetails(detail, assignment: assignment, day: day, plan: plan)
            return (day, detail)
        }.filter { plan[$0.0] != .rest || selectedDays.contains($0.0) })

        // Preferir detalles de días seleccionados / no-rest; merge con configurados.
        var mergedDetails = configuredDetails
        for day in selectedDays {
            if mergedDetails[day] == nil {
                mergedDetails[day] = enrichSessionDetails(details(for: day), assignment: plan[day] ?? .rest, day: day, plan: plan)
            }
        }

        let averageMinutes = mergedDetails.isEmpty
            ? minutes
            : mergedDetails.values.reduce(0) { $0 + $1.durationMinutes } / max(mergedDetails.count, 1)
        let trimmedName = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Plan de \(objective.title)" : trimmedName
        var records: [String: Double] = [:]
        for lift in MainLift.allCases {
            if let text = recordTexts[lift.rawValue]?.replacingOccurrences(of: ",", with: "."),
               let value = Double(text), value > 0 {
                records[lift.rawValue] = value
            }
        }

        let templateFocus = Dictionary(uniqueKeysWithValues: availableTemplates.map { ($0.id, $0.focus) })
        let engine = DailyChallengeEngine()
        let challenges: [Int: DailyChallengeDay]
        if includeDailyChallenge {
            challenges = engine.generateChallenges(
                days: plan,
                splitType: splitType,
                cardioSport: includeCardio ? cardioSport : nil,
                templateFocus: templateFocus,
                sessionDetails: mergedDetails
            )
        } else {
            challenges = [:]
        }

        let planSource = (editingPlanID?.uuidString ?? finalName.lowercased())
            .replacingOccurrences(of: " ", with: "-")
        var sessionTemplateIDs: [Int: UUID] = [:]
        for day in dayOrder {
            let assignment = plan[day] ?? .rest
            guard assignment != .rest else { continue }
            if let selectedID = mergedDetails[day]?.templateID,
               availableTemplates.contains(where: { $0.id == selectedID }) {
                sessionTemplateIDs[day] = selectedID
                continue
            }
            if case .template(let id) = assignment {
                sessionTemplateIDs[day] = id
                continue
            }
            guard let detail = mergedDetails[day] else { continue }
            let descriptor = generatedTemplateDescriptor(for: assignment, details: detail)
            let template = ScheduledTemplateMaterializer.upsert(
                sourceID: "plan.\(planSource).day.\(day)",
                name: "\(finalName) - \(Calendar.current.shortWeekdaySymbols[day - 1]) - \(assignment.shortLabel)",
                focus: descriptor.focus,
                exercisesText: descriptor.exercisesText,
                kind: descriptor.kind,
                durationMinutes: detail.durationMinutes,
                in: modelContext,
                templates: &availableTemplates
            )
            sessionTemplateIDs[day] = template.id
        }

        var challengeTemplateIDs: [Int: UUID] = [:]
        for (day, challenge) in challenges {
            // Si el usuario edito el desafio de este foco en el preview, su
            // draft (plantilla generated.challenge.*) manda sobre el engine.
            let draft = fetchChallengeDraft(focus: challenge.focus)
            let template = ScheduledTemplateMaterializer.upsert(
                sourceID: "plan.\(planSource).challenge.\(day)",
                name: "Desafio - \(Calendar.current.shortWeekdaySymbols[day - 1]) - \(challenge.focus)",
                focus: challenge.focus,
                exercisesText: draft?.exercisesText ?? challenge.exercisesText,
                kind: .dailyChallenge,
                durationMinutes: draft?.durationMinutes ?? challenge.durationMinutes,
                in: modelContext,
                templates: &availableTemplates
            )
            challengeTemplateIDs[day] = template.id
        }
        try? modelContext.save()

        let routine = WeeklyRoutine(
            goal: derivedGoal,
            minutesPerSession: averageMinutes,
            onboarded: true,
            days: plan,
            splitType: splitType,
            cardioSport: includeCardio ? cardioSport : nil,
            minutesPerDay: mergedDetails.mapValues(\.durationMinutes),
            experience: experience,
            objective: objective,
            phase: phase,
            sessionDetails: mergedDetails,
            eventDate: includesEvent ? eventDate : nil,
            planName: finalName,
            advancedConfig: advanced,
            personalRecords: records,
            planWeeks: planWeeks,
            dailyChallengesEnabled: includeDailyChallenge,
            dailyChallenges: challenges,
            sessionTemplateIDs: sessionTemplateIDs,
            dailyChallengeTemplateIDs: challengeTemplateIDs
        )
        WeeklyRoutineStore.save(routine)
        // Reusar el id del plan con el mismo nombre para no duplicar entradas
        // en la biblioteca al editar la agenda varias veces.
        let existingPlans = WeeklyPlanLibraryStore.load()
        let matched = editingPlanID
            ?? existingPlans.first { $0.name.caseInsensitiveCompare(finalName) == .orderedSame }?.id
            ?? UUID()
        let createdAt = editingCreatedAt
            ?? existingPlans.first { $0.id == matched }?.createdAt
            ?? .now
        WeeklyPlanLibraryStore.upsert(WeeklyPlan(
            id: matched,
            name: finalName,
            createdAt: createdAt,
            routine: routine
        ))
        dismiss()
    }

    private func loadExisting() {
        guard !didLoadExisting else { return }
        didLoadExisting = true
        if let editingPlan {
            editingPlanID = editingPlan.id
            editingCreatedAt = editingPlan.createdAt
            load(routine: editingPlan.routine)
            return
        }
        let saved = WeeklyRoutineStore.load()
        guard saved.onboarded else { return }
        load(routine: saved)
    }

    private static func isStrengthAssignment(_ assignment: DayAssignment) -> Bool {
        if case .template = assignment { return true }
        if case .cardio(let name) = assignment, name == "Fuerza libre" { return true }
        return false
    }

    private func load(routine saved: WeeklyRoutine) {
        experience = saved.experience
        objective = saved.objective
        phase = saved.phase
        splitType = saved.splitType
        cardioSport = saved.cardioSport ?? .running
        includeStrength = saved.goal != .cardio
        includeCardio = saved.goal != .strength
        includeMobility = saved.days.values.contains(.mobility)
        includeDailyChallenge = saved.dailyChallengesEnabled
        selectedDays = Set(saved.days.compactMap { $0.value == .rest ? nil : $0.key })
        // Un plan cargado ya es una semana personalizada: el contador refleja
        // y no pisa.
        // Contar solo dias de esfuerzo (movilidad/recuperacion = descanso).
        let effort = saved.days.values.filter { !RoutineAssessmentEngine.isRestEquivalent($0) }.count
        daysCount = max(min(effort, 6), 2)
        // Hidratar los drafts del preview desde el plan guardado.
        for (day, assignment) in saved.days {
            let detail = saved.sessionDetails[day]
            switch assignment {
            case .cardio:
                if let minutes = detail?.durationMinutes, minutes > 0 { cardioMinutesDraft = minutes }
            default:
                break
            }
        }
        didCustomizeDays = true
        minutes = saved.minutesPerSession
        sessionDetails = saved.sessionDetails
        includesEvent = saved.eventDate != nil
        eventDate = saved.eventDate
        advanced = saved.advancedConfig
        planName = saved.planName ?? ""
        planWeeks = saved.planWeeks ?? 4
        recordTexts = saved.personalRecords.mapValues { value in
            value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        }
        // Conservar tipos de sesion personalizados (pliometria, velocidad,
        // contraste...) como overrides sobre la base generada; sin esto, al
        // editar un plan avanzado el wizard regeneraria la semana y los perderia.
        assignmentOverrides = [:]
        let base = suggestedPlan()
        assignmentOverrides = saved.days.filter { base[$0.key] != $0.value }
    }
}

// MARK: - Editor de un dia desde la agenda

/// Edita la sesion de un dia concreto del plan activo (tipo, horario,
/// duracion, RPE y parametros pro). Se abre al tocar un dia de la tira
/// semanal; guarda directo en `WeeklyRoutineStore`.
struct TrainingDayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let weekday: Int
    let templates: [WorkoutTemplate]
    let onSaved: () -> Void

    @State private var routine: WeeklyRoutine
    @State private var assignment: DayAssignment
    @State private var details: ScheduledSessionDetails

    init(weekday: Int, templates: [WorkoutTemplate], onSaved: @escaping () -> Void) {
        self.weekday = weekday
        self.templates = templates
        self.onSaved = onSaved
        let loaded = WeeklyRoutineStore.load()
        _routine = State(initialValue: loaded)
        _assignment = State(initialValue: loaded.days[weekday] ?? .rest)
        _details = State(initialValue: loaded.details(forWeekday: weekday))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                WidthLockedScrollView {
                    SessionDetailEditor(
                        weekday: weekday,
                        assignment: assignment,
                        templates: templates,
                        details: $details,
                        onChangeAssignment: { newValue in
                            Haptics.selection()
                            assignment = newValue
                            if newValue != .rest, details.durationMinutes == 0 {
                                details.durationMinutes = max(newValue.defaultDurationMinutes, 15)
                                details.targetRPE = max(newValue.defaultTargetRPE, 1)
                            }
                        }
                    )
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Calendar.current.weekdaySymbols[weekday - 1])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        Haptics.soft()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Haptics.success()
                        if assignment == .rest {
                            routine.days[weekday] = .rest
                            routine.sessionDetails[weekday] = nil
                            routine.sessionTemplateIDs[weekday] = nil
                        } else {
                            routine.days[weekday] = assignment
                            routine.sessionDetails[weekday] = details
                            if let id = details.templateID {
                                routine.sessionTemplateIDs[weekday] = id
                            } else if case .template(let id) = assignment {
                                routine.sessionTemplateIDs[weekday] = id
                            } else {
                                routine.sessionTemplateIDs[weekday] = nil
                            }
                        }
                        WeeklyRoutineStore.save(routine)
                        onSaved()
                        dismiss()
                    }
                    .accessibilityIdentifier("plan.dayEditor.save")
                }
            }
            .liquidGlassNavigationBar()
        }
        .accessibilityIdentifier("plan.dayEditor")
    }
}

// MARK: - Biblioteca de planes

/// Lista los planes semanales guardados: aplicar, renombrar, duplicar,
/// eliminar uno o eliminar todos. Crear uno nuevo abre el asistente.
struct WeeklyPlanLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [WorkoutTemplate]
    let onApplied: () -> Void

    @State private var plans = WeeklyPlanLibraryStore.load()
    @State private var planToApply: WeeklyPlan?
    @State private var planToRename: WeeklyPlan?
    @State private var renameText = ""
    @State private var showDeleteAllConfirm = false
    @State private var showNewPlan = false

    private var activeRoutine: WeeklyRoutine { WeeklyRoutineStore.load() }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if plans.isEmpty {
                            VStack(spacing: 10) {
                                Text("Sin planes guardados")
                                    .font(.headline)
                                Text("Configura tu plan semanal y guárdalo aquí para reutilizarlo: bloque de fuerza, semana de descarga, pretemporada…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        } else {
                            ForEach(plans) { plan in
                                planRow(plan)
                            }
                            Button(role: .destructive) {
                                Haptics.warning()
                                showDeleteAllConfirm = true
                            } label: {
                                Label("Eliminar todos los planes", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                            .accessibilityIdentifier("fitness.plans.deleteAll")
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Mis planes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        Haptics.soft()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Haptics.add()
                        showNewPlan = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Nuevo plan")
                    .accessibilityIdentifier("fitness.plans.new")
                }
            }
            .liquidGlassNavigationBar()
        }
        .accessibilityIdentifier("fitness.plans.library")
        .confirmationDialog(
            "¿Aplicar «\(planToApply?.name ?? "")»?",
            isPresented: Binding(get: { planToApply != nil }, set: { if !$0 { planToApply = nil } }),
            titleVisibility: .visible
        ) {
            Button("Aplicar plan") {
                guard let planToApply else { return }
                Haptics.success()
                WeeklyRoutineStore.save(planToApply.routine)
                onApplied()
                self.planToApply = nil
                dismiss()
            }
            Button("Cancelar", role: .cancel) { planToApply = nil }
        } message: {
            Text("Reemplaza tu plan semanal actual.")
        }
        .alert("Renombrar plan", isPresented: Binding(get: { planToRename != nil }, set: { if !$0 { planToRename = nil } })) {
            TextField("Nombre", text: $renameText)
            Button("Guardar") {
                guard var plan = planToRename else { return }
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    plan.name = trimmed
                    plan.routine.planName = trimmed
                    plans = WeeklyPlanLibraryStore.upsert(plan)
                    if WeeklyRoutineStore.load().days == plan.routine.days {
                        WeeklyRoutineStore.save(plan.routine)
                    }
                }
                planToRename = nil
            }
            Button("Cancelar", role: .cancel) { planToRename = nil }
        }
        .confirmationDialog("¿Eliminar todos los planes?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Eliminar todos", role: .destructive) {
                Haptics.warning()
                WeeklyPlanLibraryStore.deleteAll()
                plans = []
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tu plan semanal activo no se borra; solo la biblioteca.")
        }
        .sheet(isPresented: $showNewPlan, onDismiss: { plans = WeeklyPlanLibraryStore.load() }) {
            WeeklyPlanOnboardingView(templates: templates)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }

    private func planRow(_ plan: WeeklyPlan) -> some View {
        let isActive = plan.routine == activeRoutine
        let trainingDays = plan.routine.days.values.filter { $0 != .rest }.count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plan.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    if isActive {
                        Text("Activo")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.16), in: Capsule())
                    }
                }
                Text("\(trainingDays) sesiones · \(plan.routine.plannedMinutes) min · carga \(plan.routine.plannedLoad)\(plan.routine.planWeeks.map { " · \($0) sem" } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isActive {
                Button {
                    Haptics.selection()
                    planToApply = plan
                } label: {
                    Text("Aplicar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.plans.apply.\(plan.id.uuidString)")
            }
            Menu {
                Button {
                    renameText = plan.name
                    planToRename = plan
                } label: {
                    Label("Renombrar", systemImage: "pencil")
                }
                Button {
                    Haptics.add()
                    plans = WeeklyPlanLibraryStore.upsert(WeeklyPlan(
                        name: "\(plan.name) (copia)",
                        routine: plan.routine
                    ))
                } label: {
                    Label("Duplicar", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) {
                    Haptics.warning()
                    WeeklyPlanLibraryStore.delete(id: plan.id)
                    plans = WeeklyPlanLibraryStore.load()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .hapticMenuLabel()
        }
        .padding(13)
        .liquidGlass(cornerRadius: 14, tint: isActive ? .cyan : nil)
        .accessibilityIdentifier("fitness.plans.row.\(plan.id.uuidString)")
    }
}

// MARK: - Gestor de plantillas de entrenamiento

/// Lista todas las plantillas con opciones de editar, eliminar una o
/// eliminar todas. Entrada: menu de la seccion "Plantillas de entrenamiento".
struct WorkoutTemplateManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]

    @State private var editing: WorkoutTemplate?
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if templates.isEmpty {
                            Text("No hay rutinas guardadas.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else {
                            ForEach(templates) { template in
                                Button {
                                    Haptics.soft()
                                    editing = template
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: template.kind.icon)
                                            .foregroundStyle(.cyan)
                                            .frame(width: 30, height: 30)
                                            .platformGlass(tint: .cyan, shape: .circle)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name).font(.subheadline.weight(.bold))
                                            Text("\(template.kind.title) · \(template.focus) · \(template.exerciseCount) ejercicios")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(13)
                                    .liquidGlass(cornerRadius: 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("fitness.templates.manage.row.\(template.name.replacingOccurrences(of: " ", with: "_"))")
                            }
                            Button(role: .destructive) {
                                Haptics.warning()
                                showDeleteAllConfirm = true
                            } label: {
                                Label("Eliminar todas las rutinas", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                            .accessibilityIdentifier("fitness.templates.deleteAll")
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Editar rutinas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        Haptics.soft()
                        dismiss()
                    }
                }
            }
            .liquidGlassNavigationBar()
        }
        .accessibilityIdentifier("fitness.templates.manage")
        .confirmationDialog("¿Eliminar todas las rutinas?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Eliminar todas", role: .destructive) {
                Haptics.warning()
                for template in templates {
                    modelContext.delete(template)
                }
                try? modelContext.save()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran \(templates.count) rutinas. Los días y desafíos enlazados conservarán su agenda, pero perderán la rutina editable.")
        }
        .sheet(item: $editing) { template in
            WorkoutTemplateEditor(editing: template)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }
}
