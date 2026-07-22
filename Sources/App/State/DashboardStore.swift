import Foundation
import Observation
import CodexNotchCore

struct DashboardTaskTransition: Sendable {
    let task: CodexTaskSnapshot
    let previousState: CodexTaskDisplayState
    let currentState: CodexTaskDisplayState
    let observedAt: Date
}

struct DashboardCompletionBatch: Sendable {
    let tasks: [CodexTaskSnapshot]
    let observedAt: Date
}

@Observable
@MainActor
final class DashboardStore {
    typealias SnapshotLoader = @Sendable () async throws -> DashboardSnapshot
    typealias TransitionNotificationHandler = @MainActor @Sendable (DashboardTaskTransition) -> Void
    typealias CompletionHandler = @MainActor @Sendable (DashboardCompletionBatch) -> Void
    typealias TaskOpenHandler = @MainActor @Sendable (CodexTaskSnapshot) -> Void
    typealias RefreshSettledHandler = @MainActor @Sendable () -> Void

    private enum PreferenceKey {
        static let privacyMode = "dashboard.privacyMode"
        static let quietMode = "dashboard.quietMode"
        static let notificationsEnabled = "dashboard.notificationsEnabled"
    }

    private(set) var snapshot: DashboardSnapshot
    private(set) var isRefreshing = false
    private(set) var lastRefreshErrorDescription: String?
    private(set) var lastRefreshFailedAt: Date?

    var privacyMode: Bool {
        didSet {
            guard privacyMode != oldValue else { return }
            userDefaults.set(privacyMode, forKey: PreferenceKey.privacyMode)
        }
    }

    var quietMode: Bool {
        didSet {
            guard quietMode != oldValue else { return }
            userDefaults.set(quietMode, forKey: PreferenceKey.quietMode)
        }
    }

    var completionEffect: CompletionEffect {
        didSet {
            guard completionEffect != oldValue else { return }
            userDefaults.set(
                completionEffect.rawValue,
                forKey: FeedbackPreferences.Key.completionEffect
            )
        }
    }

    var codexActiveCompletionBehavior: CodexActiveCompletionBehavior {
        didSet {
            guard codexActiveCompletionBehavior != oldValue else { return }
            userDefaults.set(
                codexActiveCompletionBehavior.rawValue,
                forKey: FeedbackPreferences.Key.codexActiveBehavior
            )
        }
    }

    var urgentAlertsInQuietMode: Bool {
        didSet {
            guard urgentAlertsInQuietMode != oldValue else { return }
            userDefaults.set(
                urgentAlertsInQuietMode,
                forKey: FeedbackPreferences.Key.urgentAlertsInQuietMode
            )
        }
    }

    private(set) var notificationsEnabled: Bool {
        didSet {
            guard notificationsEnabled != oldValue else { return }
            userDefaults.set(
                notificationsEnabled,
                forKey: PreferenceKey.notificationsEnabled
            )
        }
    }

    @ObservationIgnored
    var onRecentTransition: TransitionNotificationHandler?

    @ObservationIgnored
    var onCompletion: CompletionHandler?

    @ObservationIgnored
    var onOpenTask: TaskOpenHandler?

    @ObservationIgnored
    var onRefreshSettled: RefreshSettledHandler?

    @ObservationIgnored
    private let loader: SnapshotLoader

    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private let pollInterval: Duration

    @ObservationIgnored
    private let recentTransitionWindow: TimeInterval

    @ObservationIgnored
    private let completionCelebrationPolicy = CompletionCelebrationPolicy()

    @ObservationIgnored
    private let transitionNotificationPolicy = TransitionNotificationPolicy()

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var previousStates: [String: CodexTaskDisplayState]

