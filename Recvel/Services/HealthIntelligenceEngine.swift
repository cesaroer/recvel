import Foundation

struct StressEngine {
    private let baseline = BaselineEngine()
    private let calendar = Calendar.autoupdatingCurrent

    func assess(snapshot: DailyHealthSnapshot, history: [DailyHealthSnapshot]) -> StressAssessment {
        let prior = history
            .filter { $0.date < snapshot.date && calendar.dateComponents([.day], from: $0.date, to: snapshot.date).day ?? 31 <= 30 }
        let hrvHistory = prior.compactMap(\.hrv)
        let rhrHistory = prior.compactMap(\.restingHeartRate)
        let hrvDeviation = baseline.deviation(current: snapshot.hrv, values: hrvHistory)
        let rhrDeviation = baseline.deviation(
            current: snapshot.restingHeartRate,
            values: rhrHistory,
            lowerIsBetter: true
        )

        var impacts: [Double] = []
        if let hrvDeviation { impacts.append(-hrvDeviation * 220) }
        if let rhrDeviation { impacts.append(-rhrDeviation * 260) }

        let availableBaselineDays = min(
            snapshot.hrv == nil ? Int.max : hrvHistory.count,
            snapshot.restingHeartRate == nil ? Int.max : rhrHistory.count
        )
        let baselineDays = availableBaselineDays == Int.max ? 0 : availableBaselineDays
        guard baselineDays >= 3, !impacts.isEmpty else {
            return StressAssessment(
                score: nil,
                level: .unavailable,
                confidence: .low,
                summary: baselineDays < 3 ? "Necesitamos al menos 3 dias comparables para empezar." : "Faltan HRV o FC en reposo para estimar presion fisiologica.",
                drivers: drivers(snapshot: snapshot, hrvHistory: hrvHistory, rhrHistory: rhrHistory, hrvDeviation: hrvDeviation, rhrDeviation: rhrDeviation),
                baselineDays: baselineDays
            )
        }

        let value = min(max(Int((45 + impacts.reduce(0, +) / Double(impacts.count)).rounded()), 0), 100)
        let level: PhysiologicalStressLevel
        switch value {
        case ...30: level = .great
        case ...55: level = .normal
        case ...75: level = .attention
        default: level = .overload
        }

        let bothSignals = hrvDeviation != nil && rhrDeviation != nil
        let confidence: DataConfidence
        if bothSignals && baselineDays >= 21 { confidence = .high }
        else if bothSignals && baselineDays >= 7 { confidence = .medium }
        else { confidence = .low }

        return StressAssessment(
            score: value,
            level: level,
            confidence: confidence,
            summary: summary(for: level),
            drivers: drivers(snapshot: snapshot, hrvHistory: hrvHistory, rhrHistory: rhrHistory, hrvDeviation: hrvDeviation, rhrDeviation: rhrDeviation),
            baselineDays: baselineDays
        )
    }

    private func drivers(
        snapshot: DailyHealthSnapshot,
        hrvHistory: [Double],
        rhrHistory: [Double],
        hrvDeviation: Double?,
        rhrDeviation: Double?
    ) -> [StressDriver] {
        var result: [StressDriver] = []
        if let current = snapshot.hrv {
            result.append(StressDriver(
                name: "HRV (SDNN)",
                value: "\(Int(current.rounded())) ms",
                baseline: baseline.median(baseline.robustValues(hrvHistory)).map { "Tipico \(Int($0.rounded())) ms" } ?? "Baseline pendiente",
                impact: hrvDeviation ?? 0
            ))
        }
        if let current = snapshot.restingHeartRate {
            result.append(StressDriver(
                name: "FC en reposo",
                value: "\(Int(current.rounded())) lpm",
                baseline: baseline.median(baseline.robustValues(rhrHistory)).map { "Tipico \(Int($0.rounded())) lpm" } ?? "Baseline pendiente",
                impact: rhrDeviation ?? 0
            ))
        }
        return result
    }

    private func summary(for level: PhysiologicalStressLevel) -> String {
        switch level {
        case .great: "Tus senales autonomicas estan mejor que tu rango reciente."
        case .normal: "Tus senales estan cerca de tu rango fisiologico habitual."
        case .attention: "Una o mas senales se alejaron de tu baseline; baja el ritmo y observa la tendencia."
        case .overload: "HRV y/o FC sugieren presion fisiologica alta frente a tu historial."
        case .unavailable: "Aun no hay datos suficientes."
        }
    }
}

// MARK: - Presentacion, barras del dia y hints (funciones puras)

