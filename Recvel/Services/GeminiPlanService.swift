import Foundation

// MARK: - Modelos disponibles

/// Un modelo de Gemini que acepta `generateContent`. La lista se consulta en
/// vivo contra la API (`GET /v1beta/models`) porque el catalogo cambia sin
/// aviso: hardcodear nombres dejaria la pantalla obsoleta en meses.
struct GeminiModelInfo: Identifiable, Hashable {
    /// Nombre corto usable en `:generateContent` (sin el prefijo `models/`).
    let id: String
    let displayName: String
    let summary: String
    let inputTokenLimit: Int

    var isFlashLite: Bool {
        let lower = id.lowercased()
        return lower.contains("lite") || lower.contains("flash-8b")
    }

    var isPro: Bool {
        let lower = id.lowercased()
        return lower.contains("pro") && !lower.contains("flash")
    }

    var isFlash: Bool { id.lowercased().contains("flash") }

    var isPreview: Bool {
        let lower = id.lowercased()
        return lower.contains("preview") || lower.contains("-exp") || lower.contains("thinking")
    }

    var versionScore: Double {
        let parts = id.lowercased().split(separator: "-")
        for part in parts {
            if part.contains("."), let value = Double(part) { return value }
            if let value = Double(part), (1...9).contains(value) { return value }
        }
        return 0
    }

    /// Chip compacto: "2.5 Flash Lite", "2.5 Pro".
    var shortLabel: String {
        let prefix = versionScore > 0 ? String(format: versionScore.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f " : "%g ", versionScore) : ""
        if isFlashLite { return "\(prefix)Flash Lite" }
        if isPro { return "\(prefix)Pro" }
        if isFlash { return "\(prefix)Flash" }
        return displayName
    }

    /// Lo que se enseña por defecto: un Flash Lite y un Pro (el mas reciente estable).
    static func featured(from models: [GeminiModelInfo]) -> [GeminiModelInfo] {
        func pick(_ matches: (GeminiModelInfo) -> Bool) -> GeminiModelInfo? {
            let found = models.filter(matches)
            let stable = found.filter { !$0.isPreview }
            let pool = stable.isEmpty ? found : stable
            return pool.max { lhs, rhs in
                if lhs.versionScore != rhs.versionScore { return lhs.versionScore < rhs.versionScore }
                return lhs.id < rhs.id
            }
        }

        var featured: [GeminiModelInfo] = []
        if let lite = pick(\.isFlashLite) { featured.append(lite) }
        if let pro = pick(\.isPro), featured.contains(where: { $0.id == pro.id }) == false {
            featured.append(pro)
        }
        if featured.count < 2, let flash = pick({ $0.isFlash && !$0.isFlashLite }),
           featured.contains(where: { $0.id == flash.id }) == false {
            featured.append(flash)
        }
        if featured.isEmpty { return Array(models.prefix(2)) }
        return featured
    }

    static func defaultSelection(from models: [GeminiModelInfo]) -> GeminiModelInfo? {
        featured(from: models).first ?? models.first
    }
}

enum GeminiPlanError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidResponse
    case invalidModelOutput
    case noModelsAvailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: RecvelL10n.text("planflow.error.missingKey")
        case .invalidAPIKey: RecvelL10n.text("planflow.error.invalidKey")
        case .invalidResponse: RecvelL10n.text("planflow.error.response")
        case .invalidModelOutput: RecvelL10n.text("planflow.error.output")
        case .noModelsAvailable: RecvelL10n.text("planflow.error.noModels")
        }
    }
}

// MARK: - Contexto de salud que alimenta el prompt

/// Contexto que YA tiene la app y se manda a Gemini sin preguntar.
/// Promedios de wearables (~30 d), entrenos (hasta 90 d), scores, journal
/// (~30 d) y comidas. Se resume: no se vuelca el historial crudo.
struct PlanHealthContext: Equatable {
    var lines: [String] = []
}

