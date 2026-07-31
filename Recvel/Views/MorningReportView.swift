import SwiftUI

// MARK: - Superficie "laboratorio"
//
// Linea visual tomada de la pantalla **Bio Age** de la referencia
// (`Bevel_references/BioAge_revel.mp4`, fotograma t=33 s + `BioAgeScreenBevel.png`,
// medidos con ffmpeg a resolucion nativa 1290x2796):
//  · Fondo casi negro con DOS nebulosas tenues (una fria arriba-izquierda, una
//    calida arriba-derecha) y campo de estrellas de tamaños distintos: unas
//    nitidas, otras desenfocadas tipo bokeh.
//  · Disco interior ELEVADO (mas claro que el fondo) con el brillo cargado arriba.
//  · Surco oscuro con ticks finos y densos alrededor.
//  · Etiquetas rotadas tangencialmente fuera del surco.
//  · Nube de particulas con vida continua sobre el disco.
//
// Animacion: por decision del usuario SOLO se mueve el polvo (nube del hero y
// capa de fondo). Los aros y los mini diales se dibujan estaticos en su valor,
// y no hay punto marcador.
//
// Todo lo de abajo esta escrito desde cero para esta pantalla; no importa nada
// de `BioAgeProViews.swift` ni de `RevelInspiredComponents/`.
private enum LabInk {
    static let baseTop = Color(red: 0.105, green: 0.110, blue: 0.125)
    static let baseBottom = Color(red: 0.043, green: 0.046, blue: 0.056)
    static let panel = Color.white.opacity(0.045)
    static let hairline = Color.white.opacity(0.075)
    static let warn = Color(red: 1.00, green: 0.62, blue: 0.28)
    static let recovery = Color(red: 0.36, green: 0.92, blue: 0.66)
    static let energy = Color(red: 0.98, green: 0.80, blue: 0.35)
    static let sleep = Color(red: 0.62, green: 0.58, blue: 0.99)
    static let load = Color(red: 1.00, green: 0.55, blue: 0.35)
}

