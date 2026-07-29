import SwiftUI

// Componente derivado de las pantallas de referencia de Bevel.
// Medido sobre fotogramas de `Bevel_references/BioAge_revel.mp4`
// (`ffmpeg -vf fps=1` + recortes a 1290x2796). Ver README.md de esta carpeta.

/// Barra de la referencia: ticks verticales redondeados, los consumidos en
/// color y el resto apagados.
struct SegmentedLoadBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let tickWidth: CGFloat = 4
            let count = max(Int((geo.size.width + spacing) / (tickWidth + spacing)), 1)
            let filled = Int((Double(count) * min(max(fraction, 0), 1)).rounded())
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? tint : Color.white.opacity(0.12))
                        .frame(width: tickWidth)
                        .shadow(color: index < filled ? tint.opacity(0.5) : .clear, radius: 3)
                }
            }
            .frame(height: geo.size.height)
        }
    }
}
