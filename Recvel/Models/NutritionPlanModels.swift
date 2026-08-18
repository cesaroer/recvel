import Foundation
import SwiftData

// MARK: - Cuestionario del plan generado
//
// Cada pregunta existe porque la literatura la justifica y la app NO la tiene
// todavia. Lo que ya se conoce —peso, altura, edad, sexo, objetivo, dieta,
// alergias, comidas/dia, pasos, % grasa, sueno/recuperacion/strain— se lee del
// perfil y de HealthKit sin preguntar. Referencias y rangos:
// ver NUTRITION_PLAN_RESEARCH.md en la raiz del repo.

/// Condiciones que activan Medical Nutrition Therapy (Academy of Nutrition
/// and Dietetics) o modifican la prescripcion (OMS 2026, DASH-Sodium NEJM 2001,
/// Evert et al. Diabetes Care 2019).
enum PlanMedicalCondition: String, CaseIterable, Identifiable, Codable {
    case diabetes
    case hypertension
    case kidneyDisease
    case celiac
    case thyroid
    case none

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.condition.\(rawValue)") }
}

/// Farmacos con interacciones farmaco-nutriente documentadas (Mouly 2017,
/// Liwanpo & Hershman 2009, DPPOS B12, jugo de toronja/estatinas).
enum PlanMedication: String, CaseIterable, Identifiable, Codable {
    case warfarin
    case levothyroxine
    case metformin
    case statins
    case none

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.medication.\(rawValue)") }
}

/// NEAT: la ocupacion explica hasta ~2,000 kcal/dia de varianza en TDEE
/// (Endotext 2022, Levine Science 1999). Entrenamientos/semana solo no basta.
enum PlanOccupation: String, CaseIterable, Identifiable, Codable {
    case sedentary
    case onFeet
    case physical

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.occupation.\(rawValue)") }
    var detail: String { RecvelL10n.text("planflow.occupation.\(rawValue).detail") }
    var icon: String {
        switch self {
        case .sedentary: "chair.fill"
        case .onFeet: "figure.stand"
        case .physical: "figure.strengthtraining.functional"
        }
    }
}

/// Hora del entrenamiento para programar el timing peri-entreno
/// (ISSN Nutrient Timing 2017).
enum PlanTrainingTime: String, CaseIterable, Identifiable, Codable {
    case morning
    case midday
    case afternoon
    case evening

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.trainingTime.\(rawValue)") }
}

/// Duracion: >60-70 min intenso cambia la recomendacion de carbohidratos
/// durante la sesion (30-60 g/h, ISSN Timing 2017).
enum PlanTrainingDuration: String, CaseIterable, Identifiable, Codable {
    case under45
    case from45to75
    case over75

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.duration.\(rawValue)") }
}

/// La respuesta a la cafeina depende del consumo habitual (ISSN Caffeine 2021)
/// y 400 mg incluso 6 h antes de dormir altera el sueno (Drake 2013).
enum PlanCaffeineLevel: String, CaseIterable, Identifiable, Codable {
    case none
    case moderate
    case high

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.caffeine.\(rawValue)") }
}

/// Adherencia: el presupuesto filtra alimentos del plan (Academy 2017, OMS 2026).
enum PlanBudget: String, CaseIterable, Identifiable, Codable {
    case tight
    case moderate
    case flexible

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.budget.\(rawValue)") }
    var detail: String { RecvelL10n.text("planflow.budget.\(rawValue).detail") }
}

/// Tiempo de cocina: predictor de adherencia; filtra recetas del plan.
enum PlanCookingTime: String, CaseIterable, Identifiable, Codable {
    case under15
    case from15to30
    case over30

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.cooking.\(rawValue)") }
}

/// Ciclo irregular o amenorrea = senal de alarma de baja disponibilidad
/// energetica (consenso IOC RED-S 2018); bloquea deficit agresivo.
enum PlanMenstrualCycle: String, CaseIterable, Identifiable, Codable {
    case regular
    case irregular
    case preferNotToSay

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.cycle.\(rawValue)") }
}

/// Intentos previos de bajar de peso: el predictor pretratamiento mas
/// consistente de como va a ir un plan (Carraça et al., Obes Facts 2018,
/// DOI 10.1159/000485838; r=0.10). 3+ ciclos es el umbral de "severe cycling"
/// (Mason et al., Metabolism 2012). El cycling NO impide perder peso otra vez;
/// cambia el ritmo: deficit conservador y adherencia primero.
enum PlanWeightLossHistory: String, CaseIterable, Identifiable, Codable {
    case never
    case once
    case aFew
    case many

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.history.\(rawValue)") }
    var detail: String { RecvelL10n.text("planflow.history.\(rawValue).detail") }
    var icon: String {
        switch self {
        case .never: "circle"
        case .once: "1.circle.fill"
        case .aFew: "3.circle.fill"
        case .many: "arrow.triangle.2.circlepath"
        }
    }
}