extension StressEngine {
    /// Convierte el indice interno (alto = mas presion) al "calm score"
    /// presentado (alto = mas relajado). Solo presentacion; el motor no cambia.
    func presentation(for assessment: StressAssessment) -> StressPresentation {
        let calmScore = assessment.score.map { 100 - $0 }
        return StressPresentation(
            calmScore: calmScore,
            displayValue: calmScore.map(String.init) ?? "--",
            ringProgress: Double(calmScore ?? 0) / 100,
            headline: assessment.level.rawValue
        )
    }

    /// Clasifica un valor de ActivationPoint (0...3) para colorear las barras
    /// horarias del dia (patron StressWatch/Garmin).
    func barIntensity(_ value: Double) -> StressBarIntensity {
        if value < 0.8 { return .low }
        if value < 1.8 { return .medium }
        return .high
    }

    /// Hints de posibles factores asociados al stress de hoy. Solo cruza
    /// registros del usuario (Journal/EmotionLog) y senales fisiologicas.
    /// Lenguaje de asociacion, nunca causal; jamas infiere emociones desde HRV.
    func stressHints(
        assessment: StressAssessment,
        snapshot: DailyHealthSnapshot,
        habitsToday: [String],
        habitsYesterday: [String],
        emotionToday: StressEmotion?,
        emotionsToday: [StressEmotion] = [],
        now: Date = .now
    ) -> [StressHint] {
        var hints: [StressHint] = []
        let hrvBelowBaseline = assessment.drivers.contains { $0.name.localizedCaseInsensitiveContains("HRV") && $0.impact < 0 }

        if matches(habitsYesterday, keywords: ["alcohol"]) {
            let text = hrvBelowBaseline
                ? "Registraste alcohol ayer y hoy tu HRV esta por debajo de tu rango. El alcohol puede reducir la HRV nocturna."
                : "Registraste alcohol ayer. El alcohol puede reducir la HRV nocturna y elevar la FC en reposo."
            hints.append(StressHint(
                id: "alcohol",
                icon: "wineglass",
                text: text,
                microAction: "Prioriza hidratacion y una carga suave hoy.",
                kind: .habit,
                offersBreathing: false
            ))
        }

        if matches(habitsToday + habitsYesterday, keywords: ["cafeina"]) {
            hints.append(StressHint(
                id: "caffeine",
                icon: "cup.and.saucer",
                text: "Registraste cafeina por la tarde. La cafeina tardia puede elevar tu FC en reposo nocturna y restar sueno profundo.",
                microAction: "Intenta cortar la cafeina al menos 6 h antes de dormir.",
                kind: .habit,
                offersBreathing: false
            ))
        }

        if matches(habitsToday, keywords: ["sintoma", "enfermedad"]) {
            hints.append(StressHint(
                id: "illness",
                icon: "thermometer.variable",
                text: "Registraste sintomas de enfermedad. La enfermedad altera HRV y FC; interpreta el indice de hoy con cautela.",
                microAction: "Descansa y no fuerces entrenamiento.",
                kind: .habit,
                offersBreathing: false
            ))
        }

        if matches(habitsToday + habitsYesterday, keywords: ["viaje", "jet"]) {
            hints.append(StressHint(
                id: "travel",
                icon: "airplane",
                text: "Registraste viaje o jet lag. Tu sistema autonomico puede tardar algunos dias en reajustarse.",
                microAction: "Manten horarios de sueno consistentes.",
                kind: .habit,
                offersBreathing: false
            ))
        }

        if let sleepHours = snapshot.sleepHours, sleepHours < 6 {
            hints.append(StressHint(
                id: "shortSleep",
                icon: "moon.zzz",
                text: String(format: "Dormiste %.1f h anoche. El sueno corto se asocia con mas presion fisiologica al dia siguiente.", sleepHours),
                microAction: "Tomate 1 minuto de respiracion y protege tu ventana de sueno de hoy.",
                kind: .sleep,
                offersBreathing: true
            ))
        }

        let reportedEmotions = emotionsToday.isEmpty
            ? (emotionToday.map { [$0] } ?? [])
            : emotionsToday
        if let advice = emotionDayAdvice(emotions: reportedEmotions) {
            hints.append(advice)
        }

        if matches(habitsToday, keywords: ["meditacion"]) {
            hints.append(StressHint(
                id: "meditation",
                icon: "figure.mind.and.body",
                text: "Registraste meditacion hoy. Buen habito: se asocia con mejor recuperacion autonomica.",
                microAction: nil,
                kind: .positive,
                offersBreathing: false
            ))
        }

        return hints
    }

