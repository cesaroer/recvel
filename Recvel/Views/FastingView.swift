import Charts
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - Modelo

/// Protocolos de ayuno estandar de la categoria (Zero/Fastic/BodyFast).
/// Ver Calorie_AI_Research.md seccion 10.7 (que priorizar para v1).
enum FastingProtocol: String, CaseIterable, Identifiable, Codable {
    case circadian
    case sixteen8
    case eighteen6
    case twenty4
    case omad
    case custom

    var id: String { rawValue }

    /// Horas de ayuno objetivo del protocolo. Para `.custom` la vista usa
    /// las horas elegidas por el usuario; este valor es solo el default.
    var targetHours: Double {
        switch self {
        case .circadian: 12
        case .sixteen8: 16
        case .eighteen6: 18
        case .twenty4: 20
        case .omad: 22
        case .custom: 14
        }
    }

    var title: String {
        switch self {
        case .circadian: "Circadiano"
        case .sixteen8: "16:8"
        case .eighteen6: "18:6"
        case .twenty4: "20:4"
        case .omad: "OMAD"
        case .custom: "Personalizado"
        }
    }

    var subtitle: String {
        switch self {
        case .circadian: "12 h de ayuno"
        case .sixteen8: "16 h de ayuno"
        case .eighteen6: "18 h de ayuno"
        case .twenty4: "20 h de ayuno"
        case .omad: "Una comida al dia (~22 h)"
        case .custom: "Elige tus horas"
        }
    }

    /// Descripcion breve del protocolo para la tarjeta visual del selector.
    var description: String {
        switch self {
        case .circadian: "Alineado con tu ritmo circadiano natural. Ideal para empezar."
        case .sixteen8: "El protocolo mas popular. Ventana de 8 h para comer."
        case .eighteen6: "Mas exigente, ventana de 6 h. Para personas con experiencia."
        case .twenty4: "Ventana de 4 h. Requiere disciplina y adaptacion previa."
        case .omad: "Solo una comida diaria. El protocolo mas avanzado."
        case .custom: "Tu defines las horas de ayuno y alimentacion."
        }
    }

    var icon: String {
        switch self {
        case .circadian: "sun.and.horizon.fill"
        case .sixteen8: "clock.fill"
        case .eighteen6: "bolt.fill"
        case .twenty4: "flame.fill"
        case .omad: "star.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    /// Horas de alimentacion (24 - ayuno).
    var eatingHours: Double { 24 - targetHours }
}

/// Sesion de ayuno persistida localmente. Patron similar a MealLog/HabitLog.
/// No hay HKCategoryType nativo de Apple para ayuno (ver Calorie_AI_Research.md 10.4),
/// por eso vive como modelo propio en SwiftData.
@Model
final class FastingSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var protocolRaw: String
    var targetHours: Double
    var moodRaw: String?

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        endDate: Date? = nil,
        protocolRaw: String = FastingProtocol.sixteen8.rawValue,
        targetHours: Double = 16,
        moodRaw: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.protocolRaw = protocolRaw
        self.targetHours = targetHours
        self.moodRaw = moodRaw
    }

    var isActive: Bool { endDate == nil }

    var fastingProtocol: FastingProtocol {
        FastingProtocol(rawValue: protocolRaw) ?? .sixteen8
    }

    var mood: FastingMood? {
        moodRaw.flatMap { FastingMood(rawValue: $0) }
    }

    func elapsedHours(now: Date = .now) -> Double {
        let end = endDate ?? now
        return max(end.timeIntervalSince(startDate) / 3600, 0)
    }

    /// Hora estimada de fin del ayuno.
    var estimatedEndDate: Date {
        startDate.addingTimeInterval(targetHours * 3600)
    }
}

// MARK: - Mood tracking

/// Estados de animo registrables durante el ayuno.
/// Se guardan como String en SwiftData para flexibilidad.
enum FastingMood: String, CaseIterable, Identifiable {
    case great
    case tired
    case headache
    case irritable
    case energized
    case dizzy

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: "😊"
        case .tired: "😴"
        case .headache: "🤕"
        case .irritable: "😤"
        case .energized: "💪"
        case .dizzy: "🥴"
        }
    }

    var label: String {
        switch self {
        case .great: "Bien"
        case .tired: "Cansado"
        case .headache: "Dolor de cabeza"
        case .irritable: "Irritable"
        case .energized: "Energizado"
        case .dizzy: "Mareo"
        }
    }

    /// Valencia para graficas (-2 ... +2). Autoconocimiento, no diagnostico.
    var valence: Double {
        switch self {
        case .great, .energized: 2
        case .tired, .irritable: -1
        case .headache, .dizzy: -2
        }
    }

    var isConcerning: Bool {
        self == .dizzy || self == .headache
    }

    var isLowEnergy: Bool {
        self == .tired || self == .irritable
    }
}

// MARK: - Fases metabolicas (lenguaje matizado por evidencia)

/// Una fase metabolica del ayuno. El texto es deliberadamente matizado:
/// la evidencia en humanos sobre "cuando empieza" cada fase es variable e
/// incompleta (ver Calorie_AI_Research.md 10.3 y 12.4). Nunca se afirma un
/// estado del cuerpo como hecho.
struct FastingPhase: Identifiable, Equatable {
    let id: Int
    let startHour: Double
    let name: String
    let detail: String
    let colorKind: ScoreKind

    var color: Color { colorKind.color }
}

struct FastingStats: Equatable {
    let totalCompleted: Int
    let thisWeekCount: Int
    let averageHours: Double
    let longestHours: Double
}

/// Asociacion personal entre ayunar y el Recovery del dia siguiente.
/// Mismo espiritu que los "Impactos personales" del Journal: asociacion, no causalidad.
struct FastingImpact: Equatable {
    let delta: Double?
    let fastingDays: Int
    let otherDays: Int
}

