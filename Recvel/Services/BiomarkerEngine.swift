import Foundation
import HealthKit

enum BioAgeLens: String, CaseIterable, Identifiable {
    case cardio = "Cardio"
    case blood = "Sangre"

    var id: String { rawValue }
    var method: String { self == .cardio ? "FRIEND · beta" : "PhenoAge" }
}

enum BiomarkerStatus: String {
    case favorable = "En rango"
    case fair = "A vigilar"
    case attention = "Prioridad"
    case calibrating = "Calibrando"
    case missing = "Faltante"
}

struct BiomarkerDescriptor: Identifiable {
    let kind: BiomarkerKind
    let title: String
    let shortTitle: String
    let unit: String
    let symbol: String
    let explanation: String
    let benchmark: String
    let isLaboratory: Bool

    var id: BiomarkerKind { kind }
}

enum BiomarkerCatalog {
    static let all: [BiomarkerDescriptor] = [
        .init(kind: .weight, title: "Peso corporal", shortTitle: "Peso", unit: "kg", symbol: "scalemass.fill", explanation: "Contexto para composicion corporal y tendencias. Un valor aislado no describe salud.", benchmark: "Usa tu propia tendencia", isLaboratory: false),
        .init(kind: .hrvBaseline, title: "HRV basal", shortTitle: "HRV", unit: "ms", symbol: "waveform.path.ecg", explanation: "Variacion de 60 dias de la HRV. Es sensible a sueno, carga, enfermedad y artefactos.", benchmark: "Comparacion personal de 60 dias", isLaboratory: false),
        .init(kind: .rhrBaseline, title: "FC en reposo basal", shortTitle: "FC reposo", unit: "lpm", symbol: "heart.fill", explanation: "Tendencia de frecuencia cardiaca en reposo sobre 60 dias.", benchmark: "Comparacion personal de 60 dias", isLaboratory: false),
        .init(kind: .bodyFat, title: "Grasa corporal", shortTitle: "Grasa", unit: "%", symbol: "percent", explanation: "Estimacion dependiente del metodo y dispositivo. Sigue cambios con la misma fuente.", benchmark: "Tendencia, no lectura aislada", isLaboratory: false),
        .init(kind: .leanBodyMass, title: "Masa corporal magra", shortTitle: "Masa magra", unit: "kg", symbol: "figure.strengthtraining.traditional", explanation: "Masa corporal sin grasa estimada por la fuente autorizada.", benchmark: "Mantener o mejorar con fuerza", isLaboratory: false),
        .init(kind: .vo2Max, title: "VO2 max", shortTitle: "VO2 max", unit: "ml/kg/min", symbol: "lungs.fill", explanation: "Estimacion de aptitud cardiorrespiratoria. Es la base de la lente FRIEND.", benchmark: "Medianas FRIEND por edad y sexo", isLaboratory: false),
        .init(kind: .systolicBloodPressure, title: "Presion sistolica", shortTitle: "Sistolica", unit: "mmHg", symbol: "gauge.with.dots.needle.50percent", explanation: "Presion durante la contraccion cardiaca. Recvel no interpreta urgencias ni diagnostica.", benchmark: "Consulta la lectura con un profesional", isLaboratory: false),
        .init(kind: .diastolicBloodPressure, title: "Presion diastolica", shortTitle: "Diastolica", unit: "mmHg", symbol: "gauge.with.dots.needle.33percent", explanation: "Presion entre latidos. Repite mediciones con tecnica consistente.", benchmark: "Consulta la lectura con un profesional", isLaboratory: false),
        .init(kind: .oxygenSaturation, title: "Oxigeno en sangre", shortTitle: "SpO2", unit: "%", symbol: "drop.degreesign.fill", explanation: "Lectura de bienestar sujeta a ajuste del reloj, movimiento y perfusion.", benchmark: "Tendencia del mismo dispositivo", isLaboratory: false),
        .init(kind: .albumin, title: "Albumina", shortTitle: "Albumina", unit: "g/L", symbol: "testtube.2", explanation: "Uno de los nueve analitos publicados de PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .creatinine, title: "Creatinina", shortTitle: "Creatinina", unit: "umol/L", symbol: "testtube.2", explanation: "Uno de los nueve analitos publicados de PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .glucose, title: "Glucosa", shortTitle: "Glucosa", unit: "mmol/L", symbol: "testtube.2", explanation: "PhenoAge usa glucosa en mmol/L; no sustituye una evaluacion metabolica.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .crp, title: "Proteina C reactiva", shortTitle: "PCR", unit: "mg/L", symbol: "testtube.2", explanation: "PhenoAge utiliza el logaritmo natural de PCR. Debe ser mayor que cero.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .lymphocytePercent, title: "Linfocitos", shortTitle: "Linfocitos", unit: "%", symbol: "testtube.2", explanation: "Porcentaje de linfocitos requerido por PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .mcv, title: "Volumen corpuscular medio", shortTitle: "VCM", unit: "fL", symbol: "testtube.2", explanation: "Volumen corpuscular medio requerido por PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .rdw, title: "Amplitud eritrocitaria", shortTitle: "RDW", unit: "%", symbol: "testtube.2", explanation: "Red cell distribution width requerido por PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .alkalinePhosphatase, title: "Fosfatasa alcalina", shortTitle: "Fosfatasa", unit: "U/L", symbol: "testtube.2", explanation: "Analito requerido por PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true),
        .init(kind: .whiteBloodCellCount, title: "Leucocitos", shortTitle: "Leucocitos", unit: "10^9/L", symbol: "testtube.2", explanation: "Conteo de globulos blancos requerido por PhenoAge.", benchmark: "Rango del laboratorio", isLaboratory: true)
    ]

