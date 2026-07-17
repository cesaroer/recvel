import SwiftData
import SwiftUI

@main
struct RecvelApp: App {
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
                BioAgeReportRecord.self
            )
        } catch {
            fatalError("Unable to create local store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
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
