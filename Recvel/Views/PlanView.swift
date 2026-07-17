import SwiftData
import SwiftUI

/// Plan adaptativo completo (detalle desde Home). Metas semanales + ritmo local.
struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealLog.createdAt, order: .reverse) private var meals: [MealLog]
    @Query(sort: \EmotionLog.date, order: .reverse) private var emotionLogs: [EmotionLog]
    @Query(sort: \HabitLog.date, order: .reverse) private var habitLogs: [HabitLog]
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var nutritionProfiles: [NutritionProfile]
    @Query(sort: \SleepRoutineStep.sortOrder) private var routineSteps: [SleepRoutineStep]
    @Query(sort: \PlannedSleepNight.nightDate, order: .reverse) private var plannedNights: [PlannedSleepNight]

    @StateObject private var health = HealthDataProvider()
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("weeklyWorkoutGoal") private var workoutGoal = 4
    @AppStorage("weeklySleepGoal") private var sleepGoal = 5
    @AppStorage("weeklyBalancedGoal") private var balancedGoal = 4
    @AppStorage("weeklyNutritionGoal") private var nutritionGoal = 4
    @AppStorage("weeklyCalmGoal") private var calmGoal = 3
    @AppStorage("planWorkoutReminderEnabled") private var workoutReminderEnabled = false
    @AppStorage("planCheckInReminderEnabled") private var checkInReminderEnabled = false
    /// 0 = ciclo preferido del motor (compartido con TonightDetailView).
    @AppStorage("planCycleOverride") private var storedCycleOverride = 0
    @State private var reminderMessage = ""

    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private let nutritionPlanner = NutritionPlanEngine()
    private let notifications = LocalNotificationManager()
    private let calendar = Calendar.current

    private var cycleOverride: Int? {
        storedCycleOverride == 0 ? nil : storedCycleOverride
    }

    private var scores: [WellnessScore] {
        scoreEngine.scores(for: health.snapshot, history: health.history)
    }

    private var brief: DailyBrief {
        insightEngine.briefing(snapshot: health.snapshot, history: health.history, scores: scores, wakeMinutes: wakeMinutes)
    }

    private var thisWeekSnapshots: [DailyHealthSnapshot] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return health.history.filter { interval.contains($0.date) }
    }

    private var weekDaySlots: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var daysLeftInWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        let lastDay = interval.end.addingTimeInterval(-1)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: lastDay)
        ).day ?? 0
        return max(days, 0)
    }

    private var workoutDays: Int {
        thisWeekSnapshots.filter { ($0.workoutMinutes ?? 0) >= 20 }.count
    }

    private var sleepDays: Int {
        thisWeekSnapshots.filter { ($0.sleepHours ?? 0) >= 7.5 }.count
    }

    private var balancedDays: Int {
        thisWeekSnapshots.filter {
            let value = scoreEngine.scores(for: $0, history: health.history).first { $0.kind == .strain }?.value ?? 0
            return value >= 45 && value <= 82
        }.count
    }

    private var nutritionDays: Int {
        weekDaySlots.filter { day in
            calendar.startOfDay(for: day) <= calendar.startOfDay(for: .now)
                && nutritionHit(on: day)
        }.count
    }

    private var calmDays: Int {
        weekDaySlots.filter { day in
            calendar.startOfDay(for: day) <= calendar.startOfDay(for: .now)
                && calmHit(on: day)
        }.count
    }

    private var goalsMetCount: Int {
        [
            workoutDays >= workoutGoal,
            sleepDays >= sleepGoal,
            balancedDays >= balancedGoal,
            nutritionDays >= nutritionGoal,
            calmDays >= calmGoal
        ].filter { $0 }.count
    }

    private var weekCompletion: Double {
        let parts: [(Double, Double)] = [
            (Double(min(workoutDays, workoutGoal)), Double(max(workoutGoal, 1))),
            (Double(min(sleepDays, sleepGoal)), Double(max(sleepGoal, 1))),
            (Double(min(balancedDays, balancedGoal)), Double(max(balancedGoal, 1))),
            (Double(min(nutritionDays, nutritionGoal)), Double(max(nutritionGoal, 1))),
            (Double(min(calmDays, calmGoal)), Double(max(calmGoal, 1)))
        ]
        let sum = parts.reduce(0.0) { $0 + ($1.0 / $1.1) }
        return min(sum / Double(parts.count), 1)
    }

    /// Dias consecutivos hacia atras con al menos una meta diaria tocada (entreno, sueno o calma).
    private var softStreak: Int {
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        for _ in 0..<28 {
            let hit =
                (health.history.first { calendar.isDate($0.date, inSameDayAs: day) }.map { ($0.workoutMinutes ?? 0) >= 20 || ($0.sleepHours ?? 0) >= 7.5 } ?? false)
                || calmHit(on: day)
            if hit {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            } else if streak == 0 && calendar.isDateInToday(day) {
                // Hoy aun puede completar; no rompe la racha previa.
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            } else {
                break
            }
        }
        return streak
    }

    private var tonightWake: Date {
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        return calendar.date(byAdding: .minute, value: wakeMinutes, to: tomorrow) ?? .now
    }

    private var cycleOptions: [SleepCycleOption] {
        SleepCyclePlanner.options(wakeTime: tonightWake)
    }

    private var activeCycleOption: SleepCycleOption {
        if let cycleOverride,
           let match = cycleOptions.first(where: { $0.cycleCount == cycleOverride }) {
            return match
        }
        return SleepCyclePlanner.preferredOption(
            wakeTime: tonightWake,
            targetAsleepHours: brief.sleepNeedHours
        )
    }

    private var displayBedtime: Date { activeCycleOption.bedtime }

    private var windDownStart: Date {
        let durations = routineSteps.filter(\.isEnabled).map(\.durationMinutes)
        let earliest = SleepWindDownScheduler.earliestOffsetBeforeBed(durationsInOrder: durations)
        let minutes = max(SleepWindDownScheduler.defaultWindDownMinutes, earliest)
        return displayBedtime.addingTimeInterval(-Double(minutes) * 60)
    }

    private var disciplineNights: [SleepDisciplineNight] {
        plannedNights.map { plan in
            let sleep = health.history.compactMap(\.sleepDetails).first {
                calendar.isDate($0.startDate, inSameDayAs: plan.nightDate)
            }
            return SleepDisciplineEngine.evaluate(
                nightDate: plan.nightDate,
                plannedBedtime: plan.plannedBedtime,
                plannedWakeTime: plan.plannedWakeTime,
                targetAsleepHours: plan.targetAsleepHours,
                actualSleepStart: sleep?.startDate,
                actualSleepEnd: sleep?.endDate,
                actualAsleepHours: sleep?.asleepHours
            )
        }
        .sorted { $0.nightDate < $1.nightDate }
    }

    private var disciplineSummary: SleepDisciplineSummary {
        SleepDisciplineEngine.summary(disciplineNights)
    }

    var body: some View {
        ZStack {
            AppBackground()
            LinearGradient(
                colors: [ScoreKind.recovery.color.opacity(0.16), .clear, .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pageHeader
                    weekPulse
                    todayFocus
                    tonightEntrypoint
                    weekProgress
                    goalEditor
                    reminderCard
                    methodology
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("plan.root")
        }
        .navigationTitle("Plan")
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
                .accessibilityLabel("Atras")
            }
            ToolbarItem(placement: .principal) {
                Label("Plan", systemImage: "scope")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .platformGlass(tint: ScoreKind.recovery.color, shape: .capsule)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await health.refresh()
            snapshotTonightPlan()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN ADAPTATIVO")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(ScoreKind.recovery.color)
            Text("Hoy y esta semana")
                .font(.system(size: 31, weight: .bold))
            Text("Ajusta el sueno de esta noche a tu deuda y carga, y sigue metas semanales reales. Sin anillos punitivos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan.header")
    }

    private var weekPulse: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: weekCompletion)
                    .stroke(
                        ScoreKind.recovery.color.gradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int((weekCompletion * 100).rounded()))")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Text("%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text("Ritmo de la semana")
                    .font(.headline)
                Text("\(goalsMetCount) de 5 metas tocadas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if softStreak > 0 {
                    Label(
                        softStreak == 1 ? "1 dia con senal util" : "\(softStreak) dias con senal util",
                        systemImage: "flame.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ScoreKind.strain.color)
                } else {
                    Text("Marca un entreno, noche o check-in calmado para empezar el ritmo.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityIdentifier("plan.weekPulse")
    }

    private var todayFocus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENFOQUE DE HOY")
                .font(.caption2.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(ScoreKind.recovery.color)
            Text(brief.focusTitle)
                .font(.title3.weight(.bold))
            Text(brief.focusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ScoreKind.strain.color)
                Text(String(format: "Carga %.1f de %.1f sugerida", brief.currentLoad, brief.targetLoad))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                Spacer()
                Text(brief.remainingLoad > 0.5
                      ? String(format: "quedan %.1f", brief.remainingLoad)
                      : "objetivo tocado")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityIdentifier("plan.focus")
    }

    private var tonightEntrypoint: some View {
        NavigationLink {
            TonightDetailView()
                .hidesTabBar()
        } label: {
            TonightHomeCard(
                sleepNeedHours: brief.sleepNeedHours,
                disconnect: windDownStart,
                bedtime: displayBedtime,
                wake: activeCycleOption.wakeTime,
                cycleHint: activeCycleOption.caption,
                disciplineScore: disciplineSummary.score,
                measuredNights: disciplineSummary.measuredNights,
                minimumMeasuredNights: SleepDisciplineEngine.minimumMeasuredNights
            )
        }
        .buttonStyle(.glassCardLink)
        .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
        .accessibilityIdentifier("plan.tonight.entry")
    }

    private var weekProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Metas de esta semana")
                    .font(.headline)
                Text(weekRangeCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            weekStrip(
                title: "Entrenos 20+ min",
                icon: "figure.run",
                color: ScoreKind.strain.color,
                current: workoutDays,
                goal: workoutGoal,
                hit: { ($0.workoutMinutes ?? 0) >= 20 }
            )
            weekStrip(
                title: "Noches 7.5+ h",
                icon: "bed.double.fill",
                color: ScoreKind.sleep.color,
                current: sleepDays,
                goal: sleepGoal,
                hit: { ($0.sleepHours ?? 0) >= 7.5 }
            )
            weekStrip(
                title: "Carga equilibrada",
                icon: "scale.3d",
                color: ScoreKind.recovery.color,
                current: balancedDays,
                goal: balancedGoal,
                hit: { snapshot in
                    let value = scoreEngine.scores(for: snapshot, history: health.history).first { $0.kind == .strain }?.value ?? 0
                    return value >= 45 && value <= 82
                }
            )
            weekStripCalendar(
                title: "Nutricion registrada",
                icon: "fork.knife",
                color: ScoreKind.energy.color,
                current: nutritionDays,
                goal: nutritionGoal,
                hit: nutritionHit
            )
            weekStripCalendar(
                title: "Check-in calmado",
                icon: "brain.head.profile",
                color: .cyan,
                current: calmDays,
                goal: calmGoal,
                hit: calmHit
            )
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("plan.weekProgress")
    }

    private var weekRangeCaption: String {
        guard let first = weekDaySlots.first, let last = weekDaySlots.last else {
            return "Cuenta solo dias de esta semana desde Apple Health y tus registros"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.setLocalizedDateFormatFromTemplate("Md")
        let remaining = daysLeftInWeek == 0 ? "ultimo dia" : "quedan \(daysLeftInWeek) dias"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last)) · \(remaining)"
    }

    private func weekStrip(
        title: String,
        icon: String,
        color: Color,
        current: Int,
        goal: Int,
        hit: @escaping (DailyHealthSnapshot) -> Bool
    ) -> some View {
        weekStripCalendar(
            title: title,
            icon: icon,
            color: color,
            current: current,
            goal: goal,
            hit: { day in
                guard let snapshot = thisWeekSnapshots.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else {
                    return false
                }
                return hit(snapshot)
            }
        )
    }

    private func weekStripCalendar(
        title: String,
        icon: String,
        color: Color,
        current: Int,
        goal: Int,
        hit: @escaping (Date) -> Bool
    ) -> some View {
        let remaining = max(goal - current, 0)
        let status = remaining == 0
            ? "Meta alcanzada"
            : (remaining == 1 ? "Falta 1 dia" : "Faltan \(remaining) dias")

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(min(current, goal))/\(goal)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }

            HStack(spacing: 5) {
                ForEach(weekDaySlots, id: \.self) { day in
                    let isHit = hit(day)
                    let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: .now)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isHit ? color : Color.white.opacity(isFuture ? 0.04 : 0.10))
                            .frame(height: 22)
                            .overlay {
                                if calendar.isDateInToday(day) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                }
                            }
                        Text(weekdayLetter(day))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(calendar.isDateInToday(day) ? .primary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date).uppercased()
    }

    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ajustar metas de la semana").font(.headline)
            Text("Cambian solo el conteo de arriba (esta semana). No mueven el sueno ni la carga sugerida de hoy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            goalStepper("Entrenos de 20+ min", value: $workoutGoal, range: 1...7)
            Divider().overlay(Color.white.opacity(0.08))
            goalStepper("Noches de 7.5+ h", value: $sleepGoal, range: 1...7)
            Divider().overlay(Color.white.opacity(0.08))
            goalStepper("Dias de carga equilibrada", value: $balancedGoal, range: 1...7)
            Divider().overlay(Color.white.opacity(0.08))
            goalStepper("Dias con nutricion", value: $nutritionGoal, range: 1...7)
            Divider().overlay(Color.white.opacity(0.08))
            goalStepper("Check-ins calmados", value: $calmGoal, range: 1...7)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("plan.goalEditor")
    }

    private func goalStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value.hapticStep(), in: range) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(value.wrappedValue)/semana").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recordatorios del plan", systemImage: "bell.badge.fill")
                .font(.headline)
            Toggle("Recordar ventana de entreno", isOn: Binding(
                get: { workoutReminderEnabled },
                set: { updateWorkoutReminder($0) }
            ))
            Toggle("Recordar revisar el plan", isOn: Binding(
                get: { checkInReminderEnabled },
                set: { updateCheckInReminder($0) }
            ))
            if !reminderMessage.isEmpty {
                Text(reminderMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Locales en este dispositivo. Puedes apagarlos cuando quieras.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
        .accessibilityIdentifier("plan.reminders")
    }

    private var methodology: some View {
        Text("El enfoque y la carga de hoy salen de tu Recovery. La noche combina base, deuda reciente y strain; la hora de cama se alinea al conteo de ciclos (~90 min) mas cercano a esa necesidad, mas ~15 min para dormirte. La rutina previa es opcional (wind-down tipico 30-60 min). Nutricion cuenta dias con comida registrada (cerca de tu meta si tienes perfil). Calma cuenta meditacion Si o un check-in emocional. Estimaciones de bienestar, no prescripcion clinica.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
    }

    /// Congela la recomendacion vigente para esta noche. Si la persona cambia
    /// ciclos u hora de despertar antes de la noche, actualiza solo esa fecha.
    private func snapshotTonightPlan() {
        let nightDate = calendar.startOfDay(for: displayBedtime)
        if let existing = plannedNights.first(where: { calendar.isDate($0.nightDate, inSameDayAs: nightDate) }) {
            existing.plannedBedtime = displayBedtime
            existing.plannedWakeTime = activeCycleOption.wakeTime
            existing.targetAsleepHours = activeCycleOption.asleepHours
            existing.cycleCount = activeCycleOption.cycleCount
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                PlannedSleepNight(
                    nightDate: nightDate,
                    plannedBedtime: displayBedtime,
                    plannedWakeTime: activeCycleOption.wakeTime,
                    targetAsleepHours: activeCycleOption.asleepHours,
                    cycleCount: activeCycleOption.cycleCount
                )
            )
        }
        try? modelContext.save()
    }

    private func nutritionHit(on day: Date) -> Bool {
        let dayMeals = meals.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
        guard !dayMeals.isEmpty else { return false }
        guard let profile = nutritionProfiles.first(where: \.setupCompleted) else { return true }
        let targets = nutritionPlanner.targets(for: profile, now: day)
        let kcal = dayMeals.reduce(0) { $0 + $1.calories }
        // Banda amplia: registrar y acercarse cuenta; no castiga deficit/exceso leve.
        return kcal >= Int(Double(targets.calories) * 0.55)
    }

    private func calmHit(on day: Date) -> Bool {
        let meditated = habitLogs.contains {
            $0.habit == "Meditacion" && $0.answer && calendar.isDate($0.date, inSameDayAs: day)
        }
        let checkedIn = emotionLogs.contains { calendar.isDate($0.date, inSameDayAs: day) }
        return meditated || checkedIn
    }

    private func updateWorkoutReminder(_ enabled: Bool) {
        workoutReminderEnabled = enabled
        Task {
            if enabled {
                let ok = await notifications.requestAuthorization()
                guard ok else {
                    workoutReminderEnabled = false
                    reminderMessage = "Activa notificaciones en Ajustes de iOS para usar recordatorios."
                    return
                }
            }
            await notifications.schedulePlanWorkout(enabled: enabled, hour: 17, minute: 30)
            reminderMessage = enabled ? "Te avisaremos cerca de la tarde para moverte." : ""
        }
    }

    private func updateCheckInReminder(_ enabled: Bool) {
        checkInReminderEnabled = enabled
        Task {
            if enabled {
                let ok = await notifications.requestAuthorization()
                guard ok else {
                    checkInReminderEnabled = false
                    reminderMessage = "Activa notificaciones en Ajustes de iOS para usar recordatorios."
                    return
                }
            }
            await notifications.schedulePlanCheckIn(enabled: enabled, hour: 20, minute: 0)
            reminderMessage = enabled ? "Te recordaremos revisar enfoque y metas." : ""
        }
    }
}

