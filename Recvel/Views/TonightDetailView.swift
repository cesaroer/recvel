import SwiftData
import SwiftUI

// MARK: - Plan entrypoint card

/// Resumen compacto de Esta noche en Metas / Plan. Navega a `TonightDetailView`.
struct TonightHomeCard: View {
    let sleepNeedHours: Double
    let disconnect: Date
    let bedtime: Date
    let wake: Date
    let cycleHint: String
    let disciplineScore: Int?
    let measuredNights: Int
    let minimumMeasuredNights: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("ESTA NOCHE", systemImage: "moon.zzz.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ScoreKind.sleep.color)
                Spacer()
                Text("VER DETALLE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disciplina de sueno")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    if let disciplineScore {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(disciplineScore)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(disciplineScoreColor(disciplineScore))
                            Text("/100")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("CREANDO BASE")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(measuredNights)/\(minimumMeasuredNights) noches medidas")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f h", sleepNeedHours))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(cycleHint)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ScoreKind.sleep.color.opacity(0.95))
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 0) {
                miniTimeline(label: "Desconecta", date: disconnect, color: .cyan)
                miniLine
                miniTimeline(label: "En cama", date: bedtime, color: ScoreKind.sleep.color)
                miniLine
                miniTimeline(label: "Despierta", date: wake, color: ScoreKind.recovery.color)
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.tonight")
    }

    private func miniTimeline(label: String, date: Date, color: Color) -> some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7).shadow(color: color.opacity(0.5), radius: 3)
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 18, height: 1)
            .padding(.bottom, 18)
    }

    private func disciplineScoreColor(_ score: Int) -> Color {
        score >= 80 ? ScoreKind.recovery.color : score >= 60 ? ScoreKind.energy.color : ScoreKind.strain.color
    }
}

// MARK: - Detail

