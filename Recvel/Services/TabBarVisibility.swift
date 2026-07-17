import SwiftUI
import Observation
import UIKit

/// Controls the custom floating tab bar.
///
/// Mirrors iOS 26 Liquid Glass `tabBarMinimizeBehavior(.onScrollDown)`:
/// scroll down → **minimize**, intentional scroll up (or near top) → **expand**.
/// Uses accumulated delta + cooldown so rubber-banding / jitter cannot flicker
/// the bar open after a collapse.
@Observable
final class TabBarVisibility {
    enum Mode: Equatable {
        case expanded
        case minimized
        case hidden
    }

    private(set) var mode: Mode = .expanded

    var isExpanded: Bool { mode == .expanded }
    var isMinimized: Bool { mode == .minimized }
    var isHidden: Bool { mode == .hidden }

    /// Opens Settings from the global quick-action FAB (Dashboard observes this).
    var wantsSettings = false

    /// Opens Plan detail from the FAB (Dashboard observes this).
    var wantsPlan = false

    /// Switches to the Fitness tab (Home weekly workouts / FAB).
    var wantsFitnessTab = false

    /// Active tab selection — tabs observe this to refresh when returning (views stay mounted).
    var selectedTab: AppTab = .today

    /// Marks the bar as hidden because a detail view is on screen.
    var isHiddenByDetail: Bool = false {
        didSet {
            if isHiddenByDetail {
                mode = .hidden
            } else if mode == .hidden {
                mode = .expanded
            }
        }
    }

    private var lastContentOffset: CGFloat = 0
    private var accumulatedDelta: CGFloat = 0
    private var lockModeUntil: CFAbsoluteTime = 0
    private var hasSeededOffset = false
    /// Mientras el teclado esta arriba, ignoramos scroll (evita lag en TextFields).
    private(set) var isKeyboardVisible = false

    func setKeyboardVisible(_ visible: Bool) {
        guard isKeyboardVisible != visible else { return }
        isKeyboardVisible = visible
        if visible {
            accumulatedDelta = 0
        } else {
            // Reseed al cerrar para no interpretar el salto de inset como gesto.
            hasSeededOffset = false
            accumulatedDelta = 0
        }
    }

    /// Called by `onScrollGeometryChange` with the latest `contentOffset.y`.
    func onScrollOffsetChange(_ offset: CGFloat) {
        guard !isHiddenByDetail else { return }
        guard !isKeyboardVisible else { return }

        // First sample after appear / tab switch — seed only, don't treat as a gesture.
        if !hasSeededOffset {
            hasSeededOffset = true
            lastContentOffset = offset
            accumulatedDelta = 0
            return
        }

        let delta = offset - lastContentOffset
        lastContentOffset = offset

        // Near the top is the only place we always expand (native snap-back).
        if offset <= 8 {
            accumulatedDelta = 0
            apply(.expanded)
            return
        }

        // Layout jumps / rubber-band snaps — ignore and reset accumulator.
        if abs(delta) > 64 {
            accumulatedDelta = 0
            return
        }

        // Ignore sub-pixel / touch noise.
        if abs(delta) < 1.2 { return }

        // Direction change resets intent (native bars need a clear swipe).
        if (accumulatedDelta > 0 && delta < 0) || (accumulatedDelta < 0 && delta > 0) {
            accumulatedDelta = 0
        }
        accumulatedDelta += delta

        // Cooldown after a mode change prevents expand↔collapse flicker mid-gesture.
        if CFAbsoluteTimeGetCurrent() < lockModeUntil { return }

        // Minimize: modest downward intent once past the top.
        if accumulatedDelta >= 28, mode == .expanded {
            accumulatedDelta = 0
            apply(.minimized, lock: 0.40)
            return
        }

        // Expand: stronger upward intent so small corrections while collapsed stay collapsed.
        // Also require being meaningfully away from the absolute bottom bounce zone is hard
        // without contentSize; the higher threshold is the main guard.
        if accumulatedDelta <= -48, mode == .minimized {
            accumulatedDelta = 0
            apply(.expanded, lock: 0.40)
        }
    }

    @available(iOS 18.0, *)
    func onScrollPhaseChange(_ phase: ScrollPhase) {
        guard !isHiddenByDetail else { return }
        guard !isKeyboardVisible else { return }
        // Only snap-expand at rest when truly at the top — never while mid-list.
        if phase == .idle {
            accumulatedDelta = 0
            if lastContentOffset <= 8 {
                apply(.expanded)
            }
        }
    }

    func expand() {
        guard !isHiddenByDetail else { return }
        accumulatedDelta = 0
        apply(.expanded, lock: 0.25)
    }

    /// Light reset when switching tabs — keeps chrome mode, only reseeds scroll tracking.
    func noteTabChange() {
        lastContentOffset = 0
        accumulatedDelta = 0
        hasSeededOffset = false
        lockModeUntil = 0
    }

    func reset() {
        lastContentOffset = 0
        accumulatedDelta = 0
        hasSeededOffset = false
        lockModeUntil = 0
        if !isHiddenByDetail { mode = .expanded }
    }

    func openSettings() {
        wantsSettings = true
    }

    func openPlan() {
        wantsPlan = true
    }

    func openFitnessTab() {
        wantsFitnessTab = true
    }

    private func apply(_ newMode: Mode, lock: CFTimeInterval = 0) {
        guard mode != newMode else { return }
        mode = newMode
        if lock > 0 {
            lockModeUntil = CFAbsoluteTimeGetCurrent() + lock
        }
    }
}

extension EnvironmentValues {
    private struct TabBarVisibilityKey: EnvironmentKey {
        static let defaultValue = TabBarVisibility()
    }

    var tabBarVisibility: TabBarVisibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

extension View {
    /// Hides the custom floating tab bar while this view is on screen (detail views).
    func hidesTabBar() -> some View {
        modifier(HidesTabBarModifier())
    }

    /// Drives minimize/expand from the nearest scroll view.
    /// iOS 18+ uses `onScrollGeometryChange`; iOS 17 keeps the bar expanded while scrolling.
    func trackTabBarScroll() -> some View {
        modifier(TabBarScrollTracker())
    }
}

private struct HidesTabBarModifier: ViewModifier {
    @Environment(TabBarVisibility.self) private var visibility

    func body(content: Content) -> some View {
        content
            .onAppear {
                visibility.isHiddenByDetail = true
                visibility.reset()
            }
            .onDisappear {
                visibility.isHiddenByDetail = false
                visibility.reset()
            }
    }
}

private struct TabBarScrollTracker: ViewModifier {
    @Environment(TabBarVisibility.self) private var visibility

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onAppear { visibility.reset() }
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newValue in
                    visibility.onScrollOffsetChange(newValue)
                }
                .onScrollPhaseChange { _, newPhase in
                    visibility.onScrollPhaseChange(newPhase)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    visibility.setKeyboardVisible(true)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    visibility.setKeyboardVisible(false)
                }
        } else {
            content
                .onAppear { visibility.reset() }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    visibility.setKeyboardVisible(true)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    visibility.setKeyboardVisible(false)
                }
        }
    }
}