/// Reporte del dia: panel de instrumentos que se lee al despertar.
struct MorningReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let report: MorningReport
    var onOpenDay: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        ZStack {
            LabBackdrop()
                .ignoresSafeArea()

            WidthLockedScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    DualDialHero(report: report)

                    module(0, "Índices del día", "los cuatro scores") { indexRow }
                    module(1, "Coaching", "una sola cosa") { coaching }
                    module(2, "Sueño", "noche medida") { sleepPanel }
                    module(3, "Carga", "objetivo adaptable") { loadPanel }
                    if !report.signals.isEmpty {
                        module(4, "Señales de la noche", "lectura · tu rango") { signalsPanel }
                    }
                    if report.stressLevel != nil || !report.emotions.isEmpty {
                        module(5, "Estrés y ánimo", "últimas 24 h") { stressPanel }
                    }
                    if report.fastingHeadline != nil || report.nutritionHeadline != nil {
                        module(6, "Ayuno y nutrición", "plan de hoy") { fuelPanel }
                    }
                    disclaimer
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { footer }
            .overlay(alignment: .topTrailing) { closeButton }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morningReport")
    }

    private var closeButton: some View {
        Button {
            Haptics.soft()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().strokeBorder(LabInk.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
        .padding(.top, 10)
        .accessibilityLabel("Cerrar")
        .accessibilityIdentifier("morningReport.close")
    }

    /// Modulo del panel: micro-encabezado rotulado + contenido, sin caja.
    /// El "instrumento" es la linea, no la tarjeta.
    private func module<Content: View>(
        _ index: Int,
        _ title: String,
        _ caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.4)
                Rectangle()
                    .fill(LabInk.hairline)
                    .frame(height: 1)
                Text(caption.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            content()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 18)
        .animation(
            reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.88)
                .delay(0.16 + Double(index) * 0.06),
            value: appeared
        )
    }

    // MARK: - Índices

    private var indexRow: some View {
        HStack(spacing: 10) {
            MiniGauge(value: report.recoveryValue, label: "Recup.", tint: LabInk.recovery)
            MiniGauge(value: report.sleepValue, label: "Sueño", tint: LabInk.sleep)
            MiniGauge(value: report.energyValue, label: "Energía", tint: LabInk.energy)
            MiniGauge(
                value: report.loadPercentOfTarget,
                label: "Carga",
                tint: report.hasStrainRoom ? LabInk.load : LabInk.warn
            )
        }
        .accessibilityIdentifier("morningReport.indices")
    }

    // MARK: - Coaching

    private var coaching: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.focusTitle)
                .font(.system(size: 19, weight: .semibold))
            Text(report.focusDetail)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.focus")
    }

    // MARK: - Sueño

    private var sleepPanel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                readout(report.sleep.hours.map { String(format: "%.1f", $0) } ?? "—", "h", "Dormido")
                readoutDivider
                readout(report.sleep.efficiency.map { String(format: "%.0f", $0) } ?? "—", "%", "Eficiencia")
                readoutDivider
                readout(
                    report.sleep.bankBalanceHours.map { String(format: "%@%.1f", $0 >= 0 ? "+" : "", $0) } ?? "—",
                    "h",
                    "Banco 14 d",
                    tint: bankTint
                )
            }
            if report.hasSleepTrend {
                NightsChart(values: report.sleepTrendHours, tint: LabInk.sleep, animate: appeared)
                    .frame(height: 54)
            } else {
                Text("El banco necesita 3 noches medidas · llevas \(report.sleep.bankNights)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.sleep")
    }

    private var bankTint: Color {
        guard let balance = report.sleep.bankBalanceHours else { return .white }
        return balance >= 0 ? LabInk.recovery : LabInk.warn
    }

    // MARK: - Carga

    private var loadPanel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                readout(String(format: "%.1f", report.remainingLoad), "", "Disponible",
                        tint: report.hasStrainRoom ? .white : LabInk.warn)
                readoutDivider
                readout(String(format: "%.1f", report.currentLoad), "", "Acumulada")
                readoutDivider
                readout(String(format: "%.1f", report.targetLoad), "", "Objetivo")
            }

            TickBar(
                fraction: appeared || reduceMotion
                    ? min(report.currentLoad / max(report.targetLoad, 0.1), 1)
                    : 0,
                tint: report.hasStrainRoom ? LabInk.load : LabInk.warn
            )
            .frame(height: 22)
            .animation(
                reduceMotion ? nil : .spring(response: 1.0, dampingFraction: 0.9).delay(0.35),
                value: appeared
            )

            if let session = report.plannedSession {
                labRow(icon: "figure.strengthtraining.traditional", caption: "HOY TOCA", value: session)
                    .accessibilityIdentifier("morningReport.plannedSession")
            } else if !report.hasStrainRoom {
                Text("Ya alcanzaste el objetivo de hoy. El resto del día puede enfocarse en recuperar.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.strain")
    }

    // MARK: - Señales fisiológicas

    private var signalsPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(report.signals.enumerated()), id: \.element.id) { index, signal in
                SignalRow(signal: signal, animate: appeared, delay: 0.4 + Double(index) * 0.05)
                if signal.id != report.signals.last?.id {
                    Rectangle().fill(LabInk.hairline).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.signals")
    }

    // MARK: - Estrés y ánimo

    private var stressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let level = report.stressLevel {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LabInk.recovery)
                        .frame(width: 8, height: 8)
                        .shadow(color: LabInk.recovery.opacity(0.8), radius: 4)
                    Text(level)
                        .font(.system(size: 17, weight: .semibold))
                    if let score = report.stressScore {
                        Text("índice \(score)")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
            }
            if !report.emotions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(report.emotions.prefix(4), id: \.self) { emotion in
                        Text(emotion)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.07), in: Capsule())
                            .overlay(Capsule().strokeBorder(LabInk.hairline, lineWidth: 1))
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Sin emociones registradas todavía.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.stress")
    }

    // MARK: - Ayuno y nutrición

    private var fuelPanel: some View {
        VStack(spacing: 12) {
            if let headline = report.fastingHeadline {
                labRow(icon: "timer", caption: "AYUNO", value: headline, detail: report.fastingDetail)
            }
            if report.fastingHeadline != nil && report.nutritionHeadline != nil {
                Rectangle().fill(LabInk.hairline).frame(height: 1)
            }
            if let headline = report.nutritionHeadline {
                labRow(icon: "fork.knife", caption: "NUTRICIÓN", value: headline, detail: report.nutritionDetail)
            }
        }
        .padding(16)
        .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LabInk.hairline, lineWidth: 1)
        }
        .accessibilityIdentifier("morningReport.fuel")
    }

    // MARK: - Piezas compartidas

    private func labRow(icon: String, caption: String, value: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().strokeBorder(LabInk.hairline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func readout(_ value: String, _ unit: String, _ label: String, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.6)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readoutDivider: some View {
        Rectangle().fill(LabInk.hairline).frame(width: 1, height: 34)
    }

    private var disclaimer: some View {
        Text("Estimaciones de bienestar calculadas en tu iPhone con Apple Health y tus rangos personales. No son diagnóstico.")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        Button {
            Haptics.success()
            onOpenDay?()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text("Ver mi día").font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right").font(.footnote.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.white.opacity(0.94), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 34)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [.clear, LabInk.baseBottom.opacity(0.9), LabInk.baseBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .accessibilityIdentifier("morningReport.openDay")
    }
}

// MARK: - Fondo: nebulosa + campo de estrellas

/// Fondo de la referencia: gradiente neutro, dos nebulosas (fria y calida) y
/// estrellas de tamaños distintos, algunas nitidas y otras desenfocadas, que
/// derivan muy despacio y titilan.
private struct LabBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [LabInk.baseTop, LabInk.baseBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color(red: 0.42, green: 0.52, blue: 0.68).opacity(0.20), .clear],
                center: .init(x: 0.18, y: 0.05), startRadius: 8, endRadius: 460
            )
            RadialGradient(
                colors: [Color(red: 0.62, green: 0.56, blue: 0.34).opacity(0.16), .clear],
                center: .init(x: 0.92, y: 0.10), startRadius: 6, endRadius: 380
            )
            RadialGradient(
                colors: [Color(red: 0.30, green: 0.42, blue: 0.55).opacity(0.10), .clear],
                center: .init(x: 0.65, y: 0.62), startRadius: 10, endRadius: 420
            )
            // Las estrellas del fondo NO se animan (ver nota de medicion abajo):
            // se dibujan una sola vez, como textura con profundidad.
            StaticStarField()
            // Lo unico que se mueve en el fondo es una capa de polvo muy tenue.
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                DustLayer(time: context.date.timeIntervalSinceReferenceDate, paused: reduceMotion)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Campo de estrellas ESTATICO.
///
/// Medido sobre el video de referencia (frames a 0.4 s, `PIL` sobre pixeles
/// fijos del fondo): el brillo de un punto del fondo varia **≤3 niveles de 255
/// en 1.6 s** y su posicion no se mueve. O sea: en la referencia el fondo NO
/// titila ni deriva; es textura fija con profundidad. Lo que si tiene vida
/// continua es la nube de particulas del centro (16% de sus pixeles cambian
/// entre frames de 0.4 s). Animar el fondo entero era justo lo que hacia que la
/// pantalla se viera barata.
private struct StaticStarField: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<170 {
                let seed = Double(index)
                let x = fract(sin(seed * 12.9898) * 43_758.5453) * size.width
                let y = fract(sin(seed * 78.233) * 12_345.6789) * size.height
                let roll = fract(seed * 2.7182)

                if roll > 0.955 {
                    // Bokeh: disco grande y difuso, como los de la referencia.
                    let radius = 7 + fract(seed * 5.5) * 12
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(0.085), .clear]),
                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius
                        )
                    )
                } else if roll > 0.86 {
                    // Estrella con halo suave.
                    let radius = 1.5 + fract(seed * 4.1) * 0.9
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius * 3, y: y - radius * 3, width: radius * 6, height: radius * 6)),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(0.16), .clear]),
                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius * 3
                        )
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(0.62))
                    )
                } else {
                    let radius = 0.6 + fract(seed * 9.3) * 0.7
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(0.18 + fract(seed * 5.7) * 0.22))
                    )
                }
            }
        }
        .drawingGroup()
    }

    private func fract(_ value: Double) -> Double { value - value.rounded(.down) }
}

