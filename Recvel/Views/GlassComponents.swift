import SwiftUI

enum RecvelVisualStyle: Equatable {
    case onboarding
    case product
}

private struct RecvelVisualStyleKey: EnvironmentKey {
    static let defaultValue = RecvelVisualStyle.onboarding
}

extension EnvironmentValues {
    var recvelVisualStyle: RecvelVisualStyle {
        get { self[RecvelVisualStyleKey.self] }
        set { self[RecvelVisualStyleKey.self] = newValue }
    }
}

// MARK: - Disponibilidad de Liquid Glass nativo

var isLiquidGlassAvailable: Bool {
    if #available(iOS 26.0, *) { return true } else { return false }
}

// MARK: - Fondo

struct AppBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.recvelVisualStyle) private var visualStyle
    @State private var drift = false

    @ViewBuilder
    var body: some View {
        if visualStyle == .product {
            Color(red: 0.055, green: 0.059, blue: 0.071)
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.05, green: 0.24, blue: 0.19).opacity(0.20), location: 0),
                            .init(color: .clear, location: 0.28),
                            .init(color: Color.black.opacity(0.18), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
        } else {
            onboardingBackground
        }
    }

    private var onboardingBackground: some View {
        Color(red: 0.018, green: 0.021, blue: 0.027)
            .overlay {
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.05, green: 0.42, blue: 0.31).opacity(0.28), location: 0),
                            .init(color: .clear, location: 0.34),
                            .init(color: Color(red: 0.34, green: 0.12, blue: 0.45).opacity(0.20), location: 0.68),
                            .init(color: Color(red: 0.04, green: 0.22, blue: 0.38).opacity(0.18), location: 1)
                        ],
                        startPoint: drift ? .topTrailing : .topLeading,
                        endPoint: drift ? .bottomLeading : .bottomTrailing
                    )

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.035), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(-18))
                        .offset(x: drift ? 260 : -260)
                        .blur(radius: 24)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }
}

// MARK: - Superficie Liquid Glass (replica iOS 17/18)

private struct LiquidGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.recvelVisualStyle) private var visualStyle
    let cornerRadius: CGFloat
    var tint: Color?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if visualStyle == .product {
            productSurface(content: content)
        } else {
            onboardingSurface(content: content)
        }
    }

    private func productSurface(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Color(red: 0.105, green: 0.11, blue: 0.13))
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                    shape.fill(Color(red: 0.085, green: 0.09, blue: 0.105).opacity(reduceTransparency ? 1 : 0.52))
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.13), location: 0),
                                .init(color: Color.white.opacity(0.035), location: 0.34),
                                .init(color: Color.clear, location: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    if let tint {
                        shape.fill(tint.opacity(0.08))
                    }
                }
            }
            .overlay {
                ZStack {
                    shape.strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.34), location: 0),
                                .init(color: Color.white.opacity(0.10), location: 0.42),
                                .init(color: Color.white.opacity(0.035), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )

                    if !reduceTransparency {
                        shape
                            .inset(by: 1.2)
                            .stroke(Color.white.opacity(0.055), lineWidth: 2)
                            .blur(radius: 1.4)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.30), radius: 14, y: 7)
    }

    private func onboardingSurface(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(red: 0.09, green: 0.095, blue: 0.115))
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        // Gradiente de vidrio: mas claro arriba (luz), mas oscuro abajo
                        shape.fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.09), Color.white.opacity(0.015)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        if let tint {
                            shape.fill(tint.opacity(0.10))
                        }
                    }
                }
            }
            // Sheen diagonal (reflejo de luz sobre el cristal)
            .overlay {
                if !reduceTransparency {
                    shape
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.10), location: 0),
                                    .init(color: .white.opacity(0.02), location: 0.35),
                                    .init(color: .clear, location: 0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
            }
            // Highlight especular en el borde superior
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(reduceTransparency ? 0.20 : 0.65), location: 0),
                                .init(color: .white.opacity(0.08), location: 0.30),
                                .init(color: .clear, location: 0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.4
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            // Sombra interior inferior (profundidad del cristal)
            .overlay {
                shape
                    .stroke(Color.black.opacity(0.40), lineWidth: 5)
                    .blur(radius: 6)
                    .mask(
                        shape.fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.75)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                    )
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
            // Borde hairline continuo
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 8, tint: Color? = nil) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius, tint: tint))
    }

    @ViewBuilder
    func platformGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        shape: PlatformGlassShape = .rounded
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            switch shape {
            case .rounded:
                glassEffect(.regular.tint(tint).interactive(interactive), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            case .capsule:
                glassEffect(.regular.tint(tint).interactive(interactive), in: Capsule())
            case .circle:
                glassEffect(.regular.tint(tint).interactive(interactive), in: Circle())
            }
        } else {
            liquidGlass(cornerRadius: shape.fallbackRadius, tint: tint)
        }
#else
        liquidGlass(cornerRadius: shape.fallbackRadius, tint: tint)
