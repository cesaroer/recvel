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
        case .strain: "Desempeno de strain"
        case .cardioLoad: "Carga cardio"
        case .cardioFocus: "Foco cardio"
        case .heartRateRecovery: "Recuperacion cardiaca"
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
    @StateObject private var health = HealthDataProvider()
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]
    @State private var selectedDetail: FitnessDetailRoute?
    @State private var composer: FitnessComposer?
    @State private var previewTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var activeSessionTemplate: WorkoutTemplate?
    @State private var showRoutineOnboarding = false
    @State private var routineRevision = 0
    @State private var appeared = false
    @State private var strengthMetric = "Frecuencia"
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
                            Text("Fitness")
                                .font(.largeTitle.weight(.bold))
                            Text("Ultimos 30 dias")
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
                                revision: routineRevision,
                                onStart: { template in activeSessionTemplate = template },
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
                            entrance(10) { workoutTemplates }
                        }

                        Button { composer = .sections } label: {
                            Label("Editar Fitness", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
                        .liquidGlass(cornerRadius: 8)

                        Text("Las cargas son estimaciones de bienestar basadas en duracion, zonas de frecuencia cardiaca y tu baseline. No predicen lesiones ni sustituyen una evaluacion profesional.")
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
            .navigationTitle("Fitness")
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
                ActiveWorkoutSessionView(template: template)
            }
            .sheet(isPresented: $showRoutineOnboarding, onDismiss: { routineRevision += 1 }) {
                WeeklyRoutineOnboardingView(templates: templates)
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
            }
            .task {
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
                Label("Crear plantilla de fuerza", systemImage: "square.grid.2x2")
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
                Label("Editar Fitness", systemImage: "slider.horizontal.3")
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
        .accessibilityLabel("Agregar a Fitness")
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
                Text("Tiempo registrado en workouts y actividad manual")
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
                    Text("Conecta Apple Health para ver workouts (HKWorkout) con tipo, duracion y calorias.")
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
                    Text("Sin workouts en Apple Health")
                        .font(.subheadline.weight(.semibold))
                    Text("No hay entrenamientos en los ultimos 30 dias. Los agregados de minutos pueden existir sin sesiones detalladas.")
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
                metricHeader("Desempeno de strain", icon: "waveform.path.ecg")
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

    private var workoutTemplates: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plantillas de workout").font(.title3.weight(.bold))
                Spacer()
                Button {
                    Haptics.add()
                    composer = .template
                } label: {
                    Image(systemName: "plus")
                        .headerCircleChrome(size: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Crear plantilla")
            }

            if templates.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        templateSkeleton
                        templateSkeleton
                    }
                    .opacity(0.35)
                    Text("Sin plantillas").font(.headline)
                    Text("Crea plantillas reutilizables (ejercicios, series y kilos) y enlazalas a tu agenda semanal.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        Haptics.add()
                        composer = .template
                    } label: {
                        Label("Agregar plantilla", systemImage: "plus")
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(templates) { template in
                        Button {
                            previewTemplate = template
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "figure.strengthtraining.traditional")
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
        }
        .accessibilityIdentifier("fitness.templates")
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
        guard let value else { return "Sin muestra post-workout" }
        if value >= 35 { return "Recuperacion rapida" }
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
            heroValue(durationText(total), status: "30 dias", color: ScoreKind.strain.color)
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
            heroValue(String(format: "%.0f", total), status: "Carga relativa de 7 dias", color: .purple)
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
            heroValue("\(sessions)", status: "Sesiones de fuerza en 30 dias", color: .blue)
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
                breakdownRow("Debajo", value: "\(below) dias", progress: Double(below) / Double(total), color: .blue)
                breakdownRow("Dentro", value: "\(within) dias", progress: Double(within) / Double(total), color: .green)
                breakdownRow("Sobre", value: "\(above) dias", progress: Double(above) / Double(total), color: .orange)
            case .cardioLoad:
                breakdownRow("Ultimos 7 dias", value: String(format: "%.0f", points.suffix(7).reduce(0) { $0 + $1.cardiovascularLoad }), progress: 0.72, color: .purple)
                breakdownRow("21 dias previos", value: String(format: "%.0f", points.dropLast(7).reduce(0) { $0 + $1.cardiovascularLoad }), progress: 0.58, color: .cyan)
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
            Label("Como leer esta metrica", systemImage: "info.circle.fill")
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
            "La consistencia y el volumen semanal aportan mas contexto que un unico workout. Los minutos incluyen Apple Health y registros manuales confirmados."
        case .strain:
            "Compara tu carga diaria con un rango ajustado por recovery. Es una guia para modular esfuerzo, no una cuota obligatoria ni una prediccion de riesgo."
        case .cardioLoad:
            "La carga combina tiempo en zonas de frecuencia cardiaca. Cuando faltan zonas, usa duracion como fallback de baja confianza. Observa varias semanas."
        case .cardioFocus:
            "Las zonas bajas favorecen volumen aerobico sostenible; las altas y anaerobicas aumentan intensidad. La mezcla adecuada depende del deporte y objetivo."
        case .heartRateRecovery:
            "HRR es la caida de frecuencia cardiaca durante el primer minuto tras terminar. Hidratacion, calor, postura y la forma de detener el workout pueden cambiarla."
        case .strength:
            "La frecuencia y el volumen confirmado permiten observar progresion. Recvel no infiere series, repeticiones o peso desde un workout generico de HealthKit."
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
                    Stepper("Duracion: \(duration) min", value: $duration.hapticStep(), in: 5...300, step: 5)
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
    var exercises: [EditableTemplateExercise]

    init(editing: WorkoutTemplate?) {
        name = editing?.name ?? ""
        focus = editing?.focus ?? "Fuerza general"
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

    init(_ exercise: TemplateExercise) {
        id = exercise.id
        name = exercise.name
        sets = exercise.sets
        reps = exercise.reps
        kg = exercise.kg
    }

    init(name: String, sets: Int = 1, reps: Int = 12, kg: Double? = 10) {
        id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.kg = kg
    }

    func asStruct() -> TemplateExercise {
        TemplateExercise(id: id, name: name, sets: sets, reps: reps, kg: kg)
    }
}

private struct WorkoutTemplateEditor: View {
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
        } else {
            modelContext.insert(WorkoutTemplate(name: trimmedName, focus: draft.focus, exercisesText: serialized))
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
                Text("\(draft.exercises.count) ejercicios, \(draft.exercises.reduce(0) { $0 + $1.sets }) series")
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
                    exercise.sets = min(exercise.sets + 1, 10)
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
        .init(name: "Elevacion de piernas", group: "Core", equipment: "Peso corporal", symbol: "figure.core.training", accent: .yellow)
    ]

    static func equipmentSymbol(for equipment: String) -> String {
        switch equipment {
        case "Barra": "figure.strengthtraining.traditional"
        case "Mancuernas": "dumbbell.fill"
        case "Maquina": "gearshape.fill"
        case "Cable": "link"
        case "Peso corporal": "figure.stand"
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

private struct ExerciseLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAddMany: ([String]) -> Void

    @State private var search = ""
    @State private var selected: Set<String> = []
    @State private var customName = ""
    @State private var showCustomField = false
    @State private var groupFilter: String = "Todos"
    @State private var equipmentFilter: String = "Todos"

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
        return Button {
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
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                selectionBox(isOn: isOn)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fitness.library.item.\(item.name.replacingOccurrences(of: " ", with: "_"))")
        .accessibilityLabel("\(item.name), \(item.equipment)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
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
                    Text("Resumen de actividad y desempeno de strain permanecen visibles porque conectan todo tu entrenamiento.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Editar Fitness")
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
}

enum TemplateCodec {
    static func parse(_ text: String) -> [TemplateExercise] {
        text.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            var exercise = TemplateExercise(name: parts[0], sets: 3, reps: 10, kg: nil)
            if parts.count > 1 {
                let setsReps = parts[1].lowercased().split(separator: "x")
                if setsReps.count == 2,
                   let sets = Int(setsReps[0].trimmingCharacters(in: .whitespaces)),
                   let reps = Int(setsReps[1].trimmingCharacters(in: .whitespaces)) {
                    exercise.sets = max(sets, 1)
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
            var line = "\(exercise.name) | \(exercise.sets)x\(exercise.reps)"
            if let kg = exercise.kg, kg > 0 { line += " | \(kg.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(kg)) : String(kg))" }
            return line
        }.joined(separator: "\n")
    }
}

// MARK: - Rutina semanal (agenda de entrenamiento)
// Guardada como JSON en UserDefaults: no toca el esquema SwiftData y evita
// colisiones de migracion. Patron de agenda validado contra Bevel (video
// bevelworkout.mp4) y Hevy (rutinas reutilizables + calendario semanal).

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

enum DayAssignment: Codable, Equatable {
    case rest
    case cardio(String)
    case template(UUID)

    var shortLabel: String {
        switch self {
        case .rest: "Descanso"
        case .cardio(let name): name
        case .template: "Fuerza"
        }
    }

    var icon: String {
        switch self {
        case .rest: "moon.zzz"
        case .cardio: "figure.run"
        case .template: "dumbbell"
        }
    }
}

struct WeeklyRoutine: Codable, Equatable {
    var goal: WeeklyGoal = .mixed
    var minutesPerSession: Int = 45
    var onboarded = false
    /// Clave: weekday de Calendar (1=domingo ... 7=sabado)
    var days: [Int: DayAssignment] = [:]
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
    func suggestedWeek(
        goal: WeeklyGoal,
        trainingWeekdays: [Int],
        templateIDs: [UUID]
    ) -> [Int: DayAssignment] {
        var plan: [Int: DayAssignment] = [:]
        for weekday in 1...7 { plan[weekday] = .rest }

        let sorted = trainingWeekdays.sorted()
        for (index, weekday) in sorted.enumerated() {
            switch goal {
            case .strength:
                plan[weekday] = assignment(templateIDs: templateIDs, index: index) ?? .cardio("Fuerza libre")
            case .cardio:
                plan[weekday] = .cardio(index.isMultiple(of: 2) ? "Carrera" : "Cardio suave")
            case .mixed:
                if index.isMultiple(of: 2) {
                    plan[weekday] = assignment(templateIDs: templateIDs, index: index / 2) ?? .cardio("Fuerza libre")
                } else {
                    plan[weekday] = .cardio("Carrera")
                }
            }
        }
        return plan
    }

    private func assignment(templateIDs: [UUID], index: Int) -> DayAssignment? {
        guard !templateIDs.isEmpty else { return nil }
        return .template(templateIDs[index % templateIDs.count])
    }

    /// Consejo del dia cruzando el plan con el Recovery mas reciente.
    /// Lenguaje matizado: es una sugerencia de bienestar, no prescripcion.
    func todayAdvice(recovery: Int?, assignment: DayAssignment?) -> String {
        guard let assignment else {
            return "Configura tu semana para recibir sugerencias segun tu Recovery."
        }
        guard let recovery else {
            switch assignment {
            case .rest: return "Hoy toca descanso segun tu plan."
            default: return "Hoy tienes \(assignment.shortLabel) en tu plan."
            }
        }
        switch assignment {
        case .rest:
            return recovery >= 75
                ? "Dia de descanso planeado. Tu Recovery de \(recovery) es alto; si te sientes bien, algo suave no rompe el plan."
                : "Dia de descanso y tu Recovery de \(recovery) lo agradece."
        case .cardio(let name):
            return recovery >= 60
                ? "Recovery \(recovery): buen dia para tu \(name.lowercased())."
                : "Recovery \(recovery) bajo: considera bajar la intensidad de tu \(name.lowercased()) o acortarlo."
        case .template:
            return recovery >= 60
                ? "Recovery \(recovery): tus senales acompanan la sesion de fuerza de hoy."
                : "Recovery \(recovery) bajo: puedes hacer la sesion mas ligera o moverla; escucha a tu cuerpo."
        }
    }
}


// MARK: - Agenda semanal + sesion activa (Bevel Fitness / bevelworkout.mp4)

struct WeeklyRoutineSection: View {
    let templates: [WorkoutTemplate]
    let latestRecovery: Int?
    var revision: Int = 0
    let onStart: (WorkoutTemplate) -> Void
    let onConfigure: () -> Void

    @State private var routine = WeeklyRoutineStore.load()

    private var weekday: Int { Calendar.current.component(.weekday, from: .now) }
    private var todayAssignment: DayAssignment? { routine.days[weekday] }
    private var planner: WeeklyRoutinePlanner { WeeklyRoutinePlanner() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Agenda semanal", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                if routine.onboarded {
                    Menu {
                        Button {
                            Haptics.menuSelect()
                            onConfigure()
                        } label: {
                            Label("Editar agenda", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Haptics.warning()
                            WeeklyRoutineStore.clear()
                            routine = WeeklyRoutineStore.load()
                        } label: {
                            Label("Eliminar agenda", systemImage: "trash")
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
                weekStrip
                todayCard
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: .cyan)
        .accessibilityIdentifier("fitness.weeklyRoutine")
        .onAppear { routine = WeeklyRoutineStore.load() }
        .onChange(of: revision) { _, _ in routine = WeeklyRoutineStore.load() }
    }

    private var emptySetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Define tu semana de entrenamiento")
                .font(.subheadline.weight(.semibold))
            Text("Elige objetivo, dias y minutos. Recvel arma una agenda local y te sugiere que hacer hoy segun tu Recovery.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Haptics.add()
                onConfigure()
            } label: {
                Label("Crear mi agenda", systemImage: "calendar.badge.plus")
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
                }
                .frame(maxWidth: .infinity)
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
                Text("Cardio planeado: \(name) · \(routine.minutesPerSession) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var todayTemplate: WorkoutTemplate? {
        guard case .template(let id) = todayAssignment else { return nil }
        return templates.first { $0.id == id }
    }

    private func color(for assignment: DayAssignment) -> Color {
        switch assignment {
        case .rest: .secondary
        case .cardio: ScoreKind.strain.color
        case .template: .cyan
        }
    }
}

struct WeeklyRoutineOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [WorkoutTemplate]

    @State private var step = 0
    @State private var goal: WeeklyGoal = .mixed
    @State private var selectedDays: Set<Int> = [2, 4, 6] // Lun, Mie, Vie
    @State private var minutes = 45

    private let dayOrder = [2, 3, 4, 5, 6, 7, 1]
    private var dayNames: [String] {
        let s = Calendar.current.shortWeekdaySymbols
        return dayOrder.map { s[$0 - 1] }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 18) {
                    progress
                    Group {
                        switch step {
                        case 0: goalStep
                        case 1: daysStep
                        case 2: minutesStep
                        default: reviewStep
                        }
                    }
                    Spacer(minLength: 0)
                    primaryButton
                }
                .padding(20)
            }
            .navigationTitle("Tu agenda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.soft()
                        dismiss()
                    } label: {
                        Text("Cerrar")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Cerrar")
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("fitness.routineOnboarding")
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.cyan : Color.white.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Que quieres priorizar?")
                .font(.title3.weight(.bold))
            ForEach(WeeklyGoal.allCases) { option in
                Button {
                    Haptics.selection()
                    goal = option
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.icon)
                            .foregroundStyle(.cyan)
                            .frame(width: 36, height: 36)
                            .platformGlass(tint: .cyan, shape: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.headline)
                            Text(option.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if goal == option {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan)
                        }
                    }
                    .padding(14)
                    .liquidGlass(cornerRadius: 14, tint: goal == option ? .cyan : nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Que dias entrenas?")
                .font(.title3.weight(.bold))
            Text("El resto seran dias de descanso en tu agenda.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(Array(dayOrder.enumerated()), id: \.offset) { index, day in
                    let on = selectedDays.contains(day)
                    Button {
                        Haptics.selection()
                        if on { selectedDays.remove(day) } else { selectedDays.insert(day) }
                    } label: {
                        Text(dayNames[index])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            .background(on ? Color.cyan.opacity(0.22) : Color.white.opacity(0.06), in: Capsule())
                            .overlay { Capsule().strokeBorder(on ? Color.cyan.opacity(0.7) : Color.clear, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var minutesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cuantos minutos por sesion?")
                .font(.title3.weight(.bold))
            Text("\(minutes) min")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            Slider(value: Binding(
                get: { Double(minutes) },
                set: { minutes = Int($0) }
            ), in: 20...90, step: 5)
            .tint(.cyan)
        }
    }

    private var reviewStep: some View {
        let plan = WeeklyRoutinePlanner().suggestedWeek(
            goal: goal,
            trainingWeekdays: Array(selectedDays),
            templateIDs: templates.map(\.id)
        )
        return VStack(alignment: .leading, spacing: 12) {
            Text("Tu semana sugerida")
                .font(.title3.weight(.bold))
            Text("Puedes editarla despues. Las sesiones de fuerza usan tus plantillas si existen.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(dayOrder, id: \.self) { day in
                let assignment = plan[day] ?? .rest
                HStack {
                    Text(Calendar.current.weekdaySymbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Label(label(for: assignment), systemImage: assignment.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                Divider().overlay(Color.white.opacity(0.08))
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if step < 3 {
                Haptics.medium()
                withAnimation(.snappy(duration: 0.25)) { step += 1 }
            } else {
                save()
            }
        } label: {
            Text(step < 3 ? "Continuar" : "Guardar agenda")
                .font(.headline)
                .primaryCapsuleChrome(tint: .cyan, minHeight: 52)
        }
        .buttonStyle(.plain)
        .disabled(step == 1 && selectedDays.isEmpty)
        .accessibilityIdentifier("fitness.routineOnboarding.continue")
    }

    private func label(for assignment: DayAssignment) -> String {
        switch assignment {
        case .rest: "Descanso"
        case .cardio(let name): name
        case .template(let id):
            templates.first { $0.id == id }?.name ?? "Fuerza"
        }
    }

    private func save() {
        Haptics.success()
        let days = WeeklyRoutinePlanner().suggestedWeek(
            goal: goal,
            trainingWeekdays: Array(selectedDays),
            templateIDs: templates.map(\.id)
        )
        var routine = WeeklyRoutine(
            goal: goal,
            minutesPerSession: minutes,
            onboarded: true,
            days: days
        )
        WeeklyRoutineStore.save(routine)
        dismiss()
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
                    Text("\(exercises.count) ejercicios, \(exercises.reduce(0) { $0 + $1.sets }) series")
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
                                    Text("\(visual.equipment) · \(exercise.sets) \(exercise.sets == 1 ? "serie" : "series")")
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
            Button("Guardar sesion", role: .destructive, action: finish)
            Button("Cancelar", role: .cancel) {}
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

    private func finish() {
        Keyboard.dismiss()
        Haptics.success()
        let minutes = max(Date().timeIntervalSince(startedAt) / 60, 1)
        let volume = exercises.reduce(0.0) { partial, exercise in
            partial + exercise.sets.filter(\.completed).reduce(0.0) { $0 + ($1.kg * Double($1.reps)) }
        }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let log = FitnessActivityLog(
            activityName: template.name,
            category: "Fuerza",
            durationMinutes: minutes,
            perceivedEffort: 6,
            totalVolumeKg: volume > 0 ? volume : nil,
            muscleGroup: template.focus,
            notes: "Sesion Recvel · \(completedSets) series completadas"
        )
        modelContext.insert(log)
        try? modelContext.save()
        dismiss()
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
