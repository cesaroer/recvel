import SwiftData
import SwiftUI

struct NutritionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let profile: NutritionProfile?
    var onComplete: ((NutritionProfile) -> Void)?

    @State private var step = 0
    @State private var birthDate: Date
    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var sex: NutritionSex
    @State private var goal: NutritionGoal
    @State private var workouts: WeeklyWorkoutRange
    @State private var diet: DietStyle
    @State private var allergies: String
    @State private var dislikedFoods: String
    @State private var mealsPerDay: Int
    @State private var units: PreferredUnits

    init(profile: NutritionProfile? = nil, onComplete: ((NutritionProfile) -> Void)? = nil) {
        self.profile = profile
        self.onComplete = onComplete
        _birthDate = State(initialValue: profile?.birthDate ?? Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now)
        _heightCm = State(initialValue: profile?.heightCm ?? 170)
        _weightKg = State(initialValue: profile?.weightKg ?? 70)
        _sex = State(initialValue: NutritionSex(rawValue: profile?.sexOptional ?? "") ?? .unspecified)
        _goal = State(initialValue: NutritionGoal(rawValue: profile?.goal ?? "") ?? .maintain)
        _workouts = State(initialValue: WeeklyWorkoutRange(rawValue: profile?.weeklyWorkouts ?? "") ?? .medium)
        _diet = State(initialValue: DietStyle(rawValue: profile?.dietStyle ?? "") ?? .flexible)
        _allergies = State(initialValue: profile?.allergies ?? "")
        _dislikedFoods = State(initialValue: profile?.dislikedFoods ?? "")
        _mealsPerDay = State(initialValue: profile?.mealsPerDay ?? 3)
        _units = State(initialValue: PreferredUnits(rawValue: profile?.preferredUnits ?? "") ?? .metric)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                setupHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        stepContent
                            .id(step)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 160)
                }
                .scrollIndicators(.hidden)

                bottomAction
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.38), value: step)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var setupHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.soft()
                    if step > 0 { step -= 1 } else if profile != nil { dismiss() }
                } label: {
                    Image(systemName: step > 0 ? "chevron.left" : "xmark")
                        .font(.subheadline.weight(.bold))
                        .headerCircleChrome(size: 38)
                }
                .buttonStyle(.plain)
                .opacity(step == 0 && profile == nil ? 0 : 1)
                .disabled(step == 0 && profile == nil)
                .accessibilityLabel(step > 0 ? "Atras" : "Cerrar")

                Spacer()
                Text(profile == nil ? "Configurar Nutricion" : "Editar perfil")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }

            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? ScoreKind.recovery.color : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: goalStep
        case 1: bodyStep
        case 2: movementStep
        default: preferencesStep
        }
    }

    private var goalStep: some View {
        setupPage(
            eyebrow: "TU DIRECCION",
            title: "¿Que quieres que la nutricion haga por ti?",
            detail: "Esto ajusta el rango de energia y la prioridad de macros. Puedes cambiarlo cuando quieras."
        ) {
            VStack(spacing: 9) {
                ForEach(NutritionGoal.allCases) { item in
                    selectionRow(
                        title: item.rawValue,
                        icon: goalIcon(item),
                        selected: goal == item
                    ) { goal = item }
                }
            }
        }
    }

    private var bodyStep: some View {
        setupPage(
            eyebrow: "REFERENCIA PERSONAL",
            title: "Tu punto de partida",
            detail: "Escribe tu altura y peso, o gira la ruleta. Se usan solo en el dispositivo para el rango inicial."
        ) {
            VStack(spacing: 14) {
                setupField("Fecha de nacimiento", icon: "calendar") {
                    DatePicker("", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                }

                BodyMetricInput(
                    title: "Altura",
                    icon: "ruler",
                    value: $heightCm,
                    unit: "cm",
                    range: 120...230,
                    step: 1,
                    fractionDigits: 0,
                    accessibilityId: "nutrition.setup.height"
                )

                BodyMetricInput(
                    title: "Peso",
                    icon: "scalemass.fill",
                    value: $weightKg,
                    unit: "kg",
                    range: 35...250,
                    step: 0.5,
                    fractionDigits: 1,
                    accessibilityId: "nutrition.setup.weight"
                )

                VStack(alignment: .leading, spacing: 9) {
                    Text("Sexo para la formula inicial").font(.caption).foregroundStyle(.secondary)
                    Menu {
                        ForEach(NutritionSex.allCases) { item in
                            Button {
                                Haptics.menuSelect()
                                sex = item
                            } label: {
                                if sex == item { Label(item.rawValue, systemImage: "checkmark") }
                                else { Text(item.rawValue) }
                            }
                        }
                    } label: {
                        HStack {
                            Text(sex.rawValue).font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(13)
                        .platformGlass(interactive: true)
                    }
                    .hapticMenuLabel()
                }
            }
        }
    }

    private var movementStep: some View {
        setupPage(
            eyebrow: "RITMO REAL",
            title: "¿Cuanto entrenas normalmente?",
            detail: "La actividad cambia el rango, pero el plan diario seguira observando lo que realmente registras."
        ) {
            VStack(spacing: 10) {
                ForEach(WeeklyWorkoutRange.allCases) { item in
                    selectionRow(
                        title: "\(item.rawValue) entrenamientos por semana",
                        icon: workoutIcon(item),
                        selected: workouts == item
                    ) { workouts = item }
                }

                HStack {
                    Label("Comidas por dia", systemImage: "fork.knife")
                    Spacer()
                    Stepper("\(mealsPerDay)", value: $mealsPerDay.hapticStep(), in: 2...6)
                        .fixedSize()
                }
                .font(.subheadline.weight(.medium))
                .padding(15)
                .liquidGlass(cornerRadius: 8, tint: ScoreKind.energy.color)
            }
        }
    }

    private var preferencesStep: some View {
        setupPage(
            eyebrow: "COMER A TU MANERA",
            title: "Haz que las sugerencias sean utiles",
            detail: "Evitaremos lo que indiques en las ideas de comidas. Las alergias requieren siempre tu propia verificacion."
        ) {
            VStack(spacing: 14) {
                Menu {
                    ForEach(DietStyle.allCases) { item in
                        Button {
                            Haptics.menuSelect()
                            diet = item
                        } label: {
                            if diet == item { Label(item.rawValue, systemImage: "checkmark") }
                            else { Text(item.rawValue) }
                        }
                    }
                } label: {
                    setupMenuLabel(title: "Estilo de alimentacion", value: diet.rawValue, icon: "leaf.fill")
                }
                .hapticMenuLabel()

                inputField(title: "Alergias", placeholder: "Ej. cacahuate, lacteos", text: $allergies, icon: "exclamationmark.shield.fill")
                inputField(title: "Alimentos que no te gustan", placeholder: "Ej. atun, champiñones", text: $dislikedFoods, icon: "hand.thumbsdown.fill")

                Picker("Unidades", selection: $units) {
                    ForEach(PreferredUnits.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: units) { _, _ in Haptics.selection() }
            }
        }
    }

    private func setupPage<Content: View>(
        eyebrow: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow).font(.caption2.weight(.heavy)).foregroundStyle(ScoreKind.recovery.color)
                Text(title).font(.system(size: 29, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private func selectionRow(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(selected ? .black : ScoreKind.recovery.color)
                    .frame(width: 38, height: 38)
                    .background(selected ? ScoreKind.recovery.color : ScoreKind.recovery.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? ScoreKind.recovery.color : Color.white.opacity(0.32))
            }
            .padding(14)
            .liquidGlass(cornerRadius: 8, tint: selected ? ScoreKind.recovery.color : nil)
        }
        .buttonStyle(.plain)
    }

    private func setupField<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.cyan).frame(width: 26)
            Text(title).font(.subheadline)
            Spacer()
            content()
        }
        .padding(14)
        .liquidGlass(cornerRadius: 8)
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .snappyTextInput()
                .padding(12)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(14)
        .liquidGlass(cornerRadius: 8)
    }

    private func setupMenuLabel(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(ScoreKind.recovery.color).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .platformGlass(interactive: true)
    }

    private var bottomAction: some View {
        Group {
            if step == 3 {
                setupActionButton(title: "Crear mi plan", icon: "checkmark", identifier: "nutrition.setup.complete") {
                    Haptics.success()
                    save()
                }
            } else {
                setupActionButton(title: "Continuar", icon: "arrow.right", identifier: "nutrition.setup.continue") {
                    Haptics.medium()
                    Keyboard.dismiss()
                    step += 1
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 92)
        .background(.ultraThinMaterial)
    }

    private func setupActionButton(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(.black)
            .background(ScoreKind.recovery.color, in: RoundedRectangle(cornerRadius: 10))
            .tappableRounded(10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue("Paso \(step + 1) de 4")
    }

    private func save() {
        let value = profile ?? NutritionProfile()
        value.birthDate = birthDate
        value.heightCm = heightCm
        value.weightKg = weightKg
        value.sexOptional = sex.rawValue
        value.goal = goal.rawValue
        value.weeklyWorkouts = workouts.rawValue
        value.dietStyle = diet.rawValue
        value.allergies = allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        value.dislikedFoods = dislikedFoods.trimmingCharacters(in: .whitespacesAndNewlines)
        value.mealsPerDay = mealsPerDay
        value.preferredUnits = units.rawValue
        value.setupCompleted = true
        value.updatedAt = .now
        if profile == nil { modelContext.insert(value) }
        try? modelContext.save()
        onComplete?(value)
        if profile != nil { dismiss() }
    }

    private func goalIcon(_ goal: NutritionGoal) -> String {
        switch goal {
        case .loseFat: "arrow.down.circle.fill"
        case .maintain: "equal.circle.fill"
        case .gainMuscle: "figure.strengthtraining.traditional"
        case .improveEnergy: "bolt.fill"
        case .eatMoreProtein: "fork.knife"
        }
    }

    private func workoutIcon(_ range: WeeklyWorkoutRange) -> String {
        switch range {
        case .low: "figure.walk"
        case .medium: "figure.run"
        case .high: "figure.highintensity.intervaltraining"
        }
    }
}

/// Altura/peso: escribe el numero o abre la ruleta. Sin taps repetidos en +/−.
private struct BodyMetricInput: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double
    let fractionDigits: Int
    let accessibilityId: String

    @State private var text: String = ""
    @State private var showWheel = false
    @FocusState private var isFocused: Bool

    private var tickCount: Int {
        Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1
    }

    private var selectedTick: Binding<Int> {
        Binding(
            get: {
                let raw = ((value - range.lowerBound) / step).rounded()
                return min(max(Int(raw), 0), tickCount - 1)
            },
            set: { tick in
                let next = range.lowerBound + Double(tick) * step
                let clamped = min(max(next, range.lowerBound), range.upperBound)
                if clamped != value {
                    value = clamped
                    Haptics.step()
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .keyboardType(fractionDigits == 0 ? .numberPad : .decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .focused($isFocused)
                    .snappyTextInput()
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(accessibilityId)

                Text(unit)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    Haptics.menuOpen()
                    commitText()
                    showWheel = true
                } label: {
                    Image(systemName: "dial.low")
                        .font(.body.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .platformGlass(interactive: true, shape: .circle)
                }
                .accessibilityLabel("Ajustar \(title.lowercased()) con ruleta")
            }

            Text("Escribe el valor o usa la ruleta")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 8)
        .onAppear { text = format(value) }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = format(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commitText() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    hapticFeedback(.soft)
                    isFocused = false
                    commitText()
                }
            }
        }
        .sheet(isPresented: $showWheel) {
            NavigationStack {
                VStack(spacing: 8) {
                    Text(format(value) + " " + unit)
                        .font(.title.weight(.bold).monospacedDigit())
                        .padding(.top, 8)

                    Picker(title, selection: selectedTick) {
                        ForEach(0..<tickCount, id: \.self) { tick in
                            let item = range.lowerBound + Double(tick) * step
                            Text(format(item) + " " + unit).tag(tick)
                        }
                    }
                    .pickerStyle(.wheel)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") {
                            Haptics.soft()
                            text = format(value)
                            showWheel = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    private var placeholder: String {
        fractionDigits == 0 ? "170" : "70.0"
    }

    private func format(_ number: Double) -> String {
        if fractionDigits == 0 {
            return String(Int(number.rounded()))
        }
        return String(format: "%.\(fractionDigits)f", number)
    }

    private func commitText() {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(normalized) else {
            text = format(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        let snapped = (clamped / step).rounded() * step
        if snapped != value {
            value = snapped
            Haptics.step()
        }
        text = format(snapped)
    }
}
