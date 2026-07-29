import Charts
import SwiftData
import SwiftUI

struct FitnessDayPoint: Identifiable {
    let date: Date
    let activityCount: Int
    let minutes: Double
    let cardiovascularLoad: Double
    let strain: Double
    let targetStrain: Double

    var id: Date { date }
    var strainDeviation: Double {
        guard targetStrain > 0 else { return 0 }
        return (strain / targetStrain - 1) * 100
    }
}

struct FitnessFocusBreakdown {
    let lowAerobic: Double
    let highAerobic: Double
    let anaerobic: Double

    static let empty = FitnessFocusBreakdown(lowAerobic: 0, highAerobic: 0, anaerobic: 0)

    var total: Double { lowAerobic + highAerobic + anaerobic }
    var lowPercent: Int { percent(lowAerobic) }
    var highPercent: Int { percent(highAerobic) }
    var anaerobicPercent: Int { percent(anaerobic) }

    var primaryLabel: String {
        guard total > 0 else { return "Sin datos" }
        if lowAerobic >= highAerobic && lowAerobic >= anaerobic { return "Aerobico bajo" }
        if highAerobic >= anaerobic { return "Aerobico alto" }
        return "Anaerobico"
    }

    private func percent(_ value: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((value / total * 100).rounded())
    }
}

struct FitnessEngine {
    private let calendar = Calendar.autoupdatingCurrent
    private let scoreEngine = ScoreEngine()

    func points(
        history: [DailyHealthSnapshot],
        manualActivities: [FitnessActivityLog],
        now: Date = .now
    ) -> [FitnessDayPoint] {
        let end = calendar.startOfDay(for: now)
        return (0..<30).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 29, to: end) else { return nil }
            let snapshot = history.first { calendar.isDate($0.date, inSameDayAs: date) }
            let manual = manualActivities.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            let healthMinutes = snapshot?.workoutMinutes ?? 0
            let minutes = healthMinutes + manual.reduce(0) { $0 + $1.durationMinutes }
            let healthCount: Int
            if let snapshot, !snapshot.workouts.isEmpty { healthCount = snapshot.workouts.count }
            else { healthCount = healthMinutes > 0 ? 1 : 0 }

            let zoneLoad = snapshot?.workouts.reduce(0) { $0 + $1.cardiovascularLoad } ?? 0
            let manualLoad = manual.reduce(0) {
                $0 + ($1.durationMinutes * Double(max($1.perceivedEffort, 1)) / 30)
            }
            let durationFallback = zoneLoad == 0 ? healthMinutes * 0.12 : 0
            let cardiovascularLoad = zoneLoad + manualLoad + durationFallback

            let scores = snapshot.map { scoreEngine.scores(for: $0, history: history) } ?? []
            let measuredStrain = Double(scores.first { $0.kind == .strain }?.value ?? 0)
            let manualStrain = min(manualLoad * 7, 100)
            let recovery = Double(scores.first { $0.kind == .recovery }?.value ?? 50)
            let target = 42 + recovery * 0.38

            return FitnessDayPoint(
                date: date,
                activityCount: healthCount + manual.count,
                minutes: minutes,
                cardiovascularLoad: cardiovascularLoad,
                strain: max(measuredStrain, manualStrain),
                targetStrain: target
            )
        }
    }

    func focus(history: [DailyHealthSnapshot]) -> FitnessFocusBreakdown {
        let zones = history.flatMap(\.workouts).flatMap(\.zones)
        guard !zones.isEmpty else { return .empty }
        return FitnessFocusBreakdown(
            lowAerobic: zones.filter { $0.zone <= 2 }.reduce(0) { $0 + $1.minutes },
            highAerobic: zones.filter { $0.zone == 3 || $0.zone == 4 }.reduce(0) { $0 + $1.minutes },
            anaerobic: zones.filter { $0.zone >= 5 }.reduce(0) { $0 + $1.minutes }
        )
    }

    func latestHeartRateRecovery(history: [DailyHealthSnapshot]) -> Double? {
        history
            .flatMap(\.workouts)
            .sorted { $0.endDate > $1.endDate }
            .compactMap(\.heartRateRecoveryOneMinute)
            .first
    }
}

private enum FitnessDetailRoute: String, Identifiable {
    case activity, strain, cardioLoad, cardioFocus, heartRateRecovery, strength
    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: "Resumen de actividad"
        case .strain: RecvelL10n.text("training.loadResponse.title")
        case .cardioLoad: "Carga cardio"
        case .cardioFocus: "Foco cardio"
        case .heartRateRecovery: "Recuperación cardíaca"
        case .strength: "Progresion de fuerza"
        }
    }
}

private enum FitnessComposer: String, Identifiable {
    case activity, template, sections
    var id: String { rawValue }
}

