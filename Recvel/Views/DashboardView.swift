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
    @AppStorage("weeklyBalancedGoal") private var balancedGoal = 4
    @AppStorage(HomeDayRingMetric.storageKey) private var ringMetricsRaw = HomeDayRingMetric.defaultStorageValue
    @Query private var nutritionProfiles: [NutritionProfile]
    @StateObject private var health = HealthDataProvider()
    @State private var appeared = false
    @State private var showsSettings = false
    @State private var showsPlan = false
    @State private var showsMonthCalendar = false
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        entrance(0) { header }
                        if health.isLoading && health.dataMode == .empty {
                            loadingState
                        } else if health.dataMode == .empty {
                            emptyHealthState
                        } else {
                            entrance(1) { dayStrip }
                            entrance(2) { recoveryHero }
                            entrance(3) { scoreRail }
                            if isShowingToday {
                                entrance(4) { prescription }
                            } else {
                                entrance(4) { historicalContext }
                            }
                            if isShowingToday {
                                entrance(5) { weekWorkoutsSection }
                                entrance(6) { planWeekSection }
                            }
                            entrance(7) { stressSection }
                            entrance(8) { cardioBiologySection }
                            entrance(9) { recoveryDrivers }
                            entrance(10) { trendsHomeSection }
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
                    .navigationTitle("Ajustes")
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
            .onAppear {
                if tabBarVisibility.wantsSettings {
                    showsSettings = true
                    tabBarVisibility.wantsSettings = false
                }
                if tabBarVisibility.wantsPlan {
                    showsPlan = true
                    tabBarVisibility.wantsPlan = false
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
            }
            .onChange(of: scores.map(\.value)) { _, _ in
                if health.dataMode != .empty { LocalStore.saveDailyScores(scores, in: modelContext) }
            }
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
                Text("Briefing diario")
                    .font(.system(size: 29, weight: .bold))
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            dataSourceButton
            Menu {
                Button {
                    Haptics.menuSelect()
                    showsSettings = true
                } label: {
                    Label("Datos y privacidad", systemImage: "gearshape")
                }
                Button {
                    Haptics.menuSelect()
                    Task { await health.refresh() }
                } label: {
                    Label("Actualizar datos", systemImage: "arrow.clockwise")
                }
                Button {
                    Haptics.menuSelect()
                    Task { await health.requestAuthorization() }
                } label: {
                    Label("Permisos de Apple Health", systemImage: "heart.text.square")
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
                Text("Ultimos dias")
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
                .accessibilityLabel("Abrir calendario del mes")
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
                Text(health.isLoading ? "Leyendo" : health.dataMode.rawValue)
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .platformGlass(tint: dataModeColor, interactive: true, shape: .capsule)
        }
        .menuOrder(.fixed)
        .hapticMenuLabel()
        .accessibilityLabel("Fuente de datos: \(health.dataMode.rawValue). Toca para conectar Apple Health")
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

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ScoreKind.recovery.color).scaleEffect(1.2)
            Text("Leyendo Apple Health").font(.headline)
            Text("Normalizando fuentes y preparando tus ultimos 14 dias.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .liquidGlass(cornerRadius: 8)
    }

    private var emptyHealthState: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(ScoreKind.recovery.color)
                Text("Tu briefing necesita datos")
                    .font(.system(size: 27, weight: .bold))
                Text("Conecta Apple Health. Recvel mostrara solo las senales autorizadas y construira tu baseline sin inventar valores faltantes.")
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
                emptySignal("1–2 dias", "Primer resumen con confianza baja")
                emptySignal("7 dias", "Baseline inicial y regularidad")
                emptySignal("21 dias", "Confianza alta y mejores comparaciones")
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
                    Text("Tu ultima semana contra tu baseline")
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
                            title: "Recovery",
                            value: "\(Int(recoveryTrend.last ?? 0))%",
                            color: ScoreKind.recovery.color,
                            values: recoveryTrend
                        )
                        Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 76)
                        trendSummary(
                            title: "Sueno",
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
                        Text("Ver analisis de 7 dias")
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
                Text("Contexto del dia").font(.headline)
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
                Text("Tu plan para hoy")
                    .font(.headline)
                Spacer()
                Text("SE ACTUALIZA CON TU DIA")
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
                Label("Carga", systemImage: "scope")
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
                    Text("Activacion fisiologica")
                        .font(.headline)
                    Text("Ultimas 24 h · FC relativa a tu reposo")
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
                Text("Que mueve tu Recovery")
                    .font(.headline)
                Spacer()
                Text("vs. tu baseline")
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
             ? "Vista demo: los valores son ilustrativos. Conecta Apple Health para recibir un briefing personal."
             : "Estimaciones de bienestar basadas en tendencias de Apple Health; no son diagnostico medico.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
    }
}

private struct FluidRecoveryHero: View {
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
                        Label("RECOVERY", systemImage: "waveform.path.ecg")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ScoreKind.recovery.color)
                        Spacer()
                        Text(score.confidence.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.055), in: Capsule())
                    }

                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.07), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: progress)
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
        .accessibilityLabel("Recovery \(score.value) por ciento, confianza \(score.confidence.rawValue). \(score.summary)")
    }
}

private struct DashboardScoreInstrument: View {
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
                    .trim(from: 0, to: animatedProgress)
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

            Label(score.kind.rawValue, systemImage: score.kind.icon)
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
        .accessibilityLabel("\(score.kind.rawValue), \(displayValue)")
    }
}
