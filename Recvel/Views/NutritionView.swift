import AVFoundation
import PhotosUI
import Speech
import SwiftData
import SwiftUI
import UIKit
import Vision

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealLog.createdAt, order: .reverse) private var meals: [MealLog]
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var profiles: [NutritionProfile]
    @Query(sort: \DailyScoreRecord.date, order: .reverse) private var scoreRecords: [DailyScoreRecord]

    @State private var editingMeal: MealLog?
    /// Peticion abierta de la pantalla de registro (vacia o con texto reutilizado).
    @State private var recordRequest: RecordFoodRequest?
    @State private var completedSetupProfile: NutritionProfile?

    private let planner = NutritionPlanEngine()

    private var profile: NutritionProfile? {
        completedSetupProfile ?? profiles.first { $0.setupCompleted }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    dashboard(profile: profile)
                } else {
                    NutritionSetupView { completedProfile in
                        completedSetupProfile = completedProfile
                    }
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { editingMeal != nil },
                    set: { if !$0 { editingMeal = nil } }
                )
            ) {
                if let editingMeal {
                    MealEditorView(meal: editingMeal)
                        .hidesTabBar()
                }
            }
            .navigationDestination(item: $recordRequest) { request in
                RecordFoodView(initialText: request.text)
            }
        }
    }

    private func dashboard(profile: NutritionProfile) -> some View {
        ZStack {
            AppBackground()
            WidthLockedScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Orden por urgencia de la pregunta que trae al usuario:
                    //
                    // 1. "¿Como voy?"  → los anillos. Es el contexto que da
                    //    sentido a todo lo demas. MyFitnessPal degrado este
                    //    resumen en 2018 y tuvo que revertirlo: sin el, la
                    //    pantalla no orienta.
                    // 2. "Quiero registrar" → la accion mas frecuente, pegada
                    //    justo debajo del estado que modifica.
                    // 3. "¿Que como ahora?" → el consejo. Va DESPUES del
                    //    estado porque se deriva de el: su frase ("te faltan
                    //    37 g de proteina") no significa nada hasta haber
                    //    visto los anillos.
                    // 4-5. Mañana e historial: futuro y pasado, menos urgentes.
                    pageHeader(profile: profile)
                    dailyHero(profile: profile)
                    recordFoodEntry
                    nextMealCard(profile: profile)
                    tomorrowPlan(profile: profile)
                    recentMeals
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .trackTabBarScroll()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var todayMeals: [MealLog] {
        meals.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private func targets(_ profile: NutritionProfile) -> NutritionTargets {
        planner.targets(for: profile, now: .now)
    }

    private var healthContext: NutritionHealthContext {
        guard let record = scoreRecords.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            return .empty
        }
        return NutritionHealthContext(
            recovery: record.recovery > 0 ? record.recovery : nil,
            sleep: record.sleep > 0 ? record.sleep : nil,
            strain: record.strain > 0 ? record.strain : nil,
            plannedWorkout: record.strain >= 65
        )
    }

    private func dayPlan(_ profile: NutritionProfile) -> NutritionDayPlan {
        planner.plan(for: profile, meals: meals, context: healthContext, now: .now)
    }

    private func pageHeader(profile: NutritionProfile) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(RecvelL10n.text("nutrition.header.eyebrow").uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(ScoreKind.recovery.color.opacity(0.85))
                Text(RecvelL10n.text("tab.nutrition"))
                    .font(.system(size: 34, weight: .bold))
                // `profile.goal` guarda el rawValue en español; se resuelve por
                // el enum para usar su `displayName` localizado. Sin esto la
                // cabecera decia "Mantener" con la app en ingles.
                Text(NutritionGoal(rawValue: profile.goal)?.displayName ?? profile.goal)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                NutritionSetupView(profile: profile)
                    .hidesTabBar()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .platformGlass(tint: ScoreKind.recovery.color, interactive: true, shape: .circle)
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })
            .accessibilityLabel(RecvelL10n.text("nutrition.profile.edit"))
        }
        .padding(.top, 8)
    }

    private func dailyHero(profile: NutritionProfile) -> some View {
        let target = targets(profile)
        let kcal = todayMeals.reduce(0) { $0 + $1.calories }
        let protein = todayMeals.reduce(0) { $0 + $1.protein }
        let carbs = todayMeals.reduce(0) { $0 + $1.carbohydrates }
        let fat = todayMeals.reduce(0) { $0 + $1.fat }

        return VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    MacroRings(
                        protein: Double(protein), proteinTarget: Double(target.protein),
                        carbs: Double(carbs), carbsTarget: Double(target.carbohydrates),
                        fat: Double(fat), fatTarget: Double(target.fat)
                    )
                    .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(RecvelL10n.text("nutrition.today.eyebrow").uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(kcal)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("kcal").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(RecvelL10n.text("nutrition.today.range", values: ["lower": "\(target.calorieLower)", "upper": "\(target.calorieUpper)"]))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(kcal > target.calorieUpper ? ScoreKind.strain.color : ScoreKind.recovery.color)
                        ProgressView(value: min(Double(kcal) / Double(max(target.calories, 1)), 1.15))
                            .tint(kcal > target.calorieUpper ? ScoreKind.strain.color : ScoreKind.energy.color)
                    }
                }

                Divider().overlay(Color.white.opacity(0.07))
                HStack(spacing: 12) {
                    macroProgress(name: RecvelL10n.text("nutrition.macro.protein"), value: protein, target: target.protein, color: MacroPalette.protein.tip)
                    macroProgress(name: RecvelL10n.text("nutrition.macro.carbs"), value: carbs, target: target.carbohydrates, color: MacroPalette.carbs.tip)
                    macroProgress(name: RecvelL10n.text("nutrition.macro.fat"), value: fat, target: target.fat, color: MacroPalette.fat.tip)
                }
        }
        .padding(18)
        .revelSurface(accent: ScoreKind.energy.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition.today")
    }

    private func macroProgress(name: String, value: Int, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            Text("\(value) / \(target) g").font(.caption.weight(.bold)).monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: proxy.size.width * min(Double(value) / Double(max(target, 1)), 1))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    /// Banner de consejo de la siguiente comida.
    ///
    /// Antes apilaba SEIS niveles de texto —eyebrow, titulo de tarjeta, chip de
    /// comida, nombre del platillo, detalle, razon y estado del dia— y los tres
    /// ultimos en 9-11 pt, asi que se leia como un volcado de datos ilegible en
    /// vez de un consejo. Ahora son tres bloques:
    ///
    /// 1. Una linea de contexto (icono + "lo siguiente" + chip de la comida).
    /// 2. La recomendacion: nombre del platillo grande y su detalle.
    /// 3. El porque, separado por un divisor y en cuerpo legible.
    ///
    /// El titulo "Siguiente comida recomendada" desaparece como linea propia
    /// —vive en el eyebrow— y ningun texto baja de 13 pt.
    private func nextMealCard(profile: NutritionProfile) -> some View {
        let plan = dayPlan(profile)
        let accent = ScoreKind.recovery.color
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text(RecvelL10n.text("nutrition.nextMeal.title"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                Text(plan.nextMeal.mealType.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.nextMeal.title)
                    .font(.system(size: 23, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(plan.nextMeal.detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // El "porque": lo que justifica la recomendacion. Separado del
            // consejo para que se lea como nota al pie, no como mas contenido.
            VStack(alignment: .leading, spacing: 7) {
                Divider().overlay(Color.white.opacity(0.07))
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.9))
                    Text(nextMealRationale(plan))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Destacada: es la unica tarjeta de la pantalla que ACONSEJA; el resto
        // informa. Sin el borde se perdia entre sus vecinas identicas.
        .revelSurface(accent: accent, emphasized: true)
        .accessibilityIdentifier("nutrition.nextMeal")
    }

    /// Une la razon de la comida y el estado del dia en un solo parrafo.
    ///
    /// Eran dos lineas casi identicas en tono, una encima de otra y en dos
    /// tamaños diminutos distintos; juntas leen como una sola nota. Se descarta
    /// la duplicada cuando el motor devuelve el mismo texto en ambas.
    /// Punto de entrada al registro de comida.
    ///
    /// Antes el flujo entero (cuatro entradas, campo, estimacion, correcciones,
    /// porcion y guardado) vivia aqui dentro y empujaba el resto del dashboard
    /// hacia abajo cuando aparecia un resultado. Ahora esto solo invita, y el
    /// trabajo ocurre en `RecordFoodView`.
    private var recordFoodEntry: some View {
        Button {
            Haptics.soft()
            recordRequest = RecordFoodRequest()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ScoreKind.energy.color)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.05), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(RecvelL10n.text("nutrition.record.eyebrow").uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(ScoreKind.energy.color.opacity(0.85))
                    Text(RecvelL10n.text("nutrition.record.title"))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(RecvelL10n.text("nutrition.record.entryDetail"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .intelligenceSurface()
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrition.recordEntry")
    }

    private func nextMealRationale(_ plan: NutritionDayPlan) -> String {
        let reason = plan.nextMeal.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = plan.status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty, status != reason else { return reason }
        guard !reason.isEmpty else { return status }
        return "\(reason) \(status)"
    }

    private func tomorrowPlan(profile: NutritionProfile) -> some View {
        let plan = dayPlan(profile)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RecvelL10n.text("nutrition.tomorrow.eyebrow").uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(ScoreKind.sleep.color.opacity(0.85))
                    Text(RecvelL10n.text("nutrition.tomorrow.title")).font(.system(size: 19, weight: .semibold))
                    Text(plan.tomorrowReason).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "calendar.badge.clock").foregroundStyle(ScoreKind.sleep.color)
            }

            ForEach(Array(plan.tomorrow.enumerated()), id: \.element.id) { index, suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.heavy)).foregroundStyle(.black)
                        .frame(width: 25, height: 25)
                        .background(planColor(index), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.mealType.displayName.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                        Text(suggestion.title).font(.subheadline.weight(.semibold))
                        Text(suggestion.detail).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if index < plan.tomorrow.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
        .padding(18)
        .revelSurface(accent: ScoreKind.sleep.color)
        .accessibilityIdentifier("nutrition.tomorrowPlan")
    }

    private func planColor(_ index: Int) -> Color {
        [.cyan, ScoreKind.energy.color, .pink][min(index, 2)]
    }

    @ViewBuilder
    private var recentMeals: some View {
        RevelSectionHeader(
            eyebrow: RecvelL10n.text("nutrition.timeline.eyebrow"),
            title: RecvelL10n.text("nutrition.timeline.title"),
            accent: ScoreKind.energy.color
        )
        if meals.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle").font(.system(size: 30)).foregroundStyle(.tertiary)
                Text(RecvelL10n.text("nutrition.timeline.empty")).font(.headline)
                Text(RecvelL10n.text("nutrition.timeline.emptyDetail"))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30).revelSurface()
        } else {
            ForEach(meals.prefix(8)) { meal in
                HStack(spacing: 12) {
                        Image(systemName: mealIcon(meal))
                            .foregroundStyle(ScoreKind.energy.color)
                            .frame(width: 34, height: 34)
                            .background(ScoreKind.energy.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            HStack(spacing: 5) {
                                Text(meal.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(RecvelL10n.locale)))
                                if let type = meal.mealType { Text("· \(type)") }
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(meal.calories) kcal").font(.subheadline.weight(.semibold)).monospacedDigit()
                            Button(RecvelL10n.text("nutrition.meal.reuse")) {
                            Haptics.soft()
                            reuse(meal)
                        }
                            .font(.caption2.weight(.semibold)).foregroundStyle(.cyan)
                        }
                        Menu {
                            Button {
                                Haptics.menuSelect()
                                reuse(meal)
                            } label: { Label(RecvelL10n.text("nutrition.meal.reuse"), systemImage: "arrow.counterclockwise") }
                            Button {
                                Haptics.menuSelect()
                                editingMeal = meal
                            } label: { Label(RecvelL10n.text("nutrition.meal.edit"), systemImage: "pencil") }
                            Button(role: .destructive) {
                                Haptics.warning()
                                modelContext.delete(meal)
                                try? modelContext.save()
                            } label: { Label(RecvelL10n.text("nutrition.meal.delete"), systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                .frame(width: 32, height: 32).contentShape(Circle())
                                .platformGlass(tint: ScoreKind.energy.color, interactive: true, shape: .circle)
                        }
                        .menuOrder(.fixed)
                        .hapticMenuLabel()
                        .accessibilityLabel("Acciones de \(meal.title)")
                }
                .padding(14)
                .revelSurface(cornerRadius: 18)
            }
        }
    }

    /// Reutilizar una comida ya no rellena un campo del dashboard: abre la
    /// pantalla de registro con el texto puesto.
    private func reuse(_ meal: MealLog) {
        recordRequest = RecordFoodRequest(text: meal.title)
    }


    private func mealIcon(_ meal: MealLog) -> String {
        switch MealType(rawValue: meal.mealType ?? "") {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.fill"
        case .snack: "takeoutbag.and.cup.and.straw.fill"
        case nil: "fork.knife"
        }
    }


}

@Observable
private final class NutritionTextComposer {
    var text = ""
}

private struct CorrectionOption: Identifiable {
    let id: String
    let label: String
    let icon: String
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int

    static let all = [
        CorrectionOption(id: "oil", label: "+ aceite", icon: "drop.fill", calories: 120, protein: 0, carbohydrates: 0, fat: 14),
        CorrectionOption(id: "sauce", label: "+ salsa", icon: "takeoutbag.and.cup.and.straw.fill", calories: 35, protein: 0, carbohydrates: 6, fat: 1),
        CorrectionOption(id: "drink", label: "+ bebida", icon: "cup.and.saucer.fill", calories: 120, protein: 0, carbohydrates: 30, fat: 0),
        CorrectionOption(id: "dessert", label: "+ postre", icon: "birthday.cake.fill", calories: 220, protein: 3, carbohydrates: 34, fat: 8),
        CorrectionOption(id: "double", label: "doble porcion", icon: "plus.forwardslash.minus", calories: 0, protein: 0, carbohydrates: 0, fat: 0),
        CorrectionOption(id: "remove", label: "quitar item", icon: "minus.circle.fill", calories: 0, protein: 0, carbohydrates: 0, fat: 0)
    ]
}

private struct MealEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var meal: MealLog

    var body: some View {
        Form {
            Section("Comida") {
                TextField("Nombre", text: $meal.title)
                    .snappyTextInput()
                DatePicker("Fecha", selection: $meal.createdAt)
                Picker("Tipo", selection: Binding(
                    get: { MealType(rawValue: meal.mealType ?? "") ?? .lunch },
                    set: { meal.mealType = $0.rawValue }
                )) {
                    ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section("Energía y macronutrientes") {
                Stepper("\(meal.calories) kcal", value: $meal.calories.hapticStep(), in: 0...5_000, step: 10)
                Stepper("Proteina · \(meal.protein) g", value: $meal.protein.hapticStep(), in: 0...500)
                Stepper("Carbohidratos · \(meal.carbohydrates) g", value: $meal.carbohydrates.hapticStep(), in: 0...800)
                Stepper("Grasa · \(meal.fat) g", value: $meal.fat.hapticStep(), in: 0...500)
            }
            if let notes = meal.notes, !notes.isEmpty { Section("Correcciones") { Text(notes) } }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(RecvelL10n.text("nutrition.meal.editTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .liquidGlassNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(RecvelL10n.text("common.save")) {
                    Haptics.success()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

private struct MacroValue: View {
    let name: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value) g").font(.headline.monospacedDigit())
            Text(name).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }
}

/// Paleta de los macros.
///
/// Es una escala **categorica** (tres identidades, no una magnitud), validada
/// con el script de la guia de dataviz contra la superficie de tarjeta
/// (#191A1F) en modo oscuro y con `--pairs all`, porque los tres anillos se ven
/// simultaneamente: banda de luminosidad OK, contraste >= 3:1, y separacion
/// para daltonismo ΔE 14.4 (objetivo >= 8) / vision normal 20.1 (piso 15).
///
/// Antes eran `.cyan` y `.pink` **del sistema iOS**, que no pertenecen a la
/// familia Tailwind del resto de la app (#34D399, #FB923C, #A855F7, #FBBF24) y
/// por eso desentonaban.
///
/// `base` es el color validado —vive en la banda oscura— y `tip` es un paso mas
/// claro de la MISMA familia para el degradado. Asi el anillo tiene la vida de
/// los acentos brillantes de la app sin sacar el color medido de su banda.
private enum MacroPalette {
    static let protein = (base: Color(red: 0.231, green: 0.510, blue: 0.965),  // #3B82F6
                          tip: Color(red: 0.376, green: 0.647, blue: 0.980))   // #60A5FA
    static let carbs = (base: Color(red: 0.851, green: 0.467, blue: 0.024),    // #D97706
                        tip: Color(red: 0.984, green: 0.749, blue: 0.141))     // #FBBF24
    static let fat = (base: Color(red: 0.925, green: 0.282, blue: 0.600),      // #EC4899
                      tip: Color(red: 0.957, green: 0.447, blue: 0.714))       // #F472B6
}

private struct MacroRings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let protein: Double, proteinTarget: Double
    let carbs: Double, carbsTarget: Double
    let fat: Double, fatTarget: Double
    @State private var animated = false

    var body: some View {
        ZStack {
            ring(progress: protein / max(proteinTarget, 1), palette: MacroPalette.protein, padding: 0)
            ring(progress: carbs / max(carbsTarget, 1), palette: MacroPalette.carbs, padding: 14)
            ring(progress: fat / max(fatTarget, 1), palette: MacroPalette.fat, padding: 28)
            Image(systemName: "fork.knife")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.75).delay(0.1)) { animated = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Macros de hoy: proteina \(Int(protein)) de \(Int(proteinTarget)) gramos, carbohidratos \(Int(carbs)) de \(Int(carbsTarget)), grasa \(Int(fat)) de \(Int(fatTarget))")
    }

    private func ring(progress: Double, palette: (base: Color, tip: Color), padding: CGFloat) -> some View {
        let value = animated ? min(max(progress, 0), 1) : 0
        return ZStack {
            // Pista NEUTRA, no teñida. Con `color.opacity(0.15)` un dia sin
            // comidas mostraba tres circulos de colores apagados que parecian
            // datos sucios; en gris leen como lo que son: huecos por llenar.
            Circle().stroke(Color.white.opacity(0.07), lineWidth: 9)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(
                        colors: [palette.base, palette.tip],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: palette.base.opacity(value > 0 ? 0.45 : 0), radius: 6)
        }
        .padding(padding)
    }
}

private struct NutritionFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}

@MainActor
private final class NutritionVoiceCapture: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: RecvelL10n.locale)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    func start() async {
        guard !isRecording else { return }
        let speechAllowed = await requestSpeechAuthorization()
        let microphoneAllowed = await requestMicrophoneAuthorization()
        guard speechAllowed && microphoneAllowed else { return }

        stop()
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in request.append(buffer) }
        tapInstalled = true
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            stop()
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true { self.stop() }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}

// MARK: - Pantalla de registro de comida

/// Peticion de registro. Lleva el texto inicial para poder reutilizar una
/// comida del historial sin que la pantalla tenga que consultarla.
struct RecordFoodRequest: Identifiable, Hashable {
    let id = UUID()
    var text: String = ""
}

/// Pantalla dedicada a registrar una comida.
///
/// Antes todo esto vivia en una tarjeta dentro del dashboard de Nutricion: la
/// pantalla cargaba con el estado de la estimacion (foto, transcripcion,
/// correcciones, porcion) aunque el usuario solo estuviera consultando sus
/// macros, y el resultado se desplegaba empujando el resto del contenido hacia
/// abajo. Ahora el dashboard solo tiene el punto de entrada y este flujo es
/// **una pantalla empujada, no un modal**: se puede volver con el gesto de
/// siempre y el resultado tiene la altura completa.
struct RecordFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NutritionProfile.updatedAt, order: .reverse) private var profiles: [NutritionProfile]
    @AppStorage(NutritionFeatureFlags.experimentalAPIKey) private var experimentalAPIEnabled = NutritionFeatureFlags.experimentalAPIEnabledByDefault

    /// Texto con el que abre (reutilizar una comida del registro).
    var initialText: String = ""

    @StateObject private var voiceCapture = NutritionVoiceCapture()
    @State private var composer = NutritionTextComposer()
    @State private var estimate: NutritionEstimate?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedBarcodePhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isAnalyzing = false
    @State private var portionMultiplier = 1.0
    @State private var selectedCorrections: Set<String> = []
    @State private var mealType: MealType = .lunch
    @State private var message: String?
    @State private var showExternalConsent = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let estimator = NutritionEstimator()

    var body: some View {
        ZStack {
            // Version contenida del fondo del Reporte del dia: degradado casi
            // negro y dos nebulosas, SIN campo de estrellas ni polvo animado.
            // Aqui el usuario viene a escribir; el fondo acompaña, no compite.
            LabBackdropLite(tint: LabInk.energy)

            WidthLockedScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    module(0, RecvelL10n.text("nutrition.record.section.input"),
                           RecvelL10n.text("nutrition.record.section.inputCaption")) {
                        inputSection
                    }

                    module(1, RecvelL10n.text("nutrition.record.section.describe"),
                           RecvelL10n.text("nutrition.record.section.describeCaption")) {
                        describeSection
                    }

                    if let message {
                        module(2, RecvelL10n.text("nutrition.record.section.note"), nil) {
                            messageBanner(message)
                        }
                    }

                    if let estimate {
                        module(3, RecvelL10n.text("nutrition.record.section.estimate"),
                               RecvelL10n.text("nutrition.record.section.estimateCaption")) {
                            estimateCard(estimate)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .hidesTabBar()
        .animation(.snappy, value: estimate?.calories)
        .animation(.snappy, value: selectedCorrections)
        .onAppear {
            if composer.text.isEmpty { composer.text = initialText }
            mealType = inferredMealType()
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.08)) { appeared = true }
        }
        .onChange(of: voiceCapture.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            composer.text = transcript
        }
        .alert("Usar IA externa experimental", isPresented: $showExternalConsent) {
            Button("Cancelar", role: .cancel) {}
            Button("Enviar") { Task { await estimateWithExternalAI() } }
        } message: {
            Text(RecvelL10n.text("nutrition.ai.consentBody"))
        }
        .accessibilityIdentifier("nutrition.record")
    }

    /// Modulo con micro-encabezado rotulado, como en el Reporte del dia: el
    /// "instrumento" es la linea, no una caja alrededor de todo.
    private func module<Content: View>(
        _ index: Int,
        _ title: String,
        _ caption: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabSectionHeader(title: title, caption: caption)
            content()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 18)
        .animation(
            reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.88)
                .delay(0.14 + Double(index) * 0.06),
            value: appeared
        )
    }

    /// Cabecera en dos filas.
    ///
    /// El boton de volver estaba en la MISMA fila que el titulo: le robaba
    /// ancho —el subtitulo partia en dos lineas sin necesidad— y su circulo no
    /// se alineaba con ninguna linea base del texto. Ahora ocupa su propia fila
    /// de navegacion y el bloque de titulo dispone del ancho completo.
    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(LabInk.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(RecvelL10n.text("common.back"))

                Spacer(minLength: 0)

                if isAnalyzing {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text(RecvelL10n.text("nutrition.record.analyzing"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .transition(.opacity)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(RecvelL10n.text("nutrition.record.eyebrow").uppercased())
                    .font(.system(size: 10, weight: .black))
                    .kerning(1.2)
                    .foregroundStyle(LabInk.energy.opacity(0.9))
                Text(RecvelL10n.text("nutrition.record.title"))
                    .font(.system(size: 32, weight: .bold))
                Text(RecvelL10n.text("nutrition.record.detail"))
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Aire real bajo la isla dinamica: con 6 pt el bloque nacia pegado.
        .padding(.top, 12)
        .padding(.bottom, 6)
        .animation(.easeOut(duration: 0.2), value: isAnalyzing)
    }

    /// Las cuatro vias de entrada.
    private var inputSection: some View {
        HStack(spacing: 9) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                quickAction(icon: "camera.fill", title: RecvelL10n.text("nutrition.input.photo"))
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await analyzePhoto(item) }
            }

            Button {
                isInputFocused = true
            } label: {
                quickAction(icon: "text.cursor", title: RecvelL10n.text("nutrition.input.text"))
            }

            Button {
                Task {
                    if voiceCapture.isRecording { voiceCapture.stop() }
                    else { await voiceCapture.start() }
                }
            } label: {
                quickAction(
                    icon: voiceCapture.isRecording ? "stop.fill" : "waveform",
                    title: RecvelL10n.text(voiceCapture.isRecording ? "nutrition.input.stop" : "nutrition.input.voice"),
                    isActive: voiceCapture.isRecording
                )
            }

            PhotosPicker(selection: $selectedBarcodePhoto, matching: .images) {
                quickAction(icon: "barcode.viewfinder", title: RecvelL10n.text("nutrition.input.barcode"))
            }
            .onChange(of: selectedBarcodePhoto) { _, item in
                guard let item else { return }
                Task { await analyzeBarcode(item) }
            }
        }
        .disabled(isAnalyzing)
    }

    /// Descripcion escrita + disparo de la estimacion.
    private var describeSection: some View {
        VStack(spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "fork.knife").foregroundStyle(.white.opacity(0.45))
                TextField(RecvelL10n.text("nutrition.input.placeholder"), text: $composer.text, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(2...4)
                    .snappyTextInput()
                    .accessibilityIdentifier("nutrition.description")
            }
            .padding(14)
            .background(LabInk.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LabInk.hairline, lineWidth: 1)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.medium()
                    isInputFocused = false
                    estimateLocally()
                } label: {
                    Label(RecvelL10n.text("nutrition.record.estimateLocal"), systemImage: "iphone.and.arrow.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canEstimate ? .black : Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            canEstimate ? LabInk.energy : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canEstimate)
                .animation(.easeOut(duration: 0.2), value: canEstimate)
                .accessibilityIdentifier("nutrition.estimate")

                if experimentalAPIEnabled {
                    Button { showExternalConsent = true } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 50, height: 50)
                            .background(LabInk.panel, in: Circle())
                            .overlay(Circle().strokeBorder(LabInk.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RecvelL10n.text("nutrition.record.tryExternalAI"))
                    .disabled(!canEstimate && selectedPhotoData == nil)
                }
            }
        }
    }

    /// Hay algo que estimar: texto escrito o foto adjunta.
    private var canEstimate: Bool {
        !composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

private func quickAction(icon: String, title: String, isActive: Bool = false) -> some View {
        let accent = ScoreKind.energy.color
        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? accent : Color.white.opacity(0.85))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? accent : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            (isActive ? accent.opacity(0.14) : Color.white.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isActive ? accent.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: isActive)
    }

    private func estimateCard(_ estimate: NutritionEstimate) -> some View {
        let adjusted = adjustedEstimate(estimate)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(estimate.title).font(.headline).lineLimit(2)
                    Label("\(RecvelL10n.text("common.confidence")) \(estimate.confidence.displayName.lowercased())", systemImage: confidenceIcon(estimate.confidence))
                        .font(.caption)
                        .foregroundStyle(confidenceColor(estimate.confidence))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(adjusted.calories)").font(.title.weight(.bold)).monospacedDigit().contentTransition(.numericText())
                    Text("\(adjusted.kcalLower)-\(adjusted.kcalUpper) kcal")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }

            HStack {
                MacroValue(name: RecvelL10n.text("nutrition.macro.protein"), value: adjusted.protein, color: .cyan)
                MacroValue(name: RecvelL10n.text("nutrition.macro.carbohydrates"), value: adjusted.carbohydrates, color: .orange)
                MacroValue(name: RecvelL10n.text("nutrition.macro.fat"), value: adjusted.fat, color: .pink)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("nutrition.portion", systemImage: "scalemass.fill").font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1fx", portionMultiplier)).font(.subheadline.weight(.bold)).monospacedDigit()
                }
                Slider(value: $portionMultiplier.hapticStep(), in: 0.5...3, step: 0.25)
                    .tint(ScoreKind.recovery.color)
                    .accessibilityIdentifier("nutrition.portion")
                HStack {
                    Text("Media").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("Triple").font(.caption2).foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(RecvelL10n.text("nutrition.estimate.correct")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                correctionChips
            }

            HStack {
                Text("nutrition.mealType").font(.subheadline)
                Spacer()
                Menu {
                    ForEach(MealType.allCases) { type in
                        Button {
                            Haptics.menuSelect()
                            mealType = type
                        } label: {
                            if mealType == type { Label(type.displayName, systemImage: "checkmark") }
                            else { Text(type.displayName) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mealType.displayName).font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .padding(.horizontal, 12).frame(height: 36)
                    .platformGlass(interactive: true, shape: .capsule)
                }
                .hapticMenuLabel()
            }

            NutritionFlowLayout(spacing: 6) {
                ForEach(Array(Set(adjusted.uncertainties)).sorted(), id: \.self) { item in
                    Label(item, systemImage: "questionmark.circle")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
            }

            Button {
                Haptics.success()
                LocalStore.save(
                    adjusted,
                    mealType: mealType,
                    notes: selectedCorrections.sorted().joined(separator: ", "),
                    in: modelContext
                )
                resetEstimate()
                // Al ser pantalla propia y no una tarjeta del dashboard, guardar
                // cierra el flujo: se vuelve a Nutricion, que es donde el usuario
                // ve el efecto de lo que acaba de registrar (macros y anillos).
                dismiss()
            } label: {
                Label(RecvelL10n.text("nutrition.estimate.confirm"), systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))

            Text(RecvelL10n.text("nutrition.estimate.caveat"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(17)
        .revelSurface(accent: confidenceColor(estimate.confidence))
    }

    private var correctionChips: some View {
        NutritionFlowLayout(spacing: 7) {
            ForEach(CorrectionOption.all) { option in
                Button {
                    Haptics.selection()
                    if option.id == "double" {
                        portionMultiplier = portionMultiplier == 2 ? 1 : 2
                    } else if option.id == "remove" {
                        resetEstimate()
                    } else if selectedCorrections.contains(option.id) {
                        selectedCorrections.remove(option.id)
                    } else {
                        selectedCorrections.insert(option.id)
                    }
                } label: {
                    Label(option.label, systemImage: option.icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).frame(height: 34)
                        .foregroundStyle(isCorrectionSelected(option) ? .black : .primary)
                        .background(
                            isCorrectionSelected(option) ? ScoreKind.energy.color : Color.white.opacity(0.07),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isCorrectionSelected(_ option: CorrectionOption) -> Bool {
        option.id == "double" ? portionMultiplier == 2 : selectedCorrections.contains(option.id)
    }

    private func messageBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(.cyan)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                Haptics.soft()
                message = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(RecvelL10n.text("common.close"))
        }
        .padding(13)
        .revelSurface(accent: .cyan)
    }

    private func estimateLocally() {
        guard let value = estimator.estimate(from: composer.text) else { return }
        estimate = value
        prepareEstimate()
    }

    private func analyzePhoto(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let cgImage = image.cgImage else {
            message = "No se pudo leer la foto."
            return
        }
        selectedPhotoData = data
        let classifications: [String] = await Task.detached {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
            return (request.results ?? []).filter { $0.confidence >= 0.08 }.prefix(10).map(\.identifier)
        }.value

        if let foods = estimator.foodDescription(from: classifications), let local = estimator.estimate(from: foods) {
            composer.text = foods
            estimate = NutritionEstimate(
                title: local.title,
                calories: local.calories,
                protein: local.protein,
                carbohydrates: local.carbohydrates,
                fat: local.fat,
                confidence: .low,
                uncertainties: ["Clasificacion visual generica", "Porcion no medida", "Confirma ingredientes"],
                source: "photo-local"
            )
            prepareEstimate()
        } else {
            composer.text = "Describe los alimentos y la porcion que aparecen en la foto"
            message = "La clasificacion local no identifico suficientes alimentos. Agrega una descripcion o usa la IA experimental."
        }
    }

    private func analyzeBarcode(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let cgImage = image.cgImage else {
            message = "No se pudo leer la imagen del codigo."
            return
        }
        let payload: String? = await Task.detached {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
            return request.results?.first?.payloadStringValue
        }.value
        guard let payload else {
            message = "No encontramos un codigo legible. Prueba con una foto mas cercana y bien iluminada."
            return
        }
        do {
            estimate = try await OpenFoodFactsClient().estimate(barcode: payload)
            composer.text = "Codigo \(payload)"
            prepareEstimate()
        } catch {
            message = error.localizedDescription
        }
    }

    private func estimateWithExternalAI() async {
        guard let key = KeychainStore.get("nutrition.gemini.apiKey"), !key.isEmpty else {
            message = "Agrega tu API key de Gemini en Ajustes para usar el modo experimental."
            return
        }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            estimate = try await GeminiNutritionAIClient(apiKey: key).estimate(text: composer.text, imageData: selectedPhotoData)
            prepareEstimate()
        } catch {
            message = error.localizedDescription
        }
    }

    private func prepareEstimate() {
        portionMultiplier = 1
        selectedCorrections = []
        mealType = inferredMealType()
        message = nil
    }

    private func adjustedEstimate(_ estimate: NutritionEstimate) -> NutritionEstimate {
        let additions = CorrectionOption.all.filter { selectedCorrections.contains($0.id) }
        func total(_ base: Int, _ keyPath: KeyPath<CorrectionOption, Int>) -> Int {
            Int((Double(base) * portionMultiplier).rounded()) + additions.reduce(0) { $0 + $1[keyPath: keyPath] }
        }
        let addedKcal = additions.reduce(0) { $0 + $1.calories }
        return NutritionEstimate(
            title: estimate.title,
            calories: total(estimate.calories, \.calories),
            protein: total(estimate.protein, \.protein),
            carbohydrates: total(estimate.carbohydrates, \.carbohydrates),
            fat: total(estimate.fat, \.fat),
            confidence: estimate.confidence,
            kcalLower: Int((Double(estimate.kcalLower) * portionMultiplier).rounded()) + addedKcal,
            kcalUpper: Int((Double(estimate.kcalUpper) * portionMultiplier).rounded()) + addedKcal,
            uncertainties: estimate.uncertainties + additions.map(\.label),
            source: estimate.source
        )
    }

    private func resetEstimate() {
        estimate = nil
        composer.text = ""
        selectedPhoto = nil
        selectedPhotoData = nil
        selectedCorrections = []
        portionMultiplier = 1
    }

    private func inferredMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 11 { return .breakfast }
        if hour < 16 { return .lunch }
        if hour < 21 { return .dinner }
        return .snack
    }

    private func confidenceIcon(_ confidence: DataConfidence) -> String {
        switch confidence { case .low: "exclamationmark.triangle.fill"; case .medium: "circle.lefthalf.filled"; case .high: "checkmark.seal.fill" }
    }

    private func confidenceColor(_ confidence: DataConfidence) -> Color {
        switch confidence { case .low: ScoreKind.strain.color; case .medium: ScoreKind.energy.color; case .high: ScoreKind.recovery.color }
    }
}