#endif
    }

    /// El area visual completa recibe taps (glass/material no basta como hit-target).
    func tappableCapsule() -> some View { contentShape(Capsule()) }
    func tappableCircle() -> some View { contentShape(Circle()) }
    func tappableRounded(_ cornerRadius: CGFloat = 10) -> some View {
        contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Chrome de CTA capsule: frame + glass + hit-target completo.
    func primaryCapsuleChrome(tint: Color, minHeight: CGFloat = 52) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight)
            .platformGlass(tint: tint, interactive: true, shape: .capsule)
            .tappableCapsule()
    }

    /// Boton circular de header (cerrar / atras): frame + glass + hit completo.
    func headerCircleChrome(size: CGFloat = 40) -> some View {
        frame(width: size, height: size)
            .contentShape(Circle())
            .platformGlass(interactive: true, shape: .circle)
            .tappableCircle()
    }

    /// Fija el ancho del contenido de un ScrollView vertical al del viewport.
    /// Normalmente no se usa directo: `WidthLockedScrollView` ya lo aplica.
    func scrollContentLockedToViewportWidth() -> some View {
        containerRelativeFrame(.horizontal, alignment: .leading)
    }

    @ViewBuilder
    func liquidGlassNavigationBar() -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .toolbar(.visible, for: .navigationBar)
        } else {
            self
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
#else
        self
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
#endif
    }
}

/// Superficie plana del lenguaje Revel: relleno un punto por encima del fondo,
/// radio amplio y **sin degradado, tinte ni sombra**; solo un hairline muy
/// tenue para separarla del fondo.
///
/// Es la alternativa sobria a `.liquidGlass()`: donde hay muchas tarjetas
/// seguidas, el cristal con tinte y sus tres capas de overlay compiten entre si
/// y la pantalla se ve ruidosa. Aqui manda el contenido.
struct RevelSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    /// Acento opcional: se usa MUY diluido, solo para teñir el relleno.
    var accent: Color?
    /// Destaca la tarjeta sobre sus vecinas: borde en el color de acento,
    /// relleno algo mas teñido y un halo suave.
    ///
    /// Es para las tarjetas que **aconsejan**, no las que informan. Con todas
    /// las superficies iguales, un banner de consejo se perdia entre las
    /// tarjetas de datos que tiene encima y debajo. Usar con moderacion: si se
    /// destaca todo, no se destaca nada.
    var emphasized: Bool = false

    private var borderColor: Color {
        guard emphasized, let accent else { return Color.white.opacity(0.06) }
        return accent.opacity(0.42)
    }

    private var borderWidth: CGFloat { emphasized && accent != nil ? 1.2 : 0.5 }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape
                    .fill(Color(red: 0.098, green: 0.104, blue: 0.121))
                    .overlay {
                        if let accent {
                            shape.fill(accent.opacity(emphasized ? 0.10 : 0.055))
                        }
                    }
            }
            .overlay {
                shape
                    .strokeBorder(borderColor, lineWidth: borderWidth)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
            // El halo va FUERA del clip para que no lo recorte la propia forma.
            .shadow(
                color: emphasized ? (accent ?? .clear).opacity(0.22) : .clear,
                radius: 14,
                y: 3
            )
    }
}

extension View {
    /// Tarjeta plana Revel. Ver `RevelSurface`.
    func revelSurface(
        cornerRadius: CGFloat = 22,
        accent: Color? = nil,
        emphasized: Bool = false
    ) -> some View {
        modifier(RevelSurface(cornerRadius: cornerRadius, accent: accent, emphasized: emphasized))
    }
}

/// Cabecera de seccion: eyebrow tenue en mayusculas sobre un titulo grande.
/// Da jerarquia sin recurrir a mas cajas.
struct RevelSectionHeader: View {
    let eyebrow: String
    let title: String
    var accent: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(accent.opacity(0.85))
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

/// `ScrollView` vertical con el contenido fijado al ancho del viewport.
///
/// Sustituye al `ScrollView { … }` de las superficies a pantalla completa. Un
/// scroll vertical se vuelve **arrastrable en horizontal** (con rebote y
/// vuelta) en cuanto UN hijo rigido —texto con `fixedSize`/`lineLimit(1)` que
/// crece con el idioma o con datos reales— reporta mas ancho que el viewport:
/// toda la pantalla se desplaza en bloque manteniendo el dedo y arrastrando.
/// Visto en dispositivo (app en ingles + datos reales) en Entrenamiento, Ayuno
/// y Estres; el simulador (español + demo) no lo reproduce porque el desborde
/// depende de las cadenas. Con el candado, un hijo desbordado se recorta en
/// vez de habilitar el paneo. Los `ScrollView(.horizontal)` no se tocan.
struct WidthLockedScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            // .center replica donde un ScrollView normal coloca el contenido
            // mas estrecho que el viewport; los VStack raiz de ancho completo
            // no notan la diferencia.
            content.containerRelativeFrame(.horizontal, alignment: .center)
        }
    }
}

