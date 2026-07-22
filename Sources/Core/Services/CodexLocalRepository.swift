import Foundation

public actor CodexLocalRepository {
    private let stateDatabase: CodexStateDatabase
    private let rolloutParser: RolloutParser
    private let classifier: TaskStateClassifier
    private let recentThreadLimit: Int
    private let maximumChildrenPerThread: Int
    private let clock: @Sendable () -> Date
    private var rolloutCache: [String: RolloutCacheEntry] = [:]

    public init(
        codexHome: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true),
        recentThreadLimit: Int = 20,
        maximumChildrenPerThread: Int = 24,
        rolloutTailByteLimit: Int = 256 * 1_024,
        lifecycleScanByteLimit: Int = 4 * 1_024 * 1_024,
        staleAfter: TimeInterval = 120,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.stateDatabase = CodexStateDatabase(
            databaseURL: codexHome.appendingPathComponent("state_5.sqlite")
        )
        self.rolloutParser = RolloutParser(
            tailByteLimit: rolloutTailByteLimit,
            lifecycleScanByteLimit: lifecycleScanByteLimit
        )
        self.classifier = TaskStateClassifier(staleAfter: staleAfter)
        self.recentThreadLimit = max(1, recentThreadLimit)
        self.maximumChildrenPerThread = max(1, maximumChildrenPerThread)
        self.clock = clock
    }

    /// Returns a local-only snapshot suitable for low-frequency polling.
    /// This method never starts app-server, performs network requests, or writes Codex state.
    public func snapshot() async -> DashboardSnapshot {
        let observedAt = clock()
        let catalog: [CodexCatalogThread]
        do {
            catalog = try stateDatabase.recentThreads(
                limit: recentThreadLimit,
                maximumChildrenPerThread: maximumChildrenPerThread
            )
        } catch {
            return DashboardSnapshot(
                tasks: [],
                usageLimits: nil,
                generatedAt: observedAt,
                health: .unavailable("Codex state database is unavailable")
            )
        }

        var isDegraded = false
        var latestUsageLimits: UsageLimitsSnapshot?
        var tasks: [CodexTaskSnapshot] = []
        var observedRolloutPaths = Set<String>()
        tasks.reserveCapacity(catalog.count)

        for thread in catalog {
            observedRolloutPaths.insert(thread.rolloutPath)
            let rollout = parseRollout(
                path: thread.rolloutPath,
                threadID: thread.id,
                isDegraded: &isDegraded
            )
            consider(rollout?.usageLimits, for: &latestUsageLimits)

            let lastActivityAt = rollout?.evidence.lastActivityAt ?? thread.updatedAt
            let state: CodexTaskDisplayState
            let authority: CodexTaskAuthority
            if let rollout, rollout.lifecycleIsKnown {
                state = classifier.classify(rollout.evidence, now: observedAt)
                authority = rollout.hasLifecycleEvidence ? .liveRollout : .persistedCatalog
            } else {
                state = unresolvedState(
                    lastActivityAt: lastActivityAt,
                    observedAt: observedAt
                )
                authority = .persistedCatalog
                isDegraded = true
            }

            let childAgentCount = activeChildCount(
                for: thread,
                latestUsageLimits: &latestUsageLimits,
                isDegraded: &isDegraded,
                observedRolloutPaths: &observedRolloutPaths
            )

            tasks.append(CodexTaskSnapshot(
                id: thread.id,
                title: thread.title,
                projectName: projectName(for: thread.workingDirectory),
                workingDirectory: thread.workingDirectory,
                rolloutPath: thread.rolloutPath,
                state: state,
                authority: authority,
                lastActivityAt: lastActivityAt,
                observedAt: observedAt,
                activityLabel: rollout?.activityLabel,
                activeTurnID: rollout?.activeTurnID,
                childAgentCount: childAgentCount
            ))
        }

        rolloutCache = rolloutCache.filter { observedRolloutPaths.contains($0.key) }

        return DashboardSnapshot(
            tasks: tasks,
            usageLimits: latestUsageLimits,
            generatedAt: observedAt,
            health: isDegraded
                ? .degraded("Some local task state could not be verified")
                : .healthy
        )
    }

    private func activeChildCount(
        for thread: CodexCatalogThread,
        latestUsageLimits: inout UsageLimitsSnapshot?,
        isDegraded: inout Bool,
        observedRolloutPaths: inout Set<String>
    ) -> Int {
        guard thread.childListIsComplete else {
            isDegraded = true
            return 0
        }

        var activeCount = 0
        for child in thread.children {
            observedRolloutPaths.insert(child.rolloutPath)
            guard let rollout = parseRollout(
                path: child.rolloutPath,
                threadID: child.id,
                isDegraded: &isDegraded
            ), rollout.lifecycleIsKnown else {
                isDegraded = true
                return 0
            }
            consider(rollout.usageLimits, for: &latestUsageLimits)
            if rollout.hasActiveTurn {
                activeCount += 1
            }
        }
        return activeCount
    }

    private func parseRollout(
        path: String,
        threadID: String,
        isDegraded: inout Bool
    ) -> RolloutTailSnapshot? {
        guard let metadata = fileMetadata(at: path) else {
            isDegraded = true
            rolloutCache[path] = nil
            return nil
        }
        let cached = rolloutCache[path]
        if let cached, cached.metadata == metadata {
            return cached.snapshot
        }

        let appendOnlyCache = cached.flatMap { entry -> RolloutCacheEntry? in
            guard metadata.size > entry.metadata.size,
                  metadata.fileSystemNumber == entry.metadata.fileSystemNumber,
                  metadata.fileNumber == entry.metadata.fileNumber else {
                return nil
            }
            return entry
        }

        do {
            let snapshot = try rolloutParser.parseTail(
                at: URL(fileURLWithPath: path),
                sourceThreadID: threadID,
                previousSnapshot: appendOnlyCache?.snapshot,
                previousFileSize: appendOnlyCache?.metadata.size
            )
            rolloutCache[path] = RolloutCacheEntry(metadata: metadata, snapshot: snapshot)
            return snapshot
        } catch {
            isDegraded = true
            rolloutCache[path] = nil
            return nil
        }
    }

    private func fileMetadata(at path: String) -> RolloutFileMetadata? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return RolloutFileMetadata(
            size: size.uint64Value,
            modificationDate: modificationDate,
            fileSystemNumber: (attributes[.systemNumber] as? NSNumber)?.uint64Value,
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )
    }

    private func consider(
        _ candidate: UsageLimitsSnapshot?,
        for latest: inout UsageLimitsSnapshot?
    ) {
        guard let candidate else { return }
        if latest == nil || candidate.capturedAt > latest!.capturedAt {
            latest = candidate
        }
    }

    private func unresolvedState(
        lastActivityAt: Date,
        observedAt: Date
    ) -> CodexTaskDisplayState {
        observedAt.timeIntervalSince(lastActivityAt) > classifier.staleAfter
            ? .stale
            : .unverified
    }

    private func projectName(for workingDirectory: String) -> String {
        let name = URL(fileURLWithPath: workingDirectory, isDirectory: true).lastPathComponent
        return name.isEmpty ? workingDirectory : name
    }
}

private struct RolloutFileMetadata: Equatable, Sendable {
    let size: UInt64
    let modificationDate: Date
    let fileSystemNumber: UInt64?
    let fileNumber: UInt64?
}

private struct RolloutCacheEntry: Sendable {
    let metadata: RolloutFileMetadata
    let snapshot: RolloutTailSnapshot
}
