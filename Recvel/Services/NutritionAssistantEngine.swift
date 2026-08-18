import Foundation

struct NutritionAssistantMeal: Identifiable, Equatable {
    let mealType: MealType
    let meal: ScaledMeal
    let matchedFoodIDs: [String]
    let missingFoodIDs: [String]

    var id: String { "\(mealType.rawValue)-\(meal.recipeID)" }
}

/// Composes useful meal suggestions from the user's local profile, today's
/// records and Recvel's traceable food catalog. It never manufactures macros:
/// every total is the sum of concrete `FoodCatalog` ingredients.
enum NutritionAssistantEngine {
    static func recognizedFoods(in input: String) -> [FoodItem] {
        let text = normalized(input)
        guard !text.isEmpty else { return [] }

        return FoodCatalog.items.filter { food in
            food.tokens.contains { token in
                text.contains(normalized(token))
            }
        }
    }

    static func remainingMealTypes(profile: NutritionProfile, meals: [MealLog], now: Date) -> [MealType] {
        var sequence: [MealType] = [.breakfast, .lunch, .dinner]
        if profile.mealsPerDay > 3 { sequence.append(.snack) }

        let today = meals.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        var completed = Set(today.compactMap { log in
            log.mealType.flatMap(MealType.init(rawValue:))
        })

        // Older records may not have a meal type. Assign them to elapsed slots
        // only for planning; the persisted record remains untouched.
        let untypedCount = today.filter { $0.mealType == nil }.count
        for type in sequence where completed.count < untypedCount {
            completed.insert(type)
        }

        let remaining = sequence.filter { !completed.contains($0) }
        return remaining.isEmpty ? [sequence.last ?? .dinner] : remaining
    }

    static func dayPlan(
        profile: NutritionProfile,
        meals: [MealLog],
        context: NutritionHealthContext,
        now: Date = .now
    ) -> [NutritionAssistantMeal] {
        let planner = NutritionPlanEngine()
        let targets = planner.targets(for: profile, now: now)
        let today = meals.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        var gap = MacroGap(
            calories: targets.calories - today.reduce(0) { $0 + $1.calories },
            protein: targets.protein - today.reduce(0) { $0 + $1.protein }
        )
        let types = remainingMealTypes(profile: profile, meals: meals, now: now)
        let diet = DietStyle(rawValue: profile.dietStyle) ?? .flexible
        let exclusions = profileTerms(profile.allergies) + profileTerms(profile.dislikedFoods)
        var result: [NutritionAssistantMeal] = []

        for (index, type) in types.prefix(3).enumerated() {
            let recipes = MealRecipeCatalog.recipes(
                for: type,
                dietStyle: diet,
                excludingAllergens: exclusions
            )
            guard !recipes.isEmpty else { continue }

            // Rotate stable options by slot so a four-meal day does not repeat
            // the same recipe when the catalog offers alternatives.
            let recipe = recipes[index % recipes.count]
            let remaining = Array(types.dropFirst(index))
            let scaled = MealPortionScaler.scale(
                recipe: recipe,
                mealType: type,
                gap: gap,
                targets: targets,
                remainingMeals: remaining
            )
            result.append(
                NutritionAssistantMeal(
                    mealType: type,
                    meal: scaled,
                    matchedFoodIDs: [],
                    missingFoodIDs: recipe.components.map(\.foodID)
                )
            )
            gap = MacroGap(
                calories: gap.calories - scaled.totals.calories,
                protein: gap.protein - scaled.totals.protein
            )
        }
        return result
    }

    static func mealFromIngredients(
        _ input: String,
        profile: NutritionProfile,
        meals: [MealLog],
        now: Date = .now
    ) -> NutritionAssistantMeal? {
        let foods = recognizedFoods(in: input)
        guard !foods.isEmpty else { return nil }

        let available = Set(foods.map(\.id))
        let diet = DietStyle(rawValue: profile.dietStyle) ?? .flexible
        let exclusions = profileTerms(profile.allergies) + profileTerms(profile.dislikedFoods)
        let preferredType = remainingMealTypes(profile: profile, meals: meals, now: now).first ?? .dinner

        let candidates = MealType.allCases.flatMap { type in
            MealRecipeCatalog.recipes(for: type, dietStyle: diet, excludingAllergens: exclusions)
                .map { (type, $0) }
        }
        let ranked = candidates.compactMap { type, recipe -> (MealType, MealRecipe, Int, Int)? in
            let componentIDs = Set(recipe.components.map(\.foodID))
            let overlap = componentIDs.intersection(available).count
            guard overlap > 0 else { return nil }
            return (type, recipe, overlap, componentIDs.subtracting(available).count)
        }
        .sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            if lhs.3 != rhs.3 { return lhs.3 < rhs.3 }
            if (lhs.0 == preferredType) != (rhs.0 == preferredType) { return lhs.0 == preferredType }
            if lhs.1.prepMinutes != rhs.1.prepMinutes { return lhs.1.prepMinutes < rhs.1.prepMinutes }
            return lhs.1.id < rhs.1.id
        }
        guard let (type, recipe, _, _) = ranked.first else { return nil }

        let planner = NutritionPlanEngine()
        let targets = planner.targets(for: profile, now: now)
        let today = meals.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }
        let gap = MacroGap(
            calories: targets.calories - today.reduce(0) { $0 + $1.calories },
            protein: targets.protein - today.reduce(0) { $0 + $1.protein }
        )
        let remaining = remainingMealTypes(profile: profile, meals: meals, now: now)
        let scaled = MealPortionScaler.scale(
            recipe: recipe,
            mealType: type,
            gap: gap,
            targets: targets,
            remainingMeals: remaining
        )
        let recipeIDs = recipe.components.map(\.foodID)
        return NutritionAssistantMeal(
            mealType: type,
            meal: scaled,
            matchedFoodIDs: recipeIDs.filter(available.contains),
            missingFoodIDs: recipeIDs.filter { !available.contains($0) }
        )
    }

    static func estimate(for suggestion: NutritionAssistantMeal) -> NutritionEstimate {
        let totals = suggestion.meal.totals
        return NutritionEstimate(
            title: RecvelL10n.text(suggestion.meal.titleKey),
            calories: totals.calories,
            protein: totals.protein,
            carbohydrates: totals.carbohydrates,
            fat: totals.fat,
            confidence: suggestion.meal.confidence,
            uncertainties: suggestion.meal.caveatKeys.map { RecvelL10n.text($0) },
            source: "assistant-\(suggestion.meal.recipeID)"
        )
    }

    private static func profileTerms(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es-MX"))
            .lowercased()
    }
}
