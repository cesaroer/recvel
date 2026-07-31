import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var language: LanguageController
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
            WidthLockedScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("settings.title")
                        .font(.system(size: 28, weight: .bold))

                    profileCard

                    languageCard

                    nutritionSettingsCard

                    VStack(alignment: .leading, spacing: 14) {
                        Label("common.appleHealth", systemImage: "heart.text.square.fill").font(.headline)
                        Text("settings.health.detail")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { await health.requestAuthorization() } } label: {
                            Label("settings.health.permissions", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ScoreKind.recovery.color)
                        Text(health.authorizationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(17)
                    .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("settings.privacy.title", systemImage: "lock.shield.fill").font(.headline)
                        Text("settings.privacy.detail")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(17)
                    .liquidGlass(cornerRadius: 8)

                    notificationCard

                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("settings.onboarding.replay", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.7))

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("settings.delete.local", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Text("settings.wellness.disclaimer")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(16)
            }
        }
        .confirmationDialog(
            "settings.delete.confirm.title",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.delete.local", role: .destructive) {
                LocalStore.deleteAll(in: modelContext)
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.delete.confirm.detail")
        }
        .onAppear {
            nutritionAPIKey = KeychainStore.get("nutrition.gemini.apiKey") ?? ""
        }
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("language.section.title", systemImage: "globe")
                .font(.headline)

            Menu {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        Haptics.selection()
                        language.select(option)
                    } label: {
                        if language.selection == option {
                            Label(languageName(option), systemImage: "checkmark")
                        } else {
                            Text(languageName(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "character.bubble.fill")
                        .foregroundStyle(ScoreKind.sleep.color)
                        .frame(width: 32, height: 32)
                        .background(ScoreKind.sleep.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("language.selector.title")
                            .font(.subheadline.weight(.semibold))
                        Text(languageName(language.selection))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.language.menu")

            Text("language.selector.detail")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
    }

    private func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: RecvelL10n.text("language.system", language: self.language.resolvedLanguage)
        case .esMX: RecvelL10n.text("language.esMX", language: self.language.resolvedLanguage)
        case .english: RecvelL10n.text("language.english", language: self.language.resolvedLanguage)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("settings.profile.title", systemImage: "person.crop.circle")
                .font(.headline)
            TextField("settings.profile.name", text: $userName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))

            DatePicker(
                "settings.profile.wake",
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
                    Text("settings.profile.sleepGoal")
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
                        Text("settings.lab.title")
                            .font(.subheadline.weight(.medium))
                        Text("settings.lab.detail")
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
            Label("settings.notifications.title", systemImage: "bell.badge.fill")
                .font(.headline)
            Toggle("settings.notifications.morning", isOn: Binding(
                get: { morningBriefingEnabled },
                set: { updateMorning($0) }
            ))
            Toggle("settings.notifications.bedtime", isOn: Binding(
                get: { bedtimeReminderEnabled },
                set: { updateBedtime($0) }
            ))
            if !notificationMessage.isEmpty {
                Text(notificationMessage).font(.caption).foregroundStyle(.secondary)
            }
            Text("settings.notifications.detail")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
    }

    private var nutritionSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("settings.nutrition.title", systemImage: "fork.knife.circle.fill")
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
                            Text("settings.nutrition.profile.edit").font(.subheadline.weight(.semibold))
                            Text(nutritionProfileSummary(profile))
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
                    Label("settings.nutrition.profile.setup", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $nutritionExperimentalAPIEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.nutrition.external.title").font(.subheadline.weight(.semibold))
                    Text("settings.nutrition.external.detail").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .tint(.cyan)
            .accessibilityIdentifier("settings.nutrition.experimentalAPI")

            if nutritionExperimentalAPIEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Group {
                            if revealNutritionAPIKey {
                                TextField("settings.nutrition.api.placeholder", text: $nutritionAPIKey)
                            } else {
                                SecureField("settings.nutrition.api.placeholder", text: $nutritionAPIKey)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button { revealNutritionAPIKey.toggle() } label: {
                            Image(systemName: revealNutritionAPIKey ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(RecvelL10n.text(revealNutritionAPIKey ? "settings.nutrition.api.hide" : "settings.nutrition.api.show"))
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))

                    HStack {
                        Button("settings.nutrition.api.save") {
                            let key = nutritionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if key.isEmpty {
                                KeychainStore.remove("nutrition.gemini.apiKey")
                                nutritionAPIMessage = RecvelL10n.text("settings.nutrition.api.removed")
                            } else {
                                KeychainStore.set(key, forKey: "nutrition.gemini.apiKey")
                                nutritionAPIMessage = RecvelL10n.text("settings.nutrition.api.saved")
                            }
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        if !nutritionAPIMessage.isEmpty {
                            Text(nutritionAPIMessage).font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    Label(
                        "settings.nutrition.external.warning",
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

    private func nutritionProfileSummary(_ profile: NutritionProfile) -> String {
        let goal = NutritionGoal(rawValue: profile.goal)?.displayName ?? profile.goal
        return RecvelL10n.text(
            "settings.nutrition.profile.summary",
            values: ["goal": goal, "count": profile.weeklyWorkouts]
        )
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
            notificationMessage = RecvelL10n.text(allowed ? "notification.updated" : "notification.permission")
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
            notificationMessage = RecvelL10n.text(allowed ? "notification.updated" : "notification.permission")
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
