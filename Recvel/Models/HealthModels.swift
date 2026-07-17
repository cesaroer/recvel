import Foundation
import SwiftData
import SwiftUI

enum DataConfidence: String, Codable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"
}

enum HealthDataMode: String {
    case empty = "Sin datos"
    case demo = "Demo"
    case buildingBaseline = "Creando baseline"
    case partial = "Datos parciales"
    case healthKit = "Apple Health"
}

enum HealthPermissionState: String {
    case unavailable = "No disponible"
    case notRequested = "Permisos pendientes"
    case requested = "Permisos solicitados"
}

enum DataQualityIssue: String, Hashable {
    case partialDay
    case insufficientHistory
    case mixedSources
    case missingSleepStages
}

struct SleepSummary {
    let startDate: Date
    let endDate: Date
    let inBedHours: Double
    let asleepHours: Double
    let coreHours: Double
    let deepHours: Double
    let remHours: Double
    let awakeHours: Double
    let unspecifiedHours: Double
    let napHours: Double
    let latencyMinutes: Double?
    let consistencyMinutes: Double?
    let sourceName: String

    var efficiency: Double? {
        guard inBedHours > 0 else { return nil }
        return min(asleepHours / inBedHours * 100, 100)
    }

    var hasStages: Bool { coreHours + deepHours + remHours > 0.05 }

    func withConsistency(_ minutes: Double?) -> SleepSummary {
        SleepSummary(
            startDate: startDate,
            endDate: endDate,
            inBedHours: inBedHours,
            asleepHours: asleepHours,
            coreHours: coreHours,
            deepHours: deepHours,
            remHours: remHours,
            awakeHours: awakeHours,
            unspecifiedHours: unspecifiedHours,
            napHours: napHours,
            latencyMinutes: latencyMinutes,
            consistencyMinutes: minutes,
            sourceName: sourceName
        )
    }
}

struct HeartRateZoneDuration: Identifiable {
    let zone: Int
    let minutes: Double
    var id: Int { zone }
}

struct HeartRateObservation {
    let date: Date
    let beatsPerMinute: Double
}

struct WorkoutSummary: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityName: String
    let durationMinutes: Double
    let activeEnergy: Double?
    let averageHeartRate: Double?
    let maximumHeartRate: Double?
    let heartRateRecoveryOneMinute: Double?
    let zones: [HeartRateZoneDuration]
    let cardiovascularLoad: Double
    let sourceName: String
}

enum ScoreKind: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case strain = "Strain"
    case sleep = "Sleep"
    case energy = "Energy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recovery: "heart.fill"
        case .strain: "flame.fill"
        case .sleep: "moon.stars.fill"
        case .energy: "bolt.fill"
        }
    }

    // Paleta del sistema de diseno (README_IA_CONTEXT 5.2)
    var color: Color {
        switch self {
        case .recovery: Color(red: 0.204, green: 0.827, blue: 0.600) // #34D399 verde menta
        case .strain: Color(red: 0.984, green: 0.573, blue: 0.235)   // #FB923C naranja
        case .sleep: Color(red: 0.659, green: 0.333, blue: 0.969)    // #A855F7 purpura
        case .energy: Color(red: 0.984, green: 0.749, blue: 0.141)   // #FBBF24 ambar
        }
    }
}

struct DailyHealthSnapshot: Identifiable {
    let id: UUID
    let date: Date
    let hrv: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
    let activeEnergy: Double?
    let steps: Int?
    let respiratoryRate: Double?
    let workoutMinutes: Double?
    let vo2Max: Double?
    let vo2MaxDate: Date?
    let oxygenSaturation: Double?
    /// Temperatura de muneca durante el sueno (`appleSleepingWristTemperature`).
    /// Apple SOLO la mide dormido: no existe lectura diurna continua.
    let wristTemperature: Double?
    let daylightMinutes: Double?
    let mindfulMinutes: Double?
    let dietaryWaterLiters: Double?
    let dietaryCaffeineMg: Double?
    let dietaryAlcoholGrams: Double?
    let bodyMassKg: Double?
    let bodyFatPercentage: Double?
    let leanBodyMassKg: Double?
    let systolicBloodPressure: Double?
    let diastolicBloodPressure: Double?
    let sleepDetails: SleepSummary?
    let workouts: [WorkoutSummary]
    let sourceNames: [String]
    let qualityIssues: Set<DataQualityIssue>
    let timeZoneIdentifier: String

