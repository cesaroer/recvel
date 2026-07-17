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
    @AppStorage(NutritionFeatureFlags.experimentalAPIKey) private var experimentalAPIEnabled = NutritionFeatureFlags.experimentalAPIEnabledByDefault

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
    @State private var editingMeal: MealLog?
    @State private var message: String?
    @State private var showExternalConsent = false
    @State private var completedSetupProfile: NutritionProfile?

    private let estimator = NutritionEstimator()
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
        }
        .onChange(of: voiceCapture.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            composer.text = transcript
        }
        .alert("Usar IA externa experimental", isPresented: $showExternalConsent) {
            Button("Cancelar", role: .cancel) {}
            Button("Enviar") { Task { await estimateWithExternalAI() } }
        } message: {
            Text("La descripcion y, si existe, la foto saldran de este dispositivo hacia Gemini. El resultado seguira siendo editable antes de guardarse.")
        }
    }

    private func dashboard(profile: NutritionProfile) -> some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader(profile: profile)
                    dailyHero(profile: profile)
                    nextMealCard(profile: profile)
                    NutritionQuickEstimateCard(
                        composer: composer,
                        voiceCapture: voiceCapture,
                        experimentalAPIEnabled: experimentalAPIEnabled,
                        isAnalyzing: isAnalyzing,
                        selectedPhotoData: selectedPhotoData,
                        selectedPhoto: $selectedPhoto,
                        selectedBarcodePhoto: $selectedBarcodePhoto,
                        showExternalConsent: $showExternalConsent,
                        onEstimateLocal: estimateLocally,
                        onAnalyzePhoto: { item in Task { await analyzePhoto(item) } },
                        onAnalyzeBarcode: { item in Task { await analyzeBarcode(item) } }
                    )

                    if let message { messageBanner(message) }
                    if let estimate {
                        estimateCard(estimate)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
        .animation(.snappy, value: estimate?.calories)
        .animation(.snappy, value: selectedCorrections)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("NUTRICION ADAPTATIVA")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(ScoreKind.recovery.color)
                Text("Nutricion")
                    .font(.system(size: 31, weight: .bold))
                Text(profile.goal)
                    .font(.subheadline)
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
            .accessibilityLabel("Editar perfil nutricional")
        }
        .padding(.top, 8)
    }

    private func dailyHero(profile: NutritionProfile) -> some View {
        let target = targets(profile)
        let kcal = todayMeals.reduce(0) { $0 + $1.calories }
        let protein = todayMeals.reduce(0) { $0 + $1.protein }
        let carbs = todayMeals.reduce(0) { $0 + $1.carbohydrates }
        let fat = todayMeals.reduce(0) { $0 + $1.fat }

        return LiquidGlassCard(tint: ScoreKind.energy.color) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    MacroRings(
                        protein: Double(protein), proteinTarget: Double(target.protein),
                        carbs: Double(carbs), carbsTarget: Double(target.carbohydrates),
                        fat: Double(fat), fatTarget: Double(target.fat)
                    )
                    .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ENERGIA HOY")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(kcal)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("kcal").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Rango \(target.calorieLower)-\(target.calorieUpper)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(kcal > target.calorieUpper ? ScoreKind.strain.color : ScoreKind.recovery.color)
                        ProgressView(value: min(Double(kcal) / Double(max(target.calories, 1)), 1.15))
                            .tint(kcal > target.calorieUpper ? ScoreKind.strain.color : ScoreKind.energy.color)
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))
                HStack(spacing: 12) {
                    macroProgress(name: "Proteina", value: protein, target: target.protein, color: .cyan)
                    macroProgress(name: "Carbs", value: carbs, target: target.carbohydrates, color: ScoreKind.energy.color)
                    macroProgress(name: "Grasa", value: fat, target: target.fat, color: .pink)
                }
            }
        }
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

    private func nextMealCard(profile: NutritionProfile) -> some View {
        let plan = dayPlan(profile)
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Siguiente mejor comida", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(ScoreKind.recovery.color)
                Spacer()
                Text(plan.nextMeal.mealType.rawValue.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            Text(plan.nextMeal.title).font(.title3.weight(.bold))
            Text(plan.nextMeal.detail).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope").font(.caption).foregroundStyle(.cyan)
                Text(plan.nextMeal.reason).font(.caption).foregroundStyle(.secondary)
            }
            Text(plan.status).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.recovery.color)
        .accessibilityIdentifier("nutrition.nextMeal")
    }

    private func estimateCard(_ estimate: NutritionEstimate) -> some View {
        let adjusted = adjustedEstimate(estimate)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(estimate.title).font(.headline).lineLimit(2)
                    Label("Confianza \(estimate.confidence.rawValue.lowercased())", systemImage: confidenceIcon(estimate.confidence))
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
                MacroValue(name: "Proteina", value: adjusted.protein, color: .cyan)
                MacroValue(name: "Carbs", value: adjusted.carbohydrates, color: .orange)
                MacroValue(name: "Grasa", value: adjusted.fat, color: .pink)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Porcion", systemImage: "scalemass.fill").font(.subheadline)
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
                Text("Corrige lo que la IA no puede ver").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                correctionChips
            }

            HStack {
                Text("Tipo de comida").font(.subheadline)
                Spacer()
                Menu {
                    ForEach(MealType.allCases) { type in
                        Button {
                            Haptics.menuSelect()
                            mealType = type
                        } label: {
                            if mealType == type { Label(type.rawValue, systemImage: "checkmark") }
                            else { Text(type.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mealType.rawValue).font(.subheadline.weight(.semibold))
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
            } label: {
                Label("Confirmar y guardar", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))

            Text("Las calorias son un rango asistido. Revisa porciones, aceites y bebidas antes de guardar.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: confidenceColor(estimate.confidence))
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

    private func tomorrowPlan(profile: NutritionProfile) -> some View {
        let plan = dayPlan(profile)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan de mañana").font(.title3.weight(.bold))
                    Text(plan.tomorrowReason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
                        Text(suggestion.mealType.rawValue.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                        Text(suggestion.title).font(.subheadline.weight(.semibold))
                        Text(suggestion.detail).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if index < plan.tomorrow.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8, tint: ScoreKind.sleep.color)
        .accessibilityIdentifier("nutrition.tomorrowPlan")
    }

    private func planColor(_ index: Int) -> Color {
        [.cyan, ScoreKind.energy.color, .pink][min(index, 2)]
    }

    @ViewBuilder
    private var recentMeals: some View {
        Text("Timeline").font(.title3.weight(.semibold))
        if meals.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle").font(.system(size: 30)).foregroundStyle(.tertiary)
                Text("Sin comidas registradas").font(.headline)
                Text("Tu primera comida confirmada aparecera aqui con rango, macros y fuente.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 26).liquidGlass(cornerRadius: 8)
        } else {
            ForEach(meals.prefix(8)) { meal in
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: mealIcon(meal))
                            .foregroundStyle(ScoreKind.energy.color)
                            .frame(width: 34, height: 34)
                            .background(ScoreKind.energy.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            HStack(spacing: 5) {
                                Text(meal.createdAt.formatted(date: .abbreviated, time: .shortened))
                                if let type = meal.mealType { Text("· \(type)") }
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(meal.calories) kcal").font(.subheadline.weight(.semibold)).monospacedDigit()
                            Button("Usar de nuevo") {
                            Haptics.soft()
                            reuse(meal)
                        }
                            .font(.caption2.weight(.semibold)).foregroundStyle(.cyan)
                        }
                        Menu {
                            Button {
                                Haptics.menuSelect()
                                reuse(meal)
                            } label: { Label("Usar de nuevo", systemImage: "arrow.counterclockwise") }
                            Button {
                                Haptics.menuSelect()
                                editingMeal = meal
                            } label: { Label("Editar", systemImage: "pencil") }
                            Button(role: .destructive) {
                                Haptics.warning()
                                modelContext.delete(meal)
                                try? modelContext.save()
                            } label: { Label("Eliminar", systemImage: "trash") }
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
                }
            }
        }
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
            .accessibilityLabel("Cerrar")
        }
        .padding(13)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
    }

    private func estimateLocally() {
        guard let value = estimator.estimate(from: composer.text) else { return }
        estimate = value
        prepareEstimate()
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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

    private func reuse(_ meal: MealLog) {
        estimate = NutritionEstimate(
            title: meal.title,
            calories: meal.calories,
            protein: meal.protein,
            carbohydrates: meal.carbohydrates,
            fat: meal.fat,
            confidence: DataConfidence(rawValue: meal.confidence ?? "") ?? .high,
            kcalLower: meal.kcalLower,
            kcalUpper: meal.kcalUpper,
            uncertainties: ["Reutilizado del historial"],
            source: "reuse"
        )
        composer.text = meal.title
        prepareEstimate()
        mealType = MealType(rawValue: meal.mealType ?? "") ?? inferredMealType()
    }

    private func inferredMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 11 { return .breakfast }
        if hour < 16 { return .lunch }
        if hour < 21 { return .dinner }
        return .snack
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

    private func confidenceIcon(_ confidence: DataConfidence) -> String {
        switch confidence { case .low: "exclamationmark.triangle.fill"; case .medium: "circle.lefthalf.filled"; case .high: "checkmark.seal.fill" }
    }

    private func confidenceColor(_ confidence: DataConfidence) -> Color {
        switch confidence { case .low: ScoreKind.strain.color; case .medium: ScoreKind.energy.color; case .high: ScoreKind.recovery.color }
    }
}

@Observable
private final class NutritionTextComposer {
    var text = ""
}

private struct NutritionQuickEstimateCard: View {
    @Bindable var composer: NutritionTextComposer
    @ObservedObject var voiceCapture: NutritionVoiceCapture
    let experimentalAPIEnabled: Bool
    let isAnalyzing: Bool
    let selectedPhotoData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var selectedBarcodePhoto: PhotosPickerItem?
    @Binding var showExternalConsent: Bool
    let onEstimateLocal: () -> Void
    let onAnalyzePhoto: (PhotosPickerItem) -> Void
    let onAnalyzeBarcode: (PhotosPickerItem) -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Registrar comida").font(.headline)
                    Text("Elige la entrada mas rapida y confirma la porcion.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isAnalyzing { ProgressView().controlSize(.small) }
            }

            HStack(spacing: 9) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    quickAction(icon: "camera.fill", title: "Foto", color: .cyan)
                }
                .onChange(of: selectedPhoto) { _, item in
                    guard let item else { return }
                    onAnalyzePhoto(item)
                }

                Button {
                    isInputFocused = true
                } label: {
                    quickAction(icon: "text.cursor", title: "Texto", color: ScoreKind.recovery.color)
                }

                Button {
                    Task {
                        if voiceCapture.isRecording { voiceCapture.stop() }
                        else { await voiceCapture.start() }
                    }
                } label: {
                    quickAction(
                        icon: voiceCapture.isRecording ? "stop.fill" : "waveform",
                        title: voiceCapture.isRecording ? "Parar" : "Voz",
                        color: .pink
                    )
                }

                PhotosPicker(selection: $selectedBarcodePhoto, matching: .images) {
                    quickAction(icon: "barcode.viewfinder", title: "Codigo", color: ScoreKind.energy.color)
                }
                .onChange(of: selectedBarcodePhoto) { _, item in
                    guard let item else { return }
                    onAnalyzeBarcode(item)
                }
            }
            .disabled(isAnalyzing)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "fork.knife").foregroundStyle(.secondary)
                TextField("Ej. 2 tacos de pollo, frijoles y agua", text: $composer.text, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(2...4)
                    .snappyTextInput()
                    .accessibilityIdentifier("nutrition.description")
            }
            .padding(12)
            .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 10) {
                Button {
                    Haptics.medium()
                    isInputFocused = false
                    onEstimateLocal()
                } label: {
                    Label("Estimar local", systemImage: "iphone.and.arrow.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ScoreKind.recovery.color)
                .foregroundStyle(.black)
                .disabled(composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("nutrition.estimate")

                if experimentalAPIEnabled {
                    Button { showExternalConsent = true } label: {
                        Image(systemName: "sparkles")
                            .frame(width: 42, height: 42)
                            .platformGlass(tint: .cyan, interactive: true, shape: .circle)
                    }
                    .accessibilityLabel("Probar IA externa")
                    .disabled(composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhotoData == nil)
                }
            }
        }
        .padding(17)
        .liquidGlass(cornerRadius: 8)
    }

    private func quickAction(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.headline).foregroundStyle(color)
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .platformGlass(tint: color, interactive: true)
    }
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
                    ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Energia y macros") {
                Stepper("\(meal.calories) kcal", value: $meal.calories.hapticStep(), in: 0...5_000, step: 10)
                Stepper("Proteina · \(meal.protein) g", value: $meal.protein.hapticStep(), in: 0...500)
                Stepper("Carbohidratos · \(meal.carbohydrates) g", value: $meal.carbohydrates.hapticStep(), in: 0...800)
                Stepper("Grasa · \(meal.fat) g", value: $meal.fat.hapticStep(), in: 0...500)
            }
            if let notes = meal.notes, !notes.isEmpty { Section("Correcciones") { Text(notes) } }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Editar comida")
        .navigationBarTitleDisplayMode(.inline)
        .liquidGlassNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
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

private struct MacroRings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let protein: Double, proteinTarget: Double
    let carbs: Double, carbsTarget: Double
    let fat: Double, fatTarget: Double
    @State private var animated = false

    var body: some View {
        ZStack {
            ring(progress: protein / max(proteinTarget, 1), color: .cyan, padding: 0)
            ring(progress: carbs / max(carbsTarget, 1), color: ScoreKind.energy.color, padding: 14)
            ring(progress: fat / max(fatTarget, 1), color: .pink, padding: 28)
            Image(systemName: "fork.knife").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.75).delay(0.1)) { animated = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Macros de hoy: proteina \(Int(protein)) de \(Int(proteinTarget)) gramos, carbohidratos \(Int(carbs)) de \(Int(carbsTarget)), grasa \(Int(fat)) de \(Int(fatTarget))")
    }

    private func ring(progress: Double, color: Color, padding: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: animated ? min(progress, 1) : 0)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
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
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
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
