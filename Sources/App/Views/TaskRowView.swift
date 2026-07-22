import SwiftUI
import CodexNotchCore

struct TaskRowView: View {
    let task: CodexTaskSnapshot
    let privacyMode: Bool
    let onOpen: () -> Void

    init(
        task: CodexTaskSnapshot,
        privacyMode: Bool,
        onOpen: @escaping () -> Void = {}
    ) {
        self.task = task
        self.privacyMode = privacyMode
        self.onOpen = onOpen
    }

    private var displayedTitle: String {
        privacyMode ? "Codex task" : task.title
    }

    private var displayedProject: String {
        privacyMode ? "Private project" : task.projectName
    }

    private var activityText: String {
        guard !privacyMode else { return "Activity hidden" }
        return task.activityLabel ?? fallbackActivityLabel
    }

    private var fallbackActivityLabel: String {
        switch task.state {
        case .needsAttention:
            return "Waiting for input"
        case .working:
            return "Working"
        case .completed:
            return "Finished successfully"
        case .interrupted:
            return "Task stopped"
        case .idle:
            return "Ready"
        case .unverified:
            return "Recent activity · state unverified"
        case .stale:
            return "No recent activity"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 9) {
                    Text(displayedTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .lineLimit(1)

                    Spacer(minLength: 10)

                    StatusBadge(StatusBadgeKind(taskState: task.state))

                    if let lastActivityAt = task.lastActivityAt {
                        Text(lastActivityAt, style: .relative)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .monospacedDigit()
                    }

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.42))
                }

                HStack(spacing: 7) {
                    Text(displayedProject)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(1)

                    Text("·")
                        .foregroundStyle(Color.white.opacity(0.28))

                    Text(activityText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)

                    if task.childAgentCount > 0 {
                        Spacer(minLength: 8)

                        Label(
                            "\(task.childAgentCount)",
                            systemImage: task.childAgentCount == 1 ? "person.fill" : "person.2.fill"
                        )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.50))
                        .accessibilityLabel("\(task.childAgentCount) active child agents")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open in Codex")
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this task in Codex")
    }
}
