import Foundation
import SwiftData

enum LocalStore {
    @MainActor
    static func save(
        _ estimate: NutritionEstimate,
        mealType: MealType? = nil,
        notes: String? = nil,
        in context: ModelContext
    ) {
        context.insert(
            MealLog(
                title: estimate.title,
                calories: estimate.calories,
                protein: estimate.protein,
                carbohydrates: estimate.carbohydrates,
                fat: estimate.fat,
                source: estimate.source,
                mealType: mealType?.rawValue,
                confidence: estimate.confidence.rawValue,
                kcalLower: estimate.kcalLower,
                kcalUpper: estimate.kcalUpper,
                notes: notes
            )
        )
        try? context.save()
    }

    @MainActor
    static func saveDailyScores(_ scores: [WellnessScore], in context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? .now
        let descriptor = FetchDescriptor<DailyScoreRecord>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        let recovery = scores.first { $0.kind == .recovery }?.value ?? 0
        let sleep = scores.first { $0.kind == .sleep }?.value ?? 0
        let strain = scores.first { $0.kind == .strain }?.value ?? 0

        if let existing = try? context.fetch(descriptor).first {
            existing.recovery = recovery
            existing.sleep = sleep
            existing.strain = strain
        } else {
            context.insert(DailyScoreRecord(recovery: recovery, sleep: sleep, strain: strain))
        }
        try? context.save()
    }

    @MainActor
    static func deleteAll(in context: ModelContext) {
        if let meals = try? context.fetch(FetchDescriptor<MealLog>()) {
            meals.forEach(context.delete)
        }
        if let habits = try? context.fetch(FetchDescriptor<HabitLog>()) {
            habits.forEach(context.delete)
        }
        if let scores = try? context.fetch(FetchDescriptor<DailyScoreRecord>()) {
            scores.forEach(context.delete)
        }
        if let profiles = try? context.fetch(FetchDescriptor<NutritionProfile>()) {
            profiles.forEach(context.delete)
        }
        if let fitnessActivities = try? context.fetch(FetchDescriptor<FitnessActivityLog>()) {
            fitnessActivities.forEach(context.delete)
        }
        if let workoutTemplates = try? context.fetch(FetchDescriptor<WorkoutTemplate>()) {
            workoutTemplates.forEach(context.delete)
        }
        if let fastingSessions = try? context.fetch(FetchDescriptor<FastingSession>()) {
            fastingSessions.forEach(context.delete)
        }
        if let emotionLogs = try? context.fetch(FetchDescriptor<EmotionLog>()) {
            emotionLogs.forEach(context.delete)
        }
        if let feelingLogs = try? context.fetch(FetchDescriptor<FastingFeelingLog>()) {
            feelingLogs.forEach(context.delete)
        }
        if let mentalEntries = try? context.fetch(FetchDescriptor<MentalJournalEntry>()) {
            mentalEntries.forEach(context.delete)
        }
        if let sleepRoutine = try? context.fetch(FetchDescriptor<SleepRoutineStep>()) {
            sleepRoutine.forEach(context.delete)
        }
        if let sleepPlans = try? context.fetch(FetchDescriptor<PlannedSleepNight>()) {
            sleepPlans.forEach(context.delete)
        }
        if let journalTags = try? context.fetch(FetchDescriptor<JournalTagConfiguration>()) {
            journalTags.forEach(context.delete)
        }
        if let biomarkers = try? context.fetch(FetchDescriptor<BiomarkerSample>()) {
            biomarkers.forEach(context.delete)
        }
        if let bioReports = try? context.fetch(FetchDescriptor<BioAgeReportRecord>()) {
            bioReports.forEach(context.delete)
        }
        try? context.save()
    }

    /// Instalacion limpia local: SwiftData + UserDefaults de la app + Keychain
    /// de Recvel + notificaciones pendientes. No puede revocar HealthKit (iOS).
    @MainActor
    static func resetToFreshInstall(in context: ModelContext) {
        deleteAll(in: context)
        WeeklyRoutineStore.clear()
        MockFeatureFlags.resetAll()
        KeychainStore.remove("nutrition.gemini.apiKey")
        LocalNotificationManager().cancelAll()

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()

        // Asegura que AppRootView muestre onboarding (dominio ya limpio).
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "useDemoData")
    }
}
