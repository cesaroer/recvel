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
        content.title = RecvelL10n.text("notification.morning.title")
        content.body = RecvelL10n.text("notification.morning.body")
        content.sound = .default
        // El texto se queda sobrio a proposito: una notificacion local no puede
        // recalcular al dispararse, asi que las cifras se calculan al abrir el
        // reporte. El deep link es lo que da el valor.
        content.userInfo = [NotificationRouter.deepLinkKey: "recvel://morning"]
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
        content.title = RecvelL10n.text("notification.bedtime.title")
        content.body = RecvelL10n.text("notification.bedtime.body")
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
                title: RecvelL10n.text("notification.journal.morning.title"),
                body: RecvelL10n.text("notification.journal.morning.body"),
                minutes: normalized(wakeMinutes + 20)
            )
        }
        if evening {
            await addDaily(
                id: ids[1],
                title: RecvelL10n.text("notification.journal.evening.title"),
                body: RecvelL10n.text("notification.journal.evening.body"),
                minutes: normalized(wakeMinutes + 13 * 60)
            )
        }
        if continuity {
            await addDaily(
                id: ids[2],
                title: RecvelL10n.text("notification.journal.continuity.title"),
                body: RecvelL10n.text("notification.journal.continuity.body"),
                minutes: normalized(wakeMinutes + 15 * 60)
            )
        }
    }

    /// Recordatorio opcional de ventana de movimiento (Plan).
    func schedulePlanWorkout(enabled: Bool, hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: ["recvel.plan.workout"])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = RecvelL10n.text("notification.movement.title")
        content.body = RecvelL10n.text("notification.movement.body")
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
        content.title = RecvelL10n.text("notification.plan.title")
        content.body = RecvelL10n.text("notification.plan.body")
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

    func relocalizePendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        for request in requests where request.identifier.hasPrefix("recvel.") {
            guard let copy = localizedContent(for: request.identifier), let trigger = request.trigger else { continue }
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
            try? await center.add(
                UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            )
        }
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


    private func localizedContent(for identifier: String) -> (title: String, body: String)? {
        let keys: (String, String)? = switch identifier {
        case "recvel.morning": ("notification.morning.title", "notification.morning.body")
        case "recvel.bedtime": ("notification.bedtime.title", "notification.bedtime.body")
        case "recvel.journal.morning": ("notification.journal.morning.title", "notification.journal.morning.body")
        case "recvel.journal.evening": ("notification.journal.evening.title", "notification.journal.evening.body")
        case "recvel.journal.continuity": ("notification.journal.continuity.title", "notification.journal.continuity.body")
        case "recvel.plan.workout": ("notification.movement.title", "notification.movement.body")
        case "recvel.plan.checkin": ("notification.plan.title", "notification.plan.body")
        case "recvel.plan.winddown": ("notification.winddown.title", "notification.winddown.body")
        case "recvel.plan.inbed": ("notification.inBed.title", "notification.inBed.body")
        case "recvel.plan.lightsout": ("notification.lightsOut.title", "notification.lightsOut.body")
        default: nil
        }
        guard let keys else { return nil }
        return (RecvelL10n.text(keys.0), RecvelL10n.text(keys.1))
    }
}
