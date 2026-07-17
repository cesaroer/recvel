import Charts
import SwiftData
import SwiftUI

/// Paleta de la superficie Bio Age, muestreada de la referencia Bevel
/// (`Bevel_references/BioAgeScreenBevel.png`): TODO es gris neutro — el unico
/// color de acento es el naranja de estados "Fair/High". Nada de verde aqui.
private enum BioAgeInk {
    /// Fondo fuera del disco (mas oscuro abajo).
    static let baseTop = Color(red: 0.115, green: 0.120, blue: 0.135)
    static let baseBottom = Color(red: 0.062, green: 0.065, blue: 0.075)
    /// Naranja de estado (Fair/High en la referencia).
    static let warn = Color(red: 1.00, green: 0.63, blue: 0.30)
}

/// Entrypoint con el lenguaje visual del hero Bevel: tarjeta neutra con
/// mini disco + banda de ticks, punto marcador y tipografia SF estandar.
struct BioAgeHomeCard: View {
    let estimate: BioAgeEstimate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            BioAgeBokehField(density: .compact)
                .allowsHitTesting(false)
                .opacity(0.8)
            StardustField(count: 16)
                .opacity(0.9)

            HStack(spacing: 16) {
                // Mismas proporciones que el hero (0.321 numero · 0.619 punto),
                // escaladas al ancho del mini dial.
                ZStack(alignment: .top) {
                    BioAgeTickDial(
                        width: miniDial,
                        progress: appeared || reduceMotion ? 1 : 0,
                        hasValue: estimate.estimatedYears != nil,
                        compact: true
                    )
                    Text(estimate.estimatedYears.map { String(format: "%.0f", $0) } ?? "--")
                        .font(.system(size: 24, weight: .bold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .offset(y: miniDial * 0.321 - 15)
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .shadow(color: .white.opacity(0.85), radius: 4)
                        .opacity(estimate.estimatedYears == nil ? 0.3 : 1)
                        .offset(y: miniDial * 0.619 - 3)
                }
                .frame(width: miniDial, height: miniDial * 0.70)

                VStack(alignment: .leading, spacing: 5) {
                    Text("EDAD BIOLOGICA")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text(estimate.estimatedYears.map { String(format: "%.1f", $0) } ?? "--")
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                    Text(deltaText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 5) {
                        Circle().fill(confidenceColor).frame(width: 6, height: 6)
                        Text("Confianza \(estimate.confidence.rawValue.lowercased())")
                        Text("·")
                        Text("FRIEND")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .liquidGlass(cornerRadius: 16)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.95, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var miniDial: CGFloat { 104 }

    private var deltaText: String {
        guard let delta = estimate.deltaYears else { return "Completa edad, sexo y VO2 max" }
        if abs(delta) < 0.5 { return "Cerca de tu edad cronologica" }
        return String(format: "%+.1f anos vs cronologica", delta)
    }

    private var confidenceColor: Color {
        switch estimate.confidence { case .high: .white; case .medium: BioAgeInk.warn; case .low: .secondary }
    }

    private var accessibilityText: String {
        guard let age = estimate.estimatedYears else { return "Edad biologica, faltan datos" }
        return String(format: "Edad biologica %.1f anos, %@", age, deltaText.lowercased())
    }
}

struct BioAgeDetailView: View {
    let estimate: BioAgeEstimate
    let vo2Snapshot: DailyHealthSnapshot?
    let history: [DailyHealthSnapshot]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BiomarkerSample.observedAt, order: .reverse) private var samples: [BiomarkerSample]
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var profiles: [NutritionProfile]
    @Query(sort: \MealLog.createdAt, order: .reverse) private var meals: [MealLog]
    @Query(sort: \HabitLog.date, order: .reverse) private var habits: [HabitLog]
    @State private var preferredLens: BioAgeLens?
    @State private var sheet: BioAgeSheet?
    @State private var importState: ClinicalImportState = .idle

    private var profile: NutritionProfile? { profiles.first(where: \.setupCompleted) }
    private var report: BioAgeReport {
        BioAgeReportEngine().report(
            cardio: estimate,
            history: history,
            laboratorySamples: samples,
            birthDate: profile?.birthDate,
            meals: meals,
            habits: habits,
            preferredLens: preferredLens
        )
    }
    private var readings: [BiomarkerReading] { BiomarkerProvider().readings(history: history, samples: samples) }

    var body: some View {
        ZStack {
            // Fondo Bevel: nebulosa gris neutra + bokeh, a pantalla completa.
            BioAgeBackdrop()
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BioAgeHero(report: report)
                    lensPicker
                    traceabilityStrip
                    factorsSection
                    biomarkersSection
                    methodSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 42)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("detail.bioAge")
        }
        // Como en la referencia Bevel: el nav no lleva titulo, solo los
        // botones flotantes; el titulo vive dentro del hero.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { Haptics.soft(); dismiss() } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).foregroundStyle(.white).headerCircleChrome(size: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atras")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { sheet = .addLaboratory(nil) } label: { Label("Agregar laboratorio", systemImage: "plus") }
                    Button { sheet = .catalog } label: { Label("Catalogo de biomarcadores", systemImage: "list.bullet.rectangle") }
                    Button { Task { await importClinicalRecords() } } label: { Label("Importar Clinical Records", systemImage: "cross.case.fill") }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).foregroundStyle(.white).headerCircleChrome(size: 36)
                }
                .accessibilityIdentifier("bioAge.menu")
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .catalog:
                BiomarkerCatalogView(readings: readings) { kind in self.sheet = .addLaboratory(kind) }
            case .addLaboratory(let kind):
                BiomarkerEntryView(initialKind: kind)
            case .biomarker(let kind):
                if let reading = readings.first(where: { $0.id == kind }) { BiomarkerDetailView(reading: reading) }
            }
        }
        .alert("Clinical Records", isPresented: importAlertBinding) {
            Button("Entendido") { importState = .idle }
        } message: { Text(importState.message) }
        .onChange(of: report.selectedLens) { _, lens in preferredLens = lens }
    }

    private var lensPicker: some View {
        Group {
            if report.availableLenses.count > 1 {
                Picker("Lente", selection: Binding(get: { report.selectedLens }, set: { preferredLens = $0; Haptics.selection() })) {
                    ForEach(report.availableLenses) { lens in Text("\(lens.rawValue) · \(lens.method)").tag(lens) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("bioAge.lensPicker")
            } else {
                HStack {
                    Label("\(report.selectedLens.rawValue) · \(report.selectedLens.method)", systemImage: report.selectedLens == .blood ? "drop.fill" : "lungs.fill")
                        .font(.caption.weight(.bold))
                    Spacer()
                    if report.phenoAge == nil {
                        Button("Completar sangre") { sheet = .catalog }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14).frame(height: 42)
                .platformGlass(shape: .capsule)
            }
        }
    }

    private var traceabilityStrip: some View {
        HStack(spacing: 0) {
            bioStat("Cronologica", report.chronologicalAge.map(String.init) ?? "--")
            divider
            bioStat("Confianza", report.confidence.rawValue)
            divider
            bioStat("Cobertura", "\(report.coverageDays)/28")
        }
        .padding(.vertical, 14)
        .liquidGlass(cornerRadius: 16)
    }

    private var divider: some View { Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1, height: 48) }

    private func bioStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Factores de edad", detail: "ultimas cuatro semanas")
            VStack(spacing: 10) {
                ForEach(report.drivers) { driver in BioAgeDriverCard(driver: driver) }
            }
        }
        .accessibilityIdentifier("detail.bioAge.factors")
    }

    private var biomarkersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Otros biomarcadores", detail: "Apple Health y local")
                Spacer()
                Button("Ver todos") { sheet = .catalog }
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(readings.filter { $0.value != nil }.prefix(8)) { reading in
                        Button { sheet = .biomarker(reading.id) } label: { BiomarkerMiniCard(reading: reading) }
                            .buttonStyle(.plain)
                    }
                    if readings.allSatisfy({ $0.value == nil }) {
                        Button { sheet = .catalog } label: {
                            Label("Conectar biomarcadores", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold)).frame(width: 210, height: 100).liquidGlass(cornerRadius: 16)
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }

    private var methodSection: some View {
        VStack(spacing: 10) {
            BioAgeNote(icon: "function", title: "Metodo transparente", detail: "Cardio compara VO2 max con referencias FRIEND. Sangre usa la formula publicada PhenoAge solo con los nueve analitos recientes. Las dos lentes nunca se mezclan.", color: .secondary)
            BioAgeNote(icon: "exclamationmark.shield.fill", title: "No es una edad biologica clinica", detail: "Es informacion de bienestar y tendencia. Los factores de actividad dan contexto, pero no suman ni restan anos al resultado.", color: BioAgeInk.warn)
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            Text(detail.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
        }
    }

    private var importAlertBinding: Binding<Bool> {
        Binding(get: { importState != .idle && importState != .loading }, set: { if !$0 { importState = .idle } })
    }

    @MainActor private func importClinicalRecords() async {
        importState = .loading
        do {
            let imported = try await ClinicalRecordsImporter().importPhenoAgeLabs()
            for item in imported {
                let duplicate = samples.contains { $0.externalIdentifier == item.externalIdentifier && $0.kind == item.kind }
                guard !duplicate else { continue }
                modelContext.insert(BiomarkerSample(kind: item.kind, value: item.value, unit: item.unit, observedAt: item.observedAt, source: "Apple Clinical Records", externalIdentifier: item.externalIdentifier))
            }
            try? modelContext.save()
            importState = .success(imported.count)
        } catch { importState = .failure(error.localizedDescription) }
    }
}

