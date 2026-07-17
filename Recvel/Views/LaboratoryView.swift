import SwiftData
import SwiftUI

// MARK: - Feature flags de datos mock por feature

enum MockFeature: String, CaseIterable, Identifiable {
    case recovery, strain, sleep, energy
    case activation
    case plan
    case journal
    case nutrition
    case trends
    case workouts
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery: "Recovery"
        case .strain: "Strain"
        case .sleep: "Sueno"
        case .energy: "Energia"
        case .activation: "Activacion fisiologica"
        case .plan: "Plan adaptativo"
        case .journal: "Journal"
        case .nutrition: "Nutricion"
        case .trends: "Tendencias"
        case .workouts: "Workouts"
        case .notifications: "Notificaciones"
        }
    }

    var icon: String {
        switch self {
        case .recovery: "heart.fill"
        case .strain: "flame.fill"
        case .sleep: "moon.stars.fill"
        case .energy: "bolt.fill"
        case .activation: "waveform"
        case .plan: "scope"
        case .journal: "checklist"
        case .nutrition: "fork.knife"
        case .trends: "chart.xyaxis.line"
        case .workouts: "figure.run"
        case .notifications: "bell.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .recovery: ScoreKind.recovery.color
        case .strain: ScoreKind.strain.color
        case .sleep: ScoreKind.sleep.color
        case .energy: ScoreKind.energy.color
        case .activation: .cyan
        case .plan: ScoreKind.recovery.color
        case .journal: .cyan
        case .nutrition: ScoreKind.energy.color
        case .trends: .purple
        case .workouts: ScoreKind.strain.color
        case .notifications: ScoreKind.energy.color
        }
    }

    var storageKey: String { "mock.\(rawValue)" }
}

enum MockFeatureFlags {
    static func isEnabled(_ feature: MockFeature) -> Bool {
        UserDefaults.standard.object(forKey: feature.storageKey) as? Bool ?? false
    }

    static func setEnabled(_ feature: MockFeature, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: feature.storageKey)
    }

    static func anyEnabled() -> Bool {
        MockFeature.allCases.contains { isEnabled($0) }
    }

    static func resetAll() {
        MockFeature.allCases.forEach { UserDefaults.standard.removeObject(forKey: $0.storageKey) }
    }
}

// MARK: - Vista de Laboratorio

