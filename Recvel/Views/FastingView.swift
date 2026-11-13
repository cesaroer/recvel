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
        case .circadian: RecvelL10n.text("fasting.protocol.circadian")
        case .sixteen8: "16:8"
        case .eighteen6: "18:6"
        case .twenty4: "20:4"
        case .omad: "OMAD"
        case .custom: RecvelL10n.text("fasting.protocol.custom")
        }
    }

    var subtitle: String {
        switch self {
        case .circadian: RecvelL10n.text("fasting.window.12")
        case .sixteen8: RecvelL10n.text("fasting.window.16")
        case .eighteen6: RecvelL10n.text("fasting.window.18")
        case .twenty4: RecvelL10n.text("fasting.window.20")
        case .omad: RecvelL10n.text("fasting.window.omad")
        case .custom: RecvelL10n.text("fasting.window.custom")
        }
    }

    /// Descripcion breve del protocolo para la tarjeta visual del selector.
    var description: String {
        switch self {
        case .circadian: RecvelL10n.text("fasting.detail.circadian")
        case .sixteen8: RecvelL10n.text("fasting.detail.16")
        case .eighteen6: RecvelL10n.text("fasting.detail.18")
        case .twenty4: RecvelL10n.text("fasting.detail.20")
        case .omad: RecvelL10n.text("fasting.detail.omad")
        case .custom: RecvelL10n.text("fasting.detail.custom")
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
        case .great: RecvelL10n.text("fasting.mood.great")
        case .tired: RecvelL10n.text("fasting.mood.tired")
        case .headache: RecvelL10n.text("fasting.symptom.headache")
        case .irritable: RecvelL10n.text("fasting.mood.irritable")
        case .energized: RecvelL10n.text("fasting.mood.energized")
        case .dizzy: RecvelL10n.text("fasting.mood.dizzy")
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

/// Asociación personal entre ayunar y la Recuperación del día siguiente.
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
            name: RecvelL10n.text("fasting.phase.digestion"),
            detail: RecvelL10n.text("fasting.phase.digesting"),
            colorKind: .energy
        ),
        FastingPhase(
            id: 1,
            startHour: 4,
            name: RecvelL10n.text("fasting.phase.glycogen"),
            detail: RecvelL10n.text("fasting.phase.glycogen.detail"),
            colorKind: .sleep
        ),
        FastingPhase(
            id: 2,
            startHour: 12,
            name: RecvelL10n.text("fasting.phase.fatTransition"),
            detail: RecvelL10n.text("fasting.phase.fat.detail"),
            colorKind: .strain
        ),
        FastingPhase(
            id: 3,
            startHour: 18,
            name: RecvelL10n.text("fasting.phase.lowLiverGlycogen"),
            detail: RecvelL10n.text("fasting.phase.liver.detail"),
            colorKind: .recovery
        ),
        FastingPhase(
            id: 4,
            startHour: 24,
            name: RecvelL10n.text("fasting.phase.autophagy"),
            detail: RecvelL10n.text("fasting.phase.autophagy.detail"),
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
        FastingTip(id: 100, text: RecvelL10n.text("fasting.tip.hydrateBefore"), icon: "drop.fill"),
        FastingTip(id: 101, text: RecvelL10n.text("fasting.tip.dinner"), icon: "leaf.fill"),
        FastingTip(id: 102, text: RecvelL10n.text("fasting.tip.avoidStart"), icon: "moon.zzz.fill"),
    ]

    static let duringFastingTips: [FastingTip] = [
        FastingTip(id: 200, text: RecvelL10n.text("fasting.tip.stayHydrated"), icon: "cup.and.saucer.fill"),
        FastingTip(id: 201, text: RecvelL10n.text("fasting.tip.lightActivity"), icon: "figure.walk"),
        FastingTip(id: 202, text: RecvelL10n.text("fasting.tip.breakIfDizzy"), icon: "heart.fill"),
        FastingTip(id: 203, text: RecvelL10n.text("fasting.tip.distract"), icon: "brain.fill"),
        FastingTip(id: 204, text: RecvelL10n.text("fasting.tip.waves"), icon: "water.waves"),
    ]

    static let postFastingTips: [FastingTip] = [
        FastingTip(id: 300, text: RecvelL10n.text("fasting.tip.breakLight"), icon: "carrot.fill"),
        FastingTip(id: 301, text: RecvelL10n.text("fasting.tip.avoidHeavy"), icon: "fork.knife"),
        FastingTip(id: 302, text: RecvelL10n.text("fasting.tip.wait"), icon: "timer"),
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
        if answers.under18 { blocking.append(RecvelL10n.text("fasting.risk.under18")) }
        if answers.pregnantOrNursing { blocking.append(RecvelL10n.text("fasting.risk.pregnancy")) }
        if answers.eatingDisorderHistory { blocking.append(RecvelL10n.text("fasting.risk.eatingDisorder")) }
        if answers.insulinOrType1Diabetes { blocking.append(RecvelL10n.text("fasting.risk.diabetes")) }
        if answers.underweight { blocking.append(RecvelL10n.text("fasting.risk.underweight")) }

        if !blocking.isEmpty { return .blocked(blocking) }

        if answers.olderAdultOrHeartConditionOrMedication {
            return .caution([RecvelL10n.text("fasting.risk.talkToDoctor")])
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
    @Environment(\.isTabActive) private var isTabActive

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
                WidthLockedScrollView {
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
            // Barra de navegacion fuera del todo, como Hoy / Diario / Nutricion
            // (antes solo se ocultaba el fondo con `.toolbarBackground(.hidden)`
            // y la barra seguia viva). La cabecera la pinta el propio contenido.
            //
            // Nota historica: esto se probo primero como arreglo del "arrastre
            // horizontal de toda la pantalla" y NO era la causa — la causa real
            // era contenido mas ancho que el viewport; ver
            // `scrollContentLockedToViewportWidth()` arriba.
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(timer) { tick in
                // Sin ayuno activo no hay nada que avance, y con la pestaña
                // oculta nadie lo ve: antes este tick redibujaba la pantalla
                // entera cada segundo en ambos casos.
                guard isTabActive, activeSession != nil else { return }
                now = tick
                detectPhaseChange()
            }
            .onChange(of: isTabActive) { _, active in
                if active { now = .now }
            }
            .onChange(of: activeSession?.startDate) { _, _ in
                guard let session = activeSession else { return }
                Task {
                    await FastingLiveActivityManager.synchronize(
                        sessionID: session.id,
                        startDate: session.startDate,
                        targetDate: session.estimatedEndDate,
                        protocolName: session.fastingProtocol.title
                    )
                }
            }
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.82)) {
                    appeared = true
                }
                startGlowAnimation()
                if let session = activeSession {
                    Task {
                        await FastingLiveActivityManager.synchronize(
                            sessionID: session.id,
                            startDate: session.startDate,
                            targetDate: session.estimatedEndDate,
                            protocolName: session.fastingProtocol.title
                        )
                    }
                }
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
            Text(RecvelL10n.text("fasting.intro"))
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
                            centerCaption: targetReached
                                ? RecvelL10n.text("fasting.goalMet")
                                : RecvelL10n.text("fasting.ofTarget", values: ["target": targetText(session.targetHours)]),
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
                            Text(session.estimatedEndDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)))
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
                        Label(session.startDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)), systemImage: "play.circle.fill")
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
        .accessibilityLabel(RecvelL10n.text("fasting.phaseTimeline"))
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
                Text(RecvelL10n.text("fasting.phases.caveat"))
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
                    Text(RecvelL10n.text("fasting.howYouFeel"))
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
                            Text(log.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)))
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
                    Text(RecvelL10n.text("fasting.checkInCap", values: ["max": "\(CheckInLimits.maxPerDay)"]))
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

                Text(RecvelL10n.text("fasting.checkIn.disclaimer"))
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
            Text(RecvelL10n.text("Feeling en este ayuno"))
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
                        Text(RecvelL10n.text("fasting.eatingWindow"))
                            .font(.subheadline.weight(.semibold))
                        Text(RecvelL10n.text("fasting.sinceLast", values: ["elapsed": elapsedText(hoursSince)]))
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
                        Text("~\(estimatedEnd.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)))")
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
                Text(RecvelL10n.text("fasting.pickProtocol"))
                    .font(.headline)

                // Iniciar va ARRIBA: con el protocolo ya elegido, el boton
                // quedaba debajo de seis tarjetas y fuera de pantalla.
                Button {
                    haptic(.medium)
                    if screeningCompleted {
                        startFast()
                    } else {
                        showScreening = true
                    }
                } label: {
                    Label(RecvelL10n.text("fasting.start", values: ["target": targetText(selectedTargetHours)]), systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.strain.color)
                .accessibilityIdentifier("fasting.start")

                ForEach(FastingProtocol.allCases) { proto in
                    protocolCard(proto)
                    if proto == .custom && selectedProtocol == .custom {
                        customHoursSlider
                    }
                }

                estimatedEndHint

                Toggle(isOn: $notifyOnTarget) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(RecvelL10n.text("Avisarme al completar"))
                            .font(.subheadline)
                        Text(RecvelL10n.text("Notificacion local en este dispositivo."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(ScoreKind.recovery.color)
                .accessibilityIdentifier("fasting.notifyToggle")

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
                Text(RecvelL10n.text("fasting.hours"))
            }
            .tint(ScoreKind.strain.color)
            Text(RecvelL10n.text("fasting.customHours", values: ["hours": "\(Int(customHours))"]))
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
            Text(RecvelL10n.text("fasting.estimatedEnd", values: ["time": estimatedEnd.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale))]))
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
                        Text(RecvelL10n.text("fasting.consistency"))
                            .font(.headline)
                        HStack(spacing: 0) {
                            statColumn(value: "\(stats.thisWeekCount)", caption: RecvelL10n.text("fasting.thisWeek"))
                            statDivider
                            statColumn(value: stats.averageHours > 0 ? elapsedText(stats.averageHours) : "—", caption: RecvelL10n.text("fasting.stats.average"))
                            statDivider
                            statColumn(value: stats.longestHours > 0 ? elapsedText(stats.longestHours) : "—", caption: RecvelL10n.text("fasting.stats.longest"))
                            statDivider
                            statColumn(value: "\(stats.totalCompleted)", caption: "Totales")
                        }
                        Text(RecvelL10n.text("fasting.noStreaks"))
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
                        Text(RecvelL10n.text("fasting.firstFast"))
                            .font(.headline)
                        Text(RecvelL10n.text("fasting.firstFast.detail"))
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
                    Text(RecvelL10n.text("common.last7Days"))
                        .font(.headline)
                    Chart(data, id: \.date) { day in
                        BarMark(
                            x: .value(RecvelL10n.text("chart.axis.day"), day.date, unit: .day),
                            y: .value(RecvelL10n.text("chart.axis.hours"), day.hours),
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

    // MARK: Asociación con Recuperación

    private var impactCard: some View {
        let impact = engine.recoveryImpact(
            fasts: completedSessions.compactMap { session in
                session.endDate.map { (session.startDate, $0) }
            },
            recoveryByDay: scoreRecords.map { ($0.date, $0.recovery) }
        )
        return LiquidGlassCard(tint: ScoreKind.recovery.color) {
            VStack(alignment: .leading, spacing: 10) {
                Label(RecvelL10n.text("fasting.andRecovery"), systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.recovery.color)

                if let delta = impact.delta {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%@%.0f", delta >= 0 ? "+" : "", delta))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(delta >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                        Text(RecvelL10n.text("fasting.recoveryDelta"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(RecvelL10n.text("fasting.impact.compare", values: ["fasting": "\(impact.fastingDays)", "other": "\(impact.otherDays)"]))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(RecvelL10n.text("EN PROCESO"))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.tertiary)
                    Text(RecvelL10n.text("fasting.recoveryNeedsData"))
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
                        Text(RecvelL10n.text("common.last30Days"))
                            .font(.headline)
                        Spacer()
                        HStack(spacing: 12) {
                            legendDot(color: Color.white.opacity(0.08), label: RecvelL10n.text("fasting.without"))
                            legendDot(color: ScoreKind.strain.color.opacity(0.45), label: RecvelL10n.text("fasting.legend.belowTarget"))
                            legendDot(color: ScoreKind.recovery.color, label: RecvelL10n.text("fasting.legend.atTarget"))
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
                                .accessibilityLabel("\(day.date.formatted(.dateTime.day().month(.abbreviated).locale(RecvelL10n.locale))): \(day.hours > 0 ? "\(Int(day.hours))h" : "sin ayuno")")
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
                        Text(session.startDate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(RecvelL10n.locale)))
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
                        detailChip(icon: "timer", label: RecvelL10n.text("fasting.detail.duration"), value: elapsedText(elapsed))
                        detailChip(icon: "scope", label: RecvelL10n.text("fasting.detail.phase"), value: phase.name)
                    }
                    HStack(spacing: 16) {
                        if let mood = session.mood {
                            detailChip(icon: "face.smiling", label: RecvelL10n.text("fasting.detail.mood"), value: "\(mood.emoji) \(mood.label)")
                        }
                        detailChip(icon: "target", label: RecvelL10n.text("fasting.detail.target"), value: RecvelL10n.text(reachedTarget ? "fasting.reached" : "fasting.notReached"))
                    }

                    // Recuperación del día siguiente, si hay dato
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: session.startDate))
                    if let nextDay,
                       let record = scoreRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: nextDay) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(ScoreKind.recovery.color)
                            Text("\(ScoreKind.recovery.displayName) · \(RecvelL10n.text("fasting.nextDay")): \(record.recovery)%")
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
                Text(RecvelL10n.text("fasting.whatHappens"))
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
                Text(RecvelL10n.text("fasting.ranges.caveat"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fasting.education")
    }

    private var disclaimer: some View {
        Text(RecvelL10n.text("fasting.disclaimer"))
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
        let session = FastingSession(
            startDate: .now,
            protocolRaw: proto.rawValue,
            targetHours: target
        )
        modelContext.insert(session)
        try? modelContext.save()
        Task {
            await FastingLiveActivityManager.start(
                sessionID: session.id,
                startDate: session.startDate,
                targetDate: session.estimatedEndDate,
                protocolName: proto.title
            )
        }
        if notifyOnTarget {
            scheduleTargetNotification(after: target)
        }
    }

    private func endFast(_ session: FastingSession) {
        session.endDate = .now
        try? modelContext.save()
        Task { await FastingLiveActivityManager.end(sessionID: session.id) }
        cancelTargetNotification()
    }

    private func scheduleTargetNotification(after hours: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted, hours > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = RecvelL10n.text("fasting.notification.title")
            content.body = RecvelL10n.text("fasting.notification.body", values: ["hours": "\(Int(hours))"])
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
                    Text(RecvelL10n.text("fasting.whenDidYouStop"))
                        .font(.headline)
                    DatePicker(
                        RecvelL10n.text("Inicio del ayuno"),
                        selection: Binding(
                            get: { session.startDate },
                            set: { session.startDate = min($0, .now) }
                        ),
                        in: Date.now.addingTimeInterval(-48 * 3600)...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("fasting.startPicker")

                    Text(RecvelL10n.text("fasting.adjustStart.detail"))
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
                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(RecvelL10n.text("fasting.beforeYouStart"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(RecvelL10n.text("fasting.screening.intro"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LiquidGlassCard {
                            VStack(spacing: 4) {
                                toggle(RecvelL10n.text("fasting.gate.under18"), id: "under18", $answers.under18)
                                divider
                                toggle(RecvelL10n.text("fasting.gate.pregnant"), id: "pregnancy", $answers.pregnantOrNursing)
                                divider
                                toggle(RecvelL10n.text("fasting.gate.eatingDisorder"), id: "eatingDisorder", $answers.eatingDisorderHistory)
                                divider
                                toggle(RecvelL10n.text("fasting.gate.diabetes"), id: "insulin", $answers.insulinOrType1Diabetes)
                                divider
                                toggle(RecvelL10n.text("fasting.gate.underweight"), id: "underweight", $answers.underweight)
                                divider
                                toggle(RecvelL10n.text("fasting.gate.olderAdult"), id: "medicalCaution", $answers.olderAdultOrHeartConditionOrMedication)
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
                    Label(RecvelL10n.text("fasting.notRecommended"), systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(ScoreKind.strain.color)
                    ForEach(reasons, id: \.self) { Text("· \($0)").font(.caption) }
                    Text(RecvelL10n.text("fasting.notRecommended.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("fasting.screening.blocked")
        case .caution(let notes):
            LiquidGlassCard(tint: ScoreKind.energy.color) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(RecvelL10n.text("fasting.askYourDoctor"), systemImage: "info.circle.fill")
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