private enum BioAgeSheet: Identifiable {
    case catalog
    case addLaboratory(BiomarkerKind?)
    case biomarker(BiomarkerKind)
    var id: String {
        switch self { case .catalog: "catalog"; case .addLaboratory(let kind): "add-\(kind?.rawValue ?? "new")"; case .biomarker(let kind): "detail-\(kind.rawValue)" }
    }
}

private enum ClinicalImportState: Equatable {
    case idle, loading, success(Int), failure(String)
    var message: String {
        switch self { case .idle: ""; case .loading: "Importando..."; case .success(let count): "Se importaron \(count) resultados compatibles y se procesaran localmente."; case .failure(let message): message }
    }
}

/// Hero 1:1 con la referencia Bevel (`Bevel_references/BioAge_revel.mp4` y
/// `BioAgeScreenBevel.png`). Geometria resuelta del frame completo (W = ancho):
///   centro del circulo 0.147W · radio 0.472W · banda oscura de ticks 360 grados
///   titulo 0.071W · subtitulo 0.136W · numero 0.321W
///   etiquetas rotadas ±45 grados a radio 1.18R · punto 0.619W · valor 0.686W
/// Full-bleed: sin tarjeta. El disco interior es MAS CLARO que el fondo
/// (superficie elevada) y los ticks viven dentro de un surco oscuro.
private struct BioAgeHero: View {
    let report: BioAgeReport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var startedAt = Date.now

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .top) {
                BioAgeTickDial(
                    width: w,
                    progress: appeared || reduceMotion ? 1 : 0,
                    hasValue: report.displayedAge != nil,
                    lowLabel: rangeLabel(-5),
                    highLabel: rangeLabel(5)
                )

                Text("Edad biologica")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .offset(y: w * 0.071 - 15)

                Text(asOfText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .offset(y: w * 0.136 - 10)

                // Particulas blancas que convergen y revelan el numero.
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                    BioAgeParticleCanvas(progress: particleProgress(at: timeline.date))
                }
                .allowsHitTesting(false)

                Text(report.displayedAge.map { String(format: "%.0f", $0) } ?? "--")
                    .font(.system(size: 64, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .opacity(numberOpacity)
                    .scaleEffect(numberOpacity == 1 ? 1 : 0.92)
                    .frame(maxWidth: .infinity)
                    .offset(y: w * 0.321 - 39)

                // Punto marcador blanco con halo, en el vertice inferior de la banda.
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 26, height: 26)
                        .blur(radius: 10)
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                }
                .opacity(report.displayedAge == nil ? 0.3 : 1)
                .offset(y: w * 0.619 - 13)

                // Valor exacto debajo del punto.
                Text(report.displayedAge.map { String(format: "%.1f", $0) } ?? "--")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .offset(y: w * 0.686 - 8)

                // Contexto propio de Recvel (neutro, bajo el bloque de la referencia).
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(report.selectedLens == .blood ? "SANGRE · PHENOAGE" : "CARDIO · FRIEND BETA")
                        Text("·")
                        Text(deltaText).foregroundStyle(.primary)
                        Text("·")
                        Label(report.confidence.rawValue.uppercased(), systemImage: "checkmark.seal.fill")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                    Text(freshnessText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .offset(y: w * 0.760)
            }
        }
        .frame(height: heroHeight)
        .onAppear {
            startedAt = .now
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 1.15, dampingFraction: 0.78)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("detail.bioAge.hero")
    }

    private var heroHeight: CGFloat {
        UIScreen.main.bounds.width * 0.88
    }

    /// Rango del dial: +/-5 anos alrededor del valor (26.1 · 31.1 · 36.1 en la referencia).
    private func rangeLabel(_ offset: Double) -> String? {
        guard let age = report.displayedAge else { return nil }
        return String(format: "%.1f", age + offset)
    }

    private var asOfText: String {
        "Al \(report.updatedAt.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es_MX"))))"
    }
    private var numberOpacity: Double {
        guard !reduceMotion else { return 1 }
        return appeared ? 1 : 0
    }
    private var deltaText: String {
        guard let delta = report.deltaYears else { return "CALIBRANDO" }
        if abs(delta) < 0.5 { return "CERCA DE TU EDAD" }
        return String(format: "%+.1f VS CRONOLOGICA", delta)
    }
    private var freshnessText: String {
        let seconds = max(Int(Date.now.timeIntervalSince(report.updatedAt)), 0)
        if seconds < 60 { return "Actualizado ahora" }
        if seconds < 3_600 { return "Actualizado hace \(seconds / 60) min" }
        if seconds < 86_400 { return "Actualizado hace \(seconds / 3_600) h" }
        return "Actualizado hace \(seconds / 86_400) dias"
    }
    private var accessibilitySummary: String {
        guard let age = report.displayedAge else { return "Edad biologica, sin datos suficientes" }
        return String(format: "Edad biologica %.1f anos. %@. Confianza %@", age, deltaText.lowercased(), report.confidence.rawValue.lowercased())
    }
    private func particleProgress(at date: Date) -> Double {
        if reduceMotion { return 1 }
        return min(max(date.timeIntervalSince(startedAt) / 1.5, 0), 1)
    }
}