/// Detalle completo de Esta noche: ciclos, disciplina, recordatorios y rutina encadenada.
struct TonightDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepRoutineStep.sortOrder) private var routineSteps: [SleepRoutineStep]
    @Query(sort: \PlannedSleepNight.nightDate, order: .reverse) private var plannedNights: [PlannedSleepNight]

    @StateObject private var health = HealthDataProvider()
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("planSleepReminderEnabled") private var sleepReminderEnabled = false
    /// 0 = usar el ciclo preferido del motor; otro valor = override del usuario.
    @AppStorage("planCycleOverride") private var storedCycleOverride = 0
    @State private var sleepReminderMessage = ""
    @State private var customStepTitle = ""
    @State private var customStepMinutes = 15
    @State private var selectedSleepNight: Date?

    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private let notifications = LocalNotificationManager()
    private let calendar = Calendar.current

    private var cycleOverride: Int? {
        get { storedCycleOverride == 0 ? nil : storedCycleOverride }
        nonmutating set { storedCycleOverride = newValue ?? 0 }
    }

    private var scores: [WellnessScore] {
        scoreEngine.scores(for: health.snapshot, history: health.history)
    }

    private var brief: DailyBrief {
        insightEngine.briefing(snapshot: health.snapshot, history: health.history, scores: scores, wakeMinutes: wakeMinutes)
    }

    private var strainToday: Int {
        scores.first { $0.kind == .strain }?.value ?? 0
    }

    private var sleepNeedReason: String {
        if brief.sleepDebtHours > 0.2 && strainToday > 75 {
            return "Sube por deuda reciente y carga alta de hoy."
        }
        if brief.sleepDebtHours > 0.2 {
            return String(format: "Incluye ~%.1f h por promedio bajo de los ultimos dias.", brief.sleepDebtHours)
        }
        if strainToday > 75 {
            return "Hoy tu carga fue alta; sumamos un poco mas de oportunidad."
        }
        return "Tu promedio reciente esta cerca de tu base; mantenemos una noche estable."
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

    private var enabledRoutineDurations: [Int] {
        routineSteps.filter(\.isEnabled).map(\.durationMinutes)
    }

    private var windDownStart: Date {
        let earliest = SleepWindDownScheduler.earliestOffsetBeforeBed(durationsInOrder: enabledRoutineDurations)
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
                colors: [ScoreKind.sleep.color.opacity(0.16), .clear, .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            // Polvo estelar flotante (lenguaje Bevel, ver StardustField).
            StardustField(count: 70)
                .opacity(0.75)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tonightContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("plan.tonight.detail")
        }
        .navigationTitle("Esta noche")
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
                Label("Esta noche", systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .platformGlass(tint: ScoreKind.sleep.color, shape: .capsule)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await health.refresh()
            snapshotTonightPlan()
            if sleepReminderEnabled {
                await applySleepReminders(enabled: true, announce: false)
            }
        }
        .onChange(of: activeCycleOption.cycleCount) { _, _ in
            snapshotTonightPlan()
            rescheduleSleepRemindersIfNeeded()
        }
        .onChange(of: wakeMinutes) { _, _ in
            snapshotTonightPlan()
            rescheduleSleepRemindersIfNeeded()
        }
        .onChange(of: routineSteps.map(\.minutesBeforeBed)) { _, _ in
            rescheduleSleepRemindersIfNeeded()
        }
    }

    private var tonightContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Esta noche", systemImage: "moon.zzz.fill")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.sleep.color)
                Spacer()
                Text(String(format: "%.1f h", brief.sleepNeedHours))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }

            Text(sleepNeedReason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                timelineTime(label: "Desconecta", date: windDownStart, color: .cyan)
                timelineLine
                timelineTime(label: "En cama", date: displayBedtime, color: ScoreKind.sleep.color)
                timelineLine
                timelineTime(label: "Despierta", date: activeCycleOption.wakeTime, color: ScoreKind.recovery.color)
            }

            Text(activeCycleOption.caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(ScoreKind.sleep.color.opacity(0.95))
                .accessibilityIdentifier("plan.tonight.cycleCaption")

            cyclePicker

            sleepDisciplineSection

            Text("Los ciclos (~90 min) son una heuristica para planear; la duracion real varia entre personas y noches. No es consejo medico.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            DatePicker(
                "Hora objetivo para despertar",
                selection: Binding(
                    get: { wakeDate },
                    set: {
                        wakeMinutes = Calendar.current.component(.hour, from: $0) * 60
                            + Calendar.current.component(.minute, from: $0)
                        cycleOverride = nil
                        rescheduleSleepRemindersIfNeeded()
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .font(.subheadline)
            .tint(ScoreKind.sleep.color)

            Divider().overlay(Color.white.opacity(0.08))

            sleepReminderToggles
            sleepRoutineSection
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityIdentifier("plan.tonight.content")
    }

    private var sleepReminderToggles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recordatorios de esta noche")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            Toggle("Avisarme para rutina y cama", isOn: Binding(
                get: { sleepReminderEnabled },
                set: { updateSleepReminders($0) }
            ))
            .tint(ScoreKind.sleep.color)
            .accessibilityIdentifier("plan.tonight.sleepReminders")

            if sleepReminderEnabled {
                Text(sleepReminderScheduleCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plan.tonight.sleepReminderTimes")
            }

            if !sleepReminderMessage.isEmpty {
                Text(sleepReminderMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Hasta 3 avisos suaves al dia (rutina, en cama, luces). Locales y opcionales.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var sleepRoutineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rutina previa al sueno")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            Text("Cada paso tiene una duracion. Se encadenan hacia atras desde la cama: el ultimo termina al acostarte y los anteriores empiezan antes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !routineSteps.isEmpty {
                ForEach(Array(routineSteps.enumerated()), id: \.element.id) { index, step in
                    routineStepRow(step, chainedOffset: offsetForStep(at: index))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SleepWindDownScheduler.presets) { preset in
                        let already = routineSteps.contains {
                            $0.title.caseInsensitiveCompare(preset.title) == .orderedSame
                        }
                        Button {
                            Haptics.soft()
                            addPreset(preset)
                        } label: {
                            Label(preset.title, systemImage: preset.iconName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .foregroundStyle(already ? .tertiary : .primary)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(already ? Color.white.opacity(0.04) : ScoreKind.sleep.color.opacity(0.18))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color.white.opacity(already ? 0.06 : 0.14), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(already)
                        .accessibilityLabel("Anadir \(preset.title)")
                    }
                }
            }
            .accessibilityIdentifier("plan.tonight.routinePresets")

            HStack(spacing: 8) {
                TextField("Paso propio (ej. te)", text: $customStepTitle)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Stepper(value: $customStepMinutes, in: 5...120, step: 5) {
                    Text("\(customStepMinutes) min")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()

                Button {
                    Haptics.soft()
                    addCustomStep()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ScoreKind.sleep.color)
                }
                .buttonStyle(.plain)
                .disabled(customStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Anadir paso")
            }
            .accessibilityIdentifier("plan.tonight.routineCustom")
        }
        .accessibilityIdentifier("plan.tonight.routine")
    }

    private func offsetForStep(at index: Int) -> Int {
        let allDurations = routineSteps.map(\.durationMinutes)
        let offsets = SleepWindDownScheduler.chainedOffsetsBeforeBed(durationsInOrder: allDurations)
        guard index < offsets.count else { return 0 }
        return offsets[index]
    }

    private func routineStepRow(_ step: SleepRoutineStep, chainedOffset: Int) -> some View {
        let fire = SleepWindDownScheduler.stepFireDate(
            bedtime: displayBedtime,
            minutesBeforeBed: chainedOffset
        )
        return HStack(spacing: 10) {
            Image(systemName: step.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScoreKind.sleep.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.subheadline.weight(.medium))
                Text("\(fire.formatted(date: .omitted, time: .shortened)) · \(step.durationMinutes) min · empieza \(chainedOffset) min antes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            Stepper(
                value: Binding(
                    get: { step.durationMinutes },
                    set: {
                        step.durationMinutes = min(max($0, 5), 180)
                        step.updatedAt = .now
                        try? modelContext.save()
                        rescheduleSleepRemindersIfNeeded()
                    }
                ),
                in: 5...180,
                step: 5
            ) {
                EmptyView()
            }
            .labelsHidden()

            Button {
                Haptics.soft()
                modelContext.delete(step)
                try? modelContext.save()
                rescheduleSleepRemindersIfNeeded()
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Eliminar \(step.title)")
        }
        .padding(.vertical, 4)
        .opacity(step.isEnabled ? 1 : 0.45)
    }

    private var cyclePicker: some View {
        let preferred = SleepCyclePlanner.preferredOption(
            wakeTime: tonightWake,
            targetAsleepHours: brief.sleepNeedHours
        ).cycleCount

        return VStack(alignment: .leading, spacing: 8) {
            Text("Ajusta por ciclos")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                ForEach(cycleOptions) { option in
                    let isSelected = option.cycleCount == activeCycleOption.cycleCount
                    Button {
                        Haptics.soft()
                        cycleOverride = option.cycleCount == preferred ? nil : option.cycleCount
                        rescheduleSleepRemindersIfNeeded()
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(option.cycleCount)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text("ciclos")
                                .font(.system(size: 9, weight: .semibold))
                            Text(String(format: "~%.1fh", option.asleepHours))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? Color.primary.opacity(0.85) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? Color.primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? ScoreKind.sleep.color.opacity(0.22) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isSelected ? ScoreKind.sleep.color.opacity(0.55) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.shortCaption)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .accessibilityIdentifier("plan.tonight.cycles")
        }
    }

    private var sleepDisciplineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Color.white.opacity(0.08))
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disciplina de sueno").font(.headline)
                    Text("Plan guardado vs. inicio real en Apple Health")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let score = disciplineSummary.score {
                    Text("\(score)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(disciplineScoreColor(score))
                    Text("/100").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("CREANDO BASE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 10) {
                disciplineLegend(.followed, "Seguido")
                disciplineLegend(.close, "Cerca")
                disciplineLegend(.missed, "Fuera")
                disciplineLegend(.noData, "Sin datos")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(disciplineCalendarDays, id: \.self) { day in
                    let night = disciplineNight(on: day)
                    Button {
                        selectedSleepNight = day
                        Haptics.soft()
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 9, weight: .semibold))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(night.map { disciplineColor($0.status) } ?? Color.white.opacity(0.035))
                                .frame(height: 18)
                                .overlay {
                                    if calendar.isDate(day, inSameDayAs: selectedSleepNight ?? .distantPast) {
                                        RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.8), lineWidth: 1)
                                    }
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(night == nil)
                }
            }

            if let selectedSleepNight,
               let night = disciplineNight(on: selectedSleepNight) {
                sleepNightExplanation(night)
            } else {
                Text("\(disciplineSummary.measuredNights)/\(SleepDisciplineEngine.minimumMeasuredNights) noches medidas para mostrar score. Los dias sin sesion de sueno no cuentan como fallo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Text("Score: hora de inicio 70%, duracion 20% y consistencia de despertar 10%. Una rutina no se marca como cumplida: Apple Health no registra que completaste sus pasos.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.tonight.discipline")
    }

    private func sleepNightExplanation(_ night: SleepDisciplineNight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(night.nightDate.formatted(.dateTime.weekday(.wide).day().month()))
                .font(.caption.weight(.bold))
            Text("Plan \(night.plannedBedtime.formatted(date: .omitted, time: .shortened)) · real \(night.actualSleepStart?.formatted(date: .omitted, time: .shortened) ?? "sin datos")")
                .font(.caption).monospacedDigit()
            if let delta = night.bedtimeDeltaMinutes {
                Text("\(Int(delta.rounded())) min de diferencia · \(Int((night.points ?? 0).rounded()))/100 esa noche")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("No hay una sesion Apple Health para comparar; esta noche se excluye del score.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
    }

    private var disciplineCalendarDays: [Date] {
        (0..<28).compactMap {
            calendar.date(byAdding: .day, value: $0 - 27, to: calendar.startOfDay(for: .now))
        }
    }

    private func disciplineNight(on day: Date) -> SleepDisciplineNight? {
        disciplineNights.first { calendar.isDate($0.nightDate, inSameDayAs: day) }
    }

    private func disciplineLegend(_ status: SleepDisciplineStatus, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(disciplineColor(status)).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private func disciplineColor(_ status: SleepDisciplineStatus) -> Color {
        switch status {
        case .followed: ScoreKind.recovery.color
        case .close: ScoreKind.energy.color
        case .missed: ScoreKind.strain.color
        case .noData: .white.opacity(0.12)
        }
    }

    private func disciplineScoreColor(_ score: Int) -> Color {
        score >= 80 ? ScoreKind.recovery.color : score >= 60 ? ScoreKind.energy.color : ScoreKind.strain.color
    }

    private func timelineTime(label: String, date: Date, color: Color) -> some View {
        VStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9).shadow(color: color, radius: 5)
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var timelineLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 1)
            .padding(.bottom, 22)
    }

    private var sleepReminderSlots: [SleepWindDownScheduler.ReminderSlot] {
        SleepWindDownScheduler.reminderSlots(
            bedtime: displayBedtime,
            routineDurationsInOrder: enabledRoutineDurations
        )
    }

    private var sleepReminderScheduleCaption: String {
        let parts = sleepReminderSlots.map { slot in
            "\(slot.kind.title.replacingOccurrences(of: "Hora de ", with: "")) \(slot.fireDate.formatted(date: .omitted, time: .shortened))"
        }
        return parts.joined(separator: " · ")
    }

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

    private func addPreset(_ preset: SleepWindDownScheduler.Preset) {
        guard !routineSteps.contains(where: { $0.title.caseInsensitiveCompare(preset.title) == .orderedSame }) else {
            return
        }
        let order = (routineSteps.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(
            SleepRoutineStep(
                title: preset.title,
                iconName: preset.iconName,
                minutesBeforeBed: preset.durationMinutes,
                sortOrder: order
            )
        )
        try? modelContext.save()
        rescheduleSleepRemindersIfNeeded()
    }

    private func addCustomStep() {
        let title = customStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routineSteps.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(
            SleepRoutineStep(
                title: title,
                iconName: "moon.zzz.fill",
                minutesBeforeBed: customStepMinutes,
                sortOrder: order
            )
        )
        try? modelContext.save()
        customStepTitle = ""
        rescheduleSleepRemindersIfNeeded()
    }

    private func updateSleepReminders(_ enabled: Bool) {
        sleepReminderEnabled = enabled
        Task { await applySleepReminders(enabled: enabled, announce: true) }
    }

    private func rescheduleSleepRemindersIfNeeded() {
        guard sleepReminderEnabled else { return }
        Task { await applySleepReminders(enabled: true, announce: false) }
    }

    private func applySleepReminders(enabled: Bool, announce: Bool) async {
        if enabled {
            let ok = await notifications.requestAuthorization()
            guard ok else {
                sleepReminderEnabled = false
                sleepReminderMessage = "Activa notificaciones en Ajustes de iOS para usar recordatorios."
                await notifications.schedulePlanSleepReminders(enabled: false, slots: [])
                return
            }
        }
        let slots = sleepReminderSlots
        await notifications.schedulePlanSleepReminders(enabled: enabled, slots: slots)
        if announce {
            sleepReminderMessage = enabled
                ? "Te avisaremos para la rutina, estar en cama y apagar luces."
                : ""
        }
    }

    private var wakeDate: Date {
        Calendar.current.date(byAdding: .minute, value: wakeMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }
}