// MARK: - Home entry card

struct PlanHomeCard: View {
    let focusTitle: String
    let sleepNeedHours: Double
    let bedtime: Date
    let cycleHint: String
    let workoutCurrent: Int
    let workoutGoal: Int
    let sleepCurrent: Int
    let sleepGoal: Int
    let balancedCurrent: Int
    let balancedGoal: Int

    private var weekHits: Int {
        [workoutCurrent >= workoutGoal, sleepCurrent >= sleepGoal, balancedCurrent >= balancedGoal]
            .filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("METAS SEMANALES", systemImage: "scope")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ScoreKind.recovery.color)
                Spacer()
                Text("VER DETALLE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Enfoque de hoy")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(focusTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: "Esta noche %.1f h · en cama %@ · %@", sleepNeedHours, bedtime.formatted(date: .omitted, time: .shortened), cycleHint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            VStack(spacing: 10) {
                goalProgressRow(
                    title: "Entrenos",
                    progress: weekProgressLine(
                        current: workoutCurrent,
                        goal: workoutGoal,
                        unitSingular: "entreno",
                        unitPlural: "entrenos"
                    ),
                    remaining: remainingCaption(current: workoutCurrent, goal: workoutGoal),
                    fraction: progressFraction(current: workoutCurrent, goal: workoutGoal),
                    color: ScoreKind.strain.color
                )
                goalProgressRow(
                    title: "Noches suficientes",
                    progress: weekProgressLine(
                        current: sleepCurrent,
                        goal: sleepGoal,
                        unitSingular: "noche",
                        unitPlural: "noches"
                    ),
                    remaining: remainingCaption(current: sleepCurrent, goal: sleepGoal),
                    fraction: progressFraction(current: sleepCurrent, goal: sleepGoal),
                    color: ScoreKind.sleep.color
                )
                goalProgressRow(
                    title: "Carga equilibrada",
                    progress: weekProgressLine(
                        current: balancedCurrent,
                        goal: balancedGoal,
                        unitSingular: "dia",
                        unitPlural: "dias"
                    ),
                    remaining: remainingCaption(current: balancedCurrent, goal: balancedGoal),
                    fraction: progressFraction(current: balancedCurrent, goal: balancedGoal),
                    color: ScoreKind.recovery.color
                )
            }

            Text(weekHits == 3 ? "Tres metas principales tocadas esta semana" : "\(weekHits) de 3 metas principales esta semana")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        "Metas semanales. \(focusTitle). \(weekProgressLine(current: workoutCurrent, goal: workoutGoal, unitSingular: "entreno", unitPlural: "entrenos")). \(weekProgressLine(current: sleepCurrent, goal: sleepGoal, unitSingular: "noche", unitPlural: "noches")). \(weekProgressLine(current: balancedCurrent, goal: balancedGoal, unitSingular: "dia", unitPlural: "dias"))."
    }

    private func weekProgressLine(current: Int, goal: Int, unitSingular: String, unitPlural: String) -> String {
        let shown = min(current, goal)
        let unit = shown == 1 ? unitSingular : unitPlural
        return "\(shown) de \(goal) \(unit) esta semana"
    }

    private func remainingCaption(current: Int, goal: Int) -> String {
        let left = max(goal - current, 0)
        if left == 0 { return "meta tocada" }
        if left == 1 { return "falta 1" }
        return "faltan \(left)"
    }

    private func progressFraction(current: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    private func goalProgressRow(
        title: String,
        progress: String,
        remaining: String,
        fraction: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(remaining)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fraction >= 1 ? AnyShapeStyle(color) : AnyShapeStyle(.tertiary))
            }
            Text(progress)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 6 : 0))
                }
            }
            .frame(height: 4)
        }
    }
}