/// Fondo de pantalla completa de la superficie Bio Age (referencia Bevel):
/// gradiente gris neutro, dos brillos de nebulosa muy sutiles y bokeh animado.
private struct BioAgeBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BioAgeInk.baseTop, BioAgeInk.baseBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.10), .clear],
                center: .init(x: 0.28, y: 0.08),
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.52, blue: 0.42).opacity(0.10), .clear],
                center: .init(x: 0.85, y: 0.16),
                startRadius: 6,
                endRadius: 300
            )
            BioAgeBokehField(density: .full)
            StardustField(count: 110)
        }
        .allowsHitTesting(false)
    }
}

private enum BioAgeBokehDensity { case full, compact }

/// Bokeh Bevel: circulos blancos desenfocados de varios tamanos que derivan
/// lentamente + estrellas pequenas que titilan. Todo neutro, sin color.
private struct BioAgeBokehField: View {
    let density: BioAgeBokehDensity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
                let starCount = density == .full ? 18 : 6
                let bokehCount = density == .full ? 9 : 3

                for index in 0..<starCount {
                    let seed = Double(index)
                    let baseX = (sin(seed * 78.233) * 0.5 + 0.5) * size.width
                    let baseY = (cos(seed * 43.771) * 0.5 + 0.5) * size.height
                    let twinkle = 0.62 + 0.38 * sin(t * (0.5 + seed.truncatingRemainder(dividingBy: 0.7)) + seed)
                    let radius = index.isMultiple(of: 9) ? 2.4 : 1.2
                    let alpha = (index.isMultiple(of: 5) ? 0.5 : 0.22) * twinkle
                    context.fill(
                        Path(ellipseIn: CGRect(x: baseX, y: baseY, width: radius, height: radius)),
                        with: .color(.white.opacity(alpha))
                    )
                }