/// Barreras percibidas a comer bien. Se guardan por JSON viejo; ya no se
/// preguntan. El tiempo se cubre con tiempo de cocina (Welsh 2012).
enum PlanAdherenceBarrier: String, CaseIterable, Identifiable, Codable {
    case time
    case eatingOut
    case social
    case emotional
    case inconsistent
    case none

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.barrier.\(rawValue)") }
}

/// Frecuencia de atracones. El umbral DSM-5 de BED es ≥1 episodio/semana
/// durante 3 meses. No diagnostica; si es semanal, la restriccion calorica
/// puede precipitar mas atracones (Academy SOP peso adulto 2022).
enum PlanBingeFrequency: String, CaseIterable, Identifiable, Codable {
    case never
    case lessThanWeekly
    case weeklyOrMore

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.binge.\(rawValue)") }
    var detail: String { RecvelL10n.text("planflow.binge.\(rawValue).detail") }
}

/// Cuantos dias seguidos repite la misma comida. El batch cooking (cocinar
/// una vez, comer varios dias) es de las estrategias de adherencia con mejor
/// evidencia conductual y reduce el tiempo total de cocina.
enum PlanMealRepeat: String, CaseIterable, Identifiable, Codable {
    case none
    case twoDays
    case threeDays
    case week

    var id: String { rawValue }
    var displayName: String { RecvelL10n.text("planflow.repeat.\(rawValue)") }
    var detail: String { RecvelL10n.text("planflow.repeat.\(rawValue).detail") }

    /// Dias que cubre un mismo menu.
    var span: Int {
        switch self {
        case .none: 1
        case .twoDays: 2
        case .threeDays: 3
        case .week: 7
        }
    }
}

/// Respuestas completas del cuestionario. Se persisten como JSON dentro del
/// `GeneratedPlanRecord` para que el chat posterior conserve el contexto.
struct NutritionPlanAnswers: Codable, Equatable {
    var conditions: [PlanMedicalCondition] = []
    var pregnantOrLactating: Bool = false
    var menstrualCycle: PlanMenstrualCycle?
    /// Diagnostico o tratamiento previo de TCA (Academy SOP 2022 1.1C1).
    var eatingDisorderHistory: Bool = false
    var medications: [PlanMedication] = []
    var otherMedications: String = ""
    var occupation: PlanOccupation = .sedentary
    var trainingTime: PlanTrainingTime = .morning
    var trainingDuration: PlanTrainingDuration = .under45
    var trainsFasted: Bool = false
    var caffeine: PlanCaffeineLevel = .moderate
    var lastCaffeineHour: Int = 15
    var hotClimate: Bool = false
    var heavySweat: Bool = false
    var budget: PlanBudget = .moderate
    var cuisine: String = ""
    var cookingTime: PlanCookingTime = .from15to30
    var supplements: String = ""
    var openToSupplements: Bool = true
    /// Dias que cubre el plan generado (1-7).
    var planDays: Int = 3
    /// Dias seguidos que repite la misma comida (batch cooking).
    var mealRepeat: PlanMealRepeat = .twoDays
    var weightLossHistory: PlanWeightLossHistory?
    var barriers: [PlanAdherenceBarrier] = []
    /// SCOFF (Morgan BMJ 1999; García-Campayo 2005). nil = sin responder.
    var scoffSick: Bool?
    var scoffControl: Bool?
    var scoffOneStone: Bool?
    var scoffFat: Bool?
    var scoffFood: Bool?
    var bingeFrequency: PlanBingeFrequency?
    var drivenExercise: Bool?

    var scoffScore: Int {
        [scoffSick, scoffControl, scoffOneStone, scoffFat, scoffFood]
            .compactMap { $0 }
            .filter { $0 }
            .count
    }

    var scoffAnswered: Bool {
        [scoffSick, scoffControl, scoffOneStone, scoffFat, scoffFood].allSatisfy { $0 != nil }
    }

    /// Corte validado: ≥2 respuestas afirmativas.
    var scoffPositive: Bool { scoffAnswered && scoffScore >= 2 }

