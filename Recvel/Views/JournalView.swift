import Charts
import SwiftData
import SwiftUI

struct LegacyJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitLog.date, order: .reverse) private var logs: [HabitLog]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scores: [DailyScoreRecord]
    @Query(sort: \MentalJournalEntry.date, order: .reverse) private var mentalEntries: [MentalJournalEntry]
    @StateObject private var health = HealthDataProvider()
    @State private var selectedDate = Date.now

    private let habits = HabitSpec.defaults
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        todayOverview
                        dailyCheckIn
                        activityCalendar
                        patternSummary
                        mentalEntryPoint
                        methodology
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await health.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OBSERVA · REGISTRA · AJUSTA")
                .font(.caption2.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(.cyan)
            Text("Journal")
                .font(.system(size: 31, weight: .bold))
            Text("Lo que registraste hoy, las asociaciones que empiezan a aparecer y tu siguiente paso.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityIdentifier("journal.header")
    }

    private var todayOverview: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: Double(answeredToday) / Double(max(habits.count, 1)))
                    .stroke(.cyan.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(answeredToday)/\(habits.count)")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                Text(answeredToday == habits.count ? "Check-in completo" : "Tu registro de hoy")
                    .font(.headline)
                Text(nextAction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityIdentifier("journal.today")
    }

    private var dailyCheckIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-in rapido").font(.headline)
                    Text("Toca Si o No · menos de un minuto")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if answeredToday > 0 {
                    Button("Limpiar", role: .destructive) {
                        logs.filter { calendar.isDateInToday($0.date) }.forEach(modelContext.delete)
                        try? modelContext.save()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            habitGroup("Sueno y recuperacion", habits: habits.filter { $0.group == .recovery })
            Divider().overlay(Color.white.opacity(0.08))
            habitGroup("Ritmo del dia", habits: habits.filter { $0.group == .day })
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("journal.checkIn")
    }

    private func habitGroup(_ title: String, habits: [HabitSpec]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.tertiary)
            ForEach(habits) { habit in
                HStack(spacing: 10) {
                    Image(systemName: habit.icon)
                        .foregroundStyle(habit.color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(habit.name).font(.subheadline.weight(.medium))
                        Text(habit.prompt).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    answerControl(for: habit)
                }
                .padding(.vertical, 5)
            }
        }
    }

    private var activityCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actividad de 30 dias").font(.headline)
                Spacer()
                Text("\(completeDays)/30 completos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 7) {
                ForEach(calendarDays, id: \.self) { day in
                    let count = answered(on: day)
                    Button {
                        selectedDate = day
                        Haptics.soft()
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.caption2.weight(.semibold))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(activityColor(count: count))
                                .frame(height: 18)
                                .overlay {
                                    if calendar.isDate(day, inSameDayAs: selectedDate) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(.white.opacity(0.7), lineWidth: 1)
                                    }
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(count) respuestas")
                }
            }
            Text(selectedDayCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityIdentifier("journal.calendar")
    }

    private var patternSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Patrones emergentes").font(.headline)
                    Text("Recovery en dias con Si frente a dias con No")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ForEach(habits) { habit in
                let impact = association(for: habit.name)
                HStack(spacing: 10) {
                    Image(systemName: habit.icon)
                        .foregroundStyle(habit.color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).font(.subheadline.weight(.medium))
                        Text(impactCaption(impact))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let delta = impact.delta {
                        Text(String(format: "%+.0f pts", delta))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(delta >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                    } else {
                        Text("REUNIENDO DATOS")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityIdentifier("journal.impacts")
    }

    private var mentalEntryPoint: some View {
        NavigationLink {
            MentalJournalView()
                .hidesTabBar()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.title3)
                    .foregroundStyle(ScoreKind.sleep.color)
                    .frame(width: 44, height: 44)
                    .background(ScoreKind.sleep.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Diario mental").font(.headline)
                    Text(mentalTodayCaption)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(17)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.mental")
    }

    private var methodology: some View {
        Text("Las diferencias son asociaciones locales, no prueban causalidad. Se muestran solo con al menos 5 Si y 5 No unidos a Recovery del mismo dia. Un dato sin registrar queda como desconocido, no como No.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
    }

    private var answeredToday: Int { answered(on: .now) }
    private var completeDays: Int { calendarDays.filter { answered(on: $0) == habits.count }.count }
    private var calendarDays: [Date] {
        (0..<30).compactMap { calendar.date(byAdding: .day, value: $0 - 29, to: calendar.startOfDay(for: .now)) }
    }
    private var nextAction: String {
        if answeredToday < habits.count { return "Faltan \(habits.count - answeredToday) comportamientos por registrar." }
        if mentalEntries.first(where: { calendar.isDateInToday($0.date) }) == nil { return "Check-in listo. Añade una reflexión si te resulta útil." }
        return "Todo listo. Vuelve mañana para fortalecer tus patrones."
    }
    private var mentalTodayCaption: String {
        guard let entry = mentalEntries.first(where: { calendar.isDateInToday($0.date) }) else {
            return "Preparacion de manana y reflexion de noche, un prompt a la vez"
        }
        switch MentalJournalEngine.state(morning: entry.hasMorningReflection, evening: entry.hasEveningReflection) {
        case .complete: return "Hoy completo · abre para revisar o editar"
        case .partial: return "Hoy parcial · continua cuando quieras"
        case .none: return "Empieza una reflexion guiada"
        }
    }
    private var selectedDayCaption: String {
        let count = answered(on: selectedDate)
        let yes = logs.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.answer }.count
        return "\(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))): \(count)/\(habits.count) registrados · \(yes) Si."
    }

    private func answered(on day: Date) -> Int {
        habits.filter { habit in logs.contains { $0.habit == habit.name && calendar.isDate($0.date, inSameDayAs: day) } }.count
    }
    private func activityColor(count: Int) -> Color {
        if count == habits.count { return ScoreKind.recovery.color.opacity(0.9) }
        if count > 0 { return .cyan.opacity(0.55) }
        return .white.opacity(0.07)
    }
    private func todayLog(for habit: String) -> HabitLog? {
        logs.first { $0.habit == habit && calendar.isDateInToday($0.date) }
    }
    private func answerControl(for habit: HabitSpec) -> some View {
        let answer = todayLog(for: habit.name)?.answer
        return HStack(spacing: 2) {
            answerButton("No", value: false, selected: answer, habit: habit)
            answerButton("Si", value: true, selected: answer, habit: habit)
        }
        .padding(3)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
    }
    private func answerButton(_ title: String, value: Bool, selected: Bool?, habit: HabitSpec) -> some View {
        Button {
            if let existing = todayLog(for: habit.name) { existing.answer = value }
            else { modelContext.insert(HabitLog(habit: habit.name, answer: value)) }
            try? modelContext.save()
            Haptics.soft()
        } label: {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(selected == value ? .black : .secondary)
                .frame(width: 31, height: 27)
                .background(selected == value ? habit.color : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
    private func association(for habit: String) -> JournalAssociation {
        let pairs = logs.filter { $0.habit == habit }.compactMap { log -> (Bool, Int)? in
            scores.first { calendar.isDate($0.date, inSameDayAs: log.date) }.map { (log.answer, $0.recovery) }
        }
        return JournalImpactEngine.association(pairs: pairs)
    }
    private func impactCaption(_ impact: JournalAssociation) -> String {
        impact.isReady
            ? "\(impact.yesCount) Si · \(impact.noCount) No · asociacion, no causa"
            : "\(min(impact.yesCount, 5))/5 Si · \(min(impact.noCount, 5))/5 No comparables"
    }
}

enum HabitGroup { case recovery, day }

struct HabitSpec: Identifiable {
    let name: String
    let prompt: String
    let icon: String
    let color: Color
    let group: HabitGroup
    var id: String { name }

    static let defaults = [
        HabitSpec(name: "Alcohol", prompt: "Consumiste alcohol ayer", icon: "wineglass.fill", color: .pink, group: .recovery),
        HabitSpec(name: "Cafeina tarde", prompt: "Cafeina despues de las 15:00", icon: "cup.and.saucer.fill", color: .orange, group: .recovery),
        HabitSpec(name: "Cena tarde", prompt: "Comiste dentro de 2 h de dormir", icon: "clock.badge.exclamationmark", color: ScoreKind.strain.color, group: .recovery),
        HabitSpec(name: "Pantallas noche", prompt: "Pantallas intensas cerca de dormir", icon: "iphone", color: .cyan, group: .recovery),
        HabitSpec(name: "Meditacion", prompt: "Al menos 10 minutos", icon: "brain.head.profile", color: .cyan, group: .day),
        HabitSpec(name: "Hidratacion", prompt: "Cumpliste tu objetivo de agua", icon: "drop.fill", color: ScoreKind.recovery.color, group: .day),
        HabitSpec(name: "Luz natural", prompt: "Saliste o viste luz de dia", icon: "sun.max.fill", color: ScoreKind.energy.color, group: .day)
    ]
}

// MARK: - Guided mental journal

struct MentalJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MentalJournalEntry.date, order: .reverse) private var entries: [MentalJournalEntry]
    @State private var selectedDate = Date.now
    @State private var activeMode: ReflectionMode?
    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    mentalHeader
                    sessionChooser
                    mentalCalendar
                    selectedEntryDetail
                    Text("Esta herramienta apoya el autoconocimiento y no ofrece terapia ni diagnostico. Si escribir intensifica malestar o hay riesgo inmediato, detente y busca apoyo profesional o servicios de emergencia locales.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Diario mental")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).headerCircleChrome(size: 36)
                }
                .buttonStyle(.plain).accessibilityLabel("Atras")
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(item: $activeMode) { mode in
            MentalReflectionFlow(mode: mode, entry: entry(on: selectedDate))
        }
        .accessibilityIdentifier("mental.root")
    }

    private var mentalHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("REFLEXION GUIADA").font(.caption2.weight(.heavy)).foregroundStyle(ScoreKind.sleep.color)
            Text("Un momento, una pregunta").font(.system(size: 28, weight: .bold))
            let streak = MentalJournalEngine.completionStreak(
                completedDays: Set(entries.filter { $0.hasMorningReflection && $0.hasEveningReflection }.map(\.date))
            )
            Text(streak > 0 ? "\(streak) dias completos seguidos" : "Sin presion: una sesion parcial tambien cuenta como registro.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var sessionChooser: some View {
        HStack(spacing: 10) {
            sessionButton(.morning, icon: "sunrise.fill", color: ScoreKind.energy.color)
            sessionButton(.evening, icon: "moon.stars.fill", color: ScoreKind.sleep.color)
        }
    }

    private func sessionButton(_ mode: ReflectionMode, icon: String, color: Color) -> some View {
        let entry = entry(on: .now)
        let complete = mode == .morning ? (entry?.hasMorningReflection ?? false) : (entry?.hasEveningReflection ?? false)
        return Button {
            selectedDate = .now
            activeMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color)
                    Spacer()
                    Image(systemName: complete ? "checkmark.circle.fill" : "arrow.right.circle")
                        .foregroundStyle(complete ? ScoreKind.recovery.color : .secondary)
                }
                Text(mode.title).font(.headline)
                Text(complete ? "Completada · editar" : mode.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 8, tint: color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mental.\(mode.rawValue)")
    }

    private var mentalCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historial del mes").font(.headline)
            HStack(spacing: 12) {
                legend(.complete, "Completo")
                legend(.partial, "Parcial")
                legend(.none, "Sin entrada")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 7) {
                ForEach(monthDays, id: \.self) { day in
                    let state = state(on: day)
                    Button { selectedDate = day } label: {
                        Text(day.formatted(.dateTime.day()))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(stateColor(state), in: RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                if calendar.isDate(day, inSameDayAs: selectedDate) {
                                    RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.75), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityIdentifier("mental.calendar")
    }

    @ViewBuilder private var selectedEntryDetail: some View {
        if let entry = entry(on: selectedDate) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.headline)
                    Spacer()
                    Menu {
                        Button("Editar mañana") { activeMode = .morning }
                        Button("Editar noche") { activeMode = .evening }
                    } label: {
                        Image(systemName: "ellipsis").headerCircleChrome(size: 34)
                    }
                }
                detailLine("Intencion", entry.morningIntention ?? "")
                detailLine("Bajo mi control", entry.morningControl ?? "")
                detailLine("Que salio bien", entry.wentWell)
                detailLine("Gratitud", entry.gratitude)
                detailLine("Leccion", entry.eveningLesson ?? entry.improve)
            }
            .padding(17)
            .liquidGlass(cornerRadius: 8)
        } else {
            Text("No hay reflexion en esta fecha. Los dias vacios se muestran como ausencia de registro, no como fallo.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(cornerRadius: 8)
        }
    }

    @ViewBuilder private func detailLine(_ title: String, _ body: String) -> some View {
        if !body.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(.tertiary)
                Text(body).font(.subheadline)
            }
        }
    }
    private func legend(_ state: MentalDayState, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(stateColor(state)).frame(width: 7, height: 7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: .now),
              let range = calendar.range(of: .day, in: .month, for: .now) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
    }
    private func entry(on day: Date) -> MentalJournalEntry? {
        entries.first { calendar.isDate($0.date, inSameDayAs: day) }
    }
    private func state(on day: Date) -> MentalDayState {
        guard let entry = entry(on: day) else { return .none }
        return MentalJournalEngine.state(morning: entry.hasMorningReflection, evening: entry.hasEveningReflection)
    }
    private func stateColor(_ state: MentalDayState) -> Color {
        switch state {
        case .complete: ScoreKind.recovery.color.opacity(0.85)
        case .partial: ScoreKind.sleep.color.opacity(0.65)
        case .none: .white.opacity(0.07)
        }
    }
}

