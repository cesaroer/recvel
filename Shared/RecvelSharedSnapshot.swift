import Foundation

struct RecvelSharedSnapshot: Codable, Hashable {
    static let schemaVersion = 2

    let version: Int
    let updatedAt: Date
    let languageCode: String
    let dataModeID: String
    let recovery: Int?
    let strain: Int?
    let sleep: Int?
    let energy: Int?
    let stressCalm: Int?
    let stressLevelID: String
    let hrvMilliseconds: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
    let steps: Int?
    let activeEnergy: Double?
    let workoutMinutes: Double?
    let vo2Max: Double?
    let confidenceID: String
    let nextActionID: String

    var displayLanguage: AppLanguage { AppLanguage(rawValue: languageCode) ?? .system }
    var dataMode: String { RecvelL10n.text(dataModeID, language: displayLanguage) }
    var stressLabel: String { RecvelL10n.text(stressLevelID, language: displayLanguage) }
    var confidence: String { RecvelL10n.text(confidenceID, language: displayLanguage) }
    var nextAction: String { RecvelL10n.text(nextActionID, language: displayLanguage) }

    init(
        version: Int = schemaVersion,
        updatedAt: Date = .now,
        language: AppLanguage = RecvelLanguageStore.load(),
        dataModeID: String,
        recovery: Int?,
        strain: Int?,
        sleep: Int?,
        energy: Int?,
        stressCalm: Int?,
        stressLevelID: String,
        hrvMilliseconds: Double?,
        restingHeartRate: Double?,
        sleepHours: Double?,
        steps: Int?,
        activeEnergy: Double?,
        workoutMinutes: Double?,
        vo2Max: Double?,
        confidenceID: String,
        nextActionID: String
    ) {
        self.version = version
        self.updatedAt = updatedAt
        languageCode = language.rawValue
        self.dataModeID = dataModeID
        self.recovery = recovery
        self.strain = strain
        self.sleep = sleep
        self.energy = energy
        self.stressCalm = stressCalm
        self.stressLevelID = stressLevelID
        self.hrvMilliseconds = hrvMilliseconds
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.workoutMinutes = workoutMinutes
        self.vo2Max = vo2Max
        self.confidenceID = confidenceID
        self.nextActionID = nextActionID
    }

    func updatingLanguage(_ language: AppLanguage) -> RecvelSharedSnapshot {
        RecvelSharedSnapshot(
            updatedAt: updatedAt,
            language: language,
            dataModeID: dataModeID,
            recovery: recovery,
            strain: strain,
            sleep: sleep,
            energy: energy,
            stressCalm: stressCalm,
            stressLevelID: stressLevelID,
            hrvMilliseconds: hrvMilliseconds,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            steps: steps,
            activeEnergy: activeEnergy,
            workoutMinutes: workoutMinutes,
            vo2Max: vo2Max,
            confidenceID: confidenceID,
            nextActionID: nextActionID
        )
    }

    static let placeholder = RecvelSharedSnapshot(
        dataModeID: "shared.waiting",
        recovery: nil,
        strain: nil,
        sleep: nil,
        energy: nil,
        stressCalm: nil,
        stressLevelID: "common.calibrating",
        hrvMilliseconds: nil,
        restingHeartRate: nil,
        sleepHours: nil,
        steps: nil,
        activeEnergy: nil,
        workoutMinutes: nil,
        vo2Max: nil,
        confidenceID: "common.low",
        nextActionID: "shared.openToRefresh"
    )

    static let preview = RecvelSharedSnapshot(
        dataModeID: "common.appleHealth",
        recovery: 82,
        strain: 64,
        sleep: 88,
        energy: 76,
        stressCalm: 71,
        stressLevelID: "stress.level.normal",
        hrvMilliseconds: 58,
        restingHeartRate: 53,
        sleepHours: 7.7,
        steps: 9_420,
        activeEnergy: 684,
        workoutMinutes: 52,
        vo2Max: 46.5,
        confidenceID: "common.high",
        nextActionID: "shared.preview.action"
    )

    private enum CodingKeys: String, CodingKey {
        case version, updatedAt, languageCode, dataModeID, recovery, strain, sleep, energy
        case stressCalm, stressLevelID, hrvMilliseconds, restingHeartRate, sleepHours
        case steps, activeEnergy, workoutMinutes, vo2Max, confidenceID, nextActionID
        case dataMode, stressLabel, confidence, nextAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        version = Self.schemaVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? AppLanguage.system.rawValue
        recovery = try container.decodeIfPresent(Int.self, forKey: .recovery)
        strain = try container.decodeIfPresent(Int.self, forKey: .strain)
        sleep = try container.decodeIfPresent(Int.self, forKey: .sleep)
        energy = try container.decodeIfPresent(Int.self, forKey: .energy)
        stressCalm = try container.decodeIfPresent(Int.self, forKey: .stressCalm)
        hrvMilliseconds = try container.decodeIfPresent(Double.self, forKey: .hrvMilliseconds)
        restingHeartRate = try container.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        sleepHours = try container.decodeIfPresent(Double.self, forKey: .sleepHours)
        steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        activeEnergy = try container.decodeIfPresent(Double.self, forKey: .activeEnergy)
        workoutMinutes = try container.decodeIfPresent(Double.self, forKey: .workoutMinutes)
        vo2Max = try container.decodeIfPresent(Double.self, forKey: .vo2Max)

