import SwiftUI
import UIKit

extension View {
    /// Evita que animaciones del padre (snappy, spring) ralenticen cada tecla.
    func snappyTextInput() -> some View {
        transaction { transaction in
            transaction.animation = nil
        }
    }
}

enum Keyboard {
    /// Cierra el teclado (p. ej. antes de Guardar para flush de buffers locales).
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

/// TextField con buffer local: solo escribe al `Binding` al perder el foco o al submit.
/// Ideal para pills kg/reps dentro de listas pesadas.
struct CommitOnBlurTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var alignment: TextAlignment = .leading
    var onCommit: (() -> Void)?

    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var seeded = false

    var body: some View {
        TextField(placeholder, text: $draft)
            .keyboardType(keyboard)
            .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            .focused($focused)
            .snappyTextInput()
            .onAppear {
                guard !seeded else { return }
                draft = text
                seeded = true
            }
            .onChange(of: text) { _, newValue in
                if !focused { draft = newValue }
            }
            .onChange(of: focused) { _, isFocused in
                guard !isFocused else { return }
                commit()
            }
            .onSubmit { commit() }
    }

    private func commit() {
        if draft != text {
            text = draft
        }
        onCommit?()
    }
}