// MARK: - Tips contextuales

/// Un tip contextual mostrado durante distintos estados del ayuno.
struct FastingTip: Identifiable, Equatable {
    let id: Int
    let text: String
    let icon: String
}

struct FastingEngine {
    /// Fases ordenadas por hora de inicio. Los rangos son estimaciones
    /// poblacionales, no una medicion del usuario.
    static let phases: [FastingPhase] = [
        FastingPhase(
            id: 0,
            startHour: 0,
            name: "Digestion",
            detail: "Tu cuerpo esta procesando tu ultima comida.",
            colorKind: .energy
        ),
        FastingPhase(
            id: 1,
            startHour: 4,
            name: "Uso de glucogeno",
            detail: "Tras varias horas sin comer, el cuerpo suele recurrir mas a sus reservas de glucogeno. El momento exacto varia entre personas.",
            colorKind: .sleep
        ),
        FastingPhase(
            id: 2,
            startHour: 12,
            name: "Transicion a grasa",
            detail: "Alrededor de estas horas la investigacion sugiere que el cuerpo puede movilizar mas grasa, pero depende de tu dieta previa, ejercicio y metabolismo.",
            colorKind: .strain
        ),
        FastingPhase(
            id: 3,
            startHour: 18,
            name: "Glucogeno hepatico bajo",
            detail: "El glucogeno del higado tiende a agotarse alrededor de las 18-24 h; es una de las estimaciones con mejor respaldo fisiologico, aunque sigue siendo individual.",
            colorKind: .recovery
        ),
        FastingPhase(
            id: 4,
            startHour: 24,
            name: "Autofagia (evidencia limitada)",
            detail: "Estudios preliminares en humanos sugieren posibles cambios en marcadores de autofagia, pero la evidencia no es concluyente y proviene mayormente de estudios en animales.",
            colorKind: .recovery
        )
    ]

    func currentPhase(elapsedHours: Double) -> FastingPhase {
        Self.phases.last { elapsedHours >= $0.startHour } ?? Self.phases[0]
    }

    func nextPhase(elapsedHours: Double) -> FastingPhase? {
        Self.phases.first { $0.startHour > elapsedHours }
    }

    func progress(elapsedHours: Double, targetHours: Double) -> Double {
        guard targetHours > 0 else { return 0 }
        return min(elapsedHours / targetHours, 1)
    }

    // MARK: Tips contextuales

    /// Tips genéricos de bienestar, NO afirmaciones médicas.
    /// Tono consistente con AI_CONTEXT.md sección "Lenguaje y seguridad".
    static let preFastingTips: [FastingTip] = [
        FastingTip(id: 100, text: "Hidratate bien antes de empezar. El agua, te o cafe sin azucar son tus aliados.", icon: "drop.fill"),
        FastingTip(id: 101, text: "Una cena con fibra y proteina puede facilitar las primeras horas de ayuno.", icon: "leaf.fill"),
        FastingTip(id: 102, text: "Evita empezar un ayuno largo si dormiste mal o tuviste un dia fisicamente muy exigente.", icon: "moon.zzz.fill"),
    ]

    static let duringFastingTips: [FastingTip] = [
        FastingTip(id: 200, text: "Mantente hidratado. El agua con gas, te verde o cafe negro no rompen el ayuno.", icon: "cup.and.saucer.fill"),
        FastingTip(id: 201, text: "Actividad ligera como caminar puede hacer mas llevadera la espera.", icon: "figure.walk"),
        FastingTip(id: 202, text: "Si sientes mareo, debilidad intensa o confusión, rompe el ayuno. Tu bienestar es primero.", icon: "heart.fill"),
        FastingTip(id: 203, text: "Distraer la mente con una tarea o actividad puede reducir la sensacion de hambre.", icon: "brain.fill"),
        FastingTip(id: 204, text: "El hambre viene en oleadas — suele pasar si le das unos minutos.", icon: "water.waves"),
    ]

    static let postFastingTips: [FastingTip] = [
        FastingTip(id: 300, text: "Rompe el ayuno con algo ligero: fruta, yogurt, un puñado de nueces.", icon: "carrot.fill"),
        FastingTip(id: 301, text: "Evita comidas muy pesadas o procesadas justo al terminar.", icon: "fork.knife"),
        FastingTip(id: 302, text: "Dale a tu cuerpo 15-20 minutos antes de una comida grande.", icon: "timer"),
    ]

    func contextualTip(isActive: Bool, hasCompletedSessions: Bool, elapsedHours: Double, now: Date = .now) -> FastingTip {
        let tips: [FastingTip]
        if isActive {
            tips = Self.duringFastingTips
        } else if hasCompletedSessions {
            tips = Self.postFastingTips + Self.preFastingTips
        } else {
            tips = Self.preFastingTips
        }
        // Rotar por minuto para variedad sin ser aleatorio.
        let index = Int(now.timeIntervalSince1970 / 60) % tips.count
        return tips[index]
    }

    // MARK: Estadisticas neutrales (sin streaks punitivos, ver 12.3)

    func stats(
        completed: [(start: Date, hours: Double)],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FastingStats {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let thisWeek = completed.filter { $0.start >= weekStart }
        let durations = completed.map(\.hours)
        return FastingStats(
            totalCompleted: completed.count,
            thisWeekCount: thisWeek.count,
            averageHours: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            longestHours: durations.max() ?? 0
        )
    }

    /// Horas de ayuno por dia (ultimos `days` dias), atribuidas al dia de inicio.
    func dailyFastingHours(
        sessions: [(start: Date, hours: Double)],
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(date: Date, hours: Double)] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = sessions
                .filter { calendar.isDate($0.start, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.hours }
            return (day, total)
        }
    }

