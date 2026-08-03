import Foundation

/// Un componente del platillo: qué alimento y cuánto en la porción base.
struct RecipeComponent: Hashable {
    let foodID: String
    /// Porciones en la receta base, antes de escalar al hueco de macros.
    let baseServings: Double
    /// `false` para lo que no tiene sentido multiplicar: nadie come tres
    /// limones porque le falte proteína.
    let scalable: Bool

    init(_ foodID: String, _ baseServings: Double, scalable: Bool = true) {
        self.foodID = foodID
        self.baseServings = baseServings
        self.scalable = scalable
    }
}

/// Plantilla de un platillo: qué lleva y cómo se prepara.
///
/// Calcado de `ExerciseMechanics`: dato estático, sin macros propios. Los macros
/// **se calculan sumando** sus componentes contra `FoodCatalog`, nunca se
/// escriben a mano — así no pueden desincronizarse del catálogo ni inventarse.
struct MealRecipe: Identifiable, Hashable {
    let id: String
    /// Reusa las claves que el motor YA emite, para que el banner y la pantalla
    /// no puedan contradecirse.
    let titleKey: String
    let summaryKey: String
    let mealTypes: [MealType]
    let dietStyles: Set<DietStyle>
    let components: [RecipeComponent]
    let stepKeys: [String]
    let prepMinutes: Int
}

/// Catálogo local de recetas.
///
/// Cubre las claves de platillo que `NutritionPlanEngine` puede devolver
/// (`proteinFocusedTitle`, `balancedTitle`, `breakfastProteinTitle`).
///
/// **`nutrition.food.balancedPlate` no está aquí a propósito**: su texto es
/// "Un plato completo a tu gusto", que es una instrucción, no un platillo. No
/// tiene ingredientes que listar y fingir una receta sería inventar. La pantalla
/// maneja ese caso con un estado explícito, igual que `ExerciseMechanicsSheet`
/// cuando no encuentra mecánica.
enum MealRecipeCatalog {
    static func recipe(id: String) -> MealRecipe? {
        entries.first { $0.id == id }
    }

    static func recipe(titleKey: String) -> MealRecipe? {
        entries.first { $0.titleKey == titleKey }
    }

    /// Recetas compatibles con el tipo de comida y el estilo de dieta, ya
    /// filtradas por alergias. El orden es estable para que "ver otra
    /// sugerencia" sea determinista.
    static func recipes(
        for mealType: MealType,
        dietStyle: DietStyle,
        excludingAllergens allergens: [String] = []
    ) -> [MealRecipe] {
        entries.filter { recipe in
            recipe.mealTypes.contains(mealType)
                && recipe.dietStyles.contains(dietStyle)
                && !recipe.containsAllergen(in: allergens)
        }
    }

