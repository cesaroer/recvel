import SwiftUI

struct ContentView: View {
    @State private var selection: AppTab = .today
    @State private var tabBarVisibility = TabBarVisibility()
    /// Keep visited tabs mounted so switching back is instant (no full remount / HealthKit redo).
    @State private var mountedTabs: Set<AppTab> = [.today]

    /// Mismo tono que la parte alta de `AppBackground`.
    private static let chromeColor = Color(red: 0.05, green: 0.075, blue: 0.075)

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
            // Velo bajo la barra de estado: sin el, al hacer scroll el reloj y
            // la bateria quedaban pintados encima de titulos y tarjetas. Solo
            // en la raiz de cada pestaña: las pantallas empujadas traen su
            // propio fondo (y el asistente es claro).
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 14)
                    .background {
                        LinearGradient(
                            stops: [
                                .init(color: Self.chromeColor, location: 0),
                                .init(color: Self.chromeColor, location: 0.8),
                                .init(color: Self.chromeColor.opacity(0), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    }
                    .opacity(tabBarVisibility.isHiddenByDetail ? 0 : 1)
                    .allowsHitTesting(false)
            }

            RecvelTabBar(selection: $selection)
                .padding(.bottom, 26)
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
        .onOpenURL { open($0) }
        .onReceive(NotificationCenter.default.publisher(for: .recvelOpenDeepLink)) { notification in
            guard let url = notification.object as? URL else { return }
            open(url)
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

    /// Enrutado de `recvel://` (widgets, Live Activity y notificaciones locales).
    private func open(_ url: URL) {
        guard url.scheme == "recvel" else { return }
        switch url.host {
        case "fitness": selection = .fitness
        case "nutrition": selection = .nutrition
        case "fasting": selection = .fasting
        case "journal": selection = .journal
        case "morning":
            selection = .today
            // Home observa la bandera y presenta el reporte de la mañana.
            tabBarVisibility.wantsMorningReport = true
        default: selection = .today
        }
        mountedTabs.insert(selection)
    }

    @ViewBuilder
    private func tabPage<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            content()
                // Las pestañas visitadas siguen montadas con opacidad 0, y eso
                // NO pausa nada: sin este flag, las animaciones continuas y los
                // timers de las cinco pestañas corrian a la vez.
                .environment(\.isTabActive, selection == tab)
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
        .environmentObject(HealthDataProvider())
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
                BioAgeReportRecord.self,
                ExerciseSetLog.self,
                TrainingReadinessCheckIn.self
            ],
            inMemory: true
        )
}