enum PlanContextBuilder {
    static func make(
        history: [DailyHealthSnapshot],
        scores: [DailyScoreRecord],
        workouts: [FitnessActivityLog],
        habits: [HabitLog],
        journal: [MentalJournalEntry],
        meals: [MealLog],
        emotions: [EmotionLog],
        readiness: [TrainingReadinessCheckIn],
        routine: WeeklyRoutine,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PlanHealthContext {
        var lines: [String] = []
        lines.append(contentsOf: wearableLines(history: history, scores: scores, now: now, calendar: calendar))
        lines.append(contentsOf: workoutLines(history: history, logs: workouts, now: now, calendar: calendar))
        lines.append(contentsOf: routineLines(routine))
        lines.append(contentsOf: journalLines(habits: habits, journal: journal, emotions: emotions, now: now, calendar: calendar))
        lines.append(contentsOf: mealLines(meals: meals, now: now, calendar: calendar))
        lines.append(contentsOf: readinessLines(readiness, now: now, calendar: calendar))
        return PlanHealthContext(lines: lines)
    }

    private static func inLast(_ days: Int, _ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let start = calendar.date(byAdding: .day, value: -days, to: now) else { return false }
        return date >= start
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) / Double(values.count))
    }

    private static func wearableLines(
        history: [DailyHealthSnapshot],
        scores: [DailyScoreRecord],
        now: Date,
        calendar: Calendar
    ) -> [String] {
        guard !history.isEmpty else { return [] }
        var lines = ["SENALES (wearables, \(history.count) dias):"]
        if let sleep = average(history.compactMap(\.sleepHours)) {
            lines.append("- Sueno: \(sleep.rounded(toPlaces: 1)) h/noche")
        }
        if let hrv = average(history.compactMap(\.hrv)) {
            lines.append("- HRV: \(Int(hrv.rounded())) ms")
        }
        if let rhr = average(history.compactMap(\.restingHeartRate)) {
            lines.append("- FC reposo: \(Int(rhr.rounded())) lpm")
        }
        if let vo2 = history.compactMap(\.vo2Max).last {
            lines.append("- VO2max: \(vo2.rounded(toPlaces: 1)) ml/kg/min")
        }
        if let steps = average(history.compactMap { $0.steps.map(Double.init) }) {
            lines.append("- Pasos: \(Int(steps.rounded())) /dia")
        }
        if let energy = average(history.compactMap(\.activeEnergy)) {
            lines.append("- Energia activa: \(Int(energy.rounded())) kcal/dia")
        }
        if let caffeine = average(history.compactMap(\.dietaryCaffeineMg)) {
            lines.append("- Cafeina registrada: \(Int(caffeine.rounded())) mg/dia")
        }
        if let water = average(history.compactMap(\.dietaryWaterLiters)) {
            lines.append("- Agua: \(water.rounded(toPlaces: 1)) L/dia")
        }
        if let fat = history.compactMap(\.bodyFatPercentage).last {
            lines.append("- Grasa corporal: \(fat.rounded(toPlaces: 1)) %")
        }
        if let lean = history.compactMap(\.leanBodyMassKg).last {
            lines.append("- Masa magra: \(lean.rounded(toPlaces: 1)) kg")
        }

        let recentScores = scores.filter { inLast(30, $0.date, now: now, calendar: calendar) }
        if !recentScores.isEmpty {
            let rec = recentScores.map { Double($0.recovery) }
            let slp = recentScores.map { Double($0.sleep) }
            let str = recentScores.map { Double($0.strain) }
            var parts: [String] = []
            if let value = average(rec) { parts.append("recuperacion \(Int(value.rounded()))") }
            if let value = average(slp) { parts.append("sueno \(Int(value.rounded()))") }
            if let value = average(str) { parts.append("strain/carga \(Int(value.rounded()))") }
            if !parts.isEmpty { lines.append("- Scores 30d (0-100): \(parts.joined(separator: ", "))") }
            if let latest = recentScores.max(by: { $0.date < $1.date }) {
                lines.append("- Scores de hoy/ultimo: rec \(latest.recovery), sueno \(latest.sleep), strain \(latest.strain)")
            }
        }
        return lines
    }

    private static func workoutLines(
        history: [DailyHealthSnapshot],
        logs: [FitnessActivityLog],
        now: Date,
        calendar: Calendar
    ) -> [String] {
        let recvel = logs.filter { inLast(90, $0.startDate, now: now, calendar: calendar) }
        let healthKit = history.flatMap(\.workouts).filter { inLast(90, $0.startDate, now: now, calendar: calendar) }

        struct Event {
            var date: Date
            var name: String
            var minutes: Double
            var effort: String?
        }

        var events: [Event] = recvel.map {
            Event(
                date: $0.startDate,
                name: $0.activityName,
                minutes: $0.durationMinutes,
                effort: $0.perceivedEffort > 0 ? "RPE \($0.perceivedEffort)" : $0.workoutFeelingRaw
            )
        }
        for workout in healthKit {
            let duplicate = events.contains {
                abs($0.date.timeIntervalSince(workout.startDate)) < 8 * 60
                    && abs($0.minutes - workout.durationMinutes) < 12
            }
            if duplicate { continue }
            let effort = workout.effortScore.map { "esfuerzo \(Int($0.rounded()))" }
            events.append(Event(date: workout.startDate, name: workout.activityName, minutes: workout.durationMinutes, effort: effort))
        }
        events.sort { $0.date > $1.date }
        guard !events.isEmpty else { return [] }

        let last30 = events.filter { inLast(30, $0.date, now: now, calendar: calendar) }
        var grouped: [String: (count: Int, minutes: Double)] = [:]
        for event in events {
            let current = grouped[event.name] ?? (0, 0)
            grouped[event.name] = (current.count + 1, current.minutes + event.minutes)
        }
        let types = grouped.sorted { $0.value.minutes > $1.value.minutes }
            .prefix(6)
            .map { "\($0.key) \($0.value.count)x (\(Int($0.value.minutes.rounded())) min)" }

        var lines = ["ENTRENAMIENTO (ultimos 90 dias):"]
        lines.append("- \(events.count) sesiones, \(Int(events.map(\.minutes).reduce(0, +).rounded())) min totales")
        if !last30.isEmpty {
            lines.append("- Ultimos 30 dias: \(last30.count) sesiones, \(Int(last30.map(\.minutes).reduce(0, +).rounded())) min")
        }
        if !types.isEmpty { lines.append("- Por tipo: \(types.joined(separator: "; "))") }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d MMM"
        for event in events.prefix(15) {
            var row = "- \(formatter.string(from: event.date)): \(event.name) \(Int(event.minutes.rounded())) min"
            if let effort = event.effort, !effort.isEmpty { row += ", \(effort)" }
            lines.append(row)
        }
        return lines
    }

    private static func routineLines(_ routine: WeeklyRoutine) -> [String] {
        let planned = (1...7).compactMap { weekday -> String? in
            guard let assignment = routine.days[weekday], assignment != .rest else { return nil }
            let symbols = Calendar.current.shortWeekdaySymbols
            let name = symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
            return "\(name) \(assignment.shortLabel) \(routine.minutes(forWeekday: weekday)) min"
        }
        guard !planned.isEmpty else { return [] }
        return [
            "RUTINA SEMANAL PLANIFICADA:",
            "- \(planned.joined(separator: "; "))"
        ]
    }

    private static func journalLines(
        habits: [HabitLog],
        journal: [MentalJournalEntry],
        emotions: [EmotionLog],
        now: Date,
        calendar: Calendar
    ) -> [String] {
        var lines: [String] = []
        let recentHabits = habits.filter { inLast(30, $0.date, now: now, calendar: calendar) }
        if !recentHabits.isEmpty {
            var grouped: [String: (yes: Int, total: Int)] = [:]
            for log in recentHabits {
                let key = (log.tagID?.isEmpty == false ? log.tagID! : log.habit)
                let current = grouped[key] ?? (0, 0)
                grouped[key] = (current.yes + (log.answer ? 1 : 0), current.total + 1)
            }
            let tags = grouped
                .filter { $0.value.total >= 2 }
                .sorted { $0.value.yes > $1.value.yes }
                .prefix(10)
                .map { "\($0.key) \($0.value.yes)/\($0.value.total)" }
            if !tags.isEmpty {
                lines.append("JOURNAL HABITOS (30 d, dias si/total):")
                lines.append("- \(tags.joined(separator: "; "))")
            }
        }

        let recentJournal = journal
            .filter { inLast(30, $0.date, now: now, calendar: calendar) }
            .sorted { $0.date > $1.date }
        let withText = recentJournal.filter {
            $0.hasEveningReflection || $0.hasMorningReflection
        }
        if !withText.isEmpty {
            lines.append("REFLEXIONES (ultimo mes, \(withText.count) dias):")
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_MX")
            formatter.dateFormat = "d MMM"
            for entry in withText.prefix(6) {
                let snippets = [entry.morningIntention, entry.wentWell, entry.improve, entry.eveningLesson]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { clip($0, 90) }
                if !snippets.isEmpty {
                    lines.append("- \(formatter.string(from: entry.date)): \(snippets.joined(separator: " | "))")
                }
            }
        }

        let recentEmotions = emotions.filter { inLast(30, $0.date, now: now, calendar: calendar) }
        if !recentEmotions.isEmpty {
            var counts: [String: Int] = [:]
            for item in recentEmotions { counts[item.emotion, default: 0] += 1 }
            let listed = counts.sorted { $0.value > $1.value }.prefix(5).map { "\($0.key) \($0.value)" }
            var line = "- Emociones 30 d: \(listed.joined(separator: ", "))"
            let stress = recentEmotions.compactMap { $0.linkedStressScore }.map(Double.init)
            if let avg = average(stress) { line += "; stress medio \(Int(avg.rounded()))" }
            lines.append("ESTADO EMOCIONAL:")
            lines.append(line)
        }
        return lines
    }

    private static func mealLines(meals: [MealLog], now: Date, calendar: Calendar) -> [String] {
        let recent = meals.filter { inLast(30, $0.createdAt, now: now, calendar: calendar) }
        guard !recent.isEmpty else { return [] }
        let days = Set(recent.map { calendar.startOfDay(for: $0.createdAt) }).count
        let kcal = recent.map { Double($0.calories) }
        let protein = recent.map { Double($0.protein) }
        var lines = ["COMIDAS REGISTRADAS (30 d, \(recent.count) logs / \(days) dias):"]
        if let avgKcal = average(kcal), let avgProtein = average(protein) {
            lines.append("- Promedio por comida: \(Int(avgKcal.rounded())) kcal, \(Int(avgProtein.rounded())) g proteina")
        }
        for meal in recent.sorted(by: { $0.createdAt > $1.createdAt }).prefix(8) {
            lines.append("- \(meal.title): \(meal.calories) kcal, P\(meal.protein) C\(meal.carbohydrates) F\(meal.fat)")
        }
        return lines
    }

    private static func readinessLines(_ items: [TrainingReadinessCheckIn], now: Date, calendar: Calendar) -> [String] {
        let recent = items.filter { inLast(14, $0.date, now: now, calendar: calendar) }
        guard !recent.isEmpty else { return [] }
        let energy = average(recent.map { Double($0.energy) })
        let soreness = average(recent.map { Double($0.soreness) })
        let motivation = average(recent.map { Double($0.motivation) })
        let painDays = recent.filter(\.hasPainOrLimitation).count
        var parts: [String] = []
        if let energy { parts.append("energia \(energy.rounded(toPlaces: 1))") }
        if let soreness { parts.append("dolor \(soreness.rounded(toPlaces: 1))") }
        if let motivation { parts.append("motivacion \(motivation.rounded(toPlaces: 1))") }
        if painDays > 0 { parts.append("molestias \(painDays)/\(recent.count) dias") }
        guard !parts.isEmpty else { return [] }
        return ["READINESS (14 d):", "- \(parts.joined(separator: ", "))"]
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }
}

