import Foundation

enum NutritionFeatureFlags {
    static let experimentalAPIKey = "nutritionExperimentalFreeAPIEnabled"
    static let experimentalAPIEnabledByDefault = false
}

protocol NutritionEstimating {
    func estimate(from description: String) -> NutritionEstimate?
}

protocol NutritionPlanning {
    func targets(for profile: NutritionProfile, now: Date) -> NutritionTargets
    func plan(
        for profile: NutritionProfile,
        meals: [MealLog],
        context: NutritionHealthContext,
        now: Date
    ) -> NutritionDayPlan
}

protocol ExternalNutritionAIClient {
    func estimate(text: String, imageData: Data?) async throws -> NutritionEstimate
}

struct NutritionPlanEngine: NutritionPlanning {
    func targets(for profile: NutritionProfile, now: Date = .now) -> NutritionTargets {
        let calendar = Calendar.current
        let age = max(calendar.dateComponents([.year], from: profile.birthDate, to: now).year ?? 30, 18)
        let base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(age)
        let restingEnergy: Double

        switch profile.sexOptional {
        case NutritionSex.female.rawValue: restingEnergy = base - 161
        case NutritionSex.male.rawValue: restingEnergy = base + 5
        default: restingEnergy = base - 78
        }

        let activityFactor: Double
        switch profile.weeklyWorkouts {
        case WeeklyWorkoutRange.low.rawValue: activityFactor = 1.35
        case WeeklyWorkoutRange.high.rawValue: activityFactor = 1.70
        default: activityFactor = 1.50
        }

        let goalAdjustment: Double
        switch profile.goal {
        case NutritionGoal.loseFat.rawValue: goalAdjustment = -350
        case NutritionGoal.gainMuscle.rawValue: goalAdjustment = 250
        default: goalAdjustment = 0
        }

        let calories = max(Int((restingEnergy * activityFactor + goalAdjustment).rounded() / 10) * 10, 1_250)
        let proteinFactor = [
            NutritionGoal.loseFat.rawValue,
            NutritionGoal.gainMuscle.rawValue,
            NutritionGoal.eatMoreProtein.rawValue
        ].contains(profile.goal) ? 1.8 : 1.6
        let protein = Int((profile.weightKg * proteinFactor).rounded())
        let fat = max(Int((profile.weightKg * 0.8).rounded()), 45)
        let remainingEnergy = max(calories - protein * 4 - fat * 9, 300)
        let carbohydrates = Int((Double(remainingEnergy) / 4).rounded())

        return NutritionTargets(
            calories: calories,
            calorieLower: max(calories - 120, 1_150),
            calorieUpper: calories + 120,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat
        )
    }

