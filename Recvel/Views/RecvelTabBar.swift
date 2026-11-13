import SwiftUI
import UIKit

// MARK: - Barra de pestañas de Recvel
//
// Comportamiento tomado de Bevel:
// - Expandida: capsula con las pestañas y, aparte, un "+" circular a la derecha.
// - Al bajar el scroll: la capsula se reduce a un circulo con la pestaña
//   actual; el "+" se queda donde esta.
// - "+": abre un panel de acciones en cuadricula SOBRE la barra y el "+" gira
//   a "×". Tocar fuera lo cierra.
// - En una pantalla de detalle: la barra entera sale por abajo.
//
// Por que se rehizo. Cambiar de pestaña bloquea el hilo principal mientras se
// construye la pantalla nueva, y la barra anterior animaba su selector con
// SwiftUI, que corre en ese mismo hilo: el selector se trababa justo cuando el
// dedo acababa de tocar, y eso se percibia como "la barra tarda". Aqui:
// 1. El selector es un `CALayer` con `CASpringAnimation`: lo anima el servidor
//    de render, fuera del hilo principal, asi que no se traba aunque la app
//    este ocupada montando la pestaña.
// 2. La barra se pinta ANTES de cambiar de pestaña: `shown` cambia en el toque
//    y `selection` (lo caro) se difiere al siguiente ciclo.
// 3. El vidrio es CLARO, no esmerilado: el desenfoque del sistema va a una
//    fraccion de su fuerza, de modo que el contenido se sigue reconociendo
//    detras; el volumen lo dan una banda oscura interior y un filo fino.
// 4. El selector se comporta como una gota: al tocar sube bajo el dedo, crece
//    y se ilumina; al arrastrar lo sigue y se estira con la velocidad; al
//    soltar cae en la pestaña y se asienta con un rebote.