// MARK: - Servicio

struct GeminiPlanService {
    private let session: URLSession
    private static let base = "https://generativelanguage.googleapis.com/v1beta"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Listado de modelos

    func fetchModels(apiKey: String) async throws -> [GeminiModelInfo] {
        guard !apiKey.isEmpty else { throw GeminiPlanError.missingAPIKey }
        var collected: [GeminiModelList.ModelEntry] = []
        var pageToken: String?
        repeat {
            var items = [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "pageSize", value: "100")
            ]
            if let pageToken {
                items.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            var components = URLComponents(string: "\(Self.base)/models")
            components?.queryItems = items
            guard let url = components?.url else { throw GeminiPlanError.invalidResponse }

            let (data, response) = try await session.data(from: url)
            try validate(response)
            let payload = try JSONDecoder().decode(GeminiModelList.self, from: data)
            collected.append(contentsOf: payload.models)
            let next = payload.nextPageToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            pageToken = (next?.isEmpty == false) ? next : nil
        } while pageToken != nil

        let models = collected.compactMap(Self.planModel(from:))
        let featuredIDs = Set(GeminiModelInfo.featured(from: models).map(\.id))
        let sorted = models.sorted { lhs, rhs in
            let leftFeatured = featuredIDs.contains(lhs.id)
            let rightFeatured = featuredIDs.contains(rhs.id)
            if leftFeatured != rightFeatured { return leftFeatured }
            if lhs.versionScore != rhs.versionScore { return lhs.versionScore > rhs.versionScore }
            return lhs.id > rhs.id
        }
        guard !sorted.isEmpty else { throw GeminiPlanError.noModelsAvailable }
        return sorted
    }