    static let phenoAgeKinds: [BiomarkerKind] = [
        .albumin, .creatinine, .glucose, .crp, .lymphocytePercent,
        .mcv, .rdw, .alkalinePhosphatase, .whiteBloodCellCount
    ]

    static func descriptor(for kind: BiomarkerKind) -> BiomarkerDescriptor {
        all.first { $0.kind == kind }!
    }
}

struct PhenoAgeInput: Equatable {
    let chronologicalAge: Double
    let albuminGL: Double
    let creatinineUmolL: Double
    let glucoseMmolL: Double
    let crpMgL: Double
    let lymphocytePercent: Double
    let mcvFL: Double
    let rdwPercent: Double
    let alkalinePhosphataseUL: Double
    let whiteBloodCellCount: Double
}

struct PhenoAgeResult: Equatable {
    let years: Double
    let mortalityScore: Double
}

enum PhenoAgeError: Error, Equatable {
    case under18
    case invalidValue(BiomarkerKind)
    case incompletePanel([BiomarkerKind])
}

struct PhenoAgeEngine {
    func calculate(_ input: PhenoAgeInput) throws -> PhenoAgeResult {
        guard input.chronologicalAge >= 18 else { throw PhenoAgeError.under18 }
        let checks: [(BiomarkerKind, Double)] = [
            (.albumin, input.albuminGL), (.creatinine, input.creatinineUmolL),
            (.glucose, input.glucoseMmolL), (.crp, input.crpMgL),
            (.lymphocytePercent, input.lymphocytePercent), (.mcv, input.mcvFL),
            (.rdw, input.rdwPercent), (.alkalinePhosphatase, input.alkalinePhosphataseUL),
            (.whiteBloodCellCount, input.whiteBloodCellCount)
        ]
        if let invalid = checks.first(where: { !$0.1.isFinite || $0.1 <= 0 }) {
            throw PhenoAgeError.invalidValue(invalid.0)
        }

        let xb = -19.90667
            - 0.03359355 * input.albuminGL
            + 0.009506491 * input.creatinineUmolL
            + 0.1953192 * input.glucoseMmolL
            + 0.09536762 * log(input.crpMgL)
            - 0.01199984 * input.lymphocytePercent
            + 0.02676401 * input.mcvFL
            + 0.3306156 * input.rdwPercent
            + 0.001868778 * input.alkalinePhosphataseUL
            + 0.05542406 * input.whiteBloodCellCount
            + 0.08035356 * input.chronologicalAge
        let mortality = 1 - exp((-1.51714 * exp(xb)) / 0.0076927)
        let boundedMortality = min(max(mortality, 0.0000001), 0.9999999)
        let years = 141.50225 + log(-0.00553 * log(1 - boundedMortality)) / 0.090165
        guard years.isFinite else { throw PhenoAgeError.invalidValue(.crp) }
        return PhenoAgeResult(years: years, mortalityScore: boundedMortality)
    }
}

