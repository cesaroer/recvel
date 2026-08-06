import SwiftUI
import SwiftData

// MARK: - Rutinas pre-hechas (catalogo estatico basado en evidencia)
//
// Cada preset es una rutina completa por dia de rotacion del split, con
// ejercicios EXACTOS de `ExerciseLibrary` (sin tildes) serializados en el
// formato de `TemplateCodec` ("Nombre | 3x12"). Los `WorkoutTemplate` reales
// se materializan al abrir Entrenamiento y se reutilizan al guardar el plan.
//
// Los badges describen la INTENCION del preset (rangos de reps y volumen),
// nunca prometen resultados. Evidencia detras de los rangos:
// - Hipertrofia: 8-12 reps, ~10+ series/grupo/semana con frecuencia 2-3x
//   (Schoenfeld et al., meta-analisis 2016/2019: el volumen semanal por grupo
//   es el driver principal; el split solo lo reparte).
// - Fuerza maxima: 3-6 reps con cargas altas en basicos multiarticulares.
// - Resistencia muscular / metabolico: 12-15+ reps.

/// Un dia de rotacion de un preset (ej. "Empuje" en PPL).
struct PresetDayTemplate: Identifiable, Equatable {
    /// Etiqueta del dia dentro del split ("Full body A", "Tren superior"...).
    let focus: String
    /// Grupo muscular dominante, para el desglose de volumen (`MuscleRadar`).
    let muscleGroup: String
    /// Ejercicios en formato `TemplateCodec` (una linea por ejercicio).
    let exercisesText: String
    var id: String { focus }
}

/// Rutina pre-hecha para un split, con badge honesto y racional citado.
struct PresetRoutine: Identifiable, Equatable {
    let id: String
    let name: String
    let splitType: SplitType
    /// Banner de intencion: "Ideal para hipertrofia", "Ideal para fortalecer pierna"...
    let badge: String
    let objective: TrainingObjective
    /// Dias de fuerza por semana recomendados para completar la rotacion.
    let recommendedDays: ClosedRange<Int>
    let dayTemplates: [PresetDayTemplate]
    /// Una linea de por que, con el principio detras (no promesas).
    let rationale: String
}

enum PresetRoutineCatalog {
    /// Presets disponibles para un split. `custom` no tiene: el usuario parte
    /// de cero con sus propias plantillas.
    static func presets(for split: SplitType) -> [PresetRoutine] {
        all.filter { $0.splitType == split }
    }