struct FitnessView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FitnessActivityLog.startDate, order: .reverse) private var manualActivities: [FitnessActivityLog]
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \ExerciseSetLog.date, order: .reverse) private var setLogs: [ExerciseSetLog]
    @StateObject private var health = HealthDataProvider()
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]
    @State private var selectedDetail: FitnessDetailRoute?
    @State private var composer: FitnessComposer?
    @State private var previewTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var activeSessionTemplate: WorkoutTemplate?
    @State private var showRoutineOnboarding = false
    @State private var showTemplateManager = false
    @State private var routineRevision = 0
    @State private var appeared = false
    @State private var strengthMetric = "Frecuencia"
    @State private var progressionExercise: MetricSelection?
    @AppStorage("fitness.showCardio") private var showCardio = true
    @AppStorage("fitness.showStrength") private var showStrength = true

    private let engine = FitnessEngine()

    private var fitnessHistory: [DailyHealthSnapshot] {
        let withoutToday = health.history.filter { !Calendar.current.isDate($0.date, inSameDayAs: health.snapshot.date) }
        return (withoutToday + (health.snapshot.availableSignalCount > 0 ? [health.snapshot] : []))
            .sorted { $0.date < $1.date }
    }

    private var points: [FitnessDayPoint] {
        engine.points(history: fitnessHistory, manualActivities: manualActivities)
    }

    private var focus: FitnessFocusBreakdown { engine.focus(history: fitnessHistory) }
    private var latestHRR: Double? { engine.latestHeartRateRecovery(history: fitnessHistory) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("tab.training")
                                .font(.largeTitle.weight(.bold))
                            Text("Últimos 30 días")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)

                        entrance(0) { activityCalendar }
                        entrance(1) { activitySummaryCard }
                        entrance(2) { appleHealthWorkoutsSection }
                        entrance(3) { strainPerformanceCard }

                        entrance(4) {
                            WeeklyRoutineSection(
                                templates: templates,
                                latestRecovery: scoreRecords.first?.recovery,
                                healthWorkouts: fitnessHistory.flatMap(\.workouts),
                                revision: routineRevision,
                                onStart: { template in activeSessionTemplate = template },
                                onEdit: { template in editingTemplate = template },
                                onConfigure: { showRoutineOnboarding = true }
                            )
                        }

                        if showCardio {
                            entrance(5) { sectionTitle("Cardio") }
                            entrance(6) { cardioGrid }
                        }

                        if showStrength {
                            entrance(7) { sectionTitle("Fuerza") }
                            entrance(8) { strengthVolumeCard }
                            entrance(9) { strengthProgressionCard }
                            entrance(10) { exerciseProgressionCard }
                            entrance(11) { workoutTemplates }
                        }

                        Button { composer = .sections } label: {
                            Label("Editar Entrenamiento", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
                        .liquidGlass(cornerRadius: 8)

                        Text("La Carga es una estimación de bienestar basada en duración, zonas de frecuencia cardíaca y tu referencia personal. No predice lesiones ni sustituye una evaluación profesional.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
                .refreshable { await health.refresh() }
            }
            .navigationTitle("tab.training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { addMenu }
            }
            .liquidGlassNavigationBar()
            .sheet(item: $selectedDetail) { route in
                FitnessDetailSheet(
                    route: route,
                    points: points,
                    focus: focus,
                    heartRateRecovery: latestHRR,
                    history: fitnessHistory,
                    manualActivities: manualActivities
                )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .presentationBackground(Color(red: 0.075, green: 0.08, blue: 0.095))
            }
            .sheet(item: $composer) { destination in
                switch destination {
                case .activity:
                    FitnessActivityEditor()
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                case .template:
                    WorkoutTemplateEditor()
                        .presentationDetents([.medium, .large])
                        .presentationCornerRadius(30)
                case .sections:
                    FitnessSectionEditor(showCardio: $showCardio, showStrength: $showStrength)
                        .presentationDetents([.medium])
                        .presentationCornerRadius(30)
                }
            }
            .sheet(item: $previewTemplate) { template in
                TemplatePreviewSheet(
                    template: template,
                    onEdit: { editingTemplate = template },
                    onStart: { activeSessionTemplate = template },
                    onDelete: { deleteTemplate(template) }
                )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
            }
            .sheet(item: $editingTemplate) { template in
                WorkoutTemplateEditor(editing: template)
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
            }
            .fullScreenCover(item: $activeSessionTemplate) { template in
                if template.kind == .strength {
                    ActiveWorkoutSessionView(template: template)
                } else {
                    ActiveTimedRoutineView(template: template)
                }
            }
            .sheet(item: $progressionExercise) { selection in
                MetricDetailView(
                    descriptors: ExerciseProgression.descriptors(exerciseName: selection.key, setLogs: setLogs),
                    series: { descriptor in
                        ExerciseProgression.series(for: descriptor, exerciseName: selection.key, setLogs: setLogs)
                    },
                    selectedKey: "weight.\(selection.key)"
                )
                .presentationDetents([.large])
                .presentationCornerRadius(30)
            }
            .sheet(isPresented: $showRoutineOnboarding, onDismiss: { routineRevision += 1 }) {
                WeeklyPlanOnboardingView(templates: templates)
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
            }
            .sheet(isPresented: $showTemplateManager) {
                WorkoutTemplateManagerView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
            }
            .task {
                _ = WorkoutTemplateCatalogSeeder.seed(in: modelContext, existing: templates)
                if !UserDefaults.standard.bool(forKey: "skipHealthKitRefresh") { await health.refresh() }
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private func entrance<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 16)
            .animation(
                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.86).delay(Double(index) * 0.04),
                value: appeared
            )
    }

    private var addMenu: some View {
        Menu {
            Button {
                Haptics.menuSelect()
                composer = .activity
            } label: {
                Label("Registrar entrenamiento", systemImage: "figure.run")
            }
            Button {
                Haptics.menuSelect()
                composer = .template
            } label: {
                Label("Crear rutina de fuerza", systemImage: "square.grid.2x2")
            }
            Divider()
            Button {
                Haptics.menuSelect()
                Task { await health.refresh() }
            } label: {
                Label("Actualizar Apple Health", systemImage: "heart.text.square")
            }
            Button {
                Haptics.menuSelect()
                composer = .sections
            } label: {
                Label("Editar Entrenamiento", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .contentShape(Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(Color.cyan.opacity(0.24), lineWidth: 0.8)
                }
                .shadow(color: .cyan.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
        .accessibilityIdentifier("fitness.add")
        .accessibilityLabel("Agregar a Entrenamiento")
    }

    private var activityCalendar: some View {
        FitnessActivityCalendar(points: points)
            .padding(16)
            .liquidGlass(cornerRadius: 8)
            .accessibilityIdentifier("fitness.calendar")
    }

    private var activitySummaryCard: some View {
        Button { selectedDetail = .activity } label: {
            let total = points.reduce(0) { $0 + $1.minutes }
            let recent = points.suffix(15).reduce(0) { $0 + $1.minutes }
            let prior = points.prefix(15).reduce(0) { $0 + $1.minutes }
            let difference = recent - prior

            VStack(alignment: .leading, spacing: 12) {
                metricHeader("Resumen de actividad", icon: "square.grid.3x3.fill")
                HStack(alignment: .firstTextBaseline) {
                    Text(durationText(total))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Label(durationText(abs(difference)), systemImage: difference >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(difference >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                }
                Text("Tiempo registrado en entrenamientos y actividad manual")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(points) { point in
                    LineMark(
                        x: .value("Dia", point.date),
                        y: .value("Minutos", point.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(ScoreKind.strain.color.gradient)
                    AreaMark(
                        x: .value("Dia", point.date),
                        y: .value("Minutos", point.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [ScoreKind.strain.color.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 92)
            }
            .padding(16)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
        }
        .buttonStyle(.glassCardLink)
        .accessibilityIdentifier("fitness.activitySummary")
    }

    private var appleHealthWorkouts: [WorkoutSummary] {
        fitnessHistory
            .flatMap(\.workouts)
            .sorted { $0.startDate > $1.startDate }
    }

    private var appleHealthWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Apple Health", systemImage: "heart.fill")
                    .font(.headline)
                Spacer()
                if !appleHealthWorkouts.isEmpty {
                    Text("\(appleHealthWorkouts.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if health.dataMode == .empty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sin acceso a entrenamientos")
                        .font(.subheadline.weight(.semibold))
                    Text("Conecta Apple Health para consultar entrenamientos con tipo, duración y calorías.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await health.requestAuthorization() }
                    } label: {
                        Label("Conectar Apple Health", systemImage: "link")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
                }
            } else if appleHealthWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sin entrenamientos en Apple Health")
                        .font(.subheadline.weight(.semibold))
                    Text("No hay entrenamientos detallados en los últimos 30 días. Aun así, Apple Health puede aportar minutos de actividad acumulada.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appleHealthWorkouts.prefix(8))) { workout in
                        appleHealthWorkoutRow(workout)
                        if workout.id != appleHealthWorkouts.prefix(8).last?.id {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
        .accessibilityIdentifier("fitness.workoutList")
    }

    private func appleHealthWorkoutRow(_ workout: WorkoutSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "figure.run")
                .font(.body.weight(.semibold))
                .foregroundStyle(ScoreKind.strain.color)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activityName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(workout.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(durationText(workout.durationMinutes))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                if let energy = workout.activeEnergy {
                    Text("\(Int(energy.rounded())) kcal")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sin kcal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("fitness.workout.\(workout.id.uuidString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workoutAccessibilityLabel(workout))
    }

    private func workoutAccessibilityLabel(_ workout: WorkoutSummary) -> String {
        var parts = [
            workout.activityName,
            workout.startDate.formatted(date: .abbreviated, time: .shortened),
            durationText(workout.durationMinutes)
        ]
        if let energy = workout.activeEnergy {
            parts.append("\(Int(energy.rounded())) kilocalorias")
        }
        return parts.joined(separator: ", ")
    }

    private var strainPerformanceCard: some View {
        Button { selectedDetail = .strain } label: {
            let active = points.filter { $0.strain > 0 }
            let average = active.isEmpty ? 0 : active.reduce(0) { $0 + $1.strainDeviation } / Double(active.count)
            VStack(alignment: .leading, spacing: 12) {
                metricHeader(RecvelL10n.text("training.loadResponse.title"), icon: "waveform.path.ecg")
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%+.0f%%", average))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(strainStatusColor(average))
                    Text(strainStatus(average))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Chart(points) { point in
                    LineMark(x: .value("Dia", point.date), y: .value("Desviacion", point.strainDeviation))
                        .foregroundStyle(.blue.opacity(0.55))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Dia", point.date), y: .value("Desviacion", point.strainDeviation))
                        .foregroundStyle(strainStatusColor(point.strainDeviation))
                        .symbolSize(point.strain > 0 ? 20 : 0)
                    RuleMark(y: .value("Objetivo", 0))
                        .foregroundStyle(.white.opacity(0.14))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: -80...80)
                .frame(height: 82)
            }
            .padding(16)
            .liquidGlass(cornerRadius: 8, tint: .blue)
        }
        .buttonStyle(.glassCardLink)
        .accessibilityIdentifier("fitness.strainPerformance")
    }

    private var cardioGrid: some View {
        VStack(spacing: 10) {
            Button { selectedDetail = .cardioLoad } label: { cardioLoadCard }
                .buttonStyle(.glassCardLink)
                .accessibilityIdentifier("fitness.cardioLoad")
            HStack(spacing: 10) {
                Button { selectedDetail = .cardioFocus } label: { cardioFocusCard }
                    .buttonStyle(.glassCardLink)
                    .accessibilityIdentifier("fitness.cardioFocus")
                Button { selectedDetail = .heartRateRecovery } label: { heartRateRecoveryCard }
                    .buttonStyle(.glassCardLink)
                    .accessibilityIdentifier("fitness.hrr")
            }
        }
    }

    private var cardioLoadCard: some View {
        let last7 = points.suffix(7).reduce(0) { $0 + $1.cardiovascularLoad }
        let prior = points.dropLast(7).reduce(0) { $0 + $1.cardiovascularLoad } / 23 * 7
        let status = cardioLoadStatus(current: last7, typical: prior)
        return VStack(alignment: .leading, spacing: 11) {
            metricHeader("Carga cardio", icon: "figure.run")
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f", last7)).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                Text(status).font(.caption.weight(.bold)).foregroundStyle(.purple)
                Spacer()
            }
            Chart(points) { point in
                LineMark(x: .value("Dia", point.date), y: .value("Carga", point.cardiovascularLoad))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.purple.gradient)
                AreaMark(x: .value("Dia", point.date), y: .value("Carga", point.cardiovascularLoad))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 78)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: .purple)
    }

    private var cardioFocusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Foco cardio", systemImage: "square.3.layers.3d")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(focus.primaryLabel).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
            Text(focus.total > 0 ? "\(focus.lowPercent)% del tiempo" : "Necesita zonas FC")
                .font(.caption).foregroundStyle(focus.total > 0 ? .cyan : .secondary)
            focusBar(value: focus.lowPercent, color: .cyan)
            focusBar(value: focus.highPercent, color: .blue)
            focusBar(value: focus.anaerobicPercent, color: .purple)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(15)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
    }

    private var heartRateRecoveryCard: some View {
        let status = hrrStatus(latestHRR)
        return VStack(alignment: .leading, spacing: 10) {
            Label("HRR 1 min", systemImage: "heart.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(latestHRR.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                Text("bpm").font(.caption).foregroundStyle(.secondary)
            }
            Text(status).font(.caption.weight(.bold)).foregroundStyle(.pink)
            Spacer(minLength: 2)
            Sparkline(values: hrrHistory, color: .pink)
                .frame(height: 46)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(15)
        .liquidGlass(cornerRadius: 8, tint: .pink)
    }

    private var strengthVolumeCard: some View {
        let strengthLogs = manualActivities.filter { $0.category == "Fuerza" && ($0.totalVolumeKg ?? 0) > 0 }
        let groups = ["Pecho", "Espalda", "Piernas", "Hombros", "Brazos", "Core"]
        let values = groups.map { group in
            strengthLogs.filter { $0.muscleGroup == group }.reduce(0) { $0 + ($1.totalVolumeKg ?? 0) }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Volumen total", systemImage: "scalemass.fill").font(.headline)
                Spacer()
                Text(values.reduce(0, +) > 0 ? "\(Int(values.reduce(0, +))) kg" : "Sin dato")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            MuscleRadar(labels: groups, values: values)
                .frame(height: 238)
            if values.allSatisfy({ $0 == 0 }) {
                Text("Registra series x repeticiones x peso para activar el mapa muscular. No estimamos volumen desde HealthKit.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("fitness.strengthVolume")
    }

    private var strengthProgressionCard: some View {
        Button { selectedDetail = .strength } label: {
            let strengthPoints = strengthProgressionPoints
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Progresion de fuerza", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
                    Spacer()
                    Menu {
                        Button("Frecuencia") {
                            Haptics.menuSelect()
                            strengthMetric = "Frecuencia"
                        }
                        Button("Minutos") {
                            Haptics.menuSelect()
                            strengthMetric = "Minutos"
                        }
                    } label: {
                        Label(strengthMetric, systemImage: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .hapticMenuLabel()
                }
                if strengthPoints.allSatisfy({ $0.value == 0 }) {
                    FitnessEmptyPlot(title: "Sin progresion todavia", detail: "Tus sesiones de fuerza apareceran aqui.")
                        .frame(height: 150)
                } else {
                    Chart(strengthPoints) { point in
                        BarMark(x: .value("Dia", point.date), y: .value(strengthMetric, point.value))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top))
                            .cornerRadius(4)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 150)
                }
            }
            .padding(16)
            .liquidGlass(cornerRadius: 8, tint: .blue)
        }
        .buttonStyle(.glassCardLink)
        .accessibilityIdentifier("fitness.strengthProgression")
    }

    /// Ejercicios con series registradas. Cada uno abre el detalle con su
    /// progresión de peso y 1RM estimado (reusa `MetricDetailView`). Antes las
    /// series se descartaban, así que no había progresión por ejercicio.
    private var exerciseSummaries: [ExerciseProgression.Summary] {
        ExerciseProgression.summaries(from: setLogs)
    }

    private var exerciseProgressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progresión por ejercicio", systemImage: "chart.xyaxis.line")
                .font(.headline)
            if exerciseSummaries.isEmpty {
                Text("Registra una sesión de fuerza con series y kilos para ver aquí tu progresión de peso y 1RM estimado por ejercicio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(exerciseSummaries) { summary in
                    Button {
                        Haptics.soft()
                        progressionExercise = MetricSelection(key: summary.exerciseName)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.exerciseName).font(.subheadline.weight(.semibold))
                                Text("\(summary.sessionCount) sesiones · \(summary.muscleGroup)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if let e1rm = summary.latestOneRepMax {
                                    Text("\(Int(e1rm)) kg").font(.subheadline.weight(.bold)).monospacedDigit()
                                    Text("1RM est.").font(.system(size: 8, weight: .heavy)).foregroundStyle(.tertiary)
                                } else {
                                    Text("\(Int(summary.latestTopSet)) kg").font(.subheadline.weight(.bold)).monospacedDigit()
                                    Text("top set").font(.system(size: 8, weight: .heavy)).foregroundStyle(.tertiary)
                                }
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fitness.exerciseProgression.\(summary.exerciseName)")
                    if summary.id != exerciseSummaries.last?.id {
                        Divider().overlay(Color.white.opacity(0.07))
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: .blue)
        .accessibilityIdentifier("fitness.exerciseProgressionCard")
    }

    private var workoutTemplates: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plantillas de entrenamiento").font(.title3.weight(.bold))
                Spacer()
                if !templates.isEmpty {
                    Menu {
                        Button {
                            Haptics.menuSelect()
                            showTemplateManager = true
                        } label: {
                            Label("Editar rutinas", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .hapticMenuLabel()
                    .accessibilityIdentifier("fitness.templates.menu")
                }
                Button {
                    Haptics.add()
                    composer = .template
                } label: {
                    Image(systemName: "plus")
                        .headerCircleChrome(size: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Crear rutina")
            }

            if templates.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        templateSkeleton
                        templateSkeleton
                    }
                    .opacity(0.35)
                    Text("Sin rutinas").font(.headline)
                    Text("Crea rutinas reutilizables de fuerza, cardio, movilidad o recuperacion y enlazalas a tu plan semanal.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        Haptics.add()
                        composer = .template
                    } label: {
                        Label("Agregar rutina", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .platformGlass(tint: .cyan, interactive: true, shape: .capsule)
                            .tappableCapsule()
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .liquidGlass(cornerRadius: 16)
            } else {
                // Segmentado por tipo: las rutinas de fuerza, cardio, movilidad
                // y desafio viven todas aqui (Plantillas = LA vista de rutinas).
                ForEach(templateKindSections, id: \.kind) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(section.kind.title, systemImage: section.kind.icon)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                        templateGrid(section.templates)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("fitness.templates.section.\(section.kind.rawValue)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.templates")
    }

    /// Secciones de plantillas por tipo, en orden fijo, solo las no vacias.
    private var templateKindSections: [(kind: WorkoutTemplateKind, templates: [WorkoutTemplate])] {
        let order: [WorkoutTemplateKind] = [.strength, .cardio, .mobility, .recovery, .dailyChallenge, .performance]
        return order.compactMap { kind in
            let matching = templates.filter { $0.kind == kind }
            return matching.isEmpty ? nil : (kind, matching)
        }
    }

    private func templateGrid(_ items: [WorkoutTemplate]) -> some View {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items) { template in
                        Button {
                            previewTemplate = template
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: template.kind.icon)
                                    .foregroundStyle(.cyan)
                                Text(template.name).font(.subheadline.weight(.bold)).lineLimit(2)
                                Text(template.focus).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 0)
                                HStack {
                                    Text("\(template.exerciseCount) ejercicios").font(.caption2.weight(.semibold)).foregroundStyle(.cyan)
                                    Spacer()
                                    Image(systemName: "play.circle").font(.caption).foregroundStyle(.cyan)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                            .padding(14)
                            .liquidGlass(cornerRadius: 8, tint: .cyan)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
                        .contextMenu {
                            Button {
                                Haptics.rigid()
                                activeSessionTemplate = template
                            } label: {
                                Label("Empezar", systemImage: "play.fill")
                            }
                            Button {
                                Haptics.menuSelect()
                                editingTemplate = template
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                deleteTemplate(template)
                            } label: {
                                Label("Eliminar rutina", systemImage: "trash")
                            }
                        }
                        .accessibilityIdentifier("fitness.template.card.\(template.name.replacingOccurrences(of: " ", with: "_"))")
                    }
                }
    }

    private var templateSkeleton: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule().fill(Color.white.opacity(0.05)).frame(width: 64, height: 8)
            Capsule().fill(Color.white.opacity(0.04)).frame(height: 8)
            HStack { ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.04)).frame(height: 28) } }
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 96).contentShape(Rectangle()).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
    }

    private struct StrengthPoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var strengthProgressionPoints: [StrengthPoint] {
        points.map { point in
            let healthStrength = fitnessHistory
                .first { Calendar.current.isDate($0.date, inSameDayAs: point.date) }?
                .workouts.filter { $0.activityName.localizedCaseInsensitiveContains("Fuerza") } ?? []
            let manual = manualActivities.filter {
                $0.category == "Fuerza" && Calendar.current.isDate($0.startDate, inSameDayAs: point.date)
            }
            let value = strengthMetric == "Minutos"
                ? healthStrength.reduce(0) { $0 + $1.durationMinutes } + manual.reduce(0) { $0 + $1.durationMinutes }
                : Double(healthStrength.count + manual.count)
            return StrengthPoint(date: point.date, value: value)
        }
    }

    private var hrrHistory: [Double] {
        let values = fitnessHistory.flatMap(\.workouts).sorted { $0.endDate < $1.endDate }.compactMap(\.heartRateRecoveryOneMinute)
        return values.isEmpty ? [0, 0, 0, 0] : values
    }

    private func metricHeader(_ title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.headline)
            Spacer()
            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title2.weight(.bold)).padding(.top, 12)
    }

    private func focusBar(value: Int, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().fill(color.gradient).frame(width: proxy.size.width * CGFloat(value) / 100)
            }
        }
        .frame(height: 6)
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        Haptics.warning()
        if previewTemplate == template { previewTemplate = nil }
        modelContext.delete(template)
        try? modelContext.save()
    }

    private func durationText(_ minutes: Double) -> String {
        let rounded = max(Int(minutes.rounded()), 0)
        return rounded >= 60 ? "\(rounded / 60)h \(rounded % 60)m" : "\(rounded)m"
    }

    private func strainStatus(_ deviation: Double) -> String {
        if deviation < -12 { return "Debajo del objetivo" }
        if deviation > 12 { return "Sobre el objetivo" }
        return "Dentro del objetivo"
    }

    private func strainStatusColor(_ deviation: Double) -> Color {
        if deviation < -12 { return .blue }
        if deviation > 12 { return ScoreKind.strain.color }
        return ScoreKind.recovery.color
    }

    private func cardioLoadStatus(current: Double, typical: Double) -> String {
        guard typical > 0 else { return current > 0 ? "Calibrando" : "Sin datos" }
        let ratio = current / typical
        if ratio < 0.75 { return "Por debajo" }
        if ratio > 1.35 { return "Carga alta" }
        return "Manteniendo"
    }

    private func hrrStatus(_ value: Double?) -> String {
        guard let value else { return "Sin muestra posterior al entrenamiento" }
        if value >= 35 { return "Recuperación rápida" }
        if value >= 20 { return "Rango intermedio" }
        return "Observa la tendencia"
    }
}

private struct FitnessActivityCalendar: View {
    let points: [FitnessDayPoint]
    private let calendar = Calendar.autoupdatingCurrent

    private var months: [Date] {
        let now = Date.now
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let previous = calendar.date(byAdding: .month, value: -1, to: current) ?? current
        return [previous, current]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(months, id: \.self) { month in
                    monthGrid(month)
                }
            }
            HStack(spacing: 14) {
                legend(color: .green, text: "1 actividad")
                legend(color: ScoreKind.recovery.color, text: "2 actividades")
                legend(color: .cyan, text: "3+")
            }
        }
    }

    private func monthGrid(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.formatted(.dateTime.month(.abbreviated).year()))
                .font(.subheadline.weight(.bold))
            HStack(spacing: 4) {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                    Text(day).font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 7) {
                ForEach(0..<42, id: \.self) { index in
                    if let date = dateForCell(index, month: month) {
                        let count = activityCount(on: date)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(activityColor(count))
                            .frame(height: 7)
                            .overlay {
                                if calendar.isDateInToday(date) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                }
                            }
                            .shadow(color: count > 0 ? activityColor(count).opacity(0.5) : .clear, radius: 3)
                    } else {
                        Color.clear.frame(height: 7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dateForCell(_ index: Int, month: Date) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return nil }
        let weekday = calendar.component(.weekday, from: month)
        let mondayOffset = (weekday + 5) % 7
        let day = index - mondayOffset + 1
        guard range.contains(day) else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: month)
    }

    private func activityCount(on date: Date) -> Int {
        points.first { calendar.isDate($0.date, inSameDayAs: date) }?.activityCount ?? 0
    }

    private func activityColor(_ count: Int) -> Color {
        switch count {
        case 1: .green.opacity(0.75)
        case 2: ScoreKind.recovery.color.opacity(0.82)
        case 3...: .cyan.opacity(0.9)
        default: Color.white.opacity(0.06)
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
        }
    }
}

private struct FitnessDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: FitnessDetailRoute
    let points: [FitnessDayPoint]
    let focus: FitnessFocusBreakdown
    let heartRateRecovery: Double?
    let history: [DailyHealthSnapshot]
    let manualActivities: [FitnessActivityLog]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Button {
                            Haptics.soft()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .headerCircleChrome(size: 42)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cerrar")
                        Spacer()
                        Text(route.title).font(.headline)
                        Spacer()
                        Color.clear.frame(width: 42, height: 42)
                    }
                    detailHero
                    breakdown
                    scienceContext
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailHero: some View {
        switch route {
        case .activity:
            let total = points.reduce(0) { $0 + $1.minutes }
            heroValue(durationText(total), status: "30 días", color: ScoreKind.strain.color)
            Chart(points) { point in
                BarMark(x: .value("Dia", point.date), y: .value("Minutos", point.minutes))
                    .foregroundStyle(ScoreKind.strain.color.gradient).cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.06)); AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis(.hidden).frame(height: 280)

        case .strain:
            let active = points.filter { $0.strain > 0 }
            let value = active.isEmpty ? 0 : active.reduce(0) { $0 + $1.strainDeviation } / Double(active.count)
            heroValue(String(format: "%+.0f%%", value), status: strainStatus(value), color: statusColor(value))
            Chart(points) { point in
                AreaMark(x: .value("Dia", point.date), yStart: .value("Min", -12), yEnd: .value("Max", 12))
                    .foregroundStyle(ScoreKind.recovery.color.opacity(0.10))
                LineMark(x: .value("Dia", point.date), y: .value("Desviacion", point.strainDeviation))
                    .foregroundStyle(.blue).interpolationMethod(.catmullRom)
                PointMark(x: .value("Dia", point.date), y: .value("Desviacion", point.strainDeviation))
                    .foregroundStyle(statusColor(point.strainDeviation)).symbolSize(point.strain > 0 ? 34 : 0)
            }
            .chartYScale(domain: -80...80).frame(height: 300)

        case .cardioLoad:
            let total = points.suffix(7).reduce(0) { $0 + $1.cardiovascularLoad }
            heroValue(String(format: "%.0f", total), status: "Carga relativa de 7 días", color: .purple)
            Chart(points) { point in
                LineMark(x: .value("Dia", point.date), y: .value("Carga", point.cardiovascularLoad))
                    .foregroundStyle(.purple).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Dia", point.date), y: .value("Carga", point.cardiovascularLoad))
                    .foregroundStyle(.purple.opacity(0.14)).interpolationMethod(.catmullRom)
            }.frame(height: 300)

        case .cardioFocus:
            heroValue(focus.primaryLabel, status: focus.total > 0 ? "Distribucion por zonas FC" : "Sin zonas suficientes", color: .cyan)
            Chart([
                FocusDatum(name: "Aerobico bajo", value: focus.lowAerobic, color: .cyan),
                FocusDatum(name: "Aerobico alto", value: focus.highAerobic, color: .blue),
                FocusDatum(name: "Anaerobico", value: focus.anaerobic, color: .purple)
            ]) { item in
                BarMark(x: .value("Zona", item.name), y: .value("Minutos", item.value))
                    .foregroundStyle(item.color.gradient).cornerRadius(5)
            }.chartYAxis(.hidden).frame(height: 300)

        case .heartRateRecovery:
            heroValue(heartRateRecovery.map { "\(Int($0.rounded())) bpm" } ?? "Sin dato", status: "Descenso al minuto 1", color: .pink)
            HRRScale(value: heartRateRecovery).frame(height: 120)

        case .strength:
            let sessions = strengthSessionCount
            heroValue("\(sessions)", status: "Sesiones de fuerza en 30 días", color: .blue)
            Chart(points) { point in
                BarMark(x: .value("Dia", point.date), y: .value("Minutos", strengthMinutes(on: point.date)))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top)).cornerRadius(4)
            }.chartYAxis(.hidden).frame(height: 280)
        }
    }

    @ViewBuilder
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(breakdownTitle).font(.title2.weight(.bold))
            switch route {
            case .activity:
                breakdownRow("Dias activos", value: "\(points.filter { $0.activityCount > 0 }.count)", progress: Double(points.filter { $0.activityCount > 0 }.count) / 30, color: .green)
                breakdownRow("Workouts", value: "\(points.reduce(0) { $0 + $1.activityCount })", progress: min(Double(points.reduce(0) { $0 + $1.activityCount }) / 20, 1), color: .cyan)
            case .strain:
                let below = points.filter { $0.strain > 0 && $0.strainDeviation < -12 }.count
                let within = points.filter { $0.strain > 0 && abs($0.strainDeviation) <= 12 }.count
                let above = points.filter { $0.strain > 0 && $0.strainDeviation > 12 }.count
                let total = max(below + within + above, 1)
                breakdownRow("Por debajo", value: "\(below) días", progress: Double(below) / Double(total), color: .blue)
                breakdownRow("Dentro del rango", value: "\(within) días", progress: Double(within) / Double(total), color: .green)
                breakdownRow("Por encima", value: "\(above) días", progress: Double(above) / Double(total), color: .orange)
            case .cardioLoad:
                breakdownRow("Últimos 7 días", value: String(format: "%.0f", points.suffix(7).reduce(0) { $0 + $1.cardiovascularLoad }), progress: 0.72, color: .purple)
                breakdownRow("21 días anteriores", value: String(format: "%.0f", points.dropLast(7).reduce(0) { $0 + $1.cardiovascularLoad }), progress: 0.58, color: .cyan)
            case .cardioFocus:
                breakdownRow("Aerobico bajo", value: "\(focus.lowPercent)%", progress: Double(focus.lowPercent) / 100, color: .cyan)
                breakdownRow("Aerobico alto", value: "\(focus.highPercent)%", progress: Double(focus.highPercent) / 100, color: .blue)
                breakdownRow("Anaerobico", value: "\(focus.anaerobicPercent)%", progress: Double(focus.anaerobicPercent) / 100, color: .purple)
            case .heartRateRecovery:
                HRRScale(value: heartRateRecovery)
            case .strength:
                breakdownRow("Sesiones", value: "\(strengthSessionCount)", progress: min(Double(strengthSessionCount) / 12, 1), color: .blue)
                breakdownRow("Minutos", value: "\(Int(totalStrengthMinutes))", progress: min(totalStrengthMinutes / 360, 1), color: .cyan)
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("fitness.detail.breakdown")
    }

    private var scienceContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cómo interpretar esta métrica", systemImage: "info.circle.fill")
                .font(.headline).foregroundStyle(.cyan)
            Text(scienceText)
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Usa la tendencia junto con sensaciones, descanso y contexto. Recvel no diagnostica ni predice lesiones.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .accessibilityIdentifier("fitness.detail.science")
    }

    private struct FocusDatum: Identifiable {
        let name: String
        let value: Double
        let color: Color
        var id: String { name }
    }

    private func heroValue(_ value: String, status: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(color).minimumScaleFactor(0.6)
            Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func breakdownRow(_ title: String, value: String, progress: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).frame(width: 105, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(color).frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }.frame(height: 7)
            Text(value).font(.caption.weight(.bold)).monospacedDigit().frame(width: 58, alignment: .trailing)
        }
    }

    private var breakdownTitle: String {
        switch route {
        case .activity: "Consistencia"
        case .strain: "Rango objetivo"
        case .cardioLoad: "Carga reciente"
        case .cardioFocus: "Distribucion"
        case .heartRateRecovery: "Referencia orientativa"
        case .strength: "Trabajo de fuerza"
        }
    }

    private var scienceText: String {
        switch route {
        case .activity:
            "La consistencia y el volumen semanal aportan más contexto que un solo entrenamiento. Los minutos incluyen Apple Health y registros manuales confirmados."
        case .strain:
            "Compara tu Carga diaria con un rango ajustado según tu Recuperación. Sirve para modular el esfuerzo; no es una cuota ni una predicción de riesgo."
        case .cardioLoad:
            "La carga combina tiempo en zonas de frecuencia cardiaca. Cuando faltan zonas, usa duracion como fallback de baja confianza. Observa varias semanas."
        case .cardioFocus:
            "Las zonas bajas favorecen volumen aerobico sostenible; las altas y anaerobicas aumentan intensidad. La mezcla adecuada depende del deporte y objetivo."
        case .heartRateRecovery:
            "La recuperación de la frecuencia cardíaca es la disminución durante el primer minuto después de terminar. La hidratación, el calor, la postura y la forma de detener el entrenamiento pueden modificarla."
        case .strength:
            "La frecuencia y el volumen confirmados permiten observar la progresión. Recvel no infiere series, repeticiones ni peso desde un entrenamiento genérico de HealthKit."
        }
    }

    private func durationText(_ minutes: Double) -> String {
        let value = Int(minutes.rounded())
        return value >= 60 ? "\(value / 60)h \(value % 60)m" : "\(value)m"
    }

    private func strainStatus(_ deviation: Double) -> String {
        if deviation < -12 { return "Debajo del objetivo" }
        if deviation > 12 { return "Sobre el objetivo" }
        return "Dentro del objetivo"
    }

    private func statusColor(_ deviation: Double) -> Color {
        if deviation < -12 { return .blue }
        if deviation > 12 { return .orange }
        return .green
    }

    private var strengthSessionCount: Int {
        history.flatMap(\.workouts).filter { $0.activityName.localizedCaseInsensitiveContains("Fuerza") }.count +
        manualActivities.filter { $0.category == "Fuerza" }.count
    }

    private var totalStrengthMinutes: Double {
        history.flatMap(\.workouts).filter { $0.activityName.localizedCaseInsensitiveContains("Fuerza") }.reduce(0) { $0 + $1.durationMinutes } +
        manualActivities.filter { $0.category == "Fuerza" }.reduce(0) { $0 + $1.durationMinutes }
    }

    private func strengthMinutes(on date: Date) -> Double {
        let calendar = Calendar.current
        let healthMinutes = history
            .first { calendar.isDate($0.date, inSameDayAs: date) }?
            .workouts.filter { $0.activityName.localizedCaseInsensitiveContains("Fuerza") }
            .reduce(0) { $0 + $1.durationMinutes } ?? 0
        let manualMinutes = manualActivities
            .filter { $0.category == "Fuerza" && calendar.isDate($0.startDate, inSameDayAs: date) }
            .reduce(0) { $0 + $1.durationMinutes }
        return healthMinutes + manualMinutes
    }
}