/// Polvo en suspension: pocas motas, muy tenues, con deriva lentisima y
/// respiracion de opacidad. Da vida al fondo sin convertirlo en ruido.
private struct DustLayer: View {
    let time: TimeInterval
    let paused: Bool

    var body: some View {
        Canvas { context, size in
            for index in 0..<26 {
                let seed = Double(index)
                let baseX = fract(sin(seed * 33.17) * 9_871.23) * size.width
                let baseY = fract(sin(seed * 51.71) * 4_517.91) * size.height
                let speed = 3.5 + fract(seed * 2.3) * 5.5          // px/s
                let sway = sin(time * (0.12 + fract(seed * 1.7) * 0.15) + seed) * 14
                let y = paused ? baseY : (baseY - time * speed).truncatingRemainder(dividingBy: size.height)
                let wrapped = y < 0 ? y + size.height : y
                let breath = paused ? 0.5 : 0.35 + 0.4 * (0.5 + 0.5 * sin(time * 0.35 + seed * 2.1))
                let radius = 1.1 + fract(seed * 6.6) * 1.6

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: baseX + sway - radius * 4, y: wrapped - radius * 4,
                        width: radius * 8, height: radius * 8
                    )),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.14 * breath), .clear]),
                        center: CGPoint(x: baseX + sway, y: wrapped),
                        startRadius: 0, endRadius: radius * 4
                    )
                )
            }
        }
    }

    private func fract(_ value: Double) -> Double { value - value.rounded(.down) }
}