    /// Consejos wellness segun promedio de emociones auto-reportadas del dia.
    /// Nunca infiere desde HRV. Copy de asociacion (NIMH / lifestyle medicine).
    func emotionDayAdvice(emotions: [StressEmotion]) -> StressHint? {
        guard !emotions.isEmpty else { return nil }
        let average = emotions.map(\.valence).reduce(0, +) / Double(emotions.count)
        let latest = emotions.last

        if average <= -0.5 || (latest?.isTense == true && emotions.count == 1) {
            let label = latest?.label.lowercased() ?? "tenso"
            return StressHint(
                id: "emotion-day-tense",
                icon: "heart.text.square",
                text: emotions.count == 1
                    ? "Registraste que te sientes \(label). Tomate un minuto para ti."
                    : "Hoy el promedio de tus registros emocionales va tenso. Eso no es un diagnostico; es una senal para cuidarte.",
                microAction: "Prueba respiracion, una caminata corta, hidratacion o reducir cafeina tarde.",
                kind: .emotion,
                offersBreathing: true
            )
        }

        if average >= 0.5 {
            return StressHint(
                id: "emotion-day-positive",
                icon: "sun.max",
                text: "El promedio de tus registros de hoy es mas positivo. Sigue con lo que te esta funcionando.",
                microAction: "Protege sueno, movimiento y pausas cortas.",
                kind: .positive,
                offersBreathing: false
            )
        }

        return nil
    }

    static func averageEmotionValence(_ emotions: [StressEmotion]) -> Double? {
        guard !emotions.isEmpty else { return nil }
        return emotions.map(\.valence).reduce(0, +) / Double(emotions.count)
    }

    /// Consejos wellness si el feeling del ayuno es preocupante (mareo/dolor)
    /// o hay cansancio/irritabilidad repetido. No es consejo medico.
    func fastingFeelingAdvice(moods: [FastingMood]) -> FastingFeelingAdvice? {
        guard !moods.isEmpty else { return nil }
        let latest = moods.last!
        let lastTwo = Array(moods.suffix(2))
        let repeatedLow = lastTwo.count == 2 && lastTwo.allSatisfy(\.isLowEnergy)
        let average = moods.map(\.valence).reduce(0, +) / Double(moods.count)

        if latest.isConcerning || average <= -1.2 {
            return FastingFeelingAdvice(
                title: "Escucha a tu cuerpo",
                detail: "Mareo o dolor de cabeza durante el ayuno son senales para hidratarte (agua o te sin calorias) y considerar terminar el ayuno con calma. Si los sintomas son graves, busca ayuda medica. Esto no sustituye consejo profesional.",
                suggestsEnding: true
            )
        }

        if repeatedLow || (latest.isLowEnergy && average < 0) {
            return FastingFeelingAdvice(
                title: "Prioriza hidratacion",
                detail: "Cansancio o irritabilidad pueden mejorar con agua. Si persisten, termina el ayuno con comida ligera (caldo o proteina suave). Autoconocimiento, no diagnostico.",
                suggestsEnding: true
            )
        }

        if average >= 1 {
            return FastingFeelingAdvice(
                title: "Te sientes bien en este ayuno",
                detail: "Sigue hidratado y rompe el ayuno con calma cuando toque. Si algo cambia, registra otro check-in.",
                suggestsEnding: false
            )
        }

        return nil
    }

    /// Matching tolerante: los nombres de habitos varian entre vistas
    /// ("Cafeina por la tarde" vs "Cafeina tarde"), por eso se busca por
    /// palabra clave y no por igualdad exacta.
    private func matches(_ habits: [String], keywords: [String]) -> Bool {
        habits.contains { habit in
            keywords.contains { habit.localizedCaseInsensitiveContains($0) }
        }
    }
}

struct FastingFeelingAdvice: Equatable {
    let title: String
    let detail: String
    let suggestsEnding: Bool
}

struct BioAgeEngine {
    private let calendar = Calendar.autoupdatingCurrent
    private let baseline = BaselineEngine()

    /// Medianas (P50) de VO2peak de las tablas FRIEND para prueba en TREADMILL,
    /// verificadas contra la fuente primaria (Kaminsky et al., Mayo Clin Proc
    /// 2015; tabla completa en PMC4919021). El punto de anclaje es el centro de
    /// cada decada publicada: 20-29 -> 25 anos, 30-39 -> 35, etc.
    ///
    /// Estas cifras se corrigieron en julio 2026: los valores anteriores estaban
    /// sesgados 1.5-3.8 ml/kg/min por debajo de lo publicado, lo que producia
    /// edades biologicas artificialmente jovenes. Ver `FitnessClassificationEngine`,
    /// que usa la tabla de percentiles completa de la misma publicacion.
    private let maleReference = [(25.0, 48.0), (35, 42.4), (45, 37.8), (55, 32.6), (65, 28.2), (75, 24.4)]
    private let femaleReference = [(25.0, 37.6), (35, 30.2), (45, 26.7), (55, 23.4), (65, 20.0), (75, 18.3)]

