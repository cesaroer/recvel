#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct RecvelFastingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let phaseID: String
        let statusID: String
        let languageCode: String

        var displayLanguage: AppLanguage {
            AppLanguage(rawValue: languageCode) ?? .system
        }

        var phaseName: String {
            RecvelL10n.text(phaseID, language: displayLanguage)
        }

        var status: String {
            RecvelL10n.text(statusID, language: displayLanguage)
        }
    }

    let sessionID: UUID
    let startDate: Date
    let targetDate: Date
    let protocolName: String
}
#endif