struct ResolvedPhenoAgePanel {
    let input: PhenoAgeInput
    let newestDate: Date
    let oldestDate: Date
    let samples: [BiomarkerKind: BiomarkerSample]
}

struct PhenoAgePanelResolver {
    private let calendar = Calendar.current

    func resolve(samples: [BiomarkerSample], birthDate: Date?, now: Date = .now) throws -> ResolvedPhenoAgePanel {
        guard let birthDate else { throw PhenoAgeError.under18 }
        let age = calendar.dateComponents([.year, .month, .day], from: birthDate, to: now)
        let years = Double(age.year ?? 0) + Double(age.month ?? 0) / 12 + Double(age.day ?? 0) / 365.25
        guard years >= 18 else { throw PhenoAgeError.under18 }
        let cutoff = calendar.date(byAdding: .month, value: -6, to: now) ?? .distantPast
        var latest: [BiomarkerKind: BiomarkerSample] = [:]
        for sample in samples where sample.observedAt >= cutoff {
            guard let kind = sample.kind, BiomarkerCatalog.phenoAgeKinds.contains(kind) else { continue }
            if latest[kind] == nil || sample.observedAt > latest[kind]!.observedAt { latest[kind] = sample }
        }
        let missing = BiomarkerCatalog.phenoAgeKinds.filter { latest[$0] == nil }
        guard missing.isEmpty else { throw PhenoAgeError.incompletePanel(missing) }

        func value(_ kind: BiomarkerKind) throws -> Double {
            guard let sample = latest[kind], let normalized = normalize(sample, kind: kind) else {
                throw PhenoAgeError.invalidValue(kind)
            }
            return normalized
        }
        let dates = latest.values.map(\.observedAt)
        return ResolvedPhenoAgePanel(
            input: try PhenoAgeInput(
                chronologicalAge: years,
                albuminGL: value(.albumin),
                creatinineUmolL: value(.creatinine),
                glucoseMmolL: value(.glucose),
                crpMgL: value(.crp),
                lymphocytePercent: value(.lymphocytePercent),
                mcvFL: value(.mcv),
                rdwPercent: value(.rdw),
                alkalinePhosphataseUL: value(.alkalinePhosphatase),
                whiteBloodCellCount: value(.whiteBloodCellCount)
            ),
            newestDate: dates.max() ?? now,
            oldestDate: dates.min() ?? now,
            samples: latest
        )
    }

    private func normalize(_ sample: BiomarkerSample, kind: BiomarkerKind) -> Double? {
        let unit = sample.unit.lowercased().replacingOccurrences(of: "µ", with: "u").replacingOccurrences(of: " ", with: "")
        let value = sample.value
        guard value.isFinite, value > 0 else { return nil }
        switch kind {
        case .albumin:
            if unit.contains("g/dl") { return value * 10 }
            return unit.contains("g/l") ? value : nil
        case .creatinine:
            if unit.contains("mg/dl") { return value * 88.4 }
            return unit.contains("umol/l") ? value : nil
        case .glucose:
            if unit.contains("mg/dl") { return value / 18.018 }
            return unit.contains("mmol/l") ? value : nil
        case .crp:
            if unit.contains("mg/dl") { return value * 10 }
            return unit.contains("mg/l") ? value : nil
        case .lymphocytePercent, .rdw:
            return unit.contains("%") || unit.contains("percent") ? value : nil
        case .mcv:
            return unit.contains("fl") ? value : nil
        case .alkalinePhosphatase:
            return unit.contains("u/l") ? value : nil
        case .whiteBloodCellCount:
            if unit.contains("10^9/l") || unit.contains("10e9/l") || unit.contains("10*9/l") || unit.contains("k/ul") || unit.contains("10^3/ul") { return value }
            return nil
        default:
            return value
        }
    }
}

struct BioAgeDriver: Identifiable {
    let id: String
    let title: String
    let value: String
    let benchmark: String
    let status: BiomarkerStatus
    let priority: Int
    let points: [Double]
    let source: String
}

