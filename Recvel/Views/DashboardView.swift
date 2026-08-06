import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(TabBarVisibility.self) private var tabBarVisibility
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("weeklyWorkoutGoal") private var workoutGoal = 4
    @AppStorage("weeklySleepGoal") private var sleepGoal = 5
    /// Misma meta por noche que usa el detalle de Sueño (banco de sueño consistente).
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @AppStorage("weeklyBalancedGoal") private var balancedGoal = 4
    @AppStorage(HomeDayRingMetric.storageKey) private var ringMetricsRaw = HomeDayRingMetric.defaultStorageValue
    @Query private var nutritionProfiles: [NutritionProfile]
    @Query private var workoutTemplates: [WorkoutTemplate]
    // Contexto extra del reporte de la mañana (ayuno, nutricion, animo).
    @Query(sort: \FastingSession.startDate, order: .reverse) private var fastingSessions: [FastingSession]
    @Query(sort: \MealLog.createdAt, order: .reverse) private var meals: [MealLog]
    @Query(sort: \EmotionLog.date, order: .reverse) private var emotionLogs: [EmotionLog]
    @StateObject private var health = HealthDataProvider()
    @State private var appeared = false
    @State private var showsSettings = false
    @State private var showsPlan = false
    @State private var showsMonthCalendar = false
    @State private var showsMorningReport = false
    /// Dia (yyyy-MM-dd) en que se mostro el reporte por ultima vez: solo se abre solo una vez.
    @AppStorage("morningReportLastShownKey") private var morningReportLastShownKey = ""
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @Namespace private var daySelectionNamespace

    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private let stressEngine = StressEngine()
    private let bioAgeEngine = BioAgeEngine()
    private let calendar = Calendar.current

    private var selectedRingMetrics: [HomeDayRingMetric] {
        HomeDayRingEngine.selection(from: ringMetricsRaw)
    }

    private var selectedSnapshot: DailyHealthSnapshot {
        if Calendar.current.isDate(health.snapshot.date, inSameDayAs: selectedDay) {
            return health.snapshot
        }
        return health.history.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) } ?? health.snapshot
    }

    private var isShowingToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    private var visibleDays: [DailyHealthSnapshot] {
        let days = health.history.sorted { $0.date < $1.date }
        return Array(days.suffix(7))
    }

    private var scores: [WellnessScore] {
        scoreEngine.scores(for: selectedSnapshot, history: health.history)
    }

    private var recovery: WellnessScore {
        scores.first { $0.kind == .recovery } ?? WellnessScore(kind: .recovery, value: 50, confidence: .low, summary: "Sin datos")
    }

    private var brief: DailyBrief {
        insightEngine.briefing(
            snapshot: selectedSnapshot,
            history: health.history,
            scores: scores,
            wakeMinutes: wakeMinutes
        )
    }

    private var factors: [RecoveryFactor] {
        scoreEngine.factors(for: selectedSnapshot, history: health.history)
    }

    private var stressAssessment: StressAssessment {
        stressEngine.assess(snapshot: selectedSnapshot, history: health.history)
    }

    private var latestVO2Snapshot: DailyHealthSnapshot? {
        (health.history + [selectedSnapshot])
            .filter { $0.date <= selectedSnapshot.date && $0.vo2Max != nil }
            .max { ($0.vo2MaxDate ?? $0.date) < ($1.vo2MaxDate ?? $1.date) }
    }

    private var completedNutritionProfile: NutritionProfile? {
        nutritionProfiles.first(where: \.setupCompleted)
    }

    private var bioAgeHistory: [DailyHealthSnapshot] {
        health.history.filter { !calendar.isDate($0.date, inSameDayAs: selectedSnapshot.date) } + [selectedSnapshot]
    }

    private var bioAgeEstimate: BioAgeEstimate {
        let profile = completedNutritionProfile
        return bioAgeEngine.estimate(
            birthDate: profile?.birthDate,
            sex: profile.flatMap { NutritionSex(rawValue: $0.sexOptional) },
            snapshot: latestVO2Snapshot ?? selectedSnapshot,
            history: bioAgeHistory
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        entrance(0) { header }
                        // Solo se sustituye la pantalla cuando NO hay nada que
                        // cargar (sin permisos / sin datos). Mientras carga, la
                        // estructura real se mantiene y cada tarjeta se pinta
                        // como esqueleto hasta que llegan SUS datos: antes un
                        // cartel de "Leyendo Apple Health" tapaba la pantalla
                        // entera y escondia lo que ya estaba listo.
                        if health.dataMode == .empty && !health.isLoading {
                            emptyHealthState
                        } else {
                            entrance(1) { dayStrip.skeleton(corePhase) }
                            entrance(2) { recoveryHero.skeleton(corePhase) }
                            entrance(3) { scoreRail.skeleton(corePhase) }
                            if isShowingToday {
                                entrance(4) { prescription.skeleton(corePhase) }
                            } else {
                                entrance(4) { historicalContext.skeleton(corePhase) }
                            }
                            if isShowingToday {
                                // Plan y rutinas viven en SwiftData, no en
                                // HealthKit: ya estan listos y no se esqueletan.
                                entrance(5) { weekWorkoutsSection }
                                entrance(6) { planWeekSection }
                            }
                            // Estres depende de la curva de activacion, que se
                            // consulta despues del historial: puede seguir en
                            // esqueleto cuando el resto ya muestra datos.
                            entrance(7) { stressSection.skeleton(stressPhase) }
                            entrance(8) { cardioBiologySection.skeleton(corePhase) }
                            entrance(9) { recoveryDrivers.skeleton(corePhase) }
                            entrance(10) { trendsHomeSection.skeleton(corePhase) }
                            disclaimer
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 26)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
                .refreshable { await health.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsMonthCalendar) {
                HomeMonthCalendarSheet(
                    history: health.history,
                    selectedDay: $selectedDay,
                    ringMetricsRaw: $ringMetricsRaw
                )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .presentationBackground(Color(red: 0.075, green: 0.08, blue: 0.095))
            }
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView()
                    .navigationTitle("settings.title")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.visible, for: .navigationBar)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .hidesTabBar()
            }
            .navigationDestination(isPresented: $showsPlan) {
                PlanView()
                    .hidesTabBar()
            }
            .onChange(of: tabBarVisibility.wantsSettings) { _, wants in
                guard wants else { return }
                showsSettings = true
                tabBarVisibility.wantsSettings = false
            }
            .onChange(of: tabBarVisibility.wantsPlan) { _, wants in
                guard wants else { return }
                showsPlan = true
                tabBarVisibility.wantsPlan = false
            }
            .onChange(of: tabBarVisibility.wantsMorningReport) { _, wants in
                guard wants else { return }
                openMorningReport()
                tabBarVisibility.wantsMorningReport = false
            }
            .sheet(isPresented: $showsMorningReport) {
                MorningReportView(report: morningReport) {
                    selectedDay = Calendar.current.startOfDay(for: health.snapshot.date)
                }
                // "Visto hoy" se marca cuando la hoja aparece de verdad, no al
                // intentar abrirla: si la presentacion falla, manana reintenta.
                .onAppear { morningReportLastShownKey = MorningReportEngine.dayKey(for: .now) }
                .presentationDetents([.large])
                .presentationCornerRadius(30)
            }
            .onAppear {
                if tabBarVisibility.wantsSettings {
                    showsSettings = true
                    tabBarVisibility.wantsSettings = false
                }
                if tabBarVisibility.wantsPlan {
                    showsPlan = true
                    tabBarVisibility.wantsPlan = false
                }
                if tabBarVisibility.wantsMorningReport {
                    openMorningReport()
                    tabBarVisibility.wantsMorningReport = false
                }
            }
            .task {
                let migratedRings = HomeDayRingEngine.migratedStorageValue(from: ringMetricsRaw)
                if migratedRings != ringMetricsRaw {
                    ringMetricsRaw = migratedRings
                }
                if !UserDefaults.standard.bool(forKey: "skipHealthKitRefresh") {
                    await health.refresh()
                }
                selectedDay = Calendar.current.startOfDay(for: health.snapshot.date)
                if health.dataMode != .empty { LocalStore.saveDailyScores(scores, in: modelContext) }
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.84)) {
                    appeared = true
                }
                autoPresentMorningReportIfNeeded()
            }
            .onChange(of: scores.map(\.value)) { _, _ in
                if health.dataMode != .empty { LocalStore.saveDailyScores(scores, in: modelContext) }
            }
        }
    }

    // MARK: - Reporte de la mañana

    /// Sesion planeada para hoy en la agenda semanal (nil en descanso).
    private var plannedSessionToday: String? {
        let routine = WeeklyRoutineStore.load()
        let weekday = Calendar.current.component(.weekday, from: .now)
        guard let assignment = routine.days[weekday], assignment != .rest else { return nil }
        if case .template(let id) = assignment {
            let name = workoutTemplates.first { $0.id == id }?.name
            return name ?? assignment.displayLabel
        }
        return assignment.displayLabel
    }

    /// Ayuno activo al abrir el reporte (nil si no hay ninguno).
    private var fastingStatus: FastingStatus? {
        guard let active = fastingSessions.first(where: { $0.endDate == nil }) else {
            return FastingStatus(headline: "Sin ayuno activo", detail: "Empieza uno desde la pestaña Ayuno")
        }
        let hours = Date.now.timeIntervalSince(active.startDate) / 3600
        return FastingStatus(
            headline: String(format: "%.1f h en ayuno", max(hours, 0)),
            detail: String(format: "Objetivo %.0f h · empezaste a las %@",
                           active.targetHours,
                           active.startDate.formatted(date: .omitted, time: .shortened))
        )
    }

    /// Objetivo calorico del dia frente a lo ya registrado hoy.
    private var nutritionStatus: NutritionStatus? {
        guard let profile = completedNutritionProfile else { return nil }
        let targets = NutritionPlanEngine().targets(for: profile, now: .now)
        let today = meals.filter { calendar.isDateInToday($0.createdAt) }
        let eaten = today.reduce(0) { $0 + $1.calories }
        return NutritionStatus(
            headline: "\(eaten) / \(targets.calories) kcal",
            detail: today.isEmpty
                ? "Sin comidas registradas hoy"
                : "\(today.count) \(today.count == 1 ? "comida registrada" : "comidas registradas")"
        )
    }

    /// Emociones registradas en las ultimas 24 h.
    private var recentEmotions: [String] {
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        return emotionLogs.filter { $0.date >= cutoff }.map(\.emotion)
    }

    /// Se compone con los motores existentes; nunca con datos precalculados.
    private var morningReport: MorningReport {
        MorningReportEngine.report(
            snapshot: health.snapshot,
            history: health.history,
            scores: scoreEngine.scores(for: health.snapshot, history: health.history),
            factors: scoreEngine.factors(for: health.snapshot, history: health.history),
            brief: insightEngine.briefing(
                snapshot: health.snapshot,
                history: health.history,
                scores: scoreEngine.scores(for: health.snapshot, history: health.history),
                wakeMinutes: wakeMinutes
            ),
            sleepBank: SleepBankEngine().assess(history: health.history, goalHours: sleepGoalHours),
            plannedSession: plannedSessionToday,
            stress: stressEngine.assess(snapshot: health.snapshot, history: health.history),
            emotions: recentEmotions,
            fasting: fastingStatus,
            nutrition: nutritionStatus
        )
    }

    private func openMorningReport() {
        showsMorningReport = true
    }

    private func autoPresentMorningReportIfNeeded() {
        // Los UI tests entran a Home a cualquier hora: sin esto la hoja se
        // abriria encima y los haria fallar segun la hora del dia.
        guard !UserDefaults.standard.bool(forKey: "skipMorningReport") else { return }
        guard MorningReportEngine.shouldAutoPresent(
            now: .now,
            wakeMinutes: wakeMinutes,
            lastShownKey: morningReportLastShownKey,
            hasData: health.dataMode != .empty
        ) else { return }
        // Presentar dentro del `task` inicial se pierde: la ventana aun no es
        // key y SwiftUI descarta la hoja. Se espera a que Home este en pantalla.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            showsMorningReport = true
        }
    }

    private func entrance<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
            .animation(
                reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.84).delay(Double(index) * 0.055),
                value: appeared
            )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("RECVEL · \(isShowingToday ? "HOY" : "HISTORIAL")")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(ScoreKind.recovery.color)
                Text("home.morningSummary")
                    .font(.system(size: 29, weight: .bold))
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                // Un reporte que solo aparece solo es un reporte que no puedes consultar.
                if health.dataMode != .empty {
                    Button {
                        Haptics.soft()
                        openMorningReport()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.horizon.fill")
                                .font(.caption2.weight(.bold))
                            Text(RecvelL10n.text("home.openMorningReport"))
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(ScoreKind.recovery.color)
                        .padding(.top, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.openMorningReport")
                }
            }
            Spacer()
            dataSourceButton
            Menu {
                Button {
                    Haptics.menuSelect()
                    showsSettings = true
                } label: {
                    Label("settings.title", systemImage: "gearshape")
                }
                Button {
                    Haptics.menuSelect()
                    Task { await health.refresh() }
                } label: {
                    Label("home.refreshData", systemImage: "arrow.clockwise")
                }
                Button {
                    Haptics.menuSelect()
                    Task { await health.requestAuthorization() }
                } label: {
                    Label(RecvelL10n.text("home.healthPermissions"), systemImage: "heart.text.square")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .platformGlass(tint: ScoreKind.recovery.color, interactive: true, shape: .circle)
            }
            .menuOrder(.fixed)
            .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
            .accessibilityIdentifier("dashboard.moreMenu")
            .accessibilityLabel("Mas opciones")
        }
        .padding(.top, 8)
    }

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(RecvelL10n.text("home.recentDays"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("dashboard.dayStrip")
                Spacer()
                Button {
                    Haptics.soft()
                    showsMonthCalendar = true
                } label: {
                    Label("Mes", systemImage: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ScoreKind.recovery.color)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dashboard.dayStrip.openMonth")
            }
            .padding(.horizontal, 4)

            HStack(spacing: 2) {
                ForEach(visibleDays) { day in
                    let selected = Calendar.current.isDate(day.date, inSameDayAs: selectedDay)
                    HomeDayStripCell(
                        date: day.date,
                        selected: selected,
                        rings: rings(for: day),
                        namespace: daySelectionNamespace
                    ) {
                        if !selected { Haptics.selection() }
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                            selectedDay = Calendar.current.startOfDay(for: day.date)
                        }
                    }
                }

                Button {
                    Haptics.soft()
                    showsMonthCalendar = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(RecvelL10n.text("home.openMonthCalendar"))
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            .padding(.vertical, 4)
            .liquidGlass(cornerRadius: 8)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Haptics.soft()
                showsMonthCalendar = true
            }
        }
    }

    private func rings(for day: DailyHealthSnapshot) -> [HomeDayRingValue] {
        HomeDayRingEngine.ringValues(
            for: day,
            history: health.history,
            selected: selectedRingMetrics,
            isToday: calendar.isDateInToday(day.date),
            scoreEngine: scoreEngine,
            stressEngine: stressEngine
        )
    }

    private var weekWorkoutsSection: some View {
        HomeWeekWorkoutsCard(
            summary: HomeWeekWorkoutEngine.summarize(history: health.history, calendar: calendar),
            onOpenFitness: {
                Haptics.soft()
                tabBarVisibility.openFitnessTab()
            }
        )
    }

    private var dataSourceButton: some View {
        Menu {
            Button {
                Haptics.menuSelect()
                Task { await health.refresh() }
            } label: {
                Label("Actualizar ahora", systemImage: "arrow.clockwise")
            }
            Button {
                Haptics.menuSelect()
                Task { await health.requestAuthorization() }
            } label: {
                Label("Conectar Apple Health", systemImage: "heart.text.square")
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dataModeColor)
                    .frame(width: 7, height: 7)
                Text(health.isLoading ? RecvelL10n.text("common.reading") : health.dataMode.displayName)
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .platformGlass(tint: dataModeColor, interactive: true, shape: .capsule)
        }
        .menuOrder(.fixed)
        .hapticMenuLabel()
        .accessibilityLabel("\(RecvelL10n.text("dataSource.label")): \(health.dataMode.displayName). \(RecvelL10n.text("dataSource.connectHint"))")
    }

    private var dataModeColor: Color {
        switch health.dataMode {
        case .empty: .gray
        case .demo: .orange
        case .buildingBaseline: ScoreKind.energy.color
        case .partial: .cyan
        case .healthKit: ScoreKind.recovery.color
        }
    }

    // MARK: Fases de carga de la pantalla

    /// Fase del nucleo de HealthKit (snapshot + historial).
    private var corePhase: LoadPhase { health.corePhase }

    /// Estres necesita nucleo **y** curva de activacion: sigue en esqueleto
    /// mientras cualquiera de las dos falte.
    private var stressPhase: LoadPhase {
        LoadPhase.combined([health.corePhase, health.activationPhase])
    }

    // El antiguo `loadingState` ("Leyendo Apple Health") se elimino: sustituia
    // toda la pantalla por un cartel y escondia las tarjetas que ya tenian sus
    // datos. Ahora cada tarjeta se pinta como esqueleto por separado con
    // `.skeleton(_:)`.

    private var emptyHealthState: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(ScoreKind.recovery.color)
                Text("home.summary.needsData")
                    .font(.system(size: 27, weight: .bold))
                Text(RecvelL10n.text("home.empty.detail"))
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            Button { Task { await health.requestAuthorization() } } label: {
                Label("Conectar Apple Health", systemImage: "link")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(ScoreKind.recovery.color, in: Capsule())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 12) {
                emptySignal("1–2 días", "Primer resumen con confianza baja")
                emptySignal("7 días", "Referencia personal inicial y regularidad")
                emptySignal("21 días", "Mayor confianza y comparaciones más útiles")
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityIdentifier("dashboard.empty")
    }

    private func emptySignal(_ time: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Text(time).font(.caption.weight(.bold)).foregroundStyle(ScoreKind.recovery.color).frame(width: 62, alignment: .leading)
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 25)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var recoveryHero: some View {
        NavigationLink {
            RecoveryDetailView(score: recovery, snapshot: selectedSnapshot, week: health.history)
                .hidesTabBar()
        } label: {
            FluidRecoveryHero(score: recovery, mode: health.dataMode, date: selectedDay, reduceMotion: reduceMotion)
        }
        .buttonStyle(.glassCardLink)
        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
        .accessibilityIdentifier("dashboard.recoveryHero")
    }

    private var scoreRail: some View {
        HStack(spacing: 0) {
            ForEach([ScoreKind.sleep, .strain, .energy]) { kind in
                if let score = scores.first(where: { $0.kind == kind }) {
                    NavigationLink {
                        detailDestination(score)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            DashboardScoreInstrument(score: score)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.score.\(kind.rawValue.lowercased())")

                    if kind != .energy {
                        Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 78)
                    }
                }
            }
        }
        .liquidGlass(cornerRadius: 8)
    }

    @ViewBuilder
    private func detailDestination(_ score: WellnessScore) -> some View {
        switch score.kind {
        case .sleep:
            SleepDetailView(score: score, snapshot: selectedSnapshot, week: health.history)
                .hidesTabBar()
        case .strain:
            StrainDetailView(score: score, recovery: recovery, snapshot: selectedSnapshot, week: health.history)
                .hidesTabBar()
        case .energy:
            EnergyDetailView(score: score, scores: scores, snapshot: selectedSnapshot, week: health.history)
                .hidesTabBar()
        case .recovery:
            RecoveryDetailView(score: score, snapshot: selectedSnapshot, week: health.history)
                .hidesTabBar()
        }
    }

    private var trendsHomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tendencias").font(.title2.weight(.bold))
                    Text(RecvelL10n.text("home.trends.caption"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(.cyan)
            }

            NavigationLink {
                TrendsView().hidesTabBar()
            } label: {
                VStack(spacing: 14) {
                    HStack(spacing: 0) {
                        trendSummary(
                            title: ScoreKind.recovery.displayName,
                            value: "\(Int(recoveryTrend.last ?? 0))%",
                            color: ScoreKind.recovery.color,
                            values: recoveryTrend
                        )
                        Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 76)
                        trendSummary(
                            title: ScoreKind.sleep.displayName,
                            value: String(format: "%.1f h", sleepTrend.last ?? 0),
                            color: ScoreKind.sleep.color,
                            values: sleepTrend
                        )
                        Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 76)
                        trendSummary(
                            title: "HRV",
                            value: "\(Int(hrvTrend.last ?? 0)) ms",
                            color: .cyan,
                            values: hrvTrend
                        )
                    }

                    HStack {
                        Text(RecvelL10n.text("home.trends.open"))
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold)).foregroundStyle(.cyan)
                    }
                }
                .padding(15)
                .liquidGlass(cornerRadius: 8, tint: .cyan)
            }
            .buttonStyle(.glassCardLink)
            .accessibilityIdentifier("dashboard.trends")
        }
    }

    private var recoveryTrend: [Double] {
        visibleDays.map { day in
            Double(scoreEngine.scores(for: day, history: health.history).first { $0.kind == .recovery }?.value ?? 0)
        }
    }

    private var sleepTrend: [Double] { visibleDays.map { $0.sleepHours ?? 0 } }
    private var hrvTrend: [Double] { visibleDays.map { $0.hrv ?? 0 } }

    private func trendSummary(title: String, value: String, color: Color, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(color)
            Chart(Array(values.enumerated()), id: \.offset) { item in
                LineMark(x: .value("Dia", item.offset), y: .value(title, item.element))
                    .foregroundStyle(color).interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var historicalContext: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(RecvelL10n.text("home.dayContext")).font(.headline)
                Spacer()
                Text("REGISTROS CERRADOS").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            }
            HStack(spacing: 0) {
                historicalMetric(icon: "bolt.fill", value: selectedSnapshot.activeEnergy.map { "\(Int($0))" } ?? "—", unit: "kcal", color: ScoreKind.energy.color)
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 50)
                historicalMetric(icon: "figure.walk", value: selectedSnapshot.steps?.formatted() ?? "—", unit: "pasos", color: .cyan)
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 50)
                historicalMetric(icon: "stopwatch.fill", value: selectedSnapshot.workoutMinutes.map { "\(Int($0))" } ?? "0", unit: "min", color: ScoreKind.strain.color)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8)
    }

    private func historicalMetric(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(color)
            Text(value).font(.title3.weight(.bold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var prescription: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("home.todayPlan")
                    .font(.headline)
                Spacer()
                Text(RecvelL10n.text("home.updatesWithYourDay"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 18) {
                prescriptionValue(
                    icon: "moon.zzz.fill",
                    color: ScoreKind.sleep.color,
                    title: "Necesidad",
                    value: String(format: "%.1f h", brief.sleepNeedHours),
                    detail: brief.sleepDebtHours > 0.1 ? String(format: "+%.1f h deuda", brief.sleepDebtHours) : "Sin deuda relevante"
                )
                Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 72)
                prescriptionValue(
                    icon: "bed.double.fill",
                    color: .cyan,
                    title: "En cama",
                    value: brief.bedtime.formatted(date: .omitted, time: .shortened),
                    detail: "Para despertar a \(wakeTimeText)"
                )
            }

            loadTarget
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: Color.cyan)
    }

    private func prescriptionValue(icon: String, color: Color, title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadTarget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(RecvelL10n.text("score.load.short"), systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ScoreKind.strain.color)
                Spacer()
                Text(String(format: "%.1f actual · %.1f objetivo", brief.currentLoad, brief.targetLoad))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let total = 21.0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 9)
                    Capsule()
                        .fill(ScoreKind.strain.color.gradient)
                        .frame(width: proxy.size.width * min(brief.currentLoad / total, 1), height: 9)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 18)
                        .offset(x: proxy.size.width * min(brief.targetLoad / total, 1) - 1.5)
                        .shadow(color: .white.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 18)
            Text(brief.remainingLoad > 0.5 ? String(format: "Te quedan %.1f puntos de carga antes del objetivo.", brief.remainingLoad) : "Objetivo alcanzado. El resto del dia puede enfocarse en recuperar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(RecvelL10n.text("home.physiologicalActivation"))
                        .font(.headline)
                    Text(RecvelL10n.text("home.activation.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(activationLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(activationColor)
            }

            Chart(health.activation) { point in
                AreaMark(
                    x: .value("Hora", point.date),
                    y: .value("Activacion", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [activationColor.opacity(0.36), .clear], startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("Hora", point.date),
                    y: .value("Activacion", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(activationColor)
            }
            .chartYScale(domain: 0...3)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.07))
                    AxisValueLabel {
                        if let level = value.as(Int.self), level > 0 { Text("\(level)") }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 155)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: activationColor)
    }

    private var stressSection: some View {
        NavigationLink {
            StressDetailView(
                assessment: stressAssessment,
                snapshot: selectedSnapshot,
                history: health.history,
                activation: isShowingToday ? health.activation : []
            )
            .hidesTabBar()
        } label: {
            StressHomeCard(
                assessment: stressAssessment,
                activation: isShowingToday ? health.activation : []
            )
        }
        .buttonStyle(.glassCardLink)
        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
        .accessibilityIdentifier("dashboard.stress")
    }

    private var cardioBiologySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                VO2DetailView(snapshot: latestVO2Snapshot, history: health.history)
                    .hidesTabBar()
            } label: {
                VO2HomeCard(snapshot: latestVO2Snapshot)
            }
            .buttonStyle(.glassCardLink)
            .accessibilityIdentifier("dashboard.vo2")

            NavigationLink {
                BioAgeDetailView(estimate: bioAgeEstimate, vo2Snapshot: latestVO2Snapshot, history: bioAgeHistory)
                    .hidesTabBar()
            } label: {
                BioAgeHomeCard(estimate: bioAgeEstimate)
            }
            .buttonStyle(.glassCardLink)
            .accessibilityIdentifier("dashboard.bioAge")
        }
    }

    private var activationValue: Double { health.activation.last?.value ?? 0 }
    private var activationColor: Color {
        switch activationValue {
        case 2...: ScoreKind.strain.color
        case 1..<2: ScoreKind.energy.color
        default: ScoreKind.recovery.color
        }
    }
    private var activationLabel: String {
        switch activationValue {
        case 2...: "ALTA"
        case 1..<2: "MEDIA"
        default: "BAJA"
        }
    }

    private var recoveryDrivers: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(RecvelL10n.text("recovery.factors.title"))
                    .font(.headline)
                Spacer()
                Text(RecvelL10n.text("common.vsPersonalBaselineLower"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(factors) { factor in
                HStack(spacing: 11) {
                    Image(systemName: factor.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(factor.contribution >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(factor.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(factor.value).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                        HStack {
                            Text(factor.baseline ?? "Baseline pendiente")
                                .font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            Text(contributionText(factor.contribution))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(factor.contribution >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                        }
                    }
                }
                if factor.id != factors.last?.id {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
    }

    private func contributionText(_ value: Double) -> String {
        guard abs(value) > 0.08 else { return "NEUTRO" }
        return value > 0 ? "A FAVOR" : "EN CONTRA"
    }

    private var planWeekSection: some View {
        NavigationLink {
            PlanView()
                .hidesTabBar()
        } label: {
            PlanHomeCard(
                focusTitle: brief.focusTitle,
                sleepNeedHours: brief.sleepNeedHours,
                bedtime: brief.bedtime,
                cycleHint: "\(brief.suggestedSleepCycles) ciclos",
                workoutCurrent: planWorkoutDays,
                workoutGoal: workoutGoal,
                sleepCurrent: planSleepDays,
                sleepGoal: sleepGoal,
                balancedCurrent: planBalancedDays,
                balancedGoal: balancedGoal
            )
        }
        .buttonStyle(.glassCardLink)
        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
        .accessibilityIdentifier("dashboard.plan")
    }

    private var thisWeekSnapshots: [DailyHealthSnapshot] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return health.history.filter { interval.contains($0.date) }
    }

    private var planWorkoutDays: Int {
        thisWeekSnapshots.filter { ($0.workoutMinutes ?? 0) >= 20 }.count
    }

    private var planSleepDays: Int {
        thisWeekSnapshots.filter { ($0.sleepHours ?? 0) >= 7.5 }.count
    }

    private var planBalancedDays: Int {
        thisWeekSnapshots.filter {
            let value = scoreEngine.scores(for: $0, history: health.history).first { $0.kind == .strain }?.value ?? 0
            return value >= 45 && value <= 82
        }.count
    }

    private var wakeTimeText: String {
        let start = Calendar.current.startOfDay(for: .now)
        let date = Calendar.current.date(byAdding: .minute, value: wakeMinutes, to: start) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var disclaimer: some View {
        Text(health.dataMode == .demo
             ? RecvelL10n.text("home.demo.disclaimer")
             : RecvelL10n.text("settings.wellness.disclaimer"))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
    }
}

private struct FluidRecoveryHero: View {
    /// Bajo esqueleto el anillo NO dibuja progreso: un arco a medias se lee
    /// como un valor real y estariamos enseñando un dato que aun no existe.
    @Environment(\.redactionReasons) private var redactionReasons
    private var isRedacted: Bool { redactionReasons.contains(.placeholder) }

    let score: WellnessScore
    let mode: HealthDataMode
    let date: Date
    let reduceMotion: Bool
    @State private var progress = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.addFilter(.blur(radius: 24))
                    let wave = sin(phase * 0.55) * 18
                    var upper = Path()
                    upper.move(to: CGPoint(x: -30, y: size.height * 0.48 + wave))
                    upper.addCurve(
                        to: CGPoint(x: size.width + 30, y: size.height * 0.72),
                        control1: CGPoint(x: size.width * 0.28, y: size.height * 0.88 - wave),
                        control2: CGPoint(x: size.width * 0.72, y: size.height * 0.34 + wave)
                    )
                    upper.addLine(to: CGPoint(x: size.width + 30, y: size.height + 30))
                    upper.addLine(to: CGPoint(x: -30, y: size.height + 30))
                    upper.closeSubpath()
                    context.fill(
                        upper,
                        with: .linearGradient(
                            Gradient(colors: [ScoreKind.recovery.color.opacity(0.24), Color.cyan.opacity(0.07)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    var lower = Path()
                    lower.move(to: CGPoint(x: -20, y: size.height * 0.74))
                    lower.addCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.45),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.36 + wave),
                        control2: CGPoint(x: size.width * 0.70, y: size.height * 0.90 - wave)
                    )
                    lower.addLine(to: CGPoint(x: size.width + 20, y: size.height + 20))
                    lower.addLine(to: CGPoint(x: -20, y: size.height + 20))
                    lower.closeSubpath()
                    context.fill(lower, with: .color(Color.purple.opacity(0.09)))
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(ScoreKind.recovery.displayName.uppercased(), systemImage: "waveform.path.ecg")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ScoreKind.recovery.color)
                        Spacer()
                        Text(score.confidence.displayName.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.055), in: Capsule())
                    }

                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.07), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: isRedacted ? 0 : progress)
                                .stroke(
                                    AngularGradient(colors: [ScoreKind.recovery.color.opacity(0.55), ScoreKind.recovery.color], center: .center),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .shadow(color: ScoreKind.recovery.color.opacity(0.35), radius: 7)
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(score.value)")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                Text("%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 132, height: 132)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(score.summary)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(3)
                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(mode == .demo ? "Explorar demo" : "Ver analisis")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ScoreKind.recovery.color)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
            }
            .frame(height: 212)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
            .clipped()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.78)) {
                progress = Double(score.value) / 100
            }
        }
        .onChange(of: score.value) { _, value in
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.8)) {
                progress = Double(value) / 100
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ScoreKind.recovery.displayName) \(score.value) por ciento, \(RecvelL10n.text("common.confidence")) \(score.confidence.displayName). \(score.summary)")
    }
}

private struct DashboardScoreInstrument: View {
    /// Bajo esqueleto el anillo NO dibuja progreso: un arco a medias se lee
    /// como un valor real y estariamos enseñando un dato que aun no existe.
    @Environment(\.redactionReasons) private var redactionReasons
    private var isRedacted: Bool { redactionReasons.contains(.placeholder) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let score: WellnessScore
    @State private var animatedProgress = 0.0

    private var displayValue: String {
        score.kind == .strain
            ? String(format: "%.1f", Double(score.value) / 100 * 21)
            : "\(score.value)"
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: isRedacted ? 0 : animatedProgress)
                    .stroke(score.kind.color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text(displayValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.65)
                    if score.kind != .strain {
                        Text("%")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 62, height: 62)

            Label(score.kind.displayName, systemImage: score.kind.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.78)) {
                animatedProgress = Double(score.value) / 100
            }
        }
        .onChange(of: score.value) { _, value in
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.82)) {
                animatedProgress = Double(value) / 100
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.kind.displayName), \(displayValue)")
    }
}
