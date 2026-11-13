import Combine
import Foundation
import HealthKit

@MainActor
final class HealthDataProvider: ObservableObject {
    @Published private(set) var snapshot: DailyHealthSnapshot { didSet { revision &+= 1 } }
    @Published private(set) var history: [DailyHealthSnapshot] { didSet { revision &+= 1 } }
    /// Sube cada vez que cambian `snapshot` o `history`. Es la clave barata
    /// con la que las vistas cachean lo que derivan de ellos (`DerivedCache`).
    private(set) var revision = 0
    @Published private(set) var activation: [ActivationPoint]
    @Published private(set) var dataMode: HealthDataMode
    @Published private(set) var permissionState: HealthPermissionState
    @Published private(set) var authorizationMessage: String
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var isLoading = false

    /// Fase del nucleo: snapshot del dia + historial. La consumen las tarjetas
    /// de puntuaciones, tendencias y drivers.
    @Published private(set) var corePhase: LoadPhase = .loading
    /// Fase de la curva de activacion horaria. Va aparte porque se consulta
    /// DESPUES del historial: sin separarla, el resto de la pantalla esperaba
    /// por ella sin necesidad.
    @Published private(set) var activationPhase: LoadPhase = .loading

    /// Quien pidio el refresco. Decide si se enseña esqueleto, y existe porque
    /// las dos situaciones se veian igual desde dentro de `refresh()`.
    enum RefreshTrigger {
        /// La vista aparecio o volvio a primer plano. Con datos ya cargados NO
        /// se esqueleta: parpadear a gris cada vez que se vuelve a Home es peor
        /// que enseñar un dato de hace un minuto.
        case automatic
        /// Pull-to-refresh o boton de actualizar. SIEMPRE esqueleta: es el
        /// acuse de recibo del gesto, y sin el la pantalla se queda quieta y
        /// parece que no paso nada.
        case userInitiated
    }

    /// Decision pura, para poder verificarla sin HealthKit.
    static func showsSkeleton(trigger: RefreshTrigger, hasData: Bool) -> Bool {
        trigger == .userInitiated || !hasData
    }

    /// Cuanto dura el esqueleto en modo demo ante un refresco pedido por el
    /// usuario. Demo no consulta nada, asi que sin esta pausa el gesto no
    /// enseñaria el estado de carga que SI existe con datos reales, y el modo
    /// demo esta justamente para enseñar el comportamiento real.
    static let demoRefreshSkeletonDuration = Duration.milliseconds(900)

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.autoupdatingCurrent
    /// Modo demo APLICADO a los datos publicados. Ya no es un `let` leido una
    /// vez: el proveedor es unico para toda la app, asi que tiene que poder
    /// cambiar de modo cuando Laboratorio alterna `useDemoData`.
    private var useDemoData: Bool
    /// nil = seguir a UserDefaults; un valor fija el modo (tests).
    private let demoOverride: Bool?
    private let trainingLoadEngine = TrainingLoadEngine()

    /// Refresco en curso. Quien pida otro mientras tanto ESPERA a este en vez
    /// de volver con las manos vacias: con un proveedor compartido, varias
    /// pantallas piden refresco a la vez al aparecer.
    private var refreshTask: Task<Void, Never>?
    private var lastHealthKitRefresh: Date?
    /// Un refresco automatico (aparecer, cambiar de pestaña) no relee Apple
    /// Health si los datos tienen menos de esto. El gesto del usuario siempre
    /// relee.
    static let automaticRefreshInterval: TimeInterval = 60

    private var wantsDemoData: Bool {
        demoOverride ?? UserDefaults.standard.bool(forKey: "useDemoData")
    }

