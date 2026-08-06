import Foundation

/// Mini-rutina ligera del día, distinta al estímulo principal de la agenda.
/// Se genera como valor determinista y después se materializa como `WorkoutTemplate`.
struct DailyChallengeDay: Codable, Equatable, Identifiable {
    var id: String { "\(kind.rawValue)-\(focus)-\(title)" }
    var title: String
    var kind: DailyChallengeKind
    var focus: String
    /// Formato TemplateCodec: "Nombre | 3x12" o "Correr | 15 min".
    var exercisesText: String
    var durationMinutes: Int

    init(
        title: String,
        kind: DailyChallengeKind,
        focus: String,
        exercisesText: String,
        durationMinutes: Int
    ) {
        self.title = title
        self.kind = kind
        self.focus = focus
        self.exercisesText = exercisesText
        self.durationMinutes = durationMinutes
    }

    var exerciseLines: [String] {
        exercisesText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Categoría legada de `FitnessActivityLog`; se conserva para registros anteriores.
    static let activityCategory = "Daily Challenge"
}

enum DailyChallengeKind: String, Codable, Equatable {
    case strengthOpposite
    case cardioSingle
    case mobility
    case walk
    /// Fortalecimiento ligero de mantenimiento (McGill, banda, pasos):
    /// fuerza, no estiramiento.
    case maintenance
}

/// Cubos musculares para anti-overlap (challenge vs rutina prioritaria).
enum ChallengeMuscleBucket: String, Equatable, CaseIterable {
    case upper, lower, push, pull, legs, chest, back, shoulders, arms, full, cardio, other

    var label: String {
        switch self {
        case .upper: "Tren superior"
        case .lower: "Tren inferior"
        case .push: "Empuje"
        case .pull: "Jalon"
        case .legs: "Piernas"
        case .chest: "Pecho"
        case .back: "Espalda"
        case .shoulders: "Hombros"
        case .arms: "Brazos"
        case .full: "Full body"
        case .cardio: "Cardio"
        case .other: "General"
        }
    }

    /// Grupos que se consideran el mismo estimulo (no sobrecargar).
    /// Nota: `full` no se mete en upper/lower — si no, upper y lower "chocan" siempre.
    var conflicting: Set<ChallengeMuscleBucket> {
        switch self {
        case .upper: [.upper, .push, .pull, .chest, .back, .shoulders, .arms]
        case .lower, .legs: [.lower, .legs]
        case .push: [.push, .chest, .shoulders, .arms, .upper]
        case .pull: [.pull, .back, .arms, .upper]
        case .chest: [.chest, .push, .upper]
        case .back: [.back, .pull, .upper]
        case .shoulders: [.shoulders, .push, .upper]
        case .arms: [.arms, .push, .pull, .upper]
        case .full: Set(ChallengeMuscleBucket.allCases)
        case .cardio, .other: []
        }
    }

    static func classify(_ raw: String?) -> ChallengeMuscleBucket {
        let text = (raw ?? "").folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if text.isEmpty { return .other }
        if text.contains("full") || text.contains("cuerpo") { return .full }
        if text.contains("inferior") || text.contains("pierna") || text.contains("leg") { return .legs }
        if text.contains("superior") || text.contains("torso") { return .upper }
        if text.contains("empuje") || text.contains("push") { return .push }
        if text.contains("jalon") || text.contains("pull") { return .pull }
        if text.contains("pecho") || text.contains("chest") { return .chest }
        if text.contains("espalda") || text.contains("back") { return .back }
        if text.contains("hombro") || text.contains("shoulder") { return .shoulders }
        if text.contains("brazo") || text.contains("arm") || text.contains("bicep") || text.contains("tricep") {
            return .arms
        }
        if text.contains("correr") || text.contains("cardio") || text.contains("bici") || text.contains("nad") {
            return .cardio
        }
        return .other
    }
}

/// Genera challenges diarios y rutinas ligeras de movilidad/cardio del plan.
struct DailyChallengeEngine {
    /// Variantes predefinidas del desafio (nombres EXACTOS de ExerciseLibrary;
    /// el test de guardia lo verifica). Rotan deterministicamente por weekday.
    static let lowerChallengeVariants: [String] = [
        "Sentadilla | 30\nDesplantes | 20\nStep-ups | 10",
        "Puente de gluteos | 20\nZancadas | 16\nElevacion de talones | 25",
        "Sentadilla | 20\nStep-ups | 14\nPuente de gluteos | 15"
    ]

