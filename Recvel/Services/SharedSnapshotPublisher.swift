import Foundation
import WidgetKit

@MainActor
enum SharedSnapshotPublisher {
    static func publish(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        dataMode: HealthDataMode
    ) {
        guard snapshot.availableSignalCount > 0 else {
            RecvelSharedSnapshotStore.save(.placeholder)
            WidgetCenter.shared.reloadAllTimelines()
            WatchSyncManager.shared.send(.placeholder)
            return
        }
        let scores = ScoreEngine().scores(for: snapshot, history: history)
        let score: (ScoreKind) -> WellnessScore? = { kind in scores.first { $0.kind == kind } }
        let stress = StressEngine().assess(snapshot: snapshot, history: history)
        // Estres directo (alto = presion), misma escala que la app.
        let confidence = scores.map(\.confidence).min(by: { confidenceRank($0) < confidenceRank($1) }) ?? .low

        let shared = RecvelSharedSnapshot(
            dataModeID: dataMode.localizationID,
            recovery: score(.recovery)?.value,
            strain: score(.strain)?.value,
            sleep: score(.sleep)?.value,
            energy: score(.energy)?.value,
            stressScore: stress.score,
            stressLevelID: stress.level.localizationID,
            hrvMilliseconds: snapshot.hrv,
            restingHeartRate: snapshot.restingHeartRate,
            sleepHours: snapshot.sleepHours,
            steps: snapshot.steps,
            activeEnergy: snapshot.activeEnergy,
            workoutMinutes: snapshot.workoutMinutes,
            vo2Max: snapshot.vo2Max,
            confidenceID: confidence.localizationID,
            nextActionID: nextActionID(scores: scores, snapshot: snapshot)
        )

        RecvelSharedSnapshotStore.save(shared)
        WidgetCenter.shared.reloadAllTimelines()
        WatchSyncManager.shared.send(shared)
    }

    private static func confidenceRank(_ confidence: DataConfidence) -> Int {
        switch confidence {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    private static func nextActionID(scores: [WellnessScore], snapshot: DailyHealthSnapshot) -> String {
        let recovery = scores.first { $0.kind == .recovery }?.value ?? 0
        let sleep = scores.first { $0.kind == .sleep }?.value ?? 0
        if sleep < 60 { return "shared.action.sleep" }
        if recovery < 45 { return "shared.action.recovery" }
        if (snapshot.workoutMinutes ?? 0) < 10 && recovery >= 70 {
            return "shared.action.training"
        }
        return "shared.action.steady"
    }
}

private extension HealthDataMode {
    var localizationID: String {
        switch self {
        case .empty: "common.noData"
        case .demo: "common.demoData"
        case .buildingBaseline: "dataMode.buildingReference"
        case .partial: "common.partialData"
        case .healthKit: "common.appleHealth"
        }
    }
}

private extension PhysiologicalStressLevel {
    var localizationID: String {
        switch self {
        case .great: "stress.level.great"
        case .normal: "stress.level.normal"
        case .attention: "stress.level.attention"
        case .overload: "stress.level.overload"
        case .unavailable: "common.noData"
        }
    }
}

private extension DataConfidence {
    var localizationID: String {
        switch self {
        case .low: "common.low"
        case .medium: "common.medium"
        case .high: "common.high"
        }
    }
}