    init(
        id: UUID = UUID(),
        date: Date,
        hrv: Double?,
        restingHeartRate: Double?,
        sleepHours: Double?,
        activeEnergy: Double?,
        steps: Int?,
        respiratoryRate: Double?,
        workoutMinutes: Double?,
        vo2Max: Double? = nil,
        vo2MaxDate: Date? = nil,
        oxygenSaturation: Double? = nil,
        wristTemperature: Double? = nil,
        daylightMinutes: Double? = nil,
        mindfulMinutes: Double? = nil,
        dietaryWaterLiters: Double? = nil,
        dietaryCaffeineMg: Double? = nil,
        dietaryAlcoholGrams: Double? = nil,
        bodyMassKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        leanBodyMassKg: Double? = nil,
        systolicBloodPressure: Double? = nil,
        diastolicBloodPressure: Double? = nil,
        sleepDetails: SleepSummary? = nil,
        workouts: [WorkoutSummary] = [],
        sourceNames: [String] = [],
        qualityIssues: Set<DataQualityIssue> = [],
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.date = date
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.activeEnergy = activeEnergy
        self.steps = steps
        self.respiratoryRate = respiratoryRate
        self.workoutMinutes = workoutMinutes
        self.vo2Max = vo2Max
        self.vo2MaxDate = vo2MaxDate
        self.oxygenSaturation = oxygenSaturation
        self.wristTemperature = wristTemperature
        self.daylightMinutes = daylightMinutes
        self.mindfulMinutes = mindfulMinutes
        self.dietaryWaterLiters = dietaryWaterLiters
        self.dietaryCaffeineMg = dietaryCaffeineMg
        self.dietaryAlcoholGrams = dietaryAlcoholGrams
        self.bodyMassKg = bodyMassKg
        self.bodyFatPercentage = bodyFatPercentage
        self.leanBodyMassKg = leanBodyMassKg
        self.systolicBloodPressure = systolicBloodPressure
        self.diastolicBloodPressure = diastolicBloodPressure
        self.sleepDetails = sleepDetails
        self.workouts = workouts
        self.sourceNames = sourceNames
        self.qualityIssues = qualityIssues
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var availableSignalCount: Int {
        [hrv, restingHeartRate, sleepHours, activeEnergy, respiratoryRate, workoutMinutes, vo2Max]
            .compactMap { $0 }
            .count + (steps == nil ? 0 : 1)
    }

    private static var demoSleepStart: Date {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        return calendar.date(bySettingHour: 23, minute: 12, second: 0, of: yesterday) ?? yesterday
    }

    private static var demoSleepEnd: Date {
        Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now) ?? .now
    }

    static let demo = DailyHealthSnapshot(
        date: .now,
        hrv: 58,
        restingHeartRate: 53,
        sleepHours: 7.7,
        activeEnergy: 684,
        steps: 9_420,
        respiratoryRate: 14.2,
        workoutMinutes: 52,
        vo2Max: 46.5,
        vo2MaxDate: .now,
        oxygenSaturation: 0.972,
        wristTemperature: 36.4,
        daylightMinutes: 47,
        mindfulMinutes: 12,
        dietaryWaterLiters: 2.1,
        dietaryCaffeineMg: 118,
        dietaryAlcoholGrams: 0,
        bodyMassKg: 68.4,
        bodyFatPercentage: 0.214,
        leanBodyMassKg: 53.8,
        systolicBloodPressure: 116,
        diastolicBloodPressure: 74,
        sleepDetails: SleepSummary(
            startDate: demoSleepStart,
            endDate: demoSleepEnd,
            inBedHours: 8.0,
            asleepHours: 7.7,
            coreHours: 4.7,
            deepHours: 1.2,
            remHours: 1.8,
            awakeHours: 0.3,
            unspecifiedHours: 0,
            napHours: 0,
            latencyMinutes: 14,
            consistencyMinutes: 32,
            sourceName: "Apple Watch · demo"
        ),
        workouts: [
            WorkoutSummary(
                id: UUID(),
                startDate: Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now,
                endDate: Calendar.current.date(byAdding: .minute, value: -188, to: .now) ?? .now,
                activityName: "Carrera",
                durationMinutes: 52,
                activeEnergy: 486,
                averageHeartRate: 148,
                maximumHeartRate: 181,
                heartRateRecoveryOneMinute: 31,
                zones: [
                    HeartRateZoneDuration(zone: 1, minutes: 4),
                    HeartRateZoneDuration(zone: 2, minutes: 13),
                    HeartRateZoneDuration(zone: 3, minutes: 18),
                    HeartRateZoneDuration(zone: 4, minutes: 12),
                    HeartRateZoneDuration(zone: 5, minutes: 5)
                ],
                cardiovascularLoad: 15.1,
                sourceName: "Apple Watch · demo"
            )
        ],
        sourceNames: ["Apple Watch · demo"]
    )

    static let empty = DailyHealthSnapshot(
        date: .now,
        hrv: nil,
        restingHeartRate: nil,
        sleepHours: nil,
        activeEnergy: nil,
        steps: nil,
        respiratoryRate: nil,
        workoutMinutes: nil,
        qualityIssues: [.insufficientHistory]
    )