// MARK: - Hero: dial doble

/// Dial doble: surco exterior con ticks para Recuperacion y surco interior para
/// Energia, disco elevado al centro, etiquetas rotadas y el numero revelado por
/// particulas que convergen.
private struct DualDialHero: View {
    let report: MorningReport

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var startedAt = Date.now

    var body: some View {
        VStack(spacing: 6) {
            // Titulo sobre el dial, como "Biological Age / As of July 13".
            Text("Reporte del día")
                .font(.system(size: 25, weight: .bold))
            Text(report.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("CONFIANZA \(report.recoveryConfidence.displayName.uppercased())")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1.0)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)
            dial
        }
        .padding(.top, 4)
        .onAppear {
            startedAt = .now
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recuperación \(report.recoveryValue) por ciento. Energía \(report.energyValue) por ciento.")
        .accessibilityIdentifier("morningReport.hero")
    }

    private var dial: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, 320)
            ZStack {
                // Disco elevado: mas claro que el fondo, brillo cargado arriba.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.09), Color.white.opacity(0.012)],
                            center: .init(x: 0.5, y: 0.18),
                            startRadius: side * 0.02,
                            endRadius: side * 0.58
                        )
                    )
                    .frame(width: side * 0.80, height: side * 0.80)

                // Los aros son ESTATICOS a proposito: se dibujan ya en su valor,
                // sin barrido ni destello. Lo unico vivo aqui es el polvo.
                TickRing(
                    diameter: side,
                    progress: Double(report.recoveryValue) / 100,
                    tint: LabInk.recovery,
                    tickLength: side * 0.038,
                    lineWidth: 1.3,
                    density: 1.5
                )
                TickRing(
                    diameter: side * 0.80,
                    progress: Double(report.energyValue) / 100,
                    tint: LabInk.energy,
                    tickLength: side * 0.026,
                    lineWidth: 1.1,
                    density: 2.2
                )

                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                    OrbitingParticles(
                        elapsed: reduceMotion ? 99 : timeline.date.timeIntervalSince(startedAt),
                        diameter: side
                    )
                }
                .allowsHitTesting(false)

                VStack(spacing: 2) {
                    Text("RECUPERACIÓN")
                        .font(.system(size: 10, weight: .black))
                        .kerning(1.6)
                        .foregroundStyle(LabInk.recovery.opacity(0.9))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(report.recoveryValue)")
                            .font(.system(size: 62, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    HStack(spacing: 5) {
                        Circle().fill(LabInk.energy).frame(width: 5, height: 5)
                        Text("ENERGÍA \(report.energyValue)%")
                            .font(.system(size: 11, weight: .heavy))
                            .kerning(0.8)
                            .monospacedDigit()
                            .foregroundStyle(LabInk.energy.opacity(0.95))
                    }
                    .padding(.top, 2)
                }
                .opacity(numberOpacity)
                .scaleEffect(numberOpacity == 1 ? 1 : 0.94)

                // Etiquetas rotadas tangencialmente, fuera del surco exterior.
                dialLabel("RECUP.", tint: LabInk.recovery, angle: 138, rotation: 48, diameter: side)
                dialLabel("ENERGÍA", tint: LabInk.energy, angle: 42, rotation: -48, diameter: side)

            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .frame(height: min(UIScreen.main.bounds.width - 36, 320))
    }

    private func progress(_ value: Int) -> Double {
        guard appeared || reduceMotion else { return 0 }
        return Double(value) / 100
    }

    private var numberOpacity: Double {
        guard !reduceMotion else { return 1 }
        return appeared ? 1 : 0
    }

    private func dialLabel(_ text: String, tint: Color, angle: Double, rotation: Double, diameter: CGFloat) -> some View {
        let radius = diameter * 0.575
        let radians = Angle.degrees(angle).radians
        return Text(text)
            .font(.system(size: 9, weight: .heavy))
            .kerning(0.8)
            .foregroundStyle(tint.opacity(0.55))
            .rotationEffect(.degrees(rotation))
            .offset(x: CGFloat(cos(radians)) * radius, y: CGFloat(sin(radians)) * radius)
            .opacity(appeared || reduceMotion ? 1 : 0)
    }

}

