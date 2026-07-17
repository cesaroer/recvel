import Foundation

struct NutritionEstimator: NutritionEstimating {
    private struct Food {
        let name: String
        let tokens: [String]
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    private let catalog: [Food] = [
        Food(name: "pechuga de pollo", tokens: ["pollo", "chicken"], calories: 180, protein: 31, carbs: 0, fat: 5),
        Food(name: "arroz cocido", tokens: ["arroz", "rice"], calories: 205, protein: 4, carbs: 45, fat: 1),
        Food(name: "huevo", tokens: ["huevo", "huevos", "egg"], calories: 78, protein: 6, carbs: 1, fat: 5),
        Food(name: "aguacate", tokens: ["aguacate", "avocado"], calories: 160, protein: 2, carbs: 9, fat: 15),
        Food(name: "taco", tokens: ["taco", "tacos"], calories: 175, protein: 8, carbs: 19, fat: 7),
        Food(name: "tortilla", tokens: ["tortilla", "tortillas"], calories: 62, protein: 2, carbs: 13, fat: 1),
        Food(name: "frijoles", tokens: ["frijol", "frijoles", "beans"], calories: 125, protein: 8, carbs: 22, fat: 1),
        Food(name: "ensalada", tokens: ["ensalada", "salad"], calories: 95, protein: 3, carbs: 12, fat: 4),
        Food(name: "yogurt griego", tokens: ["yogurt", "yoghurt"], calories: 130, protein: 15, carbs: 10, fat: 3),
        Food(name: "avena", tokens: ["avena", "oat", "oatmeal"], calories: 190, protein: 7, carbs: 32, fat: 4),
        Food(name: "pan", tokens: ["pan", "bread", "toast"], calories: 90, protein: 3, carbs: 17, fat: 1),
        Food(name: "platano", tokens: ["platano", "banana"], calories: 105, protein: 1, carbs: 27, fat: 0),
        Food(name: "manzana", tokens: ["manzana", "apple"], calories: 95, protein: 0, carbs: 25, fat: 0),
        Food(name: "salmon", tokens: ["salmon"], calories: 235, protein: 25, carbs: 0, fat: 14),
        Food(name: "pasta", tokens: ["pasta", "spaghetti"], calories: 220, protein: 8, carbs: 43, fat: 1),
        Food(name: "queso", tokens: ["queso", "cheese"], calories: 110, protein: 7, carbs: 1, fat: 9),
        Food(name: "nopales", tokens: ["nopal", "nopales"], calories: 35, protein: 2, carbs: 7, fat: 0),
        Food(name: "pozole", tokens: ["pozole"], calories: 360, protein: 24, carbs: 38, fat: 12),
        Food(name: "tamales", tokens: ["tamal", "tamales"], calories: 285, protein: 9, carbs: 34, fat: 13),
        Food(name: "quesadilla", tokens: ["quesadilla", "quesadillas"], calories: 310, protein: 13, carbs: 28, fat: 16),
        Food(name: "carne asada", tokens: ["carne asada", "bistec", "res"], calories: 250, protein: 30, carbs: 0, fat: 14),
        Food(name: "atún", tokens: ["atun", "atún", "tuna"], calories: 150, protein: 29, carbs: 0, fat: 3),
        Food(name: "lentejas", tokens: ["lenteja", "lentejas", "lentils"], calories: 230, protein: 18, carbs: 40, fat: 1),
        Food(name: "camote", tokens: ["camote", "sweet potato"], calories: 180, protein: 4, carbs: 41, fat: 0),
        Food(name: "elote", tokens: ["elote", "maiz", "corn"], calories: 120, protein: 4, carbs: 27, fat: 2),
        Food(name: "leche", tokens: ["leche", "milk"], calories: 125, protein: 8, carbs: 12, fat: 5)
    ]

    func estimate(from description: String) -> NutritionEstimate? {
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let text = normalized.lowercased()
        let matches = catalog.compactMap { food -> (Food, Double)? in
            guard let token = food.tokens.first(where: { text.contains($0) }) else { return nil }
            return (food, quantity(for: token, in: text))
        }

        guard !matches.isEmpty else {
            return NutritionEstimate(
                title: normalized,
                calories: 260,
                protein: 12,
                carbohydrates: 32,
                fat: 9,
                confidence: .low,
                uncertainties: ["Alimentos no identificados", "Porcion sin confirmar"],
                source: "text-local"
            )
        }

        func total(_ value: (Food) -> Int) -> Int {
            Int(matches.reduce(0.0) { $0 + Double(value($1.0)) * $1.1 }.rounded())
        }

        return NutritionEstimate(
            title: normalized,
            calories: total { $0.calories },
            protein: total { $0.protein },
            carbohydrates: total { $0.carbs },
            fat: total { $0.fat },
            confidence: matches.count >= 2 ? .medium : .low,
            uncertainties: ["Porcion aproximada", "Aceites y salsas no incluidos"],
            source: "text-local"
        )
    }

    func foodDescription(from classifications: [String]) -> String? {
        let joined = classifications.joined(separator: " ").lowercased()
        let foods = catalog.filter { food in food.tokens.contains { joined.contains($0) } }
        guard !foods.isEmpty else { return nil }
        return foods.map(\.name).joined(separator: ", ")
    }

    private func quantity(for token: String, in text: String) -> Double {
        guard let tokenRange = text.range(of: token) else { return 1 }
        let prefix = String(text[..<tokenRange.lowerBound].suffix(18))
        let pattern = #"([0-9]+(?:[\.,][0-9]+)?)\s*(?:x|porciones?|piezas?|tazas?|rebanadas?)?\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let result = regex.firstMatch(in: prefix, range: NSRange(prefix.startIndex..., in: prefix)),
           let range = Range(result.range(at: 1), in: prefix) {
            return Double(prefix[range].replacingOccurrences(of: ",", with: ".")) ?? 1
        }
        if prefix.hasSuffix("dos ") { return 2 }
        if prefix.hasSuffix("tres ") { return 3 }
        if prefix.hasSuffix("media ") || prefix.hasSuffix("medio ") { return 0.5 }
        return 1
    }
}
