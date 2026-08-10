import SwiftData
import SwiftUI

// MARK: - Entrypoint

/// Fila "Ver insights" del detalle de Recuperación, calcada de la referencia
/// (`Recovery_insigths.mp4`, fotograma t=0 s): sparkle + texto + flecha en una
/// superficie plana.
struct RecoveryInsightsEntryRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ScoreKind.recovery.color)
                Text(RecvelL10n.text("insights.viewEntry"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .revelSurface(cornerRadius: 16)
        .accessibilityIdentifier("detail.recovery.insightsEntry")
    }
}

// MARK: - Pantalla

/// Insights de Recuperación con la gramática visual de Bevel: qué señales y
/// conductas se asocian con el score, en barras divergentes desde el centro.
///
/// Estructura de la referencia (16 fotogramas, `ffmpeg fps=1.5`):
///  · cabecera con eyebrow "✦ Insights" + título + descripción,
///  · escala Negativo / Impacto / Positivo,
///  · filas con icono + conducta + valor a la derecha y barra divergente,
///  · sección de baja confianza y "Locked tags" con progreso ✗/✓ hacia 5+5.
///
/// Diferencias deliberadas con Bevel: el impacto se expresa en **puntos** del
/// score (no "%", aunque numéricamente coincidan) y cada nivel de confianza
/// declara su criterio en pantalla. Asociaciones, nunca causalidad.
struct RecoveryInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HabitLog.date, order: .reverse) private var logs: [HabitLog]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]
    @Query(sort: \JournalTagConfiguration.updatedAt, order: .reverse) private var configurations: [JournalTagConfiguration]

    let snapshot: DailyHealthSnapshot
    let history: [DailyHealthSnapshot]

    private let scoreEngine = ScoreEngine()
    private let calendar = Calendar.current

    /// Se calcula una vez al aparecer: `behaviorImpacts` recalcula ~30 scores
    /// y no debe vivir en `body`.
    @State private var insights: RecoveryInsights?

    var body: some View {
        ZStack {
            LabBackdropLite(tint: ScoreKind.recovery.color)
                .ignoresSafeArea()

            WidthLockedScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    scaleLegend

                    section(
                        title: RecvelL10n.text("insights.today.title"),
                        caption: RecvelL10n.text("common.vsPersonalBaselineLower")
                    ) {
                        todayRows
                    }

                    if let insights {
                        if !insights.confident.isEmpty {
                            section(
                                title: RecvelL10n.text("insights.behaviors.title"),
                                caption: RecvelL10n.text("insights.behaviors.caption")
                            ) {
                                ForEach(insights.confident) { impactRow($0) }
                            }
                        }

                        if !insights.lowConfidence.isEmpty {
                            section(
                                title: RecvelL10n.text("insights.lowConfidence.title"),
                                caption: RecvelL10n.text("insights.lowConfidence.caption")
                            ) {
                                ForEach(insights.lowConfidence) { impactRow($0) }
                            }
                        }

                        if !insights.locked.isEmpty {
                            section(
                                title: RecvelL10n.text("insights.locked.title"),
                                caption: nil,
                                footnote: RecvelL10n.text("insights.locked.caption")
                            ) {
                                ForEach(insights.locked) { lockedRow($0) }
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }

                    Text(RecvelL10n.text("insights.disclaimer"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard insights == nil else { return }
            insights = computeInsights()
        }
        .accessibilityIdentifier("recovery.insights")
    }

    // MARK: Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(RecvelL10n.text("common.close"))
            }

            Label(RecvelL10n.text("insights.eyebrow").uppercased(), systemImage: "sparkles")
                .font(.system(size: 11, weight: .black))
                .kerning(1.4)
                .foregroundStyle(ScoreKind.recovery.color)
            Text(ScoreKind.recovery.displayName)
                .font(.system(size: 30, weight: .bold))
            Text(RecvelL10n.text("insights.recovery.description"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    /// Escala Negativo / Impacto / Positivo de la referencia.
    private var scaleLegend: some View {
        HStack {
            Text(RecvelL10n.text("insights.negative"))
                .font(.caption.weight(.bold))
                .foregroundStyle(ScoreKind.strain.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ScoreKind.strain.color.opacity(0.14), in: Capsule())
            Spacer()
            Text(RecvelL10n.text("insights.impactPts"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(RecvelL10n.text("insights.positive"))
                .font(.caption.weight(.bold))
                .foregroundStyle(ScoreKind.recovery.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ScoreKind.recovery.color.opacity(0.14), in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RecvelL10n.text("insights.scale.a11y"))
    }

    // MARK: Secciones

    @ViewBuilder
    private func section(
        title: String,
        caption: String?,
        footnote: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LabSectionHeader(title: title, caption: caption, tint: ScoreKind.recovery.color)
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    /// Señales de hoy: los factores del score con su contribución −1…1, más
    /// los ajustes de contexto cuando hoy restaron puntos.
    @ViewBuilder
    private var todayRows: some View {
        let factors = scoreEngine.factors(for: snapshot, history: history)
        ForEach(factors) { factor in
            InsightImpactRowView(
                symbol: factor.icon,
                title: factor.name,
                subtitle: factor.baseline,
                valueText: factor.value,
                fraction: factor.contribution,
                valueColor: color(for: factor.contribution)
            )
        }
        let adjustments = scoreEngine.recoveryAdjustments(for: snapshot, history: history)
        if adjustments.priorLoad != 0 {
            InsightImpactRowView(
                symbol: "figure.run.square.stack",
                title: RecvelL10n.text("insights.priorLoad"),
                subtitle: RecvelL10n.text("insights.priorLoad.caption"),
                valueText: RecvelL10n.text("insights.pts", values: ["value": "\(adjustments.priorLoad)"]),
                fraction: Double(adjustments.priorLoad) / ScoreEngine.maxPriorLoadPenalty,
                valueColor: ScoreKind.strain.color
            )
        }
        if adjustments.sustainedSuppression != 0 {
            InsightImpactRowView(
                symbol: "chart.line.downtrend.xyaxis",
                title: RecvelL10n.text("insights.sustained"),
                subtitle: RecvelL10n.text("insights.sustained.caption"),
                valueText: RecvelL10n.text("insights.pts", values: ["value": "\(adjustments.sustainedSuppression)"]),
                fraction: Double(adjustments.sustainedSuppression) / ScoreEngine.maxSustainedSuppressionPenalty,
                valueColor: ScoreKind.strain.color
            )
        }
    }

    private func impactRow(_ row: RecoveryImpactRow) -> some View {
        let delta = row.association.delta ?? 0
        // 15 puntos de score llenan la barra: por encima de eso la asociación
        // ya se lee como "grande" y la barra saturada lo comunica.
        let fraction = min(max(delta / 15, -1), 1)
        return InsightImpactRowView(
            symbol: row.symbol,
            title: row.title,
            subtitle: RecvelL10n.text("insights.sampleCounts", values: [
                "yes": "\(row.association.yesCount)",
                "no": "\(row.association.noCount)"
            ]),
            valueText: RecvelL10n.text("insights.pts", values: [
                "value": String(format: "%+.0f", delta)
            ]),
            fraction: fraction,
            valueColor: color(for: delta)
        )
    }

    /// Tag bloqueado con progreso hacia 5 sí / 5 no, como los contadores
    /// ✗ N | ✓ N de la referencia.
    private func lockedRow(_ row: RecoveryImpactRow) -> some View {
        HStack(spacing: 11) {
            Image(systemName: row.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(row.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            lockedCounter(symbol: "xmark", count: row.association.noCount, tint: ScoreKind.strain.color)
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 16)
            lockedCounter(symbol: "checkmark", count: row.association.yesCount, tint: ScoreKind.recovery.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .revelSurface(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RecvelL10n.text("insights.locked.a11y", values: [
            "tag": row.title,
            "yes": "\(row.association.yesCount)",
            "no": "\(row.association.noCount)",
            "target": "\(JournalImpactEngine.minimumPerGroup)"
        ]))
    }

    private func lockedCounter(symbol: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("\(count)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(count >= JournalImpactEngine.minimumPerGroup ? tint : .secondary)
        }
    }

    private func color(for value: Double) -> Color {
        if abs(value) < 0.001 { return .secondary }
        return value > 0 ? ScoreKind.recovery.color : ScoreKind.strain.color
    }

    // MARK: Datos

    private func computeInsights() -> RecoveryInsights {
        let cutoff = calendar.date(byAdding: .day, value: -RecoveryInsightsEngine.windowDays, to: .now) ?? .now

        let behaviorRows = RecoveryInsightsEngine.behaviorImpacts(history: history, scoreEngine: scoreEngine)

        // Tags manuales del Journal, mismo estadístico que la pantalla de
        // insights del Journal para que las dos cuenten lo mismo.
        let manualTags = enabledManualTags
        let recentLogs = logs.filter { $0.date >= cutoff }
        let recentScores = scoreRecords.filter { $0.date >= cutoff }
        let manualRows = JournalProImpactEngine.impacts(
            tags: manualTags,
            logs: recentLogs,
            scores: recentScores,
            metric: .recovery
        ).compactMap { impact -> RecoveryImpactRow? in
            guard let tag = manualTags.first(where: { $0.id == impact.tagID }) else { return nil }
            return RecoveryImpactRow(
                id: impact.tagID,
                symbol: tag.symbol,
                title: impact.title,
                association: impact.association
            )
        }

        return RecoveryInsightsEngine.assemble(behaviorRows + manualRows)
    }

    private var enabledManualTags: [JournalResolvedTag] {
        let builtIns = JournalCatalog.builtIns.map { definition in
            JournalResolvedTag(definition: definition, configuration: configurations.first { $0.tagID == definition.id })
        }
        let customs = configurations.filter { $0.sourceRaw == JournalTagSource.custom.rawValue }.map { config in
            JournalResolvedTag(
                definition: JournalTagDefinition(
                    config.tagID,
                    config.customTitle ?? RecvelL10n.text("journalPro.customTag"),
                    RecvelL10n.text("journalPro.customEntry"),
                    symbol: config.customSymbol ?? "tag.fill",
                    category: JournalTagCategory(rawValue: config.categoryRaw) ?? .personal,
                    period: JournalTagPeriod(rawValue: config.periodRaw) ?? .daytime,
                    source: .custom,
                    enabled: true
                ),
                configuration: config
            )
        }
        return (builtIns + customs).filter { $0.isEnabled && $0.source != .automatic }
    }
}

// MARK: - Fila de impacto

/// Fila con barra divergente: icono + título a la izquierda, valor coloreado a
/// la derecha y una barra que crece desde el punto central hacia el lado del
/// signo, proporcional a la magnitud.
private struct InsightImpactRowView: View {
    let symbol: String
    let title: String
    var subtitle: String?
    let valueText: String
    /// −1…1. Negativo pinta hacia la izquierda en color de Carga; positivo
    /// hacia la derecha en color de Recuperación.
    let fraction: Double
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.subheadline)
                    .foregroundStyle(valueColor == .secondary ? Color.secondary : valueColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
            }

            DivergingImpactBar(fraction: fraction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .revelSurface(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Barra divergente de la referencia: dos pistas apagadas a los lados de un
/// punto central; el relleno nace en el centro y crece hacia el lado del signo
/// con un degradado que se intensifica con la magnitud.
private struct DivergingImpactBar: View {
    /// −1…1.
    let fraction: Double

    private let trackHeight: CGFloat = 5
    private let dotSize: CGFloat = 9

    var body: some View {
        GeometryReader { proxy in
            let sideWidth = (proxy.size.width - dotSize - 8) / 2
            let magnitude = min(abs(fraction), 1)
            HStack(spacing: 4) {
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.07))
                    if fraction < 0 {
                        Capsule()
                            .fill(negativeGradient(magnitude))
                            .frame(width: max(sideWidth * magnitude, trackHeight))
                    }
                }
                .frame(width: sideWidth, height: trackHeight)

                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: dotColor.opacity(0.55), radius: magnitude > 0.01 ? 4 : 0)

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    if fraction > 0 {
                        Capsule()
                            .fill(positiveGradient(magnitude))
                            .frame(width: max(sideWidth * magnitude, trackHeight))
                    }
                }
                .frame(width: sideWidth, height: trackHeight)
            }
        }
        .frame(height: dotSize)
        .accessibilityHidden(true)
    }

    private var dotColor: Color {
        if abs(fraction) < 0.001 { return Color.white.opacity(0.28) }
        return fraction > 0 ? ScoreKind.recovery.color : ScoreKind.strain.color
    }

    /// Naranja que vira a rosa conforme la magnitud crece, como en Bevel.
    private func negativeGradient(_ magnitude: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.30, blue: 0.55).opacity(0.35 + magnitude * 0.65),
                ScoreKind.strain.color
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func positiveGradient(_ magnitude: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                ScoreKind.recovery.color,
                Color(red: 0.30, green: 0.90, blue: 0.85).opacity(0.35 + magnitude * 0.65)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