    func estimate(
        birthDate: Date?,
        sex: NutritionSex?,
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        now: Date = .now
    ) -> BioAgeEstimate {
        let age = birthDate.flatMap { calendar.dateComponents([.year], from: $0, to: now).year }
        let factors = contextFactors(snapshot: snapshot, history: history)
        guard let age, age >= 18 else {
            return unavailable(age: age, summary: "Agrega tu fecha de nacimiento para calcular una referencia por edad.", factors: factors)
        }
        guard sex == .male || sex == .female else {
            return unavailable(age: age, summary: "Selecciona sexo de referencia para comparar VO2 con FRIEND.", factors: factors)
        }
        guard let vo2 = snapshot.vo2Max else {
            return unavailable(age: age, summary: "Necesitamos una estimacion reciente de VO2 max en Apple Health.", factors: factors)
        }

        let reference = sex == .male ? maleReference : femaleReference
        let estimated = equivalentAge(for: vo2, reference: reference)
        let sampleCount = history.compactMap(\.vo2Max).count
        let ageDays = snapshot.vo2MaxDate.map { calendar.dateComponents([.day], from: $0, to: now).day ?? 999 } ?? 999
        let confidence: DataConfidence = sampleCount >= 3 && ageDays <= 90 ? .medium : .low
        let delta = estimated - Double(age)
        let summary: String
        if abs(delta) < 1.5 { summary = "Tu fitness cardiorrespiratorio esta cerca de la mediana de tu edad." }
        else if delta < 0 { summary = "Tu VO2 se parece a la mediana de un grupo mas joven." }
        else { summary = "Tu VO2 se parece a la mediana de un grupo de mayor edad; la tendencia es mas util que una lectura." }

        return BioAgeEstimate(
            chronologicalYears: age,
            estimatedYears: estimated,
            confidence: confidence,
            summary: summary,
            factors: factors
        )
    }

    private func unavailable(age: Int?, summary: String, factors: [BioAgeFactor]) -> BioAgeEstimate {
        BioAgeEstimate(chronologicalYears: age, estimatedYears: nil, confidence: .low, summary: summary, factors: factors)
    }

    /// Interpola la edad cuya mediana FRIEND iguala este VO2.
    /// Los topes son los limites del rango PUBLICADO (20-79): fuera de el no
    /// extrapolamos, porque FRIEND no reporta datos mas alla de la decada 70-79.
    private func equivalentAge(for vo2: Double, reference: [(Double, Double)]) -> Double {
        guard let youngest = reference.first, let oldest = reference.last else { return 0 }
        // Comparacion estricta: un VO2 que IGUALA la mediana de una decada debe
        // interpolar a la edad de anclaje de esa decada, no caer en el tope.
        if vo2 > youngest.1 { return 20 }
        if vo2 < oldest.1 { return 79 }
        for pair in zip(reference, reference.dropFirst()) {
            let upper = pair.0
            let lower = pair.1
            guard vo2 <= upper.1, vo2 >= lower.1 else { continue }
            let progress = (upper.1 - vo2) / (upper.1 - lower.1)
            return upper.0 + progress * (lower.0 - upper.0)
        }
        return 79
    }

    private func contextFactors(snapshot: DailyHealthSnapshot, history: [DailyHealthSnapshot]) -> [BioAgeFactor] {
        var factors: [BioAgeFactor] = []
        if let vo2 = snapshot.vo2Max {
            factors.append(BioAgeFactor(name: "VO2 max", value: String(format: "%.1f", vo2), note: "Base del calculo actual", favorable: nil))
        }
        if let rhr = snapshot.restingHeartRate {
            let typical = baseline.median(history.compactMap(\.restingHeartRate))
            factors.append(BioAgeFactor(name: "FC en reposo", value: "\(Int(rhr.rounded())) lpm", note: "Contexto; no cambia la edad", favorable: typical.map { rhr <= $0 }))
        }
        if let consistency = snapshot.sleepDetails?.consistencyMinutes {
            factors.append(BioAgeFactor(name: "Consistencia de sueno", value: "±\(Int(consistency.rounded())) min", note: "Contexto de 30 dias", favorable: consistency <= 45))
        }
        if let steps = snapshot.steps {
            factors.append(BioAgeFactor(name: "Actividad", value: steps.formatted(), note: "Pasos del dia; no cambia la edad", favorable: steps >= 7_000))
        }
        return factors
    }
}

// MARK: - Trends Analysis (patron Bevel)

/// Calcula las filas de "Trends Analysis": cuanto cambio una metrica en
/// ventanas de 3/7/14/30/90 dias comparando el promedio de la ventana con el
/// del periodo inmediatamente anterior de la misma longitud.
struct MetricTrendEngine {
    private let baseline = BaselineEngine()

