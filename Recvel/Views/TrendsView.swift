import Charts
import SwiftUI

struct TrendsView: View {
    @StateObject private var health = HealthDataProvider()
    private let scoreEngine = ScoreEngine()
    private let baselineEngine = BaselineEngine()

    private var week: [DailyHealthSnapshot] { Array(health.history.suffix(7)) }

    private var recoveryWeek: [(date: Date, value: Int)] {
        week.map { day in
            let value = scoreEngine.scores(for: day, history: health.history).first { $0.kind == .recovery }?.value ?? 0
            return (day.date, value)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TENDENCIAS PERSONALES")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(ScoreKind.recovery.color)
                            Text("7 dias")
                                .font(.system(size: 30, weight: .bold))
                            Text("Tu semana contra el rango que Recvel esta aprendiendo de ti.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        recoveryCard
                        sleepCard
                        hrvCard

                        Text(health.dataMode == .demo
                             ? "Vista demo. Conecta Apple Health desde Hoy para ver tus tendencias."
                             : "Tendencias calculadas localmente con datos de Apple Health.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .trackTabBarScroll()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task { await health.refresh() }
        }
    }

    // Barras coloreadas por valor: verde menta si >= 60, naranja si no
    private var recoveryCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Recovery", systemImage: ScoreKind.recovery.icon)
                        .font(.headline)
                        .foregroundStyle(ScoreKind.recovery.color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                Chart(recoveryWeek, id: \.date) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Recovery", day.value),
                        width: .fixed(14)
                    )
                    .foregroundStyle(
                        (day.value >= 60 ? ScoreKind.recovery.color : ScoreKind.strain.color).gradient
                    )
                    .cornerRadius(7)
                    .annotation(position: .top) {
                        Text("\(day.value)%")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(day.value >= 60 ? ScoreKind.recovery.color : ScoreKind.strain.color)
                    }
                }
                .chartYScale(domain: 0...110)
                .chartYAxis(.hidden)
                .frame(height: 190)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sleepCard: some View {
        LiquidGlassCard(tint: ScoreKind.sleep.color) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Sueno", systemImage: "moon.stars.fill")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.sleep.color)
                Chart(week) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Horas", day.sleepHours ?? 0),
                        width: .fixed(14)
                    )
                    .foregroundStyle(ScoreKind.sleep.color.gradient)
                    .cornerRadius(7)

                    RuleMark(y: .value("Meta", 8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .chartYScale(domain: 0...10)
                .frame(height: 180)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hrvCard: some View {
        let median = baselineEngine.median(week.compactMap(\.hrv)) ?? 0

        return LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("HRV y baseline", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.recovery.color)
                Chart(week) { day in
                    LineMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("HRV", day.hrv ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(ScoreKind.recovery.color)
                    .symbol(.circle)

                    AreaMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("HRV", day.hrv ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ScoreKind.recovery.color.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    RuleMark(y: .value("Baseline", median))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.3))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Tipico \(Int(median)) ms")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                }
                .frame(height: 180)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
