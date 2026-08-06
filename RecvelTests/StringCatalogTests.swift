import XCTest

/// Guard sobre `Shared/Localizable.xcstrings`.
///
/// Existe porque el spanglish que veia el usuario NO venia solo de literales
/// hardcodeados: venia de dentro del catalogo. Habia dos fallos distintos y
/// ninguno de los dos lo detectaba `HardcodedStringsTests`:
///
///  1. **162 claves en español sin traduccion inglesa.** `sourceLanguage` es
///     `es-MX`, asi que la clave ES el texto español. Si falta la unidad `en`,
///     la app en ingles cae al idioma fuente y pinta español — sin error, sin
///     aviso, sin fallo de compilacion.
///  2. **Traducciones automaticas rotas.** "METAS SEMANALES" salia como
///     "SEMANAL MEANS", "Nombre del ejercicio" como "Financial year name" y
///     "AYUNO INTERMITENTE" como "INTERMITENT AID". Ademas tres cadenas tenian
///     el placeholder corrompido a `XPLACEHOLDER1XZ`, que se pintaba tal cual.
///
/// El test es un trinquete igual que el de literales: fija la deuda actual y
/// falla si sube.
final class StringCatalogTests: XCTestCase {

    /// Claves en español que todavia no tienen ingles. **Solo puede bajar.**
    private let untranslatedAllowance = 0

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct Unit: Decodable { let value: String }
                let stringUnit: Unit?
            }
            let localizations: [String: Localization]?
        }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private func loadCatalog() throws -> Catalog {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RecvelTests
            .deletingLastPathComponent()   // raiz
            .appendingPathComponent("Shared/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: try Data(contentsOf: url))
    }

    /// Marcadores inequivocos de español. Deliberadamente conservador: prefiere
    /// no detectar antes que dar un falso positivo sobre ingles legitimo.
    private static let spanish = try! NSRegularExpression(
        pattern: "[áéíóúñÁÉÍÓÚÑ¿¡]|\\b(?:de|del|la|el|los|las|una|con|para|por|sin|que|dia|dias|esta|este|tu|tus|hoy|ayer|semana|noche|noches|carga|comida|entrenamiento|meta|faltan|promedio|objetivo|ciclos|cama|medidas|toca|ver|detalle|semanal|guardar|registro|sesiones|minutos|horas)\\b",
        options: .caseInsensitive
    )

    /// Prestamos con acento que son ingles legitimo. Sin esto, "Sauté the
    /// zucchini" se marcaba como español por la tilde.
    private static let accentedEnglishLoanwords = ["sauté", "sautée", "café", "purée", "jalapeño", "entrée"]

    private func looksSpanish(_ text: String) -> Bool {
        var candidate = text.lowercased()
        for loanword in Self.accentedEnglishLoanwords {
            candidate = candidate.replacingOccurrences(of: loanword, with: "")
        }
        return Self.spanish.firstMatch(in: candidate, range: NSRange(candidate.startIndex..., in: candidate)) != nil
    }

    private func english(_ entry: Catalog.Entry) -> String? {
        entry.localizations?["en"]?.stringUnit?.value
    }

    func testEverySpanishKeyHasAnEnglishTranslation() throws {
        let catalog = try loadCatalog()
        XCTAssertEqual(catalog.sourceLanguage, "es-MX", "El idioma fuente cambio; revisa la premisa de este test.")

        let untranslated = catalog.strings
            .filter { english($0.value) == nil && looksSpanish($0.key) }
            .map(\.key)
            .sorted()

        XCTAssertLessThanOrEqual(
            untranslated.count, untranslatedAllowance,
            "\(untranslated.count) claves en español no tienen traduccion inglesa; la app en ingles las pintara en español. "
            + "Primeras: \(untranslated.prefix(10).joined(separator: " | "))"
        )
    }

    func testNoEnglishTranslationIsStillInSpanish() throws {
        let catalog = try loadCatalog()
        let bad = catalog.strings.compactMap { key, entry -> String? in
            guard let en = english(entry), looksSpanish(en) else { return nil }
            return "\(key) -> \(en)"
        }.sorted()

        XCTAssertTrue(
            bad.isEmpty,
            "Traducciones inglesas que siguen conteniendo español:\n" + bad.joined(separator: "\n")
        )
    }

    func testNoTranslationHasACorruptedPlaceholder() throws {
        let catalog = try loadCatalog()
        // Un traductor automatico convirtio `%%` en `XPLACEHOLDER1XZ` y la app
        // pintaba ese texto literal en pantalla.
        let corrupted = catalog.strings.compactMap { key, entry -> String? in
            guard let en = english(entry), en.contains("PLACEHOLDER") else { return nil }
            return "\(key) -> \(en)"
        }
        XCTAssertTrue(corrupted.isEmpty, "Placeholders corrompidos:\n" + corrupted.joined(separator: "\n"))
    }

    func testTranslationsKeepTheSameFormatSpecifiers() throws {
        let catalog = try loadCatalog()
        // `%1$@` y `%@` son el mismo especificador con y sin posicion: se
        // comparan por tipo, no por texto. Un desajuste aqui es un crash en
        // tiempo de ejecucion, no un texto feo.
        let spec = try NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|@|\\.?\\d*f)")
        func types(_ text: String) -> [String] {
            let clean = text.replacingOccurrences(of: "%%", with: "")
            return spec.matches(in: clean, range: NSRange(clean.startIndex..., in: clean))
                .compactMap { Range($0.range(at: 1), in: clean).map { String(clean[$0]) } }
                .sorted()
        }

        var mismatched: [String] = []
        for (key, entry) in catalog.strings {
            guard let en = english(entry) else { continue }
            if types(key) != types(en) {
                mismatched.append("\(key) [\(types(key))] -> \(en) [\(types(en))]")
            }
        }
        XCTAssertTrue(
            mismatched.isEmpty,
            "Especificadores de formato que no coinciden entre español e ingles:\n" + mismatched.sorted().joined(separator: "\n")
        )
    }
}