    static let windows = [3, 7, 14, 30, 90]

    /// - Parameter points: serie ordenada ascendente por fecha.
    func rows(for points: [MetricPoint], now: Date = .now) -> [MetricTrendRow] {
        let ordered = points.sorted { $0.date < $1.date }
        return Self.windows.map { days in
            MetricTrendRow(
                days: days,
                change: change(ordered, days: days, now: now),
                points: Array(ordered.suffix(days).map(\.value).suffix(12))
            )
        }
    }

    /// Promedio de la ventana reciente menos el de la ventana previa.
    /// `nil` cuando cualquiera de las dos ventanas no tiene datos.
    func change(_ points: [MetricPoint], days: Int, now: Date = .now) -> Double? {
        let calendar = Calendar.current
        guard let recentStart = calendar.date(byAdding: .day, value: -days, to: now),
              let previousStart = calendar.date(byAdding: .day, value: -days * 2, to: now)
        else { return nil }

        let recent = points.filter { $0.date > recentStart }.map(\.value)
        let previous = points.filter { $0.date > previousStart && $0.date <= recentStart }.map(\.value)
        guard !recent.isEmpty, !previous.isEmpty,
              let recentMean = baseline.median(recent),
              let previousMean = baseline.median(previous)
        else { return nil }
        return recentMean - previousMean
    }

    /// Interpreta el signo del cambio segun la direccion deseada de la metrica.
    /// `tolerance` evita llamar "tendencia" al ruido.
    func direction(change: Double?, higherIsBetter: Bool, tolerance: Double) -> MetricTrendDirection {
        guard let change else { return .unknown }
        if abs(change) < tolerance { return .steady }
        let positive = change > 0
        return positive == higherIsBetter ? .improving : .declining
    }
}

// MARK: - Sleep Bank

/// Balance acumulado de sueno ("sleep debt") sobre una ventana rodante.
///
/// Evidencia: la deuda de sueno se mide convencionalmente en ventanas de 7-14
/// dias; 14 dias captura el patron semanal completo incluyendo el fin de
/// semana (Sleep Foundation; Van Dongen et al. 2003, restriccion cronica).
/// El sueno de recuperacion de fin de semana compensa PARCIALMENTE la deuda
/// entre semana pero no restaura del todo la funcion cognitiva ni los
/// marcadores metabolicos — por eso el copy nunca promete "saldar" la deuda.
struct SleepBankEngine {
    /// Ventana rodante en dias. 14 por decision de producto respaldada arriba.
    static let windowDays = 14

    struct Result: Equatable {
        /// Horas acumuladas por encima (+) o por debajo (-) de la meta.
        let balanceHours: Double
        /// Noches con dato dentro de la ventana.
        let nights: Int
        /// Meta usada por noche.
        let goalHours: Double
        /// Aporte por noche, para la grafica de barras.
        let nightly: [MetricPoint]

        var isSurplus: Bool { balanceHours >= 0 }
        /// Sin noches suficientes no afirmamos nada.
        var hasEnoughData: Bool { nights >= 3 }
    }

    /// - Parameters:
    ///   - history: snapshots ordenados o no; se filtra por la ventana.
    ///   - goalHours: meta por noche del usuario (default de producto: 8 h).
    func assess(history: [DailyHealthSnapshot], goalHours: Double, now: Date = .now) -> Result {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -Self.windowDays, to: now) ?? now
        let window = history
            .filter { $0.date > start && $0.date <= now }
            .sorted { $0.date < $1.date }

        let nightly: [MetricPoint] = window.compactMap { day in
            day.sleepHours.map { MetricPoint(date: day.date, value: $0 - goalHours) }
        }
        let balance = nightly.reduce(0) { $0 + $1.value }
        return Result(
            balanceHours: balance,
            nights: nightly.count,
            goalHours: goalHours,
            nightly: nightly
        )
    }
}

// MARK: - Sleep coaching

/// Consejo de sueno accionable. `evidence` cita la base para que la UI pueda
/// mostrarla: nunca damos una instruccion sin decir de donde sale.
struct SleepCoachingTip: Identifiable, Equatable {
    enum Kind: String { case duration, timing, consistency, stages, efficiency, positive }
    let kind: Kind
    let title: String
    let detail: String
    let evidence: String
    let symbol: String
    var id: String { kind.rawValue + title }
}

/// Genera coaching de sueno a partir del score y las senales medidas.
///
/// Reglas de honestidad (README_StressAndBio.md §3.2, Calorie_AI_Research.md §12.9):
/// lenguaje de asociacion, nunca diagnostico; no prometemos "saldar" deuda de
/// sueno porque la recuperacion de fin de semana es solo parcial.
struct SleepCoachingEngine {
    private let baseline = BaselineEngine()

