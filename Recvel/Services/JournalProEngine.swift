import Foundation

struct JournalTagDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let category: JournalTagCategory
    let period: JournalTagPeriod
    let mode: JournalTrackingMode
    let source: JournalTagSource
    let defaultEnabled: Bool
    let sensitive: Bool
    let defaultThreshold: Double?
    let unit: String?

    var localizedTitle: String {
        RecvelL10n.text("journal.tag.\(id).title")
    }

    var localizedSubtitle: String {
        RecvelL10n.text("journal.tag.\(id).detail")
    }

    init(
        _ id: String,
        _ title: String,
        _ subtitle: String,
        symbol: String,
        category: JournalTagCategory,
        period: JournalTagPeriod = .daytime,
        mode: JournalTrackingMode = .boolean,
        source: JournalTagSource = .manual,
        enabled: Bool = false,
        sensitive: Bool = false,
        threshold: Double? = nil,
        unit: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.category = category
        self.period = period
        self.mode = mode
        self.source = source
        self.defaultEnabled = enabled
        self.sensitive = sensitive
        self.defaultThreshold = threshold
        self.unit = unit
    }
}

enum JournalCatalog {
    static let builtIns: [JournalTagDefinition] = [
        // Bevel-parity automatic trackers (Apple Health / derived)
        .init("auto.steps", "10,000+ pasos", "Movimiento diario", symbol: "figure.walk", category: .automatic, source: .automatic, enabled: true, threshold: 10_000, unit: "pasos"),
        .init("auto.cardio", RecvelL10n.text("20+ min de cardio"), RecvelL10n.text("Entrenamiento aerobico"), symbol: "heart.circle.fill", category: .automatic, source: .automatic, enabled: true, threshold: 20, unit: "min"),
        .init("auto.daylight", RecvelL10n.text("20+ min de luz natural"), "Exposicion exterior", symbol: "sun.max.fill", category: .automatic, source: .automatic, enabled: true, threshold: 20, unit: "min"),
        .init("auto.strength", RecvelL10n.text("20+ min de fuerza"), RecvelL10n.text("Trabajo de resistencia"), symbol: "dumbbell.fill", category: .automatic, source: .automatic, enabled: true, threshold: 20, unit: "min"),
        .init("auto.zone2", RecvelL10n.text("30+ min en zona 2"), "Base aerobica", symbol: "figure.run.circle.fill", category: .automatic, source: .automatic, enabled: true, threshold: 30, unit: "min"),
        .init("auto.stress", RecvelL10n.text("Estrés fisiológico de 50+"), RecvelL10n.text("Presión fisiológica"), symbol: "waveform.path.ecg", category: .automatic, source: .automatic, enabled: true, threshold: 50, unit: "pts"),
        .init("auto.mindful", "Sesion mindfulness", "Minutos conscientes", symbol: "brain.head.profile", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "min"),
        .init("auto.nap", "Siestas", RecvelL10n.text("Sueno fuera de la sesion principal"), symbol: "powersleep", category: .automatic, period: .nighttime, source: .automatic, enabled: true, threshold: 10, unit: "min"),
        .init("auto.overreach", RecvelL10n.text("Carga por encima del objetivo"), RecvelL10n.text("Carga mayor a la sugerida"), symbol: "gauge.with.dots.needle.67percent", category: .automatic, source: .automatic, enabled: true),
        .init("auto.nutrition", "Nutricion registrada", RecvelL10n.text("Comidas confirmadas en Recvel"), symbol: "fork.knife", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "comidas"),
        // Recvel extras derived from available HealthKit / scores (Bevel may not show these)
        .init("auto.sleep", RecvelL10n.text("Sueno registrado"), RecvelL10n.text("Sesion de sueno del dia"), symbol: "moon.zzz.fill", category: .automatic, period: .nighttime, source: .automatic, enabled: true, threshold: 1, unit: "h"),
        .init("auto.recovery", RecvelL10n.text("Recuperación del día"), RecvelL10n.text("Puntuación local de Recuperación"), symbol: "heart.fill", category: .automatic, source: .automatic, enabled: true, threshold: 67, unit: "pts"),
        .init("auto.hrv", RecvelL10n.text("HRV del dia"), "Variabilidad cardiaca medida", symbol: "waveform.path.ecg.rectangle", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "ms"),
        .init("auto.rhr", RecvelL10n.text("FC en reposo"), RecvelL10n.text("Pulso en reposo del dia"), symbol: "heart.text.square.fill", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "lpm"),
        .init("auto.vo2", RecvelL10n.text("VO2 Max del dia"), "Muestra cardiorrespiratoria", symbol: "lungs.fill", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "ml/kg/min"),
        .init("auto.fasting", "Ayuno completado", RecvelL10n.text("Sesion de ayuno terminada hoy"), symbol: "timer", category: .automatic, source: .automatic, enabled: true, threshold: 1, unit: "sesion"),

        .init("alcohol", "Alcohol", "Consumo registrado", symbol: "wineglass.fill", category: .lifestyle, period: .nighttime, source: .hybrid, enabled: true, unit: "g"),
        .init("late.caffeine", "Cafeina tarde", RecvelL10n.text("Despues de las 15:00"), symbol: "cup.and.saucer.fill", category: .lifestyle, period: .nighttime, source: .hybrid, enabled: true, unit: "mg"),
        .init("late.meal", "Cena tarde", RecvelL10n.text("Comida cerca de dormir"), symbol: "clock.badge.exclamationmark", category: .lifestyle, period: .nighttime, source: .hybrid, enabled: true),
        .init("screens.night", RecvelL10n.text("Pantallas de noche"), RecvelL10n.text("Luz intensa antes de dormir"), symbol: "iphone", category: .lifestyle, period: .nighttime, enabled: true),
        .init("meditation", "Meditacion", RecvelL10n.text("Al menos 10 minutos"), symbol: "brain.head.profile", category: .lifestyle, enabled: true),
        .init("hydration", "Hidratacion", "Objetivo personal cumplido", symbol: "drop.fill", category: .lifestyle, source: .hybrid, enabled: true, threshold: 2, unit: "L"),
        .init("daylight", "Luz natural", RecvelL10n.text("Tiempo intencional al exterior"), symbol: "sun.max.fill", category: .lifestyle, enabled: true),
        .init("breathing", "Respiracion guiada", RecvelL10n.text("Practica de respiracion"), symbol: "wind", category: .lifestyle),
        .init("sauna", "Sauna", RecvelL10n.text("Sesion de calor"), symbol: "flame.fill", category: .lifestyle),
        .init("cold.shower", "Ducha fria", RecvelL10n.text("Exposicion breve al frio"), symbol: "snowflake", category: .lifestyle),
        .init("massage", "Masaje", "Terapia manual", symbol: "hand.raised.fill", category: .lifestyle),
        .init("fasting", "Ayuno intermitente", "Sesion completada", symbol: "timer", category: .lifestyle),
        .init("low.carb", RecvelL10n.text("Bajo en carbohidratos"), RecvelL10n.text("Patron alimentario del dia"), symbol: "leaf.fill", category: .lifestyle),
        .init("reading.bed", RecvelL10n.text("Lectura en cama"), RecvelL10n.text("Rutina previa al sueno"), symbol: "book.fill", category: .lifestyle, period: .nighttime),
        .init("sleep.mask", "Antifaz", RecvelL10n.text("Usado durante el sueno"), symbol: "eye.slash.fill", category: .lifestyle, period: .nighttime),
        .init("ear.plugs", RecvelL10n.text("Tapones de oido"), RecvelL10n.text("Usados durante el sueno"), symbol: "ear.fill", category: .lifestyle, period: .nighttime),
        .init("shared.bed", "Cama compartida", RecvelL10n.text("Dormiste con otra persona"), symbol: "person.2.fill", category: .lifestyle, period: .nighttime),
        .init("sleep.interruption", RecvelL10n.text("Interrupcion del sueno"), "Despertar relevante", symbol: "moon.zzz.fill", category: .lifestyle, period: .nighttime),

        .init("sickness", "Enfermedad", "Sintomas generales", symbol: "cross.case.fill", category: .health),
        .init("injury", "Lesion", "Molestia o limitacion fisica", symbol: "bandage.fill", category: .health),
        .init("fever", "Fiebre", "Temperatura elevada reportada", symbol: "thermometer.high", category: .health),
        .init("seasonal.allergy", "Alergia estacional", "Sintomas ambientales", symbol: "allergens.fill", category: .health),
        .init("pain", "Dolor", RecvelL10n.text("Dolor que afecto tu dia"), symbol: "bolt.trianglebadge.exclamationmark.fill", category: .health),
        .init("headache", RecvelL10n.text("Dolor de cabeza"), "Cefalea reportada", symbol: "brain.fill", category: .health),
        .init("low.mood", "Animo desagradable", RecvelL10n.text("Auto-reporte, no inferencia"), symbol: "cloud.rain.fill", category: .health),

        .init("magnesium", "Magnesio", "Suplemento registrado", symbol: "pills.fill", category: .medication, period: .nighttime, sensitive: true),
        .init("melatonin", "Melatonina", RecvelL10n.text("Ayuda de sueno registrada"), symbol: "moon.fill", category: .medication, period: .nighttime, sensitive: true),
        .init("sleep.medication", RecvelL10n.text("Medicacion para dormir"), "Uso reportado", symbol: "pills.circle.fill", category: .medication, period: .nighttime, sensitive: true),
        .init("pain.medication", RecvelL10n.text("Medicacion para dolor"), "Uso reportado", symbol: "cross.vial.fill", category: .medication, sensitive: true),
        .init("anxiety.medication", RecvelL10n.text("Medicacion para ansiedad"), "Uso reportado", symbol: "pills.fill", category: .medication, sensitive: true),
        .init("adhd.medication", RecvelL10n.text("Medicacion para TDAH"), "Uso reportado", symbol: "pills.fill", category: .medication, sensitive: true),
        .init("birth.control", "Anticonceptivo", "Uso reportado", symbol: "pills.fill", category: .medication, sensitive: true),
        .init("creatine", "Creatina", "Suplemento registrado", symbol: "bolt.fill", category: .medication, sensitive: true),

        .init("menstruation", "Menstruacion", RecvelL10n.text("Registro del ciclo"), symbol: "drop.circle.fill", category: .cycle, sensitive: true),
        .init("pms", "SPM", "Sintomas premenstruales", symbol: "waveform.path", category: .cycle, sensitive: true),
        .init("ovulation", "Ovulacion", RecvelL10n.text("Registro del ciclo"), symbol: "circle.hexagongrid.fill", category: .cycle, sensitive: true),
        .init("cramps", "Calambres abdominales", "Sintoma reportado", symbol: "bolt.heart.fill", category: .cycle, sensitive: true),
        .init("sexual.activity", "Actividad sexual", RecvelL10n.text("Registro privado local"), symbol: "heart.circle.fill", category: .cycle, sensitive: true),
        .init("pregnancy", "Embarazo", "Estado reportado", symbol: "figure.and.child.holdinghands", category: .cycle, sensitive: true),

        .init("therapy", "Terapia", RecvelL10n.text("Sesion de apoyo"), symbol: "person.2.wave.2.fill", category: .personal, sensitive: true),
        .init("tobacco", "Tabaco", "Consumo reportado", symbol: "smoke.fill", category: .personal, sensitive: true),
        .init("cannabis", "Cannabis", "Consumo reportado", symbol: "leaf.circle.fill", category: .personal, sensitive: true)
    ]

