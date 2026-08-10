import Foundation

/// Fila de la pantalla de insights de Recuperación: una conducta y su
/// asociación con el score. `association.delta` está en puntos de
/// Recuperación (el score es 0-100, así que un punto equivale a un 1 %).
struct RecoveryImpactRow: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let association: JournalAssociation
}

/// Los tres niveles de la pantalla, calcados de la referencia de Bevel pero
/// con el criterio explícito (nunca "confianza" sin definición):
///  · `confident`   — al menos `minimumConfidentPerGroup` días en cada grupo.
///  · `lowConfidence` — ya junta 5 y 5 (el mínimo del motor) pero menos que lo
///    anterior: la diferencia de medias todavía se mueve mucho con cada día.
///  · `locked`      — aún no junta 5 sí y 5 no; se muestra el progreso.
struct RecoveryInsights: Equatable {
    let confident: [RecoveryImpactRow]
    let lowConfidence: [RecoveryImpactRow]
    let locked: [RecoveryImpactRow]

    var isEmpty: Bool { confident.isEmpty && lowConfidence.isEmpty && locked.isEmpty }
}

/// Asocia conductas con la Recuperación, en dos familias:
///
///  · **Automáticas** (pasos, cardio, fuerza, zona 2, luz, siestas): se evalúan
///    sobre el día D y se emparejan con la Recuperación de la mañana del día
///    D+1, que es la que puede reflejar lo que hiciste ese día.
///  · **Manuales** (tags del Journal): se emparejan con el mismo día porque su
///    redacción ya encierra el desfase ("Consumiste alcohol ayer").
///
/// Todo son asociaciones locales de medias, el mismo estadístico que ya usa
/// `JournalImpactEngine` (5 mínimos por grupo). Nunca causalidad.
enum RecoveryInsightsEngine {
    /// Ventana de análisis, igual que la referencia ("last 90 days").
    static let windowDays = 90
    /// Días por grupo para considerar la asociación estable.
    static let minimumConfidentPerGroup = 8

    struct BehaviorSpec {
        let id: String
        let symbol: String
        let titleKey: String
        /// `nil` = ese día no hay dato para evaluar la conducta; el día no
        /// cuenta como "no" (un día sin workouts registrados no es un día
        /// sin entrenar, es un día sin señal).
        let isMet: (DailyHealthSnapshot) -> Bool?
    }

    /// Mismos umbrales que los trackers automáticos del Journal
    /// (`JournalCatalog.builtIns`) y MISMAS claves de título
    /// (`journal.tag.<id>.title`), para que las dos pantallas cuenten la
    /// misma historia en los dos idiomas.
    static let behaviors: [BehaviorSpec] = [
        BehaviorSpec(id: "behavior.steps", symbol: "figure.walk", titleKey: "journal.tag.auto.steps.title") { snapshot in
            snapshot.steps.map { $0 >= 10_000 }
        },
        BehaviorSpec(id: "behavior.cardio", symbol: "heart.circle.fill", titleKey: "journal.tag.auto.cardio.title") { snapshot in
            snapshot.workoutMinutes.map { $0 >= 20 }
        },
        BehaviorSpec(id: "behavior.strength", symbol: "dumbbell.fill", titleKey: "journal.tag.auto.strength.title") { snapshot in
            guard !snapshot.workouts.isEmpty else { return nil }
            let minutes = snapshot.workouts
                .filter {
                    $0.activityName.localizedCaseInsensitiveContains("fuerza")
                        || $0.activityName.localizedCaseInsensitiveContains("strength")
                }
                .reduce(0) { $0 + $1.durationMinutes }
            return minutes >= 20
        },
        BehaviorSpec(id: "behavior.zone2", symbol: "figure.run.circle.fill", titleKey: "journal.tag.auto.zone2.title") { snapshot in
            guard !snapshot.workouts.isEmpty else { return nil }
            let minutes = snapshot.workouts.flatMap(\.zones).filter { $0.zone == 2 }.reduce(0) { $0 + $1.minutes }
            return minutes >= 30
        },
        BehaviorSpec(id: "behavior.daylight", symbol: "sun.max.fill", titleKey: "journal.tag.auto.daylight.title") { snapshot in
            snapshot.daylightMinutes.map { $0 >= 20 }
        },
        BehaviorSpec(id: "behavior.nap", symbol: "powersleep", titleKey: "journal.tag.auto.nap.title") { snapshot in
            snapshot.sleepDetails.map { $0.napHours * 60 >= 10 }
        }
    ]