    /// Un pack de fortalecimiento ligero: variantes + el grupo que estimula
    /// (para respetar el anti-overlap con los dias de fuerza adyacentes).
    struct MaintenancePack {
        let title: String
        let focus: String
        /// Grupo estimulado; si choca con la semana, el pack se salta.
        let bucket: ChallengeMuscleBucket
        let durationMinutes: Int
        let variants: [String]
    }

    /// Packs de mantenimiento en orden de rotacion. Todos son FUERZA ligera
    /// (no estiramiento): McGill para espalda, Pilates mat, calistenia, yoga
    /// de fuerza (posturas sostenidas) y activacion de manana con pasos.
    static let maintenancePacks: [MaintenancePack] = [
        // McGill Big 3: evidencia de estabilidad lumbar comparable a terapia
        // convencional en dolor cronico inespecifico; series cortas 5-3-1.
        MaintenancePack(
            title: "Espalda fuerte",
            focus: "Core y espalda",
            bucket: .back,
            durationMinutes: 10,
            variants: [
                "Curl-up McGill | 8\nPlancha lateral | 6\nBird-dog | 10",
                "Bird-dog | 12\nDead bug | 10\nPlancha lateral | 6",
                "Dead bug | 12\nSuperman | 12\nPlancha lateral | 8"
            ]
        ),
        // Pilates mat: control del centro con fuerza, sin equipo.
        MaintenancePack(
            title: "Pilates de centro",
            focus: "Core",
            bucket: .other,
            durationMinutes: 12,
            variants: [
                "El cien | 100\nRoll-up | 8\nCirculos de pierna | 10",
                "El cien | 100\nPuente de hombros | 12\nNado boca abajo | 30",
                "Teaser | 6\nPatada lateral | 12\nPuente de hombros | 15"
            ]
        ),
        // Calistenia: fuerza con peso corporal.
        MaintenancePack(
            title: "Calistenia express",
            focus: "Cuerpo completo",
            bucket: .other,
            durationMinutes: 12,
            variants: [
                "Hollow hold | 30s\nEscaladores | 30\nSentadilla con salto | 15",
                "Flexion pike | 10\nRemo invertido | 10\nHollow hold | 30s",
                "Burpees | 10\nFondos en banca | 12\nSuperman | 15"
            ]
        ),
        // Yoga de fuerza: posturas sostenidas, no estiramiento pasivo.
        MaintenancePack(
            title: "Yoga de fuerza",
            focus: "Estabilidad",
            bucket: .other,
            durationMinutes: 10,
            variants: [
                "Plancha alta | 45s\nPostura de la silla | 45s\nPostura del barco | 30s",
                "Postura del barco | 30s\nGuerrero III | 30s\nPlancha lateral con elevacion | 20s",
                "Postura de la silla | 60s\nPlancha alta | 45s\nGuerrero III | 30s"
            ]
        ),
        // Activacion de manana: de pie + banda + pasos.
        MaintenancePack(
            title: "Rutina de mañana",
            focus: "Activacion general",
            bucket: .other,
            durationMinutes: 10,
            variants: [
                "Abdominales de pie | 20\nMarcha con rodilla alta | 30\nPasos | 500",
                "Sentadilla en pared | 45s\nRemo con banda | 15\nPasos | 1000",
                "Paseo del monstruo | 20\nAlmeja con banda | 15\nEmpuje de cadera con banda | 15"
            ]
        )
    ]

