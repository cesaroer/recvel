import Foundation

enum MentalDayState: Equatable {
    case none, partial, complete
}

enum MentalJournalEngine {
    static func state(morning: Bool, evening: Bool) -> MentalDayState {
        if morning && evening { return .complete }
        if morning || evening { return .partial }
        return .none
    }

    /// Cuenta dias consecutivos completos hacia atras. Hoy incompleto no rompe
    /// la racha de ayer porque el dia aun esta abierto.
    static func completionStreak(
        completedDays: Set<Date>,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let normalized = Set(completedDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !normalized.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while normalized.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

struct JournalAssociation: Equatable {
    let delta: Double?
    let yesCount: Int
    let noCount: Int

    var isReady: Bool { delta != nil }
}

enum JournalImpactEngine {
    static let minimumPerGroup = 5

    static func association(pairs: [(answer: Bool, value: Int)]) -> JournalAssociation {
        let yes = pairs.filter(\.answer).map(\.value)
        let no = pairs.filter { !$0.answer }.map(\.value)
        guard yes.count >= minimumPerGroup, no.count >= minimumPerGroup else {
            return JournalAssociation(delta: nil, yesCount: yes.count, noCount: no.count)
        }
        let yesMean = Double(yes.reduce(0, +)) / Double(yes.count)
        let noMean = Double(no.reduce(0, +)) / Double(no.count)
        return JournalAssociation(delta: yesMean - noMean, yesCount: yes.count, noCount: no.count)
    }
}

enum SleepDisciplineStatus: String, Equatable {
    case followed, close, missed, noData
}

struct SleepDisciplineNight: Equatable {
    let nightDate: Date
    let plannedBedtime: Date
    let plannedWakeTime: Date
    let targetAsleepHours: Double
    let actualSleepStart: Date?
    let actualSleepEnd: Date?
    let actualAsleepHours: Double?
    let status: SleepDisciplineStatus
    let bedtimeDeltaMinutes: Double?
    let points: Double?
}

struct SleepDisciplineSummary: Equatable {
    let score: Int?
    let measuredNights: Int
    let nights: [SleepDisciplineNight]
}

enum SleepDisciplineEngine {
    static let minimumMeasuredNights = 5

    /// Bedtime aporta 70 puntos: <=30 min obtiene 70; de 30 a 90 cae
    /// linealmente a cero. Duracion aporta 20 segun proporcion del objetivo.
    /// Despertar aporta 10: completo <=30 min, cae a cero a los 90 min.
    /// Sin una sesion Apple Health la noche es `noData` y no entra al score.
    static func evaluate(
        nightDate: Date,
        plannedBedtime: Date,
        plannedWakeTime: Date,
        targetAsleepHours: Double,
        actualSleepStart: Date?,
        actualSleepEnd: Date?,
        actualAsleepHours: Double?
    ) -> SleepDisciplineNight {
        guard let actualSleepStart else {
            return SleepDisciplineNight(
                nightDate: nightDate,
                plannedBedtime: plannedBedtime,
                plannedWakeTime: plannedWakeTime,
                targetAsleepHours: targetAsleepHours,
                actualSleepStart: nil,
                actualSleepEnd: actualSleepEnd,
                actualAsleepHours: actualAsleepHours,
                status: .noData,
                bedtimeDeltaMinutes: nil,
                points: nil
            )
        }
        let bedtimeDelta = abs(actualSleepStart.timeIntervalSince(plannedBedtime)) / 60
        let status: SleepDisciplineStatus = bedtimeDelta <= 30 ? .followed : bedtimeDelta <= 60 ? .close : .missed
        let bedtimePoints = bedtimeDelta <= 30 ? 70 : max(70 * (1 - (bedtimeDelta - 30) / 60), 0)
        let durationPoints = min(max((actualAsleepHours ?? 0) / max(targetAsleepHours, 0.1), 0), 1) * 20
        let wakePoints: Double
        if let actualSleepEnd {
            let wakeDelta = abs(actualSleepEnd.timeIntervalSince(plannedWakeTime)) / 60
            wakePoints = wakeDelta <= 30 ? 10 : max(10 * (1 - (wakeDelta - 30) / 60), 0)
        } else {
            wakePoints = 0
        }
        return SleepDisciplineNight(
            nightDate: nightDate,
            plannedBedtime: plannedBedtime,
            plannedWakeTime: plannedWakeTime,
            targetAsleepHours: targetAsleepHours,
            actualSleepStart: actualSleepStart,
            actualSleepEnd: actualSleepEnd,
            actualAsleepHours: actualAsleepHours,
            status: status,
            bedtimeDeltaMinutes: bedtimeDelta,
            points: bedtimePoints + durationPoints + wakePoints
        )
    }

    static func summary(_ nights: [SleepDisciplineNight]) -> SleepDisciplineSummary {
        let measured = nights.compactMap(\.points)
        let score: Int? = measured.count >= minimumMeasuredNights
            ? Int((measured.reduce(0, +) / Double(measured.count)).rounded())
            : nil
        return SleepDisciplineSummary(score: score, measuredNights: measured.count, nights: nights)
    }
}