    static var demoWeek: [DailyHealthSnapshot] {
        let calendar = Calendar.current
        let values: [(Double, Double, Double, Double)] = [
            (6.4, 41, 48, 420), (7.1, 55, 54, 610), (7.5, 62, 51, 740),
            (6.8, 48, 56, 520), (8.0, 68, 50, 810), (7.3, 59, 52, 690),
            (7.7, 58, 53, 684)
        ]
        return values.enumerated().map { index, value in
            let date = calendar.date(byAdding: .day, value: index - 6, to: .now) ?? .now
            let bedtime = calendar.date(bySettingHour: 22 + (index % 2), minute: 8 + index * 3, second: 0, of: date) ?? date
            let sleepEnd = bedtime.addingTimeInterval((value.0 + 0.35) * 3600)
            return DailyHealthSnapshot(
                date: date,
                hrv: value.1,
                restingHeartRate: value.2,
                sleepHours: value.0,
                activeEnergy: value.3,
                steps: 6_200 + index * 520,
                respiratoryRate: 14.2,
                workoutMinutes: 28 + Double(index * 4),
                vo2Max: 44.7 + Double(index) * 0.3,
                vo2MaxDate: date,
                oxygenSaturation: 0.965 + Double(index) * 0.002,
                wristTemperature: 36.2 + Double(index % 3) * 0.08,
                daylightMinutes: 25 + Double(index * 9),
                mindfulMinutes: index % 2 == 0 ? 8 : nil,
                dietaryWaterLiters: 1.6 + Double(index) * 0.1,
                dietaryCaffeineMg: index == 6 ? 118 : Double(40 + index * 15),
                sleepDetails: SleepSummary(
                    startDate: bedtime,
                    endDate: sleepEnd,
                    inBedHours: value.0 + 0.35,
                    asleepHours: value.0,
                    coreHours: value.0 * 0.60,
                    deepHours: value.0 * (0.14 + Double(index % 3) * 0.012),
                    remHours: value.0 * (0.21 - Double(index % 2) * 0.01),
                    awakeHours: 0.35,
                    unspecifiedHours: value.0 * 0.05,
                    napHours: index == 3 ? 0.35 : 0,
                    latencyMinutes: Double(11 + index * 2),
                    consistencyMinutes: Double(20 + abs(3 - index) * 8),
                    sourceName: "Apple Watch · demo"
                ),
                sourceNames: ["Apple Watch · demo"]
            )
        }
    }

    func replacingSleepDetails(_ details: SleepSummary?) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            id: id,
            date: date,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: details.map { $0.asleepHours + $0.napHours } ?? sleepHours,
            activeEnergy: activeEnergy,
            steps: steps,
            respiratoryRate: respiratoryRate,
            workoutMinutes: workoutMinutes,
            vo2Max: vo2Max,
            vo2MaxDate: vo2MaxDate,
            oxygenSaturation: oxygenSaturation,
            wristTemperature: wristTemperature,
            daylightMinutes: daylightMinutes,
            mindfulMinutes: mindfulMinutes,
            dietaryWaterLiters: dietaryWaterLiters,
            dietaryCaffeineMg: dietaryCaffeineMg,
            dietaryAlcoholGrams: dietaryAlcoholGrams,
            bodyMassKg: bodyMassKg,
            bodyFatPercentage: bodyFatPercentage,
            leanBodyMassKg: leanBodyMassKg,
            systolicBloodPressure: systolicBloodPressure,
            diastolicBloodPressure: diastolicBloodPressure,
            sleepDetails: details,
            workouts: workouts,
            sourceNames: sourceNames,
            qualityIssues: qualityIssues,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    func replacingVO2(value: Double?, date: Date?, sourceName: String?) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            id: id,
            date: self.date,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            activeEnergy: activeEnergy,
            steps: steps,
            respiratoryRate: respiratoryRate,
            workoutMinutes: workoutMinutes,
            vo2Max: value,
            vo2MaxDate: date,
            oxygenSaturation: oxygenSaturation,
            wristTemperature: wristTemperature,
            daylightMinutes: daylightMinutes,
            mindfulMinutes: mindfulMinutes,
            dietaryWaterLiters: dietaryWaterLiters,
            dietaryCaffeineMg: dietaryCaffeineMg,
            dietaryAlcoholGrams: dietaryAlcoholGrams,
            bodyMassKg: bodyMassKg,
            bodyFatPercentage: bodyFatPercentage,
            leanBodyMassKg: leanBodyMassKg,
            systolicBloodPressure: systolicBloodPressure,
            diastolicBloodPressure: diastolicBloodPressure,
            sleepDetails: sleepDetails,
            workouts: workouts,
            sourceNames: sourceName.map { Array(Set(sourceNames + [$0])).sorted() } ?? sourceNames,
            qualityIssues: qualityIssues,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}

struct WellnessScore: Identifiable {
    let kind: ScoreKind
    let value: Int
    let confidence: DataConfidence
    let summary: String

    var id: ScoreKind { kind }
}

