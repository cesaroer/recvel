import Charts
import SwiftData
import SwiftUI

struct StressHomeCard: View {
    let assessment: StressAssessment
    let activation: [ActivationPoint]
    @State private var reveal = 0.0

    private let engine = StressEngine()
    /// Calm score presentado: 100 = relajado ("Excelente"), anillo lleno = bien.
    private var presentation: StressPresentation { engine.presentation(for: assessment) }
    /// Promedio del dia (no "ahora"): es lo que resume la jornada.
    private var profile: StressDayProfile { engine.dayProfile(activation: activation) }

    private var color: Color {
        switch level {
        case .great: ScoreKind.recovery.color
        case .normal: .cyan
        case .attention: ScoreKind.energy.color
        case .overload: ScoreKind.strain.color
        case .unavailable: .gray
        }
    }

    /// Banda mostrada: la del promedio del dia cuando hay horas suficientes.
    private var level: PhysiologicalStressLevel {
        guard profile.hasEnoughData, let average = profile.average else { return assessment.level }
        return StressDayProfile.band(for: average)
    }

    /// Numero del anillo: promedio del dia en calma (100 = relajado).
    private var displayValue: String {
        guard profile.hasEnoughData, let average = profile.average else { return presentation.displayValue }
        return String(100 - average)
    }

    private var ringProgress: Double {
        guard profile.hasEnoughData, let average = profile.average else { return presentation.ringProgress }
        return Double(100 - average) / 100
    }