enum PlatformGlassShape {
    case rounded
    case capsule
    case circle

    var fallbackRadius: CGFloat {
        switch self {
        case .rounded: 18
        case .capsule, .circle: 999
        }
    }
}

// MARK: - Estilo de press para tarjetas navegables

struct GlassCardLinkStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.soft() }
            }
    }
}

extension ButtonStyle where Self == GlassCardLinkStyle {
    static var glassCardLink: GlassCardLinkStyle { GlassCardLinkStyle() }
}

// MARK: - Tarjeta Liquid Glass

struct LiquidGlassCard<Content: View>: View {
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let tint: Color?
    private let content: Content

    init(
        padding: CGFloat = 18,
        cornerRadius: CGFloat = 8,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .liquidGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

/// Alias de compatibilidad: vistas existentes siguen usando `GlassCard`.
typealias GlassCard = LiquidGlassCard

// MARK: - Boton Liquid Glass (press morph)

struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var cornerRadius: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: cornerRadius)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle { LiquidGlassButtonStyle() }
}

// MARK: - Anillo hero circular con gradiente angular

struct HeroScoreRing: View {
    /// Bajo esqueleto el anillo NO dibuja progreso: un arco a medias se lee
    /// como un valor real y estariamos enseñando un dato que aun no existe.
    @Environment(\.redactionReasons) private var redactionReasons
    private var isRedacted: Bool { redactionReasons.contains(.placeholder) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let score: WellnessScore
    var valueText: String?

    @State private var animatedProgress: Double = 0

    private var progress: Double { Double(score.value) / 100 }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: isRedacted ? 0 : animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [score.kind.color.opacity(0.55), score.kind.color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: score.kind.color.opacity(0.70), radius: 9)

                Text(valueText ?? "\(score.value)%")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
            .frame(width: 92, height: 92)

            HStack(spacing: 3) {
                Text(score.kind.displayName)
                    .font(.footnote.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.7).delay(0.12)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score.value) { _, _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            RecvelL10n.text("a11y.scoreOfHundred", values: [
                "name": score.kind.displayName,
                "value": "\(score.value)"
            ]) + " \(RecvelL10n.text("common.confidence")) \(score.confidence.displayName)"
        )
    }
}

// MARK: - Gauge semicircular

struct ArcGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Double        // 0...1
    let color: Color
    let centerText: String
    let centerCaption: String
    var minLabel = "0"
    var maxLabel = "100"

    @State private var animatedValue: Double = 0

    private let sweep = 0.68

    var body: some View {
        VStack(spacing: -8) {
            ZStack {
                arc(to: sweep, color: .white.opacity(0.09), glow: false)
                arc(to: sweep * animatedValue, color: color, glow: true)

                VStack(spacing: 2) {
                    Text(centerText)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(centerCaption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .offset(y: 8)
            }
            .frame(height: 158)

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 26)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.75).delay(0.15)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75)) {
                animatedValue = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(centerCaption): \(centerText)")
    }

    private func arc(to fraction: Double, color: Color, glow: Bool) -> some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(color.gradient, style: StrokeStyle(lineWidth: 13, lineCap: .round))
            .rotationEffect(.degrees(90 + (1 - sweep) * 360 / 2))
            .shadow(color: glow ? color.opacity(0.5) : .clear, radius: 8)
            .padding(10)
    }
}

// MARK: - Tarjeta de metrica (actual vs. referencia)

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var reference: String?
    let color: Color

    var body: some View {
        LiquidGlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(value)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        if let reference {
                            Text(reference)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.14), in: Circle())
                    Text(title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)\(reference.map { ", referencia \($0)" } ?? "")")
    }
}

// MARK: - Tab bar Liquid Glass (capsula flotante)

enum AppTab: String, CaseIterable, Identifiable {
    case today, journal, nutrition, fasting, fitness

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: "house.fill"
        case .journal: "checklist"
        case .fitness: "figure.run"
        case .nutrition: "fork.knife"
        case .fasting: "timer"
        }
    }

    var title: String {
        switch self {
        case .today: RecvelL10n.text("tab.today")
        case .journal: RecvelL10n.text("tab.journal")
        case .fitness: RecvelL10n.text("tab.training")
        case .nutrition: RecvelL10n.text("tab.nutrition")
        case .fasting: RecvelL10n.text("tab.fasting")
        }
    }
}

