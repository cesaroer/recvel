import Foundation

/// Unidad en la que se cuenta una porcion del alimento.
///
/// Existe para poder redondear a cantidades que alguien pueda cocinar: nadie
/// mide "1.37 tazas" ni "0.6 huevos".
enum FoodUnit: String {
    case piece
    case cup
    case tablespoon
    case gram
    case slice
    case tortilla

    var nameKey: String { "food.unit.\(rawValue)" }

    /// Incremento minimo al escalar. Un huevo va de uno en uno; los gramos, de
    /// 25 en 25; las tazas, de media en media.
    var servingStep: Double {
        switch self {
        case .piece, .tortilla, .slice: 1
        case .cup, .tablespoon: 0.5
        case .gram: 0.25   // la porcion base son 100 g, asi que 0.25 = 25 g
        }
    }
}

/// Papel del alimento dentro de un platillo. Gobierna el ORDEN del escalado:
/// primero se cubre la proteina, luego el carbohidrato, y la grasa absorbe el
/// error restante. Verduras y fruta no escalan con el hueco de macros.
enum NutrientRole {
    case protein
    case carb
    case fat
    case vegetable
    case fruit
    case condiment
}

/// Alimento del catalogo local, con macros **por porcion unitaria**.
///
/// `id` es una clave estable en ingles y NO se muestra: el nombre visible sale
/// de `nameKey`. Esta separacion es obligatoria — el test
/// `testNutritionTargetsStayStableWhileRecommendationsTranslate` exige que los
/// macros sean identicos en español y en ingles mientras los textos cambian, y
/// eso solo se sostiene si la identidad del alimento no es su nombre traducible.
struct FoodItem: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let tokens: [String]
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let unit: FoodUnit
    let role: NutrientRole
    /// Limites razonables de porcion. Fuera de aqui deja de ser una comida.
    let minServings: Double
    let maxServings: Double
    /// Para el filtro de alergias del perfil (texto libre del usuario).
    let allergenTokens: [String]

    var servingStep: Double { unit.servingStep }
}

/// Catalogo local de alimentos.
///
/// Nacio `private` dentro de `NutritionEstimator` y solo servia para estimar
/// macros desde texto libre. Se expone aqui porque las recetas necesitan
/// componer platillos sumando alimentos REALES en vez de inventar cifras.
///
/// **Los macros de las 26 entradas originales estan congelados.** Cambiar uno
/// alteraria estimaciones que el usuario ya guardo en su historial. Las
/// entradas nuevas van al final.
///
/// Fuente de los valores nuevos: USDA FoodData Central (fdc.nal.usda.gov),
/// redondeados a entero por porcion. Los 26 originales se conservan tal como
/// estaban, sin re-verificar, por la razon de arriba.
enum FoodCatalog {
    static func item(id: String) -> FoodItem? {
        items.first { $0.id == id }
    }

    /// Alimentos cuyos tokens aparecen en el texto, con la cantidad detectada.
    static func matches(in text: String, quantity: (String, String) -> Double) -> [(FoodItem, Double)] {
        items.compactMap { food in
            guard let token = food.tokens.first(where: { text.contains($0) }) else { return nil }
            return (food, quantity(token, text))
        }
    }