                for index in 0..<bokehCount {
                    let seed = Double(index) + 31.0
                    let baseX = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let baseY = (cos(seed * 7.233) * 0.5 + 0.5) * size.height
                    let driftX = CGFloat(sin(t * 0.11 + seed * 2.1)) * 9
                    let driftY = CGFloat(cos(t * 0.09 + seed * 1.3)) * 7
                    let radius = 4.0 + (seed * 13).truncatingRemainder(dividingBy: 9)
                    let alpha = 0.10 + (seed * 7).truncatingRemainder(dividingBy: 0.16)
                    let rect = CGRect(
                        x: baseX + driftX - radius, y: baseY + driftY - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(alpha), .clear]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Particulas blancas que convergen hacia el numero y se desvanecen al
/// revelarlo (la nube de particulas de la referencia es blanca, sin color).
private struct BioAgeParticleCanvas: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let targetX: CGFloat = size.width / 2
            let targetY: CGFloat = size.width * 0.321
            let eased: CGFloat = 1 - pow(1 - CGFloat(progress), 3)
            let spread: CGFloat = size.width * 0.28
            let fade: Double = 0.85 * Double(1 - eased)

            for index in 0..<80 {
                let seed = Double(index)
                let angle: Double = (seed / 80) * Double.pi * 2
                let jitterX: CGFloat = CGFloat(sin(seed * 12.9898) * 0.5 + 1.0)
                let jitterY: CGFloat = CGFloat(cos(seed * 8.213) * 0.5 + 1.0)
                let sourceX: CGFloat = targetX + CGFloat(cos(angle)) * spread * jitterX
                let sourceY: CGFloat = targetY + CGFloat(sin(angle)) * spread * jitterY * 0.6
                let x: CGFloat = sourceX + (targetX - sourceX) * eased
                let y: CGFloat = sourceY + (targetY - sourceY) * eased
                let dotSize: CGFloat = index.isMultiple(of: 5) ? 5 : 3
                let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(fade)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Dial Bevel: disco interior ELEVADO (mas claro que el fondo), surco circular
/// oscuro de 360 grados con ticks claros densos dentro, y etiquetas de rango
/// rotadas tangencialmente (±45 grados) fuera de la banda.
private struct BioAgeTickDial: View {
    let width: CGFloat
    let progress: Double
    let hasValue: Bool
    var lowLabel: String? = nil
    var highLabel: String? = nil
    var compact: Bool = false

    private var radius: CGFloat { width * 0.472 }
    private var centerY: CGFloat { width * 0.147 }
    private var bandWidth: CGFloat { width * 0.036 }

    var body: some View {
        ZStack(alignment: .top) {
            // Disco interior elevado: mas claro que el fondo, con el brillo
            // cargado hacia arriba (donde vive la nebulosa).
            if !compact {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.085), Color.white.opacity(0.015)],
                            center: .init(x: 0.5, y: 0.18),
                            startRadius: radius * 0.05,
                            endRadius: radius * 1.15
                        )
                    )
                    .frame(width: (radius - bandWidth / 2) * 2, height: (radius - bandWidth / 2) * 2)
                    .offset(y: centerY - (radius - bandWidth / 2))
            }

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: centerY)