    static let upperChallengeVariants: [String] = [
        "Flexiones | 20\nBand pull-aparts | 20\nFace pull | 15",
        "Fondos | 12\nFlexiones | 15\nPlancha | 3x30",
        "Flexiones | 15\nFace pull | 15\nCirculos de hombro | 20"
    ]
    func generateChallenges(
        days: [Int: DayAssignment],
        splitType: SplitType,
        cardioSport: CardioSport?,
        templateFocus: [UUID: String],
        sessionDetails: [Int: ScheduledSessionDetails] = [:]
    ) -> [Int: DailyChallengeDay] {
        let foci = dayFoci(
            days: days,
            splitType: splitType,
            templateFocus: templateFocus,
            sessionDetails: sessionDetails
        )
        var result: [Int: DailyChallengeDay] = [:]
        for weekday in 1...7 {
            let assignment = days[weekday] ?? .rest
            let forbidden = forbiddenBuckets(around: weekday, days: days, foci: foci)
            if let challenge = challenge(
                for: assignment,
                weekday: weekday,
                dayFocus: foci[weekday],
                cardioSport: cardioSport,
                forbidden: forbidden
            ) {
                result[weekday] = challenge
            }
        }
        return result
    }

    /// Rutina concreta para un día de movilidad/recuperación; se guarda como plantilla.
    func mobilityRoutine(focusHint: String? = nil, forbidden: Set<ChallengeMuscleBucket> = []) -> (focus: String, exercisesText: String, durationMinutes: Int) {
        let preferred = preferredMobilityFocus(hint: focusHint, forbidden: forbidden)
        return (
            preferred.label,
            mobilityPreset(for: preferred),
            15
        )
    }

    /// Cardio del plan: un solo ejercicio + minutos.
    func cardioRoutine(sport: CardioSport?, durationMinutes: Int) -> (focus: String, exercisesText: String, durationMinutes: Int) {
        let sport = sport ?? .walking
        let mins = max(10, min(durationMinutes, 90))
        return (sport.label, "\(sport.label) | \(mins) min", mins)
    }

    // MARK: - Day challenge builders

    private func challenge(
        for assignment: DayAssignment,
        weekday: Int,
        dayFocus: String?,
        cardioSport: CardioSport?,
        forbidden: Set<ChallengeMuscleBucket>
    ) -> DailyChallengeDay? {
        switch assignment {
        case .template, .contrast:
            return strengthOppositeChallenge(dayFocus: dayFocus, forbidden: forbidden, weekday: weekday)
        case .cardio:
            // Día cardio: challenge = movilidad corta de otra zona (anti-overlap).
            return mobilityChallenge(forbidden: forbidden.union([.legs, .lower]), title: "Movilidad corta")
        case .mobility, .recovery:
            // Día movilidad: challenge aparte (caminata o movilidad de otra zona).
            if !forbidden.contains(.cardio) {
                return DailyChallengeDay(
                    title: "Caminata suave",
                    kind: .walk,
                    focus: "Caminata",
                    exercisesText: "Caminata | 12 min",
                    durationMinutes: 12
                )
            }
            return mobilityChallenge(forbidden: forbidden, title: "Movilidad extra")
        case .rest:
            return restDayChallenge(weekday: weekday, forbidden: forbidden)
        case .plyometrics, .speed, .technique:
            return mobilityChallenge(forbidden: forbidden.union([.legs, .lower]), title: "Movilidad de descarga")
        }
    }

