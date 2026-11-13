import SwiftUI

// MARK: - Orbe

/// Esfera iridiscente del asistente. Se usa a dos tamaños: pequeña dentro del
/// entrypoint de Nutricion y grande como protagonista de esta pantalla.
///
/// El acabado "glossy" se compone por capas porque `MeshGradient` es iOS 18 y el
/// proyecto va a 17:
///
///  1. Un `RadialGradient` con el centro DESCENTRADO hacia arriba-izquierda —
///     ahi es donde entra la luz, y es lo que convierte un circulo plano en una
///     esfera.
///  2. Dos elipses desenfocadas girando muy lento en sentidos contrarios: el
///     remolino interno. Van dentro del clip del circulo.
///  3. Un realce especular pequeño y muy difuso arriba.
///  4. Filo tenue y sombra exterior del tono dominante.
///
/// Con Reduce Motion el remolino se queda quieto: la esfera sigue completa, solo
/// deja de moverse.
struct AssistantOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var diameter: CGFloat = 150

    /// Blanco → periwinkle → violeta. El nucleo casi blanco es lo que separa
    /// una esfera de cristal de una bola de plastico: sin el, el degradado se
    /// lee como un color plano con un brillo pegado encima.
    private static let deep = Color(red: 0.38, green: 0.34, blue: 0.84)
    private static let mid = Color(red: 0.60, green: 0.65, blue: 0.98)
    private static let light = Color(red: 0.93, green: 0.95, blue: 1.0)

    @Environment(\.isTabActive) private var isTabActive

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || !isTabActive)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                base
                swirl(phase: phase)
                specular
                rim
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            // Halo exterior ademas de la sombra: en la referencia la esfera
            // "tiñe" el fondo claro a su alrededor.
            .background {
                Circle()
                    .fill(Self.mid.opacity(0.32))
                    .blur(radius: diameter * 0.16)
                    .scaleEffect(1.06)
            }
            .shadow(color: Self.deep.opacity(0.22), radius: diameter * 0.13, y: diameter * 0.07)
        }
        .accessibilityHidden(true)
    }

    /// Cuerpo de la esfera: la luz entra por arriba-izquierda, asi que el
    /// degradado nace ahi y se apaga hacia el borde inferior derecho.
    private var base: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Self.light, location: 0),
                        .init(color: Self.light, location: 0.16),
                        .init(color: Self.mid, location: 0.55),
                        .init(color: Self.deep, location: 1)
                    ],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.86
                )
            )
    }

    /// Remolino interno. Dos elipses muy desenfocadas girando en sentidos
    /// opuestos; sin ellas la esfera se ve lisa como una pelota de plastico.
    private func swirl(phase: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.34))
                .frame(width: diameter * 0.72, height: diameter * 0.42)
                .blur(radius: diameter * 0.10)
                .offset(x: -diameter * 0.06, y: -diameter * 0.08)
                .rotationEffect(.degrees(phase * 9))

            Ellipse()
                .fill(Self.deep.opacity(0.55))
                .frame(width: diameter * 0.86, height: diameter * 0.38)
                .blur(radius: diameter * 0.12)
                .offset(x: diameter * 0.08, y: diameter * 0.14)
                .rotationEffect(.degrees(-phase * 6))
        }
    }

    /// Brillo especular: muy difuso y de poca opacidad. Un realce duro es
    /// justo lo que hace que una esfera parezca plastico.
    private var specular: some View {
        Ellipse()
            .fill(Color.white.opacity(0.38))
            .frame(width: diameter * 0.40, height: diameter * 0.24)
            .blur(radius: diameter * 0.10)
            .offset(x: -diameter * 0.10, y: -diameter * 0.24)
    }

    /// Filo apenas insinuado: en la referencia el borde es suave, casi sin
    /// contorno. Un `strokeBorder` marcado recorta la esfera contra el fondo.
    private var rim: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(diameter * 0.006, 0.6)
            )
    }
}

// MARK: - Entrypoints de Nutricion

