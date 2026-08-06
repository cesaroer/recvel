import ActivityKit
import Foundation

@MainActor
enum FastingLiveActivityManager {
    static func start(
        sessionID: UUID,
        startDate: Date,
        targetDate: Date,
        protocolName: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endActivities(except: sessionID)
        if let existing = Activity<RecvelFastingAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
            let datesChanged = abs(existing.attributes.startDate.timeIntervalSince(startDate)) > 1
                || abs(existing.attributes.targetDate.timeIntervalSince(targetDate)) > 1
            if !datesChanged { return }
            await existing.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = RecvelFastingAttributes(
            sessionID: sessionID,
            startDate: startDate,
            targetDate: targetDate,
            protocolName: protocolName
        )
        let content = ActivityContent(
            state: RecvelFastingAttributes.ContentState(
                phaseID: "fasting.live.active",
                statusID: "fasting.live.inProgress",
                languageCode: RecvelLanguageStore.load().rawValue
            ),
            staleDate: targetDate
        )
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end(sessionID: UUID) async {
        let final = ActivityContent(
            state: RecvelFastingAttributes.ContentState(
                phaseID: "fasting.live.completed",
                statusID: "fasting.live.finished",
                languageCode: RecvelLanguageStore.load().rawValue
            ),
            staleDate: nil
        )
        for activity in Activity<RecvelFastingAttributes>.activities where activity.attributes.sessionID == sessionID {
            await activity.end(final, dismissalPolicy: .after(.now.addingTimeInterval(60)))
        }
    }

    static func synchronize(
        sessionID: UUID,
        startDate: Date,
        targetDate: Date,
        protocolName: String
    ) async {
        await start(
            sessionID: sessionID,
            startDate: startDate,
            targetDate: targetDate,
            protocolName: protocolName
        )
    }

    static func relocalizeActiveActivities(to language: AppLanguage) async {
        for activity in Activity<RecvelFastingAttributes>.activities {
            let current = activity.content.state
            let content = ActivityContent(
                state: RecvelFastingAttributes.ContentState(
                    phaseID: current.phaseID,
                    statusID: current.statusID,
                    languageCode: language.rawValue
                ),
                staleDate: activity.content.staleDate
            )
            await activity.update(content)
        }
    }

    private static func endActivities(except sessionID: UUID) async {
        for activity in Activity<RecvelFastingAttributes>.activities where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