    private func strengthOppositeChallenge(
        dayFocus: String?,
        forbidden: Set<ChallengeMuscleBucket>,
        weekday: Int = 1
    ) -> DailyChallengeDay {
        let primary = ChallengeMuscleBucket.classify(dayFocus)
        let opposite: ChallengeMuscleBucket
        switch primary {
        case .lower, .legs: opposite = .upper
        case .upper, .push, .pull, .chest, .back, .shoulders, .arms: opposite = .lower
        case .full, .cardio, .other:
            opposite = forbidden.isDisjoint(with: ChallengeMuscleBucket.lower.conflicting) ? .lower : .upper
        }

        let safe = resolveFocus(preferred: opposite, forbidden: forbidden) ?? .other
        if safe == .lower || safe == .legs {
            return DailyChallengeDay(
                title: "Desafío de tren inferior",
                kind: .strengthOpposite,
                focus: "Tren inferior",
                exercisesText: Self.lowerChallengeVariants[weekday % Self.lowerChallengeVariants.count],
                durationMinutes: 12
            )
        }
        if safe == .upper || safe == .push || safe == .pull || safe == .chest || safe == .back || safe == .shoulders || safe == .arms {
            return DailyChallengeDay(
                title: "Desafío de tren superior",
                kind: .strengthOpposite,
                focus: "Tren superior",
                exercisesText: Self.upperChallengeVariants[weekday % Self.upperChallengeVariants.count],
                durationMinutes: 12
            )
        }
        return mobilityChallenge(forbidden: forbidden, title: "Movilidad suave")
    }

    private func restDayChallenge(weekday: Int, forbidden: Set<ChallengeMuscleBucket>) -> DailyChallengeDay {
        // Descanso = fortalecimiento ligero (no solo estiramiento). Se rota
        // entre packs (McGill, Pilates, calistenia, yoga de fuerza, manana) y
        // se salta el que choque con los dias de fuerza adyacentes. Cada
        // tercer dia queda movilidad, para variar el estimulo.
        if !weekday.isMultiple(of: 3) {
            let packs = Self.maintenancePacks
            let start = weekday % packs.count
            for offset in 0..<packs.count {
                let pack = packs[(start + offset) % packs.count]
                guard pack.bucket.conflicting.isDisjoint(with: forbidden) else { continue }
                return DailyChallengeDay(
                    title: pack.title,
                    kind: .maintenance,
                    focus: pack.focus,
                    exercisesText: pack.variants[weekday % pack.variants.count],
                    durationMinutes: pack.durationMinutes
                )
            }
        }
        // Alterna movilidad upper/lower en descanso sin chocar con la semana.
        let preferLower = weekday.isMultiple(of: 2)
        let preferred: ChallengeMuscleBucket = preferLower ? .lower : .upper
        let safe = resolveFocus(preferred: preferred, forbidden: forbidden) ?? .other
        if safe == .other || safe == .cardio {
            return DailyChallengeDay(
                title: "Movilidad de descanso",
                kind: .mobility,
                focus: "Movilidad general",
                exercisesText: """
                Gato-vaca | 10
                Respiracion diafragmatica | 8
                Estiramiento suave de cadera | 60s
                """,
                durationMinutes: 10
            )
        }
        return DailyChallengeDay(
            title: "Movilidad de descanso",
            kind: .mobility,
            focus: safe.label,
            exercisesText: mobilityPreset(for: safe),
            durationMinutes: 10
        )
    }

    private func mobilityChallenge(forbidden: Set<ChallengeMuscleBucket>, title: String) -> DailyChallengeDay {
        let safe = resolveFocus(preferred: .upper, forbidden: forbidden)
            ?? resolveFocus(preferred: .lower, forbidden: forbidden)
            ?? .other
        return DailyChallengeDay(
            title: title,
            kind: .mobility,
            focus: safe == .other ? "Movilidad general" : safe.label,
            exercisesText: mobilityPreset(for: safe),
            durationMinutes: 12
        )
    }

    // MARK: - Focus / anti-overlap

