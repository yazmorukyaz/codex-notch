import CodexNotchCore
import Foundation
import Observation
import SwiftUI

enum NotchSurface: Sendable {
    case compact
    case dashboard
    case settings
}

struct CompletionCelebrationEvent: Sendable, Equatable {
    let id: Int
    let completedCount: Int
    let remainingActiveCount: Int
    let projectSummary: String
}

@Observable
@MainActor
final class AppRuntime {
    let store: DashboardStore
    let isDemoMode: Bool

    private(set) var surface: NotchSurface
    private(set) var notificationPermissionDenied = false
    private(set) var compactPresence: CompactPanelPresence = .dormant
    private(set) var completionCelebration: CompletionCelebrationEvent?

    @ObservationIgnored
    private let repository: CodexLocalRepository?

    @ObservationIgnored
    private let notifications: NotificationCoordinator

    @ObservationIgnored
    private let isCodexFrontmost: @MainActor () -> Bool

    @ObservationIgnored
    private var panelCoordinator: PanelCoordinator?

    @ObservationIgnored
    private var completionOverlayCoordinator: CompletionOverlayCoordinator?

    @ObservationIgnored
    private let compactPresencePolicy = CompactPanelPresencePolicy()

    @ObservationIgnored
    private let completionFeedbackPolicy = CompletionFeedbackPolicy()

    @ObservationIgnored
    private var completionExpiryTask: Task<Void, Never>?

    @ObservationIgnored
    private var celebrationDismissTask: Task<Void, Never>?

    @ObservationIgnored
    private var nextCelebrationID = 0

    @ObservationIgnored
    private var isRunning = false

    @ObservationIgnored
    private let restingCompactBodyHeight: CGFloat = 18