/// Contenido de una puerta de entrada de Nutricion: elemento a la izquierda,
/// titulo + subtitulo, y flecha.
///
/// Las dos puertas de la pestaña —el asistente y el registro de comida—
/// comparten esta fila para que se lean como una familia y no diverjan cada vez
/// que se toque una. Lo unico que cambia entre ellas es el elemento de la
/// izquierda y el tratamiento del contorno, que es donde vive la jerarquia.
struct NutritionEntryRow<Leading: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 13) {
            leading()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Puerta de entrada al asistente.
///
/// **Sobre `IntelligenceSurface` y su regla de "una por pantalla".** Esta
/// capsula NO la usa: su luz esta contenida en el orbe. La superficie
/// iridiscente de Nutricion sigue siendo una sola, la de `recordFoodEntry`, que
/// es la que estima macros — justo el trabajo para el que se reservo.
struct NutritionAssistantEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NutritionEntryRow(
                title: RecvelL10n.text("nutrition.plan.entry.title"),
                detail: RecvelL10n.text("nutrition.plan.entry.detail")
            ) {
                AssistantOrb(diameter: 34)
            }
            .background(Color(red: 0.075, green: 0.078, blue: 0.094), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrition.planEntry")
        .accessibilityLabel(
            "\(RecvelL10n.text("nutrition.plan.entry.title")). \(RecvelL10n.text("nutrition.plan.entry.detail"))"
        )
    }
}

// MARK: - Pantalla