    init(
        initialSnapshot: DashboardSnapshot = .empty(),
        userDefaults: UserDefaults = .standard,
        pollInterval: Duration = .seconds(2),
        recentTransitionWindow: TimeInterval = 30,
        loader: @escaping SnapshotLoader,
        onRecentTransition: TransitionNotificationHandler? = nil,
        onCompletion: CompletionHandler? = nil,
        onOpenTask: TaskOpenHandler? = nil
    ) {
        let feedbackPreferences = FeedbackPreferences.load(from: userDefaults)
        self.snapshot = initialSnapshot
        self.userDefaults = userDefaults
        self.pollInterval = pollInterval
        self.recentTransitionWindow = recentTransitionWindow
        self.loader = loader
        self.onRecentTransition = onRecentTransition
        self.onCompletion = onCompletion
        self.onOpenTask = onOpenTask
        self.privacyMode = userDefaults.object(forKey: PreferenceKey.privacyMode) as? Bool ?? false
        self.quietMode = userDefaults.object(forKey: PreferenceKey.quietMode) as? Bool ?? false
        self.completionEffect = feedbackPreferences.completionEffect
        self.codexActiveCompletionBehavior = feedbackPreferences.codexActiveBehavior
        self.urgentAlertsInQuietMode = feedbackPreferences.urgentAlertsInQuietMode
        self.notificationsEnabled = userDefaults.object(
            forKey: PreferenceKey.notificationsEnabled
        ) as? Bool ?? false
        self.previousStates = Dictionary(
            uniqueKeysWithValues: initialSnapshot.tasks.map { ($0.id, $0.state) }
        )
    }

    var needsAttentionTasks: [CodexTaskSnapshot] {
        sortedTasks { task in
            if case .needsAttention = task.state { return true }
            return false
        }
    }

    var workingTasks: [CodexTaskSnapshot] {
        sortedTasks { task in
            if case .working = task.state { return true }
            return false
        }
    }

    var recentlyFinishedTasks: [CodexTaskSnapshot] {
        let cutoff = snapshot.generatedAt.addingTimeInterval(-30 * 60)
        return sortedTasks { task in
            let isFinished: Bool
            switch task.state {
            case .completed, .interrupted:
                isFinished = true
            default:
                isFinished = false
            }

            guard isFinished else { return false }
            return (task.lastActivityAt ?? task.observedAt) >= cutoff
        }
    }

    var staleTasks: [CodexTaskSnapshot] {
        sortedTasks { task in
            if case .stale = task.state { return true }
            return false
        }
    }

    var unverifiedTasks: [CodexTaskSnapshot] {
        sortedTasks { task in
            if case .unverified = task.state { return true }
            return false
        }
    }

    var otherTasks: [CodexTaskSnapshot] {
        sortedTasks { task in
            switch task.state {
            case .idle, .stale:
                return true
            case .needsAttention, .working, .completed, .interrupted, .unverified:
                return false
            }
        }
    }

    var activeTaskCount: Int {
        needsAttentionTasks.count + workingTasks.count
    }

    var needsAttentionCount: Int {
        needsAttentionTasks.count
    }

    var staleTaskCount: Int {
        staleTasks.count
    }

    var unverifiedTaskCount: Int {
        unverifiedTasks.count
    }

    var isPolling: Bool {
        pollingTask != nil
    }

    func startPolling() {
        guard pollingTask == nil else { return }

        let interval = pollInterval
        pollingTask = Task { [weak self] in
            guard self != nil else { return }
            await self?.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }

                guard self != nil else { return }
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        var shouldNotifyRefreshSettled = true
        defer {
            isRefreshing = false
            if shouldNotifyRefreshSettled {
                onRefreshSettled?()
            }
        }

        do {
            let updatedSnapshot = try await loader()
            try Task.checkCancellation()
            apply(updatedSnapshot)
            lastRefreshErrorDescription = nil
            lastRefreshFailedAt = nil
        } catch is CancellationError {
            shouldNotifyRefreshSettled = false
            return
        } catch {
            guard !Task.isCancelled else {
                shouldNotifyRefreshSettled = false
                return
            }
            lastRefreshErrorDescription = error.localizedDescription
            lastRefreshFailedAt = .now
        }
    }

