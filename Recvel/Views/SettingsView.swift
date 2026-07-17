import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var nutritionProfiles: [NutritionProfile]
    @StateObject private var health = HealthDataProvider()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("userName") private var userName = ""
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @AppStorage("morningBriefingEnabled") private var morningBriefingEnabled = false
    @AppStorage("bedtimeReminderEnabled") private var bedtimeReminderEnabled = false
    @AppStorage(NutritionFeatureFlags.experimentalAPIKey) private var nutritionExperimentalAPIEnabled = NutritionFeatureFlags.experimentalAPIEnabledByDefault
    @State private var notificationMessage = ""
    @State private var nutritionAPIKey = ""
    @State private var nutritionAPIMessage = ""
    @State private var revealNutritionAPIKey = false
    @State private var showsDeleteConfirmation = false

    private let notifications = LocalNotificationManager()

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Datos y privacidad")
                        .font(.system(size: 28, weight: .bold))

                    profileCard

                    nutritionSettingsCard

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Apple Health", systemImage: "heart.text.square.fill").font(.headline)
                        Text("Recvel lee las categorias que autorizas y procesa scores, journal y nutricion en este dispositivo.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { await health.requestAuthorization() } } label: {
                            Label("Conectar o actualizar permisos", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ScoreKind.recovery.color)
                        Text(health.authorizationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(17)
                    .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Local por diseno", systemImage: "lock.shield.fill").font(.headline)
                        Text("Sin cuenta, backend ni analytics externos. Puedes revocar HealthKit desde Ajustes de iOS.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(17)
                    .liquidGlass(cornerRadius: 8)

                    notificationCard

                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Ver onboarding de nuevo", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.7))

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("Borrar datos locales", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Text("Recvel es una herramienta de bienestar, no un dispositivo medico ni un sustituto de atencion profesional.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(16)
            }
        }
        .confirmationDialog(
            "Borrar comidas, journal y scores guardados?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Borrar datos locales", role: .destructive) {
                LocalStore.deleteAll(in: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esto no borra datos de Apple Health ni cambia sus permisos.")
        }
        .onAppear {
            nutritionAPIKey = KeychainStore.get("nutrition.gemini.apiKey") ?? ""
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Perfil y horario", systemImage: "person.crop.circle")
                .font(.headline)
            TextField("Nombre opcional", text: $userName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))

            DatePicker(
                "Hora de despertar",
                selection: Binding(
                    get: { wakeDate },
                    set: {
                        wakeMinutes = Calendar.current.component(.hour, from: $0) * 60
                            + Calendar.current.component(.minute, from: $0)
                        rescheduleNotifications()
                    }
                ),
                displayedComponents: .hourAndMinute
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Objetivo de sueno")
                    Spacer()
                    Text(String(format: "%.1f h", sleepGoalHours)).fontWeight(.bold).monospacedDigit()
                }
                Slider(value: $sleepGoalHours, in: 6.5...9.5, step: 0.25) { editing in
                    if !editing { rescheduleNotifications() }
                }
                .tint(ScoreKind.sleep.color)
            }

            NavigationLink {
                LaboratoryView()
                    .hidesTabBar()
            } label: {
                HStack {
                    Image(systemName: "flask.fill")
                        .foregroundStyle(ScoreKind.energy.color)
                        .frame(width: 30, height: 30)
                        .background(ScoreKind.energy.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Laboratorio")
                            .font(.subheadline.weight(.medium))
                        Text("Datos mock por feature y reset")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Recordatorios locales", systemImage: "bell.badge.fill")
                .font(.headline)
            Toggle("Briefing matutino", isOn: Binding(
                get: { morningBriefingEnabled },
                set: { updateMorning($0) }
            ))
            Toggle("Prepararme para dormir", isOn: Binding(
                get: { bedtimeReminderEnabled },
                set: { updateBedtime($0) }
            ))
            if !notificationMessage.isEmpty {
                Text(notificationMessage).font(.caption).foregroundStyle(.secondary)
            }
            Text("Se programan en este dispositivo y no requieren servidor ni cuenta.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
    }

    private var nutritionSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Nutricion y estimacion", systemImage: "fork.knife.circle.fill")
                .font(.headline)

            if let profile = nutritionProfiles.first {
                NavigationLink {
                    NutritionSetupView(profile: profile)
                        .hidesTabBar()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle.fill")
                            .foregroundStyle(ScoreKind.recovery.color)
                            .frame(width: 32, height: 32)
                            .background(ScoreKind.recovery.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Editar perfil nutricional").font(.subheadline.weight(.semibold))
                            Text("\(profile.goal) · \(profile.weeklyWorkouts) entrenamientos")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    NutritionSetupView()
                        .hidesTabBar()
                } label: {
                    Label("Configurar perfil nutricional", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $nutritionExperimentalAPIEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IA externa experimental").font(.subheadline.weight(.semibold))
                    Text("Gemini free tier para uso personal").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .tint(.cyan)
            .accessibilityIdentifier("settings.nutrition.experimentalAPI")

            if nutritionExperimentalAPIEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Group {
                            if revealNutritionAPIKey {
                                TextField("API key de Gemini", text: $nutritionAPIKey)
                            } else {
                                SecureField("API key de Gemini", text: $nutritionAPIKey)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button { revealNutritionAPIKey.toggle() } label: {
                            Image(systemName: revealNutritionAPIKey ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(revealNutritionAPIKey ? "Ocultar API key" : "Mostrar API key")
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))

                    HStack {
                        Button("Guardar en Keychain") {
                            let key = nutritionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if key.isEmpty {
                                KeychainStore.remove("nutrition.gemini.apiKey")
                                nutritionAPIMessage = "Clave eliminada"
                            } else {
                                KeychainStore.set(key, forKey: "nutrition.gemini.apiKey")
                                nutritionAPIMessage = "Clave guardada solo en este dispositivo"
                            }
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        if !nutritionAPIMessage.isEmpty {
                            Text(nutritionAPIMessage).font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    Label(
                        "Cada envio requiere confirmacion. Texto y foto salen del dispositivo; las comidas guardadas siguen siendo locales.",
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .animation(.snappy, value: nutritionExperimentalAPIEnabled)
    }

    private var wakeDate: Date {
        Calendar.current.date(byAdding: .minute, value: wakeMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func updateMorning(_ enabled: Bool) {
        Task {
            let allowed: Bool
            if enabled {
                allowed = await notifications.requestAuthorization()
            } else {
                allowed = true
            }
            morningBriefingEnabled = enabled && allowed
            await notifications.scheduleMorning(enabled: morningBriefingEnabled, wakeMinutes: wakeMinutes)
            notificationMessage = allowed ? "Horarios actualizados" : "Activa notificaciones desde Ajustes de iOS"
        }
    }

    private func updateBedtime(_ enabled: Bool) {
        Task {
            let allowed: Bool
            if enabled {
                allowed = await notifications.requestAuthorization()
            } else {
                allowed = true
            }
            bedtimeReminderEnabled = enabled && allowed
            await notifications.scheduleBedtime(
                enabled: bedtimeReminderEnabled,
                wakeMinutes: wakeMinutes,
                sleepGoalHours: sleepGoalHours
            )
            notificationMessage = allowed ? "Horarios actualizados" : "Activa notificaciones desde Ajustes de iOS"
        }
    }

    private func rescheduleNotifications() {
        Task {
            await notifications.scheduleMorning(enabled: morningBriefingEnabled, wakeMinutes: wakeMinutes)
            await notifications.scheduleBedtime(
                enabled: bedtimeReminderEnabled,
                wakeMinutes: wakeMinutes,
                sleepGoalHours: sleepGoalHours
            )
        }
    }
}
