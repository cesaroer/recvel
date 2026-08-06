import XCTest

/// Guard contra literales en español escritos a mano en la UI.
///
/// Existe porque una auditoria del catalogo de strings NO detecta este problema:
/// un `Text("Guardar")` nunca llega a `Localizable.xcstrings`, asi que el
/// catalogo se ve impecable mientras la app muestra spanglish. Se descubrio
/// justamente asi — revisando el catalogo en vez del codigo.
///
/// Funciona como TRINQUETE: fija cuantos literales quedan por archivo y falla si
/// alguno sube. Se puede bajar el numero al traducir, nunca subirlo. Cuando un
/// archivo llegue a 0, se quita de la lista y ya no admite regresiones.
final class HardcodedStringsTests: XCTestCase {

    /// Deuda conocida por archivo. **Solo puede bajar.**
    private let allowance: [String: Int] = [
        "FitnessView.swift": 55,
        "TrainingPlanViews.swift": 53,
        "LaboratoryView.swift": 14,
        "MorningReportView.swift": 13,
        "PlanView.swift": 13,
        "TonightDetailView.swift": 12,
        "TrainingPresetCatalog.swift": 10,
        "JournalProView.swift": 7,
        "DetailViews.swift": 6,
        "FastingView.swift": 5,
        "ExerciseMechanicsView.swift": 4,
        "NutritionSetupView.swift": 4,
        "HealthIntelligenceViews.swift": 2,
        "JournalView.swift": 2,
        "NutritionView.swift": 2,
        "DashboardView.swift": 1,
        "GlassComponents.swift": 1,
        "HomeCalendarViews.swift": 1,
        "OnboardingView.swift": 1,
        "ReportRing.swift": 1
    ]

    func testHardcodedSpanishDoesNotGrow() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RecvelTests
            .deletingLastPathComponent()   // raiz
            .appendingPathComponent("Recvel")

        let constructors = "Text|Label|Button|TextField|navigationTitle|accessibilityLabel"
        let literal = try NSRegularExpression(
            pattern: "\\b(?:\(constructors))\\(\\s*\"([^\"]{3,})\""
        )
        // Acentos, signos de apertura o palabras funcionales del español.
        let spanish = try NSRegularExpression(
            pattern: "[áéíóúñÁÉÍÓÚÑ¿¡]|\\b(?:de|la|el|los|las|tu|tus|con|para|por|del|una|uno|sin|que|más|día|días|comida|sueño|carga|entrenamiento|registro|ver|añadir|guardar|cerrar|editar|eliminar|nuevo|nueva|semana|hoy|ayer)\\b",
            options: .caseInsensitive
        )
        // Una clave de localizacion no es texto visible.
        let key = try NSRegularExpression(pattern: "^[a-z][a-zA-Z0-9]*(\\.[a-zA-Z0-9]+)+$")

        var counts: [String: Int] = [:]
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for file in files {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let range = NSRange(source.startIndex..., in: source)
            for match in literal.matches(in: source, range: range) {
                guard let r = Range(match.range(at: 1), in: source) else { continue }
                let text = String(source[r])
                if text.hasPrefix("http") || text.hasPrefix("#") || text.hasPrefix("%") { continue }
                let textRange = NSRange(text.startIndex..., in: text)
                if key.firstMatch(in: text, range: textRange) != nil { continue }
                if spanish.firstMatch(in: text, range: textRange) == nil { continue }
                counts[file.lastPathComponent, default: 0] += 1
            }
        }

        for (file, found) in counts.sorted(by: { $0.key < $1.key }) {
            let allowed = allowance[file] ?? 0
            XCTAssertLessThanOrEqual(
                found, allowed,
                "\(file) tiene \(found) literales en español sin localizar (permitidos \(allowed)). "
                + "Usa RecvelL10n.text(clave) y baja el numero en `allowance`."
            )
        }
        for (file, allowed) in allowance where (counts[file] ?? 0) < allowed {
            print("✅ \(file): bajo a \(counts[file] ?? 0) (permitidos \(allowed)). Actualiza `allowance`.")
        }
    }
}