    private var caption: String {
        guard profile.hasEnoughData else { return assessment.summary }
        return "Promedio de \(profile.hours) h medidas hoy. Toca para ver el valor actual y las horas."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(RecvelL10n.text("score.stress.title").uppercased(), systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                Text(profile.hasEnoughData ? "PROMEDIO DEL DIA" : "PRESION FISIOLOGICA")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: reveal)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.35), radius: 7)
                    VStack(spacing: 0) {
                        Text(displayValue)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(profile.hasEnoughData ? "PROMEDIO" : "CALMA")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 7) {
                    Text(level.displayName)
                        .font(.title2.weight(.bold))
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    HStack(spacing: 6) {
                        Text("\(RecvelL10n.text("common.confidence")) \(assessment.confidence.displayName.lowercased())")
                        Text("·")
                        Text("\(assessment.baselineDays) d · \(RecvelL10n.text("common.personalBaseline"))")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !activation.isEmpty {
                Chart(activation.suffix(12)) { point in
                    AreaMark(x: .value("Hora", point.date), y: .value("Activacion", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Hora", point.date), y: .value("Activacion", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 54)
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: color)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                reveal = ringProgress
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(RecvelL10n.text("score.stress.title")), \(level.displayName), \(RecvelL10n.text("score.calm.title")) \(displayValue) de 100")
    }
}

struct VO2HomeCard: View {
    let snapshot: DailyHealthSnapshot?

    var body: some View {
        MetricIntelligenceCard(
            eyebrow: "VO2 MAX",
            icon: "lungs.fill",
            value: snapshot?.vo2Max.map { String(format: "%.1f", $0) } ?? "--",
            unit: "ml/kg/min",
            detail: snapshot?.vo2MaxDate.map { "Apple Health · \($0.formatted(.relative(presentation: .named)))" } ?? "Sin estimación reciente",
            color: .cyan
        )
    }
}

struct LegacyBioAgeHomeCard: View {
    let estimate: BioAgeEstimate

    var body: some View {
        MetricIntelligenceCard(
            eyebrow: "EDAD FISIOLÓGICA · BETA",
            icon: "hourglass",
            value: estimate.estimatedYears.map { String(format: "%.0f", $0) } ?? "--",
            unit: "años",
            detail: estimate.deltaYears.map { delta in
                abs(delta) < 0.5 ? "Cerca de tu edad cronológica" : String(format: "%+.0f vs. edad cronológica", delta)
            } ?? "Requiere VO2, edad y sexo",
            color: ScoreKind.recovery.color
        )
    }
}

private struct MetricIntelligenceCard: View {
    let eyebrow: String
    let icon: String
    let value: String
    let unit: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(eyebrow, systemImage: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(unit).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                Text("Ver analisis")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(15)
        .liquidGlass(cornerRadius: 8, tint: color)
    }
}

/// Peticion de sesion de respiracion. Wrapper Identifiable para `.sheet(item:)`.
private struct BreathingRequest: Identifiable {
    let autoStart: Bool
    var id: Bool { autoStart }
}

struct StressDetailView: View {
    let assessment: StressAssessment
    let snapshot: DailyHealthSnapshot
    let history: [DailyHealthSnapshot]
    let activation: [ActivationPoint]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmotionLog.date, order: .reverse) private var emotionLogs: [EmotionLog]
    @Query(sort: \HabitLog.date, order: .reverse) private var habitLogs: [HabitLog]
    @State private var selectedEmotion: StressEmotion?
    @State private var emotionNote = ""
    @State private var showEmotionForm = false
    /// Sesion de respiracion abierta. Es un item (no un Bool) porque lleva
    /// `autoStart` consigo: con `.sheet(isPresented:)` + un @State aparte, el
    /// sheet leia el valor del ciclo anterior y siempre abria el selector.
    @State private var breathingRequest: BreathingRequest?

    private let engine = StressEngine()
    private var presentation: StressPresentation { engine.presentation(for: assessment) }
    /// Perfil del dia: promedio (hero) y actual (tarjeta propia).
    private var profile: StressDayProfile { engine.dayProfile(activation: activation) }

    /// Banda del promedio del dia; sin horas suficientes cae al indice del dia.
    private var displayLevel: PhysiologicalStressLevel {
        guard profile.hasEnoughData, let average = profile.average else { return assessment.level }
        return StressDayProfile.band(for: average)
    }

    private var todayEmotions: [EmotionLog] {
        emotionLogs
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var canAddEmotion: Bool { todayEmotions.count < CheckInLimits.maxPerDay }

    private var hints: [StressHint] {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let habitsToday = habitLogs.filter { $0.answer && calendar.isDateInToday($0.date) }.map(\.habit)
        let habitsYesterday = habitLogs.filter { $0.answer && calendar.isDate($0.date, inSameDayAs: yesterday) }.map(\.habit)
        return engine.stressHints(
            assessment: assessment,
            snapshot: snapshot,
            habitsToday: habitsToday,
            habitsYesterday: habitsYesterday,
            emotionToday: todayEmotions.last?.stressEmotion,
            emotionsToday: todayEmotions.compactMap(\.stressEmotion)
        )
    }

    private var color: Color {
        switch displayLevel {
        case .great: ScoreKind.recovery.color
        case .normal: .cyan
        case .attention: ScoreKind.energy.color
        case .overload: ScoreKind.strain.color
        case .unavailable: .gray
        }
    }

    var body: some View {
        IntelligenceDetailScaffold(title: RecvelL10n.text("score.stress.title"), symbol: "waveform.path.ecg", color: color, identifier: "detail.stress") {
            IntelligenceHero(
                eyebrow: profile.hasEnoughData ? "PROMEDIO DEL DIA" : "PRESION FISIOLOGICA",
                value: heroValue,
                unit: "CALMA",
                status: displayLevel.displayName,
                summary: heroSummary,
                color: color,
                progress: heroProgress
            )

            // Basta una lectura para mostrar "ahora": en la madrugada el
            // promedio del dia aun no existe, pero el valor actual si.
            if profile.current != nil {
                IntelligenceSectionTitle(title: "Ahora", detail: "última hora medida")
                nowCard
            }

            stressScale

            if !assessment.drivers.isEmpty {
                IntelligenceSectionTitle(title: RecvelL10n.text("stress.factors.title"), detail: RecvelL10n.text("common.vsPersonalBaseline"))
                VStack(spacing: 0) {
                    ForEach(Array(assessment.drivers.enumerated()), id: \.element.id) { index, driver in
                        HStack(spacing: 12) {
                            Image(systemName: driver.impact >= 0 ? "arrow.down.right" : "arrow.up.right")
                                .foregroundStyle(driver.impact >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { Text(driver.name).font(.subheadline.weight(.semibold)); Spacer(); Text(driver.value).font(.subheadline.weight(.bold)).monospacedDigit() }
                                Text(driver.baseline).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 13)
                        if index < assessment.drivers.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
                    }
                }
                .padding(.horizontal, 16)
                .liquidGlass(cornerRadius: 8)
                .accessibilityIdentifier("detail.stress.drivers")
            }

            if !activation.isEmpty {
                IntelligenceSectionTitle(title: "Activación del día", detail: "Según tu FC · no forma parte de la puntuación")
                activationChart
            }

            if !hints.isEmpty {
                IntelligenceSectionTitle(title: "Posibles factores", detail: "de tus registros")
                hintsSection
            }

            // Entrypoint permanente de respiracion. Antes solo era alcanzable
            // si aparecia un hint con offersBreathing, asi que en la practica
            // quedaba escondido.
            IntelligenceSectionTitle(title: "Herramientas", detail: "Un minuto para ti")
            breathingEntry

            IntelligenceSectionTitle(
                title: "¿Cómo te sientes?",
                detail: "\(todayEmotions.count)/\(CheckInLimits.maxPerDay) hoy"
            )
            emotionLogger

            if hints.isEmpty { adviceCard }
            scienceCard
        }
        .sheet(item: $breathingRequest) { request in
            BreathingExerciseView(autoStart: request.autoStart)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }

    /// Numero del hero: promedio del dia en calma (100 = relajado).
    private var heroValue: String {
        guard profile.hasEnoughData, let average = profile.average else { return presentation.displayValue }
        return String(100 - average)
    }

    private var heroProgress: Double {
        guard profile.hasEnoughData, let average = profile.average else { return presentation.ringProgress }
        return Double(100 - average) / 100
    }

    private var heroSummary: String {
        guard profile.hasEnoughData else { return assessment.summary }
        return "Promedio de las \(profile.hours) h medidas hoy. El valor de ahora va aparte, abajo."
    }

    /// Estres de ahora, en la gramatica de la tarjeta "Today's stress" de la
    /// referencia: punto de estado + titulo + hora, tres cifras con divisores
    /// finos y un dial de ticks a la derecha con el valor actual.
    private var nowCard: some View {
        StressTodayCard(profile: profile, updatedAt: activation.last?.date)
    }

    /// Tarjeta de acceso a la respiracion guiada, siempre visible.
    private var breathingEntry: some View {
        Button {
            Haptics.soft()
            breathingRequest = BreathingRequest(autoStart: false)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.cyan.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: "wind").font(.headline).foregroundStyle(.cyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Respiración guiada")
                        .font(.subheadline.weight(.bold))
                    Text("Suspiro ciclico, resonancia, cuadrada o 4-7-8")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("Con evidencia citada · 1 a 5 min")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ScoreKind.recovery.color)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 13, tint: .cyan)
            .tappableRounded(13)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.stress.breathingEntry")
    }

    private var stressScale: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 3) {
                ForEach(PhysiologicalStressLevel.allCases.filter { $0 != .unavailable }, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(scaleColor(level))
                        .frame(height: assessment.level == level ? 12 : 7)
                }
            }
            HStack { Text("Excelente"); Spacer(); Text("Normal"); Spacer(); Text("Atencion"); Spacer(); Text("Sobrecarga") }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8)
    }

    /// Barras por hora, en la linea de la referencia: capsulas redondeadas con
    /// degradado suave sobre una pista tenue, paleta fria→ambar (sin el rojo de
    /// alarma) y la media del dia como linea punteada. La activacion es FC
    /// relativa al reposo y NO entra en el indice de estres.
    private var activationChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Por hora")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let average = profile.average {
                    Text("media \(100 - average) calma")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(activation) { point in
                    // yStart/yEnd explicitos: con `y:` Charts APILA las dos
                    // barras de la misma hora y la de color acababa flotando
                    // encima de la pista.
                    BarMark(
                        x: .value("Hora", point.date, unit: .hour),
                        yStart: .value("Base", 0),
                        yEnd: .value("Escala", 2.0),
                        width: .fixed(9)
                    )
                    .cornerRadius(5)
                    .foregroundStyle(Color.white.opacity(0.05))

                    BarMark(
                        x: .value("Hora", point.date, unit: .hour),
                        yStart: .value("Base", 0),
                        yEnd: .value("Activacion", min(point.value, 2.0)),
                        width: .fixed(9)
                    )
                    .cornerRadius(5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barColor(engine.barIntensity(point.value)).opacity(0.95),
                                     barColor(engine.barIntensity(point.value)).opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if let average = profile.average {
                    RuleMark(y: .value("Media", Double(average) / 100 * 2.0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
            }
            .chartYScale(domain: 0...2.0)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)

            HStack(spacing: 14) {
                barLegend(color: barColor(.low), label: "Tranquilo")
                barLegend(color: barColor(.medium), label: "Activo")
                barLegend(color: barColor(.high), label: "Muy activo")
                Spacer()
            }

            Text("Activación estimada con la frecuencia cardíaca. No forma parte de la puntuación de Estrés fisiológico.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .revelCard()
        .accessibilityIdentifier("detail.stress.activation")
    }

    /// Paleta amable: azul/verde → lavanda → ambar. Sin rojo de alarma: la
    /// activacion alta no es un fallo, es actividad.
    private func barColor(_ intensity: StressBarIntensity) -> Color {
        switch intensity {
        case .low: Color(red: 0.42, green: 0.82, blue: 0.78)
        case .medium: Color(red: 0.60, green: 0.58, blue: 0.96)
        case .high: Color(red: 0.98, green: 0.76, blue: 0.42)
        }
    }

    private func barLegend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 8, height: 12)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        }
    }

    // MARK: Hints de posibles factores

    private var hintsSection: some View {
        VStack(spacing: 10) {
            ForEach(hints) { hint in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: hint.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(hintColor(hint.kind))
                        .frame(width: 30, height: 30)
                        .background(hintColor(hint.kind).opacity(0.13), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(hint.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let action = hint.microAction {
                            Text(action)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if hint.offersBreathing {
                            Button {
                                breathingRequest = BreathingRequest(autoStart: true)
                            } label: {
                                Label("1 minuto de respiracion", systemImage: "wind")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                            .accessibilityIdentifier("detail.stress.breathe")
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(cornerRadius: 8)
            }

            Text("Asociaciones con lo que registraste, no un diagnostico de la causa.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.stress.hints")
    }

    private func hintColor(_ kind: StressHint.Kind) -> Color {
        switch kind {
        case .habit: ScoreKind.energy.color
        case .sleep: ScoreKind.sleep.color
        case .emotion: .cyan
        case .positive: ScoreKind.recovery.color
        }
    }

    // MARK: Log de emociones (multi-check-in, tope 6/dia)

    private var emotionLogger: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !todayEmotions.isEmpty {
                emotionTodayChart

                ForEach(todayEmotions.reversed(), id: \.id) { log in
                    HStack(spacing: 9) {
                        Text(log.stressEmotion?.emoji ?? "·")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(log.stressEmotion?.label ?? log.emotion)
                                .font(.caption.weight(.semibold))
                            if !log.note.isEmpty {
                                Text(log.note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(log.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("detail.stress.emotion.entry")
                }
            }

            if showEmotionForm && canAddEmotion {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(StressEmotion.allCases) { emotion in
                        Button {
                            selectedEmotion = selectedEmotion == emotion ? nil : emotion
                        } label: {
                            VStack(spacing: 4) {
                                Text(emotion.emoji).font(.title3)
                                Text(emotion.label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                selectedEmotion == emotion ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 11)
                            )
                            .overlay {
                                if selectedEmotion == emotion {
                                    RoundedRectangle(cornerRadius: 11).strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(emotion.label)
                        .accessibilityIdentifier("detail.stress.emotion.\(emotion.rawValue)")
                    }
                }

                if selectedEmotion != nil {
                    TextField("Nota (opcional): ¿que esta pasando?", text: $emotionNote, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.subheadline)
                        .padding(11)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("detail.stress.emotion.note")

                    Button {
                        saveEmotion()
                    } label: {
                        Label("Guardar registro", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .accessibilityIdentifier("detail.stress.emotion.save")
                }
            } else if canAddEmotion {
                Button {
                    showEmotionForm = true
                    selectedEmotion = nil
                    emotionNote = ""
                } label: {
                    Label("Anadir registro", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .accessibilityIdentifier("detail.stress.emotion.add")
            } else {
                Text("Llegaste al tope de \(CheckInLimits.maxPerDay) registros hoy. Manana puedes seguir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("detail.stress.emotion.cap")
            }

            let recent = emotionLogs.filter { !Calendar.current.isDateInToday($0.date) }.prefix(5)
            if !recent.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                ForEach(Array(recent), id: \.id) { log in
                    HStack(spacing: 9) {
                        Text(log.stressEmotion?.emoji ?? "·")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(log.stressEmotion?.label ?? log.emotion).font(.caption.weight(.semibold))
                            if !log.note.isEmpty { Text(log.note).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                        }
                        Spacer()
                        Text(log.date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Text("Tu registro permanece en el dispositivo y aporta contexto. Recvel no infiere emociones a partir de tus señales. Es una herramienta de autoconocimiento, no de diagnóstico.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.stress.emotion")
    }

    private var emotionTodayChart: some View {
        let points = todayEmotions.compactMap { log -> (date: Date, valence: Double)? in
            guard let emotion = log.stressEmotion else { return nil }
            return (log.date, emotion.valence)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Emociones de hoy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if points.count >= 1 {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Hora", point.date),
                            y: .value("Valencia", point.valence)
                        )
                        .foregroundStyle(Color.cyan.opacity(0.7))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Hora", point.date),
                            y: .value("Valencia", point.valence)
                        )
                        .foregroundStyle(Color.cyan)
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
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: 120)
                .accessibilityIdentifier("detail.stress.emotion.chart")

                if let avg = StressEngine.averageEmotionValence(todayEmotions.compactMap(\.stressEmotion)) {
                    Text(String(format: "Promedio del dia: %.1f", avg))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityIdentifier("detail.stress.emotion.average")
                }
            }
        }
    }

    private func saveEmotion() {
        guard canAddEmotion, let emotion = selectedEmotion else { return }
        let trimmedNote = emotionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(EmotionLog(
            emotion: emotion.rawValue,
            note: trimmedNote,
            linkedStressScore: assessment.score
        ))
        try? modelContext.save()
        selectedEmotion = nil
        emotionNote = ""
        showEmotionForm = false
    }

    private var adviceCard: some View {
        let title: String
        let detail: String
        switch assessment.level {
        case .attention, .overload:
            title = "Haz una pausa para recuperarte"
            detail = "Prueba de 5 a 10 minutos de respiración tranquila o una caminata suave. Observa varias lecturas antes de modificar tu entrenamiento."
        case .great, .normal:
            title = "Protege este estado"
            detail = "Mantén la hidratación, incluye pausas y ajusta la Carga a tu Recuperación y a cómo te sientes."
        case .unavailable:
            title = "Construyendo tu referencia"
            detail = "Usa el Apple Watch durante varios días, especialmente al dormir, para comparar tu HRV y RHR con tu referencia personal."
        }
        return LabelCard(icon: "sparkles", title: title, detail: detail, color: color)
            .accessibilityIdentifier("detail.stress.advice")
    }

    private var scienceCard: some View {
        LabelCard(
            icon: "checkmark.shield.fill",
            title: "Lo que indica esta puntuación",
            detail: "Estima la presión fisiológica con HRV SDNN y RHR frente a tu historial. No mide estrés emocional, ansiedad ni la causa del cambio. El movimiento, el ejercicio, la cafeína, el alcohol, una enfermedad y algunos medicamentos pueden influir.",
            color: .cyan
        )
    }

    private func scaleColor(_ level: PhysiologicalStressLevel) -> Color {
        switch level { case .great: ScoreKind.recovery.color; case .normal: .cyan; case .attention: ScoreKind.energy.color; case .overload: ScoreKind.strain.color; case .unavailable: .gray }
    }
}

struct VO2DetailView: View {
    let snapshot: DailyHealthSnapshot?
    let history: [DailyHealthSnapshot]

    private var points: [VO2Point] {
        history.compactMap { day in day.vo2Max.map { VO2Point(date: day.vo2MaxDate ?? day.date, value: $0) } }
    }

    var body: some View {
        IntelligenceDetailScaffold(title: "VO₂ max", symbol: "lungs.fill", color: .cyan, identifier: "detail.vo2") {
            IntelligenceHero(
                eyebrow: "CAPACIDAD CARDIORRESPIRATORIA",
                value: snapshot?.vo2Max.map { String(format: "%.1f", $0) } ?? "--",
                unit: "ml/kg/min",
                status: freshness,
                summary: "Una estimación de tu capacidad cardiorrespiratoria basada en caminatas, carreras o senderismo al aire libre registrados por Apple Watch.",
                color: .cyan,
                progress: min((snapshot?.vo2Max ?? 0) / 60, 1)
            )

            HStack(spacing: 6) {
                Text("VO₂ max")
                    .font(.subheadline.weight(.semibold))
                ScientificInfoButton(term: .vo2Max)
                Spacer()
            }
            .padding(.horizontal, 2)

            if !points.isEmpty {
                IntelligenceSectionTitle(title: "Tendencia", detail: "Últimos 30 días")
                Chart(points) { point in
                    LineMark(x: .value("Fecha", point.date), y: .value("VO2", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    PointMark(x: .value("Fecha", point.date), y: .value("VO2", point.value)).foregroundStyle(.white)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 190)
                .padding(16)
                .liquidGlass(cornerRadius: 8, tint: .cyan)
                .accessibilityIdentifier("detail.vo2.trend")
            }

            LabelCard(icon: "figure.run", title: "Cómo obtener una nueva estimación", detail: "Haz una caminata, carrera o sesión de senderismo al aire libre de al menos 20 minutos, con buena señal GPS e intensidad suficiente. Apple determina cuándo guardar una muestra.", color: .cyan)
            LabelCard(icon: "info.circle.fill", title: "Es una estimación, no una prueba de laboratorio", detail: "Apple Watch utiliza una predicción submáxima. Es más útil para seguir cambios durante varias semanas que para interpretar decimales o comparar dispositivos.", color: ScoreKind.energy.color)
        }
    }

    private var freshness: String {
        snapshot?.vo2MaxDate.map { "Medido \($0.formatted(.relative(presentation: .named)))" } ?? "Sin muestras en Apple Health"
    }
}

struct LegacyBioAgeDetailView: View {
    let estimate: BioAgeEstimate
    let vo2Snapshot: DailyHealthSnapshot?

    var body: some View {
        IntelligenceDetailScaffold(title: RecvelL10n.text("bioage.title"), symbol: "hourglass", color: ScoreKind.recovery.color, identifier: "detail.bioAge") {
            IntelligenceHero(
                eyebrow: "EDAD CARDIORRESPIRATORIA · BETA",
                value: estimate.estimatedYears.map { String(format: "%.0f", $0) } ?? "--",
                unit: "años",
                status: deltaText,
                summary: estimate.summary,
                color: ScoreKind.recovery.color,
                progress: ageProgress
            )

            HStack(spacing: 0) {
                bioStat("Cronológica", estimate.chronologicalYears.map(String.init) ?? "--")
                Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 50)
                bioStat(RecvelL10n.text("common.confidence"), estimate.confidence.displayName)
                Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 50)
                bioStat("Base", vo2Snapshot?.vo2Max.map { String(format: "%.1f", $0) } ?? "--")
            }
            .padding(.vertical, 15)
            .liquidGlass(cornerRadius: 8)

            if !estimate.factors.isEmpty {
                IntelligenceSectionTitle(title: "Biomarcadores", detail: "metodo actual")
                VStack(spacing: 0) {
                    ForEach(Array(estimate.factors.enumerated()), id: \.element.id) { index, factor in
                        HStack(spacing: 12) {
                            Image(systemName: factor.favorable.map { $0 ? "arrow.up.right" : "arrow.down.right" } ?? "circle.dotted")
                                .foregroundStyle(factor.favorable.map { $0 ? ScoreKind.recovery.color : ScoreKind.energy.color } ?? .cyan)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { Text(factor.name).font(.subheadline.weight(.semibold)); Spacer(); Text(factor.value).font(.subheadline.weight(.bold)).monospacedDigit() }
                                Text(factor.note).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        if index < estimate.factors.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
                    }
                }
                .padding(.horizontal, 16)
                .liquidGlass(cornerRadius: 8)
                .accessibilityIdentifier("detail.bioAge.factors")
            }

            LabelCard(icon: "function", title: "Método transparente", detail: "Esta versión beta compara tu VO₂ máx. de Apple Health con las medianas de las referencias FRIEND por edad y sexo. Los demás biomarcadores aportan contexto, pero todavía no suman ni restan años.", color: .cyan)
            LabelCard(icon: "exclamationmark.shield.fill", title: "No es una edad biologica clinica", detail: "No es PhenoAge, un reloj epigenetico ni una prediccion de longevidad. Sin biomarcadores de laboratorio no afirmamos medir envejecimiento biologico total.", color: ScoreKind.energy.color)
        }
    }

    private var deltaText: String {
        estimate.deltaYears.map { String(format: "%+.0f años vs. edad cronológica", $0) } ?? "Completa edad, sexo y VO₂ máx."
    }

    private var ageProgress: Double {
        guard let age = estimate.estimatedYears else { return 0 }
        return min(max((90 - age) / 70, 0), 1)
    }

    private func bioStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VO2Point: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct IntelligenceDetailScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let symbol: String
    let color: Color
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppBackground()
            LinearGradient(colors: [color.opacity(0.18), .clear, .clear], startPoint: .top, endPoint: .center).ignoresSafeArea()
            // Polvo estelar flotante (lenguaje Bevel, ver StardustField).
            StardustField(count: 70)
                .opacity(0.75)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { content }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(identifier)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .headerCircleChrome(size: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atrás")
            }
            ToolbarItem(placement: .principal) {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .platformGlass(tint: color, shape: .capsule)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct IntelligenceHero: View {
    let eyebrow: String
    let value: String
    let unit: String
    let status: String
    let summary: String
    let color: Color
    let progress: Double
    @State private var reveal = 0.0

    var body: some View {
        VStack(spacing: 12) {
            Text(eyebrow).font(.caption2.weight(.heavy)).foregroundStyle(color)
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 14)
                Circle().trim(from: 0, to: reveal).stroke(AngularGradient(colors: [color.opacity(0.45), color, .white.opacity(0.9)], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90)).shadow(color: color.opacity(0.4), radius: 10)
                VStack(spacing: 1) {
                    Text(value).font(.system(size: 43, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    Text(unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(22)
            }
            .frame(width: 170, height: 170)
            Text(status).font(.headline).multilineTextAlignment(.center)
            Text(summary).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.spring(response: 0.85, dampingFraction: 0.8)) { reveal = min(max(progress, 0), 1) } }
    }
}

private struct IntelligenceSectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            Text(detail).font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
    }
}

private struct LabelCard: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.headline).foregroundStyle(color).frame(width: 38, height: 38).background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: color)
    }
}

// MARK: - Ejercicio de respiracion de 1 minuto
// Micro-accion de los hints ("tomate un minuto"). Puramente visual: ciclos de
// 4 s inhalar / 4 s exhalar durante 60 s. Sin datos, sin permisos.

/// Respiracion guiada estilo Meditopia: elige tecnica y duracion, sigue el
/// circulo, y cada tecnica muestra su evidencia real (y su fuerza).
/// Es 100% local: sin cuenta, sin red, sin permisos.
struct BreathingExerciseView: View {
    /// Tecnica inicial. Por defecto la de mejor evidencia.
    var initialTechnique: BreathingTechnique = .cyclicSigh
    /// Salta el selector y arranca la sesion. Lo usan los accesos donde la
    /// intencion ya es empezar (por ejemplo, un hint de emocion tensa).
    var autoStart: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var technique: BreathingTechnique = .cyclicSigh
    @State private var totalSeconds: Int = 60
    @State private var running = false
    @State private var finished = false
    @State private var secondsLeft = 60
    @State private var phaseIndex = 0
    @State private var phaseRemaining: Double = 0
    @State private var scale: Double = 0.85
    @State private var showEvidence = false
    @State private var cycles = 0

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let durations = [60, 180, 300]

    private var phase: BreathPhase { technique.cycle[min(phaseIndex, technique.cycle.count - 1)] }

    var body: some View {
        ZStack {
            AppBackground()
            StardustField(count: 40).opacity(0.5).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    if running || finished { session } else { setup }
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            technique = initialTechnique
            resetPhase()
            if autoStart { start() }
        }
        .onReceive(tick) { _ in advance() }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("breathing.view")
    }

    // MARK: Setup

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Respiración guiada")
                    .font(.title2.weight(.bold))
                Text("Un minuto puede bajar tu activacion. Elige como.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("TECNICA").font(.system(size: 10, weight: .heavy)).foregroundStyle(.secondary)
                ForEach(BreathingTechnique.allCases) { item in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { technique = item; resetPhase() }
                    } label: {
                        techniqueRow(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("breathing.technique.\(item.rawValue)")
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("DURACION").font(.system(size: 10, weight: .heavy)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(durations, id: \.self) { seconds in
                        Button {
                            Haptics.selection()
                            withAnimation(.snappy(duration: 0.2)) { totalSeconds = seconds }
                        } label: {
                            Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min")
                                .font(.subheadline.weight(totalSeconds == seconds ? .bold : .medium))
                                .foregroundStyle(totalSeconds == seconds ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(totalSeconds == seconds
                                            ? AnyShapeStyle(Color.cyan.opacity(0.22))
                                            : AnyShapeStyle(Color.white.opacity(0.06)))
                                }
                                .tappableRounded(11)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("breathing.duration.\(seconds)")
                    }
                }
            }

            evidenceCard

            Button {
                Haptics.success()
                start()
            } label: {
                Label("Empezar", systemImage: "play.fill")
                    .font(.headline)
                    .primaryCapsuleChrome(tint: .cyan)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("breathing.start")

            Button("Cerrar") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func techniqueRow(_ item: BreathingTechnique) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.subheadline)
                .foregroundStyle(technique == item ? .cyan : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.subheadline.weight(.semibold))
                Text(item.subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.evidenceStrength)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(item == .cyclicSigh
                    ? AnyShapeStyle(ScoreKind.recovery.color)
                    : AnyShapeStyle(.tertiary))
            if technique == item {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.cyan)
            }
        }
        .padding(13)
        .liquidGlass(cornerRadius: 13, tint: technique == item ? .cyan : nil)
        .tappableRounded(13)
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(technique.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.soft()
                withAnimation(.snappy(duration: 0.22)) { showEvidence.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "text.book.closed")
                    Text(showEvidence ? "Ocultar evidencia" : "Ver evidencia")
                    Image(systemName: showEvidence ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.cyan)
                .tappableRounded(6)
            }
            .buttonStyle(.plain)
            if showEvidence {
                Text(technique.evidence)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(cornerRadius: 13)
        .accessibilityIdentifier("breathing.evidence")
    }

    // MARK: Sesion

    private var session: some View {
        VStack(spacing: 26) {
            Text(finished ? RecvelL10n.text("common.done") : phase.kind.displayName)
                .font(.title2.weight(.bold))
                .contentTransition(.opacity)
                .accessibilityIdentifier("breathing.phase")

            ZStack {
                Circle().fill(Color.cyan.opacity(0.10)).frame(width: 210, height: 210)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.42), Color.cyan.opacity(0.14)],
                            center: .center, startRadius: 4, endRadius: 105
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(reduceMotion ? 1 : scale)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                Text(finished ? "✓" : "\(secondsLeft)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(height: 220)

            if finished {
                VStack(spacing: 6) {
                    Text("\(cycles) \(RecvelL10n.text("breathing.cycles")) · \(technique.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Un minuto para ti. Vuelve cuando lo necesites.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(reduceMotion ? phaseHint : "Sigue el circulo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                if finished {
                    Button("Otra vez") { Haptics.soft(); start() }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                }
                Button(finished ? "Cerrar" : "Terminar antes") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(finished ? .secondary : .cyan)
            }
        }
    }

    /// Con Reduce Motion no hay circulo animado: guiamos con texto.
    private var phaseHint: String {
        "\(phase.kind.rawValue) durante \(Int(phase.seconds.rounded())) s"
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - secondsLeft) / Double(totalSeconds)
    }

    // MARK: Motor

    private func start() {
        secondsLeft = totalSeconds
        phaseIndex = 0
        cycles = 0
        finished = false
        running = true
        resetPhase()
        applyScale()
    }

    private func resetPhase() {
        phaseRemaining = technique.cycle[0].seconds
        phaseIndex = 0
        scale = 0.85
    }

    private func advance() {
        guard running, !finished else { return }
        secondsLeft = max(secondsLeft - 1, 0)
        if secondsLeft == 0 {
            finished = true
            Haptics.success()
            return
        }
        phaseRemaining -= 0.1
        if phaseRemaining <= 0 {
            phaseIndex = (phaseIndex + 1) % technique.cycle.count
            if phaseIndex == 0 { cycles += 1 }
            phaseRemaining = phase.seconds
            Haptics.soft()
            applyScale()
        }
    }

    private func applyScale() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: phase.seconds)) { scale = phase.scale }
    }
}

// MARK: - Estres de ahora (tarjeta de la referencia)

/// Estilo de tarjeta de la referencia: relleno plano un punto mas claro que el
/// fondo, radio grande y **sin borde ni degradado**. Es lo que separa sus
/// tarjetas de las nuestras (glass con tinte y hairline).
private struct RevelCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                Color(red: 0.110, green: 0.115, blue: 0.132),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

private extension View {
    func revelCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(RevelCardStyle(cornerRadius: cornerRadius))
    }
}

/// Tarjeta "Estres ahora": replica la de la referencia (punto + titulo + hora,
/// tres cifras con divisores, dial de ticks con el valor actual dentro).
///
/// Habla en **indice de estres** (0 = sin presion, 100 = presion maxima), no en
/// calma: es la lectura del momento, no el resumen del dia que va en el hero.
private struct StressTodayCard: View {
    let profile: StressDayProfile
    let updatedAt: Date?

    private var currentBand: PhysiologicalStressLevel {
        profile.current.map(StressDayProfile.band(for:)) ?? .unavailable
    }

    private var bandColor: Color { StressTodayCard.color(for: currentBand) }

    static func color(for band: PhysiologicalStressLevel) -> Color {
        switch band {
        case .great: Color(red: 0.42, green: 0.82, blue: 0.78)
        case .normal: Color(red: 0.60, green: 0.58, blue: 0.96)
        case .attention: Color(red: 0.98, green: 0.76, blue: 0.42)
        case .overload: Color(red: 0.98, green: 0.55, blue: 0.42)
        case .unavailable: .gray
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(bandColor)
                            .frame(width: 9, height: 9)
                        Text("Estrés ahora")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Text(updatedAt.map { "Actualizado a las \($0.formatted(date: .omitted, time: .shortened))" }
                        ?? "Sin lectura reciente")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    stat(profile.highest, "Más alto", tint: Color(red: 0.98, green: 0.55, blue: 0.42))
                    divider
                    stat(profile.lowest, "Más bajo", tint: Color(red: 0.42, green: 0.82, blue: 0.78))
                    divider
                    stat(profile.hasEnoughData ? profile.average : nil, "Promedio", tint: .white)
                }

                if !profile.hasEnoughData {
                    Text("Llevas \(profile.hours) \(profile.hours == 1 ? "hora medida" : "horas medidas") hoy · el promedio del día aparece a partir de \(StressDayProfile.minimumHours)")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StressTickGauge(
                value: profile.current,
                band: currentBand.displayName,
                color: bandColor
            )
            .frame(width: 104, height: 104)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .revelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estrés ahora \(profile.current.map(String.init) ?? "sin lectura"), \(currentBand.displayName)")
        .accessibilityIdentifier("detail.stress.now")
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 46)
    }

    private func stat(_ value: Int?, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }
}

/// Dial de ticks radiales de la referencia: la escala completa va de frio a
/// calido y solo se enciende hasta el valor; dentro, un disco elevado con la
/// cifra y la banda.
private struct StressTickGauge: View {
    let value: Int?
    let band: String
    let color: Color

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 3
                let progress = Double(value ?? 0) / 100
                let start = 130.0            // arranca abajo-izquierda
                let sweep = 280.0            // deja el hueco inferior, como la referencia
                var step = 0.0
                while step <= sweep {
                    let fraction = step / sweep
                    let radians = Angle.degrees(start + step).radians
                    let dx = CGFloat(cos(radians))
                    let dy = CGFloat(sin(radians))
                    let length: CGFloat = 9
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + dx * (radius - length), y: center.y + dy * (radius - length)))
                    path.addLine(to: CGPoint(x: center.x + dx * radius, y: center.y + dy * radius))
                    // Escala frio → calido; apagada por encima del valor.
                    let scale = Color(
                        hue: 0.42 - 0.42 * fraction,
                        saturation: 0.62,
                        brightness: 0.95
                    )
                    let lit = fraction <= progress
                    context.stroke(
                        path,
                        with: .color(lit ? scale.opacity(0.95) : scale.opacity(0.16)),
                        lineWidth: 2.4
                    )
                    step += 5
                }
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                        center: .init(x: 0.5, y: 0.25), startRadius: 2, endRadius: 46
                    )
                )
                .frame(width: 74, height: 74)

            VStack(spacing: 0) {
                Text(value.map(String.init) ?? "--")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                Text(band)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityHidden(true)
    }
}