/// Quick actions exposed by the floating FAB next to the tab bar (Bevel "+" pattern).
enum TabQuickAction: String, CaseIterable, Identifiable {
    case meal, journal, fasting, fitness, plan, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal: RecvelL10n.text("quick.meal")
        case .journal: RecvelL10n.text("tab.journal")
        case .fasting: RecvelL10n.text("tab.fasting")
        case .fitness: RecvelL10n.text("tab.training")
        case .plan: RecvelL10n.text("quick.plan")
        case .settings: RecvelL10n.text("quick.settings")
        }
    }

    var icon: String {
        switch self {
        case .meal: "fork.knife"
        case .journal: "checklist"
        case .fasting: "timer"
        case .fitness: "figure.run"
        case .plan: "scope"
        case .settings: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .meal: ScoreKind.energy.color
        case .journal: ScoreKind.sleep.color
        case .fasting: Color.orange
        case .fitness: ScoreKind.strain.color
        case .plan: Color.cyan
        case .settings: Color.secondary
        }
    }

    var tab: AppTab? {
        switch self {
        case .meal: .nutrition
        case .journal: .journal
        case .fasting: .fasting
        case .fitness: .fitness
        case .plan: nil
        case .settings: nil
        }
    }
}


/// Floating Liquid Glass tab bar.
///
/// Behavior (Bevel + iOS 26 Liquid Glass):
/// - **Expanded:** capsule with all tabs + separate circular FAB (`+`) on the trailing edge.
/// - **Minimized (scroll down):** morph to two floating circles — active tab (leading) + FAB (trailing).
/// - **FAB:** toggles a radial glass action menu; icon morphs `+` → `xmark` with rotation.
/// - **Hidden (detail push):** slides fully off-screen.
struct LiquidGlassTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TabBarVisibility.self) private var visibility
    @Binding var selection: AppTab
    /// Visual selection for the pill/icons — updates immediately on tap.
    /// `selection` (content) is deferred one frame so the highlight never waits on page layout.
    @State private var highlight: AppTab = .today
    @State private var menuOpen = false

    private var pillAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.18, extraBounce: 0)
    }

    private var chromeAnimation: Animation? {
        if reduceMotion || visibility.isKeyboardVisible { return nil }
        return .snappy(duration: 0.24, extraBounce: 0)
    }

    private var menuAnimation: Animation? {
        if reduceMotion || visibility.isKeyboardVisible { return nil }
        return .snappy(duration: 0.2, extraBounce: 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if menuOpen {
                Color.black.opacity(0.40)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)
                    .accessibilityLabel(RecvelL10n.text("common.closeMenu"))
                    .accessibilityIdentifier("tabbar.menu.scrim")
            }

            VStack(spacing: 12) {
                if menuOpen {
                    quickActionMenu
                        .transition(.opacity)
                }

                barChrome
            }
            .padding(.bottom, 2)
        }
        .modifier(TabBarChromeMotion(mode: visibility.mode, reduceMotion: reduceMotion))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabbar")
        .onAppear {
            highlight = selection
            Haptics.prepare()
        }
        .onChange(of: selection) { _, newValue in
            if highlight != newValue {
                highlight = newValue
            }
            if menuOpen { closeMenu() }
        }
        .onChange(of: visibility.mode) { _, mode in
            if mode != .expanded, menuOpen { closeMenu() }
        }
    }

    // MARK: - Bar chrome (expanded ↔ minimized)

    private var barChrome: some View {
        HStack(spacing: visibility.isMinimized ? 0 : 10) {
            if visibility.isMinimized {
                compactTabButton
                Spacer(minLength: 0)
            } else {
                expandedCapsule
            }

            fabButton
        }
        .padding(.horizontal, visibility.isMinimized ? 20 : 14)
        .animation(chromeAnimation, value: visibility.mode)
        .animation(menuAnimation, value: menuOpen)
    }

#if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glassWrappedCapsule: some View {
        GlassEffectContainer(spacing: 8) { expandedCapsuleInner }
    }
#endif

    private var expandedCapsule: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassWrappedCapsule
        } else {
            expandedCapsuleInner
        }
#else
        expandedCapsuleInner