private struct HRRScale: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lenta").foregroundStyle(.yellow)
                Spacer(); Text("Intermedia").foregroundStyle(.orange)
                Spacer(); Text("Rapida").foregroundStyle(.pink)
            }.font(.caption2.weight(.bold))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [.yellow, .orange, .pink, .purple], startPoint: .leading, endPoint: .trailing))
                    if let value {
                        Circle().fill(.white).frame(width: 18, height: 18)
                            .shadow(color: .white.opacity(0.65), radius: 6)
                            .offset(x: min(max(value / 50, 0), 1) * (proxy.size.width - 18))
                    }
                }
            }.frame(height: 18)
            HStack { Text("0"); Spacer(); Text("15"); Spacer(); Text("30"); Spacer(); Text("45+") }
                .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            LineMark(x: .value("Indice", item.offset), y: .value("Valor", item.element))
                .foregroundStyle(color.gradient).interpolationMethod(.catmullRom)
        }.chartXAxis(.hidden).chartYAxis(.hidden)
    }
}

private struct FitnessEmptyPlot: View {
    let title: String
    let detail: String
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack { Capsule().fill(Color.white.opacity(0.04)).frame(width: 100, height: 8); Spacer(); Capsule().fill(Color.white.opacity(0.04)).frame(width: 110, height: 8) }
                }
            }
            VStack(spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MuscleRadar: View {
    let labels: [String]
    let values: [Double]
    private let cyan = Color.cyan

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.31
            let maxValue = max(values.max() ?? 0, 1)
            ZStack {
                ForEach(1...4, id: \.self) { level in
                    radarPath(center: center, radius: radius * CGFloat(level) / 4, scales: Array(repeating: 1, count: labels.count))
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
                ForEach(labels.indices, id: \.self) { index in
                    Path { path in path.move(to: center); path.addLine(to: point(index: index, center: center, radius: radius)) }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    Text(labels[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .position(point(index: index, center: center, radius: radius * 1.28))
                }
                radarPath(center: center, radius: radius, scales: values.map { CGFloat($0 / maxValue) })
                    .fill(cyan.opacity(values.allSatisfy({ $0 == 0 }) ? 0.02 : 0.16))
                    .overlay {
                        radarPath(center: center, radius: radius, scales: values.map { CGFloat($0 / maxValue) })
                            .stroke(cyan.opacity(values.allSatisfy({ $0 == 0 }) ? 0.12 : 0.85), lineWidth: 2)
                    }
            }
        }
    }

    private func radarPath(center: CGPoint, radius: CGFloat, scales: [CGFloat]) -> Path {
        Path { path in
            for index in labels.indices {
                let scale = scales.indices.contains(index) ? scales[index] : 1
                let value = point(index: index, center: center, radius: radius * max(scale, 0.08))
                if index == 0 {
                    path.move(to: value)
                } else {
                    path.addLine(to: value)
                }
            }
            path.closeSubpath()
        }
    }

    private func point(index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * CGFloat.pi / CGFloat(max(labels.count, 1))
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private struct FitnessActivityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var category = "Cardio"
    @State private var date = Date.now
    @State private var duration = 45
    @State private var effort = 6
    @State private var volume = ""
    @State private var muscleGroup = "General"
    @State private var notes = ""

    private let categories = ["Cardio", "Fuerza", "Movilidad", "Deporte"]
    private let groups = ["General", "Pecho", "Espalda", "Piernas", "Hombros", "Brazos", "Core"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Entrenamiento") {
                    TextField("Ej. Carrera suave", text: $name)
                        .snappyTextInput()
                    Picker("Categoria", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }
                    DatePicker("Fecha", selection: $date)
                    Stepper("Duración: \(duration) min", value: $duration.hapticStep(), in: 5...300, step: 5)
                    Stepper("Esfuerzo percibido: \(effort)/10", value: $effort.hapticStep(), in: 1...10)
                }
                if category == "Fuerza" {
                    Section("Fuerza confirmada") {
                        Picker("Grupo principal", selection: $muscleGroup) { ForEach(groups, id: \.self) { Text($0) } }
                        TextField("Volumen total kg (opcional)", text: $volume).keyboardType(.decimalPad)
                        Text("Suma series x repeticiones x peso. Dejalo vacio si no lo conoces.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Notas") { TextField("Contexto opcional", text: $notes, axis: .vertical).lineLimit(3...6) }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Nuevo entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { hapticFeedback(.soft); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { hapticFeedback(.medium); save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let normalizedVolume = Double(volume.replacingOccurrences(of: ",", with: "."))
        modelContext.insert(FitnessActivityLog(
            startDate: date,
            activityName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            durationMinutes: Double(duration),
            perceivedEffort: effort,
            totalVolumeKg: normalizedVolume,
            muscleGroup: muscleGroup,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        try? modelContext.save()
        dismiss()
    }
}

@Observable
private final class WorkoutEditorDraft {
    var name: String
    var focus: String
    var kind: WorkoutTemplateKind
    var durationMinutes: Int
    var exercises: [EditableTemplateExercise]

    init(editing: WorkoutTemplate?) {
        name = editing?.name ?? ""
        focus = editing?.focus ?? "Fuerza general"
        kind = editing?.kind ?? .strength
        durationMinutes = editing?.durationMinutes ?? 30
        exercises = (editing.map { TemplateCodec.parse($0.exercisesText) } ?? []).map(EditableTemplateExercise.init)
    }
}

@Observable
private final class EditableTemplateExercise: Identifiable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var kg: Double?
    var durationSeconds: Int?

    init(_ exercise: TemplateExercise) {
        id = exercise.id
        name = exercise.name
        sets = exercise.sets
        reps = exercise.reps
        kg = exercise.kg
        durationSeconds = exercise.durationSeconds
    }

    init(name: String, sets: Int = 1, reps: Int = 12, kg: Double? = 10, durationSeconds: Int? = nil) {
        id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.kg = kg
        self.durationSeconds = durationSeconds
    }

    func asStruct() -> TemplateExercise {
        TemplateExercise(id: id, name: name, sets: sets, reps: reps, kg: kg, durationSeconds: durationSeconds)
    }
}

struct WorkoutTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var editing: WorkoutTemplate?

    @State private var draft: WorkoutEditorDraft
    @State private var showLibrary = false

    private let focusOptions = ["Fuerza general", "Pecho", "Espalda", "Piernas", "Hombros", "Brazos", "Core", "Full body"]

    init(editing: WorkoutTemplate? = nil) {
        self.editing = editing
        _draft = State(initialValue: WorkoutEditorDraft(editing: editing))
    }

    var body: some View {
        @Bindable var draft = draft
        ZStack {
            Color(red: 0.09, green: 0.095, blue: 0.11).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    WorkoutEditorHeader(
                        draft: draft,
                        focusOptions: focusOptions,
                        canDelete: editing != nil,
                        onClose: {
                            Haptics.soft()
                            dismiss()
                        },
                        onDelete: deleteRoutine
                    )

                    if draft.kind != .strength {
                        HStack {
                            Label(draft.kind.title, systemImage: draft.kind.icon)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Stepper(
                                "\(draft.durationMinutes) min",
                                value: $draft.durationMinutes,
                                in: 5...180,
                                step: 5
                            )
                            .labelsHidden()
                            Text("\(draft.durationMinutes) min")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                        }
                        .padding(13)
                        .liquidGlass(cornerRadius: 14, tint: .cyan)
                    }

                    if draft.exercises.isEmpty {
                        emptyState
                    } else {
                        ForEach(draft.exercises) { exercise in
                            TemplateExerciseEditorCard(exercise: exercise) {
                                Haptics.warning()
                                draft.exercises.removeAll { $0.id == exercise.id }
                            }
                            if exercise.id != draft.exercises.last?.id {
                                supersetLink
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            WorkoutEditorBottomBar(
                draft: draft,
                isEditingExisting: editing != nil,
                onAdd: {
                    Haptics.add()
                    showLibrary = true
                },
                onSave: save
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLibrary) {
            ExerciseLibrarySheet { names in
                for name in names {
                    draft.exercises.append(EditableTemplateExercise(name: name, sets: 1, reps: 12, kg: 10))
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.templateEditor")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Sin ejercicios")
                .font(.headline)
            Text("Toca el \"+\" para empezar a agregar ejercicios a tu rutina.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showLibrary = true
            } label: {
                Label("Agregar ejercicios", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .simultaneousGesture(TapGesture().onEnded { Haptics.add() })
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var supersetLink: some View {
        HStack {
            Spacer()
            Image(systemName: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06), in: Circle())
            Spacer()
        }
        .padding(.vertical, -2)
    }

    private func deleteRoutine() {
        Haptics.warning()
        if let editing {
            modelContext.delete(editing)
            try? modelContext.save()
        }
        dismiss()
    }

    private func save() {
        Keyboard.dismiss()
        var trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { trimmedName = "Nueva rutina" }
        Haptics.success()
        let models = draft.exercises
            .map { $0.asStruct() }
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let serialized = TemplateCodec.serialize(models)
        if let editing {
            editing.name = trimmedName
            editing.focus = draft.focus
            editing.exercisesText = serialized
            editing.kind = draft.kind
            editing.durationMinutes = draft.kind == .strength ? nil : draft.durationMinutes
        } else {
            modelContext.insert(WorkoutTemplate(
                name: trimmedName,
                focus: draft.focus,
                exercisesText: serialized,
                kind: draft.kind,
                durationMinutes: draft.kind == .strength ? nil : draft.durationMinutes
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct WorkoutEditorBottomBar: View {
    @Bindable var draft: WorkoutEditorDraft
    let isEditingExisting: Bool
    let onAdd: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isEditingExisting || !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Button(action: onAdd) {
                    Text("Agregar ejercicio")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                        .background(Color.white.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.templateEditor.addExercise")
                .simultaneousGesture(TapGesture().onEnded { Haptics.add() })

                Button(action: onSave) {
                    Text("Guardar")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canSave ? .black : .white.opacity(0.4))
                        .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                        .background(
                            Capsule().fill(canSave ? Color.white.opacity(0.85) : Color.white.opacity(0.07))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityIdentifier("fitness.templateEditor.save")
                .simultaneousGesture(TapGesture().onEnded { Haptics.rigid() })
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

private struct WorkoutEditorHeader: View {
    @Bindable var draft: WorkoutEditorDraft
    let focusOptions: [String]
    let canDelete: Bool
    let onClose: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .background(Color.white.opacity(0.08), in: Circle())
                        .tappableCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")

                Spacer()

                Menu {
                    Menu("Tipo de rutina") {
                        ForEach(WorkoutTemplateKind.allCases) { kind in
                            Button {
                                Haptics.menuSelect()
                                draft.kind = kind
                            } label: {
                                if draft.kind == kind {
                                    Label(kind.title, systemImage: "checkmark")
                                } else {
                                    Label(kind.title, systemImage: kind.icon)
                                }
                            }
                        }
                    }
                    Menu {
                        ForEach(focusOptions, id: \.self) { option in
                            Button {
                                Haptics.menuSelect()
                                draft.focus = option
                            } label: {
                                if draft.focus == option {
                                    Label(option, systemImage: "checkmark")
                                } else {
                                    Text(option)
                                }
                            }
                        }
                    } label: {
                        Label("Enfoque: \(draft.focus)", systemImage: "target")
                    }
                    if canDelete {
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Eliminar rutina", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .hapticMenuLabel()
                .accessibilityIdentifier("fitness.templateEditor.menu")
            }

            VStack(alignment: .leading, spacing: 2) {
                TextField("Nueva rutina", text: $draft.name)
                    .font(.title.weight(.bold))
                    .submitLabel(.done)
                    .snappyTextInput()
                    .accessibilityIdentifier("fitness.templateEditor.name")
                Text(draft.kind == .strength
                    ? "\(draft.exercises.count) ejercicios, \(draft.exercises.reduce(0) { $0 + $1.sets }) series"
                    : "\(draft.kind.title) · \(draft.exercises.count) ejercicios · \(draft.durationMinutes) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TemplateExerciseEditorCard: View {
    @Bindable var exercise: EditableTemplateExercise
    let onDelete: () -> Void

    var body: some View {
        let visual = ExerciseLibrary.thumbnail(for: exercise.name)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ExerciseThumbnail(item: visual, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                    Text(visual.equipment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "stopwatch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Menu {
                    Button {
                        Haptics.menuSelect()
                        exercise.durationSeconds = exercise.durationSeconds == nil ? 60 : nil
                        if exercise.durationSeconds != nil {
                            exercise.sets = 1
                            exercise.kg = nil
                        }
                    } label: {
                        Label(
                            exercise.durationSeconds == nil ? "Medir por tiempo" : "Medir por repeticiones",
                            systemImage: exercise.durationSeconds == nil ? "timer" : "repeat"
                        )
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Eliminar ejercicio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .hapticMenuLabel()
                .accessibilityLabel("Opciones de \(exercise.name)")
            }

            if exercise.durationSeconds != nil {
                HStack {
                    Label("Duración", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    editorSetPill(
                        value: Binding(
                            get: { String(max(exercise.durationSeconds ?? 60, 1)) },
                            set: { exercise.durationSeconds = max(Int($0) ?? 60, 1) }
                        ),
                        unit: "s",
                        keyboard: .numberPad
                    )
                    .frame(maxWidth: 150)
                }
            } else {
                HStack(spacing: 10) {
                    Text("SET").frame(width: 40, alignment: .center)
                    Text("KG").frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(0..<max(exercise.sets, 1), id: \.self) { setIndex in
                    HStack(spacing: 10) {
                        Text("\(setIndex + 1)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .overlay { Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1) }
                        editorSetPill(
                            value: Binding(
                                get: {
                                    guard let kg = exercise.kg else { return "" }
                                    return kg.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(kg)) : String(kg)
                                },
                                set: { exercise.kg = Double($0.replacingOccurrences(of: ",", with: ".")) }
                            ),
                            unit: "kg",
                            keyboard: .decimalPad
                        )
                        editorSetPill(
                            value: Binding(
                                get: { String(exercise.reps) },
                                set: { exercise.reps = max(Int($0) ?? exercise.reps, 1) }
                            ),
                            unit: "reps",
                            keyboard: .numberPad
                        )
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack {
                Label(exercise.durationSeconds == nil ? "Progresión" : "Por tiempo", systemImage: exercise.durationSeconds == nil ? "chart.line.uptrend.xyaxis" : "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 20)
                Button {
                    Haptics.add()
                    exercise.sets = min(exercise.sets + 1, 10)
                } label: {
                    Label("Agregar serie", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(exercise.durationSeconds != nil)
                .opacity(exercise.durationSeconds == nil ? 1 : 0.35)
                .accessibilityLabel("Agregar serie a \(exercise.name)")
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("fitness.templateEditor.exercise.\(exercise.name.replacingOccurrences(of: " ", with: "_"))")
    }

    private func editorSetPill(value: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 4) {
            CommitOnBlurTextField(placeholder: "—", text: value, keyboard: keyboard, alignment: .trailing)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Biblioteca de ejercicios (estilo Bevel Library)

/// Metadata visual local (sin assets de terceros): miniatura + equipo.
struct ExerciseCatalogItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let group: String
    let equipment: String
    let symbol: String
    let accent: Color
}

enum ExerciseLibrary {
    // Simbolo = patron de movimiento (empuje, jalon, bisagra, etc.), no generico,
    // para que la silueta "cuente" el ejercicio como las ilustraciones de Bevel.
    static let items: [ExerciseCatalogItem] = [
        // Pecho
        .init(name: "Press de banca", group: "Pecho", equipment: "Barra", symbol: "figure.wrestling", accent: .orange),
        .init(name: "Press inclinado", group: "Pecho", equipment: "Barra", symbol: "figure.wrestling", accent: .orange),
        .init(name: "Aperturas con mancuernas", group: "Pecho", equipment: "Mancuernas", symbol: "figure.arms.open", accent: .orange),
        .init(name: "Fondos", group: "Pecho", equipment: "Peso corporal", symbol: "figure.gymnastics", accent: .orange),
        // Espalda
        .init(name: "Remo con barra", group: "Espalda", equipment: "Barra", symbol: "figure.rower", accent: .cyan),
        .init(name: "Jalon al pecho", group: "Espalda", equipment: "Maquina", symbol: "figure.play", accent: .cyan),
        .init(name: "Dominadas", group: "Espalda", equipment: "Peso corporal", symbol: "figure.climbing", accent: .cyan),
        .init(name: "Remo con mancuerna", group: "Espalda", equipment: "Mancuernas", symbol: "figure.rower", accent: .cyan),
        // Piernas
        .init(name: "Sentadilla", group: "Piernas", equipment: "Barra", symbol: "figure.cross.training", accent: .green),
        .init(name: "Peso muerto", group: "Piernas", equipment: "Barra", symbol: "figure.strengthtraining.traditional", accent: .green),
        .init(name: "Prensa", group: "Piernas", equipment: "Maquina", symbol: "figure.seated.seatbelt", accent: .green),
        .init(name: "Zancadas", group: "Piernas", equipment: "Mancuernas", symbol: "figure.strengthtraining.functional", accent: .green),
        .init(name: "Elevacion de talones", group: "Piernas", equipment: "Maquina", symbol: "figure.stairs", accent: .green),
        // Hombros
        .init(name: "Press militar", group: "Hombros", equipment: "Barra", symbol: "figure.mixed.cardio", accent: .purple),
        .init(name: "Elevaciones laterales", group: "Hombros", equipment: "Mancuernas", symbol: "figure.arms.open", accent: .purple),
        .init(name: "Face pull", group: "Hombros", equipment: "Cable", symbol: "figure.archery", accent: .purple),
        // Brazos
        .init(name: "Curl de biceps", group: "Brazos", equipment: "Mancuernas", symbol: "figure.strengthtraining.traditional", accent: .pink),
        .init(name: "Extension de triceps", group: "Brazos", equipment: "Cable", symbol: "figure.martial.arts", accent: .pink),
        .init(name: "Curl martillo", group: "Brazos", equipment: "Mancuernas", symbol: "figure.strengthtraining.traditional", accent: .pink),
        // Core
        .init(name: "Plancha", group: "Core", equipment: "Peso corporal", symbol: "figure.wrestling", accent: .yellow),
        .init(name: "Crunch", group: "Core", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Rueda abdominal", group: "Core", equipment: "Otro", symbol: "figure.roll", accent: .yellow),
        .init(name: "Elevacion de piernas", group: "Core", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        // Piernas (peso corporal, usados por el Desafío diario)
        .init(name: "Step-ups", group: "Piernas", equipment: "Peso corporal", symbol: "figure.stairs", accent: .green),
        .init(name: "Desplantes", group: "Piernas", equipment: "Peso corporal", symbol: "figure.strengthtraining.functional", accent: .green),
        // Tren superior con peso corporal / banda (Desafío diario)
        .init(name: "Flexiones", group: "Pecho", equipment: "Peso corporal", symbol: "figure.wrestling", accent: .orange),
        .init(name: "Band pull-aparts", group: "Espalda", equipment: "Banda", symbol: "figure.arms.open", accent: .cyan),
        // Cardio (un ejercicio + minutos; los deportes de CardioSport)
        .init(name: "Correr", group: "Cardio", equipment: "Cardio", symbol: "figure.run", accent: .red),
        .init(name: "Caminata", group: "Cardio", equipment: "Cardio", symbol: "figure.walk", accent: .red),
        .init(name: "Ciclismo", group: "Cardio", equipment: "Cardio", symbol: "figure.outdoor.cycle", accent: .red),
        .init(name: "Natacion", group: "Cardio", equipment: "Cardio", symbol: "figure.pool.swim", accent: .red),
        .init(name: "Futbol", group: "Cardio", equipment: "Cardio", symbol: "figure.soccer", accent: .red),
        .init(name: "Basquetbol", group: "Cardio", equipment: "Cardio", symbol: "figure.basketball", accent: .red),
        .init(name: "Tenis", group: "Cardio", equipment: "Cardio", symbol: "figure.tennis", accent: .red),
        .init(name: "Remo", group: "Cardio", equipment: "Cardio", symbol: "figure.rower", accent: .red),
        .init(name: "HIIT", group: "Cardio", equipment: "Cardio", symbol: "figure.highintensity.intervaltraining", accent: .red),
        .init(name: "Saltar la cuerda", group: "Cardio", equipment: "Cardio", symbol: "figure.jumprope", accent: .red),
        .init(name: "Otro", group: "Cardio", equipment: "Cardio", symbol: "figure.mixed.cardio", accent: .red),
        // Movilidad y recuperación (usados por rutinas de movilidad y Desafío)
        .init(name: "Gato-vaca", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.yoga", accent: .mint),
        .init(name: "Rotacion toracica", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Estiramiento suave de cadera", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Movilidad de cadera 90/90", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Estiramiento de isquios", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Rotacion de tobillo", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Aperturas de pecho en puerta", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.arms.open", accent: .mint),
        .init(name: "Circulos de hombro", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.cooldown", accent: .mint),
        .init(name: "Movilidad de hombro con banda", group: "Movilidad", equipment: "Banda", symbol: "figure.cooldown", accent: .mint),
        .init(name: "Estiramiento cruzado de hombro", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.cooldown", accent: .mint),
        .init(name: "Rotaciones externas suaves", group: "Movilidad", equipment: "Banda", symbol: "figure.cooldown", accent: .mint),
        .init(name: "Respiracion diafragmatica", group: "Movilidad", equipment: "Peso corporal", symbol: "lungs.fill", accent: .mint),
        // Yoga y estiramientos (amplian la biblioteca de movilidad)
        .init(name: "Postura del nino", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.mind.and.body", accent: .mint),
        .init(name: "Perro boca abajo", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.yoga", accent: .mint),
        .init(name: "Cobra", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.yoga", accent: .mint),
        .init(name: "Paloma", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.yoga", accent: .mint),
        .init(name: "Guerrero II", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.martial.arts", accent: .mint),
        .init(name: "Puente de gluteos", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.core.training", accent: .mint),
        .init(name: "Torsion espinal acostado", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Estiramiento de cuadriceps", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Sentadilla profunda sostenida", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.cross.training", accent: .mint),
        .init(name: "Estiramiento de gemelos", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Flexion lateral de pie", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.flexibility", accent: .mint),
        .init(name: "Postura del triangulo", group: "Movilidad", equipment: "Peso corporal", symbol: "figure.yoga", accent: .mint),
        // Challenge: fortalecimiento ligero diario (McGill Big 3, banda, pasos).
        // Fuerza de mantenimiento, NO estiramiento.
        .init(name: "Bird-dog", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Curl-up McGill", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Plancha lateral", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Dead bug", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Abdominales de pie", group: "Challenge", equipment: "Peso corporal", symbol: "figure.highintensity.intervaltraining", accent: .yellow),
        .init(name: "Marcha con rodilla alta", group: "Challenge", equipment: "Peso corporal", symbol: "figure.walk.motion", accent: .yellow),
        .init(name: "Pasos", group: "Challenge", equipment: "Peso corporal", symbol: "figure.walk", accent: .yellow),
        .init(name: "Sentadilla en pared", group: "Challenge", equipment: "Peso corporal", symbol: "figure.cross.training", accent: .yellow),
        .init(name: "Remo con banda", group: "Challenge", equipment: "Banda", symbol: "figure.rower", accent: .yellow),
        .init(name: "Paseo del monstruo", group: "Challenge", equipment: "Banda", symbol: "figure.walk.motion", accent: .yellow),
        .init(name: "Almeja con banda", group: "Challenge", equipment: "Banda", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Empuje de cadera con banda", group: "Challenge", equipment: "Banda", symbol: "figure.core.training", accent: .yellow),
        // Pilates (mat): fuerza y control del centro, sin equipo.
        .init(name: "El cien", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Roll-up", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Teaser", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Nado boca abajo", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Patada lateral", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Circulos de pierna", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        .init(name: "Puente de hombros", group: "Challenge", equipment: "Peso corporal", symbol: "figure.pilates", accent: .yellow),
        // Calistenia: fuerza con peso corporal.
        .init(name: "Hollow hold", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Superman", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow),
        .init(name: "Escaladores", group: "Challenge", equipment: "Peso corporal", symbol: "figure.highintensity.intervaltraining", accent: .yellow),
        .init(name: "Burpees", group: "Challenge", equipment: "Peso corporal", symbol: "figure.highintensity.intervaltraining", accent: .yellow),
        .init(name: "Sentadilla con salto", group: "Challenge", equipment: "Peso corporal", symbol: "figure.jumprope", accent: .yellow),
        .init(name: "Flexion pike", group: "Challenge", equipment: "Peso corporal", symbol: "figure.wrestling", accent: .yellow),
        .init(name: "Remo invertido", group: "Challenge", equipment: "Peso corporal", symbol: "figure.rower", accent: .yellow),
        .init(name: "Fondos en banca", group: "Challenge", equipment: "Peso corporal", symbol: "figure.gymnastics", accent: .yellow),
        // Yoga de FUERZA (posturas sostenidas, no estiramiento pasivo).
        .init(name: "Plancha alta", group: "Challenge", equipment: "Peso corporal", symbol: "figure.wrestling", accent: .yellow),
        .init(name: "Postura de la silla", group: "Challenge", equipment: "Peso corporal", symbol: "figure.yoga", accent: .yellow),
        .init(name: "Postura del barco", group: "Challenge", equipment: "Peso corporal", symbol: "figure.yoga", accent: .yellow),
        .init(name: "Guerrero III", group: "Challenge", equipment: "Peso corporal", symbol: "figure.yoga", accent: .yellow),
        .init(name: "Plancha lateral con elevacion", group: "Challenge", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow)
    ]

    static func equipmentSymbol(for equipment: String) -> String {
        switch equipment {
        case "Barra": "figure.strengthtraining.traditional"
        case "Mancuernas": "dumbbell.fill"
        case "Maquina": "gearshape.fill"
        case "Cable": "link"
        case "Peso corporal": "figure.stand"
        case "Banda": "circle.grid.cross"
        case "Cardio": "heart.circle"
        default: "circle.dashed"
        }
    }

    static func item(named name: String) -> ExerciseCatalogItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static func thumbnail(for name: String) -> ExerciseCatalogItem {
        item(named: name) ?? .init(
            name: name,
            group: "Custom",
            equipment: "Otro",
            symbol: "figure.strengthtraining.traditional",
            accent: .secondary
        )
    }
}

/// Miniatura estilo Bevel: cuadro oscuro + silueta blanca del movimiento
/// + mini badge del equipo con el acento (rojo/naranja como en Bevel).
struct ExerciseThumbnail: View {
    let item: ExerciseCatalogItem
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.18, blue: 0.20),
                            Color(red: 0.07, green: 0.08, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            // Silueta del patron de movimiento (equivale a la ilustracion Bevel).
            Image(systemName: item.symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(.white.opacity(0.96))
                .minimumScaleFactor(0.6)
                .frame(width: size * 0.72, height: size * 0.72)
            // Badge de equipo (Bevel marca barra/mancuerna/maquina en color).
            Image(systemName: ExerciseLibrary.equipmentSymbol(for: item.equipment))
                .font(.system(size: size * 0.19, weight: .bold))
                .foregroundStyle(item.accent)
                .padding(size * 0.05)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: size * 0.1, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(size * 0.06)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.6)
        }
        .accessibilityHidden(true)
    }
}

struct ExerciseLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAddMany: ([String]) -> Void

    @State private var search = ""
    @State private var selected: Set<String> = []
    @State private var customName = ""
    @State private var showCustomField = false
    @State private var groupFilter: String = "Todos"
    @State private var equipmentFilter: String = "Todos"
    /// Ejercicio cuya mecanica se esta consultando desde la "i" de la fila.
    @State private var mechanicsExercise: ExerciseMechanicsRequest?

    private var groups: [String] {
        ["Todos"] + Array(Set(ExerciseLibrary.items.map(\.group))).sorted()
    }

    private var equipments: [String] {
        ["Todos"] + Array(Set(ExerciseLibrary.items.map(\.equipment))).sorted()
    }

    private var filtered: [ExerciseCatalogItem] {
        ExerciseLibrary.items.filter { item in
            let groupOK = groupFilter == "Todos" || item.group == groupFilter
            let equipmentOK = equipmentFilter == "Todos" || item.equipment == equipmentFilter
            let searchOK = search.trimmingCharacters(in: .whitespaces).isEmpty
                || item.name.localizedCaseInsensitiveContains(search)
                || item.equipment.localizedCaseInsensitiveContains(search)
            return groupOK && equipmentOK && searchOK
        }
    }

    /// Bevel agrupa por letra inicial (A, B, C...), no por musculo.
    private var alphabetical: [(String, [ExerciseCatalogItem])] {
        Dictionary(grouping: filtered) { String($0.name.prefix(1)).uppercased() }
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.075, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 0) {
                    filterChips
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            customSection
                            ForEach(alphabetical, id: \.0) { letter, items in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(letter)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 10)
                                        .padding(.bottom, 2)
                                    ForEach(items) { item in
                                        libraryRow(item)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Biblioteca")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        let names = Array(selected)
                        guard !names.isEmpty else { return }
                        Haptics.success()
                        onAddMany(names)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("fitness.library.addSelected")
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("fitness.library")
        .sheet(item: $mechanicsExercise) { request in
            ExerciseMechanicsSheet(exerciseName: request.exerciseName)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }

    /// Dos chips-menu como Bevel: "All groups >" y "All equipment >".
    private var filterChips: some View {
        HStack(spacing: 8) {
            filterMenu(
                title: groupFilter == "Todos" ? "Todos los grupos" : groupFilter,
                options: groups,
                selection: $groupFilter
            )
            filterMenu(
                title: equipmentFilter == "Todos" ? "Todo el equipo" : equipmentFilter,
                options: equipments,
                selection: $equipmentFilter
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func filterMenu(title: String, options: [String], selection: Binding<String>) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    Haptics.selection()
                    selection.wrappedValue = option
                } label: {
                    if selection.wrappedValue == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .hapticMenuLabel()
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if showCustomField {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    TextField("Nombre del ejercicio", text: $customName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .snappyTextInput()
                        .onSubmit(addCustom)
                    Button(action: addCustom) {
                        selectionBox(isOn: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fitness.library.addCustom")
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    Haptics.add()
                    showCustomField = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Agregar ejercicio personalizado")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.library.customRow")
            }
        }
    }

    private func addCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Haptics.add()
        selected.insert(trimmed)
        customName = ""
        showCustomField = false
    }

    private func libraryRow(_ item: ExerciseCatalogItem) -> some View {
        let isOn = selected.contains(item.name)
        let slug = item.name.replacingOccurrences(of: " ", with: "_")
        return HStack(spacing: 12) {
            Button {
                Haptics.selection()
                if isOn { selected.remove(item.name) } else { selected.insert(item.name) }
            } label: {
                HStack(spacing: 12) {
                    ExerciseThumbnail(item: item, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text(item.equipment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fitness.library.item.\(slug)")
            .accessibilityLabel("\(item.name), \(item.equipment)")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])

            // La "i" ahora si abre la mecanica del ejercicio (antes era decorativa).
            Button {
                Haptics.light()
                mechanicsExercise = ExerciseMechanicsRequest(exerciseName: item.name)
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ver mecanica de \(item.name)")
            .accessibilityIdentifier("fitness.library.mechanics.\(slug)")

            Button {
                Haptics.selection()
                if isOn { selected.remove(item.name) } else { selected.insert(item.name) }
            } label: {
                selectionBox(isOn: isOn)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }

    private func selectionBox(isOn: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? Color.white : Color.white.opacity(0.08))
                .frame(width: 28, height: 28)
            Image(systemName: isOn ? "checkmark" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOn ? .black : .white)
        }
    }
}

private struct FitnessSectionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showCardio: Bool
    @Binding var showStrength: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Secciones") {
                    Toggle(isOn: $showCardio) { Label("Cardio", systemImage: "heart.fill") }
                    Toggle(isOn: $showStrength) { Label("Fuerza", systemImage: "figure.strengthtraining.traditional") }
                }
                Section {
                    Text("El resumen de actividad y la respuesta a la Carga permanecen visibles porque dan contexto a tu entrenamiento.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Editar Entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { hapticFeedback(.soft); dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Ejercicios estructurados de plantilla (estilo Bevel/Hevy)
// Se serializan dentro de `WorkoutTemplate.exercisesText` como
// "Nombre | 3x12 | 20" (series x reps | kg opcional) para no cambiar el
// esquema SwiftData. Las lineas legadas (solo nombre) se leen con defaults.

struct TemplateExercise: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var kg: Double?
    /// Prescripcion por tiempo para cardio, movilidad y recuperacion.
    var durationSeconds: Int? = nil

    var prescriptionLabel: String {
        if let durationSeconds {
            return durationSeconds >= 60 && durationSeconds.isMultiple(of: 60)
                ? "\(durationSeconds / 60) min"
                : "\(durationSeconds) s"
        }
        return sets == 1 ? "\(reps) rep" : "\(sets) x \(reps)"
    }
}

enum TemplateCodec {
    static func parse(_ text: String) -> [TemplateExercise] {
        text.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            var exercise = TemplateExercise(name: parts[0], sets: 3, reps: 10, kg: nil)
            if parts.count > 1 {
                let prescription = parts[1].lowercased()
                let setsReps = prescription.split(separator: "x")
                if setsReps.count == 2,
                   let sets = Int(setsReps[0].trimmingCharacters(in: .whitespaces)),
                   let reps = Int(setsReps[1].trimmingCharacters(in: .whitespaces)) {
                    exercise.sets = max(sets, 1)
                    exercise.reps = max(reps, 1)
                } else if prescription.hasSuffix("min"),
                          let minutes = Int(prescription.replacingOccurrences(of: "min", with: "").trimmingCharacters(in: .whitespaces)) {
                    exercise.sets = 1
                    exercise.reps = 1
                    exercise.durationSeconds = max(minutes, 1) * 60
                } else if prescription.hasSuffix("s"),
                          let seconds = Int(prescription.dropLast().trimmingCharacters(in: .whitespaces)) {
                    exercise.sets = 1
                    exercise.reps = 1
                    exercise.durationSeconds = max(seconds, 1)
                } else if let reps = Int(prescription.trimmingCharacters(in: .whitespaces)) {
                    exercise.sets = 1
                    exercise.reps = max(reps, 1)
                }
            }
            if parts.count > 2 {
                exercise.kg = Double(parts[2].replacingOccurrences(of: "kg", with: "").trimmingCharacters(in: .whitespaces))
            }
            return exercise
        }
    }

    static func serialize(_ exercises: [TemplateExercise]) -> String {
        exercises.map { exercise in
            let prescription: String
            if let seconds = exercise.durationSeconds {
                prescription = seconds.isMultiple(of: 60) ? "\(seconds / 60) min" : "\(seconds)s"
            } else {
                prescription = "\(exercise.sets)x\(exercise.reps)"
            }
            var line = "\(exercise.name) | \(prescription)"
            if let kg = exercise.kg, kg > 0 { line += " | \(kg.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(kg)) : String(kg))" }
            return line
        }.joined(separator: "\n")
    }
}

// MARK: - Rutina semanal (agenda de entrenamiento)
// Guardada como JSON en UserDefaults: no toca el esquema SwiftData y evita
// colisiones de migracion. Patron de agenda validado contra Bevel (video
// bevelworkout.mp4) y Hevy (rutinas reutilizables + calendario semanal).

enum AthleteExperience: String, Codable, CaseIterable, Identifiable {
    case starting, intermediate, advanced, competitive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .starting: "Inicial"
        case .intermediate: "Intermedia"
        case .advanced: "Avanzada"
        case .competitive: "Competitiva"
        }
    }
    var detail: String {
        switch self {
        case .starting: "Estoy construyendo constancia y técnica."
        case .intermediate: "Entreno de forma regular y registro mi progreso."
        case .advanced: "Planifico volumen, intensidad y recuperación."
        case .competitive: "Organizo bloques alrededor de competencias."
        }
    }
}

enum TrainingObjective: String, Codable, CaseIterable, Identifiable {
    case general, hypertrophy, maximalStrength, endurance, sportPerformance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "Condición general"
        case .hypertrophy: "Hipertrofia"
        case .maximalStrength: "Fuerza máxima"
        case .endurance: "Resistencia"
        case .sportPerformance: "Rendimiento deportivo"
        }
    }
    var symbol: String {
        switch self {
        case .general: "figure.mixed.cardio"
        case .hypertrophy: "dumbbell.fill"
        case .maximalStrength: "scalemass.fill"
        case .endurance: "figure.run"
        case .sportPerformance: "medal.fill"
        }
    }
}

enum TrainingProgramPhase: String, Codable, CaseIterable, Identifiable {
    case base, build, peak, deload, maintenance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .base: "Base"
        case .build: "Desarrollo"
        case .peak: "Pico"
        case .deload: "Descarga"
        case .maintenance: "Mantenimiento"
        }
    }
    var detail: String {
        switch self {
        case .base: "Consolidar técnica y capacidad de trabajo."
        case .build: "Aumentar gradualmente el estímulo."
        case .peak: "Priorizar sesiones específicas de alta calidad."
        case .deload: "Reducir carga para facilitar la recuperación."
        case .maintenance: "Conservar capacidad con una carga sostenible."
        }
    }
}

enum ScheduleFlexibility: String, Codable, CaseIterable, Identifiable {
    case fixed, preferred, flexible
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fixed: "Fijo"
        case .preferred: "Preferido"
        case .flexible: "Flexible"
        }
    }
}

enum CardioIntent: String, Codable, CaseIterable, Identifiable {
    case recovery, easy, tempo, intervals, skills, match, long
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recovery: "Recuperación activa"
        case .easy: "Base suave"
        case .tempo: "Tempo"
        case .intervals: "Intervalos"
        case .skills: "Técnica"
        case .match: "Partido o competencia"
        case .long: "Sesión larga"
        }
    }
}

struct ScheduledSessionDetails: Codable, Equatable {
    var startMinute: Int? = 18 * 60
    var flexibility: ScheduleFlexibility = .preferred
    var durationMinutes: Int = 45
    var targetRPE: Int = 6
    var cardioIntent: CardioIntent? = nil
    var focusOverride: String? = nil
    /// Contactos de salto planeados (pliometría). Métrica estándar de volumen.
    var jumpContacts: Int? = nil
    /// Número de "giant sets" del método de contraste (2-4 según la literatura).
    var contrastSets: Int? = nil
    /// Repeticiones de sprint en sesiones de aceleración/velocidad.
    var speedReps: Int? = nil
    /// Distancia por repetición (m) en sesiones de aceleración/velocidad.
    var speedDistanceMeters: Int? = nil
    /// Zona de frecuencia cardiaca objetivo (1-5) para cardio.
    var targetZone: Int? = nil
    /// %1RM objetivo del levantamiento principal (sesiones de fuerza avanzadas).
    var mainLiftPercent1RM: Int? = nil
    /// Nota libre de la sesión (p. ej. ejercicios de fisioterapia indicados).
    var sessionNote: String? = nil
    /// Rutina concreta de movilidad/cardio ligero del plan (TemplateCodec).
    var exercisesText: String? = nil
    /// Plantilla elegida en el editor del plan, sin importar su modalidad.
    var templateID: UUID? = nil

    init(
        startMinute: Int? = 18 * 60,
        flexibility: ScheduleFlexibility = .preferred,
        durationMinutes: Int = 45,
        targetRPE: Int = 6,
        cardioIntent: CardioIntent? = nil,
        focusOverride: String? = nil,
        jumpContacts: Int? = nil,
        contrastSets: Int? = nil,
        speedReps: Int? = nil,
        speedDistanceMeters: Int? = nil,
        targetZone: Int? = nil,
        mainLiftPercent1RM: Int? = nil,
        sessionNote: String? = nil,
        exercisesText: String? = nil,
        templateID: UUID? = nil
    ) {
        self.startMinute = startMinute
        self.flexibility = flexibility
        self.durationMinutes = durationMinutes
        self.targetRPE = targetRPE
        self.cardioIntent = cardioIntent
        self.focusOverride = focusOverride
        self.jumpContacts = jumpContacts
        self.contrastSets = contrastSets
        self.speedReps = speedReps
        self.speedDistanceMeters = speedDistanceMeters
        self.targetZone = targetZone
        self.mainLiftPercent1RM = mainLiftPercent1RM
        self.sessionNote = sessionNote
        self.exercisesText = exercisesText
        self.templateID = templateID
    }

    /// Decodificación retro-compatible: los campos pro (contactos, contraste,
    /// velocidad, zona, %1RM, nota) no existen en JSON de versiones previas.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute)
        flexibility = try c.decodeIfPresent(ScheduleFlexibility.self, forKey: .flexibility) ?? .preferred
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 45
        targetRPE = try c.decodeIfPresent(Int.self, forKey: .targetRPE) ?? 6
        cardioIntent = try c.decodeIfPresent(CardioIntent.self, forKey: .cardioIntent)
        focusOverride = try c.decodeIfPresent(String.self, forKey: .focusOverride)
        jumpContacts = try c.decodeIfPresent(Int.self, forKey: .jumpContacts)
        contrastSets = try c.decodeIfPresent(Int.self, forKey: .contrastSets)
        speedReps = try c.decodeIfPresent(Int.self, forKey: .speedReps)
        speedDistanceMeters = try c.decodeIfPresent(Int.self, forKey: .speedDistanceMeters)
        targetZone = try c.decodeIfPresent(Int.self, forKey: .targetZone)
        mainLiftPercent1RM = try c.decodeIfPresent(Int.self, forKey: .mainLiftPercent1RM)
        sessionNote = try c.decodeIfPresent(String.self, forKey: .sessionNote)
        exercisesText = try c.decodeIfPresent(String.self, forKey: .exercisesText)
        templateID = try c.decodeIfPresent(UUID.self, forKey: .templateID)
    }

    var plannedLoad: Int { durationMinutes * targetRPE }

    func startDate(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard let startMinute else { return nil }
        return calendar.date(
            bySettingHour: startMinute / 60,
            minute: startMinute % 60,
            second: 0,
            of: date
        )
    }
}

/// Levantamientos básicos con 1RM registrable en el modo avanzado. Las marcas
/// alimentan la guía de kg por %1RM; nunca se inventan si el usuario no las da.
enum MainLift: String, Codable, CaseIterable, Identifiable {
    case squat, bench, deadlift, overheadPress
    var id: String { rawValue }
    var title: String {
        switch self {
        case .squat: "Sentadilla"
        case .bench: "Press de banca"
        case .deadlift: "Peso muerto"
        case .overheadPress: "Press militar"
        }
    }
}

enum WeeklyGoal: String, CaseIterable, Codable, Identifiable {
    case strength, cardio, mixed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Fuerza"
        case .cardio: "Cardio"
        case .mixed: "Mixto"
        }
    }

    var subtitle: String {
        switch self {
        case .strength: "Priorizar musculo y volumen"
        case .cardio: "Priorizar capacidad aerobica"
        case .mixed: "Equilibrar fuerza y cardio"
        }
    }

    var icon: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "figure.run"
        case .mixed: "figure.cross.training"
        }
    }
}

/// Tipo de rutina de fuerza. Todos son validos segun la evidencia; lo que mas
/// importa es el volumen semanal por grupo (2-3x/semana) mas que el split
/// concreto (Schoenfeld, meta-analisis 2016/2019). El split solo decide como
/// se reparte ese volumen entre los dias.
enum SplitType: String, Codable, CaseIterable, Identifiable {
    case fullBody, upperLower, pushPullLegs, broSplit, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBody: "Full body"
        case .upperLower: "Torso / pierna"
        case .pushPullLegs: "Empuje / jalon / pierna"
        case .broSplit: "Un grupo por dia"
        case .custom: "Personalizado"
        }
    }

    var subtitle: String {
        switch self {
        case .fullBody: "Todo el cuerpo cada sesion. Ideal 2-3 dias/semana."
        case .upperLower: "Alterna tren superior e inferior. Bueno para 4 dias."
        case .pushPullLegs: "Empuje, jalon y pierna. Bueno para 3 o 6 dias."
        case .broSplit: "Un grupo muscular por dia. Necesita mas dias para frecuencia 2x."
        case .custom: "Tu decides cada dia."
        }
    }

    var icon: String {
        switch self {
        case .fullBody: "figure.mixed.cardio"
        case .upperLower: "figure.strengthtraining.traditional"
        case .pushPullLegs: "arrow.up.arrow.down"
        case .broSplit: "square.grid.3x3"
        case .custom: "slider.horizontal.3"
        }
    }

    /// Etiquetas de foco que rotan por dia de entrenamiento. `custom` no impone
    /// una rotacion (queda a criterio del usuario).
    var focusRotation: [String] {
        switch self {
        case .fullBody: ["Full body"]
        case .upperLower: ["Tren superior", "Tren inferior"]
        case .pushPullLegs: ["Empuje", "Jalon", "Pierna"]
        case .broSplit: ["Pecho", "Espalda", "Piernas", "Hombros", "Brazos"]
        case .custom: []
        }
    }
}

/// Deporte de una sesion de cardio. Permite especificar "futbol" en vez de un
/// generico "cardio". Se transporta dentro del `String` de `DayAssignment.cardio`
/// (via rawValue) para no romper el enum Codable existente.
enum CardioSport: String, Codable, CaseIterable, Identifiable {
    case running, cycling, swimming, football, basketball, tennis, rowing, hiit, walking, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .running: "Correr"
        case .cycling: "Ciclismo"
        case .swimming: "Natacion"
        case .football: "Futbol"
        case .basketball: "Basquetbol"
        case .tennis: "Tenis"
        case .rowing: "Remo"
        case .hiit: "HIIT"
        case .walking: "Caminata"
        case .other: "Otro"
        }
    }

    var icon: String {
        switch self {
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .football: "figure.soccer"
        case .basketball: "figure.basketball"
        case .tennis: "figure.tennis"
        case .rowing: "figure.rower"
        case .hiit: "figure.highintensity.intervaltraining"
        case .walking: "figure.walk"
        case .other: "figure.mixed.cardio"
        }
    }
}

enum DayAssignment: Codable, Equatable {
    case rest
    case cardio(String)
    case template(UUID)
    /// Recuperación activa o ejercicios de fisioterapia indicados por un profesional.
    case recovery
    /// Flexibilidad y movilidad articular.
    case mobility
    /// Pliometría (saltos, contactos).
    case plyometrics
    /// Aceleración y velocidad (sprints cortos).
    case speed
    /// Método de contraste (p. ej. French contrast): pesado + plio + velocidad.
    case contrast
    /// Técnica deportiva o de gestos (skills).
    case technique

    var shortLabel: String {
        switch self {
        case .rest: "Descanso"
        case .cardio(let name): name
        case .template: "Fuerza"
        case .recovery: "Recuperación"
        case .mobility: "Movilidad"
        case .plyometrics: "Pliometría"
        case .speed: "Velocidad"
        case .contrast: "Contraste"
        case .technique: "Técnica"
        }
    }

    /// Nombre completo para mostrar en agenda, editor y revisión.
    var displayLabel: String {
        switch self {
        case .rest: "Descanso"
        case .cardio(let name): DayAssignment.sport(fromCardioName: name)?.label ?? name
        case .template: "Fuerza"
        case .recovery: "Recuperación / fisioterapia"
        case .mobility: "Flexibilidad y movilidad"
        case .plyometrics: "Pliometría"
        case .speed: "Aceleración y velocidad"
        case .contrast: "Método de contraste"
        case .technique: "Técnica deportiva"
        }
    }

    var icon: String {
        switch self {
        case .rest: "moon.zzz"
        case .cardio(let name): DayAssignment.sport(fromCardioName: name)?.icon ?? "figure.run"
        case .template: "dumbbell"
        case .recovery: "cross.case"
        case .mobility: "figure.mind.and.body"
        case .plyometrics: "figure.jumprope"
        case .speed: "hare.fill"
        case .contrast: "bolt.horizontal.fill"
        case .technique: "figure.archery"
        }
    }

    /// Demanda neuronal alta: pide sistema nervioso fresco y se coloca al
    /// inicio de la sesión. Lo usa el coaching para sugerir moverla cuando la
    /// recuperación es baja.
    var isHighNeuralDemand: Bool {
        switch self {
        case .plyometrics, .speed, .contrast: true
        default: false
        }
    }

    /// Sesión orientada a recuperar (incluye descanso completo).
    var isRecoveryOriented: Bool {
        switch self {
        case .rest, .recovery, .mobility: true
        default: false
        }
    }

    /// Tipos disponibles en el modo avanzado (además de fuerza, cardio y descanso).
    static var performanceCases: [DayAssignment] {
        [.plyometrics, .speed, .contrast, .technique]
    }

    /// Color de acento del tipo de sesión en agenda y editores.
    var tintColor: Color {
        switch self {
        case .rest: .secondary
        case .template: .cyan
        case .cardio: ScoreKind.strain.color
        case .recovery: ScoreKind.recovery.color
        case .mobility: .mint
        case .plyometrics: ScoreKind.energy.color
        case .speed: .orange
        case .contrast: .red
        case .technique: ScoreKind.sleep.color
        }
    }

    /// RPE objetivo sugerido al crear la sesión (editable).
    var defaultTargetRPE: Int {
        switch self {
        case .rest: 0
        case .template: 6
        case .cardio: 6
        case .recovery: 2
        case .mobility: 3
        case .technique: 4
        case .plyometrics: 8
        case .speed: 8
        case .contrast: 9
        }
    }

    /// Duración sugerida al crear la sesión (editable).
    var defaultDurationMinutes: Int {
        switch self {
        case .rest: 0
        case .template: 60
        case .cardio: 45
        case .recovery: 20
        case .mobility: 25
        case .technique: 45
        case .plyometrics: 40
        case .speed: 40
        case .contrast: 50
        }
    }

    /// Deporte transportado dentro del `String` de `.cardio` (si el string es un
    /// rawValue de `CardioSport`). Los strings legados ("Carrera", "Fuerza
    /// libre") devuelven `nil` y se muestran tal cual.
    static func sport(fromCardioName name: String) -> CardioSport? {
        CardioSport(rawValue: name)
    }

    /// Construye una asignacion de cardio a partir de un deporte.
    static func cardio(sport: CardioSport) -> DayAssignment {
        .cardio(sport.rawValue)
    }
}

struct WeeklyRoutine: Codable, Equatable {
    var goal: WeeklyGoal = .mixed
    var minutesPerSession: Int = 45
    var onboarded = false
    /// Clave: weekday de Calendar (1=domingo ... 7=sabado)
    var days: [Int: DayAssignment] = [:]
    /// Tipo de split de fuerza (nuevo). Default para JSON viejo: full body.
    var splitType: SplitType = .fullBody
    /// Deporte principal de cardio (nuevo, opcional).
    var cardioSport: CardioSport?
    /// Override de minutos por dia (weekday -> minutos). Fallback:
    /// `minutesPerSession`. Vacio en rutinas viejas.
    var minutesPerDay: [Int: Int] = [:]
    var experience: AthleteExperience = .intermediate
    var objective: TrainingObjective = .general
    var phase: TrainingProgramPhase = .base
    var sessionDetails: [Int: ScheduledSessionDetails] = [:]
    var eventDate: Date?
    /// Nombre visible del plan semanal (biblioteca de planes). Vacío/nil en
    /// rutinas de versiones anteriores: la UI muestra "Plan semanal".
    var planName: String?
    /// true si el plan se configuró con opciones de alto rendimiento.
    var advancedConfig = false
    /// Marcas de 1RM por levantamiento (rawValue de `MainLift` -> kg).
    var personalRecords: [String: Double] = [:]
    /// Duración prevista del bloque en semanas (2-12). Informativa.
    var planWeeks: Int?
    /// Opt-in: generar y mostrar Daily Challenge en la semana.
    var dailyChallengesEnabled = false
    /// Challenge por weekday (1=domingo ... 7=sabado).
    var dailyChallenges: [Int: DailyChallengeDay] = [:]
    /// Plantilla ejecutable por dia. Incluye cardio, movilidad y rendimiento;
    /// en fuerza normalmente coincide con el UUID de `DayAssignment.template`.
    var sessionTemplateIDs: [Int: UUID] = [:]
    /// Plantilla del desafio diario por weekday. Sustituye al editor paralelo legado.
    var dailyChallengeTemplateIDs: [Int: UUID] = [:]

    init(
        goal: WeeklyGoal = .mixed,
        minutesPerSession: Int = 45,
        onboarded: Bool = false,
        days: [Int: DayAssignment] = [:],
        splitType: SplitType = .fullBody,
        cardioSport: CardioSport? = nil,
        minutesPerDay: [Int: Int] = [:],
        experience: AthleteExperience = .intermediate,
        objective: TrainingObjective = .general,
        phase: TrainingProgramPhase = .base,
        sessionDetails: [Int: ScheduledSessionDetails] = [:],
        eventDate: Date? = nil,
        planName: String? = nil,
        advancedConfig: Bool = false,
        personalRecords: [String: Double] = [:],
        planWeeks: Int? = nil,
        dailyChallengesEnabled: Bool = false,
        dailyChallenges: [Int: DailyChallengeDay] = [:],
        sessionTemplateIDs: [Int: UUID] = [:],
        dailyChallengeTemplateIDs: [Int: UUID] = [:]
    ) {
        self.goal = goal
        self.minutesPerSession = minutesPerSession
        self.onboarded = onboarded
        self.days = days
        self.splitType = splitType
        self.cardioSport = cardioSport
        self.minutesPerDay = minutesPerDay
        self.experience = experience
        self.objective = objective
        self.phase = phase
        self.sessionDetails = sessionDetails
        self.eventDate = eventDate
        self.planName = planName
        self.advancedConfig = advancedConfig
        self.personalRecords = personalRecords
        self.planWeeks = planWeeks
        self.dailyChallengesEnabled = dailyChallengesEnabled
        self.dailyChallenges = dailyChallenges
        self.sessionTemplateIDs = sessionTemplateIDs
        self.dailyChallengeTemplateIDs = dailyChallengeTemplateIDs
    }

    /// Decodificacion retro-compatible: los campos nuevos usan `decodeIfPresent`
    /// con default, asi el JSON guardado por la version MVP (sin split/sport/
    /// minutesPerDay) sigue decodificando sin fallar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(WeeklyGoal.self, forKey: .goal) ?? .mixed
        minutesPerSession = try c.decodeIfPresent(Int.self, forKey: .minutesPerSession) ?? 45
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        days = try c.decodeIfPresent([Int: DayAssignment].self, forKey: .days) ?? [:]
        splitType = try c.decodeIfPresent(SplitType.self, forKey: .splitType) ?? .fullBody
        cardioSport = try c.decodeIfPresent(CardioSport.self, forKey: .cardioSport)
        minutesPerDay = try c.decodeIfPresent([Int: Int].self, forKey: .minutesPerDay) ?? [:]
        experience = try c.decodeIfPresent(AthleteExperience.self, forKey: .experience) ?? .intermediate
        objective = try c.decodeIfPresent(TrainingObjective.self, forKey: .objective) ?? .general
        phase = try c.decodeIfPresent(TrainingProgramPhase.self, forKey: .phase) ?? .base
        sessionDetails = try c.decodeIfPresent([Int: ScheduledSessionDetails].self, forKey: .sessionDetails) ?? [:]
        eventDate = try c.decodeIfPresent(Date.self, forKey: .eventDate)
        planName = try c.decodeIfPresent(String.self, forKey: .planName)
        advancedConfig = try c.decodeIfPresent(Bool.self, forKey: .advancedConfig) ?? false
        personalRecords = try c.decodeIfPresent([String: Double].self, forKey: .personalRecords) ?? [:]
        planWeeks = try c.decodeIfPresent(Int.self, forKey: .planWeeks)
        dailyChallengesEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyChallengesEnabled) ?? false
        dailyChallenges = try c.decodeIfPresent([Int: DailyChallengeDay].self, forKey: .dailyChallenges) ?? [:]
        sessionTemplateIDs = try c.decodeIfPresent([Int: UUID].self, forKey: .sessionTemplateIDs) ?? [:]
        dailyChallengeTemplateIDs = try c.decodeIfPresent([Int: UUID].self, forKey: .dailyChallengeTemplateIDs) ?? [:]
    }

    /// Nombre para mostrar del plan (fallback cuando viene de versiones viejas).
    var displayName: String {
        let trimmed = (planName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Plan semanal" : trimmed
    }

    /// Minutos para un dia concreto: override si existe, si no el global.
    func minutes(forWeekday weekday: Int) -> Int {
        sessionDetails[weekday]?.durationMinutes ?? minutesPerDay[weekday] ?? minutesPerSession
    }

    func details(forWeekday weekday: Int) -> ScheduledSessionDetails {
        sessionDetails[weekday] ?? ScheduledSessionDetails(
            startMinute: nil,
            flexibility: .flexible,
            durationMinutes: minutes(forWeekday: weekday),
            targetRPE: 6
        )
    }

    func templateID(forWeekday weekday: Int) -> UUID? {
        if let id = sessionTemplateIDs[weekday] { return id }
        if case .template(let id) = days[weekday] { return id }
        return nil
    }

    var plannedMinutes: Int {
        days.reduce(0) { result, item in item.value == .rest ? result : result + minutes(forWeekday: item.key) }
    }

    var plannedLoad: Int {
        days.reduce(0) { result, item in
            item.value == .rest ? result : result + details(forWeekday: item.key).plannedLoad
        }
    }

    var highIntensitySessionCount: Int {
        days.filter { $0.value != .rest && details(forWeekday: $0.key).targetRPE >= 8 }.count
    }
}

enum WeeklyRoutineStore {
    static let key = "fitness.weeklyRoutine"

    static func load(defaults: UserDefaults = .standard) -> WeeklyRoutine {
        guard let data = defaults.data(forKey: key),
              let routine = try? JSONDecoder().decode(WeeklyRoutine.self, from: data) else {
            return WeeklyRoutine()
        }
        return routine
    }

    static func save(_ routine: WeeklyRoutine, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(routine) {
            defaults.set(data, forKey: key)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

struct WeeklyRoutinePlanner {
    /// Genera una semana sugerida deterministicamente segun objetivo y dias
    /// elegidos. Alterna fuerza/cardio en mixto; el resto queda descanso.
    /// `includeMobility` convierte el ultimo dia de cardio en movilidad (o
    /// coloca movilidad tras el ultimo dia de fuerza si no hay cardio).
    func suggestedWeek(
        goal: WeeklyGoal,
        trainingWeekdays: [Int],
        templateIDs: [UUID],
        splitType: SplitType = .fullBody,
        cardioSport: CardioSport? = nil,
        includeMobility: Bool = false
    ) -> [Int: DayAssignment] {
        var plan: [Int: DayAssignment] = [:]
        for weekday in 1...7 { plan[weekday] = .rest }

        // Deporte de cardio: usa el elegido; si no, alterna carrera/suave.
        func cardioDay(_ index: Int) -> DayAssignment {
            if let cardioSport { return .cardio(sport: cardioSport) }
            return .cardio(index.isMultiple(of: 2) ? "Carrera" : "Cardio suave")
        }

        let sorted = trainingWeekdays.sorted()
        for (index, weekday) in sorted.enumerated() {
            switch goal {
            case .strength:
                plan[weekday] = assignment(templateIDs: templateIDs, index: index) ?? .cardio("Fuerza libre")
            case .cardio:
                plan[weekday] = cardioDay(index)
            case .mixed:
                if index.isMultiple(of: 2) {
                    plan[weekday] = assignment(templateIDs: templateIDs, index: index / 2) ?? .cardio("Fuerza libre")
                } else {
                    plan[weekday] = cardioDay(index)
                }
            }
        }

        if includeMobility, let mobilityDay = mobilitySlot(in: plan, trainingWeekdays: sorted) {
            plan[mobilityDay] = .mobility
        }
        return plan
    }

    /// Dia candidato para la sesion de movilidad: el ultimo dia de cardio si
    /// existe; si no, el primer dia libre posterior al ultimo entrenamiento.
    private func mobilitySlot(in plan: [Int: DayAssignment], trainingWeekdays: [Int]) -> Int? {
        let ordered = trainingWeekdays.sorted()
        if let lastCardio = ordered.last(where: {
            if case .cardio = plan[$0] ?? .rest { return true }
            return false
        }) {
            return lastCardio
        }
        // Semana circular: busca el primer descanso despues del ultimo dia.
        guard let last = ordered.last else { return nil }
        for offset in 1...7 {
            let candidate = (last - 1 + offset) % 7 + 1
            if plan[candidate] == .rest { return candidate }
        }
        return nil
    }

    /// Split por defecto segun los dias de fuerza disponibles (volumen primero;
    /// el split solo reparte). 2-3 dias: full body; 4: torso/pierna; 5+: PPL.
    static func defaultSplit(forStrengthDays count: Int) -> SplitType {
        switch count {
        case ...3: .fullBody
        case 4: .upperLower
        default: .pushPullLegs
        }
    }

    /// Etiqueta de foco sugerida para el n-esimo dia de fuerza segun el split.
    /// Vacia para `custom`. La usa el onboarding para orientar al usuario.
    func focusLabel(splitType: SplitType, strengthDayIndex: Int) -> String? {
        let rotation = splitType.focusRotation
        guard !rotation.isEmpty else { return nil }
        return rotation[strengthDayIndex % rotation.count]
    }

    /// Chequea la regla de ~48h: cuenta cuantos dias de fuerza consecutivos
    /// (sin descanso intercalado) hay, para avisar en splits que golpean el
    /// mismo grupo. Se usa en el review del onboarding.
    func weeklyStrengthDays(in plan: [Int: DayAssignment]) -> Int {
        plan.values.filter {
            if case .template = $0 { return true }
            if case .cardio(let n) = $0, n == "Fuerza libre" { return true }
            return false
        }.count
    }

    private func assignment(templateIDs: [UUID], index: Int) -> DayAssignment? {
        guard !templateIDs.isEmpty else { return nil }
        return .template(templateIDs[index % templateIDs.count])
    }

    /// Consejo del día cruzando el plan con la Recuperación más reciente.
    /// Lenguaje matizado: es una sugerencia de bienestar, no prescripcion.
    func todayAdvice(recovery: Int?, assignment: DayAssignment?) -> String {
        guard let assignment else {
            return RecvelL10n.text("training.week.advice.configure")
        }
        guard let recovery else {
            switch assignment {
            case .rest: return RecvelL10n.text("training.week.advice.rest")
            default:
                return RecvelL10n.text(
                    "training.week.advice.scheduled",
                    values: ["workout": assignment.shortLabel]
                )
            }
        }
        switch assignment {
        case .rest:
            let key = recovery >= 75
                ? "training.week.advice.rest.ready"
                : "training.week.advice.rest.light"
            return RecvelL10n.text(key, values: ["recovery": "\(recovery)"])
        case .cardio(let name):
            let key = recovery >= 60
                ? "training.week.advice.cardio.ready"
                : "training.week.advice.cardio.adjust"
            return RecvelL10n.text(
                key,
                values: ["recovery": "\(recovery)", "workout": name.lowercased()]
            )
        case .template:
            let key = recovery >= 60
                ? "training.week.advice.strength.ready"
                : "training.week.advice.strength.adjust"
            return RecvelL10n.text(key, values: ["recovery": "\(recovery)"])
        case .recovery, .mobility:
            return recovery < 50
                ? "Tu Recuperación está en \(recovery)%. Día ideal para la sesión ligera de \(assignment.shortLabel.lowercased()) que planeaste."
                : "Sesión ligera de \(assignment.shortLabel.lowercased()): suma recuperación sin apenas carga (Recuperación \(recovery)%)."
        case .plyometrics, .speed, .contrast, .technique:
            return recovery >= 60
                ? "Sesión de \(assignment.shortLabel.lowercased()) con Recuperación en \(recovery)%: buen día para trabajo de calidad, fresco y al inicio de la sesión."
                : "Tu Recuperación está en \(recovery)% y la \(assignment.shortLabel.lowercased()) pide estar fresco. Considera moverla o bajar el volumen."
        }
    }
}


// MARK: - Agenda semanal + sesion activa (Bevel Fitness / bevelworkout.mp4)

/// Fila de coaching de entrenamiento con la evidencia científica plegable
/// (patrón `SleepCoachingCard`): nunca damos un consejo sin poder mostrar de
/// dónde sale.
private struct TrainingCoachingRow: View {
    let tip: TrainingCoachingTip
    @State private var showEvidence = false

    private var accent: Color {
        switch tip.kind {
        case .positive: ScoreKind.recovery.color
        case .readiness, .deload, .recovery: ScoreKind.energy.color
        case .timing: .cyan
        case .muscleReadiness: ScoreKind.strain.color
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: tip.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title).font(.subheadline.weight(.bold))
                    Text(tip.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
                .foregroundStyle(accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showEvidence {
                Text(tip.evidence)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityIdentifier("fitness.coaching.\(tip.kind.rawValue)")
    }
}

/// Dia de la semana elegido en la tira semanal para editarlo (sheet item).
private struct WeekdaySelection: Identifiable {
    let weekday: Int
    var id: Int { weekday }
}

struct WeeklyRoutineSection: View {
    let templates: [WorkoutTemplate]
    let latestRecovery: Int?
    var healthWorkouts: [WorkoutSummary] = []
    var revision: Int = 0
    let onStart: (WorkoutTemplate) -> Void
    let onEdit: (WorkoutTemplate) -> Void
    let onConfigure: () -> Void

    @State private var routine = WeeklyRoutineStore.load()
    @State private var showReadinessCheckIn = false
    @State private var showPlanLibrary = false
    @State private var editingWeekday: WeekdaySelection?
    @Environment(\.modelContext) private var modelContext
    // Datos para el coaching del dia siguiente (readiness, deload, timing).
    @Query(sort: \FitnessActivityLog.startDate, order: .reverse) private var activityLogs: [FitnessActivityLog]
    @Query(sort: \PlannedSleepNight.plannedBedtime, order: .reverse) private var plannedNights: [PlannedSleepNight]
    @Query(sort: \TrainingReadinessCheckIn.date, order: .reverse) private var readinessCheckIns: [TrainingReadinessCheckIn]

    private var weekday: Int { Calendar.current.component(.weekday, from: .now) }
    private var todayAssignment: DayAssignment? { routine.days[weekday] }
    private var todayDetails: ScheduledSessionDetails { routine.details(forWeekday: weekday) }
    private var planner: WeeklyRoutinePlanner { WeeklyRoutinePlanner() }
    private let coachingEngine = TrainingCoachingEngine()

    /// Foco planeado para hoy (grupo muscular o deporte), para el coaching.
    private var todayFocus: String? {
        if let override = todayDetails.focusOverride, !override.isEmpty { return override }
        return switch todayAssignment {
        case .template(let id): templates.first { $0.id == id }?.focus
        case .cardio(let name): DayAssignment.sport(fromCardioName: name)?.label ?? name
        default: nil
        }
    }

    /// Contexto del último entrenamiento registrado (con su emoji/esfuerzo).
    private var lastWorkoutContext: LastWorkoutContext? {
        let local = activityLogs.first
        let imported = healthWorkouts.max { $0.startDate < $1.startDate }
        if let imported, local.map({ imported.startDate > $0.startDate }) ?? true {
            let normalized = imported.activityName.lowercased()
            let strength = normalized.contains("fuerza") || normalized.contains("strength")
            return LastWorkoutContext(
                endedAt: imported.endDate,
                effortScore: imported.effortScore.map { Int($0.rounded()) },
                muscleGroup: imported.activityName,
                wasStrength: strength
            )
        }
        guard let local else { return nil }
        return LastWorkoutContext(
            endedAt: local.startDate.addingTimeInterval(local.durationMinutes * 60),
            effortScore: local.perceivedEffort,
            muscleGroup: local.muscleGroup,
            wasStrength: local.category == "Fuerza"
        )
    }

    /// Hora típica de entrenamiento (mediana del componente horario de los
    /// últimos 14 registros), aplicada a hoy. Deriva "a qué hora entrenó" sin
    /// pedir horarios estrictos: refleja el comportamiento real del usuario.
    private var typicalTrainingStart: Date? {
        if let configured = todayDetails.startDate(on: .now) { return configured }
        let cal = Calendar.current
        let minutes = activityLogs.prefix(14).map {
            cal.component(.hour, from: $0.startDate) * 60 + cal.component(.minute, from: $0.startDate)
        }.sorted()
        guard !minutes.isEmpty else { return nil }
        let median = minutes[minutes.count / 2]
        return cal.date(bySettingHour: median / 60, minute: median % 60, second: 0, of: .now)
    }

    private var todayReadiness: TrainingReadinessCheckIn? {
        readinessCheckIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private var currentWeekLogs: [FitnessActivityLog] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return activityLogs.filter { interval.contains($0.startDate) }
    }

    private var completedLoad: Int {
        let local = currentWeekLogs.reduce(0) { $0 + Int($1.durationMinutes) * max($1.perceivedEffort, 1) }
        let imported = currentWeekHealthWorkouts.reduce(0) { result, workout in
            guard let effort = workout.effortScore else { return result }
            return result + Int(workout.durationMinutes) * max(Int(effort.rounded()), 1)
        }
        return local + imported
    }

    private var currentWeekHealthWorkouts: [WorkoutSummary] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        var seen = Set<UUID>()
        return healthWorkouts.filter { workout in
            guard interval.contains(workout.startDate), seen.insert(workout.id).inserted else { return false }
            // Una sesión iniciada en Recvel también puede regresar desde
            // HealthKit. No contarla dos veces si coincide en cinco minutos.
            return !currentWeekLogs.contains {
                abs($0.startDate.timeIntervalSince(workout.startDate)) < 5 * 60
            }
        }
    }

    private var trainingTips: [TrainingCoachingTip] {
        coachingEngine.tips(
            todayFocus: todayFocus,
            recovery: latestRecovery,
            lastWorkout: lastWorkoutContext,
            consecutiveTrainingDays: coachingEngine.consecutiveTrainingDays(
                workoutDates: activityLogs.map(\.startDate) + healthWorkouts.map(\.startDate)
            ),
            plannedBedtime: plannedNights.first?.plannedBedtime,
            proposedStart: typicalTrainingStart,
            plannedDurationMinutes: todayDetails.durationMinutes,
            targetRPE: todayDetails.targetRPE,
            scheduleFlexibility: todayDetails.flexibility,
            readiness: todayReadiness?.coachingContext,
            plannedKind: todayAssignment
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Plan semanal", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                if routine.onboarded {
                    Menu {
                        Button {
                            Haptics.menuSelect()
                            onConfigure()
                        } label: {
                            Label("Editar plan", systemImage: "pencil")
                        }
                        Button {
                            Haptics.menuSelect()
                            showPlanLibrary = true
                        } label: {
                            Label("Biblioteca de planes", systemImage: "square.stack")
                        }
                        Button {
                            Haptics.add()
                            WeeklyPlanLibraryStore.upsert(WeeklyPlan(
                                name: routine.displayName,
                                routine: routine
                            ))
                        } label: {
                            Label("Guardar copia en biblioteca", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Haptics.warning()
                            WeeklyRoutineStore.clear()
                            routine = WeeklyRoutineStore.load()
                        } label: {
                            Label("Eliminar plan", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .hapticMenuLabel()
                    .accessibilityIdentifier("fitness.weeklyRoutine.menu")
                } else {
                    Button {
                        Haptics.add()
                        onConfigure()
                    } label: {
                        Text("Configurar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fitness.weeklyRoutine.configure")
                }
            }

            if !routine.onboarded {
                emptySetup
            } else {
                programSummary
                // El coach califica la semana SIEMPRE (incluido el positivo):
                // balanceada + recordatorio de variar, o avisos de descanso/
                // frecuencia. createdAt sale del plan guardado en la biblioteca.
                RoutineCoachCard(assessment: routineAssessment)
                    .accessibilityIdentifier("fitness.weeklyRoutine.coach")
                weekStrip
                todayCard
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: .cyan)
        // `.contain` antes del identifier: sin esto el contenedor aplana a sus
        // hijos y los ids fitness.weeklyRoutine.menu/.configure/.create
        // desaparecen del arbol de accesibilidad (bug documentado en HANDOFF).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.weeklyRoutine")
        .onAppear {
            routine = WeeklyRoutineStore.load()
            materializeLegacyTemplateLinksIfNeeded()
        }
        .onChange(of: revision) { _, _ in
            routine = WeeklyRoutineStore.load()
            materializeLegacyTemplateLinksIfNeeded()
        }
        .sheet(isPresented: $showReadinessCheckIn) {
            TrainingReadinessCheckInView(existing: todayReadiness)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showPlanLibrary) {
            WeeklyPlanLibraryView(templates: templates) {
                routine = WeeklyRoutineStore.load()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }
        .sheet(item: $editingWeekday) { selection in
            TrainingDayEditorSheet(weekday: selection.weekday, templates: templates) {
                routine = WeeklyRoutineStore.load()
                materializeLegacyTemplateLinksIfNeeded()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }
    }

    private var todayChallengeCompleted: Bool {
        activityLogs.contains {
            Calendar.current.isDateInToday($0.startDate)
                && ($0.category == DailyChallengeDay.activityCategory || $0.category == WorkoutTemplateKind.dailyChallenge.title)
        }
    }

    private func dailyChallengeCard(_ challenge: DailyChallengeDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("DESAFÍO DE HOY", systemImage: "flame.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(ScoreKind.strain.color)
                Spacer()
                Text(challenge.focus)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(challenge.title)
                .font(.subheadline.weight(.bold))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(challenge.exerciseLines, id: \.self) { line in
                    Text("· \(line)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(challenge.durationMinutes) min · sesion ligera")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    if let template = dailyChallengeTemplate { onEdit(template) }
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(ScoreKind.strain.color)
                .accessibilityIdentifier("fitness.dailyChallenge.edit")

                Button {
                    Haptics.success()
                    completeDailyChallenge(challenge)
                } label: {
                    Label(
                        todayChallengeCompleted ? "Hecho" : "Completar",
                        systemImage: todayChallengeCompleted ? "checkmark.circle.fill" : "play.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.strain.color)
                .disabled(todayChallengeCompleted)
                .accessibilityIdentifier("fitness.dailyChallenge.complete")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScoreKind.strain.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("fitness.dailyChallenge")
    }

    private func dailyChallengeTemplateCard(_ template: WorkoutTemplate) -> some View {
        let exercises = TemplateCodec.parse(template.exercisesText)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("DESAFÍO DE HOY", systemImage: "flame.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(ScoreKind.strain.color)
                Spacer()
                Text(template.focus)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(template.name)
                .font(.subheadline.weight(.bold))
            ForEach(exercises.prefix(4)) { exercise in
                Text("· \(exercise.name) · \(exercise.prescriptionLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(template.durationMinutes ?? 12) min · rutina ligera")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    onEdit(template)
                } label: {
                    Label("Editar plantilla", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(ScoreKind.strain.color)

                Button {
                    Haptics.rigid()
                    onStart(template)
                } label: {
                    Label(todayChallengeCompleted ? "Completado" : "Empezar", systemImage: todayChallengeCompleted ? "checkmark.circle.fill" : "play.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.strain.color)
                .disabled(todayChallengeCompleted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScoreKind.strain.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("fitness.dailyChallenge.template")
    }

    private func completeDailyChallenge(_ challenge: DailyChallengeDay) {
        guard !todayChallengeCompleted else { return }
        modelContext.insert(FitnessActivityLog(
            activityName: challenge.title,
            category: DailyChallengeDay.activityCategory,
            durationMinutes: Double(challenge.durationMinutes),
            perceivedEffort: 3,
            muscleGroup: challenge.focus,
            notes: challenge.exercisesText,
            effortSource: "feeling"
        ))
        try? modelContext.save()
    }

    private func materializeLegacyTemplateLinksIfNeeded() {
        guard routine.onboarded else { return }
        var available = templates
        var changed = false
        let source = (routine.planName ?? "active-plan").lowercased().replacingOccurrences(of: " ", with: "-")

        for day in 1...7 where routine.sessionTemplateIDs[day] == nil {
            let assignment = routine.days[day] ?? .rest
            if case .template(let id) = assignment {
                routine.sessionTemplateIDs[day] = id
                changed = true
                continue
            }
            guard assignment != .rest else { continue }
            let details = routine.details(forWeekday: day)
            let generated: (WorkoutTemplateKind, String, String)
            switch assignment {
            case .cardio(let raw):
                let sport = DayAssignment.sport(fromCardioName: raw)?.label ?? raw
                generated = (.cardio, sport, details.exercisesText ?? "\(sport) | \(details.durationMinutes) min")
            case .mobility:
                let fallback = DailyChallengeEngine().mobilityRoutine(focusHint: details.focusOverride)
                generated = (.mobility, details.focusOverride ?? fallback.focus, details.exercisesText ?? fallback.exercisesText)
            case .recovery:
                let fallback = DailyChallengeEngine().mobilityRoutine(focusHint: details.focusOverride)
                generated = (.recovery, details.focusOverride ?? "Recuperación activa", details.exercisesText ?? fallback.exercisesText)
            case .plyometrics:
                generated = (.performance, "Potencia", details.exercisesText ?? "Saltos tecnicos | 1x\(details.jumpContacts ?? 40)")
            case .speed:
                generated = (.performance, "Velocidad", details.exercisesText ?? "Sprint \(details.speedDistanceMeters ?? 30) m | 1x\(details.speedReps ?? 6)")
            case .contrast:
                generated = (.performance, "Contraste", details.exercisesText ?? "Bloque de contraste | \(details.contrastSets ?? 3)x4")
            case .technique:
                generated = (.performance, "Técnica", details.exercisesText ?? "Práctica técnica | \(details.durationMinutes) min")
            case .template, .rest:
                continue
            }
            let template = ScheduledTemplateMaterializer.upsert(
                sourceID: "plan.\(source).day.\(day)",
                name: "\(routine.displayName) - \(Calendar.current.shortWeekdaySymbols[day - 1]) - \(assignment.shortLabel)",
                focus: generated.1,
                exercisesText: generated.2,
                kind: generated.0,
                durationMinutes: details.durationMinutes,
                in: modelContext,
                templates: &available
            )
            routine.sessionTemplateIDs[day] = template.id
            changed = true
        }

        for (day, challenge) in routine.dailyChallenges where routine.dailyChallengeTemplateIDs[day] == nil {
            let template = ScheduledTemplateMaterializer.upsert(
                sourceID: "plan.\(source).challenge.\(day)",
                name: "Desafio - \(Calendar.current.shortWeekdaySymbols[day - 1]) - \(challenge.focus)",
                focus: challenge.focus,
                exercisesText: challenge.exercisesText,
                kind: .dailyChallenge,
                durationMinutes: challenge.durationMinutes,
                in: modelContext,
                templates: &available
            )
            routine.dailyChallengeTemplateIDs[day] = template.id
            changed = true
        }

        guard changed else { return }
        try? modelContext.save()
        WeeklyRoutineStore.save(routine)
    }

    private var programSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.displayName)
                        .font(.subheadline.weight(.bold))
                    Text("\(routine.objective.title) · \(routine.phase.title) · nivel \(routine.experience.title.lowercased())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedLoad) / \(routine.plannedLoad)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                Text("carga")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let progress = routine.plannedLoad > 0 ? min(Double(completedLoad) / Double(routine.plannedLoad), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Color.cyan).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 5)
            HStack(spacing: 0) {
                summaryMetric(value: "\(routine.plannedMinutes)", label: "min previstos")
                summaryMetric(value: "\(routine.highIntensitySessionCount)", label: "sesiones RPE 8+")
                summaryMetric(value: "\(currentWeekLogs.count + currentWeekHealthWorkouts.count)", label: "completadas")
            }
        }
        .padding(.vertical, 2)
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.bold).monospacedDigit())
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptySetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Define tu semana de entrenamiento")
                .font(.subheadline.weight(.semibold))
            Text("Elige objetivo, días y modalidades. Recvel crea un plan local y ajusta la sugerencia del día según tu Recuperación.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Haptics.add()
                onConfigure()
            } label: {
                Label("Crear mi plan semanal", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .primaryCapsuleChrome(tint: .cyan, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fitness.weeklyRoutine.create")
        }
    }

    private var weekStrip: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        // Calendar weekday: 1=Sun ... 7=Sat. Display Mon-first for LatAm training feel.
        let order = [2, 3, 4, 5, 6, 7, 1]
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let assignment = routine.days[day] ?? .rest
                let isToday = day == weekday
                Button {
                    Haptics.selection()
                    editingWeekday = WeekdaySelection(weekday: day)
                } label: {
                    VStack(spacing: 6) {
                        Text(symbols[day - 1])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isToday ? .white : .secondary)
                        Image(systemName: assignment.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color(for: assignment))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(isToday ? Color.cyan.opacity(0.22) : Color.white.opacity(0.05))
                            )
                            .overlay {
                                if isToday {
                                    Circle().strokeBorder(Color.cyan.opacity(0.7), lineWidth: 1)
                                }
                            }
                        if assignment != .rest {
                            Text("\(routine.details(forWeekday: day).targetRPE)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(routine.details(forWeekday: day).targetRPE >= 8 ? ScoreKind.strain.color : .secondary)
                        } else {
                            Text("–").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.weeklyRoutine.day.\(day)")
            }
        }
    }

    private var todayCard: some View {
        let advice = planner.todayAdvice(recovery: latestRecovery, assignment: todayAssignment)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Hoy")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(advice)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if todayAssignment != .rest {
                HStack(spacing: 12) {
                    Label(todayDetails.startDate(on: .now)?.formatted(date: .omitted, time: .shortened) ?? "Horario flexible", systemImage: "clock")
                    Label("\(todayDetails.durationMinutes) min", systemImage: "timer")
                    Label("RPE \(todayDetails.targetRPE)", systemImage: "gauge.with.dots.needle.67percent")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Button {
                    Haptics.selection()
                    showReadinessCheckIn = true
                } label: {
                    HStack {
                        Image(systemName: todayReadiness == nil ? "waveform.path.ecg" : "checkmark.circle.fill")
                        Text(todayReadiness == nil ? "Registrar cómo llegas" : "Preparación \(todayReadiness?.coachingContext.score ?? 0)/100")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.weeklyRoutine.readiness")
            }

            if let template = todayTemplate {
                Button {
                    Haptics.rigid()
                    onStart(template)
                } label: {
                    Label("Empezar \(template.name)", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .primaryCapsuleChrome(tint: ScoreKind.strain.color, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitness.weeklyRoutine.startToday")
            } else if case .cardio(let name) = todayAssignment {
                let label = DayAssignment.sport(fromCardioName: name)?.label ?? name
                let mins = routine.minutes(forWeekday: Calendar.current.component(.weekday, from: .now))
                Text("Cardio planeado: \(label) · \(mins) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let exercises = todayDetails.exercisesText, !exercises.isEmpty {
                    Text(exercises)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let todayAssignment, todayAssignment != .rest {
                Text(plannedSummaryLine(for: todayAssignment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let exercises = todayDetails.exercisesText, !exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(exercises.split(whereSeparator: \.isNewline).map(String.init).prefix(4)), id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if routine.dailyChallengesEnabled {
                if let template = dailyChallengeTemplate {
                    dailyChallengeTemplateCard(template)
                } else if let challenge = routine.dailyChallenges[weekday] {
                    dailyChallengeCard(challenge)
                }
            }

            if !trainingTips.isEmpty {
                Divider().overlay(Color.white.opacity(0.08)).padding(.vertical, 2)
                ForEach(trainingTips) { tip in
                    TrainingCoachingRow(tip: tip)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityIdentifier("fitness.weeklyRoutine.today")
    }

    /// Veredicto del coach sobre la semana guardada. La fecha de creacion del
    /// plan viene de la biblioteca (para el recordatorio de variar el estimulo).
    private var routineAssessment: RoutineAssessment {
        let createdAt = WeeklyPlanLibraryStore.load()
            .first { $0.name.caseInsensitiveCompare(routine.planName ?? "") == .orderedSame }?
            .createdAt
        return RoutineAssessmentEngine.assess(routine: routine, createdAt: createdAt)
    }

    private var todayTemplate: WorkoutTemplate? {
        guard let id = routine.templateID(forWeekday: weekday) else { return nil }
        return templates.first { $0.id == id }
    }

    private var dailyChallengeTemplate: WorkoutTemplate? {
        guard let id = routine.dailyChallengeTemplateIDs[weekday] else { return nil }
        return templates.first { $0.id == id }
    }

    /// Resumen de la sesion planeada de hoy para tipos sin boton de inicio
    /// (movilidad, recuperacion, pliometria, velocidad, contraste, tecnica).
    private func plannedSummaryLine(for assignment: DayAssignment) -> String {
        var parts = ["\(assignment.displayLabel) planeada", "\(todayDetails.durationMinutes) min"]
        if assignment == .plyometrics, let contacts = todayDetails.jumpContacts {
            parts.append("\(contacts) contactos")
        }
        if assignment == .contrast, let sets = todayDetails.contrastSets {
            parts.append("\(sets) giant sets")
        }
        if assignment == .speed, let reps = todayDetails.speedReps, let meters = todayDetails.speedDistanceMeters {
            parts.append("\(reps) × \(meters) m")
        }
        if let note = todayDetails.sessionNote, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private func color(for assignment: DayAssignment) -> Color {
        assignment.tintColor
    }
}

private struct TrainingReadinessCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: TrainingReadinessCheckIn?

    @State private var energy = 3
    @State private var soreness = 3
    @State private var motivation = 3
    @State private var hasPainOrLimitation = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("¿Cómo llegas a la sesión?")
                                .font(.title2.weight(.bold))
                            Text("Tu reporte complementa las señales del Apple Watch y mejora el ajuste de hoy.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        TrainingReadinessRatingRow(title: "Energía", low: "Muy baja", high: "Muy alta", value: $energy)
                        TrainingReadinessRatingRow(title: "Molestias musculares", low: "Ninguna", high: "Muy altas", value: $soreness)
                        TrainingReadinessRatingRow(title: "Motivación", low: "Muy baja", high: "Muy alta", value: $motivation)

                        Toggle(isOn: $hasPainOrLimitation) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dolor o limitación de movimiento")
                                    .font(.subheadline.weight(.semibold))
                                Text("No se interpreta como una puntuación de esfuerzo.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.orange)
                        .padding(14)
                        .liquidGlass(cornerRadius: 14, tint: hasPainOrLimitation ? .orange : nil)

                        TextField("Nota opcional", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .liquidGlass(cornerRadius: 14)

                        Button(action: save) {
                            Text(existing == nil ? "Guardar registro" : "Actualizar registro")
                                .font(.headline)
                                .primaryCapsuleChrome(tint: .cyan, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.readiness.save")
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Preparación de hoy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .liquidGlassNavigationBar()
        }
        .onAppear {
            guard let existing else { return }
            energy = existing.energy
            soreness = existing.soreness
            motivation = existing.motivation
            hasPainOrLimitation = existing.hasPainOrLimitation
            note = existing.note
        }
        .accessibilityIdentifier("fitness.readiness.sheet")
    }

    private func save() {
        Haptics.success()
        if let existing {
            existing.date = .now
            existing.energy = energy
            existing.soreness = soreness
            existing.motivation = motivation
            existing.hasPainOrLimitation = hasPainOrLimitation
            existing.note = note
        } else {
            modelContext.insert(TrainingReadinessCheckIn(
                energy: energy,
                soreness: soreness,
                motivation: motivation,
                hasPainOrLimitation: hasPainOrLimitation,
                note: note
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct TrainingReadinessRatingRow: View {
    let title: String
    let low: String
    let high: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)/5").font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(.cyan)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { option in
                    Button {
                        Haptics.selection()
                        value = option
                    } label: {
                        Text("\(option)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(value == option ? Color.cyan.opacity(0.24) : Color.white.opacity(0.05), in: Circle())
                            .overlay { Circle().strokeBorder(value == option ? Color.cyan.opacity(0.8) : .clear) }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14)
    }
}


struct TemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    let onEdit: () -> Void
    let onStart: () -> Void
    var onDelete: (() -> Void)?

    private var exercises: [TemplateExercise] { TemplateCodec.parse(template.exercisesText) }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.095, blue: 0.11).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header Bevel: X circular + menu "...", titulo grande + resumen.
                HStack {
                    Button {
                        Haptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                            .background(Color.white.opacity(0.08), in: Circle())
                            .tappableCircle()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")

                    Spacer()

                    Menu {
                        Button {
                            Haptics.menuSelect()
                            dismiss()
                            onEdit()
                        } label: {
                            Label("Editar rutina", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            dismiss()
                            onDelete?()
                        } label: {
                            Label("Eliminar rutina", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .hapticMenuLabel()
                    .accessibilityIdentifier("fitness.templatePreview.menu")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.title.weight(.bold))
                    Text(template.kind == .strength
                        ? "\(exercises.count) ejercicios, \(exercises.reduce(0) { $0 + $1.sets }) series"
                        : "\(template.kind.title) · \(exercises.count) ejercicios\(template.durationMinutes.map { " · \($0) min" } ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(exercises) { exercise in
                            let visual = ExerciseLibrary.thumbnail(for: exercise.name)
                            HStack(spacing: 12) {
                                ExerciseThumbnail(item: visual, size: 46)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body.weight(.semibold))
                                    Text(exercise.durationSeconds.map { "\(visual.equipment) · \($0 >= 60 && $0.isMultiple(of: 60) ? "\($0 / 60) min" : "\($0) s")" }
                                        ?? "\(visual.equipment) · \(exercise.sets) \(exercise.sets == 1 ? "serie" : "series")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }

                // Footer Bevel: Editar (lapiz, discreto) + Empezar (pill clara con play).
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                        onEdit()
                    } label: {
                        Label("Editar", systemImage: "pencil")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                        Haptics.rigid()
                        onStart()
                    } label: {
                        Label("Empezar", systemImage: "play.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                            .background(Color.white.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fitness.templatePreview.start")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Sesion compartida para cardio, movilidad, recuperacion y desafio diario.
/// Conserva la plantilla como fuente de verdad y evita mostrar controles de kg.
private struct ActiveTimedRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutTemplate

    @State private var startedAt = Date.now
    @State private var showFinish = false
    @State private var showFeelingPrompt = false

    private var exercises: [TemplateExercise] { TemplateCodec.parse(template.exercisesText) }
    private var targetSeconds: TimeInterval { TimeInterval(max(template.durationMinutes ?? 10, 1) * 60) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .headerCircleChrome(size: 40)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(template.kind.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { showFinish = true } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.cyan)
                            .headerCircleChrome(size: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(template.name)
                            .font(.largeTitle.weight(.bold))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let elapsed = max(context.date.timeIntervalSince(startedAt), 0)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(elapsed.formattedTimer)
                                    .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                                ProgressView(value: min(elapsed / targetSeconds, 1))
                                    .tint(.cyan)
                                Text("Objetivo · \(template.durationMinutes ?? 10) min")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .liquidGlass(cornerRadius: 16, tint: .cyan)
                        }

                        Text("Rutina")
                            .font(.title3.weight(.bold))
                        ForEach(exercises) { exercise in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.subheadline.weight(.semibold))
                                    Text(exercise.prescriptionLabel).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(13)
                            .liquidGlass(cornerRadius: 12)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("¿Terminar rutina?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Guardar") { showFeelingPrompt = true }
            Button("Continuar", role: .cancel) {}
        }
        .sheet(isPresented: $showFeelingPrompt) {
            WorkoutFeelingPrompt { feeling in finish(feeling: feeling) }
                .presentationDetents([.height(320)])
                .presentationCornerRadius(30)
        }
        .accessibilityIdentifier("fitness.activeTimedRoutine")
    }

    private func finish(feeling: WorkoutFeeling) {
        let minutes = max(Date.now.timeIntervalSince(startedAt) / 60, 1)
        modelContext.insert(FitnessActivityLog(
            startDate: startedAt,
            activityName: template.name,
            category: template.kind.title,
            durationMinutes: minutes,
            perceivedEffort: feeling.effortScore1to10,
            muscleGroup: template.focus,
            notes: "Rutina Recvel · \(exercises.count) ejercicios",
            workoutFeelingRaw: feeling.rawValue,
            effortSource: "feeling"
        ))
        try? modelContext.save()
        dismiss()
    }
}

private extension TimeInterval {
    var formattedTimer: String {
        let total = max(Int(self), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Sesion activa estilo Bevel Strength Builder (bevelworkout.mp4):
/// timer, series con kg/reps, completar set, Guardar → FitnessActivityLog.
struct ActiveWorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutTemplate

    @State private var exercises: [SessionExercise] = []
    @State private var startedAt = Date()
    @State private var showFinishConfirm = false
    @State private var showLibrary = false
    /// Al terminar preguntamos como se sintio la sesion (emoji) antes de guardar.
    @State private var showFeelingPrompt = false

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.095, blue: 0.11).ignoresSafeArea()
            VStack(spacing: 0) {
                ActiveSessionHeader(
                    templateName: template.name,
                    startedAt: startedAt,
                    onFinish: {
                        showFinishConfirm = true
                        Haptics.rigid()
                    },
                    onDiscard: {
                        Haptics.warning()
                        dismiss()
                    }
                )
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(exercises) { exercise in
                            ActiveSessionExerciseCard(exercise: exercise) {
                                Haptics.warning()
                                exercises.removeAll { $0.id == exercise.id }
                            }
                            if exercise.id != exercises.last?.id {
                                sessionSupersetLink
                            }
                        }
                        Button {
                            Haptics.add()
                            showLibrary = true
                        } label: {
                            HStack {
                                Text("Agregar ejercicio")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 60).contentShape(Rectangle())
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .accessibilityIdentifier("fitness.activeSession.addExercise")
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { bootstrap() }
        .sheet(isPresented: $showLibrary) {
            ExerciseLibrarySheet { names in
                for name in names {
                    let visual = ExerciseLibrary.thumbnail(for: name)
                    exercises.append(SessionExercise(
                        name: name,
                        equipment: visual.equipment,
                        sets: [SessionSet(kg: 10, reps: 12)]
                    ))
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }
        .confirmationDialog("Terminar entrenamiento?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Guardar sesion", action: { showFeelingPrompt = true })
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showFeelingPrompt) {
            WorkoutFeelingPrompt { feeling in
                finish(feeling: feeling)
            }
            .presentationDetents([.height(320)])
            .presentationCornerRadius(30)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.activeSession")
    }

    private var sessionSupersetLink: some View {
        HStack {
            Spacer()
            Image(systemName: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06), in: Circle())
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func bootstrap() {
        let parsed = TemplateCodec.parse(template.exercisesText)
        if parsed.isEmpty {
            exercises = [
                SessionExercise(name: template.name, equipment: template.focus, sets: [
                    SessionSet(kg: 0, reps: 10),
                    SessionSet(kg: 0, reps: 10),
                    SessionSet(kg: 0, reps: 10)
                ])
            ]
        } else {
            exercises = parsed.map { item in
                let visual = ExerciseLibrary.thumbnail(for: item.name)
                return SessionExercise(
                    name: item.name,
                    equipment: visual.equipment,
                    sets: (0..<max(item.sets, 1)).map { _ in
                        SessionSet(kg: item.kg ?? 0, reps: item.reps)
                    }
                )
            }
        }
        startedAt = .now
    }

    private func finish(feeling: WorkoutFeeling) {
        Keyboard.dismiss()
        Haptics.success()
        let minutes = max(Date().timeIntervalSince(startedAt) / 60, 1)
        let volume = exercises.reduce(0.0) { partial, exercise in
            partial + exercise.sets.filter(\.completed).reduce(0.0) { $0 + ($1.kg * Double($1.reps)) }
        }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let log = FitnessActivityLog(
            startDate: startedAt,
            activityName: template.name,
            category: template.kind.title,
            durationMinutes: minutes,
            // El esfuerzo ya no es un 6 hardcodeado: sale del emoji del usuario.
            perceivedEffort: feeling.effortScore1to10,
            totalVolumeKg: volume > 0 ? volume : nil,
            muscleGroup: template.focus,
            notes: "Sesion Recvel · \(completedSets) series completadas",
            workoutFeelingRaw: feeling.rawValue,
            effortSource: "feeling"
        )
        modelContext.insert(log)

        // Persistir cada serie completada habilita progresion de peso y 1RM.
        // Antes se descartaban y solo quedaba el volumen agregado.
        for exercise in exercises where template.kind == .strength {
            let group = MuscleGroupClassifier.group(for: exercise.name, fallback: template.focus)
            for (index, set) in exercise.sets.enumerated() where set.completed {
                modelContext.insert(ExerciseSetLog(
                    sessionID: log.id,
                    date: startedAt,
                    exerciseName: exercise.name,
                    muscleGroup: group,
                    setIndex: index,
                    weightKg: set.kg,
                    reps: set.reps,
                    completed: true,
                    estimatedOneRepMaxKg: OneRepMaxEstimator.estimate(weightKg: set.kg, reps: set.reps)
                ))
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Hoja de check-in post-entreno: una fila de emojis para calificar como se
/// sintio la sesion (patron de check-in de `StressEmotion`/`FastingMood`).
private struct WorkoutFeelingPrompt: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (WorkoutFeeling) -> Void
    @State private var selected: WorkoutFeeling?

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                VStack(spacing: 5) {
                    Text("¿Como se sintio?")
                        .font(.title3.weight(.bold))
                    Text("Ajusta tu carga de manana segun tu esfuerzo de hoy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    ForEach(WorkoutFeeling.allCases) { feeling in
                        Button {
                            Haptics.selection()
                            selected = feeling
                        } label: {
                            VStack(spacing: 6) {
                                Text(feeling.emoji).font(.system(size: 30))
                                Text(feeling.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selected == feeling ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected == feeling
                                        ? AnyShapeStyle(Color.cyan.opacity(0.22))
                                        : AnyShapeStyle(Color.white.opacity(0.05)))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(selected == feeling ? Color.cyan.opacity(0.6) : .clear, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fitness.feeling.\(feeling.rawValue)")
                    }
                }
                Button {
                    guard let selected else { return }
                    Haptics.success()
                    onSelect(selected)
                    dismiss()
                } label: {
                    Text("Guardar sesion")
                        .font(.headline)
                        .primaryCapsuleChrome(tint: .cyan, minHeight: 52)
                }
                .buttonStyle(.plain)
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.5 : 1)
                .accessibilityIdentifier("fitness.feeling.save")
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        // `.contain` antes del identifier o los ids de los emojis y el boton
        // de guardar se aplanan (bug documentado en HANDOFF).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.feelingPrompt")
    }
}

/// Clasifica un ejercicio en un grupo muscular a partir de su nombre. Es una
/// heuristica por palabras clave para poder desglosar volumen y progresion por
/// grupo sin pedirle al usuario que etiquete cada ejercicio.
enum MuscleGroupClassifier {
    private static let keywords: [(group: String, terms: [String])] = [
        ("Pecho", ["press banca", "press de banca", "pecho", "chest", "pec", "fondos", "aperturas", "bench"]),
        ("Espalda", ["dominada", "remo", "jalon", "pull", "espalda", "back", "peso muerto", "deadlift", "row"]),
        ("Piernas", ["sentadilla", "squat", "prensa", "zancada", "lunge", "pierna", "leg", "cuadriceps", "femoral", "gemelo", "pantorrilla", "hip thrust", "gluteo"]),
        ("Hombros", ["press militar", "hombro", "shoulder", "deltoide", "elevacion lateral", "overhead", "arnold"]),
        ("Brazos", ["curl", "biceps", "triceps", "brazo", "arm", "extension"]),
        ("Core", ["abdominal", "plancha", "plank", "core", "crunch", "oblicuo"])
    ]

    static func group(for exerciseName: String, fallback: String) -> String {
        let lower = exerciseName.lowercased()
        for entry in keywords where entry.terms.contains(where: { lower.contains($0) }) {
            return entry.group
        }
        // Si el nombre no matchea, usar el focus de la plantilla si es un grupo
        // valido; si no, "General".
        let validGroups = keywords.map(\.group)
        return validGroups.contains(fallback) ? fallback : "General"
    }
}

/// Timer aislado: el tick de 1s no re-renderiza las tarjetas de series.
private struct ActiveSessionHeader: View {
    let templateName: String
    let startedAt: Date
    let onFinish: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timeString(context.date.timeIntervalSince(startedAt)))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Text(templateName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onFinish) {
                Text("Terminar")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color(red: 0.28, green: 0.13, blue: 0.11), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fitness.activeSession.finish")

            Menu {
                Button(role: .destructive, action: onDiscard) {
                    Label("Descartar sesion", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .hapticMenuLabel()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func timeString(_ value: TimeInterval) -> String {
        let total = max(Int(value), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct ActiveSessionExerciseCard: View {
    @Bindable var exercise: SessionExercise
    let onDelete: () -> Void

    var body: some View {
        let visual = ExerciseLibrary.thumbnail(for: exercise.name)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ExerciseThumbnail(item: visual, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                    Text("\(visual.equipment) · \(exercise.sets.count) \(exercise.sets.count == 1 ? "serie" : "series")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "stopwatch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Eliminar ejercicio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .hapticMenuLabel()
                .accessibilityLabel("Opciones de \(exercise.name)")
            }

            // Mecanica del ejercicio: demostracion animada + pasos, sin salir de la sesion.
            ExerciseMechanicsButton(exerciseName: exercise.name)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                ActiveSessionSetRow(index: index, set: set)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack {
                Label("Progresion", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 20)
                Button {
                    Haptics.add()
                    let last = exercise.sets.last
                    exercise.sets.append(SessionSet(kg: last?.kg ?? 0, reps: last?.reps ?? 10))
                } label: {
                    Label("Agregar serie", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar serie a \(exercise.name)")
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("fitness.activeSession.exercise.\(exercise.name.replacingOccurrences(of: " ", with: "_"))")
    }
}

private struct ActiveSessionSetRow: View {
    let index: Int
    @Bindable var set: SessionSet

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 40, height: 40)
                .overlay { Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1) }

            sessionPill(
                value: Binding(
                    get: {
                        set.kg.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(set.kg)) : String(set.kg)
                    },
                    set: { set.kg = Double($0.replacingOccurrences(of: ",", with: ".")) ?? set.kg }
                ),
                unit: "kg",
                keyboard: .decimalPad
            )

            sessionPill(
                value: Binding(
                    get: { String(set.reps) },
                    set: { set.reps = max(Int($0) ?? set.reps, 0) }
                ),
                unit: "reps",
                keyboard: .numberPad
            )

            Button {
                let completing = !set.completed
                set.completed.toggle()
                if completing { Haptics.success() } else { Haptics.light() }
            } label: {
                Image(systemName: set.completed ? "checkmark" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.completed ? .black : .white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(set.completed ? Color.white.opacity(0.9) : Color.white.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.completed ? "Serie completada" : "Completar serie")
        }
    }

    private func sessionPill(value: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 4) {
            CommitOnBlurTextField(placeholder: "0", text: value, keyboard: keyboard, alignment: .trailing)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

@Observable
private final class SessionExercise: Identifiable {
    let id = UUID()
    var name: String
    var equipment: String
    var sets: [SessionSet]

    init(name: String, equipment: String, sets: [SessionSet]) {
        self.name = name
        self.equipment = equipment
        self.sets = sets
    }
}

@Observable
private final class SessionSet: Identifiable {
    let id = UUID()
    var kg: Double
    var reps: Int
    var completed = false

    init(kg: Double, reps: Int, completed: Bool = false) {
        self.kg = kg
        self.reps = reps
        self.completed = completed
    }
}

// MARK: - Progresion por ejercicio (peso top-set + 1RM estimado)

/// Construye los resumenes, descriptores y series de progresion por ejercicio a
/// partir de los `ExerciseSetLog`. Reusa `MetricDetailView` para la grafica.
enum ExerciseProgression {
    struct Summary: Identifiable {
        let exerciseName: String
        let muscleGroup: String
        let sessionCount: Int
        let latestTopSet: Double
        let latestOneRepMax: Double?
        var id: String { exerciseName }
    }

    /// Un resumen por ejercicio, ordenado por sesion mas reciente.
    static func summaries(from setLogs: [ExerciseSetLog]) -> [Summary] {
        let byExercise = Dictionary(grouping: setLogs, by: \.exerciseName)
        return byExercise.map { name, logs in
            let sessions = Set(logs.map(\.sessionID))
            let latestSession = logs.max { $0.date < $1.date }?.sessionID
            let latestLogs = logs.filter { $0.sessionID == latestSession }
            let topSet = latestLogs.map(\.weightKg).max() ?? 0
            let e1rm = latestLogs.compactMap(\.estimatedOneRepMaxKg).max()
            return Summary(
                exerciseName: name,
                muscleGroup: logs.first?.muscleGroup ?? "General",
                sessionCount: sessions.count,
                latestTopSet: topSet,
                latestOneRepMax: e1rm
            )
        }
        .sorted { ($0.latestOneRepMax ?? $0.latestTopSet) > ($1.latestOneRepMax ?? $1.latestTopSet) }
    }

    /// Dos metricas hermanas: peso del top-set y 1RM estimado.
    static func descriptors(exerciseName: String, setLogs: [ExerciseSetLog]) -> [MetricDescriptor] {
        [
            MetricDescriptor(
                key: "weight.\(exerciseName)",
                title: "Peso (top set)",
                symbol: "scalemass.fill",
                unit: "kg",
                decimals: 0,
                higherIsBetter: true,
                color: .blue,
                explanation: "El peso más alto que levantaste por sesión en \(exerciseName). Es la señal más directa de progresión de fuerza junto con las repeticiones.",
                resources: []
            ),
            MetricDescriptor(
                key: "e1rm.\(exerciseName)",
                title: "1RM estimado",
                symbol: "chart.line.uptrend.xyaxis",
                unit: "kg",
                decimals: 0,
                higherIsBetter: true,
                color: .cyan,
                explanation: "Estimación de tu repetición máxima a partir de peso y repeticiones (promedio de Epley y Brzycki). Solo se calcula con series de 10 reps o menos, donde las fórmulas son fiables (±5%). Es una estimación de tendencia, no un 1RM real medido.",
                resources: []
            )
        ]
    }

    /// Serie por dia de la metrica elegida (top-set o e1RM), tomando el mejor
    /// valor de cada sesion.
    static func series(for descriptor: MetricDescriptor, exerciseName: String, setLogs: [ExerciseSetLog]) -> [MetricPoint] {
        let logs = setLogs.filter { $0.exerciseName == exerciseName }
        let bySession = Dictionary(grouping: logs, by: \.sessionID)
        let isE1RM = descriptor.key.hasPrefix("e1rm.")
        return bySession.compactMap { _, sessionLogs -> MetricPoint? in
            guard let date = sessionLogs.first?.date else { return nil }
            if isE1RM {
                guard let best = sessionLogs.compactMap(\.estimatedOneRepMaxKg).max() else { return nil }
                return MetricPoint(date: date, value: best)
            } else {
                guard let best = sessionLogs.map(\.weightKg).max(), best > 0 else { return nil }
                return MetricPoint(date: date, value: best)
            }
        }
        .sorted { $0.date < $1.date }
    }
}
