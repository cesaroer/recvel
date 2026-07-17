import Foundation
import SwiftData

enum JournalTagCategory: String, CaseIterable, Identifiable, Codable {
    case automatic = "Automaticos"
    case health = "Salud"
    case lifestyle = "Estilo de vida"
    case medication = "Medicacion"
    case cycle = "Ciclo"
    case personal = "Personal"

    var id: String { rawValue }
}

enum JournalTagPeriod: String, CaseIterable, Codable {
    case daytime = "Durante el dia"
    case nighttime = "Durante la noche"
}

enum JournalTagSource: String, Codable {
    case automatic
    case manual
    case hybrid
    case custom
    case defaultValue
}

enum JournalTrackingMode: String, Codable {
    case boolean
    case quantity
    case mood
}

@Model
final class JournalTagConfiguration {
    var id: UUID
    var tagID: String
    var customTitle: String?
    var customSymbol: String?
    var categoryRaw: String
    var periodRaw: String
    var trackingModeRaw: String
    var sourceRaw: String
    var isEnabled: Bool
    var isPinned: Bool
    var isSensitive: Bool
    /// -1 means no default, 0 means No, 1 means Yes.
    var defaultState: Int
    var threshold: Double?
    var unit: String?
    var updatedAt: Date

    init(
        tagID: String,
        customTitle: String? = nil,
        customSymbol: String? = nil,
        category: JournalTagCategory,
        period: JournalTagPeriod,
        trackingMode: JournalTrackingMode = .boolean,
        source: JournalTagSource,
        isEnabled: Bool,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        defaultState: Int = -1,
        threshold: Double? = nil,
        unit: String? = nil
    ) {
        self.id = UUID()
        self.tagID = tagID
        self.customTitle = customTitle
        self.customSymbol = customSymbol
        self.categoryRaw = category.rawValue
        self.periodRaw = period.rawValue
        self.trackingModeRaw = trackingMode.rawValue
        self.sourceRaw = source.rawValue
        self.isEnabled = isEnabled
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.defaultState = defaultState
        self.threshold = threshold
        self.unit = unit
        self.updatedAt = .now
    }
}

enum BiomarkerKind: String, CaseIterable, Codable {
    case weight
    case hrvBaseline
    case rhrBaseline
    case bodyFat
    case leanBodyMass
    case vo2Max
    case systolicBloodPressure
    case diastolicBloodPressure
    case oxygenSaturation
    case albumin
    case creatinine
    case glucose
    case crp
    case lymphocytePercent
    case mcv
    case rdw
    case alkalinePhosphatase
    case whiteBloodCellCount
}

@Model
final class BiomarkerSample {
    var id: UUID
    var kindRaw: String
    var value: Double
    var unit: String
    var observedAt: Date
    var source: String
    var externalIdentifier: String?
    var note: String?

    init(
        kind: BiomarkerKind,
        value: Double,
        unit: String,
        observedAt: Date = .now,
        source: String = "Manual",
        externalIdentifier: String? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.value = value
        self.unit = unit
        self.observedAt = observedAt
        self.source = source
        self.externalIdentifier = externalIdentifier
        self.note = note
    }

    var kind: BiomarkerKind? { BiomarkerKind(rawValue: kindRaw) }
}

@Model
final class BioAgeReportRecord {
    var id: UUID
    var weekStart: Date
    var generatedAt: Date
    var cardioAge: Double?
    var phenoAge: Double?
    var confidenceRaw: String
    var selectedLensRaw: String

    init(
        weekStart: Date,
        generatedAt: Date = .now,
        cardioAge: Double?,
        phenoAge: Double?,
        confidence: DataConfidence,
        selectedLensRaw: String
    ) {
        self.id = UUID()
        self.weekStart = weekStart
        self.generatedAt = generatedAt
        self.cardioAge = cardioAge
        self.phenoAge = phenoAge
        self.confidenceRaw = confidence.rawValue
        self.selectedLensRaw = selectedLensRaw
    }
}
