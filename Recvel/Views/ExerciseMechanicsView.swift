import SwiftUI

/// Hoja "Ver mecanica": muestra como se ejecuta un ejercicio con una demostracion
/// animada (dos fotogramas alternados, como un gif) + pasos, claves y errores.
///
/// Las imagenes son locales (free-exercise-db, dominio publico) para que funcione
/// sin conexion; si un ejercicio no tiene fotogramas se cae a la silueta de la
/// biblioteca sin romper la vista.
/// Envoltura Identifiable para presentar la hoja con `.sheet(item:)` y evitar
/// el bug de leer el valor del ciclo anterior con `.sheet(isPresented:)`.
struct ExerciseMechanicsRequest: Identifiable, Hashable {
    var id: String { exerciseName }
    let exerciseName: String
}

struct ExerciseMechanicsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String

    private var mechanics: ExerciseMechanics? {
        ExerciseMechanicsCatalog.mechanics(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.075, blue: 0.09).ignoresSafeArea()
                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ExerciseMechanicsPlayer(
                            frames: mechanics?.frameNames ?? [],
                            fallback: ExerciseLibrary.thumbnail(for: exerciseName)
                        )

                        if let mechanics {
                            Text(mechanics.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("fitness.mechanics.summary")

                            if let focus = MuscleMapCatalog.focus(for: exerciseName) {
                                section(title: RecvelL10n.text("Musculos que trabajas"), systemImage: "figure.arms.open") {
                                    VStack(spacing: 12) {
                                        MuscleMapView(focus: focus)
                                        MuscleLegend(focus: focus)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }

                            section(title: "Posicion inicial", systemImage: "figure.stand") {
                                Text(mechanics.setup)
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            section(title: "Ejecucion", systemImage: "list.number") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(mechanics.steps.enumerated()), id: \.offset) { index, step in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(index + 1)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.black)
                                                .frame(width: 20, height: 20)
                                                .background(Color.white.opacity(0.9), in: Circle())
                                            Text(step)
                                                .font(.callout)
                                                .foregroundStyle(.white.opacity(0.92))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }

                            if !mechanics.cues.isEmpty {
                                section(title: "Claves", systemImage: "target") {
                                    bulletList(mechanics.cues, symbol: "checkmark.circle.fill", tint: .green)
                                }
                            }

                            if !mechanics.mistakes.isEmpty {
                                section(title: "Errores comunes", systemImage: "exclamationmark.triangle") {
                                    bulletList(mechanics.mistakes, symbol: "xmark.circle.fill", tint: .orange)
                                }
                            }

                            Text(creditLine(hasMedia: mechanics.mediaSlug != nil))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(RecvelL10n.text("Aun no tenemos la mecanica de este ejercicio"))
                                    .font(.body.weight(.semibold))
                                Text(RecvelL10n.text("Es un ejercicio personalizado. Ejecutalo con el rango que controles, sin dolor, y manteniendo la columna neutra."))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityIdentifier("fitness.mechanics.empty")
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .accessibilityIdentifier("fitness.mechanics.close")
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitness.mechanics")
    }

    private func creditLine(hasMedia: Bool) -> String {
        var credits: [String] = []
        if hasMedia { credits.append(ExerciseMechanicsCatalog.attribution) }
        if MuscleMapCatalog.focus(for: exerciseName) != nil { credits.append(MuscleMapCatalog.attribution) }
        return credits.joined(separator: " · ")
    }

    private func section<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bulletList(_ items: [String], symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(item)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Reproductor de la demostracion. Solo hay dos fotogramas (inicio y fin del
/// recorrido), asi que en vez de alternarlos de golpe se hace un fundido lento
/// de ida y vuelta con pausas en los extremos: se lee como una repeticion a
/// tempo controlado en lugar de un parpadeo. Respeta Reduce Motion.
struct ExerciseMechanicsPlayer: View {
    let frames: [String]
    let fallback: ExerciseCatalogItem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlaying = true
    /// Fotograma fijo cuando el usuario pausa (0 = inicio, 1 = fin).
    @State private var pausedFrame = 0

    /// Duracion de un ciclo completo (bajar y volver a subir), en segundos.
    static let cycleDuration: Double = 5.0
    /// Tiempo que se sostiene cada extremo antes de empezar a transicionar.
    static let holdDuration: Double = 1.4

    /// Mezcla entre el fotograma 0 y el 1 para un instante dado: 0 = inicio,
    /// 1 = fin, con pausas en los extremos y una transicion suavizada.
    static func blend(
        at time: TimeInterval,
        cycle: Double = cycleDuration,
        hold: Double = holdDuration
    ) -> Double {
        let half = cycle / 2
        let travel = max(half - hold, 0.01)
        let x = time.truncatingRemainder(dividingBy: cycle)
        if x < hold { return 0 }
        if x < half { return smoothstep((x - hold) / travel) }
        if x < half + hold { return 1 }
        return 1 - smoothstep((x - half - hold) / travel)
    }

    private static func smoothstep(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private var availableFrames: [UIImage] {
        frames.compactMap(Self.loadImage)
    }

    /// Los jpg viven sueltos en el bundle (no en el asset catalog), asi que
    /// `UIImage(named:)` sin extension devuelve nil: hay que resolver la ruta.
    static func loadImage(named name: String) -> UIImage? {
        if let asset = UIImage(named: name) { return asset }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        let images = availableFrames
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if images.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: fallback.symbol)
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(RecvelL10n.text("Sin demostracion visual"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("fitness.mechanics.noMedia")
            } else if images.count == 1 {
                frame(images[0])
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying || reduceMotion)) { context in
                    let blend = (isPlaying && !reduceMotion)
                        ? Self.blend(at: context.date.timeIntervalSinceReferenceDate)
                        : Double(pausedFrame)
                    ZStack {
                        frame(images[0]).opacity(1 - blend)
                        frame(images[1]).opacity(blend)
                    }
                }

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        isPlaying.toggle()
                        Haptics.light()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlaying ? "Pausar demostracion" : "Reproducir demostracion")
                    .accessibilityIdentifier("fitness.mechanics.playPause")

                    // En pausa se puede comparar inicio y fin sin esperar al ciclo.
                    if !isPlaying || reduceMotion {
                        HStack(spacing: 4) {
                            stepButton(title: "Inicio", index: 0)
                            stepButton(title: "Fin", index: 1)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func frame(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityIdentifier("fitness.mechanics.media")
    }

    private func stepButton(title: String, index: Int) -> some View {
        Button {
            pausedFrame = index
            Haptics.selection()
        } label: {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(pausedFrame == index ? .black : .white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    pausedFrame == index ? Color.white.opacity(0.9) : Color.black.opacity(0.55),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fitness.mechanics.frame.\(index)")
    }
}

/// Boton reutilizable que abre la mecanica del ejercicio.
struct ExerciseMechanicsButton: View {
    let exerciseName: String
    @State private var showMechanics = false

    var body: some View {
        Button {
            Haptics.light()
            showMechanics = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.footnote.weight(.semibold))
                Text(RecvelL10n.text("Ver mecanica del ejercicio"))
                    .font(.footnote.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fitness.mechanics.open.\(exerciseName.replacingOccurrences(of: " ", with: "_"))")
        .sheet(isPresented: $showMechanics) {
            ExerciseMechanicsSheet(exerciseName: exerciseName)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }
}