    @ObservationIgnored
    private let attentionCompactBodyHeight: CGFloat = 54

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        isCodexFrontmost: @escaping @MainActor () -> Bool = {
            CodexApplicationDetector.isCodexFrontmost()
        }
    ) {
        let dashboardDemoMode = arguments.contains("--demo")
        let settingsDemoMode = arguments.contains("--demo-settings")
        let idleDemoMode = arguments.contains("--demo-idle")
        let attentionDemoMode = arguments.contains("--demo-attention")
        let celebrationDemoMode = arguments.contains("--demo-celebration")
            || arguments.contains("--demo-screen-celebration")
            || arguments.contains("--smoke-test-screen-celebration")
        self.isDemoMode = dashboardDemoMode
            || settingsDemoMode
            || idleDemoMode
            || attentionDemoMode
            || celebrationDemoMode
        self.surface = settingsDemoMode
            ? .settings
            : (dashboardDemoMode ? .dashboard : .compact)
        self.notifications = NotificationCoordinator()
        self.isCodexFrontmost = isCodexFrontmost

        if dashboardDemoMode || settingsDemoMode || attentionDemoMode {
            self.repository = nil
            self.store = DashboardStore.demo()
        } else if celebrationDemoMode {
            self.repository = nil
            self.store = DashboardStore.completionDemo()
        } else if idleDemoMode {
            self.repository = nil
            self.store = DashboardStore {
                DashboardSnapshot.empty()
            }
        } else {
            let repository = CodexLocalRepository(recentThreadLimit: 12)
            self.repository = repository
            self.store = DashboardStore {
                await repository.snapshot()
            }
        }

        let notificationCoordinator = notifications
        store.onRecentTransition = { [weak self, weak notificationCoordinator] transition in
            guard let self, self.store.notificationsEnabled else { return }
            Task { @MainActor in
                await notificationCoordinator?.deliverTransition(
                    for: transition.task,
                    privacyMode: self.store.privacyMode
                )
            }
        }
        store.onCompletion = { [weak self] batch in
            self?.presentCompletionCelebration(for: batch)
        }
        store.onOpenTask = { task in
            CodexHandoff.open(threadID: task.id)
        }
        store.onRefreshSettled = { [weak self] in
            self?.reconcileCompactPresence()
        }
    }

    var summaryText: String {
        let active = store.activeTaskCount
        let attention = store.needsAttentionCount
        if attention > 0 {
            return "\(active) active · \(attention) need you"
        }
        if active == 0, store.unverifiedTaskCount > 0 {
            return store.unverifiedTaskCount == 1
                ? "1 recently active task · status unverified"
                : "\(store.unverifiedTaskCount) recently active tasks · status unverified"
        }
        if active == 0, store.staleTaskCount > 0 {
            return store.staleTaskCount == 1
                ? "1 task with no recent activity"
                : "\(store.staleTaskCount) tasks with no recent activity"
        }
        return active == 1 ? "1 active task" : "\(active) active tasks"
    }

    func start() {
        isRunning = true
        configurePanelIfNeeded()
        configureCompletionOverlayIfNeeded()
        store.startPolling()

        switch surface {
        case .dashboard:
            showDashboard(animated: false)
        case .compact:
            showCompact(animated: false)
        case .settings:
            showSettings()
        }
    }

    func stop() {
        isRunning = false
        completionExpiryTask?.cancel()
        completionExpiryTask = nil
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        completionCelebration = nil
        completionOverlayCoordinator?.dismiss()
        store.stopPolling()
        panelCoordinator?.hide()
    }

    func showCompact(animated: Bool = true) {
        surface = .compact
        reconcileCompactPresence(animated: animated)
    }

    func showDashboard(animated: Bool = true) {
        surface = .dashboard
        panelCoordinator?.showExpanded(animated: animated)
    }

    func showSettings() {
        surface = .settings
        panelCoordinator?.showExpanded()
    }

    func dismissSettings() {
        surface = .dashboard
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        guard enabled else {
            store.setNotificationsEnabled(false)
            notificationPermissionDenied = false
            return
        }

        Task {
            let granted = await notifications.requestAuthorization()
            store.setNotificationsEnabled(granted)
            notificationPermissionDenied = !granted
        }
    }

    func previewCompletionFeedback() {
        let presentation = completionFeedbackPolicy.resolve(
            effect: store.completionEffect,
            codexActiveBehavior: .keepSelectedEffect,
            isCodexActive: false
        )
        guard presentation != .hidden else { return }

        presentCompletionFeedback(
            completedCount: 1,
            remainingActiveCount: store.activeTaskCount,
            projectSummary: CompletionProjectSummary.text(
                for: ["Codex Notch"],
                privacyMode: store.privacyMode
            ),
            presentation: presentation
        )
    }

    /// Receives an intrinsic body height from the currently visible expanded
    /// surface. The surface identity prevents a disappearing view from resizing
    /// the panel after navigation has already moved elsewhere.
    func updateExpandedBodyHeight(
        _ height: CGFloat,
        for reportingSurface: NotchSurface,
        animated: Bool = true
    ) {
        guard reportingSurface == surface,
              reportingSurface != .compact else {
            return
        }
        panelCoordinator?.updateExpandedBodyHeight(height, animated: animated)
    }

    private func configurePanelIfNeeded() {
        guard panelCoordinator == nil else { return }

        let coordinator = PanelCoordinator { [weak self] displayState in
            if let self {
                AnyView(
                    NotchRootView(
                        runtime: self,
                        displayState: displayState
                    )
                )
            } else {
                AnyView(EmptyView())
            }
        }
        coordinator.onPresentationChange = { [weak self] presentation in
            guard let self else { return }
            if presentation == .compact {
                self.surface = .compact
            } else if self.surface == .compact {
                self.surface = .dashboard
            }
        }
        coordinator.onRequestCollapse = { [weak self] in
            self?.showCompact()
        }
        panelCoordinator = coordinator
    }

    private func configureCompletionOverlayIfNeeded() {
        guard completionOverlayCoordinator == nil else { return }
        completionOverlayCoordinator = CompletionOverlayCoordinator()
    }

    private func reconcileCompactPresence(
        at now: Date = .now,
        animated: Bool = true
    ) {
        guard isRunning else { return }

        var completedActivityDates: [Date] = []
        var interruptedActivityDates: [Date] = []
        for task in store.recentlyFinishedTasks {
            let activityDate = task.lastActivityAt ?? task.observedAt
            switch task.state {
            case .completed:
                completedActivityDates.append(activityDate)
            case .interrupted:
                interruptedActivityDates.append(activityDate)
            case .needsAttention, .working, .idle, .unverified, .stale:
                break
            }
        }
        compactPresence = compactPresencePolicy.resolve(
            refreshFailed: compactSourceIsUnavailable,
            needsAttentionCount: store.needsAttentionCount,
            workingCount: store.workingTasks.count,
            completedActivityDates: completedActivityDates,
            interruptedActivityDates: interruptedActivityDates,
            now: now
        )
        let compactBodyHeight: CGFloat
        if case .needsAttention = compactPresence {
            compactBodyHeight = attentionCompactBodyHeight
        } else {
            compactBodyHeight = restingCompactBodyHeight
        }
        panelCoordinator?.updateCompactBodyHeight(
            compactBodyHeight,
            animated: animated
        )
        scheduleCompletionExpiry(
            terminalActivityDates: completedActivityDates + interruptedActivityDates,
            now: now
        )

        guard surface == .compact else { return }

        if compactPresence.isVisible {
            panelCoordinator?.showCompact(animated: animated)
        } else {
            panelCoordinator?.concealCompact()
        }
    }

    private func scheduleCompletionExpiry(
        terminalActivityDates: [Date],
        now: Date
    ) {
        completionExpiryTask?.cancel()
        completionExpiryTask = nil

        let isTerminalTransition: Bool
        switch compactPresence {
        case .recentlyFinished, .recentlyInterrupted:
            isTerminalTransition = true
        case .dormant, .unavailable, .needsAttention, .working:
            isTerminalTransition = false
        }
        guard isTerminalTransition,
              let latestActivity = terminalActivityDates.max() else {
            return
        }

        let deadline = latestActivity.addingTimeInterval(
            compactPresencePolicy.completionVisibilityDuration
        )
        let delay = max(0, deadline.timeIntervalSince(now))
        guard delay > 0 else { return }

        completionExpiryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.reconcileCompactPresence()
        }
    }

    private func presentCompletionCelebration(for batch: DashboardCompletionBatch) {
        guard isRunning, !batch.tasks.isEmpty else { return }

        let presentation = completionFeedbackPolicy.resolve(
            effect: store.completionEffect,
            codexActiveBehavior: store.codexActiveCompletionBehavior,
            isCodexActive: isCodexFrontmost()
        )
        guard presentation != .hidden else { return }

        presentCompletionFeedback(
            completedCount: batch.tasks.count,
            remainingActiveCount: store.activeTaskCount,
            projectSummary: CompletionProjectSummary.text(
                for: batch.tasks.map(\.projectName),
                privacyMode: store.privacyMode
            ),
            presentation: presentation
        )
    }

    private func presentCompletionFeedback(
        completedCount: Int,
        remainingActiveCount: Int,
        projectSummary: String,
        presentation: CompletionFeedbackPresentation
    ) {
        nextCelebrationID &+= 1
        let event = CompletionCelebrationEvent(
            id: nextCelebrationID,
            completedCount: completedCount,
            remainingActiveCount: remainingActiveCount,
            projectSummary: projectSummary
        )
        completionCelebration = presentation.showsNotch ? event : nil
        if presentation.showsNotch, !presentation.showsFullScreen {
            surface = .compact
            panelCoordinator?.showCompact()
        }
        if presentation.showsFullScreen {
            completionOverlayCoordinator?.present(event)
        } else {
            completionOverlayCoordinator?.dismiss()
        }

        celebrationDismissTask?.cancel()
        celebrationDismissTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: CompletionOverlayCoordinator.displayDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard self?.completionCelebration?.id == event.id else { return }
            self?.completionOverlayCoordinator?.dismiss()
            self?.completionCelebration = nil
            self?.reconcileCompactPresence()
        }
    }

    private var compactSourceIsUnavailable: Bool {
        if store.lastRefreshFailedAt != nil {
            return true
        }
        if case .unavailable = store.snapshot.health {
            return true
        }
        return false
    }
}
