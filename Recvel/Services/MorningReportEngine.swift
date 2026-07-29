import Foundation

/// Reporte de la mañana: la foto de como amaneciste, para leerse una vez.
///
/// No inventa metricas: compone lo que ya calculan `ScoreEngine`, `InsightEngine`
/// y `SleepBankEngine`. Se construye **en el momento de abrirlo**, nunca se
/// precalcula la noche anterior (una notificacion local no puede recalcular al
/// dispararse, y mostrar cifras viejas seria mentir).
struct MorningReport: Equatable {
    struct SleepBlock: Equatable {
        let hours: Double?
        let efficiency: Double?
        /// Saldo del banco de sueño en la ventana rodante; nil si no hay noches suficientes.
        let bankBalanceHours: Double?
        let bankNights: Int
    }

    /// Lectura cruda de la noche con su rango personal, para el panel de señales.
    /// `range` es nil cuando no hay muestras suficientes para una banda honesta.
    struct Signal: Equatable, Identifiable {
        let name: String
        let value: String
        let unit: String
        let range: String?
        let symbol: String
        /// Posicion dentro de la banda personal (0...1) para el micro-medidor.
        /// nil = sin banda; el medidor no se dibuja.
        let bandPosition: Double?
        var id: String { name }
    }

    let date: Date
    let recoveryValue: Int
    /// Scores de sueño, carga y energia del mismo dia (los mismos que Home).
    let sleepValue: Int
    let strainValue: Int
    let energyValue: Int
    let recoveryBand: String
    let recoveryConfidence: DataConfidence
    /// Horas dormidas de las ultimas noches con dato, en orden cronologico.
    /// Solo para la mini-grafica: si hay menos de 3 noches no se dibuja.
    let sleepTrendHours: [Double]
    /// Señal que mas resto hoy (para responder "por que amaneci asi").
    let weakestFactorName: String?
    let weakestFactorValue: String?
    let weakestFactorBaseline: String?
    let sleep: SleepBlock
    let focusTitle: String
    let focusDetail: String
    let currentLoad: Double
    let targetLoad: Double
    /// Sesion planeada de hoy, si la agenda semanal tiene una.
    let plannedSession: String?
    /// Lecturas de la noche (HRV, FC reposo, respiracion, SpO2, temperatura).
    let signals: [Signal]
    /// Estres fisiologico de la lectura mas reciente.
    let stressLevel: String?
    let stressScore: Int?
    /// Emociones registradas en las ultimas 24 h.
    let emotions: [String]
    /// Estado del ayuno al abrir el reporte.
    let fastingHeadline: String?
    let fastingDetail: String?
    /// Objetivo calorico del dia y lo ya registrado.
    let nutritionHeadline: String?
    let nutritionDetail: String?

    var remainingLoad: Double { max(targetLoad - currentLoad, 0) }
    var hasStrainRoom: Bool { remainingLoad > 0.5 }
    /// Porcentaje del objetivo de carga ya consumido (puede pasar de 100).
    var loadPercentOfTarget: Int {
        guard targetLoad > 0 else { return 0 }
        return Int((currentLoad / targetLoad * 100).rounded())
    }
    /// La mini-grafica necesita al menos 3 noches para decir algo.
    var hasSleepTrend: Bool { sleepTrendHours.count >= 3 }
}

/// Estado del ayuno tal como lo resume el reporte (lo arma la vista, que es
/// quien tiene la sesion activa en SwiftData).
struct FastingStatus: Equatable {
    let headline: String
    let detail: String
}

/// Objetivo calorico del dia frente a lo ya registrado.
struct NutritionStatus: Equatable {
    let headline: String
    let detail: String
}

enum MorningReportEngine {
    /// Ventana tras despertar en la que el reporte sigue siendo "de la mañana".
    /// Fuera de ella no se auto-presenta: a las 8 de la noche ya no es un reporte
    /// matutino, es historia (se puede abrir a mano desde Home).
    static let autoPresentWindowHours = 6

