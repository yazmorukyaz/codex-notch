import Foundation

public enum CodexSourceHealth: Hashable, Sendable {
    case healthy
    case degraded(String)
    case unavailable(String)
}

public struct DashboardSnapshot: Sendable {
    public let tasks: [CodexTaskSnapshot]
    public let usageLimits: UsageLimitsSnapshot?
    public let generatedAt: Date
    public let health: CodexSourceHealth

    public init(
        tasks: [CodexTaskSnapshot],
        usageLimits: UsageLimitsSnapshot?,
        generatedAt: Date,
        health: CodexSourceHealth
    ) {
        self.tasks = tasks
        self.usageLimits = usageLimits
        self.generatedAt = generatedAt
        self.health = health
    }

    public static func empty(at date: Date = .now) -> DashboardSnapshot {
        DashboardSnapshot(tasks: [], usageLimits: nil, generatedAt: date, health: .healthy)
    }
}