private enum ReflectionMode: String, Identifiable {
    case morning, evening
    var id: String { rawValue }
    var title: String { self == .morning ? "Preparar la mañana" : "Cerrar la noche" }
    var subtitle: String { self == .morning ? "Intencion y control" : "Gratitud y aprendizaje" }
    var prompts: [(String, String)] {
        self == .morning
            ? [("¿Que haria que hoy valga la pena?", "Define una intencion concreta, no una lista completa."),
               ("¿Que depende de ti?", "Elige una accion pequena dentro de tu control.")]
            : [("¿Que salio bien hoy?", "Recuerda un hecho concreto, incluso si fue pequeño."),
               ("¿Que agradeces de hoy?", "Una persona, momento o posibilidad es suficiente."),
               ("¿Que quieres aprender de hoy?", "Describe una leccion sin juzgarte.")]
    }
}

private struct MentalReflectionFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let mode: ReflectionMode
    let entry: MentalJournalEntry?
    @State private var step = 0
    @State private var answers: [String]

    init(mode: ReflectionMode, entry: MentalJournalEntry?) {
        self.mode = mode
        self.entry = entry
        let values = mode == .morning
            ? [entry?.morningIntention ?? "", entry?.morningControl ?? ""]
            : [entry?.wentWell ?? "", entry?.gratitude ?? "", entry?.eveningLesson ?? entry?.improve ?? ""]
        _answers = State(initialValue: values)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 20) {
                    ProgressView(value: Double(min(step + 1, mode.prompts.count)), total: Double(mode.prompts.count + 1))
                        .tint(ScoreKind.sleep.color)
                    if step < mode.prompts.count { promptStep }
                    else { reviewStep }
                    Spacer()
                    controls
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(step > 0)
    }

    private var promptStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(step + 1) DE \(mode.prompts.count)")
                .font(.caption2.weight(.heavy)).foregroundStyle(ScoreKind.sleep.color)
            Text(mode.prompts[step].0).font(.system(size: 30, weight: .bold))
            Text(mode.prompts[step].1).font(.subheadline).foregroundStyle(.secondary)
            TextField("Escribe lo que necesites…", text: $answers[step], axis: .vertical)
                .lineLimit(5...10)
                .padding(15)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("mental.answer")
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REVISA").font(.caption2.weight(.heavy)).foregroundStyle(ScoreKind.recovery.color)
            Text("Tu reflexion").font(.system(size: 30, weight: .bold))
            Text("Puedes volver y editar. Las respuestas omitidas se guardan vacias.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(mode.prompts.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.prompts[index].0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(answers[index].isEmpty ? "Omitida" : answers[index])
                        .font(.subheadline).foregroundStyle(answers[index].isEmpty ? .tertiary : .primary)
                }
            }
        }
    }

    private var controls: some View {
        HStack {
            if step > 0 {
                Button("Atras") { step -= 1 }.buttonStyle(.bordered)
            }
            Spacer()
            if step < mode.prompts.count {
                Button(answers[step].isEmpty ? "Omitir" : "Continuar") { step += 1 }
                    .buttonStyle(.borderedProminent).tint(ScoreKind.sleep.color)
            } else {
                Button("Guardar reflexion") { save() }
                    .buttonStyle(.borderedProminent).tint(ScoreKind.recovery.color)
                    .accessibilityIdentifier("mental.save")
            }
        }
    }

    private func save() {
        let target = entry ?? MentalJournalEntry()
        if entry == nil { modelContext.insert(target) }
        if mode == .morning {
            target.morningIntention = answers[0].trimmed
            target.morningControl = answers[1].trimmed
            target.morningCompletedAt = .now
        } else {
            target.wentWell = answers[0].trimmed
            target.gratitude = answers[1].trimmed
            target.eveningLesson = answers[2].trimmed
            target.improve = answers[2].trimmed
            target.eveningCompletedAt = .now
        }
        target.updatedAt = .now
        try? modelContext.save()
        Haptics.medium()
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