#endif
    }

    private var expandedCapsuleInner: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    select(tab)
                } label: {
                    tabLabel(tab)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            // Cheap per-tab pill (no matchedGeometry) — paints in the same frame as the tap.
                            Capsule()
                                .fill(accent.opacity(0.16))
                                .overlay {
                                    Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 0.7)
                                }
                                .opacity(highlight == tab ? 1 : 0)
                                .scaleEffect(highlight == tab ? 1 : 0.88)
                        }
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(highlight == tab ? [.isSelected] : [])
            }
        }
        .padding(5)
        .platformGlass(tint: accent.opacity(0.10), shape: .capsule)
        .animation(pillAnimation, value: highlight)
    }

    /// Minimized leading control: current tab icon. Tap expands the bar.
    private var compactTabButton: some View {
        Button {
            Haptics.soft()
            withAnimation(chromeAnimation) {
                visibility.expand()
            }
        } label: {
            Image(systemName: highlight.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
                .platformGlass(tint: accent.opacity(0.14), interactive: true, shape: .circle)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityIdentifier("tab.compact.\(highlight.rawValue)")
        .accessibilityLabel("Expandir navegacion · \(highlight.title)")
    }

    // MARK: - FAB (+ ↔ x) + menu

    private var fabButton: some View {
        Button {
            toggleMenu()
        } label: {
            Image(systemName: menuOpen ? "xmark" : "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
                .rotationEffect(.degrees(menuOpen ? 90 : 0))
                .platformGlass(
                    tint: menuOpen ? ScoreKind.strain.color.opacity(0.28) : accent.opacity(0.14),
                    interactive: true,
                    shape: .circle
                )
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityIdentifier(menuOpen ? "tabbar.fab.close" : "tabbar.fab.open")
        .accessibilityLabel(RecvelL10n.text(menuOpen ? "a11y.closeActions" : "a11y.quickActions"))
    }

    private var quickActionMenu: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(TabQuickAction.allCases) { action in
                quickActionRow(action)
            }
        }
        .padding(.trailing, visibility.isMinimized ? 20 : 14)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func quickActionRow(_ action: TabQuickAction) -> some View {
        Button {
            perform(action)
        } label: {
            HStack(spacing: 10) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(action.color)
                    .frame(width: 40, height: 40)
                    .platformGlass(tint: action.color.opacity(0.18), interactive: true, shape: .circle)
            }
            .padding(.leading, 12)
            .padding(.vertical, 3)
            .padding(.trailing, 3)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    }
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityIdentifier("tabbar.action.\(action.rawValue)")
        .accessibilityLabel(action.title)
    }

    // MARK: - Helpers

    private var accent: Color { Color(red: 0.204, green: 0.827, blue: 0.600) }

    private func select(_ tab: AppTab) {
        if menuOpen { menuOpen = false }

        // Tick de seleccion: pill + iconos se sienten instantaneos.
        if highlight != tab {
            Haptics.selection()
        }

        // 1) Pill + icon colors move immediately (cheap).
        withAnimation(pillAnimation) {
            highlight = tab
        }

        guard selection != tab else { return }

        // 2) Heavy page swap waits one run-loop turn so the highlight isn't blocked
        //    by Dashboard/Fitness layout + HealthKit work on first mount.
        Task { @MainActor in
            await Task.yield()
            selection = tab
        }
    }

    private func toggleMenu() {
        if menuOpen {
            Haptics.soft()
        } else {
            Haptics.rigid()
        }
        withAnimation(menuAnimation) {
            menuOpen.toggle()
            if menuOpen, visibility.isMinimized {
                visibility.expand()
            }
        }
    }

    private func closeMenu() {
        Haptics.soft()
        withAnimation(menuAnimation) {
            menuOpen = false
        }
    }

    private func perform(_ action: TabQuickAction) {
        Haptics.medium()
        withAnimation(menuAnimation) {
            menuOpen = false
        }
        if let tab = action.tab {
            select(tab)
        } else if action == .settings {
            select(.today)
            visibility.openSettings()
        } else if action == .plan {
            select(.today)
            visibility.openPlan()
        }
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        VStack(spacing: 2) {
            Image(systemName: tab.icon)
                .font(.system(size: 15, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(highlight == tab ? accent : .secondary)
    }
}

/// Instant press scale — no spring, so it never delays the tap.
/// Soft haptic on finger-down for floating chrome (tabs, FAB, quick actions).
private struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.soft() }
            }
    }
}

/// Only **hidden** slides away. Minimize/expand is handled by the chrome itself.
private struct TabBarChromeMotion: ViewModifier {
    let mode: TabBarVisibility.Mode
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let hidden = mode == .hidden
        content
            .offset(y: hidden ? 120 : 0)
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .accessibilityHidden(hidden)
            .animation(
                reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0),
                value: hidden
            )
    }
}

// MARK: - Haptic Feedback Helper
func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

// MARK: - Stardust (referencia Bevel)

