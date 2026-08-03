import Foundation

/// Un ingrediente ya escalado y listo para mostrar.
struct ScaledIngredient: Identifiable, Hashable {
    let foodID: String
    let nameKey: String
    let servings: Double
    let unit: FoodUnit
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
    /// `true` si la cantidad se ajustó al hueco del usuario. La UI lo señala
    /// para que se entienda por qué pide 180 g de pollo y no 150.
    let wasScaled: Bool

    var id: String { foodID }
}

/// Platillo compuesto: la receta con cantidades resueltas para hoy.
struct ScaledMeal: Equatable {
    let recipeID: String
    let titleKey: String
    let summaryKey: String
    let ingredients: [ScaledIngredient]
    let stepKeys: [String]
    let prepMinutes: Int
    let totals: MacroTotals
    /// Techo `.medium`: es una composición estimada, no una medición.
    let confidence: DataConfidence
    /// Claves de aviso que la pantalla muestra. Callarlas sería falsa precisión.
    let caveatKeys: [String]

    static func == (lhs: ScaledMeal, rhs: ScaledMeal) -> Bool {
        lhs.recipeID == rhs.recipeID && lhs.totals == rhs.totals
            && lhs.ingredients == rhs.ingredients
    }
}

/// Lo que le falta al usuario hoy.
struct MacroGap: Equatable {
    let calories: Int
    let protein: Int

    /// Ya cubrió su rango: no hay hueco que cerrar.
    var isSatisfied: Bool { protein <= 0 && calories <= 0 }
}

/// Escala una receta al hueco de macros del usuario.
///
/// **El reparto entre comidas es lo que evita el disparate.** Escalar al hueco
/// del DÍA produce un desayuno de 2 000 kcal a las 8 a.m., cuando el hueco es
/// prácticamente el objetivo completo. Primero se reparte el hueco entre las
/// comidas que quedan, y solo entonces se escala.
enum MealPortionScaler {
    /// Qué parte del día aporta cada comida. Son proporciones de reparto para
    /// no concentrar todo en una sola toma, no recomendaciones nutricionales.
    static let mealShares: [MealType: Double] = [
        .breakfast: 0.25,
        .lunch: 0.35,
        .dinner: 0.30,
        .snack: 0.10
    ]

    /// Topes por comida. Presentados como criterio práctico de porción, nunca
    /// como límite fisiológico afirmado (regla de no-absolutos del proyecto).
    static let minCalorieShare = 0.15
    static let maxCalorieShare = 0.45
    static let minMealProtein = 15
    static let maxMealProtein = 45

    static func scale(
        recipe: MealRecipe,
        mealType: MealType,
        gap: MacroGap,
        targets: NutritionTargets,
        remainingMeals: [MealType]
    ) -> ScaledMeal {
        let mealTarget = target(for: mealType, gap: gap, targets: targets, remainingMeals: remainingMeals)
        let base = recipe.baseTotals

        // Factor sobre la proteína, que es el macro con el que el motor decide
        // la sugerencia. Si la receta no aporta proteína, no hay nada que
        // escalar por ahí y se queda en su porción base.
        let factor: Double = base.protein > 0
            ? Double(mealTarget.protein) / Double(base.protein)
            : 1.0
        let clamped = min(max(factor, 0.5), 2.5)

        var ingredients: [ScaledIngredient] = []
        var totals = MacroTotals.zero

        for component in recipe.components {
            guard let food = FoodCatalog.item(id: component.foodID) else { continue }
            let raw = component.scalable ? component.baseServings * clamped : component.baseServings
            let bounded = min(max(raw, food.minServings), food.maxServings)
            let servings = rounded(bounded, step: food.servingStep)
            // Los macros se recalculan DESPUÉS del redondeo. Si se calcularan
            // antes, la suma no cuadraría con las cantidades mostradas.
            totals.add(food, servings: servings)
            ingredients.append(
                ScaledIngredient(
                    foodID: food.id,
                    nameKey: food.nameKey,
                    servings: servings,
                    unit: food.unit,
                    calories: Int((Double(food.calories) * servings).rounded()),
                    protein: Int((Double(food.protein) * servings).rounded()),
                    carbohydrates: Int((Double(food.carbs) * servings).rounded()),
                    fat: Int((Double(food.fat) * servings).rounded()),
                    wasScaled: component.scalable && servings != component.baseServings
                )
            )
        }

        var caveats = ["recipe.caveat.portions"]
        if gap.isSatisfied {
            // Ya cumplió su rango. NO se sugiere saltarse la comida ni bajar la
            // porción a cero: la guía de copy prohíbe culpabilizar por comer.
            caveats.append("recipe.caveat.aboveRange")
        } else if factor > 2.5 {
            caveats.append("recipe.caveat.capped")
        }

        // Si tras los topes el resultado se aleja mucho del objetivo de la
        // comida, la confianza baja. Fingir que cuadró sería falsa precisión.
        let deviation = mealTarget.calories > 0
            ? abs(Double(totals.calories - mealTarget.calories)) / Double(mealTarget.calories)
            : 0
        let confidence: DataConfidence = deviation > 0.25 ? .low : .medium

        return ScaledMeal(
            recipeID: recipe.id,
            titleKey: recipe.titleKey,
            summaryKey: recipe.summaryKey,
            ingredients: ingredients,
            stepKeys: recipe.stepKeys,
            prepMinutes: recipe.prepMinutes,
            totals: totals,
            confidence: confidence,
            caveatKeys: caveats
        )
    }

    /// Reparte el hueco del día entre las comidas que faltan y aplica los topes.
    static func target(
        for mealType: MealType,
        gap: MacroGap,
        targets: NutritionTargets,
        remainingMeals: [MealType]
    ) -> MacroTotals {
        let meals = remainingMeals.isEmpty ? [mealType] : remainingMeals
        let totalShare = meals.reduce(0.0) { $0 + (mealShares[$1] ?? 0.25) }
        let share = (mealShares[mealType] ?? 0.25) / max(totalShare, 0.01)

        let rawCalories = Double(max(gap.calories, 0)) * share
        let rawProtein = Double(max(gap.protein, 0)) * share

        let calories = Int(min(
            max(rawCalories, Double(targets.calories) * minCalorieShare),
            Double(targets.calories) * maxCalorieShare
        ))
        let protein = Int(min(max(rawProtein, Double(minMealProtein)), Double(maxMealProtein)))

        var result = MacroTotals.zero
        result.calories = calories
        result.protein = protein
        return result
    }

    /// Redondea a algo que alguien pueda cocinar. Nadie mide "1.37 tazas".
    static func rounded(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return max((value / step).rounded() * step, step)
    }
}

extension ScaledIngredient {
    /// Cantidad legible: "1½ taza", "2 piezas", "150 g".
    var measure: String {
        switch unit {
        case .gram:
            // La porción base son 100 g, así que las porciones se expresan así.
            return "\(Int((servings * 100).rounded())) g"
        default:
            return "\(Self.fraction(servings)) \(RecvelL10n.text(unit.nameKey))"
        }
    }

    /// Fracciones tipográficas en vez de decimales: "1½" se lee mejor que "1.5".
    static func fraction(_ value: Double) -> String {
        let whole = Int(value)
        let remainder = value - Double(whole)
        let glyph: String
        switch (remainder * 100).rounded() {
        case 25: glyph = "¼"
        case 50: glyph = "½"
        case 75: glyph = "¾"
        default: glyph = ""
        }
        if glyph.isEmpty { return "\(whole)" }
        return whole == 0 ? glyph : "\(whole)\(glyph)"
    }
}