    init(useDemoData demoOverride: Bool? = nil) {
        self.demoOverride = demoOverride
        let useDemoData = demoOverride ?? UserDefaults.standard.bool(forKey: "useDemoData")
        self.useDemoData = useDemoData
        if useDemoData {
            snapshot = .demo
            history = DailyHealthSnapshot.demoWeek
            activation = Self.demoActivation
            dataMode = .demo
            permissionState = .requested
            authorizationMessage = "Modo demo"
            // Demo trae los datos ya puestos: las fases nacen resueltas. Sin
            // esto quedaban en `.loading` hasta el primer `refresh()`, y con
            // `-skipHealthKitRefresh` (que lo salta) las tarjetas se quedaban
            // en esqueleto para siempre.
            corePhase = .ready
            activationPhase = .ready
        } else {
            snapshot = .empty
            history = []
            activation = []
            dataMode = .empty
            permissionState = HKHealthStore.isHealthDataAvailable() ? .notRequested : .unavailable
            authorizationMessage = HKHealthStore.isHealthDataAvailable() ? "Conecta Apple Health" : RecvelL10n.text("hdp.healthKitUnavailableTitle")
            // `-skipHealthKitRefresh` (tests de UI) significa que nadie va a
            // consultar nada. Las fases no pueden quedarse en `.loading` o Home
            // enseñaria el esqueleto para siempre en vez del estado vacio.
            if UserDefaults.standard.bool(forKey: "skipHealthKitRefresh") {
                corePhase = .empty
                activationPhase = .empty
            }
        }
        SharedSnapshotPublisher.publish(snapshot: snapshot, history: history, dataMode: dataMode)
    }

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isHealthDataAvailable else {
            permissionState = .unavailable
            authorizationMessage = RecvelL10n.text("hdp.healthKitUnavailable")
            return
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            permissionState = .requested
            await refresh(forceHealthKit: true)
        } catch {
            authorizationMessage = RecvelL10n.text("hdp.accessFailed")
        }
    }

    func refresh(trigger: RefreshTrigger = .automatic, forceHealthKit: Bool = false) async {
        if let inFlight = refreshTask {
            await inFlight.value
            return
        }
        if trigger == .automatic, !forceHealthKit, wantsDemoData == useDemoData, !history.isEmpty,
           let last = lastHealthKitRefresh,
           Date.now.timeIntervalSince(last) < Self.automaticRefreshInterval {
            return
        }
        // Task propia: el `.task` de una vista que desaparece no debe cancelar
        // a medias la carga que las demas pantallas estan esperando.
        let task = Task { await performRefresh(trigger: trigger, forceHealthKit: forceHealthKit) }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh(trigger: RefreshTrigger, forceHealthKit: Bool) async {
        applyDemoModeChangeIfNeeded()
        // La rama demo va ANTES de comprobar HealthKit: demo no consulta nada,
        // asi que no puede depender de que HealthKit este disponible. Con el
        // guard delante, en un dispositivo sin HealthKit el modo demo se quedaba
        // sin refrescar nunca — y el esqueleto del gesto no llegaba a pintarse.
        if useDemoData && !forceHealthKit {
            dataMode = .demo
            if trigger == .userInitiated {
                isLoading = true
                corePhase = .loading
                activationPhase = .loading
                try? await Task.sleep(for: Self.demoRefreshSkeletonDuration)
                isLoading = false
            }
            corePhase = .ready
            activationPhase = activation.isEmpty ? .empty : .ready
            return
        }

        guard isHealthDataAvailable else {
            if history.isEmpty {
                corePhase = .empty
                activationPhase = .empty
            }
            return
        }
        isLoading = true
        if Self.showsSkeleton(trigger: trigger, hasData: !history.isEmpty) {
            corePhase = .loading
            activationPhase = .loading
        }
        defer { isLoading = false }
        await updatePermissionRequestState()

        // `loadSnapshot` y todo lo que cuelga de el son `nonisolated`: las ~650
        // consultas y el procesado de muestras (FC de cada entreno incluida)
        // corren FUERA del hilo principal. Antes todo eso se ejecutaba en el
        // MainActor y trababa el arranque y el scroll mientras cargaba.
        // Los 30 dias se piden a la vez. En serie, cada dia esperaba al
        // anterior y la primera carga tardaba la suma de todos.
        let offsets = Array(stride(from: -29, through: 0, by: 1))
        var loaded: [Int: DailyHealthSnapshot] = [:]
        await withTaskGroup(of: (Int, DailyHealthSnapshot)?.self) { group in
            for offset in offsets {
                group.addTask {
                    guard let date = self.calendar.date(byAdding: .day, value: offset, to: .now) else { return nil }
                    return (offset, await self.loadSnapshot(for: date, detailedWorkouts: true))
                }
            }
            for await result in group {
                if let result { loaded[result.0] = result.1 }
            }
        }
        var days = offsets.compactMap { loaded[$0] }.filter { $0.availableSignalCount > 0 }

        guard let latest = days.last else {
            snapshot = .empty
            history = []
            activation = []
            dataMode = .empty
            corePhase = .empty
            activationPhase = .empty
            authorizationMessage = permissionState == .notRequested
                ? RecvelL10n.text("hdp.authorize")
                : RecvelL10n.text("hdp.noData")
            SharedSnapshotPublisher.publish(snapshot: snapshot, history: history, dataMode: dataMode)
            return
        }

        // Readable samples imply the user already completed Health authorization.
        // Prefer this over a stale `.notRequested` from getRequestStatus (read-only quirk).
        if permissionState == .notRequested {
            permissionState = .requested
        }

        days = applyingSleepConsistency(to: days)
        if !days.contains(where: { $0.vo2Max != nil }), let lastIndex = days.indices.last {
            let fallbackStart = calendar.date(byAdding: .day, value: -180, to: .now) ?? .distantPast
            let latestVO2 = await latestQuantity(
                .vo2Max,
                unit: HKUnit(from: "ml/kg*min"),
                start: fallbackStart,
                end: .now
            )
            if latestVO2.value != nil {
                days[lastIndex] = days[lastIndex].replacingVO2(
                    value: latestVO2.value,
                    date: latestVO2.date,
                    sourceName: latestVO2.source
                )
            }
        }
        // El nucleo se publica AQUI, antes de pedir la activacion: las tarjetas
        // de puntuaciones dejan de esperar por una consulta que no necesitan.
        snapshot = days.last ?? latest
        history = days
        corePhase = .ready

        activation = await loadActivation(restingHeartRate: snapshot.restingHeartRate)
        activationPhase = activation.isEmpty ? .empty : .ready

        if days.count < 7 {
            dataMode = .buildingBaseline
            authorizationMessage = RecvelL10n.text("hdp.baselineProgress", values: ["days": "\(days.count)"])
        } else if snapshot.availableSignalCount < 5 {
            dataMode = .partial
            authorizationMessage = RecvelL10n.text("hdp.partialData")
        } else {
            dataMode = .healthKit
            authorizationMessage = "Apple Health · \(snapshot.sourceNames.count) fuente(s)"
        }
        lastHealthKitRefresh = .now
        SharedSnapshotPublisher.publish(snapshot: snapshot, history: history, dataMode: dataMode)
    }

    /// Laboratorio alterna `useDemoData` en caliente. Con un proveedor por
    /// pantalla bastaba crear otro; con uno compartido hay que cambiar de modo
    /// aqui.
    private func applyDemoModeChangeIfNeeded() {
        let wants = wantsDemoData
        guard wants != useDemoData else { return }
        useDemoData = wants
        lastHealthKitRefresh = nil
        if wants {
            snapshot = .demo
            history = DailyHealthSnapshot.demoWeek
            activation = Self.demoActivation
            dataMode = .demo
            permissionState = .requested
            authorizationMessage = "Modo demo"
            corePhase = .ready
            activationPhase = .ready
        } else {
            snapshot = .empty
            history = []
            activation = []
            dataMode = .empty
            corePhase = .loading
            activationPhase = .loading
        }
    }

    private var readTypes: Set<HKObjectType> {
        Set([
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature),
            HKObjectType.quantityType(forIdentifier: .timeInDaylight),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .dietaryCaffeine),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .leanBodyMass),
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.categoryType(forIdentifier: .mindfulSession),
            HKObjectType.workoutType()
        ].compactMap { $0 }).union(effortReadTypes)
    }

    /// Tipos de esfuerzo de entrenamiento (iOS 18). Se añaden aparte por el
    /// gate de disponibilidad.
    private var effortReadTypes: Set<HKObjectType> {
        guard #available(iOS 18.0, *) else { return [] }
        return Set([
            HKObjectType.quantityType(forIdentifier: .workoutEffortScore),
            HKObjectType.quantityType(forIdentifier: .estimatedWorkoutEffortScore)
        ].compactMap { $0 })
    }

    private func updatePermissionRequestState() async {
        permissionState = await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status == .shouldRequest ? .notRequested : .requested)
            }
        }
    }

    nonisolated private func loadSnapshot(for date: Date, detailedWorkouts: Bool) async -> DailyHealthSnapshot {
        let start = calendar.startOfDay(for: date)
        let end = calendar.isDateInToday(date)
            ? Date.now
            : (calendar.date(byAdding: .day, value: 1, to: start) ?? date)

        let hrvResult = await averagedQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            start: start,
            end: end
        )
        let restingResult = await averagedQuantity(
            .restingHeartRate,
            unit: .count().unitDivided(by: .minute()),
            start: start,
            end: end
        )
        let respiratoryResult = await averagedQuantity(
            .respiratoryRate,
            unit: .count().unitDivided(by: .minute()),
            start: start,
            end: end
        )
        let oxygenResult = await averagedQuantity(
            .oxygenSaturation,
            unit: .percent(),
            start: start,
            end: end
        )
        // Temperatura de muneca: Apple solo la registra durante el sueno.
        let wristTemperatureResult = await averagedQuantity(
            .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            start: start,
            end: end
        )
        let vo2Result = await latestQuantity(
            .vo2Max,
            unit: HKUnit(from: "ml/kg*min"),
            start: start,
            end: end
        )
        let energy = await cumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        let stepValue = await cumulativeQuantity(.stepCount, unit: .count(), start: start, end: end)
        let daylight = await cumulativeQuantity(.timeInDaylight, unit: .minute(), start: start, end: end)
        let water = await cumulativeQuantity(.dietaryWater, unit: .liter(), start: start, end: end)
        let caffeine = await cumulativeQuantity(.dietaryCaffeine, unit: .gramUnit(with: .milli), start: start, end: end)
        let mindful = await categoryDuration(.mindfulSession, start: start, end: end)
        let bodyMass = await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo), start: start, end: end)
        let bodyFat = await latestQuantity(.bodyFatPercentage, unit: .percent(), start: start, end: end)
        let leanMass = await latestQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo), start: start, end: end)
        let systolic = await latestQuantity(
            .bloodPressureSystolic,
            unit: .millimeterOfMercury(),
            start: start,
            end: end
        )
        let diastolic = await latestQuantity(
            .bloodPressureDiastolic,
            unit: .millimeterOfMercury(),
            start: start,
            end: end
        )
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: start) ?? end
        let sleep = await sleepSummary(start: sleepStart, end: min(sleepEnd, .now))
        let workouts = await loadWorkouts(
            start: start,
            end: end,
            restingHeartRate: restingResult.value,
            detailed: detailedWorkouts
        )

        let sources = Set(
            [hrvResult.source, restingResult.source, respiratoryResult.source, oxygenResult.source, wristTemperatureResult.source, vo2Result.source, bodyMass.source, bodyFat.source, leanMass.source, sleep?.sourceName]
                .compactMap { $0 } + workouts.map(\.sourceName)
        ).sorted()
        var issues: Set<DataQualityIssue> = []
        if calendar.isDateInToday(date) { issues.insert(.partialDay) }
        if sources.count > 1 { issues.insert(.mixedSources) }
        if let sleep, !sleep.hasStages { issues.insert(.missingSleepStages) }

        return DailyHealthSnapshot(
            date: start,
            hrv: hrvResult.value,
            restingHeartRate: restingResult.value,
            sleepHours: sleep.map { $0.asleepHours + $0.napHours },
            activeEnergy: energy,
            steps: stepValue.map { Int($0.rounded()) },
            respiratoryRate: respiratoryResult.value,
            workoutMinutes: workouts.isEmpty ? nil : workouts.reduce(0) { $0 + $1.durationMinutes },
            vo2Max: vo2Result.value,
            vo2MaxDate: vo2Result.date,
            oxygenSaturation: oxygenResult.value,
            wristTemperature: wristTemperatureResult.value,
            daylightMinutes: daylight,
            mindfulMinutes: mindful,
            dietaryWaterLiters: water,
            dietaryCaffeineMg: caffeine,
            dietaryAlcoholGrams: nil,
            bodyMassKg: bodyMass.value,
            bodyFatPercentage: bodyFat.value,
            leanBodyMassKg: leanMass.value,
            systolicBloodPressure: systolic.value,
            diastolicBloodPressure: diastolic.value,
            sleepDetails: sleep,
            workouts: workouts,
            sourceNames: sources,
            qualityIssues: issues,
            timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )
    }

    nonisolated private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier), start < end else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    nonisolated private func averagedQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> (value: Double?, source: String?) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier), start < end else { return (nil, nil) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKQuantitySample] = await sampleQuery(type: type, predicate: predicate)
        let preferred = preferredQuantitySamples(samples)
        guard !preferred.isEmpty else { return (nil, nil) }
        let value = preferred.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) } / Double(preferred.count)
        return (value, preferred.first?.sourceRevision.source.name)
    }

    nonisolated private func categoryDuration(
        _ identifier: HKCategoryTypeIdentifier,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier), start < end else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = await sampleQuery(type: type, predicate: predicate)
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60
    }

    nonisolated private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> (value: Double?, date: Date?, source: String?) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier), start < end else {
            return (nil, nil, nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKQuantitySample] = await sampleQuery(type: type, predicate: predicate)
        guard let latest = preferredQuantitySamples(samples).max(by: { $0.startDate < $1.startDate }) else {
            return (nil, nil, nil)
        }
        return (
            latest.quantity.doubleValue(for: unit),
            latest.startDate,
            latest.sourceRevision.source.name
        )
    }

    nonisolated private func sleepSummary(start: Date, end: Date) async -> SleepSummary? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis), start < end else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = await sampleQuery(type: type, predicate: predicate)
        let preferred = preferredCategorySamples(samples)
        guard !preferred.isEmpty else { return nil }

        let napSamples = preferred.filter { sample in
            let hour = calendar.component(.hour, from: sample.startDate)
            return (10..<20).contains(hour)
                && sample.endDate.timeIntervalSince(sample.startDate) <= 3 * 3600
                && isAsleep(sample.value)
        }
        let main = preferred.filter { sample in !napSamples.contains(where: { $0.uuid == sample.uuid }) }
        let stageSamples = main.filter { isAsleep($0.value) || $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }
        guard let first = stageSamples.map({ $0.startDate }).min(),
              let last = stageSamples.map({ $0.endDate }).max() else { return nil }

        let core = unionHours(main.filter { $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue })
        let deep = unionHours(main.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue })
        let rem = unionHours(main.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue })
        let unspecified = unionHours(main.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue })
        let awake = unionHours(main.filter { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue })
        let asleep = core + deep + rem + unspecified
        let inBedSamples = main.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        let inBed = max(unionHours(inBedSamples), last.timeIntervalSince(first) / 3600)
        let napHours = unionHours(napSamples)
        let inBedStart = inBedSamples.map { $0.startDate }.min() ?? first
        let firstAsleep = main.filter { isAsleep($0.value) }.map { $0.startDate }.min()
        let latency = firstAsleep.map { max($0.timeIntervalSince(inBedStart) / 60, 0) }

        return SleepSummary(
            // Inicio real dormido cuando HealthKit aporta etapas; no confundir
            // el primer intervalo despierto/en cama con inicio de sueno.
            startDate: firstAsleep ?? first,
            endDate: last,
            inBedHours: inBed,
            asleepHours: asleep,
            coreHours: core,
            deepHours: deep,
            remHours: rem,
            awakeHours: awake,
            unspecifiedHours: unspecified,
            napHours: napHours,
            latencyMinutes: latency,
            consistencyMinutes: nil,
            sourceName: preferred.first?.sourceRevision.source.name ?? "Apple Health"
        )
    }

    nonisolated private func loadWorkouts(
        start: Date,
        end: Date,
        restingHeartRate: Double?,
        detailed: Bool
    ) async -> [WorkoutSummary] {
        let type = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let workouts: [HKWorkout] = await sampleQuery(type: type, predicate: predicate)
        var summaries: [WorkoutSummary] = []

        for workout in workouts.sorted(by: { $0.startDate > $1.startDate }) {
            var observations: [HeartRateObservation] = []
            var heartRateRecovery: Double?
            if detailed, let heartType = HKObjectType.quantityType(forIdentifier: .heartRate) {
                let heartPredicate = HKQuery.predicateForSamples(
                    withStart: workout.startDate,
                    end: workout.endDate.addingTimeInterval(100),
                    options: .strictStartDate
                )
                let samples: [HKQuantitySample] = await sampleQuery(type: heartType, predicate: heartPredicate)
                let sameSource = samples.filter {
                    $0.sourceRevision.source.bundleIdentifier == workout.sourceRevision.source.bundleIdentifier
                }
                let selected = sameSource.isEmpty ? preferredQuantitySamples(samples) : sameSource
                let unit = HKUnit.count().unitDivided(by: .minute())
                let workoutSamples = selected.filter { $0.startDate <= workout.endDate }
                observations = workoutSamples.map {
                    HeartRateObservation(date: $0.startDate, beatsPerMinute: $0.quantity.doubleValue(for: unit))
                }

                let endRate = workoutSamples
                    .filter { $0.startDate >= workout.endDate.addingTimeInterval(-45) }
                    .last?
                    .quantity.doubleValue(for: unit) ?? workoutSamples.last?.quantity.doubleValue(for: unit)
                let oneMinuteRate = selected
                    .filter {
                        $0.startDate >= workout.endDate.addingTimeInterval(45) &&
                        $0.startDate <= workout.endDate.addingTimeInterval(90)
                    }
                    .min(by: {
                        abs($0.startDate.timeIntervalSince(workout.endDate.addingTimeInterval(60))) <
                        abs($1.startDate.timeIntervalSince(workout.endDate.addingTimeInterval(60)))
                    })?
                    .quantity.doubleValue(for: unit)
                if let endRate, let oneMinuteRate, endRate > oneMinuteRate {
                    heartRateRecovery = endRate - oneMinuteRate
                }
            }

            let average = observations.isEmpty ? nil : observations.reduce(0) { $0 + $1.beatsPerMinute } / Double(observations.count)
            let maximum = observations.map(\.beatsPerMinute).max()
            let estimatedMaximum = max((maximum ?? 175) * 1.03, 180)
            let zones = trainingLoadEngine.zones(observations: observations, estimatedMaximumHeartRate: estimatedMaximum)
            let load = trainingLoadEngine.cardiovascularLoad(zones: zones)
            let effort = await workoutEffort(for: workout)

            summaries.append(
                WorkoutSummary(
                    id: workout.uuid,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    activityName: workoutName(workout.workoutActivityType),
                    durationMinutes: workout.duration / 60,
                    activeEnergy: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                    averageHeartRate: average,
                    maximumHeartRate: maximum,
                    heartRateRecoveryOneMinute: heartRateRecovery,
                    zones: zones,
                    cardiovascularLoad: load,
                    sourceName: workout.sourceRevision.source.name,
                    effortScore: effort?.score,
                    effortIsEstimated: effort?.isEstimated ?? false
                )
            )
        }
        return summaries
    }

    /// Lee el esfuerzo (HKWorkoutEffortScore, iOS 18) asociado a un workout.
    /// Prefiere el manual del usuario sobre el estimado por Apple. Devuelve
    /// `nil` en iOS<18 o cuando no hay muestra.
    nonisolated private func workoutEffort(for workout: HKWorkout) async -> (score: Double, isEstimated: Bool)? {
        guard #available(iOS 18.0, *) else { return nil }
        let manual = await effortSample(for: workout, identifier: .workoutEffortScore)
        if let manual { return (manual, false) }
        if let estimated = await effortSample(for: workout, identifier: .estimatedWorkoutEffortScore) {
            return (estimated, true)
        }
        return nil
    }

    @available(iOS 18.0, *)
    nonisolated private func effortSample(for workout: HKWorkout, identifier: HKQuantityTypeIdentifier) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let samples: [HKQuantitySample] = await sampleQuery(type: type, predicate: predicate)
        // La escala de effort es adimensional (appleEffortScore 0-10).
        return samples.last?.quantity.doubleValue(for: .appleEffortScore())
    }

    nonisolated private func loadActivation(restingHeartRate: Double?) async -> [ActivationPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let start = Date.now.addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let samples: [HKQuantitySample] = await sampleQuery(type: type, predicate: predicate)
        let preferred = preferredQuantitySamples(samples)
        guard !preferred.isEmpty else { return [] }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let grouped = Dictionary(grouping: preferred) {
            calendar.dateInterval(of: .hour, for: $0.startDate)?.start ?? $0.startDate
        }
        let resting = restingHeartRate ?? 58
        return grouped.keys.sorted().compactMap { hour in
            guard let values = grouped[hour], !values.isEmpty else { return nil }
            let average = values.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) } / Double(values.count)
            return ActivationPoint(date: hour, value: min(max((average - resting) / 30, 0.08), 3))
        }
    }

    nonisolated private func sampleQuery<T: HKSample>(type: HKSampleType, predicate: NSPredicate) async -> [T] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [T] ?? [])
            }
            healthStore.execute(query)
        }
    }

    nonisolated private func preferredQuantitySamples(_ samples: [HKQuantitySample]) -> [HKQuantitySample] {
        preferredSamples(samples)
    }

    nonisolated private func preferredCategorySamples(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        preferredSamples(samples)
    }

    nonisolated private func preferredSamples<T: HKSample>(_ samples: [T]) -> [T] {
        guard !samples.isEmpty else { return [] }
        let groups = Dictionary(grouping: samples) { $0.sourceRevision.source.bundleIdentifier }
        let best = groups.max { lhs, rhs in
            sourcePriority(lhs.value) < sourcePriority(rhs.value)
        }
        return best?.value ?? samples
    }

    nonisolated private func sourcePriority<T: HKSample>(_ samples: [T]) -> Int {
        guard let sample = samples.first else { return 0 }
        let product = sample.sourceRevision.productType?.lowercased() ?? ""
        let name = sample.sourceRevision.source.name.lowercased()
        let deviceScore = product.contains("watch") || name.contains("watch") ? 10_000 : 0
        return deviceScore + samples.count
    }

    nonisolated private func unionHours<T: HKSample>(_ samples: [T]) -> Double {
        let intervals = samples
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            .sorted { $0.start < $1.start }
        guard var current = intervals.first else { return 0 }
        var seconds = 0.0
        for interval in intervals.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                seconds += current.duration
                current = interval
            }
        }
        seconds += current.duration
        return seconds / 3600
    }

    nonisolated private func isAsleep(_ value: Int) -> Bool {
        [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ].contains(value)
    }

    private func applyingSleepConsistency(to days: [DailyHealthSnapshot]) -> [DailyHealthSnapshot] {
        let details = days.compactMap(\.sleepDetails)
        guard details.count >= 3 else { return days }
        let bedtimes = details.map { normalizedMinutes($0.startDate) }
        let wakeTimes = details.map { normalizedMinutes($0.endDate) }
        let baseline = BaselineEngine()
        guard let bedMedian = baseline.median(bedtimes), let wakeMedian = baseline.median(wakeTimes) else { return days }

        return days.map { day in
            guard let sleep = day.sleepDetails else { return day }
            let consistency = (abs(normalizedMinutes(sleep.startDate) - bedMedian)
                               + abs(normalizedMinutes(sleep.endDate) - wakeMedian)) / 2
            return day.replacingSleepDetails(sleep.withConsistency(consistency))
        }
    }

    nonisolated private func normalizedMinutes(_ date: Date) -> Double {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let value = Double(hour * 60 + minute)
        return value < 12 * 60 ? value + 24 * 60 : value
    }

    /// Nombre visible del tipo de entrenamiento, en el idioma de la app.
    /// Estaba escrito solo en español y se colaba tal cual en la UI inglesa.
    nonisolated private func workoutName(_ type: HKWorkoutActivityType) -> String {
        let key = switch type {
        case .running: "workout.type.running"
        case .walking: "workout.type.walking"
        case .cycling: "workout.type.cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "workout.type.strength"
        case .highIntensityIntervalTraining: "workout.type.hiit"
        case .yoga: "workout.type.yoga"
        case .swimming: "workout.type.swimming"
        case .rowing: "workout.type.rowing"
        case .hiking: "workout.type.hiking"
        default: "workout.type.generic"
        }
        return RecvelL10n.text(key)
    }

    private static var demoActivation: [ActivationPoint] {
        let calendar = Calendar.current
        let values = [0.35, 0.28, 0.22, 0.30, 0.55, 0.82, 1.15, 0.76, 1.42, 2.18, 1.38, 0.92]
        return values.enumerated().map { index, value in
            ActivationPoint(
                date: calendar.date(byAdding: .hour, value: index * 2 - 22, to: .now) ?? .now,
                value: value
            )
        }
    }
}
