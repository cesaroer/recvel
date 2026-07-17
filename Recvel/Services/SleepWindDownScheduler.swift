import Foundation

/// Horarios suaves de rutina / cama / luces a partir de la hora de cama del Plan.
///
/// Heuristica de bienestar (estilo wind-down 30-60 min): no es consejo clinico.
/// Evita spam fusionando avisos cercanos (`minGapMinutes`).
///
/// Los pasos de rutina se encadenan hacia atras desde la cama por duracion:
/// el ultimo termina en "en cama"; los anteriores empiezan antes sumando
/// las duraciones siguientes.
enum SleepWindDownScheduler {
    enum ReminderKind: String, CaseIterable, Equatable {
        case routineStart
        case inBed
        case lightsOut

        var notificationID: String {
            switch self {
            case .routineStart: return "recvel.plan.winddown"
            case .inBed: return "recvel.plan.inbed"
            case .lightsOut: return "recvel.plan.lightsout"
            }
        }

        var title: String {
            switch self {
            case .routineStart: return "Hora de empezar la rutina"
            case .inBed: return "Hora de estar en cama"
            case .lightsOut: return "Hora de apagar luces"
            }
        }

        var body: String {
            switch self {
            case .routineStart:
                return "Baja el ritmo: un wind-down corto acerca tu ventana de sueno."
            case .inBed:
                return "Es un buen momento para estar en cama y cerrar el dia con calma."
            case .lightsOut:
                return "Apaga luces y pantallas; deja que el cuerpo encare el descanso."
            }
        }
    }

    struct ReminderSlot: Equatable {
        let kind: ReminderKind
        let fireDate: Date

