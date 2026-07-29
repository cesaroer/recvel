import SwiftData
import SwiftUI

@main
struct RecvelApp: App {
    @StateObject private var language = LanguageController()

    init() {
        _ = WatchSyncManager.shared
        // Sin delegate, tocar una notificacion abre la app pero no navega.
        NotificationRouter.shared.register()
    }

    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: MealLog.self,
                HabitLog.self,
                DailyScoreRecord.self,
                NutritionProfile.self,
                FastingSession.self,
                FitnessActivityLog.self,
                WorkoutTemplate.self,
                EmotionLog.self,
                FastingFeelingLog.self,
                MentalJournalEntry.self,
                SleepRoutineStep.self,
                PlannedSleepNight.self,
                JournalTagConfiguration.self,
                BiomarkerSample.self,
                BioAgeReportRecord.self,
                ExerciseSetLog.self,
                TrainingReadinessCheckIn.self
            )
        } catch {
            fatalError("Unable to create local store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
                .environmentObject(language)
                .environment(\.locale, language.locale)
                .onReceive(NotificationCenter.default.publisher(for: .recvelLanguageDidChange)) { _ in
                    Task { await LocalNotificationManager().relocalizePendingNotifications() }
                }
        }
        .modelContainer(modelContainer)
    }
}

private struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: hasCompletedOnboarding)
    }
}