    /// - Parameters:
    ///   - score: sleep score 0-100.
    ///   - bank: balance de la ventana rodante, para hablar de deuda.
    func tips(
        score: Int,
        snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        bank: SleepBankEngine.Result
    ) -> [SleepCoachingTip] {
        var tips: [SleepCoachingTip] = []
        let sleep = snapshot.sleepDetails

        // 1. Duracion corta. Consenso AASM/SRS: 7+ h para adultos.
        if let hours = snapshot.sleepHours, hours < 7 {
            tips.append(SleepCoachingTip(
                kind: .duration,
                title: "Apunta a mas horas de oportunidad",
                detail: String(format: "Dormiste %.1f h. Adelantar la hora de acostarte suele rendir mas que intentar recuperar el fin de semana.", hours),
                evidence: "El consenso de la American Academy of Sleep Medicine y la Sleep Research Society situa 7 h o mas por noche para adultos.",
                symbol: "bed.double.fill"
            ))
        }

        // 2. Deuda acumulada. Van Dongen 2003: la restriccion cronica acumula
        //    deficit de rendimiento aunque la somnolencia subjetiva se estabilice.
        if bank.hasEnoughData, bank.balanceHours < -3 {
            tips.append(SleepCoachingTip(
                kind: .duration,
                title: "Llevas deuda acumulada",
                detail: String(format: "Tu balance de %d dias es %.1f h. Recuperar es gradual: sumar 30-60 min por noche varias noches funciona mejor que una noche larga.", SleepBankEngine.windowDays, bank.balanceHours),
                evidence: "La restriccion cronica de sueno acumula deficit de rendimiento; el sueno de recuperacion de fin de semana compensa solo parcialmente (Van Dongen et al., Sleep 2003).",
                symbol: "chart.line.downtrend.xyaxis"
            ))
        }

        // 3. Consistencia. La variabilidad de horario se asocia con peor
        //    calidad y desalineacion circadiana.
        if let variability = bedtimeVariabilityMinutes(history), variability > 60 {
            tips.append(SleepCoachingTip(
                kind: .consistency,
                title: "Estabiliza tu horario",
                detail: String(format: "Tus horas de dormir varian ~%.0f min entre noches. Un horario constante refuerza tu ritmo circadiano.", variability),
                evidence: "La irregularidad del horario de sueno se asocia de forma independiente con peor calidad de sueno y riesgo cardiometabolico (Huang & Redline, Diabetes Care 2019).",
                symbol: "clock.arrow.circlepath"
            ))
        }

        // 4. Eficiencia baja: mucho tiempo en cama despierto.
        if let sleep, let efficiency = sleep.efficiency, efficiency < 85, sleep.inBedHours > 0 {
            tips.append(SleepCoachingTip(
                kind: .efficiency,
                title: "Pasas tiempo en cama sin dormir",
                detail: String(format: "Tu eficiencia fue %.0f%%. Usar la cama solo para dormir y salir de ella si no concilias en ~20 min es la base del control de estimulos.", efficiency),
                evidence: "El control de estimulos y la restriccion de tiempo en cama son componentes centrales de la terapia cognitivo-conductual para el insomnio (CBT-I), primera linea segun la AASM.",
                symbol: "bed.double.circle"
            ))
        }

        // 5. Etapas: profundo bajo. Solo si el dispositivo reporto etapas.
        if let sleep, sleep.hasStages, sleep.asleepHours > 0 {
            let deepShare = sleep.deepHours / sleep.asleepHours
            if deepShare < 0.10 {
                tips.append(SleepCoachingTip(
                    kind: .stages,
                    title: "Tu sueno profundo fue bajo",
                    detail: String(format: "El profundo fue %.0f%% de la noche. El alcohol y el ejercicio intenso tarde suelen asociarse con menos profundo en la primera mitad.", deepShare * 100),
                    evidence: "El sueno de ondas lentas ocupa tipicamente 13-23% de la noche en adultos; el alcohol lo suprime en la segunda mitad (Ebrahim et al., Alcohol Clin Exp Res 2013). Las etapas del reloj son estimaciones, no polisomnografia.",
                    symbol: "moon.stars.fill"
                ))
            }
        }

        // 6. Refuerzo positivo cuando el score es alto.
        if score >= 85, tips.isEmpty {
            tips.append(SleepCoachingTip(
                kind: .positive,
                title: "Tu noche fue solida",
                detail: "Mantener el mismo horario los proximos dias es lo que consolida el patron.",
                evidence: "La regularidad del horario predice mejor calidad de sueno que la duracion aislada (Phillips et al., Scientific Reports 2017).",
                symbol: "checkmark.seal.fill"
            ))
        }

        return tips
    }