                // Surco oscuro de 360 grados donde viven los ticks.
                let ringRect = CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(.black.opacity(compact ? 0.24 : 0.30)),
                    lineWidth: bandWidth
                )

                // Ticks densos alrededor de todo el circulo, con brillo
                // pseudoaleatorio como en la referencia. `fraction` mide la
                // distancia angular al vertice inferior para el barrido de entrada.
                let step = 1.6
                let tickLength = bandWidth * 0.72
                var angle = 0.0
                while angle < 360 {
                    let delta = abs(angle - 90)
                    let fraction = min(delta, 360 - delta) / 180
                    if fraction <= progress {
                        let radians = Angle.degrees(angle).radians
                        let dx = CGFloat(cos(radians))
                        let dy = CGFloat(sin(radians))
                        var path = Path()
                        path.move(to: CGPoint(
                            x: center.x + dx * (radius - tickLength / 2),
                            y: center.y + dy * (radius - tickLength / 2)
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + dx * (radius + tickLength / 2),
                            y: center.y + dy * (radius + tickLength / 2)
                        ))
                        // Brillo irregular (algunas marcas mas claras) + marcas
                        // apagadas cuando no hay dato.
                        let noise = (sin(angle * 12.9898) * 0.5 + 0.5)
                        let base = hasValue ? 1.0 : 0.45
                        let alpha = (0.07 + noise * 0.22) * base
                        context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 1.1)
                    }
                    angle += step
                }
            }

            // Etiquetas de rango rotadas tangencialmente, fuera de la banda
            // (26.1 / 36.1 en la referencia, a ±45 grados del vertice).
            if let lowLabel {
                dialLabel(lowLabel, angleDegrees: 135, rotation: 45)
            }
            if let highLabel {
                dialLabel(highLabel, angleDegrees: 45, rotation: -45)
            }
        }
        .allowsHitTesting(false)
    }

    private func dialLabel(_ text: String, angleDegrees: Double, rotation: Double) -> some View {
        let labelRadius = radius * 1.18
        let radians = Angle.degrees(angleDegrees).radians
        let x = width / 2 + CGFloat(cos(radians)) * labelRadius
        let y = centerY + CGFloat(sin(radians)) * labelRadius
        return Text(text)
            .font(.system(size: 14))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.42))
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
            .opacity(progress)
    }
}

