import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabBarVisibility.self) private var tabBarVisibility
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @Query(sort: \HabitLog.date, order: .reverse) private var logs: [HabitLog]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scores: [DailyScoreRecord]
    @Query(sort: \MentalJournalEntry.date, order: .reverse) private var mentalEntries: [MentalJournalEntry]
    @Query(sort: \MealLog.createdAt, order: .reverse) private var meals: [MealLog]
    @Query(sort: \JournalTagConfiguration.updatedAt, order: .reverse) private var configurations: [JournalTagConfiguration]
    @Query(sort: \FastingSession.startDate, order: .reverse) private var fastingSessions: [FastingSession]
    @StateObject private var health = HealthDataProvider()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var presentedSheet: JournalSheet?
    @Namespace private var selectionNamespace

    private let calendar = Calendar.current
    private let stressEngine = StressEngine()

    /// Mirror Fitness/Dashboard: authorize CTA only when Health is empty and never requested.
    /// Do not key off stale `.notRequested` once live data (or a prior request) exists.
    private var needsHealthAuthorization: Bool {
        guard health.permissionState != .unavailable else { return false }
        guard health.dataMode == .empty else { return false }
        return health.permissionState == .notRequested && !health.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        weekStrip
                        dayOverview
                        mentalEntryPoint
                        dayEntries
                        patternPreview
                        methodology
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
                .refreshable { await reloadJournalHealth() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await reloadJournalHealth()
                migrateLegacyLogs()
                applyDefaults(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, day in applyDefaults(for: day) }
            .onChange(of: tabBarVisibility.selectedTab) { _, tab in
                guard tab == .journal else { return }
                Task { await reloadJournalHealth() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, tabBarVisibility.selectedTab == .journal else { return }
                Task { await reloadJournalHealth() }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheetView(sheet)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .accessibilityIdentifier("journal.root")
    }

    private func reloadJournalHealth() async {
        await health.refresh()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Button {
                    Haptics.soft()
                    presentedSheet = .calendar
                } label: {
                    HStack(spacing: 6) {
                        Text("Journal")
                            .font(.system(size: 31, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                presentedSheet = .insights
                Haptics.soft()
            } label: {
                Label("Insights", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .platformGlass(tint: ScoreKind.recovery.color, interactive: true, shape: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("journal.insights.button")

            Menu {
                Button { presentedSheet = .customize } label: {
                    Label("Personalizar Journal", systemImage: "slider.horizontal.3")
                }
                Button { presentedSheet = .defaults } label: {
                    Label("Entradas predeterminadas", systemImage: "checkmark.circle")
                }
                Button { presentedSheet = .pinned } label: {
                    Label("Tags fijados", systemImage: "pin.fill")
                }
                Button { presentedSheet = .reminders } label: {
                    Label("Recordatorios", systemImage: "bell.fill")
                }
                Divider()
                Button(role: .destructive) { clearSelectedDay() } label: {
                    Label("Limpiar este dia", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .frame(width: 38, height: 38)
                    .platformGlass(interactive: true, shape: .circle)
            }
            .menuOrder(.fixed)
            .accessibilityIdentifier("journal.menu")
        }
        .padding(.top, 8)
    }

    private var weekStrip: some View {
        HStack(spacing: 2) {
            ForEach(weekDays, id: \.self) { day in
                let state = completionState(on: day)
                let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.24)) { selectedDate = day }
                } label: {
                    VStack(spacing: 7) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selected ? .white : .secondary)
                        ZStack {
                            Circle()
                                .stroke(stateColor(state).opacity(0.26), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: state.progress)
                                .stroke(stateColor(state), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .frame(width: 34, height: 34)
                        .background {
                            if selected {
                                Circle().fill(Color.white.opacity(0.08)).matchedGeometryEffect(id: "journal.day", in: selectionNamespace)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 5)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityIdentifier("journal.calendar")
    }

    private var dayOverview: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: completionState(on: selectedDate).progress)
                    .stroke(.cyan.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: completionState(on: selectedDate) == .complete ? "checkmark" : "pencil.line")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 4) {
                Text(calendar.isDateInToday(selectedDate) ? "Tu registro de hoy" : selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.headline)
                Text(dayOverviewCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityIdentifier("journal.today")
    }

    private var mentalEntryPoint: some View {
        NavigationLink {
            MentalJournalView().hidesTabBar()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "book.pages.fill")
                    .font(.title3)
                    .foregroundStyle(ScoreKind.sleep.color)
                    .frame(width: 42, height: 42)
                    .background(ScoreKind.sleep.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Diario mental").font(.headline)
                    Text(mentalCaption)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(15)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.mental")
    }

    private var dayEntries: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.isDateInToday(selectedDate) ? "Entradas de hoy" : "Entradas del dia")
                        .font(.headline)
                    Text("Separadas como en Bevel · lo no registrado sigue desconocido")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { presentedSheet = .customize } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 34, height: 34)
                        .platformGlass(interactive: true, shape: .circle)
                }
                .buttonStyle(.plain)
            }

            // Bevel order: manuals (Daytime / Nighttime) then Automatic
            manualEntriesSection
            Divider().overlay(Color.white.opacity(0.08))
            automaticEntriesSection
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("journal.entries")
    }

    private var manualEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MANUALES")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("journal.entries.manual.header")
            manualEntryGroup(.daytime)
            Divider().overlay(Color.white.opacity(0.06))
            manualEntryGroup(.nighttime)
        }
    }

    private var automaticEntriesSection: some View {
        let tags = automaticTags
        return VStack(alignment: .leading, spacing: 8) {
            Text("AUTOMATICAS")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("journal.entries.automatic.header")

            if health.permissionState == .unavailable {
                automaticEmptyState(
                    title: "HealthKit no disponible",
                    detail: "Este dispositivo no puede leer senales automaticas.",
                    showAuthorize: false
                )
            } else if needsHealthAuthorization {
                automaticEmptyState(
                    title: "Conecta Apple Health",
                    detail: "Autoriza Apple Health para ver pasos, sueno, workouts y mas.",
                    showAuthorize: true
                )
            } else if health.isLoading && health.dataMode == .empty {
                ProgressView("Leyendo Apple Health...")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("journal.entries.automatic.loading")
            } else if tags.isEmpty {
                automaticEmptyState(
                    title: "Sin tags automaticos",
                    detail: "Activa entradas automaticas en Personalizar Journal.",
                    showAuthorize: false
                )
            } else if health.dataMode == .empty {
                automaticEmptyState(
                    title: "Sin datos automaticos",
                    detail: "Apple Health esta conectado, pero no hay senales para este dia todavia.",
                    showAuthorize: false
                )
            } else if automaticSignals.isEmpty && !JournalActivityEngine.hasAutomaticHealthData(selectedSnapshot) {
                ForEach(tags) { tag in automaticRow(tag, signal: nil) }
                Text("Sin datos automaticos para este dia todavia.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .accessibilityIdentifier("journal.entries.automatic.empty")
            } else {
                ForEach(tags) { tag in
                    automaticRow(tag, signal: automaticSignals.first { $0.tagID == tag.id })
                }
            }
        }
    }

    private func automaticEmptyState(title: String, detail: String, showAuthorize: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if showAuthorize {
                Button("Autorizar Apple Health") {
                    Task { await health.requestAuthorization() }
                }
                .font(.caption.weight(.bold))
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("journal.entries.automatic.empty")
    }

    private func manualEntryGroup(_ period: JournalTagPeriod) -> some View {
        let tags = manualTags.filter { $0.period == period }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.title < rhs.title
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(period.rawValue.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.tertiary)
            ForEach(tags) { tag in manualRow(tag) }
            if tags.isEmpty {
                Text("No hay tags manuales activos en esta seccion.")
                    .font(.caption).foregroundStyle(.tertiary).padding(.vertical, 6)
            }
        }
    }

    private func automaticRow(_ tag: JournalResolvedTag, signal: JournalAutoSignal?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tag.symbol)
                .font(.subheadline)
                .foregroundStyle(.cyan)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.title).font(.subheadline.weight(.medium))
                Text(signal.map { "\($0.displayValue) · \($0.source)" } ?? "Sin dato todavia")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let signal {
                Image(systemName: signal.answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(signal.answer ? ScoreKind.recovery.color : Color.orange.opacity(0.85))
                    .font(.title3)
                    .accessibilityLabel(signal.answer ? "Si" : "No")
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
                    .accessibilityLabel("Sin dato")
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("journal.entry.\(tag.id)")
    }

    private func manualRow(_ tag: JournalResolvedTag) -> some View {
        let signal = hybridSignal(for: tag)
        let log = selectedLog(for: tag.id)
        return HStack(spacing: 10) {
            Image(systemName: tag.symbol)
                .font(.subheadline)
                .foregroundStyle(tagColor(tag.definition.category))
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(tag.title).font(.subheadline.weight(.medium))
                    if tag.isPinned { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.tertiary) }
                }
                Text(signal.map { "\($0.displayValue) · \($0.source)" } ?? tag.definition.subtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            answerControl(tag: tag, selected: log?.answer ?? signal?.answer)
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("journal.entry.\(tag.id)")
    }

    private func answerControl(tag: JournalResolvedTag, selected: Bool?) -> some View {
        HStack(spacing: 2) {
            answerButton("No", value: false, selected: selected, tag: tag)
            answerButton("Si", value: true, selected: selected, tag: tag)
        }
        .padding(3)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
    }

    private func answerButton(_ title: String, value: Bool, selected: Bool?, tag: JournalResolvedTag) -> some View {
        Button {
            saveAnswer(value, for: tag)
        } label: {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(selected == value ? .black : .secondary)
                .frame(width: 32, height: 27)
                .background(selected == value ? tagColor(tag.definition.category) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var patternPreview: some View {
        Button {
            presentedSheet = .insights
            Haptics.soft()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "sparkles")
                    .foregroundStyle(ScoreKind.recovery.color)
                    .frame(width: 40, height: 40)
                    .background(ScoreKind.recovery.color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Patrones emergentes").font(.headline)
                    Text(insightPreviewCaption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal.impacts")
    }

    private var methodology: some View {
        Text("Los patrones comparan dias con Si y No. Son asociaciones locales, no prueban causa. Recvel espera al menos 5 registros de cada grupo antes de mostrar una diferencia.")
            .font(.caption2).foregroundStyle(.tertiary).padding(.horizontal, 3)
    }

    @ViewBuilder
    private func sheetView(_ sheet: JournalSheet) -> some View {
        switch sheet {
        case .calendar:
            JournalMonthCalendarView(
                selectedDate: $selectedDate,
                tags: enabledTags,
                logs: logs,
                mentalEntries: mentalEntries,
                healthHistory: health.history + (health.history.contains(where: { calendar.isDate($0.date, inSameDayAs: health.snapshot.date) }) ? [] : [health.snapshot]),
                scores: scores,
                meals: meals,
                fastingSessions: fastingSessions
            )
        case .customize:
            JournalCustomizeView(mode: .all)
        case .defaults:
            JournalCustomizeView(mode: .defaults)
        case .pinned:
            JournalCustomizeView(mode: .pinned)
        case .insights:
            JournalInsightsView(tags: enabledTags, logs: logs, scores: scores)
        case .reminders:
            JournalReminderView()
        }
    }

    private var enabledTags: [JournalResolvedTag] {
        let builtIns = JournalCatalog.builtIns.map { definition in
            JournalResolvedTag(definition: definition, configuration: configurations.first { $0.tagID == definition.id })
        }
        let customs = configurations.filter { $0.sourceRaw == JournalTagSource.custom.rawValue }.map { config in
            JournalResolvedTag(
                definition: JournalTagDefinition(
                    config.tagID,
                    config.customTitle ?? "Tag personal",
                    "Registro personalizado",
                    symbol: config.customSymbol ?? "tag.fill",
                    category: JournalTagCategory(rawValue: config.categoryRaw) ?? .personal,
                    period: JournalTagPeriod(rawValue: config.periodRaw) ?? .daytime,
                    source: .custom,
                    enabled: true
                ),
                configuration: config
            )
        }
        return (builtIns + customs).filter(\.isEnabled)
    }

    private var automaticTags: [JournalResolvedTag] {
        let order = Dictionary(uniqueKeysWithValues: JournalCatalog.builtIns.enumerated().map { ($0.element.id, $0.offset) })
        return enabledTags
            .filter { $0.source == .automatic }
            .sorted { (order[$0.id] ?? 1_000) < (order[$1.id] ?? 1_000) }
    }

    private var manualTags: [JournalResolvedTag] {
        enabledTags.filter { $0.source != .automatic }
    }

    private var selectedSnapshot: DailyHealthSnapshot? {
        if calendar.isDate(health.snapshot.date, inSameDayAs: selectedDate) { return health.snapshot }
        return health.history.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedScore: DailyScoreRecord? {
        scores.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedMeals: [MealLog] {
        meals.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
    }

    private var fastingCompletedOnSelectedDay: Bool {
        fastingSessions.contains { session in
            guard let end = session.endDate else { return false }
            return calendar.isDate(end, inSameDayAs: selectedDate)
        }
    }

    private var automaticSignals: [JournalAutoSignal] {
        JournalAutoEntryEngine.signals(
            snapshot: selectedSnapshot,
            score: selectedScore,
            meals: selectedMeals,
            stress: selectedSnapshot.map { stressEngine.assess(snapshot: $0, history: health.history) },
            tags: enabledTags,
            fastingCompleted: fastingCompletedOnSelectedDay,
            calendar: calendar
        )
    }

    private var weekDays: [Date] {
        let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        let start = interval?.start ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var dayOverviewCaption: String {
        let state = completionState(on: selectedDate)
        switch state {
        case .none: return "Aun no hay respuestas manuales. Los datos automaticos aparecen cuando existen."
        case .partial: return "Hay actividad (manual o automatica). Completa solo lo que recuerdes con certeza."
        case .complete: return "Registro completo para los tags manuales activos."
        }
    }

    private var mentalCaption: String {
        guard let entry = mentalEntries.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) else {
            return "Preparacion de manana y reflexion de noche"
        }
        switch MentalJournalEngine.state(morning: entry.hasMorningReflection, evening: entry.hasEveningReflection) {
        case .complete: return "Reflexion completa · abre para revisar"
        case .partial: return "Reflexion parcial · continua cuando quieras"
        case .none: return "Empieza una reflexion guiada"
        }
    }

    private var insightPreviewCaption: String {
        let ready = JournalProImpactEngine.impacts(tags: enabledTags, logs: logs, scores: scores, metric: .recovery)
            .filter { $0.association.isReady }
        return ready.isEmpty ? "Sigue registrando para comparar Recovery y Sleep" : "\(ready.count) asociaciones listas para revisar"
    }

    private func completionState(on day: Date) -> JournalCompletionState {
        JournalActivityEngine.completionState(
            manualTags: manualTags,
            logs: logs,
            day: day,
            hasAutomaticData: hasAutomaticData(on: day),
            calendar: calendar
        )
    }

    private func hasAutomaticData(on day: Date) -> Bool {
        let snapshot: DailyHealthSnapshot? = {
            if calendar.isDate(health.snapshot.date, inSameDayAs: day) { return health.snapshot }
            return health.history.first { calendar.isDate($0.date, inSameDayAs: day) }
        }()
        if JournalActivityEngine.hasAutomaticHealthData(snapshot) { return true }
        let dayMeals = meals.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
        let dayScore = scores.first { calendar.isDate($0.date, inSameDayAs: day) }
        let fastingDone = fastingSessions.contains { session in
            guard let end = session.endDate else { return false }
            return calendar.isDate(end, inSameDayAs: day)
        }
        let signals = JournalAutoEntryEngine.signals(
            snapshot: snapshot,
            score: dayScore,
            meals: dayMeals,
            stress: snapshot.map { stressEngine.assess(snapshot: $0, history: health.history) },
            tags: enabledTags,
            fastingCompleted: fastingDone,
            calendar: calendar
        )
        return JournalActivityEngine.hasAutomaticSignals(signals)
    }

    private func stateColor(_ state: JournalCompletionState) -> Color {
        switch state {
        case .none: .white.opacity(0.13)
        case .partial: ScoreKind.energy.color
        case .complete: ScoreKind.recovery.color
        }
    }

    private func tagColor(_ category: JournalTagCategory) -> Color {
        switch category {
        case .automatic: .cyan
        case .health: ScoreKind.strain.color
        case .lifestyle: ScoreKind.energy.color
        case .medication: ScoreKind.sleep.color
        case .cycle: .pink
        case .personal: ScoreKind.recovery.color
        }
    }

    private func selectedLog(for tagID: String) -> HabitLog? {
        logs.first { calendar.isDate($0.date, inSameDayAs: selectedDate) && JournalProImpactEngine.resolvedID($0) == tagID }
    }

    private func hybridSignal(for tag: JournalResolvedTag) -> JournalAutoSignal? {
        guard let snapshot = selectedSnapshot else { return nil }
        switch tag.id {
        case "alcohol":
            guard let value = snapshot.dietaryAlcoholGrams else { return nil }
            return .init(tagID: tag.id, answer: value > 0, value: value, displayValue: String(format: "%.0f g", value), source: "Apple Health")
        case "hydration":
            guard let value = snapshot.dietaryWaterLiters else { return nil }
            return .init(tagID: tag.id, answer: value >= (tag.threshold ?? 2), value: value, displayValue: String(format: "%.1f L", value), source: "Apple Health")
        default: return nil
        }
    }

    private func saveAnswer(_ answer: Bool, for tag: JournalResolvedTag) {
        if let existing = selectedLog(for: tag.id) {
            existing.answer = answer
            existing.sourceRaw = JournalTagSource.manual.rawValue
        } else {
            modelContext.insert(HabitLog(
                date: calendar.startOfDay(for: selectedDate),
                habit: tag.title,
                answer: answer,
                tagID: tag.id,
                sourceRaw: JournalTagSource.manual.rawValue,
                periodRaw: tag.period.rawValue
            ))
        }
        try? modelContext.save()
        Haptics.soft()
    }

    private func applyDefaults(for day: Date) {
        guard day <= calendar.startOfDay(for: .now) else { return }
        var changed = false
        for tag in enabledTags {
            guard let state = tag.configuration?.defaultState, state >= 0, selectedLog(for: tag.id) == nil else { continue }
            modelContext.insert(HabitLog(
                date: calendar.startOfDay(for: day),
                habit: tag.title,
                answer: state == 1,
                tagID: tag.id,
                sourceRaw: JournalTagSource.defaultValue.rawValue,
                periodRaw: tag.period.rawValue
            ))
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    private func migrateLegacyLogs() {
        var changed = false
        for log in logs where log.tagID == nil {
            if let id = JournalCatalog.legacyID(for: log.habit) {
                log.tagID = id
                log.sourceRaw = JournalTagSource.manual.rawValue
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }

    private func clearSelectedDay() {
        logs.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }.forEach(modelContext.delete)
        try? modelContext.save()
        Haptics.warning()
    }
}

private enum JournalSheet: String, Identifiable {
    case calendar, customize, defaults, pinned, insights, reminders
    var id: String { rawValue }
}

enum JournalCompletionState: Equatable {
    case none, partial, complete
    var progress: Double {
        switch self { case .none: 0; case .partial: 0.55; case .complete: 1 }
    }
}

private struct JournalMonthCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let tags: [JournalResolvedTag]
    let logs: [HabitLog]
    let mentalEntries: [MentalJournalEntry]
    let healthHistory: [DailyHealthSnapshot]
    let scores: [DailyScoreRecord]
    let meals: [MealLog]
    let fastingSessions: [FastingSession]
    @State private var visibleMonth: Date = .now
    private let calendar = Calendar.current
    private let stressEngine = StressEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 16) {
                    HStack {
                        monthButton(-1, icon: "chevron.left")
                        Spacer()
                        Text(visibleMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                        Spacer()
                        monthButton(1, icon: "chevron.right").disabled(calendar.isDate(visibleMonth, equalTo: .now, toGranularity: .month))
                    }
                    HStack(spacing: 0) {
                        ForEach(calendar.shortWeekdaySymbols, id: \.self) { Text($0.prefix(1)).font(.caption2.weight(.bold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity) }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 8) {
                        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                            if let day { dayCell(day) } else { Color.clear.frame(height: 48) }
                        }
                    }
                    .padding(12).liquidGlass(cornerRadius: 8, tint: .cyan)
                    HStack(spacing: 15) {
                        legend(.none, "Sin registro")
                        legend(.partial, "Parcial / auto")
                        legend(.complete, "Completo")
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Calendario del Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
            .liquidGlassNavigationBar()
        }
        .accessibilityIdentifier("journal.calendar")
    }

    private func dayCell(_ day: Date) -> some View {
        let state = completion(on: day)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let mental = mentalEntries.contains { calendar.isDate($0.date, inSameDayAs: day) }
        return Button {
            selectedDate = day
            Haptics.selection()
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day())).font(.caption.weight(.bold)).monospacedDigit()
                HStack(spacing: 3) {
                    Circle().fill(color(state)).frame(width: 6, height: 6)
                    if mental { Circle().fill(ScoreKind.sleep.color).frame(width: 6, height: 6) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(selected ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(day > calendar.startOfDay(for: .now))
        .opacity(day > calendar.startOfDay(for: .now) ? 0.3 : 1)
    }

    private func completion(on day: Date) -> JournalCompletionState {
        let manual = tags.filter { $0.source != .automatic }
        let snapshot = healthHistory.first { calendar.isDate($0.date, inSameDayAs: day) }
        let dayMeals = meals.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
        let dayScore = scores.first { calendar.isDate($0.date, inSameDayAs: day) }
        let fastingDone = fastingSessions.contains { session in
            guard let end = session.endDate else { return false }
            return calendar.isDate(end, inSameDayAs: day)
        }
        let signals = JournalAutoEntryEngine.signals(
            snapshot: snapshot,
            score: dayScore,
            meals: dayMeals,
            stress: snapshot.map { stressEngine.assess(snapshot: $0, history: healthHistory) },
            tags: tags,
            fastingCompleted: fastingDone,
            calendar: calendar
        )
        let hasAuto = JournalActivityEngine.hasAutomaticHealthData(snapshot)
            || JournalActivityEngine.hasAutomaticSignals(signals)
        return JournalActivityEngine.completionState(
            manualTags: manual,
            logs: logs,
            day: day,
            hasAutomaticData: hasAuto,
            calendar: calendar
        )
    }

    private func color(_ state: JournalCompletionState) -> Color {
        switch state { case .none: .white.opacity(0.15); case .partial: ScoreKind.energy.color; case .complete: ScoreKind.recovery.color }
    }

    private func legend(_ state: JournalCompletionState, _ title: String) -> some View {
        HStack(spacing: 5) { Circle().fill(color(state)).frame(width: 7, height: 7); Text(title).font(.caption2).foregroundStyle(.secondary) }
    }

    private func monthButton(_ delta: Int, icon: String) -> some View {
        Button { if let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) { visibleMonth = next } } label: {
            Image(systemName: icon).frame(width: 36, height: 36).platformGlass(interactive: true, shape: .circle)
        }.buttonStyle(.plain)
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth), let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += range.map { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

private enum JournalCustomizeMode { case all, defaults, pinned }

private struct JournalCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalTagConfiguration.updatedAt, order: .reverse) private var configs: [JournalTagConfiguration]
    let mode: JournalCustomizeMode
    @State private var category: JournalTagCategory = .automatic
    @State private var search = ""
    @State private var customName = ""
    @State private var customNighttime = false
    @State private var showingCustom = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if mode == .all {
                            categoryPicker
                            searchField
                        }
                        ForEach(filteredDefinitions) { definition in row(definition) }
                        if mode == .all {
                            Button { showingCustom = true } label: {
                                Label("Crear tag personal", systemImage: "plus.circle.fill")
                                    .font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(16).liquidGlass(cornerRadius: 8, tint: .cyan)
                            }.buttonStyle(.plain)
                        }
                    }.padding(16).padding(.bottom, 24)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
            .liquidGlassNavigationBar()
            .sheet(isPresented: $showingCustom) { customComposer }
        }
        .accessibilityIdentifier("journal.customize")
    }

    private var title: String {
        switch mode { case .all: "Personalizar Journal"; case .defaults: "Entradas predeterminadas"; case .pinned: "Tags fijados" }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(JournalTagCategory.allCases) { item in
                    Button(item.rawValue) { category = item } .buttonStyle(.borderedProminent).tint(category == item ? .cyan : Color.white.opacity(0.08))
                }
            }
        }.scrollIndicators(.hidden)
    }

    private var searchField: some View {
        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Buscar tags", text: $search) }
            .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var filteredDefinitions: [JournalTagDefinition] {
        JournalCatalog.builtIns.filter { definition in
            let categoryMatch = mode == .all ? definition.category == category : true
            let searchMatch = search.isEmpty || definition.title.localizedCaseInsensitiveContains(search)
            return categoryMatch && searchMatch && (mode == .all || effectiveEnabled(definition))
        }
    }

    private func row(_ definition: JournalTagDefinition) -> some View {
        let config = configs.first { $0.tagID == definition.id }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(systemName: definition.symbol).foregroundStyle(definition.sensitive ? .pink : .cyan).frame(width: 25)
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.title).font(.subheadline.weight(.semibold))
                    Text(definition.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if definition.sensitive { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary) }
                switch mode {
                case .all:
                    Toggle("", isOn: Binding(get: { effectiveEnabled(definition) }, set: { setEnabled($0, definition: definition) })).labelsHidden()
                case .pinned:
                    Toggle("", isOn: Binding(get: { config?.isPinned ?? false }, set: { setPinned($0, definition: definition) })).labelsHidden()
                case .defaults:
                    Picker("", selection: Binding(get: { config?.defaultState ?? -1 }, set: { setDefault($0, definition: definition) })) {
                        Text("Ninguno").tag(-1); Text("No").tag(0); Text("Si").tag(1)
                    }.labelsHidden().pickerStyle(.menu)
                }
            }
            if mode == .all, definition.defaultThreshold != nil, effectiveEnabled(definition) {
                HStack {
                    Text("Umbral").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField("", value: Binding(get: { config?.threshold ?? definition.defaultThreshold ?? 0 }, set: { setThreshold($0, definition: definition) }), format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                    Text(definition.unit ?? "").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14).liquidGlass(cornerRadius: 8)
    }

    private var customComposer: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Un tag personal usa respuestas Si/No y permanece solo en este dispositivo.").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Nombre del tag", text: $customName).padding(14).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    Toggle("Entrada nocturna", isOn: $customNighttime).padding(14).liquidGlass(cornerRadius: 8)
                    Spacer()
                    Button("Guardar tag") { saveCustom() }.buttonStyle(.borderedProminent).tint(.cyan).frame(maxWidth: .infinity).disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(20)
            }
            .navigationTitle("Nuevo tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingCustom = false } } }
        }.presentationDetents([.medium])
    }

    private func effectiveEnabled(_ definition: JournalTagDefinition) -> Bool { configs.first { $0.tagID == definition.id }?.isEnabled ?? definition.defaultEnabled }
    private func config(for definition: JournalTagDefinition) -> JournalTagConfiguration {
        if let current = configs.first(where: { $0.tagID == definition.id }) { return current }
        let value = JournalTagConfiguration(tagID: definition.id, category: definition.category, period: definition.period, trackingMode: definition.mode, source: definition.source, isEnabled: definition.defaultEnabled, isSensitive: definition.sensitive, threshold: definition.defaultThreshold, unit: definition.unit)
        modelContext.insert(value); return value
    }
    private func setEnabled(_ value: Bool, definition: JournalTagDefinition) { let item = config(for: definition); item.isEnabled = value; item.updatedAt = .now; try? modelContext.save(); Haptics.selection() }
    private func setPinned(_ value: Bool, definition: JournalTagDefinition) { let item = config(for: definition); item.isPinned = value; item.updatedAt = .now; try? modelContext.save() }
    private func setDefault(_ value: Int, definition: JournalTagDefinition) { let item = config(for: definition); item.defaultState = value; item.updatedAt = .now; try? modelContext.save() }
    private func setThreshold(_ value: Double, definition: JournalTagDefinition) { let item = config(for: definition); item.threshold = max(value, 0); item.updatedAt = .now; try? modelContext.save() }
    private func saveCustom() {
        let title = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(JournalTagConfiguration(tagID: "custom.\(UUID().uuidString)", customTitle: title, customSymbol: "tag.fill", category: .personal, period: customNighttime ? .nighttime : .daytime, source: .custom, isEnabled: true))
        try? modelContext.save(); showingCustom = false; customName = ""; Haptics.medium()
    }
}

private struct JournalInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    let tags: [JournalResolvedTag]
    let logs: [HabitLog]
    let scores: [DailyScoreRecord]
    @State private var metric: JournalInsightMetric = .recovery

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Metrica", selection: $metric) { ForEach(JournalInsightMetric.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        impactSection("Asociaciones favorables", values: ready.filter { ($0.association.delta ?? 0) >= 0 }, color: ScoreKind.recovery.color)
                        impactSection("Asociaciones desfavorables", values: ready.filter { ($0.association.delta ?? 0) < 0 }, color: ScoreKind.strain.color)
                        impactSection("Reuniendo datos", values: pending, color: .secondary)
                        Text("Estos resultados comparan promedios personales. No controlan confusores y no demuestran que un habito cause el cambio.").font(.caption2).foregroundStyle(.tertiary)
                    }.padding(16).padding(.bottom, 24)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle("Insights del Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
            .liquidGlassNavigationBar()
        }.accessibilityIdentifier("journal.insights")
    }

    private var impacts: [JournalTagImpact] { JournalProImpactEngine.impacts(tags: tags, logs: logs, scores: scores, metric: metric) }
    private var ready: [JournalTagImpact] { impacts.filter { $0.association.isReady } }
    private var pending: [JournalTagImpact] { impacts.filter { !$0.association.isReady } }

    @ViewBuilder private func impactSection(_ title: String, values: [JournalTagImpact], color: Color) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.headline)
                ForEach(values) { impact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(impact.title).font(.subheadline.weight(.semibold))
                            Text("\(min(impact.association.yesCount, 5))/5 Si · \(min(impact.association.noCount, 5))/5 No").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(impact.association.delta.map { String(format: "%+.0f pts", $0) } ?? "Calibrando").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(color)
                    }.padding(14).liquidGlass(cornerRadius: 8, tint: color)
                }
            }
        }
    }
}

private struct JournalReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("journalMorningReminder") private var morning = false
    @AppStorage("journalEveningReminder") private var evening = false
    @AppStorage("journalStreakReminder") private var streak = false
    @AppStorage("wakeMinutes") private var wakeMinutes = 420

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 12) {
                    reminder("Recordatorio de manana", "Revisa lo ocurrido durante la noche", value: $morning)
                    reminder("Recordatorio de noche", "Cierra las entradas del dia", value: $evening)
                    reminder("Continuidad", "Un aviso suave si el dia sigue vacio", value: $streak)
                    Spacer()
                }.padding(16)
            }
            .navigationTitle("Recordatorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
            .liquidGlassNavigationBar()
            .onChange(of: morning) { _, _ in schedule() }
            .onChange(of: evening) { _, _ in schedule() }
            .onChange(of: streak) { _, _ in schedule() }
        }
    }

    private func reminder(_ title: String, _ detail: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) } }.padding(16).liquidGlass(cornerRadius: 8)
    }
    private func schedule() { Task { let manager = LocalNotificationManager(); if morning || evening || streak { _ = await manager.requestAuthorization() }; await manager.scheduleJournal(morning: morning, evening: evening, continuity: streak, wakeMinutes: wakeMinutes) } }
}
