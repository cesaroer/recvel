import SwiftUI

// Componente derivado de las pantallas de referencia de Bevel.
// Medido sobre fotogramas de `Bevel_references/BioAge_revel.mp4`
// (`ffmpeg -vf fps=1` + recortes a 1290x2796). Ver README.md de esta carpeta.

struct ReportMetricRow: View {
    let title: String
    let statusIcon: String
    let statusText: String
    let statusColor: Color
    let value: String
    var detail: String?
    var series: [Double] = []
    var lineColor: Color = .white

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(statusColor.opacity(0.9), in: Circle())
                    Text(statusText)
                        .font(.system(size: 15))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("·").foregroundStyle(.tertiary)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            if series.count >= 3 {
                ReportSparkline(series: series, color: lineColor)
                    .frame(width: 92, height: 46)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportInk.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(ReportInk.hairline, lineWidth: 1)
        }
    }
}

/// Sparkline de la referencia: linea redondeada, punto final con halo y
/// linea base punteada debajo.
struct ReportSparkline: View {
    let series: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let points = normalized(in: geo.size)
            ZStack {
                // Linea base punteada.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height - 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color.white.opacity(0.18))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.7), radius: 4)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard series.count > 1 else { return [] }
        let minValue = series.min() ?? 0
        let maxValue = series.max() ?? 1
        let span = max(maxValue - minValue, 0.001)
        let stepX = size.width / CGFloat(series.count - 1)
        // Se deja aire arriba y abajo para que el punto final no se corte.
        let top: CGFloat = 6
        let usable = size.height - top - 8
        return series.enumerated().map { index, value in
            let ratio = (value - minValue) / span
            return CGPoint(x: CGFloat(index) * stepX, y: top + usable * (1 - CGFloat(ratio)))
        }
    }
}