        if storedVersion >= Self.schemaVersion {
            dataModeID = try container.decode(String.self, forKey: .dataModeID)
            stressLevelID = try container.decode(String.self, forKey: .stressLevelID)
            confidenceID = try container.decode(String.self, forKey: .confidenceID)
            nextActionID = try container.decode(String.self, forKey: .nextActionID)
        } else {
            dataModeID = Self.legacyDataModeID(try container.decodeIfPresent(String.self, forKey: .dataMode))
            stressLevelID = Self.legacyStressID(try container.decodeIfPresent(String.self, forKey: .stressLabel))
            confidenceID = Self.legacyConfidenceID(try container.decodeIfPresent(String.self, forKey: .confidence))
            nextActionID = Self.legacyActionID(try container.decodeIfPresent(String.self, forKey: .nextAction))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .version)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(dataModeID, forKey: .dataModeID)
        try container.encodeIfPresent(recovery, forKey: .recovery)
        try container.encodeIfPresent(strain, forKey: .strain)
        try container.encodeIfPresent(sleep, forKey: .sleep)
        try container.encodeIfPresent(energy, forKey: .energy)
        try container.encodeIfPresent(stressCalm, forKey: .stressCalm)
        try container.encode(stressLevelID, forKey: .stressLevelID)
        try container.encodeIfPresent(hrvMilliseconds, forKey: .hrvMilliseconds)
        try container.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)
        try container.encodeIfPresent(sleepHours, forKey: .sleepHours)
        try container.encodeIfPresent(steps, forKey: .steps)
        try container.encodeIfPresent(activeEnergy, forKey: .activeEnergy)
        try container.encodeIfPresent(workoutMinutes, forKey: .workoutMinutes)
        try container.encodeIfPresent(vo2Max, forKey: .vo2Max)
        try container.encode(confidenceID, forKey: .confidenceID)
        try container.encode(nextActionID, forKey: .nextActionID)
    }

    private static func legacyDataModeID(_ value: String?) -> String {
        switch value {
        case "Apple Health": "common.appleHealth"
        case "Demo": "common.demoData"
        case "Datos parciales": "common.partialData"
        case "Creando baseline": "dataMode.buildingReference"
        case "Sin datos": "common.noData"
        default: "shared.waiting"
        }
    }

    private static func legacyStressID(_ value: String?) -> String {
        switch value {
        case "Excelente": "stress.level.great"
        case "Normal": "stress.level.normal"
        case "Atencion": "stress.level.attention"
        case "Sobrecarga": "stress.level.overload"
        default: "common.calibrating"
        }
    }

    private static func legacyConfidenceID(_ value: String?) -> String {
        switch value {
        case "Alta": "common.high"
        case "Media": "common.medium"
        default: "common.low"
        }
    }

    private static func legacyActionID(_ value: String?) -> String {
        switch value {
        case "Protege tu ventana de sueno esta noche.": "shared.action.sleep"
        case "Prioriza movimiento suave y recuperacion.": "shared.action.recovery"
        case "Tus senales admiten una sesion de calidad.": "shared.action.training"
        case "Buen dia para una sesion moderada.": "shared.preview.action"
        case "Abre Recvel para actualizar Apple Health.": "shared.openToRefresh"
        default: "shared.action.steady"
        }
    }
}

enum RecvelSharedSnapshotStore {
    static let appGroupIdentifier = "group.com.recvel.shared"
    static let snapshotKey = "recvel.shared.healthSnapshot.v1"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save(_ snapshot: RecvelSharedSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupIdentifier)?.set(data, forKey: snapshotKey)
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }

    static func load() -> RecvelSharedSnapshot {
        let sharedData = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: snapshotKey)
        let localData = UserDefaults.standard.data(forKey: snapshotKey)
        guard let data = sharedData ?? localData,
              let snapshot = try? decoder.decode(RecvelSharedSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    static func encoded(_ snapshot: RecvelSharedSnapshot) -> Data? {
        try? encoder.encode(snapshot)
    }

    static func decoded(_ data: Data) -> RecvelSharedSnapshot? {
        try? decoder.decode(RecvelSharedSnapshot.self, from: data)
    }
}
