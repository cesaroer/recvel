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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
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

// MARK: - Entrypoint

/// Puerta de entrada al asistente desde Nutricion.
///
/// Capsula oscura con el orbe a la izquierda, nombre + beneficio en el centro y
/// una flecha a la derecha.
///
/// **Sobre convivir con `IntelligenceSurface`.** Esa superficie esta documentada
/// como "una por pantalla" (`GlassComponents.swift`) y Nutricion ya la gasta en
/// `recordFoodEntry`. Esta capsula es la excepcion deliberada: la regla existe
/// para que dos elementos no compitan por el mismo tipo de atencion, y aqui las
/// siluetas son distintas —capsula alargada con orbe frente a tarjeta
/// rectangular con borde iridiscente—, asi que se leen como dos cosas y no como
/// dos versiones de la misma.
struct NutritionAssistantEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                AssistantOrb(diameter: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(RecvelL10n.text("nutrition.plan.entry.title"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(RecvelL10n.text("nutrition.plan.entry.detail"))
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

/// Bienvenida del asistente de nutricion.
///
/// **Andamiaje visual.** Esta pasada valida la apariencia: el boton de abajo NO
/// hace nada todavia. Se deja vivo y no deshabilitado a proposito — un boton
/// apagado se lee como "algo falla", y lo que se esta revisando aqui es la
/// intencion del diseño. No debe llegar asi a una build de usuarios.
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

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 12)

                VStack(spacing: 22) {
                    AssistantOrb(diameter: 150)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.86)
                        .opacity(appeared ? 1 : 0)

                    VStack(spacing: 7) {
                        Text(RecvelL10n.text("nutrition.assistant.name"))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Self.ink)

                        Text(RecvelL10n.text("nutrition.assistant.descriptor"))
                            .font(.system(size: 14))
                            .foregroundStyle(Self.inkSoft)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 34)
                    }
                    .opacity(appeared ? 1 : 0)

                    pulseIndicator
                        .opacity(appeared ? 1 : 0)
                }

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
        .hidesTabBar()
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.06)) {
                appeared = true
            }
        }

        .accessibilityIdentifier("nutrition.assistant")
    }

    // MARK: Paleta

    private static let ink = Color(red: 0.09, green: 0.09, blue: 0.13)
    private static let inkSoft = Color(red: 0.42, green: 0.43, blue: 0.50)
    private static let control = Color.black.opacity(0.05)

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
                // Informativo: explicara como se arma el plan. Inerte por ahora,
                // igual que el boton principal.
                circleButton(icon: "info", label: RecvelL10n.text("nutrition.assistant.info")) {}
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

    /// Guion animado de la referencia: tres puntos que respiran junto al trazo.
    /// Es decorativo; no comunica ningun estado.
    private var pulseIndicator: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                Capsule()
                    .fill(Self.ink.opacity(0.7))
                    .frame(width: 16, height: 3)
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Self.inkSoft.opacity(0.45 + 0.35 * pulse(phase: phase, index: index)))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func pulse(phase: Double, index: Int) -> Double {
        (sin(phase * 2.2 - Double(index) * 0.7) + 1) / 2
    }

    private var startButton: some View {
        Button {
            // Sin accion todavia: ver la nota de andamiaje en la cabecera del
            // tipo. Se conectara al motor de plan.
            Haptics.soft()
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