    static func definition(for id: String) -> JournalTagDefinition? {
        builtIns.first { $0.id == id }
    }

    static func legacyID(for name: String) -> String? {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let aliases: [String: String] = [
            "alcohol": "alcohol",
            "cafeina tarde": "late.caffeine",
            "cena tarde": "late.meal",
            "pantallas noche": "screens.night",
            "meditacion": "meditation",
            "hidratacion": "hydration",
            "luz natural": "daylight"
        ]
        return aliases[normalized]
    }
}

struct JournalResolvedTag: Identifiable {
    let definition: JournalTagDefinition
    let configuration: JournalTagConfiguration?

    var id: String { definition.id }
    var title: String { configuration?.customTitle ?? definition.localizedTitle }
    var symbol: String { configuration?.customSymbol ?? definition.symbol }
    var isEnabled: Bool { configuration?.isEnabled ?? definition.defaultEnabled }
    var isPinned: Bool { configuration?.isPinned ?? false }
    var threshold: Double? { configuration?.threshold ?? definition.defaultThreshold }
    var period: JournalTagPeriod { JournalTagPeriod(rawValue: configuration?.periodRaw ?? "") ?? definition.period }
    var source: JournalTagSource { JournalTagSource(rawValue: configuration?.sourceRaw ?? "") ?? definition.source }
}