struct NutritionEstimate {
    let title: String
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
    let confidence: DataConfidence
    let kcalLower: Int
    let kcalUpper: Int
    let uncertainties: [String]
    let source: String

    init(
        title: String,
        calories: Int,
        protein: Int,
        carbohydrates: Int,
        fat: Int,
        confidence: DataConfidence,
        kcalLower: Int? = nil,
        kcalUpper: Int? = nil,
        uncertainties: [String] = [],
        source: String = "text"
    ) {
        self.title = title
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.confidence = confidence
        let spread = confidence == .high ? 0.12 : confidence == .medium ? 0.22 : 0.32
        self.kcalLower = kcalLower ?? max(Int(Double(calories) * (1 - spread)), 0)
        self.kcalUpper = kcalUpper ?? Int(Double(calories) * (1 + spread))
        self.uncertainties = uncertainties
        self.source = source
    }
}

enum NutritionGoal: String, CaseIterable, Identifiable {
    case loseFat = "Perder grasa"
    case maintain = "Mantener"
    case gainMuscle = "Ganar musculo"
    case improveEnergy = "Mejorar energia"
    case eatMoreProtein = "Comer mas proteina"

    var id: String { rawValue }
}

enum WeeklyWorkoutRange: String, CaseIterable, Identifiable {
    case low = "0-2"
    case medium = "3-5"
    case high = "6+"

    var id: String { rawValue }
}

enum NutritionSex: String, CaseIterable, Identifiable {
    case unspecified = "Prefiero no decir"
    case female = "Mujer"
    case male = "Hombre"

    var id: String { rawValue }
}

enum DietStyle: String, CaseIterable, Identifiable {
    case flexible = "Flexible"
    case vegetarian = "Vegetariana"
    case vegan = "Vegana"
    case lowCarb = "Baja en carbohidratos"
    case mediterranean = "Mediterranea"

    var id: String { rawValue }
}

enum PreferredUnits: String, CaseIterable, Identifiable {
    case metric = "Metrico"
    case imperial = "Imperial"

    var id: String { rawValue }
}

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Desayuno"
    case lunch = "Comida"
    case dinner = "Cena"
    case snack = "Snack"

    var id: String { rawValue }
}

struct NutritionTargets: Equatable {
    let calories: Int
    let calorieLower: Int
    let calorieUpper: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
}

struct NutritionHealthContext: Equatable {
    let recovery: Int?
    let sleep: Int?
    let strain: Int?
    let plannedWorkout: Bool

    static let empty = NutritionHealthContext(
        recovery: nil,
        sleep: nil,
        strain: nil,
        plannedWorkout: false
    )
}

struct NutritionPlanSuggestion: Identifiable, Equatable {
    let id: String
    let mealType: MealType
    let title: String
    let detail: String
    let reason: String
}

struct NutritionDayPlan: Equatable {
    let status: String
    let nextMeal: NutritionPlanSuggestion
    let tomorrow: [NutritionPlanSuggestion]
    let tomorrowReason: String
}

struct ActivationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum PhysiologicalStressLevel: String, CaseIterable {
    case great = "Excelente"
    case normal = "Normal"
    case attention = "Atencion"
    case overload = "Sobrecarga"
    case unavailable = "Sin datos"
}

struct StressDriver: Identifiable, Equatable {
    let name: String
    let value: String
    let baseline: String
    let impact: Double

    var id: String { name }
}

struct StressAssessment: Equatable {
    let score: Int?
    let level: PhysiologicalStressLevel
    let confidence: DataConfidence
    let summary: String
    let drivers: [StressDriver]
    let baselineDays: Int
}

/// Capa de presentacion del stress: el motor calcula un indice donde
/// mas bajo = mas relajado; la UI muestra un "calm score" invertido
/// (100 = Excelente, anillo lleno = bien) para que la lectura sea
/// consistente con Recovery/Sleep. El motor interno NO cambia.
struct StressPresentation: Equatable {
    let calmScore: Int?
    let displayValue: String
    let ringProgress: Double
    let headline: String
}

/// Intensidad de una barra horaria de activacion (valor 0...3 de ActivationPoint).
enum StressBarIntensity: Equatable {
    case low, medium, high
}

/// Hint de posible factor asociado al stress del dia. Solo cruza datos
/// registrados por el usuario (Journal/EmotionLog) y senales fisiologicas;
/// nunca infiere emociones desde HRV (regla README_StressAndBio 3.2).
struct StressHint: Identifiable, Equatable {
    enum Kind: String {
        case habit, sleep, emotion, positive
    }

    let id: String
    let icon: String
    let text: String
    let microAction: String?
    let kind: Kind
    let offersBreathing: Bool
}

