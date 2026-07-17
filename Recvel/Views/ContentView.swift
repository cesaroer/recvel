import SwiftUI

struct ContentView: View {
    @State private var selection: AppTab = .today
    @State private var tabBarVisibility = TabBarVisibility()
    /// Keep visited tabs mounted so switching back is instant (no full remount / HealthKit redo).
    @State private var mountedTabs: Set<AppTab> = [.today]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            ZStack {
                tabPage(.today) { DashboardView() }
                tabPage(.journal) { JournalView() }
                tabPage(.fitness) { FitnessView() }
                tabPage(.nutrition) { NutritionView() }
                tabPage(.fasting) { FastingView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Never animate root page swaps — that was the tap lag.
            .transaction { $0.animation = nil }

            LiquidGlassTabBar(selection: $selection)
                .padding(.bottom, 10)
                .ignoresSafeArea(edges: .bottom)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 4)
        }
        .onChange(of: selection) { _, newTab in
            mountedTabs.insert(newTab)
            tabBarVisibility.selectedTab = newTab
            tabBarVisibility.noteTabChange()
        }
        .onAppear {
            tabBarVisibility.selectedTab = selection
        }
        .onChange(of: tabBarVisibility.wantsFitnessTab) { _, wants in
            guard wants else { return }
            mountedTabs.insert(.fitness)
            selection = .fitness
            tabBarVisibility.wantsFitnessTab = false
        }
        .environment(\.recvelVisualStyle, .product)
        .environment(tabBarVisibility)
        .tint(ScoreKind.recovery.color)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func tabPage<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            content()
                .opacity(selection == tab ? 1 : 0)
                .allowsHitTesting(selection == tab)
                .accessibilityHidden(selection != tab)
                // Keep the active tab on top for hit-testing / VoiceOver.
                .zIndex(selection == tab ? 1 : 0)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
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
                BioAgeReportRecord.self
            ],
            inMemory: true
        )
}
