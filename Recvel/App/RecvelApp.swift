import SwiftData
import SwiftUI

@main
struct RecvelApp: App {
    @StateObject private var language = LanguageController()
    /// Un solo proveedor de salud para toda la app. Antes cada pantalla creaba
    /// el suyo (10 instancias): cada una releia sus 30 dias de Apple Health y
    /// guardaba su propia copia en memoria.
    @StateObject private var health = HealthDataProvider()

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

    /// Antes esto era un `fatalError`: si SwiftData no podia abrir o migrar el
    /// store, la app crasheaba al arrancar PARA SIEMPRE (cada lanzamiento
    /// repetia el mismo fallo) y el usuario no tenia salida. Ahora el fallo se
    /// muestra en `StoreRecoveryView`, con reintento y la opcion de apartar el
    /// store dañado sin borrarlo.
    @State private var storeState = RecvelApp.openStore()

    private enum StoreState {
        case ready(ModelContainer)
        case failed(String)
    }

    private static var schema: Schema {
        Schema([
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
    }

    private static var storeConfiguration: ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesEphemeralStore)
    }

    private static func openStore() -> StoreState {
        do {
            let container = try ModelContainer(for: schema, configurations: storeConfiguration)
            // La generacion real necesita red y la API key del usuario, asi
            // que el UI test de "Planes guardados" no puede fabricar un plan:
            // se siembra uno ya guardado en el store efimero.
            if usesEphemeralStore,
               ProcessInfo.processInfo.arguments.contains("-uiTestSeedSavedNutritionPlan") {
                MainActor.assumeIsolated {
                    container.mainContext.insert(GeneratedPlanRecord.uiTestSeed())
                    try? container.mainContext.save()
                }
            }
            return .ready(container)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// Aparta el store que no abre (lo renombra junto con sus -wal/-shm) y
    /// crea uno nuevo. No borra nada: los archivos quedan en el contenedor de
    /// la app con sufijo `.damaged-<fecha>` por si se pueden rescatar despues.
    private static func setAsideDamagedStore() {
        let url = storeConfiguration.url
        let stamp = Int(Date.now.timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let target = URL(fileURLWithPath: url.path + ".damaged-\(stamp)" + suffix)
            try? FileManager.default.moveItem(at: source, to: target)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch storeState {
                case .ready(let container):
                    AppRootView()
                        .modelContainer(container)
                case .failed(let detail):
                    StoreRecoveryView(
                        detail: detail,
                        onRetry: { storeState = RecvelApp.openStore() },
                        onStartClean: {
                            RecvelApp.setAsideDamagedStore()
                            storeState = RecvelApp.openStore()
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(language)
            .environmentObject(health)
            .environment(\.locale, language.locale)
            .onReceive(NotificationCenter.default.publisher(for: .recvelLanguageDidChange)) { _ in
                Task { await LocalNotificationManager().relocalizePendingNotifications() }
            }
        }
    }
}

/// Pantalla de ultimo recurso cuando el store local no abre.
private struct StoreRecoveryView: View {
    let detail: String
    let onRetry: () -> Void
    let onStartClean: () -> Void
    @State private var confirmsClean = false

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.059, blue: 0.071).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                Text(RecvelL10n.text("store.recovery.title"))
                    .font(.title2.weight(.bold))
                Text(RecvelL10n.text("store.recovery.detail"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(4)

                Button(action: onRetry) {
                    Text(RecvelL10n.text("store.recovery.retry"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("store.recovery.retry")

                Button(role: .destructive) { confirmsClean = true } label: {
                    Text(RecvelL10n.text("store.recovery.startClean"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("store.recovery.startClean")
            }
            .padding(24)
        }
        .confirmationDialog(
            RecvelL10n.text("store.recovery.confirmTitle"),
            isPresented: $confirmsClean,
            titleVisibility: .visible
        ) {
            Button(RecvelL10n.text("store.recovery.startClean"), role: .destructive, action: onStartClean)
            Button(RecvelL10n.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(RecvelL10n.text("store.recovery.confirmDetail"))
        }
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