/// Emociones auto-reportadas para el log de la pantalla de stress.
/// Patron similar a FastingMood pero independiente del ayuno.
enum StressEmotion: String, CaseIterable, Identifiable {
    case calm, content, motivated, anxious, worried, irritable, exhausted

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm: "😌"
        case .content: "🙂"
        case .motivated: "💪"
        case .anxious: "😰"
        case .worried: "😟"
        case .irritable: "😤"
        case .exhausted: "😩"
        }
    }

    var label: String {
        switch self {
        case .calm: "Tranquilo"
        case .content: "Contento"
        case .motivated: "Motivado"
        case .anxious: "Ansioso"
        case .worried: "Preocupado"
        case .irritable: "Irritable"
        case .exhausted: "Agotado"
        }
    }

    /// Emociones de tension: los hints las reflejan con gentileza.
    var isTense: Bool {
        self == .anxious || self == .worried || self == .irritable || self == .exhausted
    }

    /// Valencia para graficas (-2 ... +2). Solo autoconocimiento, no diagnostico.
    var valence: Double {
        switch self {
        case .motivated: 2
        case .calm, .content: 1
        case .anxious, .worried: -1
        case .irritable, .exhausted: -2
        }
    }
}

/// Tope suave de check-ins de emocion / feeling por dia o sesion (Daylio ilimitado;
/// guias tipicas 2-3/dia; MindDoc ~3). Seis cubre manana/tarde/noche + extras.
enum CheckInLimits {
    static let maxPerDay = 6
}

struct BioAgeFactor: Identifiable, Equatable {
    let name: String
    let value: String
    let note: String
    let favorable: Bool?

    var id: String { name }
}

struct BioAgeEstimate: Equatable {
    let chronologicalYears: Int?
    let estimatedYears: Double?
    let confidence: DataConfidence
    let summary: String
    let factors: [BioAgeFactor]

    var deltaYears: Double? {
        guard let chronologicalYears, let estimatedYears else { return nil }
        return estimatedYears - Double(chronologicalYears)
    }
}

struct DailyBrief {
    let sleepNeedHours: Double
    let sleepDebtHours: Double
    let bedtime: Date
    let currentLoad: Double
    let targetLoad: Double
    let focusTitle: String
    let focusDetail: String
    /// Ciclos sugeridos (~90 min) mas cercanos a `sleepNeedHours`; heuristica, no clinico.
    let suggestedSleepCycles: Int
    let suggestedCycleCaption: String

    var remainingLoad: Double { max(targetLoad - currentLoad, 0) }
}

struct RecoveryFactor: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let baseline: String?
    let contribution: Double
    let icon: String
}

@Model
final class MealLog {
    var createdAt: Date
    var title: String
    var calories: Int
    var protein: Int
    var carbohydrates: Int
    var fat: Int
    var source: String
    var mealType: String?
    var confidence: String?
    var kcalLower: Int?
    var kcalUpper: Int?
    var notes: String?

    init(
        createdAt: Date = .now,
        title: String,
        calories: Int,
        protein: Int,
        carbohydrates: Int,
        fat: Int,
        source: String = "text",
        mealType: String? = nil,
        confidence: String? = nil,
        kcalLower: Int? = nil,
        kcalUpper: Int? = nil,
        notes: String? = nil
    ) {
        self.createdAt = createdAt
        self.title = title
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.source = source
        self.mealType = mealType
        self.confidence = confidence
        self.kcalLower = kcalLower
        self.kcalUpper = kcalUpper
        self.notes = notes
    }
}

@Model
final class NutritionProfile {
    var id: UUID
    var birthDate: Date
    var heightCm: Double
    var weightKg: Double
    var sexOptional: String
    var goal: String
    var weeklyWorkouts: String
    var dietStyle: String
    var allergies: String
    var dislikedFoods: String
    var mealsPerDay: Int
    var preferredUnits: String
    var setupCompleted: Bool
    var updatedAt: Date

    init(
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
        heightCm: Double = 170,
        weightKg: Double = 70,
        sexOptional: String = NutritionSex.unspecified.rawValue,
        goal: String = NutritionGoal.maintain.rawValue,
        weeklyWorkouts: String = WeeklyWorkoutRange.medium.rawValue,
        dietStyle: String = DietStyle.flexible.rawValue,
        allergies: String = "",
        dislikedFoods: String = "",
        mealsPerDay: Int = 3,
        preferredUnits: String = PreferredUnits.metric.rawValue,
        setupCompleted: Bool = false
    ) {
        self.id = UUID()
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.sexOptional = sexOptional
        self.goal = goal
        self.weeklyWorkouts = weeklyWorkouts
        self.dietStyle = dietStyle
        self.allergies = allergies
        self.dislikedFoods = dislikedFoods
        self.mealsPerDay = mealsPerDay
        self.preferredUnits = preferredUnits
        self.setupCompleted = setupCompleted
        self.updatedAt = .now
    }
}