    /// El usuario abrio Plan avanzado y dejo al menos un dato clinico.
    var filledAdvancedPlan: Bool {
        eatingDisorderHistory
            || scoffAnswered
            || bingeFrequency != nil
            || drivenExercise != nil
            || weightLossHistory != nil
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conditions = try container.decodeIfPresent([PlanMedicalCondition].self, forKey: .conditions) ?? []
        pregnantOrLactating = try container.decodeIfPresent(Bool.self, forKey: .pregnantOrLactating) ?? false
        menstrualCycle = try container.decodeIfPresent(PlanMenstrualCycle.self, forKey: .menstrualCycle)
        eatingDisorderHistory = try container.decodeIfPresent(Bool.self, forKey: .eatingDisorderHistory) ?? false
        medications = try container.decodeIfPresent([PlanMedication].self, forKey: .medications) ?? []
        otherMedications = try container.decodeIfPresent(String.self, forKey: .otherMedications) ?? ""
        occupation = try container.decodeIfPresent(PlanOccupation.self, forKey: .occupation) ?? .sedentary
        trainingTime = try container.decodeIfPresent(PlanTrainingTime.self, forKey: .trainingTime) ?? .morning
        trainingDuration = try container.decodeIfPresent(PlanTrainingDuration.self, forKey: .trainingDuration) ?? .under45
        trainsFasted = try container.decodeIfPresent(Bool.self, forKey: .trainsFasted) ?? false
        caffeine = try container.decodeIfPresent(PlanCaffeineLevel.self, forKey: .caffeine) ?? .moderate
        lastCaffeineHour = try container.decodeIfPresent(Int.self, forKey: .lastCaffeineHour) ?? 15
        hotClimate = try container.decodeIfPresent(Bool.self, forKey: .hotClimate) ?? false
        heavySweat = try container.decodeIfPresent(Bool.self, forKey: .heavySweat) ?? false
        budget = try container.decodeIfPresent(PlanBudget.self, forKey: .budget) ?? .moderate
        cuisine = try container.decodeIfPresent(String.self, forKey: .cuisine) ?? ""
        cookingTime = try container.decodeIfPresent(PlanCookingTime.self, forKey: .cookingTime) ?? .from15to30
        supplements = try container.decodeIfPresent(String.self, forKey: .supplements) ?? ""
        openToSupplements = try container.decodeIfPresent(Bool.self, forKey: .openToSupplements) ?? true
        planDays = try container.decodeIfPresent(Int.self, forKey: .planDays) ?? 3
        mealRepeat = try container.decodeIfPresent(PlanMealRepeat.self, forKey: .mealRepeat) ?? .twoDays
        weightLossHistory = try container.decodeIfPresent(PlanWeightLossHistory.self, forKey: .weightLossHistory)
        barriers = try container.decodeIfPresent([PlanAdherenceBarrier].self, forKey: .barriers) ?? []
        scoffSick = try container.decodeIfPresent(Bool.self, forKey: .scoffSick)
        scoffControl = try container.decodeIfPresent(Bool.self, forKey: .scoffControl)
        scoffOneStone = try container.decodeIfPresent(Bool.self, forKey: .scoffOneStone)
        scoffFat = try container.decodeIfPresent(Bool.self, forKey: .scoffFat)
        scoffFood = try container.decodeIfPresent(Bool.self, forKey: .scoffFood)
        bingeFrequency = try container.decodeIfPresent(PlanBingeFrequency.self, forKey: .bingeFrequency)
        drivenExercise = try container.decodeIfPresent(Bool.self, forKey: .drivenExercise)
    }

    /// Avisos de seguridad derivados de las respuestas. Se inyectan en el
    /// prompt para que el plan respete las precauciones de la literatura.
    var safetyFlags: [String] {
        var flags: [String] = []
        if pregnantOrLactating { flags.append("pregnancy") }
        if eatingDisorderHistory { flags.append("eatingDisorder") }
        if menstrualCycle == .irregular { flags.append("menstrualIrregular") }
        if conditions.contains(.kidneyDisease) { flags.append("kidneyDisease") }
        if conditions.contains(.diabetes) { flags.append("diabetes") }
        if conditions.contains(.hypertension) { flags.append("hypertension") }
        if medications.contains(.warfarin) { flags.append("warfarin") }
        if medications.contains(.levothyroxine) { flags.append("levothyroxine") }
        if medications.contains(.metformin) { flags.append("metformin") }
        if medications.contains(.statins) { flags.append("statins") }
        if weightLossHistory == .many { flags.append("weightCycling") }
        if scoffPositive { flags.append("scoffPositive") }
        if bingeFrequency == .weeklyOrMore { flags.append("weeklyBinge") }
        if drivenExercise == true { flags.append("drivenExercise") }
        return flags
    }
}

// MARK: - Plan generado por Gemini

/// Respuesta estructurada del modelo. El prompt pide JSON con este esquema
/// (generationConfig responseMimeType application/json).
///
/// El plan es multi-dia: `days` agrupa las comidas. Los registros guardados
/// antes de la duracion variable traian `meals` plano de un solo dia; el
/// decoder los envuelve en un `PlanDay` para no perderlos.
struct GeneratedNutritionPlan: Codable, Equatable {
    struct MacroTargets: Codable, Equatable {
        let calories: Int
        let protein: Int
        let carbohydrates: Int
        let fat: Int
        let hydrationLiters: Double
    }