    func plan(
        for profile: NutritionProfile,
        meals: [MealLog],
        context: NutritionHealthContext = .empty,
        now: Date = .now
    ) -> NutritionDayPlan {
        let targets = targets(for: profile, now: now)
        let today = meals.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        let calories = today.reduce(0) { $0 + $1.calories }
        let protein = today.reduce(0) { $0 + $1.protein }
        let carbs = today.reduce(0) { $0 + $1.carbohydrates }
        let proteinGap = max(targets.protein - protein, 0)
        let calorieGap = targets.calories - calories
        let nextType = inferredNextMeal(after: today, profile: profile)

        let nextMeal: NutritionPlanSuggestion
        if proteinGap >= 25 {
            nextMeal = suggestion(
                type: nextType,
                title: proteinFocusedTitle(profile: profile, type: nextType),
                detail: "Apunta a 30-40 g de proteina y agrega verduras o fruta.",
                reason: "Hoy faltan aproximadamente \(proteinGap) g para tu rango de proteina."
            )
        } else if calorieGap < -250 {
            nextMeal = suggestion(
                type: nextType,
                title: "Opcion ligera y saciante",
                detail: "Proteina magra, verduras y una porcion moderada de grasa.",
                reason: "Ya superaste tu rango de energia; no necesitas compensar ni saltarte comidas."
            )
        } else if (context.plannedWorkout || context.strain ?? 0 >= 70) && carbs < Int(Double(targets.carbohydrates) * 0.65) {
            nextMeal = suggestion(
                type: nextType,
                title: "Carbohidrato + proteina",
                detail: "Arroz, papa, avena o tortilla con una fuente de proteina.",
                reason: "Tu actividad es alta y aun tienes margen de carbohidratos para el dia."
            )
        } else {
            nextMeal = suggestion(
                type: nextType,
                title: balancedTitle(profile: profile, type: nextType),
                detail: "Combina proteina, fibra, color vegetal y una porcion que puedas confirmar.",
                reason: "Mantiene el dia cerca de tu rango sin perseguir una cifra exacta."
            )
        }

        var tomorrow = tomorrowSuggestions(profile: profile)
        var tomorrowReason: String
        if proteinGap >= 25 {
            tomorrowReason = "Hoy faltaron cerca de \(proteinGap) g de proteina. Mañana la distribuimos desde la primera comida."
            tomorrow[0] = suggestion(
                type: .breakfast,
                title: breakfastProteinTitle(profile: profile),
                detail: "25-35 g de proteina, fruta y una fuente de fibra.",
                reason: "Empezar temprano reduce la carga de completar la meta por la noche."
            )
        } else if calorieGap < -250 {
            tomorrowReason = "Hoy quedaste por encima del rango. Mañana vuelve a tu estructura habitual, sin recortes agresivos."
        } else if let sleep = context.sleep, sleep < 55 {
            tomorrowReason = "Tu sueño fue bajo. Priorizamos comidas regulares y cafeina temprana; esto es apoyo de bienestar, no tratamiento."
        } else if let recovery = context.recovery, recovery < 45 {
            tomorrowReason = "Tu recovery esta bajo. Mañana conviene una estructura simple, hidratacion y energia suficiente."
        } else {
            tomorrowReason = "Hoy vas cerca de tu estructura. Mañana mantenemos variedad y proteina repartida."
        }

        let status: String
        if today.isEmpty {
            status = "Aun no hay comidas. Tu primera entrada definira el resto del dia."
        } else if calories < targets.calorieLower {
            status = "Llevas \(calories) kcal; quedan cerca de \(max(calorieGap, 0)) kcal dentro de tu referencia."
        } else if calories <= targets.calorieUpper {
            status = "Vas dentro de tu rango de energia y llevas \(protein) g de proteina."
        } else {
            status = "Vas \(calories - targets.calorieUpper) kcal sobre el rango; observa la tendencia, no un solo dia."
        }

        return NutritionDayPlan(
            status: status,
            nextMeal: nextMeal,
            tomorrow: Array(tomorrow.prefix(3)),
            tomorrowReason: tomorrowReason
        )
    }

    private func inferredNextMeal(after meals: [MealLog], profile: NutritionProfile) -> MealType {
        if meals.isEmpty { return .breakfast }
        if meals.count == 1 { return .lunch }
        if meals.count == 2 { return .dinner }
        return profile.mealsPerDay > 3 ? .snack : .dinner
    }

    private func suggestion(type: MealType, title: String, detail: String, reason: String) -> NutritionPlanSuggestion {
        NutritionPlanSuggestion(id: "\(type.rawValue)-\(title)", mealType: type, title: title, detail: detail, reason: reason)
    }

    private func proteinFocusedTitle(profile: NutritionProfile, type: MealType) -> String {
        switch profile.dietStyle {
        case DietStyle.vegan.rawValue: return "Tofu, frijoles y arroz"
        case DietStyle.vegetarian.rawValue: return "Huevos, frijoles y tortillas"
        default: return type == .snack ? "Yogurt alto en proteina y fruta" : "Pollo, frijoles y verduras"
        }
    }

    private func balancedTitle(profile: NutritionProfile, type: MealType) -> String {
        if type == .breakfast { return breakfastProteinTitle(profile: profile) }
        if profile.dietStyle == DietStyle.vegan.rawValue { return "Bowl de legumbres y vegetales" }
        return "Plato completo a tu gusto"
    }

    private func breakfastProteinTitle(profile: NutritionProfile) -> String {
        switch profile.dietStyle {
        case DietStyle.vegan.rawValue: return "Avena, soya y semillas"
        case DietStyle.vegetarian.rawValue: return "Huevos con frijoles y fruta"
        default: return "Huevos, yogurt y fruta"
        }
    }

    private func tomorrowSuggestions(profile: NutritionProfile) -> [NutritionPlanSuggestion] {
        [
            suggestion(type: .breakfast, title: breakfastProteinTitle(profile: profile), detail: "Proteina + fibra para abrir el dia.", reason: "Reparte la proteina entre comidas."),
            suggestion(type: .lunch, title: proteinFocusedTitle(profile: profile, type: .lunch), detail: "Completa con vegetales y una porcion de carbohidrato.", reason: "Aporta energia util para tu actividad."),
            suggestion(type: .dinner, title: "Cena simple y completa", detail: "Proteina, verduras y carbohidrato segun hambre y actividad.", reason: "Una estructura predecible facilita registrar porciones.")
        ]
    }
}