/// Fila estilo "Other Biomarkers" de Bevel: titulo blanco, palabra de estado
/// coloreada + valor secundario, y sparkline a la derecha con punto final.
private struct BioAgeDriverCard: View {
    let driver: BioAgeDriver
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(driver.title).font(.system(size: 17, weight: .semibold))
                HStack(spacing: 5) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusColor)
                    Text(driver.status.rawValue).foregroundStyle(statusColor)
                    Text("· \(driver.value)").foregroundStyle(.secondary)
                }
                .font(.system(size: 14))
                Text(driver.benchmark)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if driver.points.count > 1 {
                BioAgeSparkline(points: Array(driver.points.suffix(14)), color: statusColor)
                    .frame(width: 92, height: 40)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 16)
    }
    private var statusColor: Color {
        switch driver.status {
        case .favorable: .primary
        case .fair, .calibrating, .attention: BioAgeInk.warn
        case .missing: .secondary
        }
    }
    private var statusSymbol: String { switch driver.status { case .favorable: "arrow.up.circle.fill"; case .fair: "arrow.right.circle.fill"; case .attention: "exclamationmark.circle.fill"; case .calibrating: "circle.dotted"; case .missing: "minus.circle.fill" } }
}

/// Sparkline Bevel: linea con punto final y linea base punteada.
private struct BioAgeSparkline: View {
    let points: [Double]
    let color: Color

