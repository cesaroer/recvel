import Foundation

/// Próxima sesión del plan semanal, para el hero de Entrenamiento.
struct NextTrainingSession: Equatable {
    /// Weekday de Calendar (1 = domingo … 7 = sábado) del día encontrado.
    let weekday: Int
    /// 0 = hoy, 1 = mañana…
    let daysAway: Int
    let assignment: DayAssignment
}

/// Estado visual de un día en la tira del resumen semanal.
enum TrainingWeekDayState: Equatable {
    /// Tocaba entrenar y hay al menos una sesión registrada ese día.
    case completed
    /// Tocaba entrenar, el día ya pasó y no hay sesión.
    case missed
    /// Día de descanso del plan (incluye movilidad/recuperación NO: esas son
    /// sesiones ligeras pero sesiones; descanso es solo `.rest`).
    case rest
    /// Tocaba entrenar y el día aún no termina (hoy sin sesión todavía) o es futuro.
    case upcoming
}

struct TrainingWeekDay: Equatable {
    let weekday: Int
    let state: TrainingWeekDayState
}

/// Resumen de la semana en curso (lunes a domingo, como la tira de iniciales
/// del resto de la app).
struct TrainingWeekSummary: Equatable {
    let days: [TrainingWeekDay]
    /// Sesiones hechas en días planeados de la semana completa.
    let completed: Int
    /// Días con sesión planeada en la semana completa.
    let planned: Int
    /// Cumplimiento HASTA HOY: hechas / planeadas cuyo día ya empezó. `nil`
    /// cuando aún no ha tocado ninguna (no hay nada que porcentuar).
    let onTrackPercent: Int?
}

/// Datos de la cabecera de Entrenamiento (hero + resumen). Funciones puras:
/// reciben el plan y las fechas de sesiones y no tocan ni SwiftData ni
/// HealthKit, para poder verificarlas con fechas sintéticas.
enum TrainingHeaderEngine {
    /// Sesión del hero: la siguiente incompleta del plan.
    ///
    /// Mientras hoy no tenga un entrenamiento registrado, se ofrece como
    /// **hoy** (aunque el hueco del plan sea mañana): no adelantar el badge a
    /// "Mañana" hasta que el de hoy ya esté hecho. Si hoy ya se entrenó, sí
    /// avanza al siguiente día de plan con el desfase real.
    static func nextSession(
        routine: WeeklyRoutine,
        sessionDates: [Date] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> NextTrainingSession? {
        guard routine.onboarded else { return nil }
        let today = calendar.startOfDay(for: now)
        let todayWeekday = calendar.component(.weekday, from: today)
        let completedDays = Set(sessionDates.map { calendar.startOfDay(for: $0) })
        let todayAssignment = routine.days[todayWeekday] ?? .rest
        // Un registro en día de descanso (o el running demo de "hoy") no cuenta
        // como haber hecho la sesión del plan. Solo un día planeado cerrado
        // adelanta el badge a mañana.
        let trainedToday = todayAssignment != .rest && completedDays.contains(today)

        if todayAssignment != .rest && !trainedToday {
            return NextTrainingSession(weekday: todayWeekday, daysAway: 0, assignment: todayAssignment)
        }

        for offset in 1...7 {
            let weekday = ((todayWeekday - 1 + offset) % 7) + 1
            if let assignment = routine.days[weekday], assignment != .rest {
                return NextTrainingSession(
                    weekday: weekday,
                    daysAway: trainedToday ? offset : 0,
                    assignment: assignment
                )
            }
        }
        return nil
    }

    /// Semana en curso, lunes a domingo.
    ///
    /// `sessionDates` son las fechas de inicio de CUALQUIER sesión registrada
    /// (HealthKit o manual): el criterio de "completado" es haber entrenado el
    /// día planeado, no haber clavado la sesión exacta — el plan es una guía,
    /// no un contrato.
    static func weekSummary(
        routine: WeeklyRoutine,
        sessionDates: [Date],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TrainingWeekSummary {
        let today = calendar.startOfDay(for: now)
        let daysWithSession = Set(sessionDates.map { calendar.startOfDay(for: $0) })

        // Lunes de la semana en curso, sin depender del firstWeekday del
        // dispositivo: la tira siempre se pinta lunes-primero.
        let weekdayToday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekdayToday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return TrainingWeekSummary(days: [], completed: 0, planned: 0, onTrackPercent: nil)
        }

        var days: [TrainingWeekDay] = []
        var completed = 0
        var planned = 0
        var plannedSoFar = 0
        var completedSoFar = 0

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let assignment = routine.days[weekday] ?? .rest
            let isPlanned = assignment != .rest
            let hasSession = daysWithSession.contains(date)

            let state: TrainingWeekDayState
            if !isPlanned {
                // Una sesión en día de descanso no cambia el estado del día:
                // sigue siendo descanso del plan (y no penaliza ni premia).
                state = .rest
            } else if hasSession {
                state = .completed
            } else if date < today {
                state = .missed
            } else {
                state = .upcoming
            }
            days.append(TrainingWeekDay(weekday: weekday, state: state))

            if isPlanned {
                planned += 1
                if hasSession { completed += 1 }
                if date <= today {
                    plannedSoFar += 1
                    if hasSession { completedSoFar += 1 }
                }
            }
        }

        // Hoy cuenta como "planeado hasta ahora" solo si ya se entrenó: un día
        // planeado que aún no termina no puede estar incumplido.
        if let todayEntry = days.first(where: { calendarWeekday(of: today, calendar) == $0.weekday }),
           todayEntry.state == .upcoming {
            plannedSoFar -= 1
        }

        let percent: Int?
        if plannedSoFar > 0 {
            percent = Int((Double(completedSoFar) / Double(plannedSoFar) * 100).rounded())
        } else {
            percent = nil
        }

        return TrainingWeekSummary(
            days: days,
            completed: completed,
            planned: planned,
            onTrackPercent: percent
        )
    }

    private static func calendarWeekday(of date: Date, _ calendar: Calendar) -> Int {
        calendar.component(.weekday, from: date)
    }
}
