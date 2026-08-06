import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class LanguageController: ObservableObject {
    @Published private(set) var selection: AppLanguage

    init(selection: AppLanguage = RecvelLanguageStore.load()) {
        self.selection = selection
    }

    var resolvedLanguage: AppLanguage { selection.resolved() }
    var locale: Locale { Locale(identifier: selection.localeIdentifier) }

    func select(_ language: AppLanguage) {
        guard selection != language else { return }
        selection = language
        RecvelLanguageStore.save(language)
        let snapshot = RecvelSharedSnapshotStore.load().updatingLanguage(language)
        RecvelSharedSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        WatchSyncManager.shared.send(snapshot)
        NotificationCenter.default.post(name: .recvelLanguageDidChange, object: language)
        Task { await FastingLiveActivityManager.relocalizeActiveActivities(to: language) }
    }
}

extension Notification.Name {
    static let recvelLanguageDidChange = Notification.Name("recvel.language.didChange")
}
