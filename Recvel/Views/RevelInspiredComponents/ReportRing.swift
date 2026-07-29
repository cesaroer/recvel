import SwiftUI

// Componente derivado de las pantallas de referencia de Bevel.
// Medido sobre fotogramas de `Bevel_references/BioAge_revel.mp4`
// (`ffmpeg -vf fps=1` + recortes a 1290x2796). Ver README.md de esta carpeta.

/// Anillo de la referencia: pista hundida, arco con degradado angular, remate
/// redondeado y halo del color. El rayado marca "fuera de objetivo".
struct ReportRing: View {
    let value: Int
    let label: String
    let colors: [Color]
    let progress: Double
    var hatched: Bool = false

    private let size: CGFloat = 92
    private let lineWidth: CGFloat = 9

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ReportInk.cardHigh)
                    .frame(width: size, height: size)
                Circle()
                    .strokeBorder(ReportInk.track, lineWidth: lineWidth)
                    .frame(width: size, height: size)

                arc
                    .frame(width: size, height: size)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, lineWidth + 6)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) por ciento")
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: max(min(progress, 1), 0.001))
            .stroke(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .overlay {
                if hatched {
                    // Trama diagonal recortada al propio arco.
                    HatchPattern()
                        .stroke(Color.black.opacity(0.45), lineWidth: 2.5)
                        .mask {
                            Circle()
                                .trim(from: 0, to: max(min(progress, 1), 0.001))
                                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                }
            }
            .shadow(color: colors.last?.opacity(0.55) ?? .clear, radius: 8)
    }
}

/// Lineas diagonales para la textura de "fuera de objetivo".
struct HatchPattern: Shape {
    var spacing: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}
