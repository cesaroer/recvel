import SwiftUI
import WebKit

/// Mapa anatomico del ejercicio: silueta muscular en gris con el musculo
/// principal en rojo y el secundario en un rojo mas tenue, como las laminas
/// de gimnasio.
///
/// Se dibuja componiendo los SVG de wger (silueta + una capa por musculo).
/// SwiftUI no rasteriza SVG, asi que el compositor es un WKWebView con el
/// marcado incrustado en linea: no toca la red ni el disco en tiempo de uso.
struct MuscleMapView: View {
    let focus: MuscleFocus
    var height: CGFloat = 230

    var body: some View {
        HStack(spacing: 10) {
            MuscleBodyView(focus: focus, side: .front)
            MuscleBodyView(focus: focus, side: .back)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("fitness.mechanics.muscleMap")
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if !focus.primary.isEmpty {
            parts.append("Principal: " + focus.primary.map(\.spanishName).joined(separator: ", "))
        }
        if !focus.secondary.isEmpty {
            parts.append("Secundario: " + focus.secondary.map(\.spanishName).joined(separator: ", "))
        }
        return parts.joined(separator: ". ")
    }
}

enum MuscleBodySide: String {
    case front, back

    var resourceName: String { "body_\(rawValue)" }
    var title: String { self == .front ? "Frente" : "Espalda" }
}

private struct MuscleBodyView: View {
    let focus: MuscleFocus
    let side: MuscleBodySide

    var body: some View {
        VStack(spacing: 6) {
            MuscleMapWebView(html: MuscleMapRenderer.html(focus: focus, side: side))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(side.title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Genera el HTML del compositor. Aislado de la vista para poder testearlo.
enum MuscleMapRenderer {
    static let primaryColor = "#ff3b30"
    static let secondaryColor = "#ff9f0a"

    static func html(focus: MuscleFocus, side: MuscleBodySide, bundle: Bundle = .main) -> String {
        let isFront = side == .front
        let base = svgMarkup(named: side.resourceName, bundle: bundle) ?? ""

        // Solo se pintan las capas que pertenecen a esta vista del cuerpo.
        let primaryLayers = layers(for: focus.primary, isFront: isFront, bundle: bundle)
        let secondaryLayers = layers(for: focus.secondary, isFront: isFront, bundle: bundle)

        let overlays = secondaryLayers.map { layer($0, color: secondaryColor, opacity: 0.75) }
            + primaryLayers.map { layer($0, color: primaryColor, opacity: 1) }

        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        html,body{margin:0;padding:0;background:transparent;height:100%;}
        .stack{position:relative;height:100%;display:flex;align-items:center;justify-content:center;}
        .stack>*{position:absolute;height:100%;width:auto;}
        .stack>*:first-child{position:relative;}
        svg{height:100%;width:auto;display:block;}
        </style></head>
        <body><div class="stack">\(base)\(overlays.joined())</div></body></html>
        """
    }

    private static func layers(for muscles: [TargetMuscle], isFront: Bool, bundle: Bundle) -> [String] {
        muscles
            .filter { $0.isFront == isFront }
            .flatMap(\.overlayIDs)
            .compactMap { svgMarkup(named: "muscle_\($0)_main", bundle: bundle) }
    }

    /// El SVG de wger trae el rojo quemado en el `fill`; se reemplaza para poder
    /// distinguir musculo principal de secundario con la paleta de la app.
    private static func layer(_ markup: String, color: String, opacity: Double) -> String {
        let tinted = markup.replacingOccurrences(of: "#fc0000", with: color)
        return "<div style=\"opacity:\(opacity)\">\(tinted)</div>"
    }

    static func svgMarkup(named name: String, bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: name, withExtension: "svg"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // Se recorta el prologo XML: dentro de HTML el <svg> va suelto.
        guard let start = raw.range(of: "<svg") else { return nil }
        return normalized(String(raw[start.lowerBound...]))
    }

    /// Los SVG de wger vienen de Inkscape con `width`/`height` pero SIN
    /// `viewBox`: sin el, WebKit no puede escalarlos y el mapa sale en blanco.
    /// Se le inyecta uno a partir del tamano declarado.
    static func normalized(_ markup: String) -> String {
        guard !markup.contains("viewBox"),
              let openTagEnd = markup.firstIndex(of: ">") else { return markup }
        let openTag = String(markup[markup.startIndex..<openTagEnd])
        guard let width = attribute("width", in: openTag),
              let height = attribute("height", in: openTag) else { return markup }
        let insertion = " viewBox=\"0 0 \(width) \(height)\" preserveAspectRatio=\"xMidYMid meet\""
        var result = markup
        result.insert(contentsOf: insertion, at: markup.index(markup.startIndex, offsetBy: 4))
        return result
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let range = tag.range(of: "\(name)=\"([^\"]+)\"", options: .regularExpression) else { return nil }
        return String(tag[range]).components(separatedBy: "\"").dropFirst().first
    }
}

private struct MuscleMapWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(lastHTML: html) }

    final class Coordinator {
        var lastHTML: String
        init(lastHTML: String) { self.lastHTML = lastHTML }
    }
}

/// Chips con el nombre de los musculos, para leer el mapa sin adivinar colores.
struct MuscleLegend: View {
    let focus: MuscleFocus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !focus.primary.isEmpty {
                row(title: "Principal", muscles: focus.primary, color: .red)
            }
            if !focus.secondary.isEmpty {
                row(title: "Secundario", muscles: focus.secondary, color: .orange)
            }
        }
    }

    private func row(title: String, muscles: [TargetMuscle], color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(muscles.map(\.spanishName).joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