    private func dayFoci(
        days: [Int: DayAssignment],
        splitType: SplitType,
        templateFocus: [UUID: String],
        sessionDetails: [Int: ScheduledSessionDetails]
    ) -> [Int: String] {
        var strengthIndex = 0
        let rotation = splitType.focusRotation
        var result: [Int: String] = [:]
        for weekday in (1...7) {
            if let override = sessionDetails[weekday]?.focusOverride, !override.isEmpty {
                result[weekday] = override
                continue
            }
            switch days[weekday] ?? .rest {
            case .template(let id):
                if let focus = templateFocus[id], !focus.isEmpty {
                    result[weekday] = focus
                } else if !rotation.isEmpty {
                    result[weekday] = rotation[strengthIndex % rotation.count]
                    strengthIndex += 1
                }
            case .cardio(let name):
                result[weekday] = DayAssignment.sport(fromCardioName: name)?.label ?? name
            case .mobility:
                result[weekday] = "Movilidad"
            case .recovery:
                result[weekday] = "Recuperación"
            case .contrast:
                result[weekday] = rotation.isEmpty ? "Full body" : rotation[strengthIndex % rotation.count]
                strengthIndex += 1
            default:
                break
            }
        }
        return result
    }

    /// Prohibido: foco del mismo día + días de fuerza adyacentes (±1 en el calendario 1...7 circular).
    private func forbiddenBuckets(
        around weekday: Int,
        days: [Int: DayAssignment],
        foci: [Int: String]
    ) -> Set<ChallengeMuscleBucket> {
        var forbidden = Set<ChallengeMuscleBucket>()
        let neighbors = [weekday, wrap(weekday - 1), wrap(weekday + 1)]
        for day in neighbors {
            let assignment = days[day] ?? .rest
            guard isPriorityStrength(assignment) || day == weekday else { continue }
            let bucket = ChallengeMuscleBucket.classify(foci[day])
            forbidden.formUnion(bucket.conflicting)
        }
        // El mismo día siempre aporta su foco (aunque sea cardio/movilidad).
        if let today = foci[weekday] {
            forbidden.formUnion(ChallengeMuscleBucket.classify(today).conflicting)
        }
        return forbidden
    }

    private func isPriorityStrength(_ assignment: DayAssignment) -> Bool {
        switch assignment {
        case .template, .contrast: true
        default: false
        }
    }

    private func wrap(_ day: Int) -> Int {
        let x = ((day - 1) % 7 + 7) % 7
        return x + 1
    }

    private func resolveFocus(
        preferred: ChallengeMuscleBucket,
        forbidden: Set<ChallengeMuscleBucket>
    ) -> ChallengeMuscleBucket? {
        if preferred.conflicting.isDisjoint(with: forbidden) { return preferred }
        let fallbacks: [ChallengeMuscleBucket] = [.upper, .lower, .shoulders, .other]
        return fallbacks.first { $0.conflicting.isDisjoint(with: forbidden) }
    }

    private func preferredMobilityFocus(
        hint: String?,
        forbidden: Set<ChallengeMuscleBucket>
    ) -> ChallengeMuscleBucket {
        let fromHint = ChallengeMuscleBucket.classify(hint)
        if let resolved = resolveFocus(preferred: fromHint == .other ? .upper : fromHint, forbidden: forbidden) {
            return resolved
        }
        return .other
    }

    private func mobilityPreset(for bucket: ChallengeMuscleBucket) -> String {
        switch bucket {
        case .lower, .legs:
            return """
            Movilidad de cadera 90/90 | 60s
            Estiramiento de isquios | 45s
            Paloma | 45s
            Estiramiento de cuadriceps | 45s
            Rotacion de tobillo | 20
            """
        case .upper, .push, .pull, .chest, .back, .arms:
            return """
            Aperturas de pecho en puerta | 45s
            Cobra | 30s
            Postura del nino | 45s
            Circulos de hombro | 20
            Gato-vaca | 10
            """
        case .shoulders:
            return """
            Movilidad de hombro con banda | 15
            Estiramiento cruzado de hombro | 45s
            Perro boca abajo | 30s
            Rotaciones externas suaves | 12
            """
        case .full, .cardio, .other:
            return """
            Gato-vaca | 10
            Rotacion toracica | 12
            Postura del triangulo | 30s
            Torsion espinal acostado | 45s
            Estiramiento suave de cadera | 60s
            """
        }
    }
}
