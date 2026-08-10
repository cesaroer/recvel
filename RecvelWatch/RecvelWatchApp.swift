import HealthKit
import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct RecvelWatchApp: App {
    @StateObject private var sync = WatchSnapshotReceiver()
    @StateObject private var workout = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sync)
                .environmentObject(workout)
                .environment(\.locale, Locale(identifier: sync.snapshot.displayLanguage.localeIdentifier))
                .id(sync.snapshot.displayLanguage)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class WatchSnapshotReceiver: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot = RecvelSharedSnapshotStore.load()
    @Published private(set) var connectionLabel = RecvelL10n.text("common.local", language: RecvelLanguageStore.load())

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestRefresh() {
        guard WCSession.default.isReachable else {
            connectionLabel = RecvelL10n.text("watch.openPhone", language: snapshot.displayLanguage)
            return
        }
        WCSession.default.sendMessage(["requestSnapshot": true], replyHandler: { [weak self] reply in
            guard let data = reply["healthSnapshot"] as? Data else { return }
            Task { @MainActor in self?.accept(data) }
        }) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.connectionLabel = RecvelL10n.text("watch.noConnection", language: self.snapshot.displayLanguage)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            connectionLabel = error == nil
                ? RecvelL10n.text("Sincronizado", language: snapshot.displayLanguage)
                : RecvelL10n.text("watch.noConnection", language: snapshot.displayLanguage)
            if activationState == .activated { requestRefresh() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["healthSnapshot"] as? Data else { return }
        Task { @MainActor in accept(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["healthSnapshot"] as? Data else { return }
        Task { @MainActor in accept(data) }
    }

    private func accept(_ data: Data) {
        guard let newSnapshot = RecvelSharedSnapshotStore.decoded(data) else { return }
        snapshot = newSnapshot
        RecvelLanguageStore.save(newSnapshot.displayLanguage)
        connectionLabel = RecvelL10n.text("Actualizado", language: newSnapshot.displayLanguage)
        RecvelSharedSnapshotStore.save(newSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var sync: WatchSnapshotReceiver
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        Group {
            if workout.isActive {
                ActiveWorkoutView()
            } else {
                TabView {
                    WatchReadinessView()
                    WatchMetricsView()
                    WatchWorkoutLauncherView()
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .tint(WatchPalette.recovery)
    }
}

private enum WatchPalette {
    static let recovery = Color(red: 0.20, green: 0.83, blue: 0.60)
    static let strain = Color(red: 0.98, green: 0.57, blue: 0.24)
    static let sleep = Color(red: 0.66, green: 0.33, blue: 0.97)
    static let energy = Color(red: 0.98, green: 0.75, blue: 0.14)
}

private struct WatchScoreRing: View {
    let title: String
    let value: Int?
    let color: Color
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: Double(value ?? 0) / 100)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value.map(String.init) ?? "--")
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(width: size, height: size)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct WatchReadinessView: View {
    @EnvironmentObject private var sync: WatchSnapshotReceiver

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("watch.today")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(WatchPalette.recovery)
                        Text("watch.status").font(.headline)
                    }
                    Spacer()
                    Button(action: sync.requestRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
                WatchScoreRing(title: RecvelL10n.text("score.recovery.title", language: sync.snapshot.displayLanguage), value: sync.snapshot.recovery, color: WatchPalette.recovery, size: 88)
                HStack(spacing: 18) {
                    mini(RecvelL10n.text("score.sleep.title", language: sync.snapshot.displayLanguage), sync.snapshot.sleep, WatchPalette.sleep)
                    mini(RecvelL10n.text("score.load.title", language: sync.snapshot.displayLanguage), sync.snapshot.strain, WatchPalette.strain)
                    mini(RecvelL10n.text("score.energy.title", language: sync.snapshot.displayLanguage), sync.snapshot.energy, WatchPalette.energy)
                }
                Text(sync.snapshot.nextAction)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(sync.snapshot.updatedAt, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func mini(_ title: String, _ value: Int?, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value.map(String.init) ?? "--")
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

private struct WatchMetricsView: View {
    @EnvironmentObject private var sync: WatchSnapshotReceiver

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("watch.signals").font(.headline)
                metric(RecvelL10n.text("score.stress.title", language: sync.snapshot.displayLanguage), sync.snapshot.stressScore.map { "\($0) · \(sync.snapshot.stressLabel)" } ?? RecvelL10n.text("common.calibrating", language: sync.snapshot.displayLanguage), "waveform.path.ecg", .cyan)
                metric("HRV", sync.snapshot.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "--", "heart.text.square", WatchPalette.recovery)
                metric(RecvelL10n.text("term.rhr.name", language: sync.snapshot.displayLanguage), sync.snapshot.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--", "heart.fill", .pink)
                metric(RecvelL10n.text("score.sleep.title", language: sync.snapshot.displayLanguage), sync.snapshot.sleepHours.map { String(format: "%.1f h", $0) } ?? "--", "moon.fill", WatchPalette.sleep)
                metric(RecvelL10n.text("metric.steps", language: sync.snapshot.displayLanguage), sync.snapshot.steps?.formatted(.number.locale(Locale(identifier: sync.snapshot.displayLanguage.localeIdentifier))) ?? "--", "figure.walk", .cyan)
                metric("VO₂ máx.", sync.snapshot.vo2Max.map { String(format: "%.1f", $0) } ?? "--", "lungs.fill", .blue)
            }
            .padding(.horizontal, 4)
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct WatchWorkoutLauncherView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("watch.train").font(.headline)
                workoutButton("Correr", "figure.run", .running)
                workoutButton("Caminar", "figure.walk", .walking)
                workoutButton("Ciclismo", "bicycle", .cycling)
                workoutButton("Fuerza", "dumbbell.fill", .traditionalStrengthTraining)
                Text("watch.workout.detail")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .task { await workout.requestAuthorization() }
    }

    private func workoutButton(_ title: String, _ icon: String, _ type: HKWorkoutActivityType) -> some View {
        Button {
            workout.start(type)
        } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(WatchPalette.recovery)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.08))
    }
}

private struct ActiveWorkoutView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Label(workout.activityTitle, systemImage: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchPalette.recovery)
                    Spacer()
                    TimelineView(.periodic(from: workout.startDate ?? .now, by: 1)) { context in
                        Text(elapsed(at: context.date)).font(.caption.monospacedDigit())
                    }
                }
                Text("\(Int(workout.heartRate.rounded()))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.pink)
                    .contentTransition(.numericText())
                Text("BPM").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                HStack {
                    liveMetric("Energia", "\(Int(workout.activeEnergy.rounded()))", "kcal")
                    liveMetric("Distancia", String(format: "%.2f", workout.distanceMeters / 1_000), "km")
                }
                Button(role: .destructive) { workout.stop() } label: {
                    Label("watch.finish", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 4)
        }
    }

    private func liveMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
            Text(unit).font(.system(size: 8)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func elapsed(at date: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(workout.startDate ?? date)), 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var heartRate = 0.0
    @Published private(set) var activeEnergy = 0.0
    @Published private(set) var distanceMeters = 0.0
    @Published private(set) var startDate: Date?
    @Published private(set) var activityTitle = RecvelL10n.text("tab.training", language: RecvelLanguageStore.load())

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let workout = HKObjectType.workoutType()
        let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let read = Set([heartRate, energy, workout] + (distance.map { [$0] } ?? []))
        try? await healthStore.requestAuthorization(toShare: [workout], read: read)
    }

    func start(_ type: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type
        configuration.locationType = type == .traditionalStrengthTraining ? .indoor : .outdoor
        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            newSession.delegate = self
            newBuilder.delegate = self
            session = newSession
            builder = newBuilder
            startDate = .now
            activityTitle = Self.title(for: type)
            heartRate = 0
            activeEnergy = 0
            distanceMeters = 0
            isActive = true
            newSession.startActivity(with: startDate!)
            newBuilder.beginCollection(withStart: startDate!) { _, _ in }
        } catch {
            isActive = false
        }
    }

    func stop() {
        session?.end()
    }

    private static func title(for type: HKWorkoutActivityType) -> String {
        let language = RecvelLanguageStore.load()
        switch type {
        case .running: return RecvelL10n.text("Carrera", language: language)
        case .walking: return RecvelL10n.text("Caminata", language: language)
        case .cycling: return RecvelL10n.text("Ciclismo", language: language)
        case .traditionalStrengthTraining: return RecvelL10n.text("Fuerza", language: language)
        default: return RecvelL10n.text("tab.training", language: language)
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        Task { @MainActor in
            if let currentBuilder = builder {
                try? await currentBuilder.endCollection(at: date)
                _ = try? await currentBuilder.finishWorkout()
            }
            isActive = false
            builder = nil
            session = nil
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in isActive = false }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType,
                      let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
                switch quantityType.identifier {
                case HKQuantityTypeIdentifier.heartRate.rawValue:
                    heartRate = statistics.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? heartRate
                case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                    activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeEnergy
                case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
                    distanceMeters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? distanceMeters
                default:
                    break
                }
            }
        }
    }
}