/// Surco con ticks finos, ESTATICO: los del recorrido se pintan con el color y
/// el resto queda apagado, con brillo irregular como en la referencia. Sin
/// barrido ni destello: el usuario pidió que aquí no hubiera animación.
private struct TickRing: View {
    let diameter: CGFloat
    /// Valor del arco (0...1).
    let progress: Double
    let tint: Color
    let tickLength: CGFloat
    let lineWidth: CGFloat
    /// Grados entre ticks: mas bajo = mas denso.
    let density: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = diameter / 2

            // Surco.
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(.black.opacity(0.28)),
                lineWidth: tickLength * 1.5
            )

            var angle = 0.0
            while angle < 360 {
                let fraction = angle / 360
                let radians = Angle.degrees(angle - 90).radians
                let dx = CGFloat(cos(radians))
                let dy = CGFloat(sin(radians))
                // Brillo irregular: no todos los ticks tienen la misma intensidad.
                let noise = sin(angle * 12.9898) * 0.5 + 0.5
                let lit = fraction <= progress
                let color = lit ? tint : Color.white
                let alpha = lit ? 0.42 + noise * 0.5 : 0.05 + noise * 0.05

                var path = Path()
                path.move(to: CGPoint(
                    x: center.x + dx * (radius - tickLength / 2),
                    y: center.y + dy * (radius - tickLength / 2)
                ))
                path.addLine(to: CGPoint(
                    x: center.x + dx * (radius + tickLength / 2),
                    y: center.y + dy * (radius + tickLength / 2)
                ))
                context.stroke(path, with: .color(color.opacity(alpha)), lineWidth: lineWidth)
                angle += density
            }

            // Resplandor del arco encendido: trazo difuso del propio arco, fijo.
            if progress > 0.01 {
                var glow = context
                glow.addFilter(.blur(radius: tickLength * 0.9))
                glow.stroke(
                    Path { path in
                        path.addArc(
                            center: center, radius: radius,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * progress),
                            clockwise: false
                        )
                    },
                    with: .color(tint.opacity(0.22)),
                    lineWidth: tickLength * 0.7
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .drawingGroup()
    }
}

