import Foundation
import WatchConnectivity

final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()
    static let snapshotMessageKey = "healthSnapshot"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snapshot: RecvelSharedSnapshot) {
        guard WCSession.isSupported(), let data = RecvelSharedSnapshotStore.encoded(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([Self.snapshotMessageKey: data])
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        send(RecvelSharedSnapshotStore.load())
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["requestSnapshot"] as? Bool == true,
              let data = RecvelSharedSnapshotStore.encoded(RecvelSharedSnapshotStore.load()) else {
            replyHandler([:])
            return
        }
        replyHandler([Self.snapshotMessageKey: data])
    }
}
