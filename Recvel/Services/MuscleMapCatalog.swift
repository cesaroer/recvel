import Foundation

/// Musculos que trabaja cada ejercicio, para pintar el mapa anatomico
/// (silueta gris + musculo en rojo) igual que las laminas de gimnasio.
///
/// Las siluetas y las capas por musculo son de wger (https://wger.de,
/// wger-project/wger), empaquetadas en Recvel/Resources/MuscleMap. Uso personal
/// y sin distribucion: ver la nota de licencias en HANDOFF.md.
enum TargetMuscle: String, CaseIterable, Hashable {
    case chest, shoulders, biceps, triceps, forearms
    case abs, obliques
    case lats, traps, midBack, lowerBack
    case quads, hamstrings, glutes, calves, adductors, abductors

    var spanishName: String {
        switch self {
        case .chest: "Pectoral"
        case .shoulders: "Deltoides"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Antebrazo"
        case .abs: "Abdomen"
        case .obliques: "Oblicuos"
        case .lats: "Dorsal ancho"
        case .traps: "Trapecio"
        case .midBack: "Espalda media"
        case .lowerBack: "Espalda baja"
        case .quads: "Cuadriceps"
        case .hamstrings: "Isquiotibiales"
        case .glutes: "Gluteos"
        case .calves: "Gemelos"
        case .adductors: "Aductores"
        case .abductors: "Abductores"
        }
    }

    /// Capas de wger que pintan este musculo (algunos necesitan dos, como el
    /// gemelo = gastrocnemio + soleo). Vacio = no hay lamina para ese musculo.
    var overlayIDs: [Int] {
        switch self {
        case .chest: [4]
        case .shoulders: [2]
        case .biceps: [1]
        case .triceps: [5]
        case .forearms: [13]
        case .abs: [6]
        case .obliques: [14]
        case .lats: [12]
        case .traps: [9]
        case .midBack: [9]
        case .lowerBack: []
        case .quads: [10]
        case .hamstrings: [11]
        case .glutes: [8]
        case .calves: [7, 15]
        case .adductors: []
        case .abductors: [8]
        }
    }

    /// Vista del cuerpo donde se ve el musculo (para saber si hace falta la
    /// silueta de espalda).
    var isFront: Bool {
        switch self {
        case .chest, .shoulders, .biceps, .forearms, .abs, .obliques, .quads, .adductors: true
        case .triceps, .lats, .traps, .midBack, .lowerBack, .hamstrings, .glutes, .calves, .abductors: false
        }
    }
}

struct MuscleFocus: Hashable {
    let primary: [TargetMuscle]
    let secondary: [TargetMuscle]

    var isEmpty: Bool { primary.isEmpty && secondary.isEmpty }
    var all: [TargetMuscle] { primary + secondary }
}

enum MuscleMapCatalog {
    static let attribution = RecvelL10n.text("Mapa muscular: wger (wger.de)")