    func openTask(_ task: CodexTaskSnapshot) {
        onOpenTask?(task)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
    }

    private func apply(_ updatedSnapshot: DashboardSnapshot) {
        let nextStates = Dictionary(
            uniqueKeysWithValues: updatedSnapshot.tasks.map { ($0.id, $0.state) }
        )
        let transitions = recentTransitions(
            in: updatedSnapshot,
            previousStates: previousStates
        )

        snapshot = updatedSnapshot
        previousStates = nextStates

        notifyAboutCompletions(in: transitions, observedAt: updatedSnapshot.generatedAt)

        notifyAboutRecentTransitions(transitions)
    }

    private func recentTransitions(
        in updatedSnapshot: DashboardSnapshot,
        previousStates: [String: CodexTaskDisplayState]
    ) -> [DashboardTaskTransition] {
        updatedSnapshot.tasks.compactMap { task in
            guard let previousState = previousStates[task.id],
                  previousState.rawValue != task.state.rawValue,
                  isRecent(task, relativeTo: updatedSnapshot.generatedAt) else {
                return nil
            }

            return DashboardTaskTransition(
                task: task,
                previousState: previousState,
                currentState: task.state,
                observedAt: updatedSnapshot.generatedAt
            )
        }
    }

    private func notifyAboutCompletions(
        in transitions: [DashboardTaskTransition],
        observedAt: Date
    ) {
        guard let onCompletion else { return }

        let completedTasks = transitions.compactMap { transition in
            completionCelebrationPolicy.shouldCelebrate(
                previousState: transition.previousState,
                currentState: transition.currentState,
                isRecent: true
            ) ? transition.task : nil
        }
        guard !completedTasks.isEmpty else { return }

        onCompletion(
            DashboardCompletionBatch(
                tasks: completedTasks,
                observedAt: observedAt
            )
        )
    }

    private func notifyAboutRecentTransitions(
        _ transitions: [DashboardTaskTransition]
    ) {
        guard let onRecentTransition else { return }

        for transition in transitions where transitionNotificationPolicy.shouldDeliver(
            state: transition.currentState,
            notificationsEnabled: notificationsEnabled,
            quietMode: quietMode,
            urgentAlertsInQuietMode: urgentAlertsInQuietMode
        ) {
            onRecentTransition(transition)
        }
    }

    private func isRecent(_ task: CodexTaskSnapshot, relativeTo generatedAt: Date) -> Bool {
        let transitionDate = task.lastActivityAt ?? task.observedAt
        return abs(generatedAt.timeIntervalSince(transitionDate)) <= recentTransitionWindow
    }

    private func sortedTasks(
        matching predicate: (CodexTaskSnapshot) -> Bool
    ) -> [CodexTaskSnapshot] {
        snapshot.tasks
            .filter(predicate)
            .sorted { left, right in
                let leftDate = left.lastActivityAt ?? left.observedAt
                let rightDate = right.lastActivityAt ?? right.observedAt

                if leftDate == rightDate {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }

                return leftDate > rightDate
            }
    }
}

extension DashboardStore {
    static func completionDemo(
        userDefaults: UserDefaults = .standard
    ) -> DashboardStore {
        let initialSnapshot = completionDemoSnapshot(state: .working, at: .now)

        return DashboardStore(
            initialSnapshot: initialSnapshot,
            userDefaults: userDefaults,
            pollInterval: .seconds(60),
            loader: {
                DashboardStore.completionDemoSnapshot(
                    state: .completed,
                    at: .now
                )
            }
        )
    }