struct JournalAutoSignal: Identifiable, Equatable {
    let tagID: String
    let answer: Bool
    let value: Double?
    let displayValue: String
    let source: String
    var id: String { tagID }
}

enum JournalDayEngine {
    static func journalDay(for date: Date, wakeMinutes: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let boundary = calendar.date(byAdding: .minute, value: wakeMinutes, to: start) ?? start
        if date < boundary {
            return calendar.date(byAdding: .day, value: -1, to: start) ?? start
        }
        return start
    }
}

enum JournalAutoEntryEngine {
    static func signals(
        snapshot: DailyHealthSnapshot?,
        score: DailyScoreRecord?,
        meals: [MealLog],
        stress: StressAssessment?,
        tags: [JournalResolvedTag],
        fastingCompleted: Bool = false,
        calendar: Calendar = .current
    ) -> [JournalAutoSignal] {
        guard let snapshot else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        var result: [JournalAutoSignal] = []

        func append(
            _ id: String,
            value: Double?,
            display: String,
            source: String = "Apple Health",
            answerOverride: Bool? = nil
        ) {
            guard let tag = lookup[id], tag.isEnabled, let value else { return }
            let answer = answerOverride ?? (value >= (tag.threshold ?? 0))
            result.append(JournalAutoSignal(tagID: id, answer: answer, value: value, displayValue: display, source: source))
        }

        append("auto.steps", value: snapshot.steps.map(Double.init), display: snapshot.steps.map { "\($0.formatted(.number.locale(RecvelL10n.locale))) pasos" } ?? "")
        let cardioMinutes = snapshot.workoutMinutes ?? (snapshot.workouts.isEmpty ? nil : 0)
        append("auto.cardio", value: cardioMinutes, display: cardioMinutes.map { "\(Int($0.rounded())) min" } ?? "")
        append("auto.daylight", value: snapshot.daylightMinutes, display: snapshot.daylightMinutes.map { "\(Int($0.rounded())) min" } ?? "")
        let strength = snapshot.workouts.filter { $0.activityName.localizedCaseInsensitiveContains("fuerza") || $0.activityName.localizedCaseInsensitiveContains("strength") }
            .reduce(0) { $0 + $1.durationMinutes }
        if !snapshot.workouts.isEmpty || strength > 0 {
            append("auto.strength", value: strength, display: "\(Int(strength.rounded())) min")
        }
        let zone2 = snapshot.workouts.flatMap(\.zones).filter { $0.zone == 2 }.reduce(0) { $0 + $1.minutes }
        if !snapshot.workouts.isEmpty || zone2 > 0 {
            append("auto.zone2", value: zone2, display: "\(Int(zone2.rounded())) min")
        }
        append("auto.mindful", value: snapshot.mindfulMinutes, display: snapshot.mindfulMinutes.map { "\(Int($0.rounded())) min" } ?? "")
        let napMinutes = snapshot.sleepDetails.map { $0.napHours * 60 }
        append("auto.nap", value: napMinutes, display: napMinutes.map { "\(Int($0.rounded())) min" } ?? "")
        append("auto.stress", value: stress?.score.map(Double.init), display: stress?.score.map { "\($0) pts" } ?? "", source: "Recvel")
        if !meals.isEmpty {
            append("auto.nutrition", value: Double(meals.count), display: "\(meals.count) comidas", source: "Recvel")
        }
        if let score, let tag = lookup["auto.overreach"], tag.isEnabled {
            let target = max(35, min(85, score.recovery + 5))
            result.append(JournalAutoSignal(
                tagID: tag.id,
                answer: score.strain > target,
                value: Double(score.strain),
                displayValue: "\(score.strain) / objetivo \(target)",
                source: "Recvel"
            ))
        }

        append(
            "auto.sleep",
            value: snapshot.sleepHours,
            display: snapshot.sleepHours.map { String(format: "%.1f h" , $0) } ?? "",
            answerOverride: (snapshot.sleepHours ?? 0) > 0
        )
        if let score {
            append(
                "auto.recovery",
                value: Double(score.recovery),
                display: "\(score.recovery) pts",
                source: "Recvel",
                answerOverride: score.recovery >= Int(lookup["auto.recovery"]?.threshold ?? 67)
            )
        }
        append(
            "auto.hrv",
            value: snapshot.hrv,
            display: snapshot.hrv.map { "\(Int($0.rounded())) ms" } ?? "",
            answerOverride: snapshot.hrv != nil
        )
        append(
            "auto.rhr",
            value: snapshot.restingHeartRate,
            display: snapshot.restingHeartRate.map { "\(Int($0.rounded())) lpm" } ?? "",
            answerOverride: snapshot.restingHeartRate != nil
        )
        if let vo2 = snapshot.vo2Max, let vo2Date = snapshot.vo2MaxDate, calendar.isDate(vo2Date, inSameDayAs: snapshot.date) {
            append("auto.vo2", value: vo2, display: String(format: "%.1f", vo2), answerOverride: true)
        }
        if fastingCompleted {
            append("auto.fasting", value: 1, display: "Completado", source: "Recvel", answerOverride: true)
        }
        return result
    }
}

