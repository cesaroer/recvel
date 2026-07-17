import SwiftUI

// MARK: - Bevel-style segmented rings

/// Tick-segment progress ring matching Bevel CalendarAndJournal day cells.
struct HomeSegmentedDayRings: View {
    let values: [HomeDayRingValue]
    var size: CGFloat = 28
    var lineWidth: CGFloat = 2.6
    var segmentCount: Int = 26

    private var rings: [HomeDayRingValue] {
        Array(values.prefix(HomeDayRingMetric.maxSelected))
    }

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.element.id) { index, value in
                let inset = CGFloat(index) * (lineWidth + 1.6)
                let diameter = max(size - inset * 2, 10)
                HomeSegmentedRingTrack(
                    progress: value.progress,
                    color: value.metric.color,
                    size: diameter,
                    lineWidth: lineWidth,
                    segmentCount: segmentCount
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct HomeSegmentedRingTrack: View {
    let progress: Double?
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let segmentCount: Int

    var body: some View {
        let filledCount: Int = {
            guard let progress, progress > 0 else { return 0 }
            return min(segmentCount, max(1, Int((progress * Double(segmentCount)).rounded(.up))))
        }()

        ZStack {
            ForEach(0..<segmentCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: max(lineWidth * 0.42, 1.1), height: lineWidth)
                    .offset(y: -(size - lineWidth) / 2)
                    .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
            }

            ForEach(0..<filledCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(color.opacity(0.95))
                    .frame(width: max(lineWidth * 0.42, 1.1), height: lineWidth)
                    .offset(y: -(size - lineWidth) / 2)
                    .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Alias kept for Home week strip call sites; Bevel segmented language.
struct HomeMiniDayRings: View {
    let values: [HomeDayRingValue]
    var size: CGFloat = 36
    var lineWidth: CGFloat = 2.4

    var body: some View {
        HomeSegmentedDayRings(
            values: values,
            size: size,
            lineWidth: lineWidth,
            segmentCount: size >= 34 ? 26 : 22
        )
    }
}

// MARK: - Day strip cell

struct HomeDayStripCell: View {
    let date: Date
    let selected: Bool
    let rings: [HomeDayRingValue]
    let namespace: Namespace.ID
    let action: () -> Void

    private let todayBlue = Color(red: 0.35, green: 0.62, blue: 1.0)

    var body: some View {
        let isToday = Calendar.current.isDateInToday(date)
        Button(action: action) {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? .white : .secondary)
                ZStack {
                    HomeMiniDayRings(values: rings, size: 34, lineWidth: 2.2)
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(selected ? .white : (isToday ? todayBlue : .primary))
                        .frame(width: 22, height: 22)
                        .background {
                            if selected {
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                                    .matchedGeometryEffect(id: "selectedDay", in: namespace)
                            }
                        }
                }
                .frame(width: 36, height: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(date: .complete, time: .omitted)
        let ringText = rings.compactMap { value -> String? in
            guard let display = value.displayValue else { return "\(value.metric.title) sin dato" }
            return "\(value.metric.title) \(display)"
        }.joined(separator: ", ")
        return ringText.isEmpty ? dateText : "\(dateText). \(ringText)"
    }
}

// MARK: - Month calendar sheet (Bevel CalendarAndJournal 1:1)

struct HomeMonthCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let history: [DailyHealthSnapshot]
    @Binding var selectedDay: Date
    @Binding var ringMetricsRaw: String

    @State private var visibleMonth: Date
    @State private var detailDay: Date

    private let calendar = Calendar.current
    private let scoreEngine = ScoreEngine()
    private let stressEngine = StressEngine()
    private let todayBlue = Color(red: 0.35, green: 0.62, blue: 1.0)

    private let weekSymbols: [String] = {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }()

    init(
        history: [DailyHealthSnapshot],
        selectedDay: Binding<Date>,
        ringMetricsRaw: Binding<String>
    ) {
        self.history = history
        self._selectedDay = selectedDay
        self._ringMetricsRaw = ringMetricsRaw
        let day = selectedDay.wrappedValue
        _visibleMonth = State(initialValue: Calendar.current.startOfDay(for: day))
        _detailDay = State(initialValue: Calendar.current.startOfDay(for: day))
    }

    private var selectedMetrics: [HomeDayRingMetric] {
        HomeDayRingEngine.selection(from: ringMetricsRaw)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.075, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            monthHeader
                            categoryChips
                            weekdayHeader
                            monthGrid
                            selectedDaySummary
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)

                    footerBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .onAppear {
                let migrated = HomeDayRingEngine.migratedStorageValue(from: ringMetricsRaw)
                if migrated != ringMetricsRaw {
                    ringMetricsRaw = migrated
                }
            }
        }
        .accessibilityIdentifier("dashboard.monthCalendar")
    }

    // MARK: Header — month title left, chevrons right (Bevel)

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(monthMenuOptions, id: \.self) { month in
                    Button {
                        Haptics.selection()
                        visibleMonth = calendar.startOfDay(for: month)
                    } label: {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    Haptics.selection()
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.selection()
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(isCurrentMonth ? 0.25 : 0.7))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
            }
        }
        .padding(.top, 4)
    }

    private var monthMenuOptions: [Date] {
        (-11...0).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: calendar.startOfDay(for: .now))
        }
        .reversed()
    }

    // MARK: Category chips — multi-select up to 2

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeDayRingMetric.chipOrder) { metric in
                    let on = selectedMetrics.contains(metric)
                    Button {
                        Haptics.selection()
                        let next = HomeDayRingEngine.toggling(metric, in: selectedMetrics)
                        guard !next.isEmpty else { return }
                        ringMetricsRaw = HomeDayRingEngine.encode(next)
                    } label: {
                        Text(metric.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? .white : Color.white.opacity(0.45))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(on ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.ringPicker.\(metric.rawValue)")
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("dashboard.ringPicker")
        .accessibilityLabel("Indicadores del calendario, maximo \(HomeDayRingMetric.maxSelected)")
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekSymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    private var monthGrid: some View {
        let days = monthGridDays
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7),
            spacing: 6
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .frame(height: 64)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: detailDay)
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > calendar.startOfDay(for: .now)
        let rings = rings(for: day)

        return Button {
            guard !isFuture else { return }
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                detailDay = calendar.startOfDay(for: day)
                selectedDay = detailDay
            }
        } label: {
            VStack(spacing: 4) {
                HomeSegmentedDayRings(
                    values: rings,
                    size: 26,
                    lineWidth: 2.4,
                    segmentCount: 24
                )
                .opacity(isFuture ? 0.35 : 1)

                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dayNumberColor(selected: selected, isToday: isToday, isFuture: isFuture))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                Capsule(style: .continuous)
                    .fill(selected ? Color.white.opacity(0.14) : Color.white.opacity(0.055))
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func dayNumberColor(selected: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isFuture { return Color.white.opacity(0.28) }
        if isToday { return todayBlue }
        if selected { return .white }
        return Color.white.opacity(0.88)
    }

    private var selectedDaySummary: some View {
        let rings = rings(for: detailDay)
        return HStack(spacing: 12) {
            ForEach(rings) { value in
                HStack(spacing: 6) {
                    Circle()
                        .fill(value.metric.color.opacity(value.hasData ? 1 : 0.3))
                        .frame(width: 7, height: 7)
                    Text(value.metric.shortTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value.displayValue ?? "—")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(value.hasData ? .primary : .tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .accessibilityIdentifier("dashboard.monthCalendar.legend")
    }

    private var footerBar: some View {
        HStack {
            Button {
                Haptics.selection()
                jumpToToday()
            } label: {
                Text("Hoy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(todayBlue)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(todayBlue.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard.monthCalendar.today")

            Spacer()

            Image(systemName: "info.circle")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.35))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.25))
    }

    private var monthGridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        if calendar.compare(next, to: .now, toGranularity: .month) == .orderedDescending { return }
        visibleMonth = next
    }

    private func jumpToToday() {
        let today = calendar.startOfDay(for: .now)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            visibleMonth = today
            detailDay = today
            selectedDay = today
        }
    }

    private func snapshot(on day: Date) -> DailyHealthSnapshot? {
        history.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func rings(for day: Date) -> [HomeDayRingValue] {
        HomeDayRingEngine.ringValues(
            for: snapshot(on: day),
            history: history,
            selected: selectedMetrics,
            isToday: calendar.isDateInToday(day),
            scoreEngine: scoreEngine,
            stressEngine: stressEngine
        )
    }
}

// MARK: - Weekly workouts card

struct HomeWeekWorkoutsCard: View {
    let summary: HomeWeekWorkoutSummary
    let onOpenFitness: () -> Void

    var body: some View {
        Button(action: onOpenFitness) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Entrenos de la semana", systemImage: "figure.run")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                if summary.hasSessions {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(summary.sessionCount)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(summary.sessionCount == 1 ? "sesion" : "sesiones")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(durationText(summary.totalMinutes))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("tiempo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if summary.totalEnergy > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(summary.totalEnergy.rounded()))")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text("kcal")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if !summary.keySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(summary.keySessions.prefix(2)) { workout in
                                HStack {
                                    Text(workout.activityName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(durationText(workout.durationMinutes))
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("Sin entrenamientos esta semana en Apple Health.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
        }
        .buttonStyle(.glassCardLink)
        .accessibilityIdentifier("dashboard.workouts")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if summary.hasSessions {
            return "Entrenos de la semana: \(summary.sessionCount) sesiones, \(durationText(summary.totalMinutes)). Abrir Fitness."
        }
        return "Sin entrenamientos esta semana. Abrir Fitness."
    }

    private func durationText(_ minutes: Double) -> String {
        let rounded = max(Int(minutes.rounded()), 0)
        return rounded >= 60 ? "\(rounded / 60)h \(rounded % 60)m" : "\(rounded)m"
    }
}
