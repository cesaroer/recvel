import Foundation

struct NutritionEstimator: NutritionEstimating {
    // El catalogo de alimentos vive ahora en `FoodCatalog`: las recetas
    // necesitan componer platillos sumando alimentos reales, y tenerlo privado
    // aqui obligaba a duplicarlo. Los macros no cambiaron.

    func estimate(from description: String) -> NutritionEstimate? {
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let text = normalized.lowercased()
        let matches = FoodCatalog.items.compactMap { food -> (FoodItem, Double)? in
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

        func total(_ value: (FoodItem) -> Int) -> Int {
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
        let foods = FoodCatalog.items.filter { food in food.tokens.contains { joined.contains($0) } }
        guard !foods.isEmpty else { return nil }
        // El nombre visible sale de la clave de localizacion, no de un
        // literal en español: esta descripcion acaba en la UI.
        return foods.map { RecvelL10n.text($0.nameKey) }.joined(separator: ", ")
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
