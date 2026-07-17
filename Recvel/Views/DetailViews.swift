import Charts
import SwiftData
import SwiftUI

// MARK: - Shared detail language

private struct DetailPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct DetailStat: Identifiable {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var id: String { label }
}

private struct DetailStatus {
    let text: String
    let color: Color
}

private struct DetailScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let symbol: String
    let color: Color
    let identifier: String
    @ViewBuilder let content: Content
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            LinearGradient(
                colors: [color.opacity(0.20), .clear, .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            // Polvo estelar flotante (lenguaje Bevel, ver StardustField).
            StardustField(count: 70)
                .opacity(0.75)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 14)
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
        }
        .navigationTitle(title)
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
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 13)
                .frame(height: 34)
                .platformGlass(tint: color, shape: .capsule)
                .accessibilityElement(children: .combine)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }
}

private struct DetailHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let date: Date
    let score: WellnessScore
    let valueText: String
    let unitText: String
    let statusText: String
    var targetBand: ClosedRange<Double>?
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 10) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "es_MX"))))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.055), lineWidth: 19)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(-10)

                if let targetBand {
                    Circle()
                        .trim(from: clamped(targetBand.lowerBound), to: clamped(targetBand.upperBound))
                        .stroke(
                            Color.white.opacity(0.28),
                            style: StrokeStyle(lineWidth: 19, lineCap: .butt, dash: [4, 5])
                        )
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [score.kind.color.opacity(0.45), score.kind.color, .white.opacity(0.9)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: score.kind.color.opacity(0.55), radius: 13)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(valueText)
                            .font(.system(size: 47, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(unitText)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(score.kind.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 184, height: 184)
            .padding(.vertical, 2)

            HStack(spacing: 8) {
                Circle().fill(score.kind.color).frame(width: 7, height: 7)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("Confianza \(score.confidence.rawValue.lowercased())")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(score.kind.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(score.kind.color.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.76).delay(0.08)) {
                progress = clamped(Double(score.value) / 100)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(valueText) \(unitText), confianza \(score.confidence.rawValue). \(statusText)")
    }

    private func clamped(_ value: Double) -> Double { min(max(value, 0), 1) }
}

private struct DetailStatStrip: View {
    let stats: [DetailStat]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                VStack(alignment: .leading, spacing: 6) {
                    Label(stat.label, systemImage: stat.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stat.color)
                    Text(stat.value)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)

                if index < stats.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 52)
                }
            }
        }
        .padding(.vertical, 15)
        .liquidGlass(cornerRadius: 8)
    }
}

private struct DetailSectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
    }
}

private struct DetailTrendCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let icon: String
    let valueText: String
    let typicalText: String
    let status: DetailStatus
    let points: [DetailPoint]
    let band: ClosedRange<Double>?
    let color: Color
    @State private var chartRevealed = false

    private var chartDomain: ClosedRange<Double> {
        let values = points.map(\.value) + [band?.lowerBound, band?.upperBound].compactMap { $0 }
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        let spread = max(maximum - minimum, max(abs(maximum), 1) * 0.12)
        return (minimum - spread * 0.28)...(maximum + spread * 0.28)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                Label(status.text, systemImage: "circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status.color)
                Text(typicalText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 138, alignment: .leading)

            if points.count > 1 {
                Chart {
                    if let band, let first = points.first, let last = points.last {
                        RectangleMark(
                            xStart: .value("Inicio", first.date),
                            xEnd: .value("Fin", last.date),
                            yStart: .value("Rango bajo", band.lowerBound),
                            yEnd: .value("Rango alto", band.upperBound)
                        )
                        .foregroundStyle(color.opacity(0.12))
                    }

                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Fecha", point.date),
                            y: .value("Valor", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.24), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Fecha", point.date),
                            y: .value("Valor", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(color)
                    }

                    if let last = points.last {
                        PointMark(x: .value("Actual", last.date), y: .value("Actual", last.value))
                            .symbolSize(70)
                            .foregroundStyle(color)
                    }
                }
                .chartXScale(domain: (points.first?.date ?? .now)...(points.last?.date ?? .now))
                .chartYScale(domain: chartDomain)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 92)
                .mask(alignment: .leading) {
                    Rectangle()
                        .scaleEffect(x: chartRevealed ? 1 : 0, anchor: .leading)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.title2)
                    Text("Se necesitan mas dias")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: color.opacity(0.35))
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.72)) {
                chartRevealed = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(valueText). \(status.text). \(typicalText)")
    }
}

private struct CaveatFootnote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 3)
    }
}

