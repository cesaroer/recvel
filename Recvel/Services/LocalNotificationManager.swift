import Foundation
import UserNotifications

struct LocalNotificationManager {
    private let center = UNUserNotificationCenter.current()

    private static let planSleepIDs = SleepWindDownScheduler.ReminderKind.allCases.map(\.notificationID)

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleMorning(enabled: Bool, wakeMinutes: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: ["recvel.morning"])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tu briefing esta listo"
        content.body = "Revisa Recovery, sueno y la carga sugerida para hoy."
        content.sound = .default
        let minutes = normalized(wakeMinutes + 15)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: "recvel.morning", content: content, trigger: trigger))
    }

    func scheduleBedtime(enabled: Bool, wakeMinutes: Int, sleepGoalHours: Double) async {
        center.removePendingNotificationRequests(withIdentifiers: ["recvel.bedtime"])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Empieza a cerrar el dia"
        content.body = "Tu ventana de sueno comienza pronto. Baja el ritmo y protege tu horario."
        content.sound = .default
        let bedtime = wakeMinutes - Int(sleepGoalHours * 60) - 45
        let minutes = normalized(bedtime)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: "recvel.bedtime", content: content, trigger: trigger))
    }

    func scheduleJournal(morning: Bool, evening: Bool, continuity: Bool, wakeMinutes: Int) async {
        let ids = ["recvel.journal.morning", "recvel.journal.evening", "recvel.journal.continuity"]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        if morning {
            await addDaily(
                id: ids[0],
                title: "Completa la noche",
                body: "Registra solo lo que recuerdes y deja lo demas como desconocido.",
                minutes: normalized(wakeMinutes + 20)
            )
        }
        if evening {
            await addDaily(
                id: ids[1],
                title: "Cierra tu Journal",
                body: "Un minuto de contexto hace mas utiles tus patrones personales.",
                minutes: normalized(wakeMinutes + 13 * 60)
            )
        }
        if continuity {
            await addDaily(
                id: ids[2],
                title: "Tu registro sigue abierto",
                body: "Puedes completar una sola entrada; no hace falta llenar todo.",
                minutes: normalized(wakeMinutes + 15 * 60)
            )
        }
    }

    /// Recordatorio opcional de ventana de movimiento (Plan).
    func schedulePlanWorkout(enabled: Bool, hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: ["recvel.plan.workout"])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ventana de movimiento"
        content.body = "Si encaja, un bloque corto de 20+ min acerca tu meta semanal."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: "recvel.plan.workout", content: content, trigger: trigger))
    }

    /// Recordatorio opcional para revisar Plan / enfoque del dia.
    func schedulePlanCheckIn(enabled: Bool, hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: ["recvel.plan.checkin"])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Revisa tu plan"
        content.body = "Un vistazo a enfoque, sueno de esta noche y metas de la semana."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: "recvel.plan.checkin", content: content, trigger: trigger))
    }

    /// Avisos suaves de wind-down / en cama / luces alineados a la hora de cama del Plan (ciclos).
    /// Maximo tres; no spamea pasos individuales de la rutina.
    func schedulePlanSleepReminders(enabled: Bool, slots: [SleepWindDownScheduler.ReminderSlot]) async {
        center.removePendingNotificationRequests(withIdentifiers: Self.planSleepIDs)
        guard enabled else { return }
        for slot in slots {
            let content = UNMutableNotificationContent()
            content.title = slot.kind.title
            content.body = slot.kind.body
            content.sound = .default
            let minutes = SleepWindDownScheduler.minutesOfDay(from: slot.fireDate)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
                repeats: true
            )
            try? await center.add(
                UNNotificationRequest(
                    identifier: slot.kind.notificationID,
                    content: content,
                    trigger: trigger
                )
            )
        }
    }

    func pendingStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Cancela pendientes y entregadas de Recvel (fresh install local).
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func normalized(_ minutes: Int) -> Int {
        (minutes % 1440 + 1440) % 1440
    }

    private func addDaily(id: String, title: String, body: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            repeats: true
        )
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