enum NutritionNetworkError: LocalizedError {
    case invalidResponse
    case missingProduct
    case missingAPIKey
    case invalidModelOutput

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "No se pudo leer la respuesta del servicio."
        case .missingProduct: "No encontramos ese codigo en Open Food Facts."
        case .missingAPIKey: "Agrega una API key en Ajustes."
        case .invalidModelOutput: "El modelo no devolvio una estimacion editable."
        }
    }
}

struct OpenFoodFactsClient {
    func estimate(barcode: String) async throws -> NutritionEstimate {
        let clean = barcode.filter(\.isNumber)
        guard !clean.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(clean).json") else {
            throw NutritionNetworkError.missingProduct
        }
        var request = URLRequest(url: url)
        request.setValue("Recvel/1.0 (personal wellness app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NutritionNetworkError.invalidResponse }
        let payload = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        guard payload.status == 1, let product = payload.product else { throw NutritionNetworkError.missingProduct }

        let kcal = Int((product.nutriments.energyKcalServing ?? product.nutriments.energyKcal100g ?? 0).rounded())
        guard kcal > 0 else { throw NutritionNetworkError.missingProduct }
        let servingKnown = product.nutriments.energyKcalServing != nil
        return NutritionEstimate(
            title: product.productName ?? "Producto escaneado",
            calories: kcal,
            protein: Int((product.nutriments.proteinsServing ?? product.nutriments.proteins100g ?? 0).rounded()),
            carbohydrates: Int((product.nutriments.carbohydratesServing ?? product.nutriments.carbohydrates100g ?? 0).rounded()),
            fat: Int((product.nutriments.fatServing ?? product.nutriments.fat100g ?? 0).rounded()),
            confidence: servingKnown ? .high : .medium,
            uncertainties: servingKnown ? [] : ["Valores por 100 g", "Confirma la porcion"],
            source: "barcode"
        )
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: Product?

    struct Product: Decodable {
        let productName: String?
        let nutriments: Nutriments

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case nutriments
        }
    }

    struct Nutriments: Decodable {
        let energyKcalServing: Double?
        let energyKcal100g: Double?
        let proteinsServing: Double?
        let proteins100g: Double?
        let carbohydratesServing: Double?
        let carbohydrates100g: Double?
        let fatServing: Double?
        let fat100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcalServing = "energy-kcal_serving"
            case energyKcal100g = "energy-kcal_100g"
            case proteinsServing = "proteins_serving"
            case proteins100g = "proteins_100g"
            case carbohydratesServing = "carbohydrates_serving"
            case carbohydrates100g = "carbohydrates_100g"
            case fatServing = "fat_serving"
            case fat100g = "fat_100g"
        }
    }
}

struct GeminiNutritionAIClient: ExternalNutritionAIClient {
    let apiKey: String
    var model = "gemini-2.0-flash"

    func estimate(text: String, imageData: Data?) async throws -> NutritionEstimate {
        guard !apiKey.isEmpty else { throw NutritionNetworkError.missingAPIKey }
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw NutritionNetworkError.invalidResponse }

        let prompt = """
        Estima esta comida como apoyo de registro, no como diagnostico. Devuelve SOLO JSON con:
        title, calories, protein, carbohydrates, fat, kcalLower, kcalUpper, confidence (Baja|Media|Alta), uncertainties (array de strings).
        Si faltan porciones usa un rango amplio y confidence Baja. Entrada: \(text)
        """
        var parts: [[String: Any]] = [["text": prompt]]
        if let imageData {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]])
        }
        let body: [String: Any] = ["contents": [["parts": parts]]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NutritionNetworkError.invalidResponse }
        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)
        guard let text = envelope.candidates.first?.content.parts.first?.text else { throw NutritionNetworkError.invalidModelOutput }
        let clean = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        guard let jsonData = clean.data(using: .utf8),
              let result = try? JSONDecoder().decode(GeminiNutritionResult.self, from: jsonData) else {
            throw NutritionNetworkError.invalidModelOutput
        }
        return NutritionEstimate(
            title: result.title,
            calories: result.calories,
            protein: result.protein,
            carbohydrates: result.carbohydrates,
            fat: result.fat,
            confidence: DataConfidence(rawValue: result.confidence) ?? .low,
            kcalLower: result.kcalLower,
            kcalUpper: result.kcalUpper,
            uncertainties: result.uncertainties,
            source: "gemini-experimental"
        )
    }
}

private struct GeminiEnvelope: Decodable {
    let candidates: [Candidate]
    struct Candidate: Decodable { let content: Content }
    struct Content: Decodable { let parts: [Part] }
    struct Part: Decodable { let text: String? }
}

private struct GeminiNutritionResult: Decodable {
    let title: String
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
    let kcalLower: Int
    let kcalUpper: Int
    let confidence: String
    let uncertainties: [String]
}