/// Nube de particulas con vida CONTINUA alrededor del numero.
///
/// En la referencia esta nube nunca se detiene: entre fotogramas separados 0.4 s
/// cambia ~16% de sus pixeles, mientras el fondo permanece quieto. Aqui hace dos
/// cosas: al abrir converge desde fuera (el "reveal" atomico) y despues se queda
/// orbitando como aura, con deriva y respiracion por particula.
private struct OrbitingParticles: View {
    let elapsed: TimeInterval
    let diameter: CGFloat

    private let count = 76
    private let revealDuration: TimeInterval = 1.35

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let revealRaw = min(max(elapsed / revealDuration, 0), 1)
            let reveal = 1 - pow(1 - revealRaw, 3)

            for index in 0..<count {
                let seed = Double(index)
                // En la referencia las particulas NO estan repartidas uniformes:
                // forman cumulos. Cada particula pertenece a uno de cuatro
                // cumulos que orbitan a distinta velocidad.
                let cluster = Double(index % 4)
                let clusterAngle = cluster * (.pi / 2) + elapsed * (0.10 + cluster * 0.035)
                let spreadAngle = (fract(seed * 7.13) - 0.5) * 1.5
                let direction: Double = index.isMultiple(of: 2) ? 1 : -1
                let ownSpin = direction * elapsed * (0.10 + fract(seed * 3.7) * 0.22)
                let angle = clusterAngle + spreadAngle + ownSpin

                // Radio con respiracion propia + expansion inicial.
                let baseRadius = diameter * (0.285 + fract(seed * 5.1) * 0.155)
                let bob = sin(elapsed * (0.7 + fract(seed * 2.9) * 0.9) + seed) * diameter * 0.026
                let radius = baseRadius * (2.1 - 1.1 * reveal) + bob

                // Deriva browniana: dos senos incompatibles por eje. Es lo que
                // hace que la nube "hierva" en vez de girar como un molinillo.
                let wobbleX = (sin(elapsed * (0.9 + fract(seed * 4.7) * 1.3) + seed * 3.1)
                    + 0.6 * sin(elapsed * (1.7 + fract(seed * 8.3)) + seed)) * diameter * 0.016
                let wobbleY = (cos(elapsed * (0.8 + fract(seed * 6.2) * 1.4) + seed * 2.2)
                    + 0.6 * cos(elapsed * (1.9 + fract(seed * 3.3)) + seed * 1.4)) * diameter * 0.016

                let x = center.x + CGFloat(cos(angle)) * CGFloat(radius) + CGFloat(wobbleX)
                let y = center.y + CGFloat(sin(angle)) * CGFloat(radius) * 0.94 + CGFloat(wobbleY)
                // Tamaños medidos en la referencia: motas gruesas, no polvo fino.
                let dot = 2.4 + fract(seed * 9.7) * 4.0
                // Al entrar brillan y luego bajan a nivel de aura; cada una
                // parpadea con su propio ritmo.
                let settle = 0.30 + fract(seed * 4.4) * 0.30
                let flicker = 0.60 + 0.40 * sin(elapsed * (1.1 + fract(seed * 6.1) * 1.6) + seed * 2.3)
                let alpha = (settle + (0.9 - settle) * (1 - reveal)) * flicker

                context.fill(
                    Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)),
                    with: .color(.white.opacity(alpha))
                )
                // Las mas grandes llevan halo, como el bokeh del fondo.
                if dot > 4.2 {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dot * 1.8, y: y - dot * 1.8, width: dot * 3.6, height: dot * 3.6)),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(alpha * 0.28), .clear]),
                            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: dot * 1.8
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fract(_ value: Double) -> Double { value - value.rounded(.down) }
}

