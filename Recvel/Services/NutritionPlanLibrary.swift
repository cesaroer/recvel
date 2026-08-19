import Foundation

/// Ultimas respuestas del cuestionario del asistente, fuera de SwiftData.
///
/// El prefill del cuestionario dependia de que existiera el ultimo
/// `GeneratedPlanRecord`; con el guardado explicito los borradores se purgan,
/// asi que las respuestas viven aqui (UserDefaults, patron
/// `WeeklyPlanLibraryStore`) y sobreviven a la purga. `resetToFreshInstall`
/// borra el dominio completo de UserDefaults, asi que tambien limpia esto.
enum NutritionPlanAnswersStore {
    static let key = "nutrition.plan.lastAnswersJSON"

    static func save(_ answers: NutritionPlanAnswers, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(answers),
              let json = String(data: data, encoding: .utf8) else { return }
        defaults.set(json, forKey: key)
    }

    static func saveJSON(_ json: String, defaults: UserDefaults = .standard) {
        defaults.set(json, forKey: key)
    }

    static func load(defaults: UserDefaults = .standard) -> NutritionPlanAnswers? {
        guard let json = defaults.string(forKey: key),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NutritionPlanAnswers.self, from: data)
    }

    static func hasAnswers(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key) != nil
    }
}

/// Reglas del ciclo de vida de un plan generado, como funciones puras sobre
/// instancias (sin ModelContext) para poder testearlas igual que los engines.
enum NutritionPlanDraftPolicy {
    /// Borradores a purgar al abrir el flujo: todo registro sin guardado
    /// explicito. Incluye los registros pre-migracion (nunca tuvieron
    /// `savedAt`) y los restos de sesiones que murieron a medias.
    static func purgeableDrafts(in records: [GeneratedPlanRecord]) -> [GeneratedPlanRecord] {
        records.filter { !$0.isSaved }
    }

    /// `answersJSON` a rescatar hacia `NutritionPlanAnswersStore` antes de
    /// purgar: el registro mas reciente, solo si el store sigue vacio (un
    /// store con datos ya es mas nuevo que cualquier registro).
    static func answersJSONToSalvage(
        records: [GeneratedPlanRecord],
        storeHasAnswers: Bool
    ) -> String? {
        guard !storeHasAnswers else { return nil }
        return records.max(by: { $0.createdAt < $1.createdAt })?.answersJSON
    }

    /// Nombre por defecto de un plan: el summary de la IA es demasiado largo
    /// para una fila, asi que se arma con lo que identifica al plan de un
    /// vistazo (objetivo calorico y fecha).
    static func defaultName(
        targets: GeneratedNutritionPlan.MacroTargets,
        date: Date,
        locale: Locale = RecvelL10n.locale
    ) -> String {
        RecvelL10n.text("planflow.defaultName", values: [
            "kcal": "\(targets.calories)",
            "date": date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        ])
    }

    /// Nombre visible en filas y alertas: el del usuario, o el por defecto.
    static func displayName(for record: GeneratedPlanRecord) -> String {
        if let name = record.name, !name.isEmpty { return name }
        let date = record.savedAt ?? record.createdAt
        guard let targets = record.plan?.targets else {
            return date.formatted(.dateTime.day().month(.abbreviated).locale(RecvelL10n.locale))
        }
        return defaultName(targets: targets, date: date)
    }
}