    var body: some View {
        Chart {
            RuleMark(y: .value("Base", points.min() ?? 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .foregroundStyle(Color.white.opacity(0.18))
            ForEach(Array(points.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("Muestra", index), y: .value("Valor", value))
                    .foregroundStyle(color == .primary ? Color.white.opacity(0.75) : color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
            }
            if let last = points.last {
                PointMark(x: .value("Muestra", points.count - 1), y: .value("Valor", last))
                    .foregroundStyle(color == .primary ? Color.white : color)
                    .symbolSize(26)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct BiomarkerMiniCard: View {
    let reading: BiomarkerReading
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: reading.descriptor.symbol).foregroundStyle(.secondary); Spacer(); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
            Text(reading.value.map { String(format: "%.1f", $0) } ?? "--").font(.title3.weight(.bold)).monospacedDigit()
            Text(reading.descriptor.shortTitle).font(.caption.weight(.semibold))
            Text(reading.date?.formatted(.relative(presentation: .named)) ?? "Sin fecha").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 126, height: 112, alignment: .leading).padding(13).liquidGlass(cornerRadius: 16)
    }
}

private struct BiomarkerCatalogView: View {
    let readings: [BiomarkerReading]
    let addLaboratory: (BiomarkerKind) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var filtered: [BiomarkerReading] { search.isEmpty ? readings : readings.filter { $0.descriptor.title.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { reading in
                            NavigationLink { BiomarkerDetailView(reading: reading) } label: {
                                HStack(spacing: 13) {
                                    Image(systemName: reading.descriptor.symbol).foregroundStyle(.secondary).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(reading.descriptor.title).font(.subheadline.weight(.semibold))
                                        Text(reading.value.map { "\(String(format: "%.1f", $0)) \(reading.unit)" } ?? "Sin datos").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if reading.descriptor.isLaboratory {
                                        Button { addLaboratory(reading.id) } label: { Image(systemName: "plus.circle.fill").foregroundStyle(.white) }.buttonStyle(.plain)
                                    }
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }.padding(14).liquidGlass(cornerRadius: 16)
                            }.buttonStyle(.plain)
                        }
                    }.padding(16)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle("Biomarcadores")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar biomarcador")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Listo") { dismiss() } } }
            .liquidGlassNavigationBar()
        }
    }
}

private struct BiomarkerDetailView: View {
    let reading: BiomarkerReading
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(reading.descriptor.title.uppercased(), systemImage: reading.descriptor.symbol).font(.system(size: 10, weight: .heavy)).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(reading.value.map { String(format: "%.1f", $0) } ?? "--").font(.system(size: 48, weight: .bold)).monospacedDigit()
                            Text(reading.unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text("\(reading.source) · \(reading.date?.formatted(date: .abbreviated, time: .omitted) ?? "sin fecha")").font(.caption).foregroundStyle(.secondary)
                    }.padding(18).liquidGlass(cornerRadius: 16)

