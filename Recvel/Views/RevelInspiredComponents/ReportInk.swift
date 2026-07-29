import SwiftUI

// Componente derivado de las pantallas de referencia de Bevel.
// Medido sobre fotogramas de `Bevel_references/BioAge_revel.mp4`
// (`ffmpeg -vf fps=1` + recortes a 1290x2796). Ver README.md de esta carpeta.

enum ReportInk {
    static let page = Color(red: 0.075, green: 0.076, blue: 0.086)
    static let card = Color(red: 0.118, green: 0.122, blue: 0.137)
    static let cardHigh = Color(red: 0.145, green: 0.149, blue: 0.165)
    static let track = Color(red: 0.169, green: 0.173, blue: 0.192)
    static let hairline = Color.white.opacity(0.07)
    static let warn = Color(red: 1.00, green: 0.58, blue: 0.20)
    static let good = Color(red: 0.44, green: 0.84, blue: 0.20)
}