struct BioAgeReport {
    let selectedLens: BioAgeLens
    let cardioAge: Double?
    let phenoAge: Double?
    let chronologicalAge: Int?
    let confidence: DataConfidence
    let updatedAt: Date
    let coverageDays: Int
    let summary: String
    let drivers: [BioAgeDriver]

    var displayedAge: Double? { selectedLens == .blood ? phenoAge : cardioAge }
    var deltaYears: Double? {
        guard let displayedAge, let chronologicalAge else { return nil }
        return displayedAge - Double(chronologicalAge)
    }
    var availableLenses: [BioAgeLens] {
        var values: [BioAgeLens] = []
        if cardioAge != nil { values.append(.cardio) }
        if phenoAge != nil { values.append(.blood) }
        return values.isEmpty ? [.cardio] : values
    }
}

struct BioAgeReportEngine {
    private let calendar = Calendar.current

    func report(
        cardio: BioAgeEstimate,
        history: [DailyHealthSnapshot],
        laboratorySamples: [BiomarkerSample],
        birthDate: Date?,
        meals: [MealLog] = [],
        habits: [HabitLog] = [],
        preferredLens: BioAgeLens? = nil,
        now: Date = .now
    ) -> BioAgeReport {
        let cutoff = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? .distantPast
        let recent = history.filter { $0.date >= cutoff && $0.date <= now }
        let coverage = Set(recent.filter { $0.availableSignalCount >= 3 }.map { calendar.startOfDay(for: $0.date) }).count
        let phenoAge: Double?
        let bloodDate: Date?
        if let panel = try? PhenoAgePanelResolver().resolve(samples: laboratorySamples, birthDate: birthDate, now: now),
           let result = try? PhenoAgeEngine().calculate(panel.input) {
            phenoAge = result.years
            bloodDate = panel.newestDate
        } else {
            phenoAge = nil
            bloodDate = nil
        }
        let available: [BioAgeLens] = [cardio.estimatedYears == nil ? nil : .cardio, phenoAge == nil ? nil : .blood].compactMap { $0 }
        let lens = preferredLens.flatMap { available.contains($0) ? $0 : nil } ?? (phenoAge != nil ? .blood : .cardio)
        let confidence: DataConfidence
        if lens == .blood { confidence = phenoAge == nil ? .low : .high }
        else if coverage >= 20 && cardio.estimatedYears != nil { confidence = .high }
        else if coverage >= 7 && cardio.estimatedYears != nil { confidence = .medium }
        else { confidence = .low }
        let updated = lens == .blood ? (bloodDate ?? now) : (recent.compactMap(\.vo2MaxDate).max() ?? now)
        let summary: String
        if lens == .blood {
            summary = "PhenoAge usa edad y nueve analitos publicados. No combina sueno o actividad con el numero principal."
        } else {
            summary = cardio.summary
        }
        return BioAgeReport(
            selectedLens: lens,
            cardioAge: cardio.estimatedYears,
            phenoAge: phenoAge,
            chronologicalAge: cardio.chronologicalYears,
            confidence: confidence,
            updatedAt: updated,
            coverageDays: coverage,
            summary: summary,
            drivers: drivers(history: recent, meals: meals, habits: habits, now: now)
        )
    }

