import Foundation
import UserNotifications

extension Notification.Name {
    /// Deep link pedido desde una notificacion local (userInfo: `url`).
    static let recvelOpenDeepLink = Notification.Name("recvel.open.deepLink")
}

/// Enruta el tap sobre una notificacion local al deep link que trae en su
/// `userInfo`. Sin esto la notificacion abre la app pero no lleva a ningun lado.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    static let deepLinkKey = "recvel.deeplink"

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let raw = response.notification.request.content.userInfo[Self.deepLinkKey] as? String,
              let url = URL(string: raw) else { return }
        NotificationCenter.default.post(name: .recvelOpenDeepLink, object: url)
    }

    /// Con la app en primer plano seguimos mostrando el aviso: si el usuario
    /// pidio recordatorios, silenciarlos por estar dentro es incumplir.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