/// Recorrido breve por las capacidades del asistente de nutricion.
///
/// El contenido es una presentacion del producto, no un segundo espacio de
/// trabajo. Al terminar, el usuario vuelve al plan de nutricion desde el que
/// entro. Cada pagina describe una capacidad trazable del flujo local.
///
/// **Por que fondo claro en una app oscura.** Es una decision explicita para
/// esta iteracion; el modo oscuro viene despues. Conseguirlo pide DOS cosas, y
/// hacen falta las dos:
///
///  · `environment(\.colorScheme, .light)` para el subarbol, que es lo que
///    resuelve materiales y colores semanticos.
///  · Ocultar la barra de estado, porque su color no se puede cambiar desde
///    aqui — ver la nota junto a `statusBarHidden` mas abajo.
struct NutritionAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var showMethodology = false
    @State private var selectedPage = 0
    @State private var carouselContentOpacity = 1.0
    @State private var isChangingPage = false
    @State private var showPlanFlow = false

    private struct Slide: Identifiable {
        let id: Int
        let symbol: String
        let titleKey: String
        let detailKey: String
    }

    private let slides: [Slide] = [
        Slide(
            id: 0,
            symbol: "calendar",
            titleKey: "nutrition.assistant.slide.plan.title",
            detailKey: "nutrition.assistant.slide.plan.detail"
        ),
        Slide(
            id: 1,
            symbol: "text.viewfinder",
            titleKey: "nutrition.assistant.slide.ingredients.title",
            detailKey: "nutrition.assistant.slide.ingredients.detail"
        ),
        Slide(
            id: 2,
            symbol: "heart.text.square.fill",
            titleKey: "nutrition.assistant.slide.health.title",
            detailKey: "nutrition.assistant.slide.health.detail"
        ),
        Slide(
            id: 3,
            symbol: "lock.fill",
            titleKey: "nutrition.assistant.slide.privacy.title",
            detailKey: "nutrition.assistant.slide.privacy.detail"
        )
    ]

    var body: some View {
        Group {
            if showPlanFlow {
                NutritionPlanFlowView()
            } else {
                intro
            }
        }
        .hidesTabBar()
    }

    private var intro: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 12)

                assistantCarousel
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 12)

                startButton
            }
        }
        .environment(\.colorScheme, .light)
        // La barra de estado se oculta porque no hay forma de aclararla desde
        // aqui: la pinta SwiftUI a partir del `preferredColorScheme(.dark)` que
        // fijan `RecvelApp` y `ContentView`, y el ancestro gana. Se probaron y
        // descartaron tres vias — `preferredColorScheme(.light)` en la pantalla,
        // `overrideUserInterfaceStyle` en la ventana, y lo mismo en el
        // controlador raiz, sincrono y diferido: el reloj seguia blanco sobre un
        // fondo casi blanco (luminancia 251 sobre 255).
        //
        // Ocultarla encaja con una pantalla inmersiva sin scroll, y el problema
        // desaparece solo cuando esta vista tenga modo oscuro.
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.06)) {
                appeared = true
            }
        }
        .alert(RecvelL10n.text("nutrition.assistant.method.title"), isPresented: $showMethodology) {
            Button(RecvelL10n.text("common.close"), role: .cancel) {}
        } message: {
            Text(RecvelL10n.text("nutrition.assistant.method.summary"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition.assistant")
    }

    // MARK: Paleta

    private static let ink = Color(red: 0.09, green: 0.09, blue: 0.13)
    private static let inkSoft = Color(red: 0.42, green: 0.43, blue: 0.50)
    private static let accent = Color(red: 0.38, green: 0.34, blue: 0.84)
    private static let control = Color.black.opacity(0.05)
    /// El orbe ya aporta movimiento continuo. El carrusel solo disuelve su
    /// contenido para no competir con el ritmo sereno de la pantalla.
    private static let fadeOut = Animation.easeOut(duration: 0.20)
    private static let fadeIn = Animation.easeIn(duration: 0.34)
    private static let indicatorFade = Animation.easeInOut(duration: 0.32)

    /// Blanco que vira a lavanda muy suave hacia abajo, como la referencia.
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.99, green: 0.99, blue: 1.0), location: 0),
                .init(color: Color(red: 0.95, green: 0.95, blue: 0.99), location: 0.45),
                .init(color: Color(red: 0.91, green: 0.91, blue: 0.98), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        ZStack {
            Text(RecvelL10n.text("nutrition.assistant.title"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Self.ink)

            HStack {
                circleButton(icon: "chevron.left", label: RecvelL10n.text("common.back")) {
                    Haptics.soft()
                    dismiss()
                }
                Spacer()
                circleButton(icon: "info", label: RecvelL10n.text("nutrition.assistant.info")) {
                    Haptics.soft()
                    showMethodology = true
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func circleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Self.ink.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(Self.control, in: Circle())
                .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var assistantCarousel: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                AssistantOrb(diameter: 150)

                ZStack {
                    ForEach(slides) { slide in
                        if slide.id == selectedPage {
                            Image(systemName: slide.symbol)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Self.ink.opacity(0.78))
                        }
                    }
                }
                .opacity(carouselContentOpacity)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1))
                .shadow(color: Self.ink.opacity(0.12), radius: 12, y: 5)
                .offset(x: -2, y: -2)
            }
            .scaleEffect(appeared || reduceMotion ? 1 : 0.86)

            ZStack {
                ForEach(slides) { slide in
                    if slide.id == selectedPage {
                        slideCopy(slide)
                    }
                }
            }
            .opacity(carouselContentOpacity)
            .frame(maxWidth: .infinity)
            .frame(height: 96, alignment: .top)

            pageIndicator
        }
        .contentShape(Rectangle())
        .gesture(carouselGesture)
        .task(id: selectedPage) {
            guard !reduceMotion else { return }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            movePage(by: 1)
        }
        .accessibilityIdentifier("nutrition.assistant.slide.\(selectedPage)")
    }

    private func slideCopy(_ slide: Slide) -> some View {
        VStack(spacing: 7) {
            Text(RecvelL10n.text("nutrition.assistant.name"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Self.accent.opacity(0.9))
                .textCase(.uppercase)

            Text(RecvelL10n.text(slide.titleKey))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Self.ink)

            Text(RecvelL10n.text(slide.detailKey))
                .font(.system(size: 14))
                .foregroundStyle(Self.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
    }

    private var carouselGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onEnded { value in
                guard abs(value.translation.width) > 42 else { return }
                Haptics.soft()
                movePage(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func movePage(by delta: Int) {
        guard !isChangingPage else { return }
        let nextPage = (selectedPage + delta + slides.count) % slides.count

        guard !reduceMotion else {
            selectedPage = nextPage
            return
        }

        isChangingPage = true
        withAnimation(Self.fadeOut) {
            carouselContentOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.20))
            selectedPage = nextPage

            withAnimation(Self.fadeIn) {
                carouselContentOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.34))
            isChangingPage = false
        }
    }

    private var pageIndicator: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 7) {
                ForEach(slides) { slide in
                    Button {
                        guard slide.id != selectedPage else { return }
                        Haptics.soft()
                        let delta = slide.id - selectedPage
                        movePage(by: delta)
                    } label: {
                        Capsule(style: .continuous)
                            .fill(indicatorColor(for: slide.id, phase: phase))
                            .frame(width: slide.id == selectedPage ? 18 : 5, height: 5)
                            .contentShape(Rectangle().inset(by: -8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RecvelL10n.text(slide.titleKey))
                    .accessibilityAddTraits(slide.id == selectedPage ? .isSelected : [])
                }
            }
        }
        .animation(reduceMotion ? nil : Self.indicatorFade, value: selectedPage)
        .accessibilityIdentifier("nutrition.assistant.pages")
    }

    private func indicatorColor(for page: Int, phase: Double) -> Color {
        guard page != selectedPage else { return Self.ink.opacity(0.78) }
        let pulse = (sin(phase * 2.2 - Double(page) * 0.7) + 1) / 2
        return Self.inkSoft.opacity(0.24 + 0.18 * pulse)
    }

    private var startButton: some View {
        Button {
            Haptics.medium()
            withAnimation(reduceMotion ? nil : .snappy) { showPlanFlow = true }
        } label: {
            Text(RecvelL10n.text("nutrition.assistant.start"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Self.ink, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .accessibilityIdentifier("nutrition.assistant.start")
    }
}