    static func report(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        scores: [WellnessScore],
        factors: [RecoveryFactor],
        brief: DailyBrief,
        sleepBank: SleepBankEngine.Result,
        plannedSession: String? = nil,
        stress: StressAssessment? = nil,
        emotions: [String] = [],
        fasting: FastingStatus? = nil,
        nutrition: NutritionStatus? = nil
    ) -> MorningReport {
        let recovery = scores.first { $0.kind == .recovery }
        // El factor "mas debil" es el que mas resta; si todos suman, no señalamos nada.
        let weakest = factors.filter { $0.contribution < 0 }.min { $0.contribution < $1.contribution }

        // Ultimas noches medidas (incluida la de hoy), en orden cronologico.
        let trend = (history + [snapshot])
            .filter { $0.date <= snapshot.date }
            .sorted { $0.date < $1.date }
            .suffix(7)
            .compactMap(\.sleepHours)

        return MorningReport(
            date: snapshot.date,
            recoveryValue: recovery?.value ?? 0,
            sleepValue: scores.first { $0.kind == .sleep }?.value ?? 0,
            strainValue: scores.first { $0.kind == .strain }?.value ?? 0,
            energyValue: scores.first { $0.kind == .energy }?.value ?? 0,
            recoveryBand: recovery?.summary ?? "",
            recoveryConfidence: recovery?.confidence ?? .low,
            sleepTrendHours: Array(trend),
            weakestFactorName: weakest?.name,
            weakestFactorValue: weakest?.value,
            weakestFactorBaseline: weakest?.baseline,
            sleep: MorningReport.SleepBlock(
                hours: snapshot.sleepHours,
                efficiency: snapshot.sleepDetails?.efficiency,
                bankBalanceHours: sleepBank.hasEnoughData ? sleepBank.balanceHours : nil,
                bankNights: sleepBank.nights
            ),
            focusTitle: brief.focusTitle,
            focusDetail: brief.focusDetail,
            currentLoad: brief.currentLoad,
            targetLoad: brief.targetLoad,
            plannedSession: plannedSession,
            signals: signals(snapshot: snapshot, history: history),
            stressLevel: stress?.level.displayName,
            stressScore: stress?.score,
            emotions: emotions,
            fastingHeadline: fasting?.headline,
            fastingDetail: fasting?.detail,
            nutritionHeadline: nutrition?.headline,
            nutritionDetail: nutrition?.detail
        )
    }

    /// Lecturas de la noche con su banda personal. Solo se incluye lo medido:
    /// una señal sin dato no aparece (nunca se rellena con ceros).
    static func signals(
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        baseline: BaselineEngine = BaselineEngine()
    ) -> [MorningReport.Signal] {
        func build(
            _ name: String,
            _ value: Double?,
            unit: String,
            symbol: String,
            decimals: Int,
            samples: [Double],
            /// Tope fisico de la señal (SpO2 no puede pasar de 100 %).
            cap: Double? = nil
        ) -> MorningReport.Signal? {
            guard let value else { return nil }
            let band = baseline.personalBand(samples).map { band -> ClosedRange<Double> in
                guard let cap else { return band }
                return band.lowerBound...min(band.upperBound, cap)
            }
            let rangeText = band.map {
                "\(format($0.lowerBound, decimals))–\(format($0.upperBound, decimals))"
            }
            let position = band.map { band -> Double in
                let span = max(band.upperBound - band.lowerBound, 0.0001)
                return min(max((value - band.lowerBound) / span, 0), 1)
            }
            return MorningReport.Signal(
                name: name,
                value: format(value, decimals),
                unit: unit,
                range: rangeText,
                symbol: symbol,
                bandPosition: position
            )
        }

        let past = history.filter { $0.date < snapshot.date }
        return [
            build("HRV", snapshot.hrv, unit: "ms", symbol: "waveform.path.ecg",
                  decimals: 0, samples: past.compactMap(\.hrv)),
            build("FC reposo", snapshot.restingHeartRate, unit: "lpm", symbol: "heart",
                  decimals: 0, samples: past.compactMap(\.restingHeartRate)),
            build("Respiración", snapshot.respiratoryRate, unit: "rpm", symbol: "lungs",
                  decimals: 1, samples: past.compactMap(\.respiratoryRate)),
            // HealthKit entrega SpO2 como fraccion (0.97) o como porcentaje
            // segun la fuente: se normaliza igual que en el detalle de Recovery.
            build("SpO₂", normalizedOxygen(snapshot.oxygenSaturation), unit: "%", symbol: "drop.circle",
                  decimals: 0, samples: past.compactMap { normalizedOxygen($0.oxygenSaturation) }, cap: 100),
            build("Temp. muñeca", snapshot.wristTemperature, unit: "°C", symbol: "thermometer.medium",
                  decimals: 1, samples: past.compactMap(\.wristTemperature))
        ].compactMap { $0 }
    }

    private static func normalizedOxygen(_ value: Double?) -> Double? {
        value.map { $0 <= 1 ? $0 * 100 : $0 }
    }

    private static func format(_ value: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Clave de "ya lo vi hoy" (una sola vez al dia).
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// Decide si el reporte se abre solo al entrar a la app.
    ///
    /// Se abre cuando: hay datos, todavia estamos dentro de la ventana matutina
    /// y no se ha visto hoy. Antes de la hora de despertar NO se abre: el reporte
    /// habla de la noche que aun no termina.
    static func shouldAutoPresent(
        now: Date,
        wakeMinutes: Int,
        lastShownKey: String,
        hasData: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        guard hasData else { return false }
        guard lastShownKey != dayKey(for: now, calendar: calendar) else { return false }

        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        guard minutesNow >= wakeMinutes else { return false }
        return minutesNow < wakeMinutes + autoPresentWindowHours * 60
    }
}