    static let all: [PresetRoutine] = [
        // MARK: Full body
        PresetRoutine(
            id: "fullBody.hypertrophy",
            name: "Full body crecimiento",
            splitType: .fullBody,
            badge: RecvelL10n.text("Ideal para hipertrofia"),
            objective: .hypertrophy,
            recommendedDays: 2...3,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Full body A",
                    muscleGroup: "General",
                    exercisesText: """
                    Sentadilla | 3x10
                    Press de banca | 3x10
                    Remo con barra | 3x10
                    Press militar | 3x12
                    Curl de biceps | 3x12
                    Plancha | 3x30
                    """
                ),
                PresetDayTemplate(
                    focus: "Full body B",
                    muscleGroup: "General",
                    exercisesText: """
                    Peso muerto | 3x8
                    Press inclinado | 3x10
                    Jalon al pecho | 3x10
                    Zancadas | 3x10
                    Extension de triceps | 3x12
                    Crunch | 3x15
                    """
                )
            ],
            rationale: RecvelL10n.text("8-12 reps y cada grupo 2-3 veces por semana: el volumen semanal es el driver principal del crecimiento.")
        ),
        PresetRoutine(
            id: "fullBody.strength",
            name: "Full body fuerza",
            splitType: .fullBody,
            badge: RecvelL10n.text("Ideal para ganar fuerza"),
            objective: .maximalStrength,
            recommendedDays: 2...3,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Fuerza A",
                    muscleGroup: "General",
                    exercisesText: """
                    Sentadilla | 5x5
                    Press de banca | 5x5
                    Remo con barra | 4x6
                    Plancha | 3x30
                    """
                ),
                PresetDayTemplate(
                    focus: "Fuerza B",
                    muscleGroup: "General",
                    exercisesText: """
                    Peso muerto | 3x5
                    Press militar | 5x5
                    Dominadas | 4x6
                    Prensa | 3x8
                    """
                )
            ],
            rationale: RecvelL10n.text("3-6 reps con cargas altas en basicos multiarticulares: el rango clasico para fuerza maxima.")
        ),

        // MARK: Torso / pierna
        PresetRoutine(
            id: "upperLower.hypertrophy",
            name: "Torso-pierna crecimiento",
            splitType: .upperLower,
            badge: RecvelL10n.text("Ideal para hipertrofia"),
            objective: .hypertrophy,
            recommendedDays: 4...4,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Tren superior",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 4x8
                    Remo con barra | 4x8
                    Press inclinado | 3x10
                    Jalon al pecho | 3x10
                    Elevaciones laterales | 3x12
                    Curl de biceps | 3x12
                    Extension de triceps | 3x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Tren inferior",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Sentadilla | 4x8
                    Peso muerto | 3x6
                    Prensa | 3x10
                    Zancadas | 3x10
                    Elevacion de talones | 4x12
                    Plancha | 3x30
                    """
                )
            ],
            rationale: RecvelL10n.text("Con 4 dias, cada mitad del cuerpo se entrena 2 veces por semana con volumen alto por sesion.")
        ),
        PresetRoutine(
            id: "upperLower.legFocus",
            name: "Torso-pierna enfoque pierna",
            splitType: .upperLower,
            badge: RecvelL10n.text("Ideal para fortalecer pierna"),
            objective: .maximalStrength,
            recommendedDays: 4...4,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Tren superior",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 3x8
                    Remo con barra | 3x8
                    Press militar | 3x10
                    Curl de biceps | 2x12
                    Extension de triceps | 2x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Tren inferior",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Sentadilla | 5x5
                    Peso muerto | 4x6
                    Prensa | 4x10
                    Zancadas | 3x10
                    Elevacion de talones | 4x15
                    """
                )
            ],
            rationale: RecvelL10n.text("Prioriza pierna con mas series y cargas altas; el torso queda en volumen de mantenimiento.")
        ),

        // MARK: Empuje / jalon / pierna
        PresetRoutine(
            id: "pushPullLegs.hypertrophy",
            name: "PPL crecimiento",
            splitType: .pushPullLegs,
            badge: RecvelL10n.text("Ideal para hipertrofia"),
            objective: .hypertrophy,
            recommendedDays: 3...6,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Empuje",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 4x8
                    Press militar | 3x10
                    Press inclinado | 3x10
                    Elevaciones laterales | 3x12
                    Extension de triceps | 3x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Jalon",
                    muscleGroup: "Espalda",
                    exercisesText: """
                    Dominadas | 4x8
                    Remo con barra | 4x8
                    Remo con mancuerna | 3x10
                    Face pull | 3x15
                    Curl de biceps | 3x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Pierna",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Sentadilla | 4x8
                    Peso muerto | 3x6
                    Prensa | 3x10
                    Zancadas | 3x10
                    Elevacion de talones | 4x15
                    """
                )
            ],
            rationale: RecvelL10n.text("Con 6 dias cada patron se repite 2 veces por semana; con 3, una vuelta completa de volumen alto.")
        ),
        PresetRoutine(
            id: "pushPullLegs.strength",
            name: "PPL fuerza",
            splitType: .pushPullLegs,
            badge: RecvelL10n.text("Ideal para ganar fuerza"),
            objective: .maximalStrength,
            recommendedDays: 3...6,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Empuje",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 5x5
                    Press militar | 4x6
                    Fondos | 3x8
                    Extension de triceps | 2x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Jalon",
                    muscleGroup: "Espalda",
                    exercisesText: """
                    Peso muerto | 3x5
                    Dominadas | 4x6
                    Remo con barra | 4x6
                    Curl de biceps | 2x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Pierna",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Sentadilla | 5x5
                    Prensa | 4x8
                    Zancadas | 3x8
                    Elevacion de talones | 3x12
                    """
                )
            ],
            rationale: RecvelL10n.text("Basicos pesados a 3-6 reps con accesorios reducidos: fuerza primero, volumen justo.")
        ),

        // MARK: Un grupo por dia
        PresetRoutine(
            id: "broSplit.classicVolume",
            name: RecvelL10n.text("Grupo por dia clasico"),
            splitType: .broSplit,
            badge: RecvelL10n.text("Ideal para hipertrofia con 5+ dias"),
            objective: .hypertrophy,
            recommendedDays: 5...6,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Pecho",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 4x8
                    Press inclinado | 3x10
                    Aperturas con mancuernas | 3x12
                    Fondos | 3x10
                    """
                ),
                PresetDayTemplate(
                    focus: "Espalda",
                    muscleGroup: "Espalda",
                    exercisesText: """
                    Dominadas | 4x8
                    Remo con barra | 4x8
                    Jalon al pecho | 3x10
                    Remo con mancuerna | 3x12
                    """
                ),
                PresetDayTemplate(
                    focus: "Piernas",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Sentadilla | 4x8
                    Prensa | 3x10
                    Zancadas | 3x10
                    Elevacion de talones | 4x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Hombros",
                    muscleGroup: "Hombros",
                    exercisesText: """
                    Press militar | 4x8
                    Elevaciones laterales | 4x12
                    Face pull | 3x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Brazos",
                    muscleGroup: "Brazos",
                    exercisesText: """
                    Curl de biceps | 4x10
                    Curl martillo | 3x12
                    Extension de triceps | 4x10
                    Rueda abdominal | 3x10
                    """
                )
            ],
            rationale: RecvelL10n.text("Volumen alto por grupo en su dia. Ojo: con menos de 5 dias la frecuencia por grupo cae bajo 2x/semana.")
        ),
        PresetRoutine(
            id: "broSplit.pump",
            name: RecvelL10n.text("Grupo por dia metabolico"),
            splitType: .broSplit,
            badge: RecvelL10n.text("Ideal para resistencia muscular"),
            objective: .endurance,
            recommendedDays: 5...6,
            dayTemplates: [
                PresetDayTemplate(
                    focus: "Pecho",
                    muscleGroup: "Pecho",
                    exercisesText: """
                    Press de banca | 3x12
                    Press inclinado | 3x12
                    Aperturas con mancuernas | 3x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Espalda",
                    muscleGroup: "Espalda",
                    exercisesText: """
                    Jalon al pecho | 3x12
                    Remo con mancuerna | 3x12
                    Face pull | 3x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Piernas",
                    muscleGroup: "Piernas",
                    exercisesText: """
                    Prensa | 3x15
                    Zancadas | 3x12
                    Elevacion de talones | 4x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Hombros",
                    muscleGroup: "Hombros",
                    exercisesText: """
                    Press militar | 3x12
                    Elevaciones laterales | 3x15
                    Face pull | 3x15
                    """
                ),
                PresetDayTemplate(
                    focus: "Brazos",
                    muscleGroup: "Brazos",
                    exercisesText: """
                    Curl de biceps | 3x15
                    Curl martillo | 3x12
                    Extension de triceps | 3x15
                    """
                )
            ],
            rationale: RecvelL10n.text("12-15 reps con descansos cortos: resistencia muscular y trabajo metabolico, no cargas maximas.")
        )
    ]
}

// MARK: - Biblioteca compartida

/// Materializa el catalogo incluido como `WorkoutTemplate` reales. El usuario
/// puede verlos y editarlos desde Plantillas; `sourceID` evita duplicados.
@MainActor
enum WorkoutTemplateCatalogSeeder {
    static func sourceID(for preset: PresetRoutine, day: PresetDayTemplate) -> String {
        "preset.\(preset.id).\(day.focus)"
    }

    /// Materializa en la biblioteca los dias de **un** preset, el que el usuario
    /// eligio. Idempotente por `sourceID`.
    ///
    /// Antes existia un `seed(in:existing:)` que materializaba el catalogo
    /// ENTERO —8 presets x 3 dias = 24 `WorkoutTemplate`— y se llamaba al abrir
    /// la pestaña de Entrenamiento, al abrir el selector y al guardar el plan.
    /// Resultado: cualquiera que entrara una vez a Entrenamiento se encontraba
    /// 24 plantillas que nunca creo. El catalogo (`PresetRoutineCatalog`) es
    /// dato estatico y la UI puede pintarlo sin escribir en SwiftData; solo se
    /// crean filas cuando el usuario se compromete con una rutina.
    @discardableResult
    static func materialize(
        preset: PresetRoutine,
        in context: ModelContext,
        existing: [WorkoutTemplate]
    ) -> [WorkoutTemplate] {
        var result = existing
        for day in preset.dayTemplates {
            let id = sourceID(for: preset, day: day)
            guard !result.contains(where: { $0.sourceID == id }) else { continue }
            let template = WorkoutTemplate(
                name: "\(preset.name) - \(day.focus)",
                focus: day.muscleGroup,
                exercisesText: day.exercisesText,
                kind: .strength,
                sourceID: id
            )
            context.insert(template)
            result.append(template)
        }
        if result.count != existing.count { try? context.save() }
        return result
    }

    /// Borra plantillas de preset que el usuario nunca eligio.
    ///
    /// Repara las bibliotecas ya contaminadas por el `seed` masivo anterior:
    /// conserva las del preset indicado y las que el usuario haya tocado
    /// (renombradas o con ejercicios editados), y tira el resto. Sin esto, quien
    /// ya tenga las 24 se las queda para siempre.
    static func pruneUnusedPresetTemplates(
        keeping keptPresetID: String?,
        in context: ModelContext,
        templates: [WorkoutTemplate]
    ) {
        let keptPrefix = keptPresetID.map { "preset.\($0)." }
        var removed = false
        for template in templates {
            guard let source = template.sourceID, source.hasPrefix("preset.") else { continue }
            if let keptPrefix, source.hasPrefix(keptPrefix) { continue }
            guard isPristine(template) else { continue }
            context.delete(template)
            removed = true
        }
        if removed { try? context.save() }
    }

    /// `true` si la plantilla sigue exactamente como la creo el catalogo, asi
    /// que borrarla no destruye trabajo del usuario.
    private static func isPristine(_ template: WorkoutTemplate) -> Bool {
        guard let source = template.sourceID else { return false }
        for preset in PresetRoutineCatalog.all {
            for day in preset.dayTemplates where sourceID(for: preset, day: day) == source {
                return template.name == "\(preset.name) - \(day.focus)"
                    && template.exercisesText == day.exercisesText
                    && template.focus == day.muscleGroup
            }
        }
        return false
    }
}

/// Unico punto para crear o actualizar rutinas generadas por la agenda.
@MainActor
enum ScheduledTemplateMaterializer {
    static func upsert(
        sourceID: String,
        name: String,
        focus: String,
        exercisesText: String,
        kind: WorkoutTemplateKind,
        durationMinutes: Int?,
        in context: ModelContext,
        templates: inout [WorkoutTemplate]
    ) -> WorkoutTemplate {
        if let existing = templates.first(where: { $0.sourceID == sourceID }) {
            existing.name = name
            existing.focus = focus
            existing.exercisesText = exercisesText
            existing.kind = kind
            existing.durationMinutes = durationMinutes
            return existing
        }
        let template = WorkoutTemplate(
            name: name,
            focus: focus,
            exercisesText: exercisesText,
            kind: kind,
            sourceID: sourceID,
            durationMinutes: durationMinutes
        )
        context.insert(template)
        templates.append(template)
        return template
    }
}

// MARK: - UI del preview de rutina (paso del wizard)

/// Selector de rutina pre-hecha. Cada dia es un `WorkoutTemplate` real y abre
/// el mismo editor que la biblioteca de Plantillas.
struct PresetPickerSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    let splitType: SplitType
    @Binding var selectedPresetID: String?
    @Binding var presetDrafts: [String: String]
    /// Mostrar la seccion de fuerza (false cuando la semana no la incluye).
    var showStrength: Bool = true
    /// Seccion de cardio (deporte + minutos), nil si la semana no incluye cardio.
    var cardioSection: CardioPreviewConfig?
    /// Mostrar la seccion de movilidad (la semana la incluye).
    var showMobility: Bool = false
    /// Ejemplos del desafio diario ([] = desactivado).
    var challengeSamples: [DailyChallengeDay] = []
    @State private var editingTemplate: WorkoutTemplate?

    private var presets: [PresetRoutine] { PresetRoutineCatalog.presets(for: splitType) }
    private var selected: PresetRoutine? { presets.first { $0.id == selectedPresetID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(RecvelL10n.text("Tu rutina sugerida"))
                .font(.title3.weight(.bold))
            Text(previewSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if showStrength && !presets.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(presets) { preset in
                            presetCard(preset)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)

                if let selected {
                    routineDetail(selected)
                }
            }

            if let cardioSection {
                cardioPreviewCard(cardioSection)
            }

            if showMobility {
                mobilityPreviewCard
            }

            if !challengeSamples.isEmpty {
                challengePreviewCard
            }
        }
        .sheet(item: $editingTemplate) { template in
            WorkoutTemplateEditor(editing: template)
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }

        .onAppear {
            // Abrir el selector NO materializa nada: las tarjetas se pintan
            // desde `PresetRoutineCatalog`, que es dato estatico. Las filas de
            // SwiftData se crean al guardar el plan.
            if selectedPresetID == nil { selectedPresetID = presets.first?.id }
        }
    }

    private var previewSubtitle: String {
        if !showStrength {
            return RecvelL10n.text("Tu semana incluye cardio y recuperacion: asi se veran esas sesiones.")
        }
        return splitType == .custom
            ? RecvelL10n.text("Elegiste personalizado: armaras tus plantillas a mano y el plan las rotara.")
            : RecvelL10n.text("Rutinas armadas segun la evidencia para tu split. Elige una y ajustala a tu gusto.")
    }

    /// Plantilla de movilidad del plan, si ya existe.
    private var mobilityTemplate: WorkoutTemplate? {
        templates.first { $0.sourceID == PlanGeneratedTemplates.mobilitySourceID }
    }

    /// Texto actual de la rutina de movilidad (plantilla o default del engine).
    private var mobilityText: String {
        if let text = mobilityTemplate?.exercisesText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return DailyChallengeEngine().mobilityRoutine().exercisesText
    }

    /// Editar un desafio = materializar su draft por foco y abrir EL editor
    /// de plantillas. El save del plan usa este draft en vez del texto del
    /// engine para los dias con ese foco.
    private func editChallenge(_ sample: DailyChallengeDay) {
        let sourceID = PlanGeneratedTemplates.challengeSourceID(focus: sample.focus)
        let existing = templates.first { $0.sourceID == sourceID }
        var mutable = templates.map { $0 }
        let template = ScheduledTemplateMaterializer.upsert(
            sourceID: sourceID,
            name: "Desafío — \(sample.focus)",
            focus: sample.focus,
            exercisesText: existing?.exercisesText ?? sample.exercisesText,
            kind: .dailyChallenge,
            durationMinutes: existing?.durationMinutes ?? sample.durationMinutes,
            in: modelContext,
            templates: &mutable
        )
        try? modelContext.save()
        editingTemplate = template
    }

    /// Editar movilidad = materializar la plantilla y abrir EL editor de
    /// plantillas (fuente unica: las rutinas viven en Plantillas).
    private func editMobility() {
        let routine = DailyChallengeEngine().mobilityRoutine()
        var mutable = templates.map { $0 }
        let template = ScheduledTemplateMaterializer.upsert(
            sourceID: PlanGeneratedTemplates.mobilitySourceID,
            name: RecvelL10n.text("Movilidad y recuperación"),
            focus: mobilityTemplate?.focus ?? routine.focus,
            exercisesText: mobilityText,
            kind: .mobility,
            durationMinutes: mobilityTemplate?.durationMinutes ?? routine.durationMinutes,
            in: modelContext,
            templates: &mutable
        )
        try? modelContext.save()
        editingTemplate = template
    }

    /// Cardio del plan: UN ejercicio (el deporte) + cuanto tiempo.
    private func cardioPreviewCard(_ config: CardioPreviewConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: config.sport.icon)
                    .font(.headline)
                    .foregroundStyle(ScoreKind.strain.color)
                    .frame(width: 34, height: 34)
                    .background(ScoreKind.strain.color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cardio · \(config.sport.label)")
                        .font(.subheadline.weight(.bold))
                    Text(RecvelL10n.text("Un solo ejercicio, medido por tiempo."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Stepper(value: config.$minutes, in: 10...90, step: 5) {
                Text("\(config.minutes) min por sesión")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fitness.routineOnboarding.cardioMinutes")
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14, tint: ScoreKind.strain.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.routineOnboarding.cardioPreview")
    }

    /// Movilidad y recuperacion: rutina propia, editable, contada como descanso.
    private var mobilityPreviewCard: some View {
        let exercises = TemplateCodec.parse(mobilityText)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "figure.yoga")
                        .font(.headline)
                        .foregroundStyle(ScoreKind.recovery.color)
                        .frame(width: 34, height: 34)
                        .background(ScoreKind.recovery.color.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(RecvelL10n.text("Movilidad y recuperación"))
                            .font(.subheadline.weight(.bold))
                        Text(RecvelL10n.text("Cuenta como recuperación activa, no como día de esfuerzo."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Haptics.soft()
                    editMobility()
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ScoreKind.recovery.color)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.routineOnboarding.editMobility")
            }
            ForEach(exercises) { exercise in
                HStack(spacing: 10) {
                    Image(systemName: ExerciseLibrary.item(named: exercise.name)?.symbol ?? "figure.flexibility")
                        .font(.caption)
                        .foregroundStyle(ScoreKind.recovery.color)
                        .frame(width: 22)
                    Text(RecvelL10n.text(exercise.name)).font(.caption)
                    Spacer()
                    Text(prescriptionLabel(exercise))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14, tint: ScoreKind.recovery.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.routineOnboarding.mobilityPreview")
    }

    /// Desafio diario: mini-preview con la regla visible.
    private var challengePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.badge.clock")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .frame(width: 34, height: 34)
                    .background(Color.yellow.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(RecvelL10n.text("Desafío diario"))
                        .font(.subheadline.weight(.bold))
                    Text(RecvelL10n.text("Mini-rutina ligera, siempre distinta a lo que entrenas ese día."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(challengeSamples) { sample in
                HStack(spacing: 8) {
                    Text(sample.title).font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(sample.durationMinutes) min · \(sample.focus)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button {
                        Haptics.soft()
                        editChallenge(sample)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Editar \(sample.title)")
                    .accessibilityIdentifier("fitness.routineOnboarding.editChallenge.\(sample.focus)")
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14, tint: .yellow)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.routineOnboarding.challengePreview")
    }

    private func prescriptionLabel(_ exercise: TemplateExercise) -> String {
        if let seconds = exercise.durationSeconds {
            return seconds.isMultiple(of: 60) ? "\(seconds / 60) min" : "\(seconds)s"
        }
        if exercise.sets <= 1 { return "\(exercise.reps)" }
        return "\(exercise.sets)x\(exercise.reps)"
    }

    private func presetCard(_ preset: PresetRoutine) -> some View {
        let isOn = selectedPresetID == preset.id
        return Button {
            Haptics.selection()
            if selectedPresetID != preset.id {
                selectedPresetID = preset.id
                presetDrafts = [:]
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Badge de intencion, honesto (rangos/volumen, no promesas).
                Text(preset.badge)
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(isOn ? 0.28 : 0.14)))
                    .foregroundStyle(.cyan)
                Text(preset.name)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.leading)
                Text("\(preset.recommendedDays.lowerBound)-\(preset.recommendedDays.upperBound) dias · \(preset.dayTemplates.count) sesiones distintas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(preset.rationale)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 210, height: 148, alignment: .topLeading)
            .padding(13)
            .liquidGlass(cornerRadius: 14, tint: isOn ? .cyan : nil)
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                        .padding(8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fitness.routineOnboarding.preset.\(preset.id)")
    }

    private func routineDetail(_ preset: PresetRoutine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(preset.dayTemplates) { day in
                let text = presetDrafts[day.focus] ?? template(for: preset, day: day)?.exercisesText ?? day.exercisesText
                let exercises = TemplateCodec.parse(text)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(day.focus).font(.subheadline.weight(.bold))
                        Spacer()
                        Button {
                            Haptics.soft()
                            // Materializa al vuelo SOLO este preset: tocar
                            // "Editar" es un acto explicito del usuario, asi que
                            // aqui si toca crear la fila. El resto del catalogo
                            // sigue sin escribirse.
                            editingTemplate = templateForEditing(preset: preset, day: day)
                        } label: {
                            Label("Editar", systemImage: "pencil")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.cyan)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.routineOnboarding.editDay.\(day.focus)")
                    }
                    ForEach(exercises) { exercise in
                        HStack(spacing: 10) {
                            Image(systemName: ExerciseLibrary.item(named: exercise.name)?.symbol ?? "dumbbell")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                                .frame(width: 22)
                            Text(RecvelL10n.text(exercise.name)).font(.caption)
                            Spacer()
                            Text("\(exercise.sets)x\(exercise.reps)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(13)
                .liquidGlass(cornerRadius: 13)
            }
        }
    }

    /// Solo consulta: `nil` mientras el preset no se haya materializado.
    private func template(for preset: PresetRoutine, day: PresetDayTemplate) -> WorkoutTemplate? {
        templates.first { $0.sourceID == WorkoutTemplateCatalogSeeder.sourceID(for: preset, day: day) }
    }

    /// Consulta y, si hace falta, materializa el preset para poder editarlo.
    private func templateForEditing(preset: PresetRoutine, day: PresetDayTemplate) -> WorkoutTemplate? {
        if let existing = template(for: preset, day: day) { return existing }
        let created = WorkoutTemplateCatalogSeeder.materialize(
            preset: preset,
            in: modelContext,
            existing: templates
        )
        let id = WorkoutTemplateCatalogSeeder.sourceID(for: preset, day: day)
        return created.first { $0.sourceID == id }
    }
}

// MARK: - Card del Coach (review del wizard + agenda semanal)

/// La voz del coach sobre la semana armada: veredicto + evidencia plegable.
struct RoutineCoachCard: View {
    let assessment: RoutineAssessment
    @State private var showEvidence = false

    private var accent: Color {
        switch assessment.verdict {
        case .balanced: ScoreKind.recovery.color
        case .caution: ScoreKind.energy.color
        case .unsustainable: ScoreKind.strain.color
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: assessment.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(assessment.headline).font(.subheadline.weight(.bold))
                    Text(assessment.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                Haptics.soft()
                withAnimation(.snappy(duration: 0.22)) { showEvidence.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "text.book.closed")
                    Text(showEvidence ? "Ocultar evidencia" : RecvelL10n.text("Ver evidencia"))
                    Image(systemName: showEvidence ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showEvidence {
                Text(assessment.evidence)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .liquidGlass(cornerRadius: 14, tint: accent)
    }
}

// MARK: - Secciones de cardio, movilidad y desafio en el preview

/// Config de la seccion de cardio del preview: deporte elegido + minutos.
struct CardioPreviewConfig {
    let sport: CardioSport
    @Binding var minutes: Int
}

/// sourceID de la plantilla de movilidad del plan (fuente unica, editable
/// con el mismo WorkoutTemplateEditor de la biblioteca).
enum PlanGeneratedTemplates {
    static let mobilitySourceID = "generated.mobility.plan"

    /// Draft editable del desafio diario, uno por foco ("Tren inferior"...).
    /// El save del plan lo respeta sobre el texto del engine.
    static func challengeSourceID(focus: String) -> String {
        let slug = focus
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
        return "generated.challenge.\(slug)"
    }
}