/// Polvo estelar flotante como el de la pantalla Bio Age de Bevel
/// (`Bevel_references/BioAge_revel.mp4`, verificado con diffs de frames a
/// 10 fps: cientos de motas diminutas derivan lentamente por TODA la pantalla
/// mientras titilan; no es un fondo estatico).
///
/// Cada mota tiene direccion propia (angulo aureo: quedan repartidas), una
/// velocidad de 4-14 pt/s y titileo sinusoidal propio. Las posiciones se
/// envuelven en los bordes, asi que la deriva es continua. Con Reduce Motion
/// el campo queda estatico (t = 0).
struct StardustField: View {
    var tint: Color = .white
    var count: Int = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                guard size.width > 1, size.height > 1 else { return }
                let t: Double = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<count {
                    let seed = Double(index)
                    let direction = seed * 2.399963
                    let speed = 4.0 + (seed * 7.31).truncatingRemainder(dividingBy: 10)
                    let baseX = (sin(seed * 78.233) * 0.5 + 0.5) * size.width
                    let baseY = (cos(seed * 43.771) * 0.5 + 0.5) * size.height

                    var x = (baseX + CGFloat(cos(direction) * speed * t)).truncatingRemainder(dividingBy: size.width)
                    var y = (baseY + CGFloat(sin(direction) * speed * t)).truncatingRemainder(dividingBy: size.height)
                    if x < 0 { x += size.width }
                    if y < 0 { y += size.height }

                    let twinkle = 0.55 + 0.45 * sin(t * (0.6 + (seed * 0.53).truncatingRemainder(dividingBy: 0.9)) + seed * 1.7)
                    let isMote = index.isMultiple(of: 11)
                    let radius: CGFloat = isMote ? 2.6 : 1.0 + CGFloat((seed * 0.37).truncatingRemainder(dividingBy: 1.2))
                    let alpha = (isMote ? 0.55 : 0.28) * twinkle
                    let rect = CGRect(x: x - radius / 2, y: y - radius / 2, width: radius, height: radius)

                    if isMote {
                        // Halo suave alrededor de las motas grandes.
                        let halo = rect.insetBy(dx: -radius * 2, dy: -radius * 2)
                        context.fill(
                            Path(ellipseIn: halo),
                            with: .radialGradient(
                                Gradient(colors: [tint.opacity(alpha * 0.35), .clear]),
                                center: CGPoint(x: halo.midX, y: halo.midY),
                                startRadius: 0,
                                endRadius: halo.width / 2
                            )
                        )
                    }
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Grafica neon (lenguaje Revel para tendencias)

/// Tendencia con estetica neon: linea gruesa con halo, matriz de puntos bajo la
/// curva, relleno degradado tenue y anillo hueco en el ultimo dato.
///
/// Sustituye a los `Chart` de Swift Charts de las tarjetas de Entrenamiento.
/// Se dibuja en un solo `Canvas` porque la matriz de puntos va **recortada al
/// area bajo la curva**, algo que Swift Charts no expresa; ademas evita montar
/// un motor de graficas entero para una sparkline sin ejes ni etiquetas.
///
/// El color lo pone quien la usa: cada metrica conserva su identidad (carga en
/// ambar, cardio en morado…) y solo se comparte el estilo.
struct NeonTrendChart: View {
    /// Valores en orden cronologico. Con menos de 2 no se dibuja nada.
    let values: [Double]
    let color: Color
    /// Escala fija opcional. Si es `nil` se ajusta a los datos.
    var domain: ClosedRange<Double>?
    /// Anillo en el ultimo punto, como en la referencia.
    var showsEndMarker: Bool = true

    private let dotSpacing: CGFloat = 9
    private let lineWidth: CGFloat = 3.4

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }

            // Fantasma de carga: un `Canvas` se dibuja a mano, asi que
            // `.redacted` no lo afecta y sin esto la tarjeta en esqueleto
            // dejaba un hueco vacio. Con menos de 2 datos pintamos la matriz y
            // una linea base tenues, que bajo el barrido del esqueleto se leen
            // como grafica cargando.
            guard values.count >= 2 else {
                var y = dotSpacing / 2
                while y < size.height {
                    var x = dotSpacing / 2
                    while x < size.width {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)),
                            with: .color(.white.opacity(0.05))
                        )
                        x += dotSpacing
                    }
                    y += dotSpacing
                }
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height * 0.72))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height * 0.72))
                context.stroke(baseline, with: .color(.white.opacity(0.08)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                return
            }

            let lower: Double
            let upper: Double
            if let domain {
                lower = domain.lowerBound
                upper = domain.upperBound
            } else {
                let minimum = values.min() ?? 0
                let maximum = values.max() ?? 1
                // Aire arriba y abajo para que la curva no toque los bordes.
                let padding = max((maximum - minimum) * 0.18, 0.5)
                lower = minimum - padding
                upper = maximum + padding
            }
            let span = max(upper - lower, 0.0001)

            // El trazo tiene grosor: se reserva su radio para que no se recorte.
            let inset = lineWidth / 2 + 2
            let usableHeight = max(size.height - inset * 2, 1)
            // Y a la derecha, el radio del anillo final: sin esto se dibujaba
            // justo en el borde y salia cortado por la mitad.
            let trailingInset: CGFloat = showsEndMarker ? 9 : inset
            let usableWidth = max(size.width - trailingInset, 1)
            let points: [CGPoint] = values.enumerated().map { index, value in
                let x = usableWidth * CGFloat(index) / CGFloat(values.count - 1)
                let normalized = (value - lower) / span
                let y = inset + usableHeight * CGFloat(1 - min(max(normalized, 0), 1))
                return CGPoint(x: x, y: y)
            }

            let line = Self.smoothPath(through: points)
            var area = line
            area.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
            area.addLine(to: CGPoint(x: points[0].x, y: size.height))
            area.closeSubpath()

            // 1. Matriz de puntos, recortada bajo la curva. Se apaga hacia la
            //    izquierda y hacia abajo para dar profundidad.
            var matrix = context
            matrix.clip(to: area)
            var y = dotSpacing / 2
            while y < size.height {
                var x = dotSpacing / 2
                while x < size.width {
                    let horizontal = x / size.width
                    let vertical = 1 - (y / size.height)
                    let intensity = (0.22 + 0.55 * horizontal) * (0.35 + 0.65 * vertical)
                    matrix.fill(
                        Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)),
                        with: .color(color.opacity(intensity * 0.85))
                    )
                    x += dotSpacing
                }
                y += dotSpacing
            }

            // 2. Relleno degradado, muy tenue: da cuerpo sin tapar la matriz.
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.20), color.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            // 3. Halo: el mismo trazo desenfocado debajo del principal.
            var glow = context
            glow.addFilter(.blur(radius: 7))
            glow.stroke(line, with: .color(color.opacity(0.75)),
                        style: StrokeStyle(lineWidth: lineWidth + 3, lineCap: .round, lineJoin: .round))

            // 4. Trazo principal, con el centro aclarado (efecto tubo de neon).
            context.stroke(line, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(.white.opacity(0.35)),
                           style: StrokeStyle(lineWidth: lineWidth * 0.35, lineCap: .round, lineJoin: .round))

            // 5. Anillo del ultimo dato: hueco, como en la referencia.
            if showsEndMarker, let end = points.last {
                let outer = CGRect(x: end.x - 6.5, y: end.y - 6.5, width: 13, height: 13)
                var ringGlow = context
                ringGlow.addFilter(.blur(radius: 6))
                ringGlow.stroke(Path(ellipseIn: outer), with: .color(color), lineWidth: 3)
                context.fill(Path(ellipseIn: outer), with: .color(.black.opacity(0.85)))
                context.stroke(Path(ellipseIn: outer), with: .color(color), lineWidth: 3)
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }

    /// Catmull-Rom a Bezier cubica: curva suave que **pasa por** los datos, a
    /// diferencia de suavizar con puntos de control inventados.
    private static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            for point in points.dropFirst() { path.addLine(to: point) }
            return path
        }
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }
}

