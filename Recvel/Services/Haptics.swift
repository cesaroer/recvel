import UIKit
import CoreHaptics
import SwiftUI

/// Feedback haptico centralizado para un feel premium y consistente.
/// - Selection: chips, tabs, toggles de lista
/// - Soft/Light: taps secundarios, expandir chrome
/// - Medium/Rigid: CTAs principales (guardar, empezar, FAB)
/// - Success/Warning/Error: resultados (terminar sesion, borrar, fallo)
enum Haptics {
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let notifyGen = UINotificationFeedbackGenerator()

    private static var isEnabled: Bool {
        // UITests / demos pueden silenciar con `-disableHaptics`.
        if ProcessInfo.processInfo.arguments.contains("-disableHaptics") { return false }
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Precalienta generadores antes de una rafaga de taps (p. ej. al montar la tab bar).
    static func prepare() {
        guard isEnabled else { return }
        lightGen.prepare()
        mediumGen.prepare()
        softGen.prepare()
        selectionGen.prepare()
        notifyGen.prepare()
    }

    static func light() {
        guard isEnabled else { return }
        lightGen.impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        mediumGen.impactOccurred()
    }

    static func heavy() {
        guard isEnabled else { return }
        heavyGen.impactOccurred()
    }

    /// Toque suave, casi "glass" — ideal para expandir chrome o taps secundarios.
    static func soft() {
        guard isEnabled else { return }
        softGen.impactOccurred()
    }

    /// Toque firme y corto — CTAs premium (FAB, Empezar).
    static func rigid() {
        guard isEnabled else { return }
        rigidGen.impactOccurred()
    }

    /// Tick de seleccion (tabs, chips, checkmarks de biblioteca).
    static func selection() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        notifyGen.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        notifyGen.notificationOccurred(.warning)
    }

    static func error() {
        guard isEnabled else { return }
        notifyGen.notificationOccurred(.error)
    }

    /// Abrir un Menu / FAB / boton "+" flotante.
    static func menuOpen() {
        soft()
    }

    /// Elegir una opcion dentro de un Menu.
    static func menuSelect() {
        selection()
    }

    /// CTA de "Agregar / Crear / Añadir".
    static func add() {
        medium()
    }

    /// Tick de Stepper (+/−) al cambiar peso, macros, duracion, etc.
    static func step() {
        selection()
    }
}

extension Binding where Value: Equatable {
    /// Dispara `Haptics.step()` cada vez que el valor cambia (p. ej. Stepper +/−).
    func hapticStep() -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                if newValue != wrappedValue {
                    Haptics.step()
                }
                wrappedValue = newValue
            }
        )
    }
}

extension View {
    /// Soft tick al tocar el label de un `Menu` (abrir el sheet del sistema).
    /// Usa DragGesture(min 0) porque `TapGesture` suele no dispararse en `Menu`.
    func hapticMenuLabel() -> some View {
        modifier(HapticMenuLabelModifier())
    }
}

private struct HapticMenuLabelModifier: ViewModifier {
    @State private var didFire = false

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !didFire else { return }
                    didFire = true
                    Haptics.menuOpen()
                }
                .onEnded { _ in
                    didFire = false
                }
        )
    }
}