                    if !reading.history.isEmpty {
                        Chart(reading.history, id: \.date) { point in
                            LineMark(x: .value("Fecha", point.date), y: .value("Valor", point.value)).foregroundStyle(Color.white.opacity(0.8)).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Fecha", point.date), y: .value("Valor", point.value)).foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom))
                        }.chartYAxis { AxisMarks(position: .leading) }.frame(height: 190).padding(14).liquidGlass(cornerRadius: 16)
                    }
                    BioAgeNote(icon: "book.closed.fill", title: "Que representa", detail: reading.descriptor.explanation, color: .secondary)
                    BioAgeNote(icon: "scope", title: "Referencia", detail: reading.descriptor.benchmark, color: .secondary)
                    BioAgeNote(icon: "person.crop.circle.badge.exclamationmark", title: "Lectura prudente", detail: "Usa tendencias y la fuente original. Ante valores inesperados o sintomas, consulta a un profesional de salud.", color: BioAgeInk.warn)
                }.padding(16).padding(.bottom, 28)
            }.scrollIndicators(.hidden)
        }.navigationTitle(reading.descriptor.shortTitle).navigationBarTitleDisplayMode(.inline).liquidGlassNavigationBar()
    }
}

private struct BiomarkerEntryView: View {
    let initialKind: BiomarkerKind?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var kind: BiomarkerKind
    @State private var value = ""
    @State private var unit: String
    @State private var date = Date.now
    @State private var source = "Laboratorio manual"

    init(initialKind: BiomarkerKind?) {
        let first = initialKind ?? .albumin
        self.initialKind = initialKind
        _kind = State(initialValue: first)
        _unit = State(initialValue: BiomarkerCatalog.descriptor(for: first).unit)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Los nueve analitos deben pertenecer a un panel reciente. Recvel nunca completa valores faltantes.")
                            .font(.caption).foregroundStyle(.secondary).padding(14).liquidGlass(cornerRadius: 16)
                        Menu {
                            ForEach(BiomarkerCatalog.phenoAgeKinds, id: \.self) { item in
                                Button(BiomarkerCatalog.descriptor(for: item).title) { kind = item; unit = BiomarkerCatalog.descriptor(for: item).unit }
                            }
                        } label: { field("Analito", value: BiomarkerCatalog.descriptor(for: kind).title, symbol: "testtube.2") }
                        TextField("Valor", text: $value).keyboardType(.decimalPad).padding(15).liquidGlass(cornerRadius: 16)
                        Menu {
                            ForEach(unitOptions, id: \.self) { item in Button(item) { unit = item } }
                        } label: { field("Unidad", value: unit, symbol: "ruler") }
                        DatePicker("Fecha de muestra", selection: $date, in: ...Date.now, displayedComponents: .date).padding(15).liquidGlass(cornerRadius: 16)
                        TextField("Fuente", text: $source).padding(15).liquidGlass(cornerRadius: 16)
                    }.padding(16)
                }
            }
            .navigationTitle("Agregar laboratorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(parsedValue == nil) }
            }.liquidGlassNavigationBar()
        }
    }

    private var parsedValue: Double? { Double(value.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil } }
    private var unitOptions: [String] {
        switch kind { case .albumin: ["g/L", "g/dL"]; case .creatinine: ["umol/L", "mg/dL"]; case .glucose: ["mmol/L", "mg/dL"]; case .crp: ["mg/L", "mg/dL"]; case .lymphocytePercent, .rdw: ["%"]; case .mcv: ["fL"]; case .alkalinePhosphatase: ["U/L"]; case .whiteBloodCellCount: ["10^9/L", "K/uL"]; default: [BiomarkerCatalog.descriptor(for: kind).unit] }
    }
    private func field(_ title: String, value: String, symbol: String) -> some View {
        HStack { Label(title, systemImage: symbol).foregroundStyle(.primary); Spacer(); Text(value).foregroundStyle(.secondary); Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary) }.padding(15).liquidGlass(cornerRadius: 16)
    }
    private func save() {
        guard let parsedValue else { return }
        modelContext.insert(BiomarkerSample(kind: kind, value: parsedValue, unit: unit, observedAt: date, source: source.isEmpty ? "Laboratorio manual" : source))
        try? modelContext.save(); Haptics.success(); dismiss()
    }
}

private struct BioAgeNote: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.headline).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.bold)); Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).liquidGlass(cornerRadius: 16)
    }
}