    /// Genera un mapa de los ultimos 30 dias con las horas ayunadas por dia.
    func calendarData(
        sessions: [(start: Date, hours: Double)],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(date: Date, hours: Double)] {
        let today = calendar.startOfDay(for: now)
        return (0..<30).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = sessions
                .filter { calendar.isDate($0.start, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.hours }
            return (day, total)
        }
    }

    /// Compara el Recovery de dias "con ayuno largo la noche anterior" contra el resto.
    /// Un dia D cuenta como dia de ayuno si un ayuno de al menos `minimumHours`
    /// estaba activo a las 3:00 de ese dia (cubre el ayuno nocturno tipico).
    func recoveryImpact(
        fasts: [(start: Date, end: Date)],
        recoveryByDay: [(date: Date, recovery: Int)],
        minimumHours: Double = 14,
        minimumSamples: Int = 3,
        calendar: Calendar = .current
    ) -> FastingImpact {
        let qualifying = fasts.filter { $0.end.timeIntervalSince($0.start) / 3600 >= minimumHours }

        var fastingValues: [Int] = []
        var otherValues: [Int] = []
        for record in recoveryByDay {
            let anchor = calendar.date(
                bySettingHour: 3, minute: 0, second: 0,
                of: calendar.startOfDay(for: record.date)
            ) ?? record.date
            let wasFasting = qualifying.contains { $0.start <= anchor && anchor <= $0.end }
            if wasFasting {
                fastingValues.append(record.recovery)
            } else {
                otherValues.append(record.recovery)
            }
        }

        guard fastingValues.count >= minimumSamples, otherValues.count >= minimumSamples else {
            return FastingImpact(delta: nil, fastingDays: fastingValues.count, otherDays: otherValues.count)
        }
        let fastingAverage = Double(fastingValues.reduce(0, +)) / Double(fastingValues.count)
        let otherAverage = Double(otherValues.reduce(0, +)) / Double(otherValues.count)
        return FastingImpact(
            delta: fastingAverage - otherAverage,
            fastingDays: fastingValues.count,
            otherDays: otherValues.count
        )
    }
}

// MARK: - Screening de seguridad (obligatorio antes de activar el ayuno)

/// Respuestas del screening previo. Basado en las contraindicaciones
/// documentadas en Calorie_AI_Research.md 12.2 y el riesgo de TCA en 12.3.
struct FastingSafetyAnswers: Equatable {
    var under18 = false
    var pregnantOrNursing = false
    var eatingDisorderHistory = false
    var insulinOrType1Diabetes = false
    var underweight = false
    var olderAdultOrHeartConditionOrMedication = false
}

enum FastingSafetyResult: Equatable {
    case clear
    case caution([String])
    case blocked([String])
}

extension FastingEngine {
    /// Evalua el screening. Exclusiones duras vs. avisos de "consulta a tu medico".
    func safetyResult(_ answers: FastingSafetyAnswers) -> FastingSafetyResult {
        var blocking: [String] = []
        if answers.under18 { blocking.append("Eres menor de 18 anos") }
        if answers.pregnantOrNursing { blocking.append("Embarazo o lactancia") }
        if answers.eatingDisorderHistory { blocking.append("Historial de trastorno alimentario") }
        if answers.insulinOrType1Diabetes { blocking.append("Diabetes tipo 1 o uso de insulina/sulfonilureas") }
        if answers.underweight { blocking.append("Bajo peso") }

        if !blocking.isEmpty { return .blocked(blocking) }

        if answers.olderAdultOrHeartConditionOrMedication {
            return .caution(["Habla con tu medico antes de ayunar si eres adulto mayor, tienes una condicion cardiaca o tomas medicamentos que requieren horario con alimentos."])
        }
        return .clear
    }
}

// MARK: - Vista principal