    /// Conducta del día D → Recuperación del día D+1. Solo cuentan pares de
    /// días consecutivos con dato en ambos lados.
    static func behaviorImpacts(
        history: [DailyHealthSnapshot],
        scoreEngine: ScoreEngine = ScoreEngine(),
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [RecoveryImpactRow] {
        let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let ordered = history
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        guard ordered.count >= 2 else {
            return behaviors.map {
                RecoveryImpactRow(
                    id: $0.id,
                    symbol: $0.symbol,
                    title: RecvelL10n.text($0.titleKey),
                    association: JournalAssociation(delta: nil, yesCount: 0, noCount: 0)
                )
            }
        }

        // Recuperación por día, calculada una sola vez.
        var recoveryByDay: [Date: Int] = [:]
        for snapshot in ordered {
            let day = calendar.startOfDay(for: snapshot.date)
            recoveryByDay[day] = scoreEngine
                .scores(for: snapshot, history: history)
                .first { $0.kind == .recovery }?
                .value
        }

        return behaviors.map { spec in
            var pairs: [(answer: Bool, value: Int)] = []
            for snapshot in ordered {
                guard let answer = spec.isMet(snapshot) else { continue }
                let day = calendar.startOfDay(for: snapshot.date)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                      let nextRecovery = recoveryByDay[nextDay] else { continue }
                pairs.append((answer, nextRecovery))
            }
            return RecoveryImpactRow(
                id: spec.id,
                symbol: spec.symbol,
                title: RecvelL10n.text(spec.titleKey),
                association: JournalImpactEngine.association(pairs: pairs)
            )
        }
    }

    /// Reparte las filas en los tres niveles y ordena por magnitud.
    static func assemble(_ rows: [RecoveryImpactRow]) -> RecoveryInsights {
        var confident: [RecoveryImpactRow] = []
        var lowConfidence: [RecoveryImpactRow] = []
        var locked: [RecoveryImpactRow] = []

        for row in rows {
            let association = row.association
            if !association.isReady {
                locked.append(row)
            } else if min(association.yesCount, association.noCount) >= minimumConfidentPerGroup {
                confident.append(row)
            } else {
                lowConfidence.append(row)
            }
        }

        func byMagnitude(_ lhs: RecoveryImpactRow, _ rhs: RecoveryImpactRow) -> Bool {
            abs(lhs.association.delta ?? 0) > abs(rhs.association.delta ?? 0)
        }
        // Bloqueados: primero los que están más cerca de desbloquearse.
        func byProgress(_ lhs: RecoveryImpactRow, _ rhs: RecoveryImpactRow) -> Bool {
            let lhsMissing = missingAnswers(lhs.association)
            let rhsMissing = missingAnswers(rhs.association)
            return lhsMissing == rhsMissing ? lhs.title < rhs.title : lhsMissing < rhsMissing
        }

        return RecoveryInsights(
            confident: confident.sorted(by: byMagnitude),
            lowConfidence: lowConfidence.sorted(by: byMagnitude),
            locked: locked.sorted(by: byProgress)
        )
    }

    static func missingAnswers(_ association: JournalAssociation) -> Int {
        max(JournalImpactEngine.minimumPerGroup - association.yesCount, 0)
            + max(JournalImpactEngine.minimumPerGroup - association.noCount, 0)
    }
}