    /// Desviacion tipica aproximada (MAD) de la hora de dormir, en minutos.
    func bedtimeVariabilityMinutes(_ history: [DailyHealthSnapshot]) -> Double? {
        let calendar = Calendar.current
        let minutes: [Double] = history.compactMap { day in
            guard let start = day.sleepDetails?.startDate else { return nil }
            let components = calendar.dateComponents([.hour, .minute], from: start)
            guard let hour = components.hour, let minute = components.minute else { return nil }
            // Centrar alrededor de medianoche: 22:00 -> -120, 02:00 -> 120.
            let raw = Double(hour * 60 + minute)
            return raw > 12 * 60 ? raw - 24 * 60 : raw
        }
        guard minutes.count >= 4, let center = baseline.median(minutes) else { return nil }
        let deviations = minutes.map { abs($0 - center) }
        guard let mad = baseline.median(deviations) else { return nil }
        return mad * 1.4826
    }
}

// MARK: - Clasificacion de aptitud cardiorrespiratoria

/// Categoria de rendimiento derivada del percentil FRIEND del usuario.
/// Los cortes son percentiles publicados; los nombres son de producto.
enum FitnessClass: String, CaseIterable, Identifiable {
    case elite = "Atleta"
    case high = "Alto rendimiento"
    case good = "Buena forma"
    case average = "Promedio"
    case low = "Bajo el promedio"
    case sedentary = "Sedentario"
    var id: String { rawValue }

    /// Percentil minimo (inclusive) de cada categoria.
    var minimumPercentile: Double {
        switch self {
        case .elite: 90
        case .high: 75
        case .good: 50
        case .average: 25
        case .low: 10
        case .sedentary: 0
        }
    }

    var detail: String {
        switch self {
        case .elite: "Tu VO2 max esta en el decil superior de tu grupo de edad y sexo."
        case .high: "Tu VO2 max supera a tres de cada cuatro personas de tu grupo."
        case .good: "Tu VO2 max esta por encima de la mediana de tu grupo."
        case .average: "Tu VO2 max esta en el rango central de tu grupo."
        case .low: "Tu VO2 max esta por debajo del cuartil inferior de tu grupo."
        case .sedentary: "Tu VO2 max esta en el decil inferior de tu grupo."
        }
    }

    var symbol: String {
        switch self {
        case .elite: "trophy.fill"
        case .high: "flame.fill"
        case .good: "figure.run"
        case .average: "figure.walk"
        case .low: "figure.stand"
        case .sedentary: "chair.lounge.fill"
        }
    }
}

/// Resultado de clasificar la aptitud cardiorrespiratoria.
struct FitnessClassification: Equatable {
    let fitnessClass: FitnessClass
    /// Percentil estimado (0-100) dentro del grupo de edad y sexo.
    let percentile: Double
    let vo2Max: Double
    let ageGroup: String
    /// Mediana del grupo, para contexto.
    let groupMedian: Double
    /// VO2 necesario para subir a la siguiente categoria, si hay una.
    let nextClass: FitnessClass?
    let vo2ForNextClass: Double?
    let confidence: DataConfidence
}

/// Clasifica el VO2 max contra las tablas de percentiles FRIEND.
///
/// Fuente: Kaminsky LA et al., "Reference Standards for Cardiorespiratory
/// Fitness Measured With Cardiopulmonary Exercise Testing Using Treadmill",
/// Mayo Clin Proc 2015 (tabla completa verificada en PMC4919021).
/// N = 4,611 hombres y 3,172 mujeres, pruebas maximas en treadmill.
///
/// La publicacion reporta P5, P10, P25, P50, P75, P90 y P95. NO define
/// categorias como "excelente" o "pobre": los nombres de `FitnessClass` son
/// una decision de producto sobre percentiles publicados, no una clasificacion
/// clinica. Entre percentiles publicados interpolamos linealmente.
///
/// Limite importante: FRIEND mide VO2 en ergoespirometria maxima. Apple Watch
/// lo ESTIMA desde caminatas/carreras al aire libre, con error tipico mayor.
/// Por eso la confianza nunca es alta con una sola lectura.
struct FitnessClassificationEngine {
    /// Percentiles publicados, en orden.
    private static let percentiles: [Double] = [5, 10, 25, 50, 75, 90, 95]

