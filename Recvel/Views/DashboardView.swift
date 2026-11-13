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
    // Solo se miran las comidas de hoy.
    @Query(MealLog.recent(60)) private var meals: [MealLog]
    @Query(EmotionLog.recent(60)) private var emotionLogs: [EmotionLog]
    @EnvironmentObject private var health: HealthDataProvider
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
    @State private var derived = DerivedCache()
    /// Clave de todo lo que depende del dia elegido y de los datos de salud.
    private var dayKey: AnyHashable { [AnyHashable(health.revision), AnyHashable(selectedDay)] }
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

    /// Los 7 dias hasta hoy, por FECHA y no por historial.
    ///
    /// Recorriendo `history` la fila se quedaba con menos celdas cuando faltaban
    /// dias — y en la primera carga, con el historial aun vacio, se quedaba solo
    /// con la capsula del mes. El esqueleto tiene que imitar la forma real de la
    /// fila, y un dia sin datos ya se pinta con el anillo apagado.
    private var visibleDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func snapshot(on day: Date) -> DailyHealthSnapshot? {
        health.history.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private var scores: [WellnessScore] {
        derived.value("scores", key: dayKey) {
            scoreEngine.scores(for: selectedSnapshot, history: health.history)
        }
    }

    private var recovery: WellnessScore {
        scores.first { $0.kind == .recovery } ?? WellnessScore(kind: .recovery, value: 50, confidence: .low, summary: RecvelL10n.text("home.noData"))
    }

    private var brief: DailyBrief {
        derived.value("brief", key: [dayKey, AnyHashable(wakeMinutes)] as [AnyHashable]) {
            insightEngine.briefing(
                snapshot: selectedSnapshot,
                history: health.history,
                scores: scores,
                wakeMinutes: wakeMinutes
            )
        }
    }

    private var factors: [RecoveryFactor] {
        derived.value("factors", key: dayKey) {
            scoreEngine.factors(for: selectedSnapshot, history: health.history)
        }
    }

    private var stressAssessment: StressAssessment {
        derived.value("stress", key: dayKey) {
            stressEngine.assess(snapshot: selectedSnapshot, history: health.history)
        }
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
                        // `corePhase != .loading` es lo que evita el parpadeo de
                        // la PRIMERA apertura: al arrancar, `dataMode` ya vale
                        // `.empty` y `isLoading` aun es false, asi que el cartel
                        // de "necesita mas datos" se pintaba un instante antes
                        // de que el `.task` empezara a cargar. El vacio solo es
                        // vacio cuando ya se miro.
                        if health.dataMode == .empty && !health.isLoading && corePhase != .loading {
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
                .refreshable { await health.refresh(trigger: .userInitiated) }
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
            return FastingStatus(
                headline: RecvelL10n.text("home.fasting.none.title"),
                detail: RecvelL10n.text("home.fasting.none.detail")
            )
        }
        let hours = Date.now.timeIntervalSince(active.startDate) / 3600
        return FastingStatus(
            headline: RecvelL10n.text("home.fasting.active.title", values: [
                "hours": String(format: "%.1f", max(hours, 0))
            ]),
            detail: RecvelL10n.text("home.fasting.active.detail", values: [
                "target": String(format: "%.0f", active.targetHours),
                "start": active.startDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale))
            ])
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
                ? RecvelL10n.text("home.nutrition.none")
                : RecvelL10n.text(
                    today.count == 1 ? "home.nutrition.count.one" : "home.nutrition.count.other",
                    values: ["count": "\(today.count)"]
                )
        )
    }

    /// Emociones registradas en las ultimas 24 h.
    private var recentEmotions: [String] {
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        return emotionLogs.filter { $0.date >= cutoff }.map(\.emotion)
    }

    /// Se compone con los motores existentes; nunca con datos precalculados.
    private var morningReport: MorningReport {
        // La hoja relee esto en cada pasada mientras esta abierta; sin cache
        // corria todos los motores (scores dos veces) y releia la rutina.
        let key: [AnyHashable] = [
            AnyHashable(health.revision), AnyHashable(wakeMinutes), AnyHashable(sleepGoalHours),
            AnyHashable(meals.count), AnyHashable(emotionLogs.count), AnyHashable(fastingSessions.count)
        ]
        return derived.value("morningReport", key: key) { composeMorningReport() }
    }

    private func composeMorningReport() -> MorningReport {
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
            // Esperar a que termine la entrada escalonada de Hoy (~1.2 s). A
            // los 450 ms la hoja subia encima de once tarjetas todavia
            // animandose, y las dos animaciones se trababan entre si.
            try? await Task.sleep(for: .milliseconds(1300))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RECVEL · \(RecvelL10n.text(isShowingToday ? "home.eyebrow.today" : "home.eyebrow.history"))")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(ScoreKind.recovery.color)
                    Text("home.morningSummary")
                        .font(.system(size: 29, weight: .bold))
                }
                Spacer()
                dataSourceButton
                moreMenu
            }

            dateChip
            morningReportLink
        }
        .padding(.top, 8)
    }

    /// Entrypoint del calendario, en el patron de chip de Bevel (la referencia
    /// usa capsulas con chevron: "Active ⌄").
    ///
    /// Va en su PROPIA FILA. Dentro de la columna del titulo solo le quedaban
    /// ~176 pt —el resto se lo llevan el chip de fuente de datos, de ancho
    /// variable, y el menu de 40 pt— y el peor caso de la fecha
    /// ("miércoles, 28 de septiembre") pide ~247 pt. Por eso se truncaba: no es
    /// que el texto sea largo, es que la fila no era suya. A ancho completo hay
    /// 370 pt y cabe en los dos idiomas, asi que tampoco hace falta acortar el
    /// formato ni encoger la tipografia.
    private var dateChip: some View {
        Button {
            Haptics.soft()
            showsMonthCalendar = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .bold))
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(RecvelL10n.locale)))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minHeight: 34)
            .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.header.openMonth")
        .accessibilityLabel(RecvelL10n.text("home.openMonthCalendar"))
        .accessibilityAddTraits(.isButton)
    }

    /// Un reporte que solo aparece solo es un reporte que no puedes consultar.
    @ViewBuilder
    private var morningReportLink: some View {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.openMorningReport")
        }
    }

    /// Menu "…" del encabezado. Se extrajo al reordenar el header en filas.
    private var moreMenu: some View {
        Menu {
            Button {
                Haptics.menuSelect()
                showsSettings = true
            } label: {
                Label("settings.title", systemImage: "gearshape")
            }
            Button {
                Haptics.menuSelect()
                Task { await health.refresh(trigger: .userInitiated) }
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
        .accessibilityLabel(RecvelL10n.text("home.moreOptions"))
    }

    /// Tira de la semana. Las pastillas flotan sobre el fondo, sin caja: es la
    /// misma pieza que la rejilla del mes (`HomeMonthCalendarSheet`), que
    /// tampoco encierra sus celdas. El acceso al mes vive en la fecha del
    /// encabezado, no aqui.
    private var dayStrip: some View {
        HStack(spacing: 4) {
            ForEach(visibleDays, id: \.self) { day in
                let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                HomeDayStripCell(
                    date: day,
                    selected: selected,
                    rings: rings(for: day),
                    namespace: daySelectionNamespace
                ) {
                    if !selected { Haptics.selection() }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                        selectedDay = calendar.startOfDay(for: day)
                    }
                }
            }

            // Acceso al mes DENTRO de la tira. Tocar una celda selecciona ese
            // dia, asi que el acceso no puede ser la tira entera: necesita su
            // propio control. Va con la misma capsula que los dias —es parte
            // del componente, no un boton pegado al lado— pero en color de
            // acento para que se lea como "hay mas aqui".
            HomeStripMonthCell {
                Haptics.soft()
                showsMonthCalendar = true
            }
        }
        // Sin esto, el identificador del contenedor convierte la fila en UN
        // solo elemento de accesibilidad y sus hijos dejan de ser alcanzables:
        // el boton del mes existia en pantalla pero no para XCUITest ni para
        // VoiceOver.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.dayStrip")
    }

    private func rings(for day: Date) -> [HomeDayRingValue] {
        // Los anillos de un dia no dependen del dia SELECCIONADO: tocar otra
        // celda no debe recalcular los siete.
        derived.value(
            "rings.\(day.timeIntervalSinceReferenceDate)",
            key: [AnyHashable(health.revision), AnyHashable(ringMetricsRaw)] as [AnyHashable]
        ) {
            HomeDayRingEngine.ringValues(
                for: snapshot(on: day),
                history: health.history,
                selected: selectedRingMetrics,
                isToday: calendar.isDateInToday(day),
                scoreEngine: scoreEngine,
                stressEngine: stressEngine
            )
        }
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
                Task { await health.refresh(trigger: .userInitiated) }
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
                emptySignal(RecvelL10n.text("home.empty.days1"), RecvelL10n.text("home.empty.days1.detail"))
                emptySignal(RecvelL10n.text("home.empty.days7"), RecvelL10n.text("home.empty.days7.detail"))
                emptySignal(RecvelL10n.text("home.empty.days21"), RecvelL10n.text("home.empty.days21.detail"))
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
                // Con el reporte encima, el fondo animado del hero no se ve
                // pero seguia redibujando su blur a la vez que la hoja.
                .transformEnvironment(\.isTabActive) { $0 = $0 && !showsMorningReport }
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
                    Text(RecvelL10n.text("home.trends.title")).font(.title2.weight(.bold))
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

    /// Las mini-graficas quieren los ultimos dias CON datos, no los ultimos
    /// siete del calendario: un hueco no es un cero, y dibujarlo como cero
    /// hundiria la linea inventando una caida.
    private var recentSnapshots: [DailyHealthSnapshot] {
        Array(health.history.sorted { $0.date < $1.date }.suffix(7))
    }

    private var recoveryTrend: [Double] {
        recentSnapshots.map { day in
            Double(scoreEngine.scores(for: day, history: health.history).first { $0.kind == .recovery }?.value ?? 0)
        }
    }

    private var sleepTrend: [Double] { recentSnapshots.map { $0.sleepHours ?? 0 } }
    private var hrvTrend: [Double] { recentSnapshots.map { $0.hrv ?? 0 } }

    private func trendSummary(title: String, value: String, color: Color, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(color)
            Chart(Array(values.enumerated()), id: \.offset) { item in
                LineMark(x: .value(RecvelL10n.text("chart.axis.day"), item.offset), y: .value(title, item.element))
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
                Text(RecvelL10n.text("home.dayContext.closed")).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            }
            HStack(spacing: 0) {
                historicalMetric(icon: "bolt.fill", value: selectedSnapshot.activeEnergy.map { "\(Int($0))" } ?? "—", unit: "kcal", color: ScoreKind.energy.color)
                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 50)
                historicalMetric(icon: "figure.walk", value: selectedSnapshot.steps?.formatted(.number.locale(RecvelL10n.locale)) ?? "—", unit: RecvelL10n.text("unit.steps"), color: .cyan)
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
                    title: RecvelL10n.text("home.plan.sleepNeed"),
                    value: String(format: "%.1f h", brief.sleepNeedHours),
                    detail: brief.sleepDebtHours > 0.1
                        ? RecvelL10n.text("home.plan.sleepDebt", values: ["hours": String(format: "%.1f", brief.sleepDebtHours)])
                        : RecvelL10n.text("home.plan.noDebt")
                )
                Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 72)
                prescriptionValue(
                    icon: "bed.double.fill",
                    color: .cyan,
                    title: RecvelL10n.text("home.plan.bedtime"),
                    value: brief.bedtime.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale)),
                    detail: RecvelL10n.text("home.plan.wakeAt", values: ["time": wakeTimeText])
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
            Text(brief.remainingLoad > 0.5
                 ? RecvelL10n.text("home.load.remaining", values: ["points": String(format: "%.1f", brief.remainingLoad)])
                 : RecvelL10n.text("home.load.reached"))
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
                    x: .value(RecvelL10n.text("chart.axis.hour"), point.date),
                    y: .value(RecvelL10n.text("chart.axis.activation"), point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [activationColor.opacity(0.36), .clear], startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value(RecvelL10n.text("chart.axis.hour"), point.date),
                    y: .value(RecvelL10n.text("chart.axis.activation"), point.value)
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
        case 2...: RecvelL10n.text("home.activation.high")
        case 1..<2: RecvelL10n.text("home.activation.medium")
        default: RecvelL10n.text("home.activation.low")
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
                        .foregroundStyle(contributionColor(factor.contribution))
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(factor.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(factor.value).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                        HStack {
                            Text(factor.baseline ?? RecvelL10n.text("home.factor.baselinePending"))
                                .font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            Text(contributionText(factor.contribution))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(contributionColor(factor.contribution))
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

    /// Por debajo de esto la señal esta "en su rango". La contribucion va
    /// normalizada a ±18 % de desviacion, asi que 0.25 ≈ 4.5 %: con el 0.08
    /// anterior, 53 lpm frente a 52 habituales ya salia "en contra".
    private static let neutralContribution = 0.25

    /// Neutro es gris en TODAS las filas; antes heredaba verde o naranja segun
    /// el signo de una desviacion minima.
    private func contributionColor(_ value: Double) -> Color {
        guard abs(value) > Self.neutralContribution else { return .secondary }
        return value > 0 ? ScoreKind.recovery.color : ScoreKind.strain.color
    }

    private func contributionText(_ value: Double) -> String {
        guard abs(value) > Self.neutralContribution else { return RecvelL10n.text("home.contribution.neutral") }
        return RecvelL10n.text(value > 0 ? "home.contribution.for" : "home.contribution.against")
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
                cycleHint: RecvelL10n.text("unit.cycles", values: ["count": "\(brief.suggestedSleepCycles)"]),
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
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(RecvelL10n.locale))
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
    @Environment(\.isTabActive) private var isTabActive
    @State private var progress = 0.0

    var body: some View {
        // 15 fps: la ola se mueve <1 pt por cuadro, asi que mas cuadros solo
        // repetian un blur de 24 pt sin que se notara.
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion || !isTabActive)) { timeline in
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
                        // "BAJA" a secas junto al 60% se leia como "recuperacion
                        // baja"; es la confianza del dato.
                        Text(RecvelL10n.text("score.confidenceBadge", values: ["level": score.confidence.displayName]).uppercased())
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
                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(RecvelL10n.locale)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(RecvelL10n.text(mode == .demo ? "home.hero.exploreDemo" : "home.hero.openAnalysis"))
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

/// Instrumento de Sueño / Carga / Energia del Home.
///
/// Linea visual tomada de la fila Strain·Recovery·Sleep de la referencia
/// (`CalendarAndJournal.mp4`, t=0 s, medido a resolucion nativa 1290x2796).
/// Lo que hace que ese anillo se lea como instrumento y no como una barra
/// doblada son cuatro cosas, y las cuatro estan aqui:
///
///  1. **Profundidad.** El arco vive en un pozo: bisel exterior con la luz
///     cargada arriba, disco interior mas oscuro que la tarjeta y un surco
///     negro donde corre el trazo. Antes era un aro plano sobre el fondo.
///  2. **Gradiente ANGULAR**, no lineal: el color viaja a lo largo del arco,
///     de una version apagada en el origen a la plena en la punta. Un
///     `LinearGradient` sobre un circulo cruza el trazo en diagonal y no
///     acompaña el recorrido.
///  3. **Glow** del color bajo el arco.
///  4. **El valor y el `%` con el mismo cuerpo**, como una sola cifra. Antes
///     el `%` iba diminuto y en secundario, y la cifra perdia peso.
private struct DashboardScoreInstrument: View {
    /// Bajo esqueleto el anillo NO dibuja progreso: un arco a medias se lee
    /// como un valor real y estariamos enseñando un dato que aun no existe.
    @Environment(\.redactionReasons) private var redactionReasons
    private var isRedacted: Bool { redactionReasons.contains(.placeholder) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let score: WellnessScore
    @State private var animatedProgress = 0.0

    private let diameter: CGFloat = 68
    private let lineWidth: CGFloat = 7

    private var displayValue: String {
        score.kind == .strain
            ? String(format: "%.1f", Double(score.value) / 100 * 21)
            : "\(score.value)"
    }

    /// Carga se expresa 0-21, no en porcentaje.
    private var unitSuffix: String { score.kind == .strain ? "" : "%" }

    /// Origen del gradiente: el mismo tono con menos brillo y algo menos de
    /// saturacion. `Color.mix` es iOS 18 y el proyecto va a 17, asi que se
    /// calcula por HSB.
    private var deepTint: Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(score.kind.color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return score.kind.color.opacity(0.5)
        }
        return Color(hue: hue, saturation: saturation * 0.95, brightness: brightness * 0.56)
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                well
                track
                arc
                readout
            }
            .frame(width: diameter, height: diameter)

            Text(score.kind.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

    /// Bisel elevado + disco hundido. La luz entra por arriba, asi que el
    /// borde superior aclara y el inferior se apaga.
    ///
    /// El disco NO se oscurece a negro: en la referencia es una superficie
    /// gris, y pintarlo negro convertia el centro en un agujero.
    private var well: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            Circle()
                .fill(Color.white.opacity(0.028))
                .padding(2)
        }
    }

    /// Surco por el que corre el arco.
    private var track: some View {
        Circle()
            .stroke(Color.black.opacity(0.34), lineWidth: lineWidth)
            .padding(lineWidth / 2 + 3)
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: isRedacted ? 0 : animatedProgress)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [deepTint, score.kind.color]),
                    center: .center,
                    // El trazo arranca en las 12 por el giro de -90°, asi que
                    // el gradiente arranca ahi tambien. El final SIGUE al
                    // progreso para que la rampa completa quepa dentro del arco
                    // dibujado: con `endAngle` fijo en 360, un arco corto solo
                    // enseñaba el tramo apagado del degradado.
                    startAngle: .degrees(0),
                    endAngle: .degrees(max(360 * animatedProgress, 1))
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .padding(lineWidth / 2 + 3)
            .shadow(color: score.kind.color.opacity(isRedacted ? 0 : 0.28), radius: 3.5)
    }

    private var readout: some View {
        Text(displayValue + unitSuffix)
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(.horizontal, lineWidth + 6)
    }
}
