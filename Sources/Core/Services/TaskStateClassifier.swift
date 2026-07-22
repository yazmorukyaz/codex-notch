import Foundation

public enum TaskTerminalKind: Sendable {
    case completed
    case interrupted
}

public struct TaskStateEvidence: Sendable {
    public let latestTurnStartedAt: Date?
    public let latestTurnFinishedAt: Date?
    public let terminalKind: TaskTerminalKind?
    public let attentionSince: Date?
    public let lastActivityAt: Date?

    public init(
        latestTurnStartedAt: Date? = nil,
        latestTurnFinishedAt: Date? = nil,
        terminalKind: TaskTerminalKind? = nil,
        attentionSince: Date? = nil,
        lastActivityAt: Date? = nil
    ) {
        self.latestTurnStartedAt = latestTurnStartedAt
        self.latestTurnFinishedAt = latestTurnFinishedAt
        self.terminalKind = terminalKind
        self.attentionSince = attentionSince
        self.lastActivityAt = lastActivityAt
    }
}

public struct TaskStateClassifier: Sendable {
    public let staleAfter: TimeInterval

    public init(staleAfter: TimeInterval = 120) {
        self.staleAfter = staleAfter
    }

    public func classify(_ evidence: TaskStateEvidence, now: Date) -> CodexTaskDisplayState {
        let startedAt = evidence.latestTurnStartedAt
        let finishedAt = evidence.latestTurnFinishedAt
        let hasOpenTurn = startedAt.map { start in
            guard let finishedAt else { return true }
            return start > finishedAt
        } ?? false

        if let attentionSince = evidence.attentionSince,
           hasOpenTurn,
           attentionSince >= (startedAt ?? .distantPast) {
            return .needsAttention
        }

        if hasOpenTurn {
            let lastEvidenceAt = evidence.lastActivityAt ?? startedAt ?? .distantPast
            return now.timeIntervalSince(lastEvidenceAt) > staleAfter ? .stale : .working
        }

        switch evidence.terminalKind {
        case .completed:
            return .completed
        case .interrupted:
            return .interrupted
        case nil:
            return .idle
        }
    }
}