    /// Texto usable para el plan: Gemini + generateContent, sin embed/imagen/aqa/veo/tts.
    static func isUsableTextModel(id: String, methods: [String]) -> Bool {
        guard methods.contains("generateContent") else { return false }
        let lower = id.lowercased()
        guard lower.contains("gemini") else { return false }
        let banned = ["embed", "image", "imagen", "aqa", "gecko", "veo", "tts", "robotics"]
        return !banned.contains { lower.contains($0) }
    }

    private static func planModel(from entry: GeminiModelList.ModelEntry) -> GeminiModelInfo? {
        guard isUsableTextModel(id: entry.name, methods: entry.supportedGenerationMethods) else { return nil }
        return GeminiModelInfo(
            id: entry.name.replacingOccurrences(of: "models/", with: ""),
            displayName: entry.displayName.isEmpty ? entry.name : entry.displayName,
            summary: entry.description ?? "",
            inputTokenLimit: entry.inputTokenLimit ?? 0
        )
    }

    // MARK: Generacion del plan

    func generatePlan(
        apiKey: String,
        model: String,
        profile: NutritionProfile,
        answers: NutritionPlanAnswers,
        health: PlanHealthContext
    ) async throws -> GeneratedNutritionPlan {
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction()]]],
            "contents": [["role": "user", "parts": [["text": planPrompt(profile: profile, answers: answers, health: health)]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.4
            ]
        ]
        let text = try await generate(apiKey: apiKey, model: model, body: body)
        guard let jsonData = text.data(using: .utf8),
              let plan = try? JSONDecoder().decode(GeneratedNutritionPlan.self, from: jsonData) else {
            throw GeminiPlanError.invalidModelOutput
        }
        return plan
    }

    // MARK: Chat con el plan como contexto

    /// Multi-turn: el sistema recibe el plan serializado; `history` alterna
    /// roles user/model tal como exige la API.
    func sendChatMessage(
        apiKey: String,
        model: String,
        plan: GeneratedNutritionPlan,
        history: [PlanChatMessage],
        message: String
    ) async throws -> String {
        let planData = try JSONEncoder().encode(plan)
        let planJSON = String(data: planData, encoding: .utf8) ?? "{}"
        let system = systemInstruction() + "\n\n" + chatContextInstruction(planJSON: planJSON)

        var contents: [[String: Any]] = history.map { entry in
            [
                "role": entry.role == .user ? "user" : "model",
                "parts": [["text": entry.text]]
            ]
        }
        contents.append(["role": "user", "parts": [["text": message]]])

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": contents,
            "generationConfig": ["temperature": 0.6]
        ]
        return try await generate(apiKey: apiKey, model: model, body: body)
    }

    // MARK: - Red

    private func generate(apiKey: String, model: String, body: [String: Any]) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiPlanError.missingAPIKey }
        var components = URLComponents(string: "\(Self.base)/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw GeminiPlanError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)
        guard let text = envelope.candidates.first?.content.parts.first?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiPlanError.invalidModelOutput
        }
        // Con responseMimeType application/json no deberian venir fences,
        // pero un modelo lo hace de todos modos de vez en cuando.
        return text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw GeminiPlanError.invalidResponse }
        switch http.statusCode {
        case 200...299: return
        case 400, 401, 403: throw GeminiPlanError.invalidAPIKey
        default: throw GeminiPlanError.invalidResponse
        }
    }

    // MARK: - Prompts

    /// Rol y reglas cientificas duras. Los rangos y contraindicaciones salen
    /// de NUTRITION_PLAN_RESEARCH.md (ISSN, Academy, ACSM, IOC RED-S, OMS).
    private func systemInstruction() -> String {
        """
        Eres un nutriologo deportivo que prescribe SOLO con evidencia cientifica \
        (ISSN position stands, Academy of Nutrition and Dietetics, ACSM, OMS). \
        No inventes alimentos milagro ni restricciones sin sustento.

        REGLAS DE PRESCRIPCION (rangos validados):
        - Proteina: 1.4-2.0 g/kg/dia general; 1.6-2.2 g/kg para ganancia muscular; \
        1.2-1.6 g/kg en perdida de grasa con sobrepeso; 2.3-3.1 g/kg de masa libre \
        de grasa si la persona es magra y entrenada en deficit; >=1.7 g/kg en \
        embarazo/lactancia. Distribuye 0.25-0.40 g/kg por comida cada 3-4 h.
        - Perdida de peso: 0.5-1.0 % del peso corporal por semana, nunca mas agresivo.
        - Carbohidratos: 8-12 g/kg/dia solo con volumen alto de entrenamiento; \
        30-60 g/hora durante sesiones >60-70 min intensas.
        - Hidratacion: ~3.7 L/dia hombres, ~2.7 L/dia mujeres como base; sube con \
        calor y sudoracion fuerte; nunca mas de ~1 L/hora.
        - Micronutrientes OMS: frutas+verduras >=400 g/dia, fibra >=25 g/dia, \
        azucares libres <10% kcal, grasa 15-30% kcal, saturada <10%, sal <5 g/dia.
        - Cafeina: nunca dentro de las 6 h previas a dormir; maximo ~400 mg/dia.

        CONTRAINDICACIONES (si aplican, Ajusta el plan y dilo en precautions):
        - Embarazo/lactancia, SCOFF >=2, historia de TCA, atracones semanales \
        o ciclo menstrual irregular: PROHIBIDO deficit calorico agresivo. \
        No diagnostiques. En precautions pide valoracion profesional. \
        Prioriza comidas regulares: la restriccion precipita atracones.
        - Si el cribado SCOFF no se contesto (plan avanzado omitido): no asumas \
        ausencia de TCA. Usa deficit moderado (0.5-1%/semana), nunca un crash.
        - Enfermedad renal o hepatica: NO prescribas proteina alta; recomienda \
        supervision medica.
        - Diabetes o hipertension: aplica ajustes (patron DASH, sodio <2 g/dia) y \
        recomienda confirmar con su medico.
        - Warfarina: vitamina K (verduras verdes) consistente dia a dia.
        - Levotiroxina: nunca junto a desayuno, cafe, calcio o hierro.
        - Metformina cronica: sugiere monitorear B12.
        - Estatinas: sin toronja (pomelo).
        - Vegano: B12 siempre; vigila hierro, zinc, yodo, calcio y omega-3.

        ADHERENCIA PRIMERO: la variable que mejor predice resultados es la \
        adherencia (r=0.60, Dansinger JAMA 2005), no el tipo de dieta. Respeta \
        presupuesto, cocina preferida y tiempo de cocina del usuario. \
        Tiempo <15 min: comidas rapidas o batch cooking.

        PLAN AVANZADO (solo si el usuario lo lleno):
        - 3+ intentos previos de bajar de peso: NO prescribas deficit agresivo. \
        Apunta a ~0.5% del peso/semana. El cycling NO impide perder peso otra vez \
        (Mason 2012).
        - Ejercicio para compensar lo comido: no anadas cardio extra como castigo.

        USA EL CONTEXTO REAL DEL USUARIO (wearables, entrenos, journal, comidas):
        - Sueno corto o strain alto: no metas deficit agresivo; prioriza carbohidratos \
        alrededor del entreno y recuperacion.
        - Fuerza: proteina 0.25-0.40 g/kg en la comida post.
        - Sesiones >60-70 min intensas: 30-60 g carbs/hora durante.
        - Journal (alcohol, cafeina tarde, poco sueno): ajusta cafeina y alcohol del plan.
        - Si hay comidas registradas, el plan debe parecerse a lo que ya come, no a un menu extranjero.
        """
    }

    private func planPrompt(
        profile: NutritionProfile,
        answers: NutritionPlanAnswers,
        health: PlanHealthContext
    ) -> String {
        let age = Calendar.current.dateComponents([.year], from: profile.birthDate, to: .now).year ?? 30
        let planDays = max(1, min(answers.planDays, 7))
        var lines: [String] = [
            "Genera un plan de alimentacion de \(planDays) DIA(S), realista y accionable, para esta persona.",
            "",
            "PERFIL (datos que la app ya conoce):",
            "- Edad: \(age) anos; sexo: \(profile.sexOptional)",
            "- Peso: \(profile.weightKg) kg; altura: \(profile.heightCm) cm",
            "- Objetivo: \(profile.goal)",
            "- Entrenamientos por semana: \(profile.weeklyWorkouts)",
            "- Estilo de dieta: \(profile.dietStyle)",
            "- Comidas por dia: \(profile.mealsPerDay)",
            "- Alergias: \(profile.allergies.isEmpty ? "ninguna" : profile.allergies)",
            "- Alimentos que no le gustan: \(profile.dislikedFoods.isEmpty ? "ninguno" : profile.dislikedFoods)"
        ]

        lines.append("")
        if health.lines.isEmpty {
            lines.append("SENALES DE SALUD: sin historial wearable/entreno/journal todavia.")
        } else {
            lines.append(contentsOf: health.lines)
        }

        lines.append("")
        lines.append("CUESTIONARIO (datos nuevos):")
        lines.append("- Condiciones medicas: \(describe(answers.conditions))")
        lines.append("- Medicamentos: \(describe(answers.medications))\(answers.otherMedications.isEmpty ? "" : " + " + answers.otherMedications)")
        if answers.pregnantOrLactating { lines.append("- Embarazo/lactancia: SI") }
        if let cycle = answers.menstrualCycle { lines.append("- Ciclo menstrual: \(cycle.rawValue)") }
        if answers.filledAdvancedPlan {
            if answers.eatingDisorderHistory { lines.append("- Historia de trastorno alimentario: SI") }
            if answers.scoffAnswered {
                lines.append("- SCOFF: \(answers.scoffScore)/5 (positivo si >=2): \(answers.scoffPositive ? "SI" : "no")")
            }
            if let binge = answers.bingeFrequency {
                lines.append("- Atracones (umbral DSM-5 semanal): \(binge.rawValue)")
            }
            if answers.drivenExercise == true { lines.append("- Ejercicio para compensar lo comido: SI") }
            if let history = answers.weightLossHistory {
                lines.append("- Intentos previos de bajar de peso: \(history.rawValue)")
            }
        } else {
            lines.append("- Plan avanzado (SCOFF, atracones, historial de peso): omitido")
        }
        lines.append("- Ocupacion (actividad fuera del gym): \(answers.occupation.rawValue)")
        lines.append("- Hora habitual de entrenamiento (inferida de la rutina): \(answers.trainingTime.rawValue); duracion: \(answers.trainingDuration.rawValue); en ayunas: \(answers.trainsFasted ? "si" : "no")")
        lines.append("- Cafeina (inferida de HealthKit): \(answers.caffeine.rawValue); ultima cafeina ~\(answers.lastCaffeineHour):00 h")
        lines.append("- Clima caluroso: \(answers.hotClimate ? "si" : "no"); sudoracion fuerte: \(answers.heavySweat ? "si" : "no")")
        lines.append("- Presupuesto: \(answers.budget.rawValue)")
        if !answers.cuisine.isEmpty { lines.append("- Cocina preferida: \(answers.cuisine)") }
        lines.append("- Tiempo para cocinar: \(answers.cookingTime.rawValue)")
        lines.append("- Duracion del plan pedida: \(planDays) dia(s)")
        lines.append("- Repeticion de comidas: \(answers.mealRepeat.rawValue) (\(repetitionInstruction(for: answers.mealRepeat)))")
        if !answers.supplements.isEmpty { lines.append("- Suplementos actuales: \(answers.supplements)") }
        lines.append("- Abierto a suplementos con evidencia: \(answers.openToSupplements ? "si" : "no")")
        let activeBarriers = answers.barriers.filter { $0 != .none }
        if !activeBarriers.isEmpty {
            lines.append("- Barreras de adherencia (dato previo): \(describe(answers.barriers))")
        }

        let language = RecvelL10n.locale.language.languageCode?.identifier ?? "es"
        lines.append("")
        lines.append("""
        RESPONDE SOLO JSON valido (sin markdown) en idioma \(language) con este esquema exacto:
        {
          "summary": "resumen ejecutivo del plan en 2-3 frases, mencionando que cubre \(planDays) dia(s)",
          "scienceBasis": ["cada rango o decision con su fundamento, 3-5 items"],
          "targets": {"calories": 0, "protein": 0, "carbohydrates": 0, "fat": 0, "hydrationLiters": 0.0},
          "days": [
            {"day": 1, "label": "nombre corto opcional del dia", "note": "nota de preparacion o null", \
        "meals": [
              {"mealType": "Desayuno|Comida|Cena|Snack", "time": "07:30", "title": "nombre del platillo", \
        "detail": "alimentos y porciones en gramos/unidades caseras", "calories": 0, "protein": 0, \
        "carbohydrates": 0, "fat": 0}
            ]}
          ],
          "shoppingList": ["ingrediente con cantidad para TODOS los \(planDays) dias del plan"],
          "supplementGuidance": ["solo suplementos con evidencia ISSN, dosis incluida; vacio si ninguno"],
          "precautions": ["avisos de seguridad derivados de sus condiciones/medicamentos; vacio si ninguno"]
        }
        REGLAS DEL PLAN MULTI-DIA:
        - `days` tiene exactamente \(planDays) entradas, day numerado desde 1.
        - Cada dia trae \(profile.mealsPerDay) comidas, horarios alrededor de su entrenamiento \
        (\(answers.trainingTime.rawValue)); las calorias de cada dia suman el target.
        - \(repetitionSchemaRule(for: answers.mealRepeat, planDays: planDays))
        - Cuando un dia repite el menu de otro, escribe las comidas completas igual y pon en \
        `note` algo como "Mismo menu que el dia 1: cocina una sola vez y guarda porciones".
        - Varia proteina/carbohidrato entre menus distintos para cubrir micronutrientes (OMS).
        - `shoppingList` agrega cantidades de los \(planDays) dias completos, no de un solo dia.
        Todo en unidades metricas.
        """)
        return lines.joined(separator: "\n")
    }

    /// Lo que el usuario entiende por repetir comida, para el prompt.
    private func repetitionInstruction(for repeat: PlanMealRepeat) -> String {
        switch `repeat` {
        case .none: "cada dia un menu distinto"
        case .twoDays: "repite el mismo menu 2 dias seguidos (batch cooking)"
        case .threeDays: "repite el mismo menu 3 dias seguidos (batch cooking)"
        case .week: "un solo menu toda la semana (meal prep completo)"
        }
    }

    /// Como se traduce la repeticion al numero de menus distintos del JSON.
    private func repetitionSchemaRule(for repeat: PlanMealRepeat, planDays: Int) -> String {
        switch `repeat` {
        case .none:
            return "Los \(planDays) dias llevan menus DISTINTOS."
        case .twoDays:
            let menus = Int((Double(planDays) / 2).rounded(.up))
            return "Genera \(menus) menu(s) distinto(s) y repite cada uno 2 dias seguidos hasta cubrir los \(planDays) dias."
        case .threeDays:
            let menus = Int((Double(planDays) / 3).rounded(.up))
            return "Genera \(menus) menu(s) distinto(s) y repite cada uno 3 dias seguidos hasta cubrir los \(planDays) dias."
        case .week:
            return "Un SOLO menu repetido todos los dias del plan."
        }
    }

    private func chatContextInstruction(planJSON: String) -> String {
        """
        El usuario ya tiene este plan generado (JSON). Responde sus dudas y \
        ajustes SIEMPRE en relacion a el, con las mismas reglas cientificas. \
        Si pide cambiar una comida, propone la sustitucion con sus macros.
        PLAN: \(planJSON)
        """
    }

    private func describe(_ conditions: [PlanMedicalCondition]) -> String {
        let active = conditions.filter { $0 != .none }
        return active.isEmpty ? "ninguna" : active.map(\.rawValue).joined(separator: ", ")
    }

    private func describe(_ medications: [PlanMedication]) -> String {
        let active = medications.filter { $0 != .none }
        return active.isEmpty ? "ninguno" : active.map(\.rawValue).joined(separator: ", ")
    }

    private func describe(_ barriers: [PlanAdherenceBarrier]) -> String {
        let active = barriers.filter { $0 != .none }
        return active.isEmpty ? "ninguna declarada" : active.map(\.rawValue).joined(separator: ", ")
    }
}

// MARK: - Decodificadores de la API

private struct GeminiModelList: Decodable {
    struct ModelEntry: Decodable {
        let name: String
        let displayName: String
        let description: String?
        let inputTokenLimit: Int?
        let supportedGenerationMethods: [String]

        private enum CodingKeys: String, CodingKey {
            case name, displayName, description, inputTokenLimit, supportedGenerationMethods
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
            description = try container.decodeIfPresent(String.self, forKey: .description)
            inputTokenLimit = try container.decodeIfPresent(Int.self, forKey: .inputTokenLimit)
            supportedGenerationMethods = try container.decodeIfPresent([String].self, forKey: .supportedGenerationMethods) ?? []
        }
    }

    let models: [ModelEntry]
    let nextPageToken: String?
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