/// Calendar / week-strip activity: manual check-ins plus Health-derived automatic data.
enum JournalActivityEngine {
    /// True when the day has measurable automatic health activity (even with zero manual logs).
    static func hasAutomaticHealthData(_ snapshot: DailyHealthSnapshot?) -> Bool {
        guard let snapshot else { return false }
        if let steps = snapshot.steps, steps > 0 { return true }
        if let sleep = snapshot.sleepHours, sleep > 0 { return true }
        if let minutes = snapshot.workoutMinutes, minutes > 0 { return true }
        if !snapshot.workouts.isEmpty { return true }
        if let mindful = snapshot.mindfulMinutes, mindful > 0 { return true }
        if let daylight = snapshot.daylightMinutes, daylight > 0 { return true }
        if snapshot.hrv != nil || snapshot.restingHeartRate != nil { return true }
        if let energy = snapshot.activeEnergy, energy > 0 { return true }
        if let nap = snapshot.sleepDetails?.napHours, nap > 0 { return true }
        return false
    }

    static func hasAutomaticSignals(_ signals: [JournalAutoSignal]) -> Bool {
        !signals.isEmpty
    }

    static func dayHasActivity(
        manualAnswerCount: Int,
        hasAutomaticData: Bool
    ) -> Bool {
        manualAnswerCount > 0 || hasAutomaticData
    }