    /// Fila = decada (20-29, 30-39, ... 70-79); columna = percentil de arriba.
    private static let maleTable: [(range: ClosedRange<Int>, values: [Double])] = [
        (20...29, [29.0, 32.1, 40.1, 48.0, 55.2, 61.8, 66.3]),
        (30...39, [27.2, 30.2, 35.9, 42.4, 49.2, 56.5, 59.8]),
        (40...49, [24.2, 26.8, 31.9, 37.8, 45.0, 52.1, 55.6]),
        (50...59, [20.9, 22.8, 27.1, 32.6, 39.7, 45.6, 50.7]),
        (60...69, [17.4, 19.8, 23.7, 28.2, 34.5, 40.3, 43.0]),
        (70...79, [16.3, 17.1, 20.4, 24.4, 30.4, 36.6, 39.7])
    ]

    private static let femaleTable: [(range: ClosedRange<Int>, values: [Double])] = [
        (20...29, [21.7, 23.9, 30.5, 37.6, 44.7, 51.3, 56.0]),
        (30...39, [19.0, 20.9, 25.3, 30.2, 36.1, 41.4, 45.8]),
        (40...49, [17.0, 18.8, 22.1, 26.7, 32.4, 38.4, 41.7]),
        (50...59, [16.0, 17.3, 19.9, 23.4, 27.6, 32.0, 35.9]),
        (60...69, [13.4, 14.6, 17.2, 20.0, 23.8, 27.0, 29.4]),
        (70...79, [13.1, 13.6, 15.6, 18.3, 20.8, 23.1, 24.1])
    ]

    /// - Returns: `nil` cuando falta edad, sexo de referencia o VO2, o cuando la
    ///   edad cae fuera del rango publicado (20-79). Nunca adivinamos.
    func classify(
        vo2Max: Double?,
        age: Int?,
        sex: NutritionSex?,
        vo2SampleCount: Int = 1,
        vo2AgeDays: Int = 0
    ) -> FitnessClassification? {
        guard let vo2Max, let age, age >= 20, age <= 79,
              sex == .male || sex == .female
        else { return nil }

        let table = sex == .male ? Self.maleTable : Self.femaleTable
        guard let row = table.first(where: { $0.range.contains(age) }) else { return nil }

        let percentile = self.percentile(for: vo2Max, in: row.values)
        let fitnessClass = FitnessClass.allCases.first { percentile >= $0.minimumPercentile } ?? .sedentary
        let next = nextClass(above: fitnessClass)

        return FitnessClassification(
            fitnessClass: fitnessClass,
            percentile: percentile,
            vo2Max: vo2Max,
            ageGroup: "\(row.range.lowerBound)-\(row.range.upperBound)",
            groupMedian: row.values[3],
            nextClass: next,
            vo2ForNextClass: next.map { vo2(forPercentile: $0.minimumPercentile, in: row.values) },
            confidence: vo2SampleCount >= 3 && vo2AgeDays <= 90 ? .medium : .low
        )
    }

    /// Percentil de un VO2 interpolando entre los percentiles publicados.
    /// Fuera del rango publicado (P5-P95) devolvemos el extremo, sin extrapolar.
    func percentile(for vo2: Double, in values: [Double]) -> Double {
        guard let first = values.first, let last = values.last else { return 50 }
        if vo2 <= first { return Self.percentiles[0] }
        if vo2 >= last { return Self.percentiles[Self.percentiles.count - 1] }
        for index in 0..<(values.count - 1) where vo2 >= values[index] && vo2 <= values[index + 1] {
            let span = values[index + 1] - values[index]
            guard span > 0 else { return Self.percentiles[index] }
            let progress = (vo2 - values[index]) / span
            let low = Self.percentiles[index]
            let high = Self.percentiles[index + 1]
            return low + progress * (high - low)
        }
        return 50
    }

    /// VO2 correspondiente a un percentil, interpolando entre los publicados.
    func vo2(forPercentile target: Double, in values: [Double]) -> Double {
        guard let firstValue = values.first, let lastValue = values.last else { return 0 }
        if target <= Self.percentiles[0] { return firstValue }
        if target >= Self.percentiles[Self.percentiles.count - 1] { return lastValue }
        for index in 0..<(Self.percentiles.count - 1)
        where target >= Self.percentiles[index] && target <= Self.percentiles[index + 1] {
            let span = Self.percentiles[index + 1] - Self.percentiles[index]
            guard span > 0 else { return values[index] }
            let progress = (target - Self.percentiles[index]) / span
            return values[index] + progress * (values[index + 1] - values[index])
        }
        return values[3]
    }

    private func nextClass(above current: FitnessClass) -> FitnessClass? {
        let ordered = FitnessClass.allCases.sorted { $0.minimumPercentile < $1.minimumPercentile }
        guard let index = ordered.firstIndex(of: current), index + 1 < ordered.count else { return nil }
        return ordered[index + 1]
    }
}