    private func drivers(history: [DailyHealthSnapshot], meals: [MealLog], habits: [HabitLog], now: Date) -> [BioAgeDriver] {
        func average(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
        func points(_ values: [Double?]) -> [Double] { values.compactMap { $0 } }
        let sleep = points(history.map(\.sleepHours))
        let consistency = points(history.map { $0.sleepDetails?.consistencyMinutes })
        let steps = history.compactMap(\.steps).map(Double.init)
        let zone23 = history.flatMap(\.workouts).flatMap(\.zones).filter { $0.zone == 2 || $0.zone == 3 }.reduce(0) { $0 + $1.minutes } / 4
        let zone45 = history.flatMap(\.workouts).flatMap(\.zones).filter { $0.zone >= 4 }.reduce(0) { $0 + $1.minutes } / 4
        let strength = history.flatMap(\.workouts).filter { $0.activityName == "Fuerza" }.reduce(0) { $0 + $1.durationMinutes } / 4
        let vo2 = points(history.map(\.vo2Max))
        let rhr = points(history.map(\.restingHeartRate))
        let lean = points(history.map(\.leanBodyMassKg))
        let mealCutoff = calendar.date(byAdding: .day, value: -27, to: now) ?? .distantPast
        let mealDays = Set(meals.filter { $0.createdAt >= mealCutoff }.map { calendar.startOfDay(for: $0.createdAt) }).count
        let alcoholYes = habits.filter { $0.date >= mealCutoff && $0.answer && (($0.tagID ?? "").contains("alcohol") || $0.habit.localizedCaseInsensitiveContains("alcohol")) }.count

        func driver(_ id: String, _ title: String, _ value: Double?, unit: String, benchmark: String, good: ClosedRange<Double>, fair: ClosedRange<Double>, priority: Int, points: [Double], source: String = "Apple Health") -> BioAgeDriver {
            let status: BiomarkerStatus
            if let value { status = good.contains(value) ? .favorable : (fair.contains(value) ? .fair : .attention) }
            else { status = .missing }
            return BioAgeDriver(id: id, title: title, value: value.map { String(format: $0 >= 100 ? "%.0f %@" : "%.1f %@", $0, unit) } ?? "Sin datos", benchmark: benchmark, status: status, priority: priority, points: points, source: source)
        }

        var values: [BioAgeDriver] = [
            driver("sleep.duration", "Tiempo de sueno", average(sleep), unit: "h", benchmark: "Referencia de bienestar: 7-9 h", good: 7...9, fair: 6...10, priority: 1, points: sleep),
            driver("sleep.consistency", "Consistencia del sueno", average(consistency), unit: "min", benchmark: "Variacion menor a 45 min", good: 0...45, fair: 45...75, priority: 2, points: consistency),
            driver("activity.steps", "Pasos", average(steps), unit: "pasos/dia", benchmark: "Objetivo contextual: 8,000/dia", good: 8000...50000, fair: 6000...7999, priority: 1, points: steps),
            driver("activity.zone23", "Zonas 2-3", zone23, unit: "min/sem", benchmark: "Referencia general: 150 min/sem", good: 150...2000, fair: 90...149, priority: 2, points: [zone23]),
            driver("activity.zone45", "Zonas 4-5", zone45, unit: "min/sem", benchmark: "Contexto de intensidad: 10+ min/sem", good: 10...1000, fair: 1...9.99, priority: 3, points: [zone45]),
            driver("activity.strength", "Fuerza", strength, unit: "min/sem", benchmark: "Dos sesiones semanales", good: 40...2000, fair: 20...39.99, priority: 1, points: [strength]),
            driver("cardio.vo2", "VO2 max", vo2.last, unit: "ml/kg/min", benchmark: "Comparacion FRIEND por edad y sexo", good: 40...100, fair: 30...39.99, priority: 1, points: vo2),
            driver("cardio.rhr", "FC en reposo", average(rhr), unit: "lpm", benchmark: "Usa tu baseline de 60 dias", good: 40...65, fair: 65...75, priority: 2, points: rhr),
            driver("body.lean", "Masa magra", lean.last, unit: "kg", benchmark: "Seguir tendencia con la misma fuente", good: 1...300, fair: 0...0, priority: 3, points: lean)
        ]
        values.append(BioAgeDriver(id: "lifestyle.nutrition", title: "Nutricion", value: mealDays == 0 ? "Sin registros" : "(mealDays) dias registrados", benchmark: "La consistencia mejora el contexto", status: mealDays >= 20 ? .favorable : (mealDays >= 7 ? .fair : .calibrating), priority: 3, points: [], source: "Recvel local"))
        values.append(BioAgeDriver(id: "lifestyle.alcohol", title: "Alcohol", value: alcoholYes == 0 ? "Sin reportes" : "(alcoholYes) dias", benchmark: "Solo registros voluntarios", status: alcoholYes == 0 ? .calibrating : .attention, priority: 3, points: [], source: "Journal"))
        return values.sorted { ($0.status == .attention ? 0 : $0.priority) < ($1.status == .attention ? 0 : $1.priority) }
    }
}

struct BiomarkerReading: Identifiable {
    let descriptor: BiomarkerDescriptor
    let value: Double?
    let unit: String
    let date: Date?
    let source: String
    let history: [(date: Date, value: Double)]