    static func focus(for exercise: String) -> MuscleFocus? {
        let trimmed = exercise.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = table.first(where: { $0.key.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact.value.isEmpty ? nil : exact.value
        }
        let partial = table
            .filter { trimmed.localizedCaseInsensitiveContains($0.key) }
            .max { $0.key.count < $1.key.count }
        guard let focus = partial?.value, !focus.isEmpty else { return nil }
        return focus
    }

    private static func f(_ primary: [TargetMuscle], _ secondary: [TargetMuscle] = []) -> MuscleFocus {
        MuscleFocus(primary: primary, secondary: secondary)
    }

    /// Los ejercicios con equivalente en free-exercise-db heredan sus musculos
    /// primarios/secundarios; el resto esta asignado a mano segun la mecanica.
    static let table: [String: MuscleFocus] = [
        // Pecho
        "Press de banca": f([.chest], [.shoulders, .triceps]),
        "Press inclinado": f([.chest], [.shoulders, .triceps]),
        "Aperturas con mancuernas": f([.chest], [.shoulders]),
        "Fondos": f([.triceps], [.chest, .shoulders]),
        "Flexiones": f([.chest], [.shoulders, .triceps, .abs]),
        // Espalda
        "Remo con barra": f([.midBack], [.biceps, .lats, .shoulders]),
        "Jalon al pecho": f([.lats], [.biceps, .midBack, .shoulders]),
        "Dominadas": f([.lats], [.biceps, .midBack]),
        "Remo con mancuerna": f([.midBack], [.biceps, .lats, .shoulders]),
        "Band pull-aparts": f([.shoulders], [.midBack, .traps]),
        // Piernas
        "Sentadilla": f([.quads], [.glutes, .hamstrings, .calves, .lowerBack]),
        "Peso muerto": f([.lowerBack, .hamstrings], [.glutes, .quads, .traps, .lats, .forearms]),
        "Prensa": f([.quads], [.glutes, .hamstrings, .calves]),
        "Zancadas": f([.quads], [.glutes, .hamstrings, .calves]),
        "Elevacion de talones": f([.calves]),
        "Step-ups": f([.glutes], [.quads, .hamstrings]),
        "Desplantes": f([.quads], [.glutes, .hamstrings, .calves]),
        // Hombros
        "Press militar": f([.shoulders], [.triceps, .abs]),
        "Elevaciones laterales": f([.shoulders]),
        "Face pull": f([.shoulders], [.midBack, .traps]),
        // Brazos
        "Curl de biceps": f([.biceps], [.forearms]),
        "Extension de triceps": f([.triceps], [.shoulders]),
        "Curl martillo": f([.biceps], [.forearms]),
        // Core
        "Plancha": f([.abs], [.shoulders, .glutes]),
        "Crunch": f([.abs]),
        "Rueda abdominal": f([.abs], [.lats, .shoulders]),
        "Elevacion de piernas": f([.abs], [.quads]),
        // Cardio
        "Correr": f([.quads], [.calves, .glutes, .hamstrings]),
        "Caminata": f([.quads], [.calves, .glutes, .hamstrings]),
        "Ciclismo": f([.quads], [.calves, .glutes, .hamstrings]),
        "Natacion": f([.lats], [.shoulders, .midBack, .triceps, .glutes]),
        "Futbol": f([.quads], [.hamstrings, .glutes, .calves]),
        "Basquetbol": f([.quads], [.calves, .glutes, .hamstrings]),
        "Tenis": f([.quads], [.shoulders, .obliques, .calves]),
        "Remo": f([.quads], [.midBack, .lats, .biceps, .glutes, .hamstrings]),
        "HIIT": f([.quads], [.glutes, .hamstrings, .calves]),
        "Saltar la cuerda": f([.calves], [.quads, .hamstrings]),
        "Otro": f([]),
        // Movilidad
        "Gato-vaca": f([.lowerBack], [.midBack, .traps]),
        "Rotacion toracica": f([.midBack], [.lats, .traps]),
        "Estiramiento suave de cadera": f([.quads], [.glutes]),
        "Movilidad de cadera 90/90": f([.adductors], [.glutes]),
        "Estiramiento de isquios": f([.hamstrings], [.calves]),
        "Rotacion de tobillo": f([.calves]),
        "Aperturas de pecho en puerta": f([.chest], [.shoulders]),
        "Circulos de hombro": f([.shoulders], [.traps]),
        "Movilidad de hombro con banda": f([.shoulders], [.chest]),
        "Estiramiento cruzado de hombro": f([.shoulders]),
        "Rotaciones externas suaves": f([.shoulders]),
        "Respiracion diafragmatica": f([]),
        "Postura del nino": f([.lowerBack], [.lats, .glutes]),
        "Perro boca abajo": f([.hamstrings], [.calves, .shoulders, .lats]),
        "Cobra": f([.lowerBack], [.abs, .chest]),
        "Paloma": f([.glutes], [.adductors]),
        "Guerrero II": f([.quads], [.glutes, .adductors]),
        "Puente de gluteos": f([.glutes], [.hamstrings]),
        "Torsion espinal acostado": f([.midBack], [.lowerBack, .obliques]),
        "Estiramiento de cuadriceps": f([.quads]),
        "Sentadilla profunda sostenida": f([.quads], [.glutes, .adductors, .calves]),
        "Estiramiento de gemelos": f([.calves]),
        "Flexion lateral de pie": f([.obliques], [.lats]),
        "Postura del triangulo": f([.hamstrings], [.obliques, .adductors]),
        // Challenge
        "Bird-dog": f([.lowerBack], [.glutes, .abs, .shoulders]),
        "Curl-up McGill": f([.abs]),
        "Plancha lateral": f([.obliques], [.abs, .shoulders, .abductors]),
        "Dead bug": f([.abs], [.lowerBack]),
        "Abdominales de pie": f([.abs], [.obliques]),
        "Marcha con rodilla alta": f([.quads], [.abs, .calves]),
        "Pasos": f([.calves], [.quads, .glutes]),
        "Sentadilla en pared": f([.quads], [.glutes]),
        "Remo con banda": f([.midBack], [.biceps, .shoulders]),
        "Paseo del monstruo": f([.abductors], [.glutes, .quads]),
        "Almeja con banda": f([.abductors], [.glutes]),
        "Empuje de cadera con banda": f([.glutes], [.hamstrings]),
        "El cien": f([.abs], [.quads]),
        "Roll-up": f([.abs], [.hamstrings]),
        "Teaser": f([.abs], [.quads]),
        "Nado boca abajo": f([.lowerBack], [.glutes, .hamstrings, .shoulders]),
        "Patada lateral": f([.abductors], [.glutes, .abs]),
        "Circulos de pierna": f([.abs], [.quads, .adductors]),
        "Puente de hombros": f([.glutes], [.hamstrings, .lowerBack]),
        "Hollow hold": f([.abs], [.quads]),
        "Superman": f([.lowerBack], [.glutes, .hamstrings]),
        "Escaladores": f([.abs], [.quads, .shoulders, .chest]),
        "Burpees": f([.quads], [.chest, .shoulders, .abs, .glutes]),
        "Sentadilla con salto": f([.quads], [.glutes, .hamstrings, .calves]),
        "Flexion pike": f([.shoulders], [.triceps, .abs]),
        "Remo invertido": f([.midBack], [.lats, .biceps]),
        "Fondos en banca": f([.triceps], [.chest, .shoulders]),
        "Plancha alta": f([.abs], [.shoulders, .chest]),
        "Postura de la silla": f([.quads], [.glutes, .shoulders]),
        "Postura del barco": f([.abs], [.quads]),
        "Guerrero III": f([.glutes], [.hamstrings, .lowerBack, .abs]),
        "Plancha lateral con elevacion": f([.obliques], [.abductors, .shoulders])
    ]
}