    struct Meal: Codable, Equatable, Identifiable {
        var id = UUID()
        let mealType: String
        let time: String
        let title: String
        let detail: String
        let calories: Int
        let protein: Int
        let carbohydrates: Int
        let fat: Int

        private enum CodingKeys: String, CodingKey {
            case mealType, time, title, detail, calories, protein, carbohydrates, fat
        }
    }

    struct PlanDay: Codable, Equatable, Identifiable {
        var id = UUID()
        let day: Int
        /// Etiqueta corta opcional del modelo ("Lunes", "Dia de pierna"...).
        let label: String
        /// Nota de preparacion ("Mismo menu que el dia 1: cocina una vez").
        let note: String?
        let meals: [Meal]

        init(day: Int, label: String = "", note: String? = nil, meals: [Meal]) {
            self.day = day
            self.label = label
            self.note = note
            self.meals = meals
        }

        private enum CodingKeys: String, CodingKey {
            case day, label, note, meals
        }
    }

    let summary: String
    let scienceBasis: [String]
    let targets: MacroTargets
    let days: [PlanDay]
    let shoppingList: [String]
    let supplementGuidance: [String]
    let precautions: [String]

    init(
        summary: String,
        scienceBasis: [String],
        targets: MacroTargets,
        days: [PlanDay],
        shoppingList: [String],
        supplementGuidance: [String],
        precautions: [String]
    ) {
        self.summary = summary
        self.scienceBasis = scienceBasis
        self.targets = targets
        self.days = days
        self.shoppingList = shoppingList
        self.supplementGuidance = supplementGuidance
        self.precautions = precautions
    }

    private enum CodingKeys: String, CodingKey {
        case summary, scienceBasis, targets, days, meals, shoppingList, supplementGuidance, precautions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        scienceBasis = try container.decodeIfPresent([String].self, forKey: .scienceBasis) ?? []
        targets = try container.decode(MacroTargets.self, forKey: .targets)
        if let decodedDays = try container.decodeIfPresent([PlanDay].self, forKey: .days), !decodedDays.isEmpty {
            days = decodedDays
        } else {
            // Compat: planes viejos de UN dia con `meals` plano.
            let legacyMeals = try container.decodeIfPresent([Meal].self, forKey: .meals) ?? []
            days = [PlanDay(day: 1, meals: legacyMeals)]
        }
        shoppingList = try container.decodeIfPresent([String].self, forKey: .shoppingList) ?? []
        supplementGuidance = try container.decodeIfPresent([String].self, forKey: .supplementGuidance) ?? []
        precautions = try container.decodeIfPresent([String].self, forKey: .precautions) ?? []
    }

    /// Encoder manual: `meals` solo existe como llave de lectura (compat).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summary, forKey: .summary)
        try container.encode(scienceBasis, forKey: .scienceBasis)
        try container.encode(targets, forKey: .targets)
        try container.encode(days, forKey: .days)
        try container.encode(shoppingList, forKey: .shoppingList)
        try container.encode(supplementGuidance, forKey: .supplementGuidance)
        try container.encode(precautions, forKey: .precautions)
    }

    /// Todas las comidas del plan (para compat con chat y vistas viejas).
    var allMeals: [Meal] { days.flatMap(\.meals) }
}

// MARK: - Chat posterior al plan

struct PlanChatMessage: Codable, Equatable, Identifiable {
    enum Role: String, Codable {
        case user
        case model
    }

    var id = UUID()
    let role: Role
    let text: String
    var date: Date = .now

    init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

// MARK: - Persistencia

/// Un plan generado y su conversacion. El plan y las respuestas viajan como
/// JSON: el esquema del plan lo define el modelo de IA y no queremos migrar
/// SwiftData cada vez que el prompt mejore.
@Model
final class GeneratedPlanRecord {
    var id: UUID
    var createdAt: Date
    var modelName: String
    var planJSON: String
    var answersJSON: String
    var chatJSON: String

    init(
        modelName: String,
        planJSON: String,
        answersJSON: String,
        chatJSON: String = "[]"
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.modelName = modelName
        self.planJSON = planJSON
        self.answersJSON = answersJSON
        self.chatJSON = chatJSON
    }

    var plan: GeneratedNutritionPlan? {
        guard let data = planJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GeneratedNutritionPlan.self, from: data)
    }

    var answers: NutritionPlanAnswers? {
        guard let data = answersJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NutritionPlanAnswers.self, from: data)
    }

    var chatMessages: [PlanChatMessage] {
        get {
            guard let data = chatJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([PlanChatMessage].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else { return }
            chatJSON = json
        }
    }
}