// MARK: - Instrumentos menores

/// Mini dial con la misma gramatica del hero, para los cuatro indices.
private struct MiniGauge: View {
    let value: Int
    let label: String
    let tint: Color
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.07), .white.opacity(0.01)],
                            center: .init(x: 0.5, y: 0.2), startRadius: 1, endRadius: 34
                        )
                    )
                TickRing(
                    diameter: 62,
                    progress: Double(min(value, 100)) / 100,
                    tint: tint,
                    tickLength: 5,
                    lineWidth: 1,
                    density: 4
                )
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
            .frame(width: 62, height: 62)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// Fila de señal: nombre, lectura monoespaciada y micro-medidor con la posicion
/// dentro del rango personal.
private struct SignalRow: View {
    let signal: MorningReport.Signal
    let animate: Bool
    let delay: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: signal.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(signal.name)
                    .font(.system(size: 15, weight: .semibold))
                if let range = signal.range {
                    Text("tu rango \(range) \(signal.unit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("sin rango personal todavía")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            if let position = signal.bandPosition {
                BandMeter(position: animate ? position : 0.5)
                    .frame(width: 54, height: 22)
                    .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(delay), value: animate)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(signal.value)
                    .font(.system(size: 19, weight: .bold))
                    .monospacedDigit()
                Text(signal.unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}

/// Micro-medidor: escala de ticks con la posicion de hoy marcada.
private struct BandMeter: View {
    let position: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(0..<9, id: \.self) { _ in
                        Capsule().fill(Color.white.opacity(0.16)).frame(width: 1.5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.5, height: geo.size.height)
                    .shadow(color: .white.opacity(0.8), radius: 4)
                    .offset(x: geo.size.width * CGFloat(min(max(position, 0), 1)) - 1.25)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Barra de ticks para el margen de carga.
private struct TickBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3.5
            let width: CGFloat = 2.5
            let count = max(Int((geo.size.width + spacing) / (width + spacing)), 1)
            let filled = Int((Double(count) * min(max(fraction, 0), 1)).rounded())
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? tint : Color.white.opacity(0.10))
                        .frame(width: width)
                        .shadow(color: index < filled ? tint.opacity(0.6) : .clear, radius: 3)
                }
            }
            .frame(height: geo.size.height)
        }
    }
}

/// Noches del banco de sueño: barras verticales con la meta como linea.
private struct NightsChart: View {
    let values: [Double]
    let tint: Color
    let animate: Bool

    var body: some View {
        GeometryReader { geo in
            // Escala fija 3-10 h: con 0-max todas las noches se ven iguales.
            let lower = 3.0
            let upper = max(values.max() ?? 9, 9)
            let barWidth = min(max((geo.size.width - CGFloat(values.count - 1) * 8) / CGFloat(values.count), 4), 12)
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.95), tint.opacity(0.45)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(
                                width: barWidth,
                                height: animate
                                    ? max(geo.size.height * CGFloat((value - lower) / (upper - lower)), 4)
                                    : 4
                            )
                            .shadow(color: tint.opacity(0.5), radius: 4)
                            .animation(
                                .spring(response: 0.7, dampingFraction: 0.85).delay(0.3 + Double(index) * 0.04),
                                value: animate
                            )
                    }
                }
                // Linea de meta (8 h) como referencia del instrumento.
                Path { path in
                    let y = geo.size.height * (1 - CGFloat((8 - lower) / (upper - lower)))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .accessibilityHidden(true)
    }
}