        var minutesOfDay: Int {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: fireDate)
            let minute = calendar.component(.minute, from: fireDate)
            return hour * 60 + minute
        }
    }

    /// Presets tipicos de higiene del sueno. `durationMinutes` es la duracion del bloque;
    /// el offset real se calcula encadenando con el resto de pasos.
    struct Preset: Identifiable, Equatable {
        let id: String
        let title: String
        let iconName: String
        let durationMinutes: Int
    }

    static let presets: [Preset] = [
        Preset(id: "screens", title: "Sin pantallas", iconName: "iphone.slash", durationMinutes: 30),
        Preset(id: "bath", title: "Bano", iconName: "drop.fill", durationMinutes: 20),
        Preset(id: "read", title: "Lectura", iconName: "book.fill", durationMinutes: 20),
        Preset(id: "stretch", title: "Estiramientos", iconName: "figure.flexibility", durationMinutes: 15),
        Preset(id: "breathe", title: "Respiracion", iconName: "wind", durationMinutes: 15)
    ]

    /// Minutos antes de cama para iniciar el wind-down si no hay pasos de rutina.
    static let defaultWindDownMinutes = 45
    /// Luces unos minutos despues de "en cama" (suave, no segundo aviso pegado).
    static let defaultLightsOutDelayMinutes = 8
    /// Fusiona avisos si quedan demasiado cerca.
    static let defaultMinGapMinutes = 20

    /// Encadena duraciones en orden cronologico (primer paso = mas temprano).
    /// Cada valor es minutos antes de cama en que empieza ese paso.
    ///
    /// Ejemplo: `[15, 15]` (estiramientos, respiracion) → `[30, 15]`.
    static func chainedOffsetsBeforeBed(durationsInOrder: [Int]) -> [Int] {
        guard !durationsInOrder.isEmpty else { return [] }
        var remaining = 0
        var offsets = Array(repeating: 0, count: durationsInOrder.count)
        for index in stride(from: durationsInOrder.count - 1, through: 0, by: -1) {
            remaining += max(durationsInOrder[index], 0)
            offsets[index] = remaining
        }
        return offsets
    }

    /// Offset del paso mas temprano (inicio de toda la cadena), o 0 si no hay pasos.
    static func earliestOffsetBeforeBed(durationsInOrder: [Int]) -> Int {
        chainedOffsetsBeforeBed(durationsInOrder: durationsInOrder).max() ?? 0
    }

    /// Calcula hasta 3 avisos diarios alineados a `bedtime`.
    ///
    /// - `routineOffsetsBeforeBed`: minutos antes de cama ya encadenados (puede estar vacio).
    /// - El inicio de rutina usa el mayor offset, o `defaultWindDownMinutes` si no hay pasos.
    static func reminderSlots(
        bedtime: Date,
        routineOffsetsBeforeBed: [Int] = [],
        windDownMinutes: Int = defaultWindDownMinutes,
        lightsOutDelayMinutes: Int = defaultLightsOutDelayMinutes,
        minGapMinutes: Int = defaultMinGapMinutes
    ) -> [ReminderSlot] {
        let startOffset = max(
            windDownMinutes,
            routineOffsetsBeforeBed.filter { $0 > 0 }.max() ?? 0
        )
        let candidates: [ReminderSlot] = [
            ReminderSlot(
                kind: .routineStart,
                fireDate: bedtime.addingTimeInterval(-Double(startOffset) * 60)
            ),
            ReminderSlot(kind: .inBed, fireDate: bedtime),
            ReminderSlot(
                kind: .lightsOut,
                fireDate: bedtime.addingTimeInterval(Double(max(lightsOutDelayMinutes, 0)) * 60)
            )
        ]

        return coalesce(candidates, minGapMinutes: minGapMinutes)
    }

    /// Atajo: slots a partir de duraciones en orden (encadena y agenda).
    static func reminderSlots(
        bedtime: Date,
        routineDurationsInOrder: [Int],
        windDownMinutes: Int = defaultWindDownMinutes,
        lightsOutDelayMinutes: Int = defaultLightsOutDelayMinutes,
        minGapMinutes: Int = defaultMinGapMinutes
    ) -> [ReminderSlot] {
        reminderSlots(
            bedtime: bedtime,
            routineOffsetsBeforeBed: chainedOffsetsBeforeBed(durationsInOrder: routineDurationsInOrder),
            windDownMinutes: windDownMinutes,
            lightsOutDelayMinutes: lightsOutDelayMinutes,
            minGapMinutes: minGapMinutes
        )
    }

    /// Minutos del dia (0-1439) para un disparo diario repetible.
    static func minutesOfDay(from date: Date, calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return ((hour * 60 + minute) % 1440 + 1440) % 1440
    }

    /// Hora absoluta de un paso: `bedtime - minutesBeforeBed`.
    static func stepFireDate(bedtime: Date, minutesBeforeBed: Int) -> Date {
        bedtime.addingTimeInterval(-Double(max(minutesBeforeBed, 0)) * 60)
    }

    private static func coalesce(_ slots: [ReminderSlot], minGapMinutes: Int) -> [ReminderSlot] {
        let gap = Double(max(minGapMinutes, 1)) * 60
        /// En cama y luces pueden ir cerca a proposito; solo fusionamos el inicio de rutina si queda pegado.
        let hardFloor: TimeInterval = 90
        var kept: [ReminderSlot] = []
        for slot in slots.sorted(by: { $0.fireDate < $1.fireDate }) {
            guard let last = kept.last else {
                kept.append(slot)
                continue
            }
            let delta = slot.fireDate.timeIntervalSince(last.fireDate)
            let involvesRoutine = last.kind == .routineStart || slot.kind == .routineStart
            let threshold = involvesRoutine ? gap : hardFloor
            if delta < threshold {
                kept[kept.count - 1] = preferred(last, slot)
            } else {
                kept.append(slot)
            }
        }
        return kept
    }

    private static func preferred(_ a: ReminderSlot, _ b: ReminderSlot) -> ReminderSlot {
        let rank: (ReminderKind) -> Int = {
            switch $0 {
            case .lightsOut: return 3
            case .inBed: return 2
            case .routineStart: return 1
            }
        }
        return rank(b.kind) >= rank(a.kind) ? b : a
    }
}