    static let items: [FoodItem] = [
        // MARK: - Originales (macros congelados, venian de NutritionEstimator)
        FoodItem(id: "chicken_breast", nameKey: "food.name.chickenBreast", tokens: ["pollo", "chicken"],
                 calories: 180, protein: 31, carbs: 0, fat: 5,
                 unit: .gram, role: .protein, minServings: 0.75, maxServings: 2.5, allergenTokens: []),
        FoodItem(id: "rice", nameKey: "food.name.rice", tokens: ["arroz", "rice"],
                 calories: 205, protein: 4, carbs: 45, fat: 1,
                 unit: .cup, role: .carb, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "egg", nameKey: "food.name.egg", tokens: ["huevo", "huevos", "egg"],
                 calories: 78, protein: 6, carbs: 1, fat: 5,
                 unit: .piece, role: .protein, minServings: 1, maxServings: 4, allergenTokens: ["huevo", "egg"]),
        FoodItem(id: "avocado", nameKey: "food.name.avocado", tokens: ["aguacate", "avocado"],
                 calories: 160, protein: 2, carbs: 9, fat: 15,
                 unit: .piece, role: .fat, minServings: 0.5, maxServings: 1.5, allergenTokens: []),
        FoodItem(id: "taco", nameKey: "food.name.taco", tokens: ["taco", "tacos"],
                 calories: 175, protein: 8, carbs: 19, fat: 7,
                 unit: .piece, role: .carb, minServings: 1, maxServings: 5, allergenTokens: []),
        FoodItem(id: "tortilla", nameKey: "food.name.tortilla", tokens: ["tortilla", "tortillas"],
                 calories: 62, protein: 2, carbs: 13, fat: 1,
                 unit: .tortilla, role: .carb, minServings: 1, maxServings: 4, allergenTokens: []),
        FoodItem(id: "beans", nameKey: "food.name.beans", tokens: ["frijol", "frijoles", "beans"],
                 calories: 125, protein: 8, carbs: 22, fat: 1,
                 unit: .cup, role: .carb, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "salad", nameKey: "food.name.salad", tokens: ["ensalada", "salad"],
                 calories: 95, protein: 3, carbs: 12, fat: 4,
                 unit: .cup, role: .vegetable, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "greek_yogurt", nameKey: "food.name.greekYogurt", tokens: ["yogurt", "yoghurt"],
                 calories: 130, protein: 15, carbs: 10, fat: 3,
                 unit: .cup, role: .protein, minServings: 0.5, maxServings: 2, allergenTokens: ["lacteo", "lacteos", "leche", "dairy", "milk"]),
        FoodItem(id: "oats", nameKey: "food.name.oats", tokens: ["avena", "oat", "oatmeal"],
                 calories: 190, protein: 7, carbs: 32, fat: 4,
                 unit: .cup, role: .carb, minServings: 0.5, maxServings: 2, allergenTokens: ["gluten"]),
        FoodItem(id: "bread", nameKey: "food.name.bread", tokens: ["pan", "bread", "toast"],
                 calories: 90, protein: 3, carbs: 17, fat: 1,
                 unit: .slice, role: .carb, minServings: 1, maxServings: 4, allergenTokens: ["gluten", "trigo", "wheat"]),
        FoodItem(id: "banana", nameKey: "food.name.banana", tokens: ["platano", "banana"],
                 calories: 105, protein: 1, carbs: 27, fat: 0,
                 unit: .piece, role: .fruit, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "apple", nameKey: "food.name.apple", tokens: ["manzana", "apple"],
                 calories: 95, protein: 0, carbs: 25, fat: 0,
                 unit: .piece, role: .fruit, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "salmon", nameKey: "food.name.salmon", tokens: ["salmon"],
                 calories: 235, protein: 25, carbs: 0, fat: 14,
                 unit: .gram, role: .protein, minServings: 0.75, maxServings: 2, allergenTokens: ["pescado", "fish"]),
        FoodItem(id: "pasta", nameKey: "food.name.pasta", tokens: ["pasta", "spaghetti"],
                 calories: 220, protein: 8, carbs: 43, fat: 1,
                 unit: .cup, role: .carb, minServings: 0.5, maxServings: 2, allergenTokens: ["gluten", "trigo", "wheat"]),
        FoodItem(id: "cheese", nameKey: "food.name.cheese", tokens: ["queso", "cheese"],
                 calories: 110, protein: 7, carbs: 1, fat: 9,
                 unit: .slice, role: .fat, minServings: 1, maxServings: 3, allergenTokens: ["lacteo", "lacteos", "leche", "dairy", "milk"]),
        FoodItem(id: "nopales", nameKey: "food.name.nopales", tokens: ["nopal", "nopales"],
                 calories: 35, protein: 2, carbs: 7, fat: 0,
                 unit: .cup, role: .vegetable, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "pozole", nameKey: "food.name.pozole", tokens: ["pozole"],
                 calories: 360, protein: 24, carbs: 38, fat: 12,
                 unit: .cup, role: .protein, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "tamales", nameKey: "food.name.tamales", tokens: ["tamal", "tamales"],
                 calories: 285, protein: 9, carbs: 34, fat: 13,
                 unit: .piece, role: .carb, minServings: 1, maxServings: 3, allergenTokens: []),
        FoodItem(id: "quesadilla", nameKey: "food.name.quesadilla", tokens: ["quesadilla", "quesadillas"],
                 calories: 310, protein: 13, carbs: 28, fat: 16,
                 unit: .piece, role: .carb, minServings: 1, maxServings: 3, allergenTokens: ["lacteo", "lacteos", "dairy"]),
        FoodItem(id: "beef", nameKey: "food.name.beef", tokens: ["carne asada", "bistec", "res"],
                 calories: 250, protein: 30, carbs: 0, fat: 14,
                 unit: .gram, role: .protein, minServings: 0.75, maxServings: 2, allergenTokens: []),
        FoodItem(id: "tuna", nameKey: "food.name.tuna", tokens: ["atun", "atún", "tuna"],
                 calories: 150, protein: 29, carbs: 0, fat: 3,
                 unit: .gram, role: .protein, minServings: 0.75, maxServings: 2, allergenTokens: ["pescado", "fish"]),
        FoodItem(id: "lentils", nameKey: "food.name.lentils", tokens: ["lenteja", "lentejas", "lentils"],
                 calories: 230, protein: 18, carbs: 40, fat: 1,
                 unit: .cup, role: .protein, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "sweet_potato", nameKey: "food.name.sweetPotato", tokens: ["camote", "sweet potato"],
                 calories: 180, protein: 4, carbs: 41, fat: 0,
                 unit: .cup, role: .carb, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "corn", nameKey: "food.name.corn", tokens: ["elote", "maiz", "corn"],
                 calories: 120, protein: 4, carbs: 27, fat: 2,
                 unit: .piece, role: .carb, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "milk", nameKey: "food.name.milk", tokens: ["leche", "milk"],
                 calories: 125, protein: 8, carbs: 12, fat: 5,
                 unit: .cup, role: .protein, minServings: 0.5, maxServings: 2, allergenTokens: ["lacteo", "lacteos", "leche", "dairy", "milk"]),

        // MARK: - Nuevos (USDA FoodData Central, por porcion)
        // Sin estos, las recetas vegana y vegetariana que el motor YA promete
        // ("Tofu, frijoles y arroz", "Avena, soya y semillas") no se pueden
        // componer: no habia tofu, ni soya, ni semillas, ni grasa añadida.
        FoodItem(id: "tofu", nameKey: "food.name.tofu", tokens: ["tofu"],
                 calories: 145, protein: 16, carbs: 4, fat: 9,
                 unit: .gram, role: .protein, minServings: 0.75, maxServings: 2.5, allergenTokens: ["soya", "soja", "soy"]),
        FoodItem(id: "soy_milk", nameKey: "food.name.soyMilk", tokens: ["soya", "soja", "soy milk"],
                 calories: 105, protein: 7, carbs: 12, fat: 4,
                 unit: .cup, role: .protein, minServings: 0.5, maxServings: 2, allergenTokens: ["soya", "soja", "soy"]),
        FoodItem(id: "seeds", nameKey: "food.name.seeds", tokens: ["semilla", "semillas", "chia", "linaza", "seeds"],
                 calories: 140, protein: 5, carbs: 8, fat: 10,
                 unit: .tablespoon, role: .fat, minServings: 1, maxServings: 3, allergenTokens: []),
        FoodItem(id: "olive_oil", nameKey: "food.name.oliveOil", tokens: ["aceite", "oil"],
                 calories: 120, protein: 0, carbs: 0, fat: 14,
                 unit: .tablespoon, role: .fat, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "broccoli", nameKey: "food.name.broccoli", tokens: ["brocoli", "brócoli", "broccoli"],
                 calories: 55, protein: 4, carbs: 11, fat: 1,
                 unit: .cup, role: .vegetable, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "zucchini", nameKey: "food.name.zucchini", tokens: ["calabacita", "calabaza", "zucchini"],
                 calories: 33, protein: 2, carbs: 6, fat: 1,
                 unit: .cup, role: .vegetable, minServings: 1, maxServings: 2, allergenTokens: []),
        FoodItem(id: "tomato", nameKey: "food.name.tomato", tokens: ["jitomate", "tomate", "tomato"],
                 calories: 32, protein: 2, carbs: 7, fat: 0,
                 unit: .cup, role: .vegetable, minServings: 0.5, maxServings: 2, allergenTokens: []),
        FoodItem(id: "onion", nameKey: "food.name.onion", tokens: ["cebolla", "onion"],
                 calories: 46, protein: 1, carbs: 11, fat: 0,
                 unit: .cup, role: .vegetable, minServings: 0.5, maxServings: 1.5, allergenTokens: []),
        FoodItem(id: "cottage_cheese", nameKey: "food.name.cottageCheese", tokens: ["requeson", "requesón", "panela", "cottage"],
                 calories: 110, protein: 13, carbs: 4, fat: 5,
                 unit: .cup, role: .protein, minServings: 0.5, maxServings: 2, allergenTokens: ["lacteo", "lacteos", "leche", "dairy", "milk"]),
        FoodItem(id: "lime", nameKey: "food.name.lime", tokens: ["limon", "limón", "lime"],
                 calories: 10, protein: 0, carbs: 3, fat: 0,
                 unit: .piece, role: .condiment, minServings: 0.5, maxServings: 2, allergenTokens: [])
    ]
}