@Model
final class HabitLog {
    var id: UUID
    var date: Date
    var habit: String
    var answer: Bool
    /// Stable catalog identifier. Nil means a legacy record and is resolved by name.
    var tagID: String? = nil
    var numericValue: Double? = nil
    var unit: String? = nil
    var sourceRaw: String? = nil
    var periodRaw: String? = nil
    var note: String? = nil

    init(
        date: Date = .now,
        habit: String,
        answer: Bool,
        tagID: String? = nil,
        numericValue: Double? = nil,
        unit: String? = nil,
        sourceRaw: String? = nil,
        periodRaw: String? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.habit = habit
        self.answer = answer
        self.tagID = tagID
        self.numericValue = numericValue
        self.unit = unit
        self.sourceRaw = sourceRaw
        self.periodRaw = periodRaw
        self.note = note
    }
}

/// Paso de rutina previa al sueno (Plan → Esta noche). Local-first.
@Model
final class SleepRoutineStep {
    var id: UUID
    var title: String
    var iconName: String
    /// Duracion del paso en minutos. Los inicios se encadenan hacia atras desde la cama
    /// (`SleepWindDownScheduler.chainedOffsetsBeforeBed`); no es un offset absoluto fijo.
    var minutesBeforeBed: Int
    var sortOrder: Int
    var isEnabled: Bool
    var updatedAt: Date

    /// Alias claro: la UI edita duracion; el offset se deriva del encadenamiento.
    var durationMinutes: Int {
        get { minutesBeforeBed }
        set { minutesBeforeBed = max(newValue, 0) }
    }

    init(
        title: String,
        iconName: String = "moon.zzz.fill",
        minutesBeforeBed: Int = 15,
        sortOrder: Int = 0,
        isEnabled: Bool = true,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.iconName = iconName
        self.minutesBeforeBed = max(minutesBeforeBed, 0)
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.updatedAt = updatedAt
    }
}

/// Reflexion mental diaria (una entrada por dia calendario). Local-first.
@Model
final class MentalJournalEntry {
    var id: UUID
    var date: Date
    var wentWell: String
    var gratitude: String
    /// Accion o mejora dentro del control del usuario (inspiracion stoica).
    var improve: String
    var updatedAt: Date
    /// Campos opcionales para migracion ligera desde la reflexion diaria v1.
    var morningIntention: String? = nil
    var morningControl: String? = nil
    var eveningLesson: String? = nil
    var morningCompletedAt: Date? = nil
    var eveningCompletedAt: Date? = nil

    init(
        date: Date = .now,
        wentWell: String = "",
        gratitude: String = "",
        improve: String = "",
        morningIntention: String? = nil,
        morningControl: String? = nil,
        eveningLesson: String? = nil,
        morningCompletedAt: Date? = nil,
        eveningCompletedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.wentWell = wentWell
        self.gratitude = gratitude
        self.improve = improve
        self.morningIntention = morningIntention
        self.morningControl = morningControl
        self.eveningLesson = eveningLesson
        self.morningCompletedAt = morningCompletedAt
        self.eveningCompletedAt = eveningCompletedAt
        self.updatedAt = updatedAt
    }