    var id: BiomarkerKind { descriptor.kind }
}

struct BiomarkerProvider {
    func readings(history: [DailyHealthSnapshot], samples: [BiomarkerSample]) -> [BiomarkerReading] {
        BiomarkerCatalog.all.map { descriptor in
            let local = samples.filter { $0.kind == descriptor.kind }.sorted { $0.observedAt < $1.observedAt }
            if descriptor.isLaboratory {
                return BiomarkerReading(descriptor: descriptor, value: local.last?.value, unit: local.last?.unit ?? descriptor.unit, date: local.last?.observedAt, source: local.last?.source ?? "Manual", history: local.map { ($0.observedAt, $0.value) })
            }
            let series = wearableSeries(for: descriptor.kind, history: history)
            return BiomarkerReading(descriptor: descriptor, value: series.last?.value, unit: descriptor.unit, date: series.last?.date, source: series.isEmpty ? "Apple Health" : "Apple Health", history: series)
        }
    }

    private func wearableSeries(for kind: BiomarkerKind, history: [DailyHealthSnapshot]) -> [(date: Date, value: Double)] {
        history.sorted { $0.date < $1.date }.compactMap { day in
            let value: Double?
            switch kind {
            case .weight: value = day.bodyMassKg
            case .hrvBaseline: value = day.hrv
            case .rhrBaseline: value = day.restingHeartRate
            case .bodyFat: value = day.bodyFatPercentage.map { $0 <= 1 ? $0 * 100 : $0 }
            case .leanBodyMass: value = day.leanBodyMassKg
            case .vo2Max: value = day.vo2Max
            case .systolicBloodPressure: value = day.systolicBloodPressure
            case .diastolicBloodPressure: value = day.diastolicBloodPressure
            case .oxygenSaturation: value = day.oxygenSaturation.map { $0 <= 1 ? $0 * 100 : $0 }
            default: value = nil
            }
            return value.map { (day.date, $0) }
        }
    }
}

struct ImportedBiomarker {
    let kind: BiomarkerKind
    let value: Double
    let unit: String
    let observedAt: Date
    let externalIdentifier: String?
}

enum ClinicalRecordsImportError: LocalizedError {
    case unavailable
    case unsupportedRecord

    var errorDescription: String? {
        switch self {
        case .unavailable: "Clinical Records no esta disponible en este dispositivo."
        case .unsupportedRecord: "No encontramos analitos PhenoAge compatibles en los registros autorizados."
        }
    }
}

final class ClinicalRecordsImporter {
    private let store = HKHealthStore()

    func importPhenoAgeLabs() async throws -> [ImportedBiomarker] {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.clinicalType(forIdentifier: .labResultRecord) else {
            throw ClinicalRecordsImportError.unavailable
        }
        try await store.requestAuthorization(toShare: [], read: [type])
        let records: [HKClinicalRecord] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKClinicalRecord]) ?? [])
            }
            store.execute(query)
        }
        let imported = records.compactMap(parse)
        guard !imported.isEmpty else { throw ClinicalRecordsImportError.unsupportedRecord }
        return imported
    }

    private func parse(_ record: HKClinicalRecord) -> ImportedBiomarker? {
        guard let resource = record.fhirResource,
              let object = try? JSONSerialization.jsonObject(with: resource.data) as? [String: Any],
              let coding = ((object["code"] as? [String: Any])?["coding"] as? [[String: Any]])?.first,
              let code = coding["code"] as? String,
              let quantity = object["valueQuantity"] as? [String: Any],
              let value = quantity["value"] as? Double else { return nil }
        let map: [String: BiomarkerKind] = [
            "1751-7": .albumin, "2160-0": .creatinine, "2345-7": .glucose,
            "1988-5": .crp, "736-9": .lymphocytePercent, "787-2": .mcv,
            "788-0": .rdw, "6768-6": .alkalinePhosphatase, "6690-2": .whiteBloodCellCount
        ]
        guard let kind = map[code] else { return nil }
        let unit = (quantity["unit"] as? String) ?? (quantity["code"] as? String) ?? BiomarkerCatalog.descriptor(for: kind).unit
        let date = (object["effectiveDateTime"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? record.startDate
        return ImportedBiomarker(kind: kind, value: value, unit: unit, observedAt: date, externalIdentifier: resource.identifier)
    }
}