    nonisolated private static func completionDemoSnapshot(
        state: CodexTaskDisplayState,
        at now: Date
    ) -> DashboardSnapshot {
        DashboardSnapshot(
            tasks: [
                CodexTaskSnapshot(
                    id: "completion-demo",
                    title: "Polish the completion animation",
                    projectName: "Codex Notch",
                    workingDirectory: "/demo/codex-notch",
                    rolloutPath: "/demo/rollouts/completion.jsonl",
                    state: state,
                    authority: .liveRollout,
                    lastActivityAt: now,
                    observedAt: now,
                    activityLabel: state.rawValue.capitalized,
                    activeTurnID: state.rawValue == CodexTaskDisplayState.working.rawValue
                        ? "completion-demo-turn"
                        : nil
                )
            ],
            usageLimits: nil,
            generatedAt: now,
            health: .healthy
        )
    }

    static func demo(
        userDefaults: UserDefaults = .standard,
        onRecentTransition: TransitionNotificationHandler? = nil,
        onCompletion: CompletionHandler? = nil,
        onOpenTask: TaskOpenHandler? = nil
    ) -> DashboardStore {
        let snapshot = demoSnapshot(at: .now)

        return DashboardStore(
            initialSnapshot: snapshot,
            userDefaults: userDefaults,
            loader: {
                DashboardStore.demoSnapshot(at: .now)
            },
            onRecentTransition: onRecentTransition,
            onCompletion: onCompletion,
            onOpenTask: onOpenTask
        )
    }

    nonisolated static func demoSnapshot(at now: Date = .now) -> DashboardSnapshot {
        let tasks = [
            CodexTaskSnapshot(
                id: "demo-attention",
                title: "Prepare release build",
                projectName: "Codex Notch",
                workingDirectory: "/demo/codex-notch",
                rolloutPath: "/demo/rollouts/attention.jsonl",
                state: .needsAttention,
                authority: .liveRollout,
                lastActivityAt: now.addingTimeInterval(-18),
                observedAt: now,
                activityLabel: "Waiting for approval",
                activeTurnID: "demo-turn-attention",
                childAgentCount: 1
            ),
            CodexTaskSnapshot(
                id: "demo-working",
                title: "Audit onboarding flow",
                projectName: "Stitchify",
                workingDirectory: "/demo/stitchify",
                rolloutPath: "/demo/rollouts/working.jsonl",
                state: .working,
                authority: .liveRollout,
                lastActivityAt: now.addingTimeInterval(-8),
                observedAt: now,
                activityLabel: "Running tests",
                activeTurnID: "demo-turn-working",
                childAgentCount: 2
            ),
            CodexTaskSnapshot(
                id: "demo-complete",
                title: "Update launch copy",
                projectName: "Apply Labs",
                workingDirectory: "/demo/apply-labs",
                rolloutPath: "/demo/rollouts/completed.jsonl",
                state: .completed,
                authority: .liveRollout,
                lastActivityAt: now.addingTimeInterval(-180),
                observedAt: now,
                activityLabel: "Finished successfully"
            ),
            CodexTaskSnapshot(
                id: "demo-stale",
                title: "Research checkout issue",
                projectName: "Storefront",
                workingDirectory: "/demo/storefront",
                rolloutPath: "/demo/rollouts/stale.jsonl",
                state: .stale,
                authority: .derived,
                lastActivityAt: now.addingTimeInterval(-420),
                observedAt: now,
                activityLabel: "No recent activity"
            )
        ]

        let usage = UsageLimitsSnapshot(
            limitID: "demo-limits",
            planType: "Codex",
            primary: UsageWindowSnapshot(
                usedPercent: 37,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(2 * 60 * 60)
            ),
            secondary: UsageWindowSnapshot(
                usedPercent: 61,
                windowMinutes: 7 * 24 * 60,
                resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60)
            ),
            capturedAt: now,
            sourceThreadID: "demo-source"
        )

        return DashboardSnapshot(
            tasks: tasks,
            usageLimits: usage,
            generatedAt: now,
            health: .healthy
        )
    }
}