    var hasMorningReflection: Bool {
        morningCompletedAt != nil
            || !(morningIntention ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(morningControl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasEveningReflection: Bool {
        eveningCompletedAt != nil
            || !wentWell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !gratitude.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !improve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(eveningLesson ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Recomendacion de sueno congelada para una noche concreta. Nunca se recalculan
/// noches pasadas con el plan actual.
@Model
final class PlannedSleepNight {
    var id: UUID
    /// Dia calendario en que comienza la noche (fecha de la hora de cama).
    var nightDate: Date
    var plannedBedtime: Date
    var plannedWakeTime: Date
    var targetAsleepHours: Double
    var cycleCount: Int
    var updatedAt: Date

    init(
        nightDate: Date,
        plannedBedtime: Date,
        plannedWakeTime: Date,
        targetAsleepHours: Double,
        cycleCount: Int,
        updatedAt: Date = .now
    ) {
        self.id = UUID()
        self.nightDate = Calendar.current.startOfDay(for: nightDate)
        self.plannedBedtime = plannedBedtime
        self.plannedWakeTime = plannedWakeTime
        self.targetAsleepHours = targetAsleepHours
        self.cycleCount = cycleCount
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyScoreRecord {
    var id: UUID
    var date: Date
    var recovery: Int
    var sleep: Int
    var strain: Int

    init(date: Date = .now, recovery: Int, sleep: Int, strain: Int) {
        self.id = UUID()
        self.date = date
        self.recovery = recovery
        self.sleep = sleep
        self.strain = strain
    }
}

@Model
final class EmotionLog {
    var id: UUID
    var date: Date
    var emotion: String
    var note: String
    /// Indice INTERNO del motor de stress al momento del registro
    /// (alto = mas presion), NO el calm score presentado. Se guarda crudo
    /// para que correlaciones futuras usen la senal fisiologica sin
    /// doble transformacion.
    var linkedStressScore: Int?

    init(date: Date = .now, emotion: String, note: String = "", linkedStressScore: Int? = nil) {
        self.id = UUID()
        self.date = date
        self.emotion = emotion
        self.note = note
        self.linkedStressScore = linkedStressScore
    }

    var stressEmotion: StressEmotion? {
        StressEmotion(rawValue: emotion)
    }
}

/// Check-in de feeling durante una sesion de ayuno (multi por sesion, tope 6).
@Model
final class FastingFeelingLog {
    var id: UUID
    var sessionId: UUID
    var date: Date
    var moodRaw: String
    var note: String

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        date: Date = .now,
        moodRaw: String,
        note: String = ""
    ) {
        self.id = id
        self.sessionId = sessionId
        self.date = date
        self.moodRaw = moodRaw
        self.note = note
    }

    var mood: FastingMood? {
        FastingMood(rawValue: moodRaw)
    }
}

@Model
final class FitnessActivityLog {
    var id: UUID
    var startDate: Date
    var activityName: String
    var category: String
    var durationMinutes: Double
    var perceivedEffort: Int
    var activeEnergy: Double?
    var totalVolumeKg: Double?
    var muscleGroup: String
    var notes: String

    init(
        startDate: Date = .now,
        activityName: String,
        category: String,
        durationMinutes: Double,
        perceivedEffort: Int,
        activeEnergy: Double? = nil,
        totalVolumeKg: Double? = nil,
        muscleGroup: String = "General",
        notes: String = ""
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.activityName = activityName
        self.category = category
        self.durationMinutes = durationMinutes
        self.perceivedEffort = perceivedEffort
        self.activeEnergy = activeEnergy
        self.totalVolumeKg = totalVolumeKg
        self.muscleGroup = muscleGroup
        self.notes = notes
    }
}

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var focus: String
    var exercisesText: String
    var createdAt: Date

    init(name: String, focus: String, exercisesText: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.focus = focus
        self.exercisesText = exercisesText
        self.createdAt = createdAt
    }

    var exerciseCount: Int {
        exercisesText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Detalle de metrica (patron Bevel `mainmetrics_bevel.mp4`)

/// Ventana temporal del grafico de detalle. Bevel usa 30D/3M/6M/1Y.
enum MetricWindow: String, CaseIterable, Identifiable {
    case month = "30D"
    case quarter = "3M"
    case half = "6M"
    case year = "1Y"
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .month: 30
        case .quarter: 90
        case .half: 180
        case .year: 365
        }
    }
}

/// Un punto de una serie de metrica.
struct MetricPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Fila de "Trends Analysis": cuanto cambio la metrica en una ventana.
struct MetricTrendRow: Identifiable, Equatable {
    /// 3, 7, 14, 30 o 90 dias.
    let days: Int
    /// Cambio vs el periodo anterior, en unidades de la metrica.
    let change: Double?
    /// Serie corta para el sparkline de la fila.
    let points: [Double]
    var id: Int { days }
    var label: String { "\(days) dias" }
}

/// Direccion de un cambio, interpretada con `higherIsBetter` de la metrica.
enum MetricTrendDirection {
    case improving, declining, steady, unknown
}

/// Recurso educativo (las tarjetas "Resources" de Bevel).
struct MetricResource: Identifiable, Equatable {
    let title: String
    let subtitle: String
    let symbol: String
    /// Cuerpo del articulo. Recvel lo escribe con evidencia citada.
    let body: String
    var id: String { title }
}

extension MetricDescriptor {
    /// Fallback defensivo para un catalogo vacio (no deberia ocurrir).
    static let unavailable = MetricDescriptor(
        key: "unavailable",
        title: "Sin datos",
        symbol: "questionmark.circle",
        unit: "",
        decimals: 0,
        higherIsBetter: true,
        color: .secondary,
        explanation: "No hay una metrica seleccionada.",
        resources: []
    )
}

/// Descriptor completo de una metrica para `MetricDetailView`.
/// `siblings` son las metricas hermanas navegables con los chips superiores.
struct MetricDescriptor: Identifiable, Equatable {
    let key: String
    let title: String
    let symbol: String
    let unit: String
    let decimals: Int
    let higherIsBetter: Bool
    let color: Color
    /// Explicacion honesta de que mide y que no.
    let explanation: String
    let resources: [MetricResource]
    var id: String { key }

    static func == (lhs: MetricDescriptor, rhs: MetricDescriptor) -> Bool { lhs.key == rhs.key }
}

// MARK: - Respiracion guiada

/// Una fase de un ciclo respiratorio.
struct BreathPhase: Equatable {
    enum Kind: String {
        case inhale = "Inhala"
        case inhaleTop = "Inhala otro poco"
        case hold = "Manten"
        case exhale = "Exhala"
        case holdEmpty = "Manten vacio"
    }
    let kind: Kind
    let seconds: Double
    /// Escala del circulo guia al terminar esta fase.
    let scale: Double
}

/// Tecnicas de respiracion guiada, cada una con su evidencia.
///
/// El orden refleja la fuerza de la evidencia: `cyclicSigh` primero porque es
/// la unica con un ensayo aleatorizado que la comparo de frente contra
/// meditacion mindfulness y la supero (Balban et al., Cell Rep Med 2023).
enum BreathingTechnique: String, CaseIterable, Identifiable {
    case cyclicSigh = "Suspiro ciclico"
    case resonance = "Resonancia"
    case box = "Cuadrada"
    case relaxing = "4-7-8"
    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .cyclicSigh: "Doble inhalacion, exhalacion larga"
        case .resonance: "6 respiraciones por minuto"
        case .box: "4-4-4-4"
        case .relaxing: "Exhalacion extendida"
        }
    }

    var symbol: String {
        switch self {
        case .cyclicSigh: "wind"
        case .resonance: "waveform.path"
        case .box: "square"
        case .relaxing: "moon.zzz"
        }
    }

    /// Un ciclo completo de la tecnica.
    var cycle: [BreathPhase] {
        switch self {
        case .cyclicSigh:
            [
                BreathPhase(kind: .inhale, seconds: 2, scale: 1.18),
                BreathPhase(kind: .inhaleTop, seconds: 1, scale: 1.34),
                BreathPhase(kind: .exhale, seconds: 5, scale: 0.80)
            ]
        case .resonance:
            [
                BreathPhase(kind: .inhale, seconds: 5, scale: 1.30),
                BreathPhase(kind: .exhale, seconds: 5, scale: 0.80)
            ]
        case .box:
            [
                BreathPhase(kind: .inhale, seconds: 4, scale: 1.30),
                BreathPhase(kind: .hold, seconds: 4, scale: 1.30),
                BreathPhase(kind: .exhale, seconds: 4, scale: 0.80),
                BreathPhase(kind: .holdEmpty, seconds: 4, scale: 0.80)
            ]
        case .relaxing:
            [
                BreathPhase(kind: .inhale, seconds: 4, scale: 1.30),
                BreathPhase(kind: .hold, seconds: 7, scale: 1.30),
                BreathPhase(kind: .exhale, seconds: 8, scale: 0.78)
            ]
        }
    }

    var explanation: String {
        switch self {
        case .cyclicSigh:
            "Dos inhalaciones seguidas por la nariz y una exhalacion larga por la boca. Reinfla los alveolos colapsados y descarga CO2 de forma eficiente."
        case .resonance:
            "Respirar a unas 6 veces por minuto sincroniza el ritmo cardiaco con la respiracion y maximiza la arritmia sinusal respiratoria."
        case .box:
            "Cuatro fases iguales. Usada en entrenamiento militar por su simplicidad para sostener la atencion bajo presion."
        case .relaxing:
            "Exhalacion mas larga que la inhalacion. La exhalacion prolongada favorece el tono parasimpatico."
        }
    }

    /// Evidencia citada. La UI SIEMPRE la muestra: no proponemos una tecnica
    /// sin decir que la respalda y con que fuerza.
    var evidence: String {
        switch self {
        case .cyclicSigh:
            "Es la tecnica con mejor evidencia directa. En un ensayo aleatorizado de Stanford con 111 adultos durante 28 dias (5 min diarios), el suspiro ciclico produjo la mayor mejora diaria del animo positivo y la mayor reduccion de la frecuencia respiratoria en reposo, superando a la meditacion mindfulness y a las otras tecnicas de respiracion (Balban et al., Cell Reports Medicine 2023)."
        case .resonance:
            "Respirar cerca de 6 respiraciones por minuto (la 'frecuencia de resonancia') maximiza la amplitud de la arritmia sinusal respiratoria y la HRV a corto plazo. La evidencia sobre su efecto sostenido en ansiedad es prometedora pero mas limitada que la del suspiro ciclico (Lehrer & Gevirtz, Front Psychol 2014)."
        case .box:
            "Muy difundida por su uso en entrenamiento militar, pero su evidencia especifica es mas debil: en el mismo ensayo de Stanford mejoro el animo menos que el suspiro ciclico. Su ventaja real es la simplicidad y la facilidad para sostener la atencion."
        case .relaxing:
            "La exhalacion prolongada se asocia con activacion parasimpatica, pero los estudios especificos de la pauta 4-7-8 son pequenos y de baja calidad metodologica. Uselo si le resulta comodo, sin esperar el efecto documentado del suspiro ciclico."
        }
    }

    /// Fuerza de la evidencia, para no vender todas por igual.
    var evidenceStrength: String {
        switch self {
        case .cyclicSigh: "Ensayo aleatorizado"
        case .resonance: "Evidencia moderada"
        case .box: "Evidencia limitada"
        case .relaxing: "Evidencia preliminar"
        }
    }
}