// MARK: - Estado de carga unificado

/// Fase de carga de un componente.
///
/// Es el vocabulario compartido de toda la app: cada tarjeta declara la suya y
/// se pinta en consecuencia. **Deliberadamente por componente y no por
/// pantalla**: antes Home cambiaba TODO el contenido por un cartel de "Leyendo
/// Apple Health", asi que una sola consulta lenta escondia datos que ya
/// estaban listos. Ahora cada tarjeta que ya tiene lo suyo lo pinta, y solo las
/// que siguen esperando muestran esqueleto.
enum LoadPhase: Equatable {
    /// Sin datos todavia: se muestra el esqueleto.
    case loading
    /// Hay datos que pintar.
    case ready
    /// Termino de cargar y no hay nada que mostrar (estado vacio, no esqueleto).
    case empty

    var isLoading: Bool { self == .loading }

    /// Combina dependencias: una tarjeta que necesita varias fuentes sigue en
    /// `.loading` mientras cualquiera lo este, y solo esta vacia si todas lo estan.
    static func combined(_ phases: [LoadPhase]) -> LoadPhase {
        if phases.contains(.loading) { return .loading }
        return phases.contains(.ready) ? .ready : .empty
    }
}

/// Componente que sabe declarar su propia fase de carga.
///
/// Implementarlo obliga a cada tarjeta a responder "¿tengo ya mis datos?" sin
/// consultar un estado global, que es lo que permite que carguen a ritmos
/// distintos sin bloquearse entre si.
protocol LoadableComponent: View {
    var phase: LoadPhase { get }
}

extension LoadableComponent {
    /// Aplica el esqueleto segun la fase declarada por el componente.
    func withSkeleton() -> some View { skeleton(phase) }
}

/// Barrido de brillo del esqueleto. Se para con Reduce Motion.
private struct SkeletonShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.16), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: max(width * 0.5, 40))
            .offset(x: sweep ? width : -width * 0.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SkeletonModifier: ViewModifier {
    let phase: LoadPhase

    func body(content: Content) -> some View {
        content
            // `.redacted` reutiliza el layout REAL como esqueleto: los bloques
            // grises salen con el tamaño y la posicion definitivos, asi que no
            // hay una vista-esqueleto paralela que mantener sincronizada.
            .redacted(reason: phase.isLoading ? .placeholder : [])
            .overlay {
                if phase.isLoading {
                    SkeletonShimmer().clipped()
                }
            }
            // Un esqueleto no se toca: evita navegar a una tarjeta aun sin datos.
            .disabled(phase.isLoading)
            .accessibilityHidden(phase.isLoading)
            .animation(.easeOut(duration: 0.32), value: phase)
    }
}

extension View {
    /// Muestra este componente como esqueleto mientras `phase` sea `.loading`.
    func skeleton(_ phase: LoadPhase) -> some View {
        modifier(SkeletonModifier(phase: phase))
    }
}

/// Bloque de esqueleto explicito.
///
/// Para lo que `.redacted` no puede cubrir: un `Canvas` (las graficas neon) se
/// dibuja a mano y la redaccion no lo toca, asi que ahi hace falta un
/// marcador con la altura real del grafico.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }
}

