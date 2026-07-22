import SwiftUI
import CodexNotchCore

enum StatusBadgeKind {
    case needsAttention
    case working
    case completed
    case interrupted
    case idle
    case unverified
    case stale
    case healthy
    case degraded
    case unavailable
    case quiet
    case privacy

    init(taskState: CodexTaskDisplayState) {
        switch taskState {
        case .needsAttention:
            self = .needsAttention
        case .working:
            self = .working
        case .completed:
            self = .completed
        case .interrupted:
            self = .interrupted
        case .idle:
            self = .idle
        case .unverified:
            self = .unverified
        case .stale:
            self = .stale
        }
    }

    init(sourceHealth: CodexSourceHealth) {
        switch sourceHealth {
        case .healthy:
            self = .healthy
        case .degraded:
            self = .degraded
        case .unavailable:
            self = .unavailable
        }
    }

    var label: String {
        switch self {
        case .needsAttention:
            return "Needs you"
        case .working:
            return "Working"
        case .completed:
            return "Finished"
        case .interrupted:
            return "Interrupted"
        case .idle:
            return "Idle"
        case .unverified:
            return "Unverified"
        case .stale:
            return "No recent activity"
        case .healthy:
            return "Live"
        case .degraded:
            return "Partial data"
        case .unavailable:
            return "Offline"
        case .quiet:
            return "Quiet"
        case .privacy:
            return "Private"
        }
    }

    var systemImage: String {
        switch self {
        case .needsAttention:
            return "exclamationmark"
        case .working:
            return "circle.dotted"
        case .completed:
            return "checkmark"
        case .interrupted:
            return "xmark"
        case .idle:
            return "pause.fill"
        case .unverified:
            return "questionmark.circle"
        case .stale:
            return "clock"
        case .healthy:
            return "wave.3.right"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "wifi.slash"
        case .quiet:
            return "moon.fill"
        case .privacy:
            return "eye.slash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .needsAttention, .degraded:
            return Color(red: 0.96, green: 0.67, blue: 0.24)
        case .working, .healthy:
            return Color(red: 0.35, green: 0.82, blue: 0.76)
        case .completed:
            return Color(red: 0.31, green: 0.78, blue: 0.49)
        case .interrupted, .unavailable:
            return Color(red: 0.95, green: 0.36, blue: 0.42)
        case .unverified:
            return Color(red: 0.48, green: 0.68, blue: 0.96)
        case .idle, .stale, .quiet, .privacy:
            return Color.white.opacity(0.58)
        }
    }
}

struct StatusBadge: View {
    let kind: StatusBadgeKind
    let showsLabel: Bool

    init(_ kind: StatusBadgeKind, showsLabel: Bool = true) {
        self.kind = kind
        self.showsLabel = showsLabel
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 10, weight: .semibold))

            if showsLabel {
                Text(kind.label)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(kind.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.label)
    }
}