struct LaboratoryView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("useDemoData") private var useDemoData = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @AppStorage("onboardingGoal") private var savedGoal = ""
    @AppStorage("onboardingPriorities") private var savedPriorities = ""
    @State private var flags: [MockFeature: Bool] = [:]
    @State private var showsResetConfirmation = false
    @State private var showsFreshInstallConfirmation = false
    @State private var resetInProgress = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    explanation
                    featureSwitchesCard
                    bulkActionsCard
                    profileDemoCard
                    freshInstallCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Laboratorio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { reloadFlags() }
        .confirmationDialog(
            "Reset as debug",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Borrar todo y reiniciar con perfil demo", role: .destructive) {
                performReset()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Borra comidas, journal y scores; activa datos mock para todos los features; rellena un perfil demo (Sara, 7:00, 8.0 h) y te lleva al onboarding.")
        }
        .confirmationDialog(
            "Eliminar datos y reiniciar",
            isPresented: $showsFreshInstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar todo y empezar de cero", role: .destructive) {
                performFreshInstall()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Borra todos los datos locales de Recvel (SwiftData, preferencias, agenda, mocks, API key y notificaciones) y vuelve al onboarding como una instalacion nueva. No revoca permisos de Apple Health.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LABORATORIO")
                .font(.caption2.weight(.heavy))
                .tracking(1.3)
                .foregroundStyle(ScoreKind.energy.color)
            Text("Datos mock por feature")
                .font(.system(size: 31, weight: .bold))
            Text("Enciende o apaga los datos demo para cada modulo. Util para previsualizar la app sin Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "flask.fill")
                .foregroundStyle(ScoreKind.energy.color)
            Text("Cada switch guarda su estado en este dispositivo. No afecta a Apple Health ni a tus datos reales.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }

    private var featureSwitchesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Features")
                    .font(.headline)
                Spacer()
                Button("Encender todos") {
                    MockFeature.allCases.forEach { MockFeatureFlags.setEnabled($0, true) }
                    reloadFlags()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScoreKind.recovery.color)
            }
            .padding(.bottom, 10)

            ForEach(MockFeature.allCases) { feature in
                toggleRow(for: feature)
                if feature != MockFeature.allCases.last {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
    }

    private func toggleRow(for feature: MockFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(feature.color)
                .frame(width: 30, height: 30)
                .background(feature.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            Text(feature.title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { flags[feature] ?? false },
                set: { newValue in
                    flags[feature] = newValue
                    MockFeatureFlags.setEnabled(feature, newValue)
                }
            ))
            .labelsHidden()
            .tint(feature.color)
        }
        .padding(.vertical, 10)
        .accessibilityLabel("\(feature.title) datos mock")
    }

    private var bulkActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Acciones rapids", systemImage: "bolt.fill")
                .font(.headline)

            Button {
                MockFeature.allCases.forEach { MockFeatureFlags.setEnabled($0, true) }
                reloadFlags()
            } label: {
                Label("Encender todos los mocks", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(ScoreKind.recovery.color)

            Button {
                MockFeature.allCases.forEach { MockFeatureFlags.setEnabled($0, false) }
                reloadFlags()
            } label: {
                Label("Apagar todos los mocks", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.7))
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
    }

    private var profileDemoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Reset as debug", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.headline)
                .foregroundStyle(ScoreKind.strain.color)

            Text("Borra comidas, journal y scores guardados; activa los mocks de todos los features; rellena un perfil demo (Sara, despertar 7:00, sueno 8.0 h) y te lleva al onboarding para verlo desde cero.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Group {
                    if resetInProgress {
                        ProgressView().tint(.white)
                    } else {
                        Label("Reset as debug", systemImage: "arrow.counterclockwise")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(ScoreKind.strain.color)
            .disabled(resetInProgress)

            Text("Esto no borra datos de Apple Health ni revoca sus permisos.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.strain.color)
    }

    private var freshInstallCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Instalacion limpia", systemImage: "trash.circle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text("Elimina todos los datos de Recvel en este dispositivo y reinicia la app como si acabaras de instalarla: sin perfil, sin mocks, sin comidas ni rutinas, de vuelta al onboarding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showsFreshInstallConfirmation = true
            } label: {
                Group {
                    if resetInProgress {
                        ProgressView().tint(.white)
                    } else {
                        Label("Eliminar datos y reiniciar", systemImage: "trash")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .disabled(resetInProgress)
            .accessibilityIdentifier("lab.freshInstall")

            Text("No puede revocar permisos de Apple Health (iOS los gestiona). Puedes hacerlo en Ajustes > Privacidad > Salud.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: .red)
    }

    private func reloadFlags() {
        flags = Dictionary(uniqueKeysWithValues: MockFeature.allCases.map { ($0, MockFeatureFlags.isEnabled($0)) })
    }

    private func performReset() {
        resetInProgress = true
        Haptics.warning()
        LocalStore.deleteAll(in: modelContext)
        MockFeature.allCases.forEach { MockFeatureFlags.setEnabled($0, true) }
        useDemoData = true
        userName = "Sara"
        wakeMinutes = 7 * 60
        sleepGoalHours = 8.0
        savedGoal = OnboardingDemoProfile.goal
        savedPriorities = OnboardingDemoProfile.priorities
        reloadFlags()
        hasCompletedOnboarding = false
        resetInProgress = false
    }

    private func performFreshInstall() {
        resetInProgress = true
        Haptics.warning()
        LocalStore.resetToFreshInstall(in: modelContext)

        // Sincroniza bindings @AppStorage en memoria tras wipe del dominio.
        useDemoData = false
        userName = ""
        wakeMinutes = 420
        sleepGoalHours = 8.0
        savedGoal = ""
        savedPriorities = ""
        reloadFlags()
        hasCompletedOnboarding = false
        resetInProgress = false
    }
}

enum OnboardingDemoProfile {
    static let goal = "balance"
    static let priorities = "recovery,sleep,training"
}

#Preview {
    NavigationStack {
        LaboratoryView()
    }
    .modelContainer(
        for: [MealLog.self, HabitLog.self, DailyScoreRecord.self, NutritionProfile.self, FitnessActivityLog.self, WorkoutTemplate.self, EmotionLog.self, FastingFeelingLog.self, MentalJournalEntry.self, SleepRoutineStep.self, PlannedSleepNight.self, JournalTagConfiguration.self, BiomarkerSample.self, BioAgeReportRecord.self],
        inMemory: true
    )
}