private struct DetailAdviceCard: View {
    let advice: DetailAdvice
    let color: Color
    let icon: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(advice.eyebrow)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(color)
                    Text(advice.title)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(advice.metric)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(color)
                    Text(advice.metricLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Text(advice.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 7) {
                ForEach(advice.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .labelStyle(AdviceReasonLabelStyle(color: color))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.065), in: Capsule())
                }
            }

            Label("Orientacion de wellness basada en tendencias, no una indicacion medica", systemImage: "checkmark.shield")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background {
            LinearGradient(
                colors: [color.opacity(0.12), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .liquidGlass(cornerRadius: 8, tint: color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct AdviceReasonLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(color)
            configuration.title
        }
    }
}

private struct DataProvenanceCard: View {
    let snapshot: DailyHealthSnapshot
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Calidad y fuente", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(color)

            Text(snapshot.sourceNames.isEmpty ? "Apple Health no reporto una fuente para estas senales." : snapshot.sourceNames.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !snapshot.qualityIssues.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(Array(snapshot.qualityIssues), id: \.self) { issue in
                        Text(issueLabel(issue))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .liquidGlass(cornerRadius: 8)
    }

    private func issueLabel(_ issue: DataQualityIssue) -> String {
        switch issue {
        case .partialDay: "Dia en progreso"
        case .insufficientHistory: "Baseline en formacion"
        case .mixedSources: "Varias fuentes"
        case .missingSleepStages: "Sin etapas de sueno"
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: y + lineHeight), points)
    }
}

// MARK: - Sleep

private struct SleepStageSlice: Identifiable {
    let name: String
    let hours: Double
    let color: Color
    let icon: String
    var id: String { name }
}

struct SleepDetailView: View {
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    let score: WellnessScore
    let snapshot: DailyHealthSnapshot
    let week: [DailyHealthSnapshot]
    /// Metrica abierta en el detalle (patron Bevel: cada card lleva a su pantalla).
    @State private var metricKey: MetricSelection?
    private let insightEngine = InsightEngine()

    private var orderedWeek: [DailyHealthSnapshot] { week.sorted { $0.date < $1.date } }
    private var tonightPlan: SleepOpportunityPlan {
        insightEngine.sleepOpportunityPlan(
            snapshot: snapshot,
            history: orderedWeek,
            wakeMinutes: wakeMinutes,
            preferredHours: sleepGoalHours
        )
    }

    var body: some View {
        DetailScaffold(title: "Sueno", symbol: "moon.stars.fill", color: ScoreKind.sleep.color, identifier: "detail.sleep") {
            Button {
                Haptics.soft()
                metricKey = MetricSelection(key: "sleepScore")
            } label: {
                DetailHero(
                    title: "Sueno",
                    date: snapshot.date,
                    score: score,
                    valueText: "\(score.value)",
                    unitText: "%",
                    statusText: score.summary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.sleep.scoreCard")

            if let sleep = snapshot.sleepDetails {
                DetailStatStrip(stats: [
                    DetailStat(label: "Tiempo dormido", value: hoursText(sleep.asleepHours + sleep.napHours), icon: "moon.fill", color: ScoreKind.sleep.color),
                    DetailStat(label: "Tiempo en cama", value: hoursText(sleep.inBedHours), icon: "bed.double.fill", color: .cyan)
                ])

                tonightPlanCard

                DetailSectionTitle(title: "Tu noche", detail: sleep.sourceName)
                sleepWindow(sleep)
                stagesCard(sleep)
                sleepBankCard
                sleepGoalStepper

                coachingSection

                DetailSectionTitle(title: "Tendencias", detail: "TOCA PARA VER EL DETALLE")
                sleepTrendCards
                DataProvenanceCard(snapshot: snapshot, color: ScoreKind.sleep.color)
            } else {
                missingSleepCard
            }

            CaveatFootnote(text: "Las etapas de sueno son estimaciones del dispositivo, no polisomnografia. Recvel muestra composicion agregada porque Apple Health no siempre entrega una secuencia suficientemente consistente para reconstruir un hipnograma sin inventar intervalos.")
        }
        .sheet(item: $metricKey) { selection in
            MetricDetailView(
                descriptors: SleepMetricCatalog.descriptors(),
                series: { descriptor in
                    if descriptor.key == "sleepScore" { return sleepScoreSeries }
                    return SleepMetricCatalog.series(for: descriptor, history: orderedWeek, goalHours: sleepGoalHours)
                },
                selectedKey: selection.key
            )
        }
    }

    /// Serie historica del Sleep Score, recalculada dia a dia con el mismo motor.
    private var sleepScoreSeries: [MetricPoint] {
        let engine = ScoreEngine()
        return orderedWeek.compactMap { day in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = engine.scores(for: day, history: history).first(where: { $0.kind == .sleep })?.value,
                  day.sleepDetails != nil
            else { return nil }
            return MetricPoint(date: day.date, value: Double(value))
        }
    }

    private var tonightPlanCard: some View {
        let plan = tonightPlan
        return VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAN PARA ESTA NOCHE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(ScoreKind.sleep.color)
                    Text("Empieza a bajar revoluciones a las \(timeText(plan.windDownStart))")
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Text(String(format: "%.1f h", plan.opportunityHours))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ScoreKind.sleep.color)
            }

            HStack(spacing: 0) {
                planMilestone(icon: "sparkles", label: "Desconecta", value: timeText(plan.windDownStart), color: .cyan)
                planConnector
                planMilestone(icon: "bed.double.fill", label: "En cama", value: timeText(plan.bedtime), color: ScoreKind.sleep.color)
                planConnector
                planMilestone(icon: "alarm.fill", label: "Despierta", value: timeText(plan.wakeTime), color: ScoreKind.recovery.color)
            }

            FlowLayout(spacing: 7) {
                if let average = plan.averageSleepHours {
                    planChip("Promedio 7d \(String(format: "%.1f h", average))", icon: "calendar")
                }
                if plan.gapHours > 0.1 {
                    planChip("Brecha \(String(format: "%.1f h", plan.gapHours))", icon: "minus.circle")
                }
                planChip("Latencia \(Int(plan.latencyMinutes)) min", icon: "hourglass")
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(ScoreKind.energy.color)
                Text("Si consumes una dosis grande de cafeina, evita hacerlo despues de las \(timeText(plan.caffeineCutoff)). La sensibilidad y la dosis cambian el efecto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background {
            LinearGradient(
                colors: [ScoreKind.sleep.color.opacity(0.16), Color.cyan.opacity(0.035), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.sleep.plan")
    }

    private func planMilestone(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 27, height: 27)
                .background(color.opacity(0.13), in: Circle())
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var planConnector: some View {
        Capsule()
            .fill(Color.white.opacity(0.11))
            .frame(width: 18, height: 2)
            .offset(y: 14)
    }

    private func planChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.065), in: Capsule())
    }

    private func sleepWindow(_ sleep: SleepSummary) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                timelineEndpoint(icon: "bed.double.fill", label: "Inicio", value: timeText(sleep.startDate), color: .cyan)
                Spacer()
                timelineEndpoint(icon: "alarm.fill", label: "Despertar", value: timeText(sleep.endDate), color: ScoreKind.sleep.color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.65), ScoreKind.sleep.color, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width)
                        .shadow(color: ScoreKind.sleep.color.opacity(0.35), radius: 8)
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .position(x: proxy.size.width * 0.54, y: 7)
                }
            }
            .frame(height: 14)

            HStack {
                Label("Latencia \(sleep.latencyMinutes.map { "\(Int($0)) min" } ?? "sin dato")", systemImage: "hourglass")
                Spacer()
                Label("Eficiencia \(sleep.efficiency.map { "\(Int($0))%" } ?? "sin dato")", systemImage: "gauge.with.dots.needle.67percent")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
    }

    private func timelineEndpoint(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
        }
    }

    private func stagesCard(_ sleep: SleepSummary) -> some View {
        let stages = stageSlices(sleep)
        let total = max(stages.reduce(0) { $0 + $1.hours }, 0.1)

        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Composicion").font(.headline)
                Spacer()
                if sleep.napHours > 0 {
                    Label("Siesta \(hoursText(sleep.napHours))", systemImage: "sun.haze.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ScoreKind.energy.color)
                }
            }

            if sleep.hasStages {
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        ForEach(stages) { stage in
                            Capsule()
                                .fill(stage.color)
                                .frame(width: max(proxy.size.width * stage.hours / total - 3, 5))
                                .shadow(color: stage.color.opacity(0.35), radius: 4)
                        }
                    }
                }
                .frame(height: 16)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(stages) { stage in
                        HStack(spacing: 9) {
                            Image(systemName: stage.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(stage.color)
                                .frame(width: 27, height: 27)
                                .background(stage.color.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stage.name).font(.caption).foregroundStyle(.secondary)
                                Text("\(hoursText(stage.hours)) · \(Int(stage.hours / total * 100))%")
                                    .font(.subheadline.weight(.bold)).monospacedDigit()
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            } else {
                Label("Esta fuente registra duracion, pero no etapas. Recvel no las inventa.", systemImage: "moon.dust.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.sleep.stages")
    }

    /// Sleep Bank (patron Bevel): balance acumulado de la ventana rodante de
    /// 14 dias contra la meta del usuario. La ventana y el copy siguen la
    /// evidencia documentada en `SleepBankEngine`.
    private var sleepBankCard: some View {
        let bank = SleepBankEngine().assess(history: orderedWeek, goalHours: sleepGoalHours)
        let accent = bank.isSurplus ? ScoreKind.recovery.color : ScoreKind.sleep.color

        return Button {
            Haptics.soft()
            metricKey = MetricSelection(key: "sleepBank")
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SLEEP BANK")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(accent)
                        Text(bank.hasEnoughData ? (bank.isSurplus ? "Superavit" : "Deuda acumulada") : "Calibrando")
                            .font(.title3.weight(.bold))
                        Text("Ultimos \(SleepBankEngine.windowDays) dias · meta \(String(format: "%.1f", sleepGoalHours)) h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(bank.hasEnoughData ? signedHours(bank.balanceHours) : "--")
                            .font(.system(size: 30, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                        Text("\(bank.nights) noches")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if bank.nightly.count > 1 {
                    Chart(bank.nightly) { point in
                        BarMark(
                            x: .value("Dia", point.date, unit: .day),
                            y: .value("Balance", point.value)
                        )
                        .foregroundStyle(point.value >= 0 ? ScoreKind.recovery.color : ScoreKind.sleep.color)
                        .cornerRadius(3)
                        RuleMark(y: .value("Meta", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.22))
                    }
                    .chartYAxis { AxisMarks(position: .trailing) }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.narrow))
                        }
                    }
                    .frame(height: 118)
                    .allowsHitTesting(false)
                }

                // Copy honesto: la recuperacion de fin de semana es parcial.
                if bank.hasEnoughData && !bank.isSurplus {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Recuperar es gradual: sumar 30-60 min por noche rinde mas que una sola noche larga. El sueno de fin de semana compensa solo en parte.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 16, tint: accent)
            .tappableRounded(16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.sleep.bank")
    }

    /// Meta de sueno debajo del Sleep Bank (fuera del boton para no pelear gestos).
    private var sleepGoalStepper: some View {
        Stepper(value: $sleepGoalHours, in: 6...10, step: 0.5) {
            Text("Meta por noche: \(String(format: "%.1f", sleepGoalHours)) h")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 12, tint: ScoreKind.sleep.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.sleep.bank.goal")
    }

    /// Coaching con evidencia citada (`SleepCoachingEngine`).
    private var coachingSection: some View {
        let bank = SleepBankEngine().assess(history: orderedWeek, goalHours: sleepGoalHours)
        let tips = SleepCoachingEngine().tips(
            score: score.value,
            snapshot: snapshot,
            history: orderedWeek,
            bank: bank
        )
        return Group {
            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    DetailSectionTitle(title: "Coaching", detail: "segun tu score y tus senales")
                    VStack(spacing: 10) {
                        ForEach(tips) { tip in SleepCoachingCard(tip: tip) }
                    }
                }
                .accessibilityIdentifier("detail.sleep.coaching")
            }
        }
    }

    /// Cada card abre el detalle de su metrica (patron Bevel).
    @ViewBuilder
    private var sleepTrendCards: some View {
        tappableTrendCard(key: "timeAsleep", title: "Tiempo dormido", icon: "moon.fill", values: orderedWeek.compactMap { day in day.sleepHours.map { DetailPoint(date: day.date, value: $0) } }, current: snapshot.sleepHours, unit: "h", higherIsBetter: true, decimals: 1)
        tappableTrendCard(key: "deep", title: "Sueno profundo", icon: "moon.stars.fill", values: orderedWeek.compactMap { day in day.sleepDetails.map { DetailPoint(date: day.date, value: $0.deepHours) } }, current: snapshot.sleepDetails?.deepHours, unit: "h", higherIsBetter: true, decimals: 1)
        tappableTrendCard(key: "rem", title: "Sueno REM", icon: "brain.head.profile", values: orderedWeek.compactMap { day in day.sleepDetails.map { DetailPoint(date: day.date, value: $0.remHours) } }, current: snapshot.sleepDetails?.remHours, unit: "h", higherIsBetter: true, decimals: 1)
        tappableTrendCard(key: "latency", title: "Latencia", icon: "hourglass", values: orderedWeek.compactMap { day in day.sleepDetails?.latencyMinutes.map { DetailPoint(date: day.date, value: $0) } }, current: snapshot.sleepDetails?.latencyMinutes, unit: "min", higherIsBetter: false, decimals: 0)
        tappableTrendCard(key: "efficiency", title: "Eficiencia", icon: "gauge.with.dots.needle.67percent", values: orderedWeek.compactMap { day in day.sleepDetails?.efficiency.map { DetailPoint(date: day.date, value: $0) } }, current: snapshot.sleepDetails?.efficiency, unit: "%", higherIsBetter: true, decimals: 0)
        tappableTrendCard(key: "consistency", title: "Consistencia", icon: "clock.arrow.2.circlepath", values: orderedWeek.compactMap { day in day.sleepDetails?.consistencyMinutes.map { DetailPoint(date: day.date, value: $0) } }, current: snapshot.sleepDetails?.consistencyMinutes, unit: "min", higherIsBetter: false, decimals: 0)
    }

    private func tappableTrendCard(key: String, title: String, icon: String, values: [DetailPoint], current: Double?, unit: String, higherIsBetter: Bool, decimals: Int) -> some View {
        Button {
            Haptics.soft()
            metricKey = MetricSelection(key: key)
        } label: {
            trendCard(title: title, icon: icon, values: values, current: current, unit: unit, higherIsBetter: higherIsBetter, decimals: decimals)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.sleep.metric.\(key)")
    }

    private func trendCard(title: String, icon: String, values: [DetailPoint], current: Double?, unit: String, higherIsBetter: Bool, decimals: Int) -> some View {
        let raw = values.map(\.value)
        let band = personalBand(raw)
        let typical = median(raw)
        return DetailTrendCard(
            title: title,
            icon: icon,
            valueText: current.map { number($0, decimals: decimals, unit: unit) } ?? "Sin dato",
            typicalText: typical.map { "Tipico \(number($0, decimals: decimals, unit: unit))" } ?? "Baseline pendiente",
            status: detailStatus(current: current, band: band, higherIsBetter: higherIsBetter),
            points: values,
            band: band,
            color: ScoreKind.sleep.color
        )
    }

    private var missingSleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sin sueno disponible", systemImage: "moon.zzz")
                .font(.headline)
                .foregroundStyle(ScoreKind.sleep.color)
            Text("Usa Apple Watch durante la noche y revisa el permiso de Sueno en Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
    }

    private func stageSlices(_ sleep: SleepSummary) -> [SleepStageSlice] {
        var stages = [
            SleepStageSlice(name: "Deep", hours: sleep.deepHours, color: Color(red: 0.38, green: 0.32, blue: 0.95), icon: "moon.fill"),
            SleepStageSlice(name: "Core", hours: sleep.coreHours, color: ScoreKind.sleep.color, icon: "moon.haze.fill"),
            SleepStageSlice(name: "REM", hours: sleep.remHours, color: .cyan, icon: "brain.head.profile"),
            SleepStageSlice(name: "Despierto", hours: sleep.awakeHours, color: ScoreKind.strain.color, icon: "eye.fill")
        ]
        if sleep.unspecifiedHours > 0.05 {
            stages.insert(SleepStageSlice(name: "Sin clasificar", hours: sleep.unspecifiedHours, color: .gray, icon: "questionmark"), at: 3)
        }
        return stages.filter { $0.hours > 0.01 }
    }
}

// MARK: - Recovery

struct RecoveryDetailView: View {
    let score: WellnessScore
    let snapshot: DailyHealthSnapshot
    let week: [DailyHealthSnapshot]
    /// Metrica abierta en el detalle (patron Bevel).
    @State private var metricKey: MetricSelection?
    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private var orderedWeek: [DailyHealthSnapshot] { week.sorted { $0.date < $1.date } }
    private var strainScore: Int {
        scoreEngine.scores(for: snapshot, history: orderedWeek).first { $0.kind == .strain }?.value ?? 0
    }
    private var advice: DetailAdvice {
        insightEngine.recoveryAdvice(
            snapshot: snapshot,
            history: orderedWeek,
            recoveryScore: score.value,
            strainScore: strainScore
        )
    }

    var body: some View {
        DetailScaffold(title: "Recovery", symbol: "heart.fill", color: ScoreKind.recovery.color, identifier: "detail.recovery") {
            Button {
                Haptics.soft()
                metricKey = MetricSelection(key: "recoveryScore")
            } label: {
                DetailHero(
                    title: "Recovery",
                    date: snapshot.date,
                    score: score,
                    valueText: "\(score.value)",
                    unitText: "%",
                    statusText: score.summary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.recovery.scoreCard")

            DetailStatStrip(stats: [
                DetailStat(label: "HRV", value: snapshot.hrv.map { "\(Int($0)) ms" } ?? "Sin dato", icon: "waveform.path.ecg", color: ScoreKind.recovery.color),
                DetailStat(label: "FC en reposo", value: snapshot.restingHeartRate.map { "\(Int($0)) bpm" } ?? "Sin dato", icon: "heart.fill", color: .cyan)
            ])

            DetailAdviceCard(
                advice: advice,
                color: ScoreKind.recovery.color,
                icon: "wand.and.stars",
                identifier: "detail.recovery.advice"
            )

            DetailSectionTitle(title: "Que movio tu Recovery", detail: "VS. BASELINE")
            driversCard

            DetailSectionTitle(title: "Senales", detail: "ULTIMOS \(min(orderedWeek.count, 14)) DIAS")
            recoveryTrendCards
            DataProvenanceCard(snapshot: snapshot, color: ScoreKind.recovery.color)

            CaveatFootnote(text: "HRV y FC en reposo cambian con alcohol, enfermedad, sueno, postura y calidad de medicion. Recovery resume tendencias de bienestar y no diagnostica fatiga, enfermedad ni capacidad deportiva.")
        }
        .sheet(item: $metricKey) { selection in
            MetricDetailView(
                descriptors: RecoveryMetricCatalog.descriptors(),
                series: { descriptor in
                    if descriptor.key == "recoveryScore" { return recoveryScoreSeries }
                    return RecoveryMetricCatalog.series(for: descriptor, history: orderedWeek)
                },
                selectedKey: selection.key
            )
        }
    }

    private var recoveryScoreSeries: [MetricPoint] {
        orderedWeek.compactMap { day in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = scoreEngine.scores(for: day, history: history).first(where: { $0.kind == .recovery })?.value
            else { return nil }
            return MetricPoint(date: day.date, value: Double(value))
        }
    }

    private var driversCard: some View {
        let factors = scoreEngine.factors(for: snapshot, history: orderedWeek)
        return VStack(alignment: .leading, spacing: 15) {
            ForEach(factors) { factor in
                HStack(spacing: 11) {
                    Image(systemName: factor.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ScoreKind.recovery.color)
                        .frame(width: 30, height: 30)
                        .background(ScoreKind.recovery.color.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(factor.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(factor.value).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                        HStack(spacing: 8) {
                            Text(factor.baseline ?? "Baseline pendiente")
                                .font(.caption2).foregroundStyle(.secondary)
                            contributionTrack(factor.contribution)
                        }
                    }
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.recovery.factors")
    }

    private func contributionTrack(_ contribution: Double) -> some View {
        GeometryReader { proxy in
            let position = proxy.size.width * (min(max(contribution, -1), 1) + 1) / 2
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 13).offset(x: proxy.size.width / 2)
                Circle()
                    .fill(contribution >= 0 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                    .frame(width: 10, height: 10)
                    .offset(x: max(position - 5, 0))
            }
        }
        .frame(height: 13)
    }

    @ViewBuilder
    private var recoveryTrendCards: some View {
        // Misma serie que el detalle: baseline solo con dias ANTERIORES (no se
        // mira al futuro) y se omiten los dias sin score en vez de inyectar 0.
        let recoveryPoints = recoveryScoreSeries.map { DetailPoint(date: $0.date, value: $0.value) }
        tappableTrendCard(key: "recoveryScore", title: "Recovery", icon: "heart.fill", values: recoveryPoints, current: Double(score.value), unit: "%", higherIsBetter: true, decimals: 0, color: ScoreKind.recovery.color)
        tappableTrendCard(key: "hrv", title: "HRV", icon: "waveform.path.ecg", values: points(\.hrv), current: snapshot.hrv, unit: "ms", higherIsBetter: true, decimals: 0, color: ScoreKind.recovery.color)
        tappableTrendCard(key: "rhr", title: "FC en reposo", icon: "heart.fill", values: points(\.restingHeartRate), current: snapshot.restingHeartRate, unit: "bpm", higherIsBetter: false, decimals: 0, color: .cyan)
        tappableTrendCard(key: "respiratory", title: "Respiracion", icon: "lungs.fill", values: points(\.respiratoryRate), current: snapshot.respiratoryRate, unit: "rpm", higherIsBetter: false, decimals: 1, color: Color(red: 0.35, green: 0.72, blue: 0.95))
        // SpO2 y temperatura de muneca: presentes en Bevel, faltaban en Recvel.
        tappableTrendCard(key: "spo2", title: "Saturacion de oxigeno", icon: "drop.degreesign.fill", values: oxygenPoints, current: normalizedOxygen(snapshot.oxygenSaturation), unit: "%", higherIsBetter: true, decimals: 1, color: Color(red: 0.45, green: 0.65, blue: 1.0))
        tappableTrendCard(key: "wristTemperature", title: "Temperatura de muneca", icon: "thermometer.medium", values: points(\.wristTemperature), current: snapshot.wristTemperature, unit: "°C", higherIsBetter: false, decimals: 1, color: ScoreKind.energy.color)
        tappableTrendCard(key: "timeAsleep", title: "Tiempo dormido", icon: "moon.fill", values: points(\.sleepHours), current: snapshot.sleepHours, unit: "h", higherIsBetter: true, decimals: 1, color: ScoreKind.sleep.color)
    }

    /// HealthKit entrega SpO2 como fraccion (0-1); la UI la muestra en porcentaje.
    private func normalizedOxygen(_ value: Double?) -> Double? {
        value.map { $0 <= 1 ? $0 * 100 : $0 }
    }

    private var oxygenPoints: [DetailPoint] {
        orderedWeek.compactMap { day in
            normalizedOxygen(day.oxygenSaturation).map { DetailPoint(date: day.date, value: $0) }
        }
    }

    private func tappableTrendCard(key: String, title: String, icon: String, values: [DetailPoint], current: Double?, unit: String, higherIsBetter: Bool, decimals: Int, color: Color) -> some View {
        Button {
            Haptics.soft()
            metricKey = MetricSelection(key: key)
        } label: {
            trendCard(title: title, icon: icon, values: values, current: current, unit: unit, higherIsBetter: higherIsBetter, decimals: decimals, color: color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.recovery.metric.\(key)")
    }

    private func points(_ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> [DetailPoint] {
        orderedWeek.compactMap { day in day[keyPath: keyPath].map { DetailPoint(date: day.date, value: $0) } }
    }

    private func trendCard(title: String, icon: String, values: [DetailPoint], current: Double?, unit: String, higherIsBetter: Bool, decimals: Int, color: Color) -> some View {
        let raw = values.map(\.value)
        let band = personalBand(raw)
        let typical = median(raw)
        return DetailTrendCard(
            title: title,
            icon: icon,
            valueText: current.map { number($0, decimals: decimals, unit: unit) } ?? "Sin dato",
            typicalText: typical.map { "Tipico \(number($0, decimals: decimals, unit: unit))" } ?? "Baseline pendiente",
            status: detailStatus(current: current, band: band, higherIsBetter: higherIsBetter),
            points: values,
            band: band,
            color: color
        )
    }
}

// MARK: - Strain

struct StrainDetailView: View {
    let score: WellnessScore
    let recovery: WellnessScore?
    let snapshot: DailyHealthSnapshot
    let week: [DailyHealthSnapshot]
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var profiles: [NutritionProfile]
    /// Metrica abierta en el detalle (patron Bevel: cada card lleva a su pantalla).
    @State private var metricKey: MetricSelection?
    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private var orderedWeek: [DailyHealthSnapshot] { week.sorted { $0.date < $1.date } }

    private var targetPercent: ClosedRange<Double> {
        let recoveryValue = recovery?.value ?? 58
        return Double(max(recoveryValue - 25, 20)) / 100...Double(min(recoveryValue - 5, 95)) / 100
    }

    private var targetLoad: ClosedRange<Double> {
        targetPercent.lowerBound * 21...targetPercent.upperBound * 21
    }

    private var aggregatedZones: [HeartRateZoneDuration] {
        (1...5).map { zone in
            HeartRateZoneDuration(
                zone: zone,
                minutes: snapshot.workouts.flatMap(\.zones).filter { $0.zone == zone }.reduce(0) { $0 + $1.minutes }
            )
        }
    }

    /// Clasifica la aptitud cardiorrespiratoria contra FRIEND. `nil` cuando
    /// falta VO2, fecha de nacimiento o sexo de referencia: no adivinamos.
    private var fitnessClassification: FitnessClassification? {
        let profile = profiles.first { $0.setupCompleted }
        let age = profile.map {
            Calendar.current.dateComponents([.year], from: $0.birthDate, to: .now).year ?? 0
        }
        let vo2Samples = orderedWeek.compactMap(\.vo2Max)
        let latest = orderedWeek.last { $0.vo2Max != nil }
        let ageDays = latest?.vo2MaxDate.map {
            Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 999
        } ?? 999
        return FitnessClassificationEngine().classify(
            vo2Max: latest?.vo2Max,
            age: age,
            sex: profile.flatMap { NutritionSex(rawValue: $0.sexOptional) },
            vo2SampleCount: vo2Samples.count,
            vo2AgeDays: ageDays
        )
    }

    /// Que falta para poder clasificar. Orden: perfil, luego VO2.
    private var classificationGap: String {
        let profile = profiles.first { $0.setupCompleted }
        guard let profile else {
            return "Completa tu perfil (fecha de nacimiento y sexo de referencia) para comparar tu VO2 max con las tablas FRIEND."
        }
        let sex = NutritionSex(rawValue: profile.sexOptional)
        if sex != .male && sex != .female {
            return "Selecciona un sexo de referencia en tu perfil: las tablas FRIEND publican percentiles separados por sexo."
        }
        let age = Calendar.current.dateComponents([.year], from: profile.birthDate, to: .now).year ?? 0
        if age < 20 || age > 79 {
            return "Las tablas FRIEND publican percentiles de 20 a 79 anos. Fuera de ese rango no extrapolamos."
        }
        if orderedWeek.last(where: { $0.vo2Max != nil }) == nil {
            return "Necesitamos una estimacion de VO2 max en Apple Health. Se genera con caminatas, carreras o senderismo al aire libre."
        }
        return "Faltan datos para clasificar tu aptitud cardiorrespiratoria."
    }

    private var advice: DetailAdvice {
        insightEngine.strainAdvice(
            strainScore: score.value,
            recoveryScore: recovery?.value ?? 58,
            snapshot: snapshot,
            history: orderedWeek
        )
    }

    var body: some View {
        DetailScaffold(title: "Strain", symbol: "flame.fill", color: ScoreKind.strain.color, identifier: "detail.strain") {
            Button {
                Haptics.soft()
                metricKey = MetricSelection(key: "strainScore")
            } label: {
                DetailHero(
                    title: "Strain",
                    date: snapshot.date,
                    score: score,
                    valueText: String(format: "%.1f", loadValue(score.value)),
                    unitText: "/21",
                    statusText: String(format: "Objetivo de hoy %.1f–%.1f", targetLoad.lowerBound, targetLoad.upperBound),
                    targetBand: targetPercent
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.strain.scoreCard")

            DetailStatStrip(stats: [
                DetailStat(label: "Duracion", value: snapshot.workoutMinutes.map { "\(Int($0)) min" } ?? "0 min", icon: "stopwatch.fill", color: ScoreKind.strain.color),
                DetailStat(label: "Energia activa", value: snapshot.activeEnergy.map { "\(Int($0)) kcal" } ?? "Sin dato", icon: "flame.fill", color: ScoreKind.energy.color)
            ])

            DetailAdviceCard(
                advice: advice,
                color: ScoreKind.strain.color,
                icon: "scope",
                identifier: "detail.strain.advice"
            )

            // Clasificacion de aptitud contra percentiles FRIEND publicados.
            // Si faltan datos mostramos que falta, en vez de ocultar la seccion.
            if let classification = fitnessClassification {
                FitnessClassCard(classification: classification)
            } else {
                FitnessClassPlaceholder(reason: classificationGap)
            }

            DetailSectionTitle(title: "Timeline", detail: "\(snapshot.workouts.count) ACTIVIDADES")
            workoutTimeline

            DetailSectionTitle(title: "Zonas cardiacas", detail: "DISTRIBUCION DE HOY")
            zonesCard

            calibrationCard

            DetailSectionTitle(title: "Tendencias", detail: "TOCA PARA VER EL DETALLE")
            strainTrendCards
            DataProvenanceCard(snapshot: snapshot, color: ScoreKind.strain.color)

            CaveatFootnote(text: "Strain estima carga cardiovascular con actividad, energia y zonas de FC. No predice lesiones ni sustituye la percepcion de esfuerzo, dolor, enfermedad o indicaciones profesionales.")
        }
        .sheet(item: $metricKey) { selection in
            MetricDetailView(
                descriptors: StrainMetricCatalog.descriptors(),
                series: { descriptor in
                    if descriptor.key == "strainScore" { return strainScoreSeries }
                    return StrainMetricCatalog.series(for: descriptor, history: orderedWeek)
                },
                selectedKey: selection.key
            )
        }
    }

    /// Serie historica de Strain en escala /21, usando solo dias anteriores
    /// para el baseline (misma regla que Recovery: sin mirar el futuro).
    private var strainScoreSeries: [MetricPoint] {
        orderedWeek.compactMap { day in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = scoreEngine.scores(for: day, history: history).first(where: { $0.kind == .strain })?.value
            else { return nil }
            return MetricPoint(date: day.date, value: loadValue(value))
        }
    }

    private var workoutTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snapshot.workouts.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.title2)
                        .foregroundStyle(ScoreKind.strain.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sin workouts registrados").font(.headline)
                        Text("Los pasos y la energia activa siguen aportando a tu carga diaria.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(Array(snapshot.workouts.enumerated()), id: \.element.id) { index, workout in
                    HStack(alignment: .top, spacing: 13) {
                        VStack(spacing: 0) {
                            Circle().fill(zoneColor(4)).frame(width: 11, height: 11)
                            if index < snapshot.workouts.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 65)
                            }
                        }
                        .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.activityName).font(.headline)
                                    Text("\(timeText(workout.startDate))–\(timeText(workout.endDate)) · \(workout.sourceName)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", workout.cardiovascularLoad))
                                    .font(.title3.weight(.bold)).monospacedDigit()
                                    .foregroundStyle(ScoreKind.strain.color)
                            }
                            HStack(spacing: 12) {
                                Label("\(Int(workout.durationMinutes)) min", systemImage: "stopwatch")
                                if let average = workout.averageHeartRate {
                                    Label("\(Int(average)) bpm", systemImage: "heart.fill")
                                }
                                if let energy = workout.activeEnergy {
                                    Label("\(Int(energy)) kcal", systemImage: "flame.fill")
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.strain.timeline")
    }

    private var zonesCard: some View {
        let total = aggregatedZones.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: 13) {
            if total > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        ForEach(aggregatedZones) { zone in
                            Rectangle()
                                .fill(zoneColor(zone.zone))
                                .frame(width: max(proxy.size.width * zone.minutes / total - 3, 2))
                        }
                    }
                }
                .frame(height: 14)

                ForEach(aggregatedZones) { zone in
                    HStack(spacing: 10) {
                        Text("Z\(zone.zone)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(zoneColor(zone.zone))
                            .frame(width: 24, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule().fill(zoneColor(zone.zone)).frame(width: proxy.size.width * zone.minutes / max(total, 0.1))
                            }
                        }
                        .frame(height: 7)
                        Text("\(Int(zone.minutes)) min")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                        Text("\(Int(zone.minutes / total * 100))%")
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            } else {
                Label("No hay muestras de FC suficientes para calcular zonas hoy.", systemImage: "heart.slash")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
    }

    private var calibrationCard: some View {
        let days = min(orderedWeek.count, 14)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Calibracion del objetivo", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.strain.color)
                Spacer()
                Text("\(days)/14 dias").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(days), total: 14)
                .tint(ScoreKind.strain.color)
            Text("El rango combina tu Recovery actual con la carga reciente. Mejora al reunir dias comparables; no es una cuota que debas alcanzar si no te sientes bien.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
    }

    @ViewBuilder
    private var strainTrendCards: some View {
        let strainPoints = orderedWeek.compactMap { day -> DetailPoint? in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = scoreEngine.scores(for: day, history: history).first(where: { $0.kind == .strain })?.value
            else { return nil }
            return DetailPoint(date: day.date, value: loadValue(value))
        }
        tappableTrendCard(key: "strainScore", title: "Strain", icon: "flame.fill", values: strainPoints, current: loadValue(score.value), unit: "/21", decimals: 1, color: ScoreKind.strain.color)
        tappableTrendCard(key: "workoutMinutes", title: "Duracion", icon: "stopwatch.fill", values: points(\.workoutMinutes), current: snapshot.workoutMinutes, unit: "min", decimals: 0, color: .cyan)
        tappableTrendCard(key: "activeEnergy", title: "Energia activa", icon: "bolt.fill", values: points(\.activeEnergy), current: snapshot.activeEnergy, unit: "kcal", decimals: 0, color: ScoreKind.energy.color)
        let stepPoints = orderedWeek.compactMap { day in day.steps.map { DetailPoint(date: day.date, value: Double($0)) } }
        tappableTrendCard(key: "steps", title: "Pasos", icon: "figure.walk", values: stepPoints, current: snapshot.steps.map(Double.init), unit: "", decimals: 0, color: ScoreKind.recovery.color)
    }

    private func points(_ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> [DetailPoint] {
        orderedWeek.compactMap { day in day[keyPath: keyPath].map { DetailPoint(date: day.date, value: $0) } }
    }

    private func tappableTrendCard(key: String, title: String, icon: String, values: [DetailPoint], current: Double?, unit: String, decimals: Int, color: Color) -> some View {
        Button {
            Haptics.soft()
            metricKey = MetricSelection(key: key)
        } label: {
            let raw = values.map(\.value)
            let band = personalBand(raw)
            let typical = median(raw)
            DetailTrendCard(
                title: title,
                icon: icon,
                valueText: current.map { number($0, decimals: decimals, unit: unit) } ?? "Sin dato",
                typicalText: typical.map { "Tipico \(number($0, decimals: decimals, unit: unit))" } ?? "Baseline pendiente",
                status: detailStatus(current: current, band: band, higherIsBetter: true),
                points: values,
                band: band,
                color: color
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.strain.metric.\(key)")
    }

    private func loadValue(_ percentage: Int) -> Double { Double(percentage) / 100 * 21 }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: .gray
        case 2: .cyan
        case 3: ScoreKind.recovery.color
        case 4: ScoreKind.energy.color
        default: ScoreKind.strain.color
        }
    }
}

// MARK: - Energy

struct EnergyDetailView: View {
    let score: WellnessScore
    let scores: [WellnessScore]
    let snapshot: DailyHealthSnapshot
    let week: [DailyHealthSnapshot]
    /// Metrica abierta en el detalle (patron Bevel).
    @State private var metricKey: MetricSelection?
    private let scoreEngine = ScoreEngine()
    private let insightEngine = InsightEngine()
    private var orderedWeek: [DailyHealthSnapshot] { week.sorted { $0.date < $1.date } }

    private func scoreValue(_ kind: ScoreKind) -> Int {
        scores.first { $0.kind == kind }?.value ?? 0
    }

    private var advice: DetailAdvice {
        insightEngine.energyAdvice(score: score.value, scores: scores, snapshot: snapshot)
    }

    var body: some View {
        DetailScaffold(title: "Energia", symbol: "bolt.fill", color: ScoreKind.energy.color, identifier: "detail.energy") {
            Button {
                Haptics.soft()
                metricKey = MetricSelection(key: "energyScore")
            } label: {
                DetailHero(
                    title: "Energia",
                    date: snapshot.date,
                    score: score,
                    valueText: "\(score.value)",
                    unitText: "%",
                    statusText: score.summary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.energy.scoreCard")

            DetailStatStrip(stats: [
                DetailStat(label: "Recovery", value: "\(scoreValue(.recovery))%", icon: "heart.fill", color: ScoreKind.recovery.color),
                DetailStat(label: "Sleep", value: "\(scoreValue(.sleep))%", icon: "moon.fill", color: ScoreKind.sleep.color)
            ])

            DetailAdviceCard(
                advice: advice,
                color: ScoreKind.energy.color,
                icon: "bolt.heart.fill",
                identifier: "detail.energy.advice"
            )

            DetailSectionTitle(title: "Balance del dia", detail: "SENALES DISPONIBLES")
            contributorsCard
            contextCard
            daylightAndCaffeineCard

            DetailSectionTitle(title: "Tendencias", detail: "TOCA PARA VER EL DETALLE")
            energyTrendCards
            DataProvenanceCard(snapshot: snapshot, color: ScoreKind.energy.color)

            CaveatFootnote(text: "Energia es hoy una estimacion diaria de capacidad basada en Recovery, Sleep y Strain. La luz diurna y la cafeina dan contexto medido; no representan una bateria fisiologica ni una curva intradia de carga y descarga.")
        }
        .sheet(item: $metricKey) { selection in
            MetricDetailView(
                descriptors: EnergyMetricCatalog.descriptors(),
                series: { descriptor in
                    if descriptor.key == "energyScore" { return energyScoreSeries }
                    if descriptor.key == "recoveryScore" { return scoreSeries(for: .recovery) }
                    if descriptor.key == "sleepScore" { return scoreSeries(for: .sleep) }
                    if descriptor.key == "strainScore" { return scoreSeries(for: .strain) }
                    return EnergyMetricCatalog.series(for: descriptor, history: orderedWeek)
                },
                selectedKey: selection.key
            )
        }
    }

    private var energyScoreSeries: [MetricPoint] { scoreSeries(for: .energy) }

    private func scoreSeries(for kind: ScoreKind) -> [MetricPoint] {
        orderedWeek.compactMap { day in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = scoreEngine.scores(for: day, history: history).first(where: { $0.kind == kind })?.value
            else { return nil }
            return MetricPoint(date: day.date, value: Double(value))
        }
    }

    private var contributorsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            signalBar(name: "Recovery", detail: "Aporta capacidad", value: scoreValue(.recovery), color: ScoreKind.recovery.color, icon: "heart.fill")
            signalBar(name: "Sleep", detail: "Restaura capacidad", value: scoreValue(.sleep), color: ScoreKind.sleep.color, icon: "moon.fill")
            signalBar(name: "Strain", detail: "Consume margen", value: scoreValue(.strain), color: ScoreKind.strain.color, icon: "flame.fill")
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.energy.contributors")
    }

    private func signalBar(name: String, detail: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(name, systemImage: icon).font(.subheadline.weight(.semibold)).foregroundStyle(color)
                Spacer()
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                Text("\(value)").font(.subheadline.weight(.bold)).monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(color.gradient).frame(width: proxy.size.width * Double(value) / 100)
                }
            }
            .frame(height: 8)
        }
    }

    private var contextCard: some View {
        HStack(spacing: 0) {
            tappableContextMetric(key: "activeEnergy", icon: "bolt.fill", value: snapshot.activeEnergy.map { "\(Int($0))" } ?? "—", label: "kcal activas", color: ScoreKind.energy.color)
            Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 52)
            tappableContextMetric(key: "workoutMinutes", icon: "figure.run", value: snapshot.workoutMinutes.map { "\(Int($0))" } ?? "0", label: "min workout", color: ScoreKind.strain.color)
            Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 52)
            tappableContextMetric(key: "steps", icon: "figure.walk", value: snapshot.steps?.formatted() ?? "—", label: "pasos", color: ScoreKind.recovery.color)
        }
        .padding(.vertical, 16)
        .liquidGlass(cornerRadius: 8)
        .accessibilityIdentifier("detail.energy.context")
    }

    private func tappableContextMetric(key: String, icon: String, value: String, label: String, color: Color) -> some View {
        Button {
            Haptics.soft()
            metricKey = MetricSelection(key: key)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(color)
                Text(value).font(.title3.weight(.bold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.energy.context.\(key)")
    }

    /// Luz diurna y cafeina: ya las leemos de HealthKit; en Energia aportan
    /// contexto circadiano y de estimulantes sin inventar senales nuevas.
    @ViewBuilder
    private var daylightAndCaffeineCard: some View {
        let hasDaylight = snapshot.daylightMinutes != nil
        let hasCaffeine = snapshot.dietaryCaffeineMg != nil
        if hasDaylight || hasCaffeine {
            HStack(spacing: 0) {
                if hasDaylight {
                    tappableContextMetric(
                        key: "daylight",
                        icon: "sun.max.fill",
                        value: snapshot.daylightMinutes.map { "\(Int($0))" } ?? "—",
                        label: "min luz dia",
                        color: ScoreKind.energy.color
                    )
                }
                if hasDaylight && hasCaffeine {
                    Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 52)
                }
                if hasCaffeine {
                    tappableContextMetric(
                        key: "caffeine",
                        icon: "cup.and.saucer.fill",
                        value: snapshot.dietaryCaffeineMg.map { "\(Int($0))" } ?? "—",
                        label: "mg cafeina",
                        color: .cyan
                    )
                }
            }
            .padding(.vertical, 16)
            .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
            .accessibilityIdentifier("detail.energy.circadian")
        }
    }

    @ViewBuilder
    private var energyTrendCards: some View {
        tappableScoreTrendCard(key: "energyScore", kind: .energy, color: ScoreKind.energy.color)
        tappableTrendCard(
            key: "activeEnergy",
            title: "Energia activa",
            icon: "bolt.fill",
            values: orderedWeek.compactMap { day in day.activeEnergy.map { DetailPoint(date: day.date, value: $0) } },
            current: snapshot.activeEnergy,
            unit: "kcal",
            higherIsBetter: true,
            decimals: 0,
            color: ScoreKind.energy.color
        )
        let stepPoints = orderedWeek.compactMap { day in day.steps.map { DetailPoint(date: day.date, value: Double($0)) } }
        tappableTrendCard(
            key: "steps",
            title: "Pasos",
            icon: "figure.walk",
            values: stepPoints,
            current: snapshot.steps.map(Double.init),
            unit: "",
            higherIsBetter: true,
            decimals: 0,
            color: ScoreKind.recovery.color
        )
        tappableTrendCard(
            key: "daylight",
            title: "Luz diurna",
            icon: "sun.max.fill",
            values: orderedWeek.compactMap { day in day.daylightMinutes.map { DetailPoint(date: day.date, value: $0) } },
            current: snapshot.daylightMinutes,
            unit: "min",
            higherIsBetter: true,
            decimals: 0,
            color: ScoreKind.energy.color
        )
        tappableScoreTrendCard(key: "recoveryScore", kind: .recovery, color: ScoreKind.recovery.color)
        tappableScoreTrendCard(key: "sleepScore", kind: .sleep, color: ScoreKind.sleep.color)
        tappableScoreTrendCard(key: "strainScore", kind: .strain, color: ScoreKind.strain.color)
    }

    private func tappableScoreTrendCard(key: String, kind: ScoreKind, color: Color) -> some View {
        let points = orderedWeek.compactMap { day -> DetailPoint? in
            let history = orderedWeek.filter { $0.date < day.date }
            guard let value = scoreEngine.scores(for: day, history: history).first(where: { $0.kind == kind })?.value
            else { return nil }
            return DetailPoint(date: day.date, value: Double(value))
        }
        return tappableTrendCard(
            key: key,
            title: kind.rawValue,
            icon: kind.icon,
            values: points,
            current: Double(scoreValue(kind)),
            unit: "%",
            higherIsBetter: kind != .strain,
            decimals: 0,
            color: color
        )
    }

    private func tappableTrendCard(
        key: String,
        title: String,
        icon: String,
        values: [DetailPoint],
        current: Double?,
        unit: String,
        higherIsBetter: Bool,
        decimals: Int,
        color: Color
    ) -> some View {
        Button {
            Haptics.soft()
            metricKey = MetricSelection(key: key)
        } label: {
            let raw = values.map(\.value)
            let band = personalBand(raw)
            let typical = median(raw)
            DetailTrendCard(
                title: title,
                icon: icon,
                valueText: current.map { number($0, decimals: decimals, unit: unit) } ?? "Sin dato",
                typicalText: typical.map { "Tipico \(number($0, decimals: decimals, unit: unit))" } ?? "Baseline pendiente",
                status: detailStatus(current: current, band: band, higherIsBetter: higherIsBetter),
                points: values,
                band: band,
                color: color
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.energy.metric.\(key)")
    }
}

// MARK: - Formatting and personal ranges

private func median(_ values: [Double]) -> Double? {
    BaselineEngine().median(values)
}

private func personalBand(_ values: [Double]) -> ClosedRange<Double>? {
    BaselineEngine().personalBand(values)
}

private func detailStatus(current: Double?, band: ClosedRange<Double>?, higherIsBetter: Bool) -> DetailStatus {
    guard let current else { return DetailStatus(text: "Sin dato", color: .gray) }
    guard let band else { return DetailStatus(text: "Construyendo baseline", color: ScoreKind.energy.color) }
    if band.contains(current) { return DetailStatus(text: "En tu rango", color: ScoreKind.recovery.color) }
    if current > band.upperBound {
        return DetailStatus(text: "Sobre tu rango", color: higherIsBetter ? ScoreKind.recovery.color : ScoreKind.strain.color)
    }
    return DetailStatus(text: "Bajo tu rango", color: higherIsBetter ? ScoreKind.strain.color : ScoreKind.recovery.color)
}

private func number(_ value: Double, decimals: Int, unit: String) -> String {
    let formatted = String(format: "%.*f", decimals, value)
    return unit.isEmpty ? formatted : "\(formatted) \(unit)"
}

private func hoursText(_ hours: Double) -> String {
    let safe = max(hours, 0)
    let h = Int(safe)
    let m = Int(((safe - Double(h)) * 60).rounded())
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

private func signedHours(_ hours: Double) -> String {
    let sign = hours > 0 ? "+" : hours < 0 ? "−" : ""
    return "\(sign)\(hoursText(abs(hours)))"
}

private func timeText(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
}

// MARK: - Detalle de metrica (patron Bevel `mainmetrics_bevel.mp4`)

/// Identifica la metrica abierta en un sheet. Wrapper propio para no conformar
/// `String` a `Identifiable` de forma retroactiva.
struct MetricSelection: Identifiable, Equatable {
    let key: String
    var id: String { key }
}

/// Pantalla de detalle de UNA metrica, replicando la estructura de Bevel:
/// valor grande + rango normal · chips de metricas hermanas · grafico con banda
/// y promedio · selector de ventana · Trends Analysis · Resources.
///
/// Es el mismo componente para Sleep, Recovery, Strain y Stress: se alimenta de
/// un `MetricDescriptor` y un proveedor de series, asi cada seccion solo declara
/// sus metricas.
struct MetricDetailView: View {
    let descriptors: [MetricDescriptor]
    /// Serie completa por metrica (se recorta segun la ventana elegida).
    let series: (MetricDescriptor) -> [MetricPoint]
    @State var selectedKey: String
    @State private var window: MetricWindow = .month
    @Environment(\.dismiss) private var dismiss

    private let trendEngine = MetricTrendEngine()

    /// Nunca indexamos por posicion: `descriptors[0]` haria crash con un
    /// catalogo vacio. Los catalogos reales nunca lo estan, pero preferimos
    /// una pantalla honesta a un crash.
    private var descriptor: MetricDescriptor {
        descriptors.first { $0.key == selectedKey } ?? descriptors.first ?? .unavailable
    }
    private var allPoints: [MetricPoint] { series(descriptor).sorted { $0.date < $1.date } }
    private var windowPoints: [MetricPoint] {
        let start = Calendar.current.date(byAdding: .day, value: -window.days, to: .now) ?? .now
        return allPoints.filter { $0.date > start }
    }
    private var average: Double? { median(windowPoints.map(\.value)) }
    private var band: ClosedRange<Double>? { personalBand(allPoints.map(\.value)) }
    private var current: Double? { allPoints.last?.value }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                LinearGradient(
                    colors: [descriptor.color.opacity(0.18), .clear, .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                StardustField(count: 60)
                    .opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if descriptors.count > 1 { siblingChips }
                        chartCard
                        trendsCard
                        explanationCard
                        if !descriptor.resources.isEmpty { resourcesSection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("metric.detail")
            }
            .navigationTitle(descriptor.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.soft(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .headerCircleChrome(size: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
            }
            .liquidGlassNavigationBar()
        }
    }

    // Valor grande + estado + rango personal, como el encabezado de Bevel.
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(current.map { number($0, decimals: descriptor.decimals, unit: "") } ?? "--")
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if !descriptor.unit.isEmpty {
                    Text(descriptor.unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(status.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status.color)
            }
            HStack(spacing: 8) {
                Text(allPoints.last?.date.formatted(
                    .dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "es_MX"))
                ) ?? "Sin dato")
                if let band {
                    Text("·")
                    Image(systemName: "chart.bar.fill").font(.caption2)
                    Text("\(number(band.lowerBound, decimals: descriptor.decimals, unit: "")) - \(number(band.upperBound, decimals: descriptor.decimals, unit: descriptor.unit))")
                        .monospacedDigit()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("metric.detail.header")
    }

    private var status: DetailStatus {
        detailStatus(current: current, band: band, higherIsBetter: descriptor.higherIsBetter)
    }

    /// Chips de metricas hermanas: permiten saltar sin volver atras (Bevel).
    private var siblingChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(descriptors) { item in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.22)) { selectedKey = item.key }
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(item.key == selectedKey ? .bold : .medium))
                            .foregroundStyle(item.key == selectedKey ? .primary : .secondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background {
                                Capsule().fill(item.key == selectedKey
                                    ? AnyShapeStyle(item.color.opacity(0.22))
                                    : AnyShapeStyle(Color.white.opacity(0.06)))
                            }
                            .overlay {
                                Capsule().strokeBorder(
                                    item.key == selectedKey ? item.color.opacity(0.5) : .clear,
                                    lineWidth: 1
                                )
                            }
                            .tappableCapsule()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("metric.sibling.\(item.key)")
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("metric.detail.siblings")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if windowPoints.count > 1 {
                metricChart
            } else {
                Text("Aun no hay suficientes puntos en esta ventana.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            windowPicker
            if let note = coverageNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: descriptor.color)
        .accessibilityIdentifier("metric.detail.chart")
    }

    /// Recvel lee 30 dias de Apple Health, asi que las ventanas mas largas no
    /// tienen mas datos que mostrar. Lo decimos en vez de dejar creer que ese
    /// es todo tu historial.
    private var coverageNote: String? {
        guard window.days > 30, let first = allPoints.first else { return nil }
        let covered = Calendar.current.dateComponents([.day], from: first.date, to: .now).day ?? 0
        guard covered < window.days - 5 else { return nil }
        return "Recvel lee los ultimos 30 dias de Apple Health. Esta ventana muestra los \(max(covered, 1)) dias con datos, no un hueco en tu historial."
    }

    private var metricChart: some View {
        Chart {
            if let band {
                RectangleMark(
                    yStart: .value("Min", band.lowerBound),
                    yEnd: .value("Max", band.upperBound)
                )
                .foregroundStyle(descriptor.color.opacity(0.10))
            }
            if let average {
                RuleMark(y: .value("Promedio", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(descriptor.color.opacity(0.7))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Prom. \(number(average, decimals: descriptor.decimals, unit: descriptor.unit))")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(descriptor.color.opacity(0.22)))
                    }
            }
            ForEach(windowPoints) { point in
                AreaMark(x: .value("Fecha", point.date), y: .value("Valor", point.value))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [descriptor.color.opacity(0.26), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Fecha", point.date), y: .value("Valor", point.value))
                    .foregroundStyle(descriptor.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
            }
            if let last = windowPoints.last {
                PointMark(x: .value("Fecha", last.date), y: .value("Valor", last.value))
                    .foregroundStyle(.white)
                    .symbolSize(60)
            }
        }
        .chartYAxis { AxisMarks(position: .trailing) }
        .chartXAxis { AxisMarks(preset: .aligned) }
        .frame(height: 200)
        .animation(.snappy(duration: 0.3), value: selectedKey)
    }

    private var windowPicker: some View {
        HStack(spacing: 6) {
            ForEach(MetricWindow.allCases) { item in
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.24)) { window = item }
                } label: {
                    Text(item.rawValue)
                        .font(.caption.weight(window == item ? .bold : .medium))
                        .foregroundStyle(window == item ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            Capsule().fill(window == item
                                ? AnyShapeStyle(descriptor.color.opacity(0.22))
                                : AnyShapeStyle(Color.clear))
                        }
                        .tappableCapsule()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("metric.window.\(item.rawValue)")
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    /// Tabla "Trends Analysis" de Bevel: cambio por ventana + sparkline.
    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(title: "Analisis de tendencia", detail: "vs periodo anterior")
            VStack(spacing: 0) {
                ForEach(trendEngine.rows(for: allPoints)) { row in
                    trendRow(row)
                    if row.days != MetricTrendEngine.windows.last {
                        Divider().overlay(Color.white.opacity(0.07))
                    }
                }
            }
            .padding(.vertical, 4)
            .liquidGlass(cornerRadius: 16)
        }
        .accessibilityIdentifier("metric.detail.trends")
    }

    private func trendRow(_ row: MetricTrendRow) -> some View {
        let tolerance = max(abs(average ?? 1) * 0.02, 0.05)
        let direction = trendEngine.direction(
            change: row.change,
            higherIsBetter: descriptor.higherIsBetter,
            tolerance: tolerance
        )
        return HStack(spacing: 12) {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)
            HStack(spacing: 5) {
                Image(systemName: directionSymbol(direction))
                    .font(.caption.weight(.bold))
                Text(row.change.map { changeText($0) } ?? "Sin dato")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(directionColor(direction))
            Spacer(minLength: 6)
            if row.points.count > 1 {
                sparkline(row.points, color: directionColor(direction))
                    .frame(width: 74, height: 26)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func sparkline(_ values: [Double], color: Color) -> some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("i", index), y: .value("v", value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.4))
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func changeText(_ change: Double) -> String {
        let sign = change > 0 ? "+" : ""
        return "\(sign)\(number(change, decimals: descriptor.decimals, unit: descriptor.unit))"
    }

    private func directionSymbol(_ direction: MetricTrendDirection) -> String {
        switch direction {
        case .improving: "arrow.up.right"
        case .declining: "arrow.down.right"
        case .steady: "arrow.right"
        case .unknown: "minus"
        }
    }

    private func directionColor(_ direction: MetricTrendDirection) -> Color {
        switch direction {
        case .improving: ScoreKind.recovery.color
        case .declining: ScoreKind.strain.color
        case .steady: .secondary
        case .unknown: .gray
        }
    }

    private var explanationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: descriptor.symbol)
                .font(.headline)
                .foregroundStyle(descriptor.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text("Que es \(descriptor.title)")
                    .font(.subheadline.weight(.bold))
                Text(descriptor.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .liquidGlass(cornerRadius: 16, tint: descriptor.color)
    }

    /// "Resources" de Bevel: articulos educativos por metrica.
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionTitle(title: "Recursos", detail: "con evidencia citada")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(descriptor.resources) { resource in
                        NavigationLink {
                            MetricResourceView(resource: resource, color: descriptor.color)
                        } label: {
                            MetricResourceCard(resource: resource, color: descriptor.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("metric.detail.resources")
    }
}

private struct MetricResourceCard: View {
    let resource: MetricResource
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: resource.symbol)
                .font(.title3)
                .foregroundStyle(color)
            Spacer(minLength: 4)
            Text(resource.title)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            Text(resource.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 158, height: 118, alignment: .leading)
        .padding(14)
        .liquidGlass(cornerRadius: 16, tint: color)
    }
}

private struct MetricResourceView: View {
    let resource: MetricResource
    let color: Color

    var body: some View {
        ZStack {
            AppBackground()
            StardustField(count: 50).opacity(0.6).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: resource.symbol)
                        .font(.system(size: 34))
                        .foregroundStyle(color)
                    Text(resource.title)
                        .font(.title2.weight(.bold))
                    Text(resource.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Divider().overlay(Color.white.opacity(0.1))
                    Text(resource.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Recurso")
        .navigationBarTitleDisplayMode(.inline)
        .liquidGlassNavigationBar()
    }
}

/// Tarjeta de coaching de sueno. Siempre muestra la evidencia detras del
/// consejo (plegable) para no dar instrucciones sin respaldo.
private struct SleepCoachingCard: View {
    let tip: SleepCoachingTip
    @State private var showEvidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: tip.symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title).font(.subheadline.weight(.bold))
                    Text(tip.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Haptics.soft()
                withAnimation(.snappy(duration: 0.24)) { showEvidence.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "text.book.closed")
                    Text(showEvidence ? "Ocultar evidencia" : "Ver evidencia")
                    Image(systemName: showEvidence ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
                .tappableRounded(6)
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
        .padding(15)
        .liquidGlass(cornerRadius: 16, tint: accent)
        .accessibilityIdentifier("sleep.coaching.\(tip.kind.rawValue)")
    }

    private var accent: Color {
        tip.kind == .positive ? ScoreKind.recovery.color : ScoreKind.sleep.color
    }
}

// MARK: - Catalogo de metricas de sueno (alimenta MetricDetailView)

enum SleepMetricCatalog {
    static func descriptors() -> [MetricDescriptor] {
        [
            MetricDescriptor(
                key: "sleepScore", title: "Sleep Score", symbol: "moon.stars.fill",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Resume la noche en un solo numero combinando duracion, composicion por etapas y consistencia de horario. Es una herramienta de tendencia: un numero aislado importa menos que hacia donde va.",
                resources: [
                    MetricResource(
                        title: "Que es el Sleep Score",
                        subtitle: "Como se calcula",
                        symbol: "function",
                        body: """
                        El Sleep Score de Recvel condensa tu noche en un valor de 0 a 100 a partir de tres bloques:

                        · Duracion. El consenso de la American Academy of Sleep Medicine y la Sleep Research Society situa 7 h o mas por noche para adultos como el rango asociado con mejores resultados de salud.

                        · Composicion por etapas. En adultos, el sueno profundo (ondas lentas) ocupa tipicamente entre 13% y 23% de la noche, y el REM entre 20% y 25%. Desviaciones grandes y sostenidas son mas informativas que una sola noche.

                        · Consistencia. La regularidad del horario predice la calidad del sueno de forma independiente a la duracion (Phillips et al., Scientific Reports 2017).

                        Limite importante: las etapas provienen de la estimacion del reloj, no de polisomnografia. Su exactitud para clasificar etapas especificas es moderada, por eso Recvel muestra composicion agregada y no reconstruye un hipnograma minuto a minuto.
                        """
                    ),
                    MetricResource(
                        title: "Como mejorar tu score",
                        subtitle: "Intervenciones con respaldo",
                        symbol: "sparkles",
                        body: """
                        Las intervenciones con mejor respaldo, en orden de evidencia:

                        1. Horario constante. Acostarte y levantarte a la misma hora, incluso en fin de semana, refuerza la senal circadiana. La irregularidad se asocia de forma independiente con peor calidad y con riesgo cardiometabolico (Huang & Redline, Diabetes Care 2019).

                        2. Control de estimulos. Usar la cama solo para dormir y levantarte si no concilias en unos 20 minutos son componentes centrales de la terapia cognitivo-conductual para el insomnio (CBT-I), que la AASM recomienda como primera linea, por delante de la medicacion.

                        3. Luz de dia temprano. La exposicion a luz brillante por la manana adelanta la fase circadiana y ayuda a conciliar antes.

                        4. Cortar cafeina temprano. La cafeina tiene una vida media de unas 5-6 h y puede reducir el sueno total aun tomada 6 h antes de acostarse (Drake et al., J Clin Sleep Med 2013).

                        5. Cuidado con el alcohol. Acorta la latencia pero suprime el REM y fragmenta la segunda mitad de la noche (Ebrahim et al., Alcohol Clin Exp Res 2013).
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "timeAsleep", title: "Tiempo dormido", symbol: "moon.fill",
                unit: "h", decimals: 1, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Horas efectivamente dormidas, sin contar el tiempo en cama despierto. Es la senal con mas respaldo de todas las del sueno.",
                resources: [
                    MetricResource(
                        title: "Cuanto sueno necesitas",
                        subtitle: "El consenso y sus matices",
                        symbol: "bed.double.fill",
                        body: """
                        La American Academy of Sleep Medicine y la Sleep Research Society recomiendan 7 h o mas por noche de forma regular para adultos de 18 a 60 anos. Dormir menos de 7 h de forma habitual se asocia con peores resultados cardiometabolicos, inmunes y cognitivos.

                        El rango es un consenso poblacional, no una receta individual: la necesidad real varia entre personas (tipicamente 7-9 h). Por eso la meta en Recvel es ajustable.

                        Un matiz que suele perderse: en la restriccion cronica de sueno, el deterioro del rendimiento se acumula noche a noche aunque la sensacion subjetiva de somnolencia se estabilice. Es decir, te acostumbras a sentirte cansado, pero tu rendimiento sigue cayendo (Van Dongen et al., Sleep 2003).
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "sleepBank", title: "Sleep Bank", symbol: "banknote",
                unit: "h", decimals: 1, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Balance acumulado de horas por encima o por debajo de tu meta en los ultimos 14 dias. Positivo es superavit; negativo es deuda.",
                resources: [
                    MetricResource(
                        title: "Deuda de sueno",
                        subtitle: "Que se puede y que no se puede recuperar",
                        symbol: "creditcard",
                        body: """
                        La deuda de sueno es la diferencia acumulada entre lo que duermes y lo que tu cuerpo necesita. Convencionalmente se mide en ventanas de 7 a 14 dias; Recvel usa 14 para capturar el patron semanal completo, fin de semana incluido.

                        Que dice la evidencia sobre recuperarla:

                        · Tras una semana de restriccion, 2-3 noches de sueno de recuperacion restauran la alerta subjetiva y parte del rendimiento, pero el tiempo de reaccion y algunos marcadores metabolicos tardan mas.

                        · El sueno de recuperacion de fin de semana compensa PARCIALMENTE la deuda entre semana, pero no restaura del todo la funcion cognitiva ni la salud metabolica en la mayoria de las personas.

                        Por eso Recvel nunca dice que "saldaste" tu deuda: la analogia bancaria es util para visualizar, pero el cuerpo no funciona exactamente como una cuenta. Sumar 30-60 min por noche de forma sostenida rinde mas que una sola noche larga.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "deep", title: "Sueno profundo", symbol: "moon.zzz.fill",
                unit: "h", decimals: 1, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Sueno de ondas lentas, asociado con recuperacion fisica y consolidacion de memoria. Se concentra en la primera mitad de la noche. Es una estimacion del reloj, no polisomnografia.",
                resources: []
            ),
            MetricDescriptor(
                key: "rem", title: "Sueno REM", symbol: "brain.head.profile",
                unit: "h", decimals: 1, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Fase asociada con consolidacion de memoria emocional y procedimental. Se concentra en la segunda mitad de la noche, por eso acortar el final de la noche recorta REM de forma desproporcionada.",
                resources: []
            ),
            MetricDescriptor(
                key: "efficiency", title: "Eficiencia", symbol: "gauge.with.dots.needle.67percent",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Proporcion del tiempo en cama que pasaste dormido. Por debajo de ~85% suele indicar tiempo en cama despierto, el objetivo central del control de estimulos en CBT-I.",
                resources: []
            ),
            MetricDescriptor(
                key: "latency", title: "Latencia", symbol: "hourglass",
                unit: "min", decimals: 0, higherIsBetter: false, color: ScoreKind.sleep.color,
                explanation: "Cuanto tardas en conciliar el sueno. Una latencia muy corta de forma constante puede ser senal de deuda de sueno, no de buen dormir.",
                resources: []
            ),
            MetricDescriptor(
                key: "consistency", title: "Consistencia", symbol: "clock.arrow.2.circlepath",
                unit: "min", decimals: 0, higherIsBetter: false, color: ScoreKind.sleep.color,
                explanation: "Cuanto varia tu horario de sueno. La regularidad predice la calidad de forma independiente a la duracion.",
                resources: []
            )
        ]
    }

    /// Serie historica por metrica, a partir del historial de snapshots.
    static func series(for descriptor: MetricDescriptor, history: [DailyHealthSnapshot], goalHours: Double) -> [MetricPoint] {
        switch descriptor.key {
        case "timeAsleep":
            return history.compactMap { day in day.sleepHours.map { MetricPoint(date: day.date, value: $0) } }
        case "sleepBank":
            // Balance RODANTE de 14 dias en cada fecha: la misma ventana que usa
            // la tarjeta, para que el ultimo punto de la serie coincida con el
            // numero grande. Acumular todo el historial daba dos valores
            // distintos para el mismo "Sleep Bank".
            let bankEngine = SleepBankEngine()
            return history.compactMap { day -> MetricPoint? in
                guard day.sleepHours != nil else { return nil }
                let result = bankEngine.assess(history: history, goalHours: goalHours, now: day.date)
                guard result.nights > 0 else { return nil }
                return MetricPoint(date: day.date, value: result.balanceHours)
            }
        case "deep":
            return history.compactMap { day in day.sleepDetails.map { MetricPoint(date: day.date, value: $0.deepHours) } }
        case "rem":
            return history.compactMap { day in day.sleepDetails.map { MetricPoint(date: day.date, value: $0.remHours) } }
        case "efficiency":
            return history.compactMap { day in day.sleepDetails?.efficiency.map { MetricPoint(date: day.date, value: $0) } }
        case "latency":
            return history.compactMap { day in day.sleepDetails?.latencyMinutes.map { MetricPoint(date: day.date, value: $0) } }
        case "consistency":
            return history.compactMap { day in day.sleepDetails?.consistencyMinutes.map { MetricPoint(date: day.date, value: $0) } }
        default:
            return []
        }
    }
}

// MARK: - Catalogo de metricas de Recovery

enum RecoveryMetricCatalog {
    static func descriptors() -> [MetricDescriptor] {
        [
            MetricDescriptor(
                key: "recoveryScore", title: "Recovery", symbol: "heart.fill",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.recovery.color,
                explanation: "Resume que tan listo esta tu cuerpo para asumir carga, comparando tus senales de hoy contra TU baseline personal, no contra una poblacion.",
                resources: [
                    MetricResource(
                        title: "Que es el Recovery Score",
                        subtitle: "Que entra y que no",
                        symbol: "function",
                        body: """
                        El Recovery de Recvel compara las senales de hoy con tu propio rango reciente. Las senales que pesan:

                        · HRV (variabilidad de la frecuencia cardiaca). Refleja el balance del sistema nervioso autonomo. Una HRV mas alta que tu rango suele indicar mejor disposicion. Es muy individual: comparar tu HRV con la de otra persona no informa nada; comparar tu HRV con la tuya de la semana pasada, si.

                        · FC en reposo. Sube con estres, enfermedad, alcohol, calor y sueno insuficiente.

                        · Sueno. Duracion y calidad de la noche previa.

                        · Frecuencia respiratoria. Muy estable en condiciones normales, por eso una desviacion sostenida es informativa.

                        · SpO2 y temperatura de muneca como contexto adicional.

                        Recovery es una herramienta de bienestar y tendencia. No diagnostica fatiga, enfermedad ni capacidad deportiva.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "hrv", title: "HRV", symbol: "waveform.path.ecg",
                unit: "ms", decimals: 0, higherIsBetter: true, color: ScoreKind.recovery.color,
                explanation: "Variacion en el tiempo entre latidos. Refleja el tono del sistema nervioso autonomo. Es una senal muy personal: solo tiene sentido compararla contra tu propio baseline.",
                resources: [
                    MetricResource(
                        title: "Como leer tu HRV",
                        subtitle: "Por que tu numero no se compara",
                        symbol: "waveform.path.ecg.rectangle",
                        body: """
                        La HRV mide la variacion en los intervalos entre latidos consecutivos. Una HRV mas alta se asocia con un sistema nervioso autonomo mas adaptable.

                        Lo que casi nadie explica: el rango normal entre personas es enorme (puede ir de 20 a 200 ms segun edad, genetica y metodo de medicion). Por eso comparar tu HRV con la de otra persona no dice nada util. Lo informativo es tu tendencia contra tu propio baseline.

                        Que la baja de forma tipica: alcohol (efecto marcado la misma noche), enfermedad, sueno insuficiente, entrenamiento intenso reciente, calor y estres psicologico.

                        Nota de medicion: Apple Watch reporta SDNN en mediciones puntuales, principalmente durante periodos de calma. No es lo mismo que el RMSSD nocturno que usan las bandas de pecho, asi que los valores absolutos no son comparables entre dispositivos.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "rhr", title: "FC en reposo", symbol: "heart.fill",
                unit: "bpm", decimals: 0, higherIsBetter: false, color: .cyan,
                explanation: "Latidos por minuto en reposo completo. Sube con estres, enfermedad, alcohol, calor y sueno insuficiente. Una FC en reposo mas baja suele acompanar mejor aptitud cardiorrespiratoria.",
                resources: []
            ),
            MetricDescriptor(
                key: "respiratory", title: "Respiracion", symbol: "lungs.fill",
                unit: "rpm", decimals: 1, higherIsBetter: false, color: Color(red: 0.35, green: 0.72, blue: 0.95),
                explanation: "Respiraciones por minuto durante el sueno. Es notablemente estable noche a noche, por eso una desviacion sostenida suele ser mas informativa que en otras senales.",
                resources: []
            ),
            MetricDescriptor(
                key: "spo2", title: "Saturacion de oxigeno", symbol: "drop.degreesign.fill",
                unit: "%", decimals: 1, higherIsBetter: true, color: Color(red: 0.45, green: 0.65, blue: 1.0),
                explanation: "Porcentaje de hemoglobina saturada de oxigeno. En el reloj es una lectura de bienestar sujeta a ajuste, movimiento, perfusion y tono de piel: usa la tendencia del mismo dispositivo, no el valor puntual.",
                resources: [
                    MetricResource(
                        title: "SpO2 en la muneca",
                        subtitle: "Que puedes y que no puedes concluir",
                        symbol: "drop.degreesign",
                        body: """
                        La SpO2 estima el porcentaje de hemoglobina que lleva oxigeno. En una persona sana a nivel del mar suele situarse entre 95% y 100%, y desciende con la altitud.

                        Limites que importan de verdad:

                        · El sensor del reloj es un oximetro de reflectancia en la muneca, no de transmision en el dedo como los clinicos. Es mas sensible al ajuste de la correa, al movimiento y a la perfusion.

                        · La oximetria de pulso puede sobrestimar la saturacion real en personas con piel mas oscura, un sesgo documentado tambien en oximetros clinicos (Sjoding et al., NEJM 2020). Es una limitacion de la tecnologia, no del reloj en particular.

                        · Apple declara explicitamente que no es un dispositivo medico y no debe usarse para diagnostico.

                        Como usarlo bien: mira la tendencia de tus propias lecturas nocturnas con el mismo dispositivo. Una caida sostenida frente a tu patron habitual es motivo para consultar a un profesional, nunca para autodiagnosticarte.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "wristTemperature", title: "Temperatura de muneca", symbol: "thermometer.medium",
                unit: "°C", decimals: 1, higherIsBetter: false, color: ScoreKind.energy.color,
                explanation: "Temperatura de la piel de la muneca medida SOLO mientras duermes. No es temperatura corporal ni un termometro: lo informativo es la desviacion frente a tu baseline personal.",
                resources: [
                    MetricResource(
                        title: "Temperatura de muneca",
                        subtitle: "Para que sirve y para que no",
                        symbol: "thermometer.variable",
                        body: """
                        Apple Watch (Series 8 y posteriores) mide la temperatura de la PIEL de tu muneca mientras duermes. Necesita unas 5 noches para establecer tu baseline, y a partir de ahi reporta desviaciones, no valores absolutos.

                        Donde SI tiene evidencia:

                        · Deteccion pre-sintomatica de enfermedad. Es su uso mas validado: una desviacion sostenida por encima de tu baseline, mantenida varias noches, precedio enfermedad confirmada por 1-2 dias en cerca del 75% de los casos en un estudio con datos continuos de temperatura de 47,000 participantes.

                        · Fase lutea del ciclo menstrual. El aumento de progesterona tras la ovulacion eleva la temperatura de forma sostenida (~0.2-0.5 °C) hasta la menstruacion.

                        Donde NO sirve, y por que Recvel no la usa ahi:

                        · Para detectar episodios de ansiedad o estres agudo. Apple solo registra esta senal MIENTRAS DUERMES: no existe una lectura diurna continua. Los estudios que detectan estres por temperatura usan sensores de investigacion con registro continuo, y aun asi es la senal con menos validacion: la relacion entre lo que mide un termistor de muneca y el estado fisiologico es indirecta y muy dependiente del contexto (ejercicio, ambiente, alcohol, ciclo menstrual).

                        Por eso esta metrica vive en Recovery y no en Stress. Es contexto de termorregulacion y carga, no un detector de emociones.

                        Apple declara que la funcion no es un dispositivo medico y no sirve para diagnostico.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "timeAsleep", title: "Tiempo dormido", symbol: "moon.fill",
                unit: "h", decimals: 1, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Horas dormidas la noche previa. Es uno de los factores con mas peso sobre tu disposicion del dia siguiente.",
                resources: []
            )
        ]
    }

    static func series(for descriptor: MetricDescriptor, history: [DailyHealthSnapshot]) -> [MetricPoint] {
        switch descriptor.key {
        case "hrv":
            return history.compactMap { day in day.hrv.map { MetricPoint(date: day.date, value: $0) } }
        case "rhr":
            return history.compactMap { day in day.restingHeartRate.map { MetricPoint(date: day.date, value: $0) } }
        case "respiratory":
            return history.compactMap { day in day.respiratoryRate.map { MetricPoint(date: day.date, value: $0) } }
        case "spo2":
            return history.compactMap { day in
                day.oxygenSaturation.map { MetricPoint(date: day.date, value: $0 <= 1 ? $0 * 100 : $0) }
            }
        case "wristTemperature":
            return history.compactMap { day in day.wristTemperature.map { MetricPoint(date: day.date, value: $0) } }
        case "timeAsleep":
            return history.compactMap { day in day.sleepHours.map { MetricPoint(date: day.date, value: $0) } }
        default:
            return []
        }
    }
}

// MARK: - Catalogo de metricas de Strain

enum StrainMetricCatalog {
    static func descriptors() -> [MetricDescriptor] {
        [
            MetricDescriptor(
                key: "strainScore", title: "Strain", symbol: "flame.fill",
                unit: "/21", decimals: 1, higherIsBetter: true, color: ScoreKind.strain.color,
                explanation: "Estima la carga cardiovascular del dia a partir de energia activa, workouts y zonas de frecuencia cardiaca. Se expresa en una escala 0-21 comparable dia a dia.",
                resources: [
                    MetricResource(
                        title: "Que es el Strain",
                        subtitle: "Carga, no rendimiento",
                        symbol: "function",
                        body: """
                        El Strain de Recvel resume cuanto estres cardiovascular acumulo tu dia. Combina:

                        · Energia activa (kcal) relativa a tu baseline personal.
                        · Minutos de workout y, cuando hay datos, tiempo en zonas de FC.

                        Un Strain alto no es "mejor" ni "peor" por si solo: lo informativo es si encaja con tu Recovery de hoy. Un dia de carga alta tras Recovery bajo suele ser mala idea; el mismo Strain tras Recovery alto puede ser el objetivo.

                        Limite: no predice lesiones, no sustituye RPE ni dolor, y depende de que el reloj registre bien FC y workouts.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "workoutMinutes", title: "Duracion", symbol: "stopwatch.fill",
                unit: "min", decimals: 0, higherIsBetter: true, color: .cyan,
                explanation: "Minutos de workouts registrados hoy. Es una senal de volumen, no de intensidad: 60 min de caminata no equivalen a 60 min de intervalos.",
                resources: []
            ),
            MetricDescriptor(
                key: "activeEnergy", title: "Energia activa", symbol: "bolt.fill",
                unit: "kcal", decimals: 0, higherIsBetter: true, color: ScoreKind.energy.color,
                explanation: "Kilocalorias quemadas por encima del metabolismo basal segun Apple Health. Es una de las senales con mas peso en Strain.",
                resources: [
                    MetricResource(
                        title: "Energia activa vs total",
                        subtitle: "Que mide el reloj",
                        symbol: "flame.fill",
                        body: """
                        Apple Health separa energia activa (movimiento) de energia basal (reposo). Recvel usa la activa porque refleja esfuerzo voluntario y es la que mas se mueve dia a dia.

                        La estimacion depende del modelo de reloj, del ajuste y de si llevas el dispositivo. Compara tu tendencia, no el numero absoluto con el de otra persona.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "steps", title: "Pasos", symbol: "figure.walk",
                unit: "", decimals: 0, higherIsBetter: true, color: ScoreKind.recovery.color,
                explanation: "Conteo diario de pasos. Util como senal de movimiento espontaneo, pero no mide intensidad: muchos pasos lentos no equivalen a Strain alto.",
                resources: []
            )
        ]
    }

    static func series(for descriptor: MetricDescriptor, history: [DailyHealthSnapshot]) -> [MetricPoint] {
        switch descriptor.key {
        case "workoutMinutes":
            return history.compactMap { day in day.workoutMinutes.map { MetricPoint(date: day.date, value: $0) } }
        case "activeEnergy":
            return history.compactMap { day in day.activeEnergy.map { MetricPoint(date: day.date, value: $0) } }
        case "steps":
            return history.compactMap { day in day.steps.map { MetricPoint(date: day.date, value: Double($0)) } }
        default:
            return []
        }
    }
}

// MARK: - Catalogo de metricas de Energia

enum EnergyMetricCatalog {
    static func descriptors() -> [MetricDescriptor] {
        [
            MetricDescriptor(
                key: "energyScore", title: "Energia", symbol: "bolt.fill",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.energy.color,
                explanation: "Estimacion diaria de margen disponible a partir de Recovery, Sleep y Strain. No es una bateria fisiologica medida minuto a minuto.",
                resources: [
                    MetricResource(
                        title: "Como se estima la Energia",
                        subtitle: "Capacidad, no calorias",
                        symbol: "function",
                        body: """
                        Recvel combina tres scores que ya calculas:

                        · Recovery (mayor peso): cuanto margen tienes para asumir carga.
                        · Sleep: restauracion de la noche previa.
                        · Strain (resta): carga ya consumida hoy.

                        Ademas mostramos contexto medido que no entra en la formula pero si importa para la alerta subjetiva: luz diurna (ancla circadiana) y cafeina si la registras en Apple Health.

                        Limite: no hay curva intradia tipo "Energy Bank" continuo porque no inventamos descarga por hora sin senales temporales densas y validadas.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "activeEnergy", title: "Energia activa", symbol: "bolt.fill",
                unit: "kcal", decimals: 0, higherIsBetter: true, color: ScoreKind.energy.color,
                explanation: "Kilocalorias de movimiento del dia. Suben el Strain y, por tanto, reducen el margen de Energia estimado.",
                resources: []
            ),
            MetricDescriptor(
                key: "steps", title: "Pasos", symbol: "figure.walk",
                unit: "", decimals: 0, higherIsBetter: true, color: ScoreKind.recovery.color,
                explanation: "Movimiento espontaneo del dia. Complementa la energia activa cuando no hay workouts formales.",
                resources: []
            ),
            MetricDescriptor(
                key: "workoutMinutes", title: "Minutos de workout", symbol: "figure.run",
                unit: "min", decimals: 0, higherIsBetter: true, color: ScoreKind.strain.color,
                explanation: "Duracion acumulada de sesiones registradas. Aporta volumen a la carga del dia.",
                resources: []
            ),
            MetricDescriptor(
                key: "daylight", title: "Luz diurna", symbol: "sun.max.fill",
                unit: "min", decimals: 0, higherIsBetter: true, color: ScoreKind.energy.color,
                explanation: "Minutos de exposicion a luz diurna medidos por el reloj (timeInDaylight). La luz de dia ancla el ritmo circadiano y se asocia con mejor alerta; no es un suplemento de calorias.",
                resources: [
                    MetricResource(
                        title: "Luz diurna y alerta",
                        subtitle: "Por que aparece en Energia",
                        symbol: "sun.max.fill",
                        body: """
                        La exposicion a luz brillante durante el dia refuerza el ritmo circadiano y mejora la alerta subjetiva en adultos sanos. Estudios de laboratorio muestran que la luz diurna (frente a luz tenue) adelanta y estabiliza la fase circadiana (Wright et al., Current Biology 2013).

                        Apple Watch estima minutos al aire libre / luz diurna (`timeInDaylight`). Es una proxy, no un luxometro clinico: depende de llevar el reloj y de la calibracion del sensor.

                        Recvel la muestra como contexto de Energia, no como peso inventado en el score: aporta senal util sin fingir una bateria fisiologica.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "caffeine", title: "Cafeina", symbol: "cup.and.saucer.fill",
                unit: "mg", decimals: 0, higherIsBetter: false, color: .cyan,
                explanation: "Cafeina dietetica registrada en Apple Health. La vida media tipica es de 5-6 h: ayuda a la alerta a corto plazo, pero puede restar sueno si llega tarde.",
                resources: [
                    MetricResource(
                        title: "Cafeina y energia percibida",
                        subtitle: "Estimulante, no combustible",
                        symbol: "cup.and.saucer.fill",
                        body: """
                        La cafeina bloquea receptores de adenosina y aumenta la alerta percibida. No anade "energia metabolica": redistribuye la sensacion de fatiga.

                        Evidencia practica: 400 mg/dia suele ser el techo tolerado en adultos sanos (FDA). Tomada 6 h antes de acostarse puede reducir el sueno total (Drake et al., J Clin Sleep Med 2013).

                        Solo aparece si hay registros en Apple Health (apps de nutricion, registro manual). Recvel no inventa dosis.
                        """
                    )
                ]
            ),
            MetricDescriptor(
                key: "recoveryScore", title: "Recovery", symbol: "heart.fill",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.recovery.color,
                explanation: "Aporta la mayor parte de la capacidad estimada de Energia.",
                resources: []
            ),
            MetricDescriptor(
                key: "sleepScore", title: "Sleep", symbol: "moon.fill",
                unit: "%", decimals: 0, higherIsBetter: true, color: ScoreKind.sleep.color,
                explanation: "Restauracion de la noche previa. Sin sueno suficiente, el margen de Energia cae aunque el Strain sea bajo.",
                resources: []
            ),
            MetricDescriptor(
                key: "strainScore", title: "Strain", symbol: "flame.fill",
                unit: "%", decimals: 0, higherIsBetter: false, color: ScoreKind.strain.color,
                explanation: "Carga ya consumida hoy. Resta margen a la Energia estimada.",
                resources: []
            )
        ]
    }

    static func series(for descriptor: MetricDescriptor, history: [DailyHealthSnapshot]) -> [MetricPoint] {
        switch descriptor.key {
        case "activeEnergy":
            return history.compactMap { day in day.activeEnergy.map { MetricPoint(date: day.date, value: $0) } }
        case "steps":
            return history.compactMap { day in day.steps.map { MetricPoint(date: day.date, value: Double($0)) } }
        case "workoutMinutes":
            return history.compactMap { day in day.workoutMinutes.map { MetricPoint(date: day.date, value: $0) } }
        case "daylight":
            return history.compactMap { day in day.daylightMinutes.map { MetricPoint(date: day.date, value: $0) } }
        case "caffeine":
            return history.compactMap { day in day.dietaryCaffeineMg.map { MetricPoint(date: day.date, value: $0) } }
        default:
            return []
        }
    }
}

// MARK: - Clasificacion de rendimiento (FRIEND)

/// Tarjeta compacta de "tipo de entrenamiento". Toca para ver por que.
/// Se apoya en `FitnessClassificationEngine` (percentiles FRIEND publicados).
struct FitnessClassCard: View {
    let classification: FitnessClassification
    @State private var showDetail = false

    var body: some View {
        Button {
            Haptics.soft()
            showDetail = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(accent.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: classification.fitnessClass.symbol)
                        .font(.headline)
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("TIPO DE ENTRENAMIENTO")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text(classification.fitnessClass.rawValue)
                        .font(.title3.weight(.bold))
                    Text("Percentil \(Int(classification.percentile.rounded())) · \(classification.ageGroup) anos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 16, tint: accent)
            .tappableRounded(16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.strain.fitnessClass")
        .sheet(isPresented: $showDetail) {
            FitnessClassDetailView(classification: classification)
        }
    }

    private var accent: Color {
        switch classification.fitnessClass {
        case .elite, .high: ScoreKind.recovery.color
        case .good, .average: ScoreKind.energy.color
        case .low, .sedentary: ScoreKind.strain.color
        }
    }
}

/// Explica POR QUE caes en tu categoria: tu percentil, la escala completa, la
/// distancia al siguiente escalon y los limites del metodo.
struct FitnessClassDetailView: View {
    let classification: FitnessClassification
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                LinearGradient(colors: [accent.opacity(0.18), .clear, .clear], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                StardustField(count: 60).opacity(0.7).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        scaleCard
                        if let next = classification.nextClass, let target = classification.vo2ForNextClass {
                            nextStepCard(next: next, target: target)
                        }
                        methodCard
                        limitsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("detail.fitnessClass")
            }
            .navigationTitle("Tipo de entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Haptics.soft(); dismiss() } label: {
                        Image(systemName: "xmark").font(.subheadline.weight(.bold)).headerCircleChrome(size: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
            }
            .liquidGlassNavigationBar()
        }
    }

    private var accent: Color {
        switch classification.fitnessClass {
        case .elite, .high: ScoreKind.recovery.color
        case .good, .average: ScoreKind.energy.color
        case .low, .sedentary: ScoreKind.strain.color
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.14)).frame(width: 76, height: 76)
                Image(systemName: classification.fitnessClass.symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(accent)
            }
            Text(classification.fitnessClass.rawValue)
                .font(.system(size: 28, weight: .bold))
            Text(classification.fitnessClass.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                statBlock("VO2 max", String(format: "%.1f", classification.vo2Max), "ml/kg/min")
                statBlock("Percentil", "\(Int(classification.percentile.rounded()))", "de 100")
                statBlock("Tu grupo", classification.ageGroup, "anos")
            }
            .padding(.top, 4)
            HStack(spacing: 5) {
                Circle()
                    .fill(classification.confidence == .medium ? ScoreKind.energy.color : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("Confianza \(classification.confidence.rawValue.lowercased()) · estimacion del reloj")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .liquidGlass(cornerRadius: 16, tint: accent)
        .accessibilityElement(children: .combine)
    }

    private func statBlock(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.bold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(unit).font(.system(size: 8)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Escala completa con tu posicion marcada.
    private var scaleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Donde caes en la escala")
                .font(.subheadline.weight(.bold))
            ForEach(FitnessClass.allCases) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.symbol)
                        .font(.caption)
                        .foregroundStyle(item == classification.fitnessClass ? accent : .secondary)
                        .frame(width: 20)
                    Text(item.rawValue)
                        .font(.subheadline.weight(item == classification.fitnessClass ? .bold : .regular))
                        .foregroundStyle(item == classification.fitnessClass ? .primary : .secondary)
                    Spacer()
                    Text(percentileRange(for: item))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(item == classification.fitnessClass
                            ? AnyShapeStyle(accent)
                            : AnyShapeStyle(.tertiary))
                    if item == classification.fitnessClass {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(accent)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 16)
    }

    private func percentileRange(for item: FitnessClass) -> String {
        let ordered = FitnessClass.allCases.sorted { $0.minimumPercentile > $1.minimumPercentile }
        guard let index = ordered.firstIndex(of: item) else { return "" }
        let lower = Int(item.minimumPercentile)
        if index == 0 { return "P\(lower)+" }
        let upper = Int(ordered[index - 1].minimumPercentile)
        return "P\(lower)-\(upper)"
    }

    private func nextStepCard(next: FitnessClass, target: Double) -> some View {
        let gap = target - classification.vo2Max
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "target").foregroundStyle(ScoreKind.energy.color)
                Text("Siguiente escalon: \(next.rawValue)")
                    .font(.subheadline.weight(.bold))
            }
            Text(String(format: "Necesitas un VO2 max de %.1f ml/kg/min (te faltan %.1f).", target, max(gap, 0)))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Lo que mas mueve el VO2 max en la literatura es el entrenamiento interválico de alta intensidad combinado con volumen aeróbico constante. Los cambios se miden en meses, no en semanas.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: ScoreKind.energy.color)
    }

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "function").foregroundStyle(.cyan)
                Text("Como se calcula").font(.subheadline.weight(.bold))
            }
            Text("""
            Tu VO2 max se compara contra las tablas de percentiles del registro FRIEND (Fitness Registry and the Importance of Exercise National Database), especificamente las de prueba en treadmill de Kaminsky et al., Mayo Clinic Proceedings 2015: 4,611 hombres y 3,172 mujeres con ergoespirometria maxima.

            La publicacion reporta los percentiles 5, 10, 25, 50, 75, 90 y 95 por decada de edad y sexo. Recvel interpola entre esos valores para ubicar el tuyo. Tu grupo de referencia es \(classification.ageGroup) anos, cuya mediana es \(String(format: "%.1f", classification.groupMedian)) ml/kg/min.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: .cyan)
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill").foregroundStyle(ScoreKind.energy.color)
                Text("Limites honestos").font(.subheadline.weight(.bold))
            }
            Text("""
            · Los nombres de las categorias son una decision de producto sobre percentiles publicados. FRIEND reporta los percentiles pero NO define categorias como "atleta" o "sedentario": no es una clasificacion clinica ni deportiva oficial.

            · FRIEND mide VO2 con ergoespirometria maxima en laboratorio. Tu Apple Watch lo ESTIMA a partir de caminatas y carreras al aire libre, con un error tipico mayor. Por eso la confianza nunca es alta con una sola lectura.

            · La muestra de FRIEND es mayoritariamente estadounidense y puede no representar a toda la poblacion.

            · Esto es informacion de bienestar y tendencia. No es una evaluacion medica ni una prescripcion de entrenamiento.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 16, tint: ScoreKind.energy.color)
    }
}

/// Estado vacio de la clasificacion: decimos QUE falta en vez de ocultar la
/// seccion, para que el feature sea descubrible sin adivinar datos.
private struct FitnessClassPlaceholder: View {
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: "figure.run.circle")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("TIPO DE ENTRENAMIENTO")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text("Sin clasificar todavia")
                    .font(.subheadline.weight(.bold))
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail.strain.fitnessClass.empty")
    }
}
