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
                detail: text("nutrition.plan.protein.detail"),
                reason: text("nutrition.plan.protein.reason", ["grams": "\(proteinGap)"])
            )
        } else if calorieGap < -250 {
            nextMeal = suggestion(
                type: nextType,
                title: text("nutrition.plan.light.title"),
                detail: text("nutrition.plan.light.detail"),
                reason: text("nutrition.plan.light.reason")
            )
        } else if (context.plannedWorkout || context.strain ?? 0 >= 70) && carbs < Int(Double(targets.carbohydrates) * 0.65) {
            nextMeal = suggestion(
                type: nextType,
                title: text("nutrition.plan.carbs.title"),
                detail: text("nutrition.plan.carbs.detail"),
                reason: text("nutrition.plan.carbs.reason")
            )
        } else {
            nextMeal = suggestion(
                type: nextType,
                title: balancedTitle(profile: profile, type: nextType),
                detail: text("nutrition.plan.balanced.detail"),
                reason: text("nutrition.plan.balanced.reason")
            )
        }

        var tomorrow = tomorrowSuggestions(profile: profile)
        var tomorrowReason: String
        if proteinGap >= 25 {
            tomorrowReason = text("nutrition.plan.tomorrow.protein", ["grams": "\(proteinGap)"])
            tomorrow[0] = suggestion(
                type: .breakfast,
                title: breakfastProteinTitle(profile: profile),
                detail: text("nutrition.plan.breakfast.detail"),
                reason: text("nutrition.plan.breakfast.reason")
            )
        } else if calorieGap < -250 {
            tomorrowReason = text("nutrition.plan.tomorrow.above")
        } else if let sleep = context.sleep, sleep < 55 {
            tomorrowReason = text("nutrition.plan.tomorrow.sleep")
        } else if let recovery = context.recovery, recovery < 45 {
            tomorrowReason = text("nutrition.plan.tomorrow.recovery")
        } else {
            tomorrowReason = text("nutrition.plan.tomorrow.steady")
        }

        let status: String
        if today.isEmpty {
            status = text("nutrition.plan.status.empty")
        } else if calories < targets.calorieLower {
            status = text("nutrition.plan.status.below", ["calories": "\(calories)", "remaining": "\(max(calorieGap, 0))"])
        } else if calories <= targets.calorieUpper {
            status = text("nutrition.plan.status.inRange", ["protein": "\(protein)"])
        } else {
            status = text("nutrition.plan.status.above", ["calories": "\(calories - targets.calorieUpper)"])
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
        case DietStyle.vegan.rawValue: return text("nutrition.food.tofuBeansRice")
        case DietStyle.vegetarian.rawValue: return text("nutrition.food.eggsBeansTortillas")
        default: return type == .snack ? text("nutrition.food.yogurtFruit") : text("nutrition.food.chickenBeansVegetables")
        }
    }

    private func balancedTitle(profile: NutritionProfile, type: MealType) -> String {
        if type == .breakfast { return breakfastProteinTitle(profile: profile) }
        if profile.dietStyle == DietStyle.vegan.rawValue { return text("nutrition.food.legumeBowl") }
        return text("nutrition.food.balancedPlate")
    }

    private func breakfastProteinTitle(profile: NutritionProfile) -> String {
        switch profile.dietStyle {
        case DietStyle.vegan.rawValue: return text("nutrition.food.oatsSoySeeds")
        case DietStyle.vegetarian.rawValue: return text("nutrition.food.eggsBeansFruit")
        default: return text("nutrition.food.eggsYogurtFruit")
        }
    }

    private func tomorrowSuggestions(profile: NutritionProfile) -> [NutritionPlanSuggestion] {
        [
            suggestion(type: .breakfast, title: breakfastProteinTitle(profile: profile), detail: text("nutrition.plan.tomorrow.breakfast.detail"), reason: text("nutrition.plan.tomorrow.breakfast.reason")),
            suggestion(type: .lunch, title: proteinFocusedTitle(profile: profile, type: .lunch), detail: text("nutrition.plan.tomorrow.lunch.detail"), reason: text("nutrition.plan.tomorrow.lunch.reason")),
            suggestion(type: .dinner, title: text("nutrition.plan.tomorrow.dinner.title"), detail: text("nutrition.plan.tomorrow.dinner.detail"), reason: text("nutrition.plan.tomorrow.dinner.reason"))
        ]
    }

    private func text(_ key: String, _ values: [String: String] = [:]) -> String {
        CopyMessage(key: key, values: values).localized()
    }
}

enum NutritionNetworkError: LocalizedError {
    case invalidResponse
    case missingProduct
    case missingAPIKey
    case invalidModelOutput

    var errorDescription: String? {
        switch self {
        case .invalidResponse: RecvelL10n.text("No se pudo leer la respuesta del servicio.")
        case .missingProduct: RecvelL10n.text("No encontramos ese codigo en Open Food Facts.")
        case .missingAPIKey: RecvelL10n.text("Agrega una API key en Ajustes.")
        case .invalidModelOutput: RecvelL10n.text("El modelo no devolvio una estimacion editable.")
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
            uncertainties: servingKnown ? [] : [RecvelL10n.text("Valores por 100 g"), RecvelL10n.text("Confirma la porcion")],
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
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw NutritionNetworkError.invalidResponse
        }

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
        // La clave va en header, no en la URL: las URLs acaban en logs y proxies.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
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

struct GeminiEnvelope: Decodable {
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
