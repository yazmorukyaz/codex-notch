import CodexNotchCore
import Foundation

@MainActor
enum DashboardDiagnosticsExporter {
    static func destination(from arguments: [String]) -> URL? {
        guard let flagIndex = arguments.firstIndex(of: "--export-live-summary"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return URL(fileURLWithPath: arguments[flagIndex + 1])
    }

    static func export(snapshot: DashboardSnapshot, to destination: URL) throws {
        var stateCounts: [String: Int] = [:]
        for task in snapshot.tasks {
            stateCounts[task.state.rawValue, default: 0] += 1
        }

        let health: String
        switch snapshot.health {
        case .healthy:
            health = "healthy"
        case .degraded:
            health = "degraded"
        case .unavailable:
            health = "unavailable"
        }

        var object: [String: Any] = [
            "generated_at": ISO8601DateFormatter().string(from: snapshot.generatedAt),
            "health": health,
            "task_count": snapshot.tasks.count,
            "active_child_agent_count": snapshot.tasks.reduce(0) { $0 + $1.childAgentCount },
            "states": stateCounts,
        ]

        if let limits = snapshot.usageLimits {
            var limitObject: [String: Any] = [
                "limit_id": limits.limitID,
                "captured_at": ISO8601DateFormatter().string(from: limits.capturedAt),
            ]
            if let primary = limits.primary {
                limitObject["primary_used_percent"] = primary.usedPercent
                limitObject["primary_window_minutes"] = primary.windowMinutes
            }
            if let secondary = limits.secondary {
                limitObject["secondary_used_percent"] = secondary.usedPercent
                limitObject["secondary_window_minutes"] = secondary.windowMinutes
            }
            object["limits"] = limitObject
        }

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }
}
