import Foundation

public enum CodexTaskDisplayState: String, Codable, CaseIterable, Sendable {
    case needsAttention
    case working
    case completed
    case interrupted
    case idle
    case unverified
    case stale
}

public enum CodexTaskAuthority: String, Codable, Sendable {
    case liveRollout
    case persistedCatalog
    case derived
}

public struct CodexTaskSnapshot: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let projectName: String
    public let workingDirectory: String
    public let rolloutPath: String
    public let state: CodexTaskDisplayState
    public let authority: CodexTaskAuthority
    public let lastActivityAt: Date?
    public let observedAt: Date
    public let activityLabel: String?
    public let activeTurnID: String?
    public let childAgentCount: Int

    public init(
        id: String,
        title: String,
        projectName: String,
        workingDirectory: String,
        rolloutPath: String,
        state: CodexTaskDisplayState,
        authority: CodexTaskAuthority,
        lastActivityAt: Date?,
        observedAt: Date,
        activityLabel: String? = nil,
        activeTurnID: String? = nil,
        childAgentCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.workingDirectory = workingDirectory
        self.rolloutPath = rolloutPath
        self.state = state
        self.authority = authority
        self.lastActivityAt = lastActivityAt
        self.observedAt = observedAt
        self.activityLabel = activityLabel
        self.activeTurnID = activeTurnID
        self.childAgentCount = childAgentCount
    }
}