struct FastingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FastingSession.startDate, order: .reverse) private var sessions: [FastingSession]
    @Query(sort: \FastingFeelingLog.date, order: .forward) private var feelingLogs: [FastingFeelingLog]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]
    @AppStorage("fastingScreeningCompleted") private var screeningCompleted = false
    @AppStorage("fastingSelectedProtocol") private var selectedProtocolRaw = FastingProtocol.sixteen8.rawValue
    @AppStorage("fastingCustomHours") private var customHours = 14.0
    @AppStorage("fastingNotifyOnTarget") private var notifyOnTarget = false

    @State private var showScreening = false
    @State private var showStartAdjustment = false
    @State private var now = Date.now
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var celebrationScale: CGFloat = 1
    @State private var previousPhaseId: Int?
    @State private var expandedHistoryId: UUID?
    private let engine = FastingEngine()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeSession: FastingSession? { sessions.first { $0.isActive } }
    private var completedSessions: [FastingSession] { sessions.filter { !$0.isActive && $0.endDate != nil } }
    private var selectedProtocol: FastingProtocol {
        FastingProtocol(rawValue: selectedProtocolRaw) ?? .sixteen8
    }
    private var selectedTargetHours: Double {
        selectedProtocol == .custom ? customHours : selectedProtocol.targetHours
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        entrance(0) { header }
                        if let session = activeSession {
                            entrance(1) { activeCard(session) }
                            entrance(2) { moodCard(session) }
                            entrance(3) { tipCard }
                        } else {
                            entrance(1) { quickStartCard }
                            entrance(2) { eatingWindowCard }
                            entrance(3) { idleCard }
                            entrance(4) { tipCard }
                        }
                        entrance(5) { statsCard }
                        entrance(6) { weeklyChartCard }
                        entrance(7) { impactCard }
                        entrance(8) { calendarCard }
                        if activeSession == nil { entrance(9) { educationCard } }
                        entrance(10) { disclaimer }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fasting.scroll")
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onReceive(timer) { tick in
                now = tick
                detectPhaseChange()
            }
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.82)) {
                    appeared = true
                }
                startGlowAnimation()
            }
            .sheet(isPresented: $showScreening) {
                FastingScreeningView(engine: engine) { passed in
                    screeningCompleted = passed
                    showScreening = false
                    if passed { startFast() }
                }
            }
            .sheet(isPresented: $showStartAdjustment) {
                if let session = activeSession {
                    FastingStartAdjustmentView(session: session)
                        .presentationDetents([.height(320)])
                }
            }
        }
    }

    // MARK: Entrance animation (patron del Dashboard)

    private func entrance<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
            .animation(
                reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.84).delay(Double(index) * 0.055),
                value: appeared
            )
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AYUNO INTERMITENTE")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(ScoreKind.strain.color)
            Text("Ayuno")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Un metodo alternativo de alimentacion, no necesariamente mas efectivo que otras formas de cuidar tu dieta.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityIdentifier("fasting.header")
    }

    // MARK: Ayuno en curso — Hero inmersivo

    private func activeCard(_ session: FastingSession) -> some View {
        let elapsed = session.elapsedHours(now: now)
        let phase = engine.currentPhase(elapsedHours: elapsed)
        let progress = engine.progress(elapsedHours: elapsed, targetHours: session.targetHours)
        let remaining = max(session.targetHours - elapsed, 0)
        let targetReached = elapsed >= session.targetHours

        return VStack(spacing: 16) {
            LiquidGlassCard(tint: phase.color) {
                VStack(spacing: 14) {
                    // Hero ring con glow animado
                    ZStack {
                        ArcGauge(
                            value: progress,
                            color: phase.color,
                            centerText: elapsedText(elapsed),
                            centerCaption: targetReached ? "¡Objetivo cumplido!" : "de \(targetText(session.targetHours))",
                            minLabel: "0 h",
                            maxLabel: targetText(session.targetHours)
                        )
                        .shadow(
                            color: phase.color.opacity(glowPulse ? 0.35 : 0.10),
                            radius: glowPulse ? 22 : 8
                        )
                        .scaleEffect(targetReached ? celebrationScale : 1)

                        if targetReached {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(ScoreKind.recovery.color)
                                .offset(y: -78)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Porcentaje y hora estimada
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(phase.color)
                            Text("Progreso")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity).contentShape(Rectangle())

                        Divider().overlay(Color.white.opacity(0.1)).frame(height: 30)

                        VStack(spacing: 2) {
                            Text(session.estimatedEndDate.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text("Fin estimado")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity).contentShape(Rectangle())

                        Divider().overlay(Color.white.opacity(0.1)).frame(height: 30)

                        VStack(spacing: 2) {
                            Text(remaining > 0 ? elapsedText(remaining) : "✓")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(targetReached ? ScoreKind.recovery.color : .primary)
                            Text(targetReached ? "Cumplido" : "Restante")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                    }

                    phaseTimeline(elapsed: elapsed, target: session.targetHours)

                    // Info de inicio y protocolo
                    HStack {
                        Label(session.startDate.formatted(date: .omitted, time: .shortened), systemImage: "play.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(session.fastingProtocol.title, systemImage: session.fastingProtocol.icon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fasting.activeRing")

            phaseCard(phase: phase, elapsed: elapsed)

            HStack(spacing: 12) {
                Button {
                    showStartAdjustment = true
                } label: {
                    Label("Ajustar inicio", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .accessibilityIdentifier("fasting.adjustStart")

                Button(role: .destructive) {
                    haptic(.medium)
                    endFast(session)
                } label: {
                    Label("Terminar", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.strain.color)
                .accessibilityIdentifier("fasting.end")
            }
        }
    }

    /// Linea de tiempo horizontal con las fases coloreadas y un marcador de
    /// progreso — patron visual comun de la categoria (ver 10.2), con copy honesto.
    private func phaseTimeline(elapsed: Double, target: Double) -> some View {
        let scale = max(target, 24)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(FastingEngine.phases.enumerated()), id: \.element.id) { index, phase in
                            let nextStart = index + 1 < FastingEngine.phases.count
                                ? FastingEngine.phases[index + 1].startHour
                                : scale
                            let width = max((min(nextStart, scale) - phase.startHour) / scale, 0)
                            Capsule()
                                .fill(phase.color.opacity(elapsed >= phase.startHour ? 0.9 : 0.22))
                                .frame(width: max(geo.size.width * width - 2, 4))
                        }
                    }

                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .offset(x: geo.size.width * min(elapsed / scale, 1) - 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)

            HStack {
                ForEach(FastingEngine.phases) { phase in
                    Text("\(Int(phase.startHour))h")
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(elapsed >= phase.startHour ? phase.color : Color.white.opacity(0.35))
                    if phase.id != FastingEngine.phases.last?.id { Spacer() }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Linea de tiempo de fases del ayuno")
        .accessibilityIdentifier("fasting.timeline")
    }

    private func phaseCard(phase: FastingPhase, elapsed: Double) -> some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(phase.color).frame(width: 9, height: 9)
                    Text(phase.name)
                        .font(.headline)
                    Spacer()
                    if let next = engine.nextPhase(elapsedHours: elapsed) {
                        Text("Siguiente: \(next.name) · \(Int(next.startHour)) h")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(phase.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Las fases son estimaciones poblacionales aproximadas, no una medicion de tu cuerpo.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.phase")
    }

    // MARK: Feeling tracking (multi durante ayuno activo, tope 6)

    private func feelingLogs(for session: FastingSession) -> [FastingFeelingLog] {
        feelingLogs.filter { $0.sessionId == session.id }.sorted { $0.date < $1.date }
    }

    private func migrateLegacyMoodIfNeeded(_ session: FastingSession) {
        guard let legacy = session.moodRaw, !legacy.isEmpty else { return }
        let existing = feelingLogs(for: session)
        guard existing.isEmpty else {
            session.moodRaw = nil
            try? modelContext.save()
            return
        }
        modelContext.insert(FastingFeelingLog(
            sessionId: session.id,
            date: session.startDate,
            moodRaw: legacy
        ))
        session.moodRaw = nil
        try? modelContext.save()
    }

    private func moodCard(_ session: FastingSession) -> some View {
        let logs = feelingLogs(for: session)
        let moods = logs.compactMap(\.mood)
        let canAdd = logs.count < CheckInLimits.maxPerDay
        let advice = StressEngine().fastingFeelingAdvice(moods: moods)

        return LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ScoreKind.energy.color)
                    Text("Como te sientes en este ayuno")
                        .font(.headline)
                    Spacer()
                    Text("\(logs.count)/\(CheckInLimits.maxPerDay)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityIdentifier("fasting.feeling.count")
                }

                if !logs.isEmpty {
                    fastingFeelingChart(logs: logs)

                    ForEach(logs.reversed(), id: \.id) { log in
                        HStack(spacing: 8) {
                            Text(log.mood?.emoji ?? "·")
                            Text(log.mood?.label ?? log.moodRaw)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(log.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        .accessibilityIdentifier("fasting.feeling.entry")
                    }
                }

                if canAdd {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(FastingMood.allCases) { mood in
                            Button {
                                haptic(.light)
                                addFeeling(mood, to: session)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(mood.emoji)
                                        .font(.title2)
                                    Text(mood.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity).contentShape(Rectangle())
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("fasting.mood.\(mood.rawValue)")
                        }
                    }
                } else {
                    Text("Llegaste al tope de \(CheckInLimits.maxPerDay) registros en este ayuno.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("fasting.feeling.cap")
                }

                if let advice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(advice.title)
                            .font(.subheadline.weight(.semibold))
                        Text(advice.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if advice.suggestsEnding {
                            Button {
                                endFast(session)
                            } label: {
                                Label("Terminar ayuno", systemImage: "flag.checkered")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ScoreKind.energy.color)
                            .accessibilityIdentifier("fasting.feeling.end")
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ScoreKind.energy.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("fasting.feeling.advice")
                }

                Text("Autoconocimiento sobre como te sientes; no es diagnostico. Si tienes sintomas graves, busca ayuda medica.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.mood")
        .onAppear { migrateLegacyMoodIfNeeded(session) }
    }

    private func fastingFeelingChart(logs: [FastingFeelingLog]) -> some View {
        let points = logs.compactMap { log -> (date: Date, valence: Double)? in
            guard let mood = log.mood else { return nil }
            return (log.date, mood.valence)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Feeling en este ayuno")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Hora", point.date),
                        y: .value("Valencia", point.valence)
                    )
                    .foregroundStyle(ScoreKind.energy.color.opacity(0.7))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Hora", point.date),
                        y: .value("Valencia", point.valence)
                    )
                    .foregroundStyle(ScoreKind.energy.color)
                    .symbolSize(48)
                }
            }
            .chartYScale(domain: -2.5...2.5)
            .chartYAxis {
                AxisMarks(values: [-2, 0, 2]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v > 0 ? "+" : v == 0 ? "0" : "−")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 110)
            .accessibilityIdentifier("fasting.feeling.chart")
        }
    }

    private func addFeeling(_ mood: FastingMood, to session: FastingSession) {
        let logs = feelingLogs(for: session)
        guard logs.count < CheckInLimits.maxPerDay else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            modelContext.insert(FastingFeelingLog(
                sessionId: session.id,
                moodRaw: mood.rawValue
            ))
            // Mantener moodRaw legacy como ultimo feeling (compatibilidad historial).
            session.moodRaw = mood.rawValue
            try? modelContext.save()
        }
    }

    // MARK: Ventana de alimentacion (sin ayuno activo)

    @ViewBuilder
    private var eatingWindowCard: some View {
        if let lastEnd = completedSessions.first?.endDate,
           now.timeIntervalSince(lastEnd) < 24 * 3600 {
            let hoursSince = now.timeIntervalSince(lastEnd) / 3600
            LiquidGlassCard(tint: ScoreKind.energy.color) {
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ScoreKind.energy.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ventana de alimentacion")
                            .font(.subheadline.weight(.semibold))
                        Text("Llevas \(elapsedText(hoursSince)) desde tu ultimo ayuno.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fasting.eatingWindow")
        }
    }

    // MARK: Quick-start

    @ViewBuilder
    private var quickStartCard: some View {
        if let lastSession = completedSessions.first {
            let proto = lastSession.fastingProtocol
            let target = lastSession.targetHours
            let estimatedEnd = Date.now.addingTimeInterval(target * 3600)

            LiquidGlassCard(tint: ScoreKind.strain.color) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ScoreKind.strain.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inicio rapido")
                                .font(.subheadline.weight(.semibold))
                            Text("Repetir \(proto.title) · \(targetText(target))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("~\(estimatedEnd.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        haptic(.medium)
                        selectedProtocolRaw = proto.rawValue
                        if proto == .custom { customHours = target }
                        if screeningCompleted {
                            startFast()
                        } else {
                            showScreening = true
                        }
                    } label: {
                        Label("Empezar ahora", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ScoreKind.strain.color)
                    .accessibilityIdentifier("fasting.quickStart")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Selector de protocolo (idle state) — tarjetas visuales

    private var idleCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Elige tu protocolo")
                    .font(.headline)

                ForEach(FastingProtocol.allCases) { proto in
                    protocolCard(proto)
                    if proto == .custom && selectedProtocol == .custom {
                        customHoursSlider
                    }
                }

                estimatedEndHint

                Toggle(isOn: $notifyOnTarget) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisarme al completar")
                            .font(.subheadline)
                        Text("Notificacion local en este dispositivo.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(ScoreKind.recovery.color)
                .accessibilityIdentifier("fasting.notifyToggle")

                Button {
                    haptic(.medium)
                    if screeningCompleted {
                        startFast()
                    } else {
                        showScreening = true
                    }
                } label: {
                    Label("Empezar ayuno de \(targetText(selectedTargetHours))", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.strain.color)
                .accessibilityIdentifier("fasting.start")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.idle")
    }

    private func protocolCard(_ proto: FastingProtocol) -> some View {
        let isSelected = selectedProtocol == proto
        let effectiveTarget = proto == .custom ? customHours : proto.targetHours

        return Button {
            haptic(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selectedProtocolRaw = proto.rawValue
            }
        } label: {
            protocolCardLabel(proto: proto, isSelected: isSelected, target: effectiveTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fasting.protocol.\(proto.rawValue)")
    }

    private func protocolCardLabel(proto: FastingProtocol, isSelected: Bool, target: Double) -> some View {
        let eating = 24 - target
        let selectionShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: proto.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? ScoreKind.strain.color : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(proto.title)
                        .font(.subheadline.weight(.semibold))
                    Text(proto.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(ScoreKind.strain.color) : AnyShapeStyle(.tertiary))
                    .font(.body)
            }

            fastEatProportionBar(target: target, eating: eating, isSelected: isSelected)

            HStack {
                Text("\(Int(target))h ayuno")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ScoreKind.strain.color.opacity(isSelected ? 1 : 0.5))
                Spacer()
                Text("\(Int(eating))h comer")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ScoreKind.recovery.color.opacity(isSelected ? 1 : 0.5))
            }
        }
        .padding(12)
        .background {
            selectionShape.fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
        }
        .overlay {
            selectionShape.strokeBorder(
                isSelected ? ScoreKind.strain.color.opacity(0.35) : Color.white.opacity(0.06),
                lineWidth: 1
            )
        }
        .contentShape(Rectangle())
    }

    /// Barra de proporcion ayuno vs alimentacion en 24 h.
    private func fastEatProportionBar(target: Double, eating: Double, isSelected: Bool) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                Capsule()
                    .fill(ScoreKind.strain.color.opacity(isSelected ? 0.7 : 0.3))
                    .frame(width: geo.size.width * (target / 24))
                Capsule()
                    .fill(ScoreKind.recovery.color.opacity(isSelected ? 0.5 : 0.18))
                    .frame(width: geo.size.width * (max(eating, 0) / 24))
            }
        }
        .frame(height: 6)
    }

    private var customHoursSlider: some View {
        VStack(spacing: 8) {
            Slider(value: $customHours, in: 12...36, step: 1) {
                Text("Horas de ayuno")
            }
            .tint(ScoreKind.strain.color)
            Text("\(Int(customHours)) horas de ayuno")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .accessibilityIdentifier("fasting.customHours")
    }

    private var estimatedEndHint: some View {
        let estimatedEnd = Date.now.addingTimeInterval(selectedTargetHours * 3600)
        return HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("Si empiezas ahora, terminarias ~\(estimatedEnd.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: Tips contextuales

    private var tipCard: some View {
        let tip = engine.contextualTip(
            isActive: activeSession != nil,
            hasCompletedSessions: !completedSessions.isEmpty,
            elapsedHours: activeSession?.elapsedHours(now: now) ?? 0,
            now: now
        )
        return LiquidGlassCard {
            HStack(spacing: 12) {
                Image(systemName: tip.icon)
                    .font(.title3)
                    .foregroundStyle(ScoreKind.sleep.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Consejo")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(ScoreKind.sleep.color)
                    Text(tip.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.tip")
    }

    // MARK: Estadisticas (framing neutral, sin presion de racha — regla 12.3)

    private var statsCard: some View {
        let stats = engine.stats(
            completed: completedSessions.map { ($0.startDate, $0.elapsedHours()) },
            now: now
        )
        return Group {
            if stats.totalCompleted > 0 {
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tu constancia")
                            .font(.headline)
                        HStack(spacing: 0) {
                            statColumn(value: "\(stats.thisWeekCount)", caption: "Esta semana")
                            statDivider
                            statColumn(value: stats.averageHours > 0 ? elapsedText(stats.averageHours) : "—", caption: "Promedio")
                            statDivider
                            statColumn(value: stats.longestHours > 0 ? elapsedText(stats.longestHours) : "—", caption: "Mas largo")
                            statDivider
                            statColumn(value: "\(stats.totalCompleted)", caption: "Totales")
                        }
                        Text("Sin rachas ni castigos: saltarte un dia no borra tu progreso.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fasting.stats")
            } else {
                // Empty state — sin historial aun
                LiquidGlassCard {
                    VStack(spacing: 14) {
                        Image(systemName: "timer.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(ScoreKind.strain.color.opacity(0.5))
                        Text("Tu primer ayuno")
                            .font(.headline)
                        Text("Empieza cuando quieras. Aqui veras tus estadisticas: promedio, constancia y tu registro mas largo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                    .padding(.vertical, 8)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fasting.emptyState")
            }
        }
    }

    private func statColumn(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).contentShape(Rectangle())
    }

    private var statDivider: some View {
        Divider().overlay(Color.white.opacity(0.1)).frame(height: 34)
    }

    // MARK: Grafica semanal

    @ViewBuilder
    private var weeklyChartCard: some View {
        let data = engine.dailyFastingHours(
            sessions: completedSessions.map { ($0.startDate, $0.elapsedHours()) },
            now: now
        )
        if data.contains(where: { $0.hours > 0 }) {
            LiquidGlassCard(tint: ScoreKind.strain.color) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ultimos 7 dias")
                        .font(.headline)
                    Chart(data, id: \.date) { day in
                        BarMark(
                            x: .value("Dia", day.date, unit: .day),
                            y: .value("Horas", day.hours),
                            width: .fixed(14)
                        )
                        .foregroundStyle(ScoreKind.strain.color.gradient)
                        .cornerRadius(7)

                        RuleMark(y: .value("Objetivo", selectedTargetHours))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .chartYScale(domain: 0...max(24, selectedTargetHours + 2))
                    .frame(height: 150)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fasting.weeklyChart")
        }
    }

    // MARK: Asociacion con Recovery (el diferenciador de Recvel, ver 10.7)

    private var impactCard: some View {
        let impact = engine.recoveryImpact(
            fasts: completedSessions.compactMap { session in
                session.endDate.map { (session.startDate, $0) }
            },
            recoveryByDay: scoreRecords.map { ($0.date, $0.recovery) }
        )
        return LiquidGlassCard(tint: ScoreKind.recovery.color) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Ayuno y tu Recovery", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.recovery.color)

                if let delta = impact.delta {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%@%.0f", delta >= 0 ? "+" : "", delta))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(delta >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                        Text("pts de Recovery en promedio tras ayunos de 14 h o mas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Comparado en \(impact.fastingDays) dias con ayuno vs \(impact.otherDays) sin. Es una asociacion personal, no demuestra causalidad.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("EN PROCESO")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.tertiary)
                    Text("Cuando acumules al menos 3 dias con ayuno de 14 h o mas y 3 sin (con Recovery registrado), Recvel comparara como responde tu cuerpo. Ninguna app de ayuno hace esto con tus datos reales.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.impact")
    }

    // MARK: Calendario de 30 dias

    @ViewBuilder
    private var calendarCard: some View {
        let calData = engine.calendarData(
            sessions: completedSessions.map { ($0.startDate, $0.elapsedHours()) },
            now: now
        )
        let hasAnyData = calData.contains { $0.hours > 0 }

        if hasAnyData {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ultimos 30 dias")
                            .font(.headline)
                        Spacer()
                        HStack(spacing: 12) {
                            legendDot(color: Color.white.opacity(0.08), label: "Sin")
                            legendDot(color: ScoreKind.strain.color.opacity(0.45), label: "< Obj.")
                            legendDot(color: ScoreKind.recovery.color, label: "≥ Obj.")
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(calData, id: \.date) { day in
                            let dayColor: Color = {
                                if day.hours <= 0 { return Color.white.opacity(0.06) }
                                if day.hours >= selectedTargetHours { return ScoreKind.recovery.color.opacity(0.75) }
                                return ScoreKind.strain.color.opacity(0.45)
                            }()

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(dayColor)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if Calendar.current.isDateInToday(day.date) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                                    }
                                }
                                .accessibilityLabel("\(day.date.formatted(.dateTime.day().month(.abbreviated))): \(day.hours > 0 ? "\(Int(day.hours))h" : "sin ayuno")")
                        }
                    }

                    // Historial expandible de los mas recientes
                    let recentCompleted = Array(completedSessions.prefix(5))
                    if !recentCompleted.isEmpty {
                        Divider().overlay(Color.white.opacity(0.07))
                        ForEach(recentCompleted) { session in
                            historyRow(session)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fasting.calendar")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    private func historyRow(_ session: FastingSession) -> some View {
        let isExpanded = expandedHistoryId == session.id
        let elapsed = session.elapsedHours()
        let reachedTarget = elapsed >= session.targetHours
        let phase = engine.currentPhase(elapsedHours: elapsed)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expandedHistoryId = isExpanded ? nil : session.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.fastingProtocol.title)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if reachedTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ScoreKind.recovery.color)
                    }
                    Text(elapsedText(elapsed))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        detailChip(icon: "timer", label: "Duracion", value: elapsedText(elapsed))
                        detailChip(icon: "scope", label: "Fase", value: phase.name)
                    }
                    HStack(spacing: 16) {
                        if let mood = session.mood {
                            detailChip(icon: "face.smiling", label: "Mood", value: "\(mood.emoji) \(mood.label)")
                        }
                        detailChip(icon: "target", label: "Objetivo", value: reachedTarget ? "Cumplido ✓" : "No alcanzado")
                    }

                    // Recovery del dia siguiente, si hay dato
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: session.startDate))
                    if let nextDay,
                       let record = scoreRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: nextDay) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(ScoreKind.recovery.color)
                            Text("Recovery dia siguiente: \(record.recovery)%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func detailChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Educacion de fases (estado idle)

    private var educationCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Que pasa durante el ayuno")
                    .font(.headline)
                ForEach(FastingEngine.phases) { phase in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(Int(phase.startHour))h")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(phase.color)
                            .frame(width: 34, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.name)
                                .font(.subheadline.weight(.semibold))
                            Text(phase.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if phase.id != FastingEngine.phases.last?.id {
                        Divider().overlay(Color.white.opacity(0.07))
                    }
                }
                Text("Rangos aproximados de estudios poblacionales; tu cuerpo puede variar.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.education")
    }

    private var disclaimer: some View {
        Text("Recvel es una herramienta de bienestar, no un dispositivo medico. El ayuno no es adecuado para todas las personas; consulta a un profesional de salud si tienes dudas o alguna condicion medica.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }

    // MARK: Acciones

    private func startFast() {
        guard activeSession == nil else { return }
        let proto = selectedProtocol
        let target = selectedTargetHours
        haptic(.medium)
        modelContext.insert(
            FastingSession(
                startDate: .now,
                protocolRaw: proto.rawValue,
                targetHours: target
            )
        )
        try? modelContext.save()
        if notifyOnTarget {
            scheduleTargetNotification(after: target)
        }
    }

    private func endFast(_ session: FastingSession) {
        session.endDate = .now
        try? modelContext.save()
        cancelTargetNotification()
    }

    private func scheduleTargetNotification(after hours: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted, hours > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "Objetivo de ayuno alcanzado"
            content.body = "Completaste tu ventana de \(Int(hours)) h. Rompe el ayuno con calma cuando estes listo."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
            let request = UNNotificationRequest(identifier: "recvel.fasting.target", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelTargetNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["recvel.fasting.target"])
    }

    // MARK: Glow y animaciones

    private func startGlowAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    private func detectPhaseChange() {
        guard let session = activeSession else { return }
        let elapsed = session.elapsedHours(now: now)
        let phase = engine.currentPhase(elapsedHours: elapsed)

        if let prev = previousPhaseId, prev != phase.id {
            haptic(.medium)
        }
        previousPhaseId = phase.id

        // Celebracion al alcanzar el objetivo
        let targetReached = elapsed >= session.targetHours
        if targetReached && celebrationScale == 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                celebrationScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    celebrationScale = 1
                }
            }
            Haptics.success()
        }
    }

    // MARK: Helpers

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: Haptics.light()
        case .medium: Haptics.medium()
        case .heavy: Haptics.heavy()
        case .soft: Haptics.soft()
        case .rigid: Haptics.rigid()
        @unknown default: Haptics.medium()
        }
    }

    private func elapsedText(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    private func targetText(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours)) h" : String(format: "%.1f h", hours)
    }
}

// MARK: - Ajuste de hora de inicio (la gente olvida iniciar el timer)

struct FastingStartAdjustmentView: View {
    @Bindable var session: FastingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 16) {
                    Text("¿A que hora dejaste de comer realmente?")
                        .font(.headline)
                    DatePicker(
                        "Inicio del ayuno",
                        selection: Binding(
                            get: { session.startDate },
                            set: { session.startDate = min($0, .now) }
                        ),
                        in: Date.now.addingTimeInterval(-48 * 3600)...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("fasting.startPicker")

                    Text("Puedes retroceder hasta 48 horas. El progreso y las fases se recalculan al instante.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Ajustar inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        Haptics.soft()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screening de seguridad

struct FastingScreeningView: View {
    let engine: FastingEngine
    let onFinish: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var answers = FastingScreeningView.initialAnswers
    @State private var result: FastingSafetyResult?

    private static var initialAnswers: FastingSafetyAnswers {
        var value = FastingSafetyAnswers()
        if ProcessInfo.processInfo.arguments.contains("-fastingUITestUnder18") {
            value.under18 = true
        }
        return value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Antes de empezar")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("El ayuno no es seguro para todas las personas. Responde con honestidad; tus respuestas se quedan en tu dispositivo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LiquidGlassCard {
                            VStack(spacing: 4) {
                                toggle("Soy menor de 18 anos", id: "under18", $answers.under18)
                                divider
                                toggle("Estoy en embarazo o lactancia", id: "pregnancy", $answers.pregnantOrNursing)
                                divider
                                toggle("Tengo historial de trastorno alimentario", id: "eatingDisorder", $answers.eatingDisorderHistory)
                                divider
                                toggle("Tengo diabetes tipo 1 o uso insulina/sulfonilureas", id: "insulin", $answers.insulinOrType1Diabetes)
                                divider
                                toggle("Tengo bajo peso", id: "underweight", $answers.underweight)
                                divider
                                toggle("Soy adulto mayor, tengo una condicion cardiaca o tomo medicamentos con horario", id: "medicalCaution", $answers.olderAdultOrHeartConditionOrMedication)
                            }
                        }

                        if let result { resultView(result) }

                        Button {
                            evaluate()
                        } label: {
                            Text("Continuar")
                                .frame(maxWidth: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ScoreKind.recovery.color)
                        .accessibilityIdentifier("fasting.screening.continue")
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("fasting.screening")
            }
            .navigationTitle("Seguridad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { Haptics.soft(); onFinish(false) }
                }
            }
        }
    }

    private var divider: some View {
        Divider().overlay(Color.white.opacity(0.07))
    }

    private func toggle(_ label: String, id: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(label, isOn: binding)
                .labelsHidden()
                .tint(ScoreKind.strain.color)
                .accessibilityLabel(label)
                .accessibilityIdentifier("fasting.screening.\(id)")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func resultView(_ result: FastingSafetyResult) -> some View {
        switch result {
        case .blocked(let reasons):
            LiquidGlassCard(tint: ScoreKind.strain.color) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("El ayuno no se recomienda para ti", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(ScoreKind.strain.color)
                    ForEach(reasons, id: \.self) { Text("· \($0)").font(.caption) }
                    Text("Por tu seguridad, Recvel no activara el temporizador de ayuno. Consulta a un profesional de salud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("fasting.screening.blocked")
        case .caution(let notes):
            LiquidGlassCard(tint: ScoreKind.energy.color) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Consulta a tu medico primero", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(ScoreKind.energy.color)
                    ForEach(notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    Button {
                        onFinish(true)
                    } label: {
                        Text("Entiendo, continuar")
                            .frame(maxWidth: .infinity).contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("fasting.screening.acknowledgeCaution")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .clear:
            Color.clear.frame(height: 0)
        }
    }

    private func evaluate() {
        let outcome = engine.safetyResult(answers)
        result = outcome
        if case .clear = outcome {
            onFinish(true)
        }
    }
}