struct RecvelTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TabBarVisibility.self) private var visibility
    @Binding var selection: AppTab

    /// Lo que la barra muestra como seleccionado. Va un ciclo por delante de
    /// `selection`.
    @State private var shown: AppTab = .today
    @State private var menuOpen = false

    private static let tabs: [AppTab] = [.today, .journal, .nutrition, .fasting, .fitness]
    private static let height: CGFloat = 58
    private static let panelColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
    private static let accent = Color(red: 0.204, green: 0.827, blue: 0.600)

    /// Corta y sin rebote: el panel no debe "llegar tarde" tras el toque.
    private var menuAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var chromeAnimation: Animation? {
        reduceMotion || visibility.isKeyboardVisible ? nil : .spring(response: 0.34, dampingFraction: 0.84)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // El panel ya no lleva desenfoque propio ni entra con escala: eso
            // obligaba a recalcular blur y sombra en cada cuadro y era el
            // tiron al abrir y cerrar. Ahora es una superficie plana que solo
            // cambia opacidad y desplazamiento. No se deja premontado: oculto
            // seguia tapando lo que tenia detras para accesibilidad.
            if menuOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { setMenu(false) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 12) {
                if menuOpen {
                    actionPanel
                        .transition(.opacity.combined(with: .offset(y: 18)))
                }
                barRow
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: visibility.isHidden ? 150 : 0)
        .opacity(visibility.isHidden ? 0 : 1)
        .allowsHitTesting(!visibility.isHidden)
        .accessibilityHidden(visibility.isHidden)
        .animation(chromeAnimation, value: visibility.mode)
        .animation(menuAnimation, value: menuOpen)
        .onAppear { shown = selection }
        .onChange(of: selection) { _, new in shown = new }
        .onChange(of: visibility.mode) { _, mode in
            if mode != .expanded, menuOpen { menuOpen = false }
        }
    }

    // MARK: Fila: pestañas + accion

    private var barRow: some View {
        HStack(spacing: 10) {
            if visibility.isMinimized {
                compactTab
                    .transition(.scale(scale: 0.7, anchor: .leading).combined(with: .opacity))
                Spacer(minLength: 0)
            } else {
                tabCapsule
                    .transition(.scale(scale: 0.92, anchor: .leading).combined(with: .opacity))
            }
            actionButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabbar")
    }

    private var tabCapsule: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.self) { tab in tabLabel(tab) }
        }
        .padding(4)
        .frame(height: Self.height)
        .background {
            // Toques y gota viven en UNA vista UIKit bajo las etiquetas: toda
            // la interaccion corre en Core Animation.
            TabDroplet(
                index: Self.tabs.firstIndex(of: shown) ?? 0,
                count: Self.tabs.count,
                inset: 4,
                reduceMotion: reduceMotion,
                onPreview: { shown = Self.tabs[$0] },
                onCommit: { select(Self.tabs[$0]) }
            )
        }
        .background(LiquidGlass(shape: Capsule(style: .continuous)))
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        let selected = shown == tab
        return VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(height: 20)
            Text(tab.title)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(selected ? Self.accent : Color.white.opacity(0.62))
        // Lo que queda bajo la gota se ve algo aumentado, como a traves de ella.
        .scaleEffect(selected ? 1.08 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.62), value: selected)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(false)   // los toques van a la gota, debajo
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityAction { select(tab) }
    }

    /// Circulo con la pestaña actual (modo minimizado). Tocarlo re-expande.
    private var compactTab: some View {
        Button {
            Haptics.soft()
            visibility.expand()
        } label: {
            Image(systemName: shown.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Self.accent)
                .frame(width: Self.height, height: Self.height)
                .background(LiquidGlass(shape: Circle()))
                .contentShape(Circle())
        }
        .buttonStyle(DropletPressStyle())
        .accessibilityLabel(shown.title)
        .accessibilityIdentifier("tab.compact.\(shown.rawValue)")
    }

    // MARK: Boton de accion

    private var actionButton: some View {
        Button {
            setMenu(!menuOpen)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(menuOpen ? 45 : 0))
                .frame(width: Self.height, height: Self.height)
                .background(LiquidGlass(shape: Circle(), highlighted: menuOpen))
                .contentShape(Circle())
        }
        .buttonStyle(DropletPressStyle())
        .accessibilityLabel(RecvelL10n.text(menuOpen ? "common.close" : "tabbar.actions"))
        .accessibilityIdentifier(menuOpen ? "tabbar.fab.close" : "tabbar.fab.open")
    }

    /// Panel de acciones: cuadricula de icono + etiqueta, como el de Bevel.
    private var actionPanel: some View {
        LazyVGrid(columns: Self.panelColumns, spacing: 6) {
            ForEach(TabQuickAction.allCases) { action in
                Button { perform(action) } label: {
                    VStack(spacing: 9) {
                        Image(systemName: action.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(height: 28)
                        Text(action.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DropletPressStyle())
                .accessibilityIdentifier("tabbar.action.\(action.rawValue)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(PanelSurface())
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("tabbar.actionPanel")
    }

    // MARK: Acciones

    private func select(_ tab: AppTab) {
        if menuOpen { menuOpen = false }
        if shown != tab { Haptics.selection() }
        shown = tab
        guard selection != tab else { return }
        // Montar la pestaña puede ocupar el hilo principal varios cuadros.
        // Este cuadro —selector y color— llega a pantalla primero.
        DispatchQueue.main.async { selection = tab }
    }

    private func setMenu(_ open: Bool) {
        if open { Haptics.rigid() } else { Haptics.soft() }
        if open, visibility.isMinimized { visibility.expand() }
        menuOpen = open
    }

    private func perform(_ action: TabQuickAction) {
        Haptics.medium()
        menuOpen = false
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
}

/// Fondo del panel de acciones. Sin desenfoque en vivo a proposito: va sobre
/// un velo oscuro, donde el blur apenas se aprecia, y asi animarlo cuesta lo
/// mismo que animar un rectangulo.
private struct PanelSurface: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        shape
            .fill(Color(red: 0.085, green: 0.095, blue: 0.105).opacity(0.96))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.08), .white.opacity(0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Vidrio liquido

/// Vidrio claro para controles flotantes (aproximacion en iOS 17/18; el
/// material real con refraccion solo existe en el SDK de iOS 26).
///
/// De atras hacia delante: fondo apenas desenfocado, un tinte leve para que el
/// contenido blanco se lea, una banda oscura interior que da grosor y aspecto
/// abombado, una banda clara, y el filo: toda la luz del vidrio vive en el
/// borde, mas fuerte arriba y abajo, como un labio que la atrapa.
private struct LiquidGlass<S: InsettableShape>: View {
    let shape: S
    var highlighted = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(intensity: 0.32)
            Color(red: 0.03, green: 0.035, blue: 0.04).opacity(highlighted ? 0.12 : 0.30)
            shape.stroke(.black.opacity(0.50), lineWidth: 10)
                .blur(radius: 7)
            shape.strokeBorder(.white.opacity(0.12), lineWidth: 2.5)
                .blur(radius: 1.5)
                .blendMode(.plusLighter)
            if highlighted { Color.white.opacity(0.14) }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.62), location: 0),
                        .init(color: .white.opacity(0.20), location: 0.22),
                        .init(color: .white.opacity(0.10), location: 0.62),
                        .init(color: .white.opacity(0.36), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
        .allowsHitTesting(false)
    }
}

/// Desenfoque del sistema rebajado a una fraccion de su fuerza.
///
/// `UIBlurEffect` no tiene radio: el efecto se instala con un animador, se
/// lleva a `intensity` y el animador se RETIRA dejando el efecto congelado. No
/// se deja pausado: un animador pausado cuenta como animacion en curso para
/// siempre (los UI tests nunca ven la app en reposo). Se reconstruye al volver
/// a primer plano.
private struct LiquidGlassBackdrop: UIViewRepresentable {
    var intensity: CGFloat

    func makeUIView(context: Context) -> BackdropView { BackdropView(intensity: intensity) }
    func updateUIView(_ view: BackdropView, context: Context) {}

    final class BackdropView: UIVisualEffectView {
        private let intensity: CGFloat

        init(intensity: CGFloat) {
            self.intensity = intensity
            super.init(effect: nil)
            isUserInteractionEnabled = false
            for name in [UIApplication.willEnterForegroundNotification,
                         UIApplication.didBecomeActiveNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(rebuild), name: name, object: nil)
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("unsupported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { rebuild() }
        }

        @objc private func rebuild() {
            effect = nil
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
                self?.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            }
            animator.fractionComplete = min(max(intensity, 0), 1)
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
    }
}

/// Pulsacion de gota para un control suelto: crece bajo el dedo, se aclara y
/// vuelve con un rebote.
private struct DropletPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Capsule(style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.14 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 1.14 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }
    }
}

// MARK: - La gota (selector)

/// El selector y todo lo que lo hace comportarse como una gota de agua. Es
/// Core Animation a proposito: los resortes corren en el servidor de render y
/// siguen fluidos mientras el hilo principal construye la pestaña nueva.
private struct TabDroplet: UIViewRepresentable {
    let index: Int
    let count: Int
    let inset: CGFloat
    let reduceMotion: Bool
    let onPreview: (Int) -> Void
    let onCommit: (Int) -> Void

    func makeUIView(context: Context) -> DropletView {
        let view = DropletView()
        view.count = count
        view.inset = inset
        view.index = index
        view.reduceMotion = reduceMotion
        view.onPreview = onPreview
        view.onCommit = onCommit
        return view
    }

    func updateUIView(_ view: DropletView, context: Context) {
        view.count = count
        view.inset = inset
        view.reduceMotion = reduceMotion
        view.onPreview = onPreview
        view.onCommit = onCommit
        view.settle(on: index)
    }

    final class DropletView: UIView {
        var index = 0
        var count = 1
        var inset: CGFloat = 0
        var reduceMotion = false
        var onPreview: (Int) -> Void = { _ in }
        var onCommit: (Int) -> Void = { _ in }

        private let glowClip = CALayer()
        private let glow = CAGradientLayer()
        private let lens = CALayer()
        private let tick = UISelectionFeedbackGenerator()
        private var touching = false
        private var hovered = 0
        private var lastX: CGFloat = 0
        private var lastTime: CFTimeInterval = 0
        private var stretch: CGFloat = 0

        private static let lift: CGFloat = 1.2

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear

            // Luz que florece en el vidrio de la barra en el punto de contacto.
            glowClip.masksToBounds = true
            glowClip.cornerCurve = .continuous
            layer.addSublayer(glowClip)
            glow.type = .radial
            glow.colors = [UIColor.white.withAlphaComponent(0.26).cgColor,
                           UIColor.white.withAlphaComponent(0).cgColor]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            glow.bounds = CGRect(x: 0, y: 0, width: 190, height: 190)
            glow.opacity = 0
            glowClip.addSublayer(glow)

            lens.backgroundColor = UIColor.white.withAlphaComponent(0.12).cgColor
            lens.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
            lens.borderWidth = 0
            lens.cornerCurve = .continuous
            lens.shadowColor = UIColor.black.cgColor
            lens.shadowOpacity = 0
            lens.shadowRadius = 10
            lens.shadowOffset = CGSize(width: 0, height: 5)
            layer.addSublayer(lens)

            let press = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
            press.minimumPressDuration = 0
            press.allowableMovement = .greatestFiniteMagnitude
            addGestureRecognizer(press)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("unsupported") }

        // MARK: Geometria

        private var slotWidth: CGFloat { (bounds.width - inset * 2) / CGFloat(max(count, 1)) }

        private func slotCenter(_ index: Int) -> CGPoint {
            CGPoint(x: inset + slotWidth * (CGFloat(index) + 0.5), y: bounds.midY)
        }

        private func slot(at x: CGFloat) -> Int {
            guard slotWidth > 0 else { return 0 }
            return min(max(Int((x - inset) / slotWidth), 0), count - 1)
        }

        private func clampedX(_ x: CGFloat) -> CGFloat {
            min(max(x, slotCenter(0).x), slotCenter(count - 1).x)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glowClip.frame = bounds
            glowClip.cornerRadius = bounds.height / 2
            lens.bounds = CGRect(x: 0, y: 0, width: slotWidth, height: bounds.height - inset * 2)
            lens.cornerRadius = lens.bounds.height / 2
            if !touching { lens.position = slotCenter(index) }
            CATransaction.commit()
        }

        // MARK: Animacion
        // Toda animacion parte de lo que hay EN PANTALLA (la capa de
        // presentacion), para poder interrumpirse sin saltos.

        private func spring(_ layer: CALayer, _ keyPath: String, to value: Any,
                            stiffness: CGFloat, damping: CGFloat) {
            guard !reduceMotion else { set(layer, keyPath, value); return }
            let animation = CASpringAnimation(keyPath: keyPath)
            animation.fromValue = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
            animation.toValue = value
            animation.mass = 1
            animation.stiffness = stiffness
            animation.damping = damping
            animation.duration = animation.settlingDuration
            set(layer, keyPath, value)
            layer.add(animation, forKey: keyPath)
        }

        private func ease(_ layer: CALayer, _ keyPath: String, to value: Any, duration: CFTimeInterval) {
            guard !reduceMotion else { set(layer, keyPath, value); return }
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
            animation.toValue = value
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            set(layer, keyPath, value)
            layer.add(animation, forKey: keyPath)
        }

        private func set(_ layer: CALayer, _ keyPath: String, _ value: Any) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.setValue(value, forKeyPath: keyPath)
            CATransaction.commit()
        }

        private func scale(_ x: CGFloat, _ y: CGFloat) -> NSValue {
            NSValue(caTransform3D: CATransform3DMakeScale(x, y, 1))
        }

        /// Levantada: una gota mas clara, con filo, que sobresale de la barra.
        private func setLifted(_ lifted: Bool) {
            let duration = lifted ? 0.16 : 0.32
            ease(lens, "backgroundColor",
                 to: UIColor.white.withAlphaComponent(lifted ? 0.20 : 0.12).cgColor, duration: duration)
            ease(lens, "borderWidth", to: lifted ? 1.0 : 0.0, duration: duration)
            ease(lens, "shadowOpacity", to: lifted ? Float(0.34) : Float(0), duration: duration)
            ease(glow, "opacity", to: lifted ? Float(1) : Float(0), duration: lifted ? 0.14 : 0.45)
        }

        // MARK: Toque

        @objc private func handle(_ press: UILongPressGestureRecognizer) {
            let point = press.location(in: self)
            switch press.state {
            case .began:
                touching = true
                hovered = slot(at: point.x)
                lastX = point.x
                lastTime = CACurrentMediaTime()
                stretch = 0
                set(glow, "position", NSValue(cgPoint: point))
                setLifted(true)
                // La gota corre al dedo y se hincha al llegar.
                spring(lens, "position", to: NSValue(cgPoint: CGPoint(x: clampedX(point.x), y: bounds.midY)),
                       stiffness: 420, damping: 30)
                spring(lens, "transform", to: scale(Self.lift, Self.lift), stiffness: 380, damping: 17)
                if hovered != index { tick.selectionChanged(); onPreview(hovered) }

            case .changed:
                let now = CACurrentMediaTime()
                let velocity = (point.x - lastX) / CGFloat(max(now - lastTime, 0.001))
                lastX = point.x
                lastTime = now
                // La velocidad la estira larga y fina; se relaja al frenar.
                let target = min(abs(velocity) / 2600, 0.22)
                stretch += (target - stretch) * 0.35
                ease(lens, "position", to: NSValue(cgPoint: CGPoint(x: clampedX(point.x), y: bounds.midY)),
                     duration: 0.09)
                ease(lens, "transform", to: scale(Self.lift + stretch, Self.lift - stretch * 0.55),
                     duration: 0.12)
                set(glow, "position", NSValue(cgPoint: CGPoint(x: point.x, y: min(max(point.y, 0), bounds.height))))
                let over = slot(at: point.x)
                if over != hovered {
                    hovered = over
                    tick.selectionChanged()
                    onPreview(over)
                }

            case .ended, .cancelled, .failed:
                touching = false
                // Soltar lejos de la barra cancela, como en un control del sistema.
                let inside = bounds.insetBy(dx: -40, dy: -28).contains(point) && press.state == .ended
                let target = inside ? slot(at: point.x) : index
                index = target
                setLifted(false)
                // La gota cae en su sitio y se asienta con un rebote.
                spring(lens, "position", to: NSValue(cgPoint: slotCenter(target)), stiffness: 300, damping: 22)
                spring(lens, "transform", to: scale(1, 1), stiffness: 300, damping: 13)
                if inside { onCommit(target) } else { onPreview(target) }

            default:
                break
            }
        }

        /// La seleccion cambio desde fuera (enlace profundo, accion rapida).
        func settle(on newIndex: Int) {
            guard !touching, newIndex != index else { return }
            index = newIndex
            guard bounds.width > 0 else { return }
            spring(lens, "position", to: NSValue(cgPoint: slotCenter(newIndex)), stiffness: 300, damping: 24)
        }
    }
}
