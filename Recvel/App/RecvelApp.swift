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

    /// Los UITests corren contra la app real, asi que sin esto escriben en el
    /// MISMO store de SwiftData que usa el usuario: cada pasada dejaba
    /// plantillas, logs y sesiones que despues aparecian en la app de verdad
    /// (el usuario se encontro 24 plantillas que nunca creo). Con el flag el
    /// store es efimero y muere con el proceso, asi que los tests no necesitan
    /// limpiar nada al terminar: no llegan a escribir en disco.
    private static var usesEphemeralStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestEphemeralStore")
    }

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                MealLog.self,
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
                TrainingReadinessCheckIn.self,
                GeneratedPlanRecord.self
            ])
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: RecvelApp.usesEphemeralStore
                )
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