    static func completionState(
        manualTags: [JournalResolvedTag],
        logs: [HabitLog],
        day: Date,
        hasAutomaticData: Bool,
        calendar: Calendar = .current
    ) -> JournalCompletionState {
        let manual = manualTags.filter { $0.source != .automatic }
        let answered = manual.filter { tag in
            logs.contains { calendar.isDate($0.date, inSameDayAs: day) && JournalProImpactEngine.resolvedID($0) == tag.id }
        }.count

        if manual.isEmpty {
            return hasAutomaticData ? .partial : .none
        }
        if answered == 0 {
            return hasAutomaticData ? .partial : .none
        }
        if answered == manual.count { return .complete }
        return .partial
    }
}

enum JournalInsightMetric: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case sleep = "Sleep"
    var id: String { rawValue }
    var displayName: String { self == .recovery ? ScoreKind.recovery.displayName : ScoreKind.sleep.displayName }
}

struct JournalTagImpact: Identifiable, Equatable {
    let tagID: String
    let title: String
    let association: JournalAssociation
    var id: String { tagID }
}

enum JournalProImpactEngine {
    static func impacts(
        tags: [JournalResolvedTag],
        logs: [HabitLog],
        scores: [DailyScoreRecord],
        metric: JournalInsightMetric,
        calendar: Calendar = .current
    ) -> [JournalTagImpact] {
        tags.compactMap { tag in
            let pairs = logs.filter { resolvedID($0) == tag.id }.compactMap { log -> (Bool, Int)? in
                guard let score = scores.first(where: { calendar.isDate($0.date, inSameDayAs: log.date) }) else { return nil }
                return (log.answer, metric == .recovery ? score.recovery : score.sleep)
            }
            guard !pairs.isEmpty else { return nil }
            return JournalTagImpact(tagID: tag.id, title: tag.title, association: JournalImpactEngine.association(pairs: pairs))
        }
        .sorted {
            abs($0.association.delta ?? 0) > abs($1.association.delta ?? 0)
        }
    }

    static func resolvedID(_ log: HabitLog) -> String {
        log.tagID ?? JournalCatalog.legacyID(for: log.habit) ?? log.habit
    }
}
