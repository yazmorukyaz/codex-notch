import Foundation

public struct UsageWindowSnapshot: Hashable, Sendable {
    public let usedPercent: Double
    public let windowMinutes: Int
    public let resetsAt: Date?

    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date?) {
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct UsageLimitsSnapshot: Hashable, Sendable {
    public let limitID: String
    public let planType: String?
    public let primary: UsageWindowSnapshot?
    public let secondary: UsageWindowSnapshot?
    public let capturedAt: Date
    public let sourceThreadID: String?

    public init(
        limitID: String,
        planType: String?,
        primary: UsageWindowSnapshot?,
        secondary: UsageWindowSnapshot?,
        capturedAt: Date,
        sourceThreadID: String?
    ) {
        self.limitID = limitID
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.capturedAt = capturedAt
        self.sourceThreadID = sourceThreadID
    }
}