// MARK: - Superficie "inteligente" (borde iridiscente animado)

/// Superficie con borde iridiscente animado, en la linea de como Apple destaca
/// sus componentes de Apple Intelligence.
///
/// Se reserva para lo que **interpreta o estima**, no para lo que informa: en
/// Nutricion la lleva "Registrar comida", donde la app estima macros a partir
/// de texto, foto, voz o codigo de barras. Igual que `emphasized` en
/// `RevelSurface`, pierde todo su valor si se usa en mas de un sitio por
/// pantalla.
///
/// La tecnica: varios trazos de un `AngularGradient` con distintos grosores y
/// desenfoques —eso da la profundidad del halo— y el degradado girando
/// lentamente. Con Reduce Motion se queda quieto: el borde sigue ahi, solo deja
/// de rotar.
/// Secuencia iridiscente violeta → azul → cian → rosa → naranja → dorado.
/// El primer tono se repite al final para que el ciclo cierre sin costura.
///
/// Vive fuera de `IntelligenceSurface` porque Swift no admite propiedades
/// estaticas almacenadas en tipos genericos.
private enum IntelligenceSpectrum {
    static let colors: [Color] = [
        Color(red: 0.60, green: 0.35, blue: 0.96),
        Color(red: 0.30, green: 0.56, blue: 0.98),
        Color(red: 0.26, green: 0.82, blue: 0.90),
        Color(red: 0.95, green: 0.45, blue: 0.72),
        Color(red: 0.98, green: 0.60, blue: 0.33),
        Color(red: 0.98, green: 0.78, blue: 0.30),
        Color(red: 0.60, green: 0.35, blue: 0.96)
    ]
}

struct IntelligenceSurface<Outline: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La forma la decide quien lo usa: tarjeta redondeada o capsula. El borde
    /// iridiscente es el mismo; lo unico que cambia es por donde corre.
    var outline: Outline
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        let shape = outline
        let gradient = AngularGradient(
            gradient: Gradient(colors: IntelligenceSpectrum.colors),
            center: .center,
            angle: .degrees(angle)
        )

        return content
            .background {
                ZStack {
                    shape.fill(Color(red: 0.098, green: 0.104, blue: 0.121))
                    // Tinte del relleno: muy desenfocado y muy diluido, solo
                    // para que el interior no quede gris muerto junto al borde.
                    shape.fill(gradient)
                        .blur(radius: 34)
                        .opacity(0.16)
                }
                .clipShape(shape)
            }
            .overlay {
                ZStack {
                    // Capa difusa: el halo.
                    shape.strokeBorder(gradient, lineWidth: 3.5)
                        .blur(radius: 8)
                        .opacity(0.6)
                    // Capa nitida: el filo del borde.
                    shape.strokeBorder(gradient, lineWidth: 1.4)
                        .opacity(0.95)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

extension View {
    /// Borde iridiscente animado sobre una tarjeta redondeada. Ver
    /// `IntelligenceSurface` antes de usarlo: es para componentes que estiman o
    /// interpretan, uno por pantalla.
    func intelligenceSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(IntelligenceSurface(outline: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    /// La misma superficie sobre una capsula, para los entrypoints de fila.
    func intelligenceCapsule() -> some View {
        modifier(IntelligenceSurface(outline: Capsule(style: .continuous)))
    }
}

/// Cabecera de seccion del lenguaje "laboratorio": titulo en mayusculas con
/// kerning, filete que ocupa el hueco y una nota a la derecha.
///
/// Es la firma tipografica del Reporte del dia. Se extrajo aqui para que otras
/// pantallas puedan hablar ese idioma sin copiar la maquetacion.
struct LabSectionHeader: View {
    let title: String
    var caption: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black))
                .kerning(1.4)
                .foregroundStyle(tint)
            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(height: 1)
            if let caption {
                Text(caption.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Fondo del lenguaje "laboratorio" **en version contenida**: el degradado casi
/// negro y UNA nebulosa tenue, sin el campo de estrellas ni el polvo animado del
/// Reporte del dia. Da el mismo aire sin robar atencion a una pantalla donde el
/// usuario viene a escribir.
struct LabBackdropLite: View {
    var tint: Color = Color(red: 0.98, green: 0.80, blue: 0.35)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.105, green: 0.110, blue: 0.125),
                         Color(red: 0.043, green: 0.046, blue: 0.056)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [tint.opacity(0.16), .clear],
                center: .init(x: 0.85, y: 0.02),
                startRadius: 8,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.36, green: 0.92, blue: 0.66).opacity(0.07), .clear],
                center: .init(x: 0.08, y: 0.18),
                startRadius: 8,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}
