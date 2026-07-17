import Foundation

/// Opcion de hora de cama alineada a N ciclos NREM-REM completos.
///
/// Heuristica de producto, no medicion clinica: en adultos el ciclo tipico ronda ~90 min
/// (rango frecuente ~70-120; ~1.45 h = 87 min cae dentro de esa variacion). El buffer de
/// ~15 min refleja la latencia de inicio de sueno habitual (~10-20 min) usada por calculadoras
/// populares; no sustituye la latencia observada en HealthKit cuando exista.
struct SleepCycleOption: Equatable, Identifiable {
    var id: Int { cycleCount }

    let cycleCount: Int
    let cycleMinutes: Int
    let fallAsleepBufferMinutes: Int
    let asleepHours: Double
    let bedtime: Date
    let wakeTime: Date

    /// Ej.: "5 ciclos · ~7.5 h + 15 min para dormirte"
    var caption: String {
        let hours = Self.formatHours(asleepHours)
        return "\(cycleCount) ciclos · ~\(hours) h + \(fallAsleepBufferMinutes) min para dormirte"
    }

    /// Ej.: "5 ciclos · ~7.5 h"
    var shortCaption: String {
        "\(cycleCount) ciclos · ~\(Self.formatHours(asleepHours)) h"
    }

    private static func formatHours(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return String(format: "%.0f", value.rounded())
        }
        return String(format: "%.1f", value)
    }
}

enum SleepCyclePlanner {
    /// Promedio poblacional citado con frecuencia; no es fijo por persona ni por noche.
    static let defaultCycleMinutes = 90
    /// Buffer tipico de inicio de sueno (~10-20 min en adultos sanos).
    static let defaultFallAsleepBufferMinutes = 15
    /// 4-6 ciclos cubren ~6-9 h dormidas, alineado con rangos de oportunidad adultos.
    static let defaultCycleCounts = [4, 5, 6]

    static func asleepHours(
        cycles: Int,
        cycleMinutes: Int = defaultCycleMinutes
    ) -> Double {
        Double(cycles * cycleMinutes) / 60.0
    }

    static func bedtime(
        wakeTime: Date,
        cycles: Int,
        cycleMinutes: Int = defaultCycleMinutes,
        fallAsleepBufferMinutes: Int = defaultFallAsleepBufferMinutes
    ) -> Date {
        let asleepSeconds = Double(cycles * cycleMinutes) * 60.0
        let bufferSeconds = Double(fallAsleepBufferMinutes) * 60.0
        return wakeTime.addingTimeInterval(-(asleepSeconds + bufferSeconds))
    }

    static func option(
        wakeTime: Date,
        cycles: Int,
        cycleMinutes: Int = defaultCycleMinutes,
        fallAsleepBufferMinutes: Int = defaultFallAsleepBufferMinutes
    ) -> SleepCycleOption {
        SleepCycleOption(
            cycleCount: cycles,
            cycleMinutes: cycleMinutes,
            fallAsleepBufferMinutes: fallAsleepBufferMinutes,
            asleepHours: asleepHours(cycles: cycles, cycleMinutes: cycleMinutes),
            bedtime: bedtime(
                wakeTime: wakeTime,
                cycles: cycles,
                cycleMinutes: cycleMinutes,
                fallAsleepBufferMinutes: fallAsleepBufferMinutes
            ),
            wakeTime: wakeTime
        )
    }

    static func options(
        wakeTime: Date,
        cycleCounts: [Int] = defaultCycleCounts,
        cycleMinutes: Int = defaultCycleMinutes,
        fallAsleepBufferMinutes: Int = defaultFallAsleepBufferMinutes
    ) -> [SleepCycleOption] {
        cycleCounts.map {
            option(
                wakeTime: wakeTime,
                cycles: $0,
                cycleMinutes: cycleMinutes,
                fallAsleepBufferMinutes: fallAsleepBufferMinutes
            )
        }
    }

    /// Elige el conteo de ciclos cuya duracion dormida esta mas cerca de la necesidad del motor.
    /// En empate, prefiere no quedarse corto respecto a la necesidad; si sigue empatado, mas ciclos.
    static func preferredOption(
        wakeTime: Date,
        targetAsleepHours: Double,
        cycleCounts: [Int] = defaultCycleCounts,
        cycleMinutes: Int = defaultCycleMinutes,
        fallAsleepBufferMinutes: Int = defaultFallAsleepBufferMinutes
    ) -> SleepCycleOption {
        let candidates = options(
            wakeTime: wakeTime,
            cycleCounts: cycleCounts,
            cycleMinutes: cycleMinutes,
            fallAsleepBufferMinutes: fallAsleepBufferMinutes
        )
        guard let first = candidates.first else {
            return option(
                wakeTime: wakeTime,
                cycles: 5,
                cycleMinutes: cycleMinutes,
                fallAsleepBufferMinutes: fallAsleepBufferMinutes
            )
        }

        return candidates.reduce(first) { best, next in
            let bestDelta = abs(best.asleepHours - targetAsleepHours)
            let nextDelta = abs(next.asleepHours - targetAsleepHours)
            if nextDelta < bestDelta - 0.0001 { return next }
            if abs(nextDelta - bestDelta) <= 0.0001 {
                let bestShort = best.asleepHours + 0.0001 < targetAsleepHours
                let nextShort = next.asleepHours + 0.0001 < targetAsleepHours
                if bestShort != nextShort { return nextShort ? best : next }
                return next.cycleCount > best.cycleCount ? next : best
            }
            return best
        }
    }
}
