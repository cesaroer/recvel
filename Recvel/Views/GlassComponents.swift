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
                    .trim(from: 0, to: animatedProgress)
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
                Text(score.kind.rawValue)
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
        .accessibilityLabel("\(score.kind.rawValue), \(score.value) de 100. Confianza \(score.confidence.rawValue)")
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
        case .today: "Hoy"
        case .journal: "Journal"
        case .fitness: "Fitness"
        case .nutrition: "Nutricion"
        case .fasting: "Ayuno"
        }
    }
}

/// Quick actions exposed by the floating FAB next to the tab bar (Bevel "+" pattern).
enum TabQuickAction: String, CaseIterable, Identifiable {
    case meal, journal, fasting, fitness, plan, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal: "Comida"
        case .journal: "Journal"
        case .fasting: "Ayuno"
        case .fitness: "Actividad"
        case .plan: "Plan"
        case .settings: "Ajustes"
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
                    .accessibilityLabel("Cerrar menu")
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
        .accessibilityLabel(menuOpen ? "Cerrar acciones" : "Acciones rapidas")
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