    static let entries: [MealRecipe] = [
        MealRecipe(
            id: "chicken-beans-vegetables",
            titleKey: "nutrition.food.chickenBeansVegetables",
            summaryKey: "recipe.chickenBeansVegetables.summary",
            mealTypes: [.lunch, .dinner],
            dietStyles: [.flexible, .lowCarb, .mediterranean],
            components: [
                RecipeComponent("chicken_breast", 1.25),
                RecipeComponent("beans", 1),
                RecipeComponent("broccoli", 1, scalable: false),
                RecipeComponent("olive_oil", 0.5),
                RecipeComponent("lime", 0.5, scalable: false)
            ],
            stepKeys: (1...5).map { "recipe.chickenBeansVegetables.step.\($0)" },
            prepMinutes: 25
        ),
        MealRecipe(
            id: "tofu-beans-rice",
            titleKey: "nutrition.food.tofuBeansRice",
            summaryKey: "recipe.tofuBeansRice.summary",
            mealTypes: [.lunch, .dinner],
            dietStyles: [.vegan, .vegetarian],
            components: [
                RecipeComponent("tofu", 1.5),
                RecipeComponent("beans", 1),
                RecipeComponent("rice", 1),
                RecipeComponent("zucchini", 1, scalable: false),
                RecipeComponent("olive_oil", 0.5)
            ],
            stepKeys: (1...5).map { "recipe.tofuBeansRice.step.\($0)" },
            prepMinutes: 30
        ),
        MealRecipe(
            id: "eggs-beans-tortillas",
            titleKey: "nutrition.food.eggsBeansTortillas",
            summaryKey: "recipe.eggsBeansTortillas.summary",
            mealTypes: [.breakfast, .lunch, .dinner],
            dietStyles: [.vegetarian, .flexible],
            components: [
                RecipeComponent("egg", 2),
                RecipeComponent("beans", 1),
                RecipeComponent("tortilla", 2),
                RecipeComponent("tomato", 0.5, scalable: false),
                RecipeComponent("onion", 0.5, scalable: false)
            ],
            stepKeys: (1...5).map { "recipe.eggsBeansTortillas.step.\($0)" },
            prepMinutes: 15
        ),
        MealRecipe(
            id: "yogurt-fruit",
            titleKey: "nutrition.food.yogurtFruit",
            summaryKey: "recipe.yogurtFruit.summary",
            mealTypes: [.snack, .breakfast],
            dietStyles: [.flexible, .vegetarian, .mediterranean, .lowCarb],
            components: [
                RecipeComponent("greek_yogurt", 1),
                RecipeComponent("banana", 1, scalable: false),
                RecipeComponent("seeds", 1)
            ],
            stepKeys: (1...3).map { "recipe.yogurtFruit.step.\($0)" },
            prepMinutes: 5
        ),
        MealRecipe(
            id: "eggs-yogurt-fruit",
            titleKey: "nutrition.food.eggsYogurtFruit",
            summaryKey: "recipe.eggsYogurtFruit.summary",
            mealTypes: [.breakfast],
            dietStyles: [.flexible, .vegetarian, .mediterranean, .lowCarb],
            components: [
                RecipeComponent("egg", 2),
                RecipeComponent("greek_yogurt", 1),
                RecipeComponent("apple", 1, scalable: false)
            ],
            stepKeys: (1...4).map { "recipe.eggsYogurtFruit.step.\($0)" },
            prepMinutes: 12
        ),
        MealRecipe(
            id: "eggs-beans-fruit",
            titleKey: "nutrition.food.eggsBeansFruit",
            summaryKey: "recipe.eggsBeansFruit.summary",
            mealTypes: [.breakfast],
            dietStyles: [.vegetarian, .flexible],
            components: [
                RecipeComponent("egg", 2),
                RecipeComponent("beans", 0.75),
                RecipeComponent("banana", 1, scalable: false),
                RecipeComponent("olive_oil", 0.5)
            ],
            stepKeys: (1...4).map { "recipe.eggsBeansFruit.step.\($0)" },
            prepMinutes: 15
        ),
        MealRecipe(
            id: "oats-soy-seeds",
            titleKey: "nutrition.food.oatsSoySeeds",
            summaryKey: "recipe.oatsSoySeeds.summary",
            mealTypes: [.breakfast],
            dietStyles: [.vegan, .vegetarian],
            components: [
                RecipeComponent("oats", 1),
                RecipeComponent("soy_milk", 1),
                RecipeComponent("seeds", 1),
                RecipeComponent("banana", 1, scalable: false)
            ],
            stepKeys: (1...4).map { "recipe.oatsSoySeeds.step.\($0)" },
            prepMinutes: 10
        ),
        MealRecipe(
            id: "legume-bowl",
            titleKey: "nutrition.food.legumeBowl",
            summaryKey: "recipe.legumeBowl.summary",
            mealTypes: [.lunch, .dinner],
            dietStyles: [.vegan, .vegetarian, .mediterranean],
            components: [
                RecipeComponent("lentils", 1),
                RecipeComponent("sweet_potato", 0.75),
                RecipeComponent("broccoli", 1, scalable: false),
                RecipeComponent("avocado", 0.5),
                RecipeComponent("olive_oil", 0.5)
            ],
            stepKeys: (1...5).map { "recipe.legumeBowl.step.\($0)" },
            prepMinutes: 35
        )
    ]
}

extension MealRecipe {
    /// Macros de la receta SIN escalar, sumados de `FoodCatalog`.
    var baseTotals: MacroTotals {
        components.reduce(into: MacroTotals.zero) { totals, component in
            guard let food = FoodCatalog.item(id: component.foodID) else { return }
            totals.add(food, servings: component.baseServings)
        }
    }

    /// `true` si algún ingrediente coincide con un alérgeno declarado por el
    /// usuario. Exclusión dura: la pantalla lista ingredientes y ofrece
    /// registrarlos, así que aquí no vale con bajar el orden.
    func containsAllergen(in allergens: [String]) -> Bool {
        guard !allergens.isEmpty else { return false }
        let normalized = allergens
            .map { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased() }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return false }

        return components.contains { component in
            guard let food = FoodCatalog.item(id: component.foodID) else { return false }
            let haystack = (food.allergenTokens + food.tokens)
                .map { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased() }
            return normalized.contains { allergen in
                haystack.contains { $0.contains(allergen) || allergen.contains($0) }
            }
        }
    }
}

/// Suma de macros. Existe para que nadie escriba un total a mano.
struct MacroTotals: Equatable {
    var calories = 0
    var protein = 0
    var carbohydrates = 0
    var fat = 0

    static let zero = MacroTotals()

    mutating func add(_ food: FoodItem, servings: Double) {
        calories += Int((Double(food.calories) * servings).rounded())
        protein += Int((Double(food.protein) * servings).rounded())
        carbohydrates += Int((Double(food.carbs) * servings).rounded())
        fat += Int((Double(food.fat) * servings).rounded())
    }
}
