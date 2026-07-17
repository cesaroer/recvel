import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingGoal") private var savedGoal = ""
    @AppStorage("onboardingPriorities") private var savedPriorities = ""
    @AppStorage("wakeMinutes") private var wakeMinutes = 420
    @AppStorage("sleepGoalHours") private var sleepGoalHours = 8.0
    @AppStorage("userName") private var savedName = ""

    @StateObject private var health = HealthDataProvider()
    @State private var step = 0
    @State private var goal = ""
    @State private var priorities: Set<String> = []
    @State private var name = ""
    @State private var contentVisible = false
    @FocusState private var nameFocused: Bool

    private let stepCount = 5

    var body: some View {
        ZStack {
            OnboardingBackground(step: step)

            VStack(spacing: 0) {
                topBar

                ZStack {
                    stepContent
                        .id(step)
                        .transition(
                            reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomAction
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            goal = savedGoal
            priorities = Set(savedPriorities.split(separator: ",").map(String.init))
            name = savedName
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) {
                contentVisible = true
            }
        }
        .accessibilityIdentifier("onboarding.root")
    }

    private var topBar: some View {
        HStack {
            if step > 0 {
                Button {
                    Haptics.soft()
                    nameFocused = false
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .headerCircleChrome(size: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Anterior")
            } else {
                Text("RECVEL")
                    .font(.caption.weight(.black))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? onboardingAccent : Color.white.opacity(0.14))
                        .frame(width: index == step ? 25 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: step)
            .accessibilityLabel("Paso \(step + 1) de \(stepCount)")
        }
        .frame(height: 50)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: goalStep
        case 2: prioritiesStep
        case 3: scheduleStep
        default: healthStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)
            OnboardingSignalOrb(reduceMotion: reduceMotion)
                .frame(height: 315)
                .padding(.horizontal, -4)

            Spacer(minLength: 16)

            Text("Entiende tu cuerpo.\nDecide mejor cada dia.")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboarding.welcomeTitle")

            Text("Recvel transforma tus senales de Apple Watch en recuperacion, carga y sueno que puedes usar hoy.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.top, 13)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 18)
        }
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 14)
    }

    private var goalStep: some View {
        OnboardingPageHeader(
            eyebrow: "TU NORTE",
            title: "¿Que quieres mejorar primero?",
            detail: "Esto define el tono de tus objetivos diarios. Puedes cambiarlo despues."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingGoal.allCases) { item in
                    SelectableGlassRow(
                        icon: item.icon,
                        title: item.title,
                        detail: item.detail,
                        color: item.color,
                        selected: goal == item.rawValue
                    ) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { goal = item.rawValue }
                    }
                }
            }
        }
    }

    private var prioritiesStep: some View {
        OnboardingPageHeader(
            eyebrow: "PERSONALIZACION",
            title: "¿Que senales importan para ti?",
            detail: "Elige hasta tres. Recvel las priorizara en tu briefing."
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(OnboardingPriority.allCases) { item in
                    Button {
                        Haptics.selection()
                        togglePriority(item.rawValue)
                    } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(item.color)
                                Spacer()
                                Image(systemName: priorities.contains(item.rawValue) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(priorities.contains(item.rawValue) ? item.color : Color.white.opacity(0.24))
                            }
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .padding(15)
                        .platformGlass(tint: priorities.contains(item.rawValue) ? item.color : nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(priorities.contains(item.rawValue) ? .isSelected : [])
                }
            }
        }
    }

    private var scheduleStep: some View {
        OnboardingPageHeader(
            eyebrow: "TU RITMO",
            title: "Construyamos tu noche",
            detail: "Usaremos tu hora de despertar para calcular una ventana de sueno realista."
        ) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("¿Como te llamamos?")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField("Nombre opcional", text: $name)
                        .focused($nameFocused)
                        .font(.title3.weight(.semibold))
                        .snappyTextInput()
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(17)
                .platformGlass()

                HStack(spacing: 10) {
                    scheduleValue(
                        title: "Despertar",
                        value: wakeDate.formatted(date: .omitted, time: .shortened),
                        icon: "sun.max.fill",
                        color: ScoreKind.energy.color
                    )
                    scheduleValue(
                        title: "Objetivo",
                        value: String(format: "%.1f h", sleepGoalHours),
                        icon: "moon.stars.fill",
                        color: ScoreKind.sleep.color
                    )
                }

                VStack(spacing: 15) {
                    DatePicker(
                        "Hora de despertar",
                        selection: Binding(
                            get: { wakeDate },
                            set: { wakeMinutes = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .tint(ScoreKind.energy.color)

                    Divider().overlay(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Horas de sueno")
                            Spacer()
                            Text(String(format: "%.1f", sleepGoalHours)).fontWeight(.bold).monospacedDigit()
                        }
                        Slider(value: $sleepGoalHours, in: 6.5...9.5, step: 0.25)
                            .tint(ScoreKind.sleep.color)
                    }
                }
                .font(.subheadline.weight(.medium))
                .padding(17)
                .platformGlass(tint: ScoreKind.sleep.color)
            }
        }
    }

    private func scheduleValue(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .platformGlass(tint: color)
    }

    private var healthStep: some View {
        OnboardingPageHeader(
            eyebrow: "TU INFORMACION, TUYA",
            title: "Conecta Apple Health",
            detail: "Recvel procesa tus senales en este dispositivo. Sin cuenta, backend ni venta de datos."
        ) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    healthDataRow(icon: "waveform.path.ecg", title: "Recuperacion", detail: "HRV, FC en reposo y respiracion", color: ScoreKind.recovery.color)
                    Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 46)
                    healthDataRow(icon: "moon.stars.fill", title: "Sueno", detail: "Duracion y fases disponibles", color: ScoreKind.sleep.color)
                    Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 46)
                    healthDataRow(icon: "figure.run", title: "Carga", detail: "Workouts, energia, pasos y FC", color: ScoreKind.strain.color)
                }
                .padding(16)
                .platformGlass()

                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(ScoreKind.recovery.color)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Procesamiento local").font(.subheadline.weight(.bold))
                        Text("Puedes revocar permisos cuando quieras.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .platformGlass(tint: ScoreKind.recovery.color)

                Button {
                    Haptics.medium()
                    Task { await health.requestAuthorization() }
                } label: {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                        Text(health.isRequestingAuthorization ? "Solicitando acceso" : "Conectar Apple Health")
                        Spacer()
                        if health.dataMode != .demo { Image(systemName: "checkmark.circle.fill") }
                    }
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .platformGlass(tint: ScoreKind.recovery.color, interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(health.isRequestingAuthorization)
                .accessibilityIdentifier("onboarding.connectHealth")

                Text(health.authorizationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func healthDataRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var bottomAction: some View {
        VStack(spacing: 9) {
            Button {
                advance()
            } label: {
                HStack {
                    Text(step == stepCount - 1 ? "Entrar a Recvel" : (step == 0 ? "Comenzar" : "Continuar"))
                    Spacer()
                    Image(systemName: step == stepCount - 1 ? "checkmark" : "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(onboardingAccent, in: Capsule())
                .shadow(color: onboardingAccent.opacity(0.34), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .accessibilityIdentifier("onboarding.primaryAction")

            if step == stepCount - 1 {
                Text("Puedes conectar Apple Health mas tarde desde Ajustes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 1: !goal.isEmpty
        case 2: !priorities.isEmpty
        default: true
        }
    }

    private var onboardingAccent: Color {
        switch step {
        case 1: ScoreKind.strain.color
        case 2: .cyan
        case 3: ScoreKind.sleep.color
        default: ScoreKind.recovery.color
        }
    }

    private var wakeDate: Date {
        Calendar.current.date(byAdding: .minute, value: wakeMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private func togglePriority(_ value: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            if priorities.contains(value) {
                priorities.remove(value)
            } else if priorities.count < 3 {
                priorities.insert(value)
            }
        }
    }

    private func advance() {
        nameFocused = false
        if step < stepCount - 1 {
            Haptics.medium()
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) { step += 1 }
        } else {
            Haptics.success()
            savedGoal = goal
            savedPriorities = priorities.sorted().joined(separator: ",")
            savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingPageHeader<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let content: Content

    init(eyebrow: String, title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 22)
                Text(eyebrow)
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
                content.padding(.top, 24)
                Spacer().frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct SelectableGlassRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? color : Color.white.opacity(0.24))
            }
            .padding(15)
            .platformGlass(tint: selected ? color : nil, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct OnboardingBackground: View {
    let step: Int

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.018, blue: 0.025)
            LinearGradient(
                colors: [accent.opacity(0.26), .clear, accent2.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.18))
                .mask(
                    LinearGradient(colors: [.clear, .black, .clear], startPoint: .top, endPoint: .bottom)
                )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: step)
    }

    private var accent: Color {
        [ScoreKind.recovery.color, ScoreKind.strain.color, .cyan, ScoreKind.sleep.color, ScoreKind.recovery.color][step]
    }
    private var accent2: Color {
        [Color.purple, ScoreKind.energy.color, ScoreKind.recovery.color, .cyan, Color.blue][step]
    }
}

private struct OnboardingSignalOrb: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in 0..<5 {
                    let offset = sin(phase * (0.42 + Double(index) * 0.05) + Double(index)) * 9
                    let diameter = min(size.width, size.height) * (0.38 + Double(index) * 0.105)
                    let rect = CGRect(
                        x: center.x - diameter / 2 + offset,
                        y: center.y - diameter / 2 - offset * 0.45,
                        width: diameter,
                        height: diameter
                    )
                    let color: Color = index.isMultiple(of: 2) ? ScoreKind.recovery.color : Color.purple
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(0.42 - Double(index) * 0.05)),
                        lineWidth: 2.2
                    )
                }
            }
            .overlay {
                VStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ScoreKind.recovery.color)
                    Text("READY")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 106, height: 106)
                .platformGlass(shape: .circle)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum OnboardingGoal: String, CaseIterable, Identifiable {
    case perform, recover, sleep, balance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .perform: "Rendir mejor"
        case .recover: "Recuperarme mejor"
        case .sleep: "Dormir con consistencia"
        case .balance: "Sentirme con mas energia"
        }
    }
    var detail: String {
        switch self {
        case .perform: "Entrenar con la carga adecuada"
        case .recover: "Entender cuando bajar el ritmo"
        case .sleep: "Construir horarios que si funcionan"
        case .balance: "Equilibrar actividad, descanso y habitos"
        }
    }
    var icon: String {
        switch self {
        case .perform: "figure.run"
        case .recover: "heart.fill"
        case .sleep: "moon.stars.fill"
        case .balance: "bolt.fill"
        }
    }
    var color: Color {
        switch self {
        case .perform: ScoreKind.strain.color
        case .recover: ScoreKind.recovery.color
        case .sleep: ScoreKind.sleep.color
        case .balance: ScoreKind.energy.color
        }
    }
}

private enum OnboardingPriority: String, CaseIterable, Identifiable {
    case recovery, sleep, training, stress, nutrition, heart
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recovery: "Recovery"
        case .sleep: "Sueno"
        case .training: "Entrenamiento"
        case .stress: "Activacion"
        case .nutrition: "Nutricion"
        case .heart: "Salud cardiaca"
        }
    }
    var icon: String {
        switch self {
        case .recovery: "waveform.path.ecg"
        case .sleep: "moon.fill"
        case .training: "figure.strengthtraining.traditional"
        case .stress: "gauge.with.dots.needle.50percent"
        case .nutrition: "fork.knife"
        case .heart: "heart.fill"
        }
    }
    var color: Color {
        switch self {
        case .recovery, .heart: ScoreKind.recovery.color
        case .sleep: ScoreKind.sleep.color
        case .training: ScoreKind.strain.color
        case .stress: .cyan
        case .nutrition: ScoreKind.energy.color
        }
    }
}

#Preview {
    OnboardingView()
}
