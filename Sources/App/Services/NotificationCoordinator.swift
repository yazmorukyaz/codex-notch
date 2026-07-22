import CodexNotchCore
import Foundation
import UserNotifications

@MainActor
final class NotificationCoordinator {
    private let center: UNUserNotificationCenter
    private var deliveredKeys: Set<String> = []

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func deliverTransition(for task: CodexTaskSnapshot, privacyMode: Bool) async {
        guard let message = message(for: task) else { return }

        let transitionKey = [
            task.id,
            task.activeTurnID ?? "latest",
            task.state.rawValue,
            task.activityLabel ?? "activity",
            String((task.lastActivityAt ?? task.observedAt).timeIntervalSince1970),
        ].joined(separator: ":")

        guard deliveredKeys.insert(transitionKey).inserted else { return }

        let content = UNMutableNotificationContent()
        content.title = privacyMode ? "Codex task updated" : task.projectName
        content.body = privacyMode ? message.privateText : "\(task.title) — \(message.publicText)"
        content.sound = task.state == .needsAttention ? .default : nil
        content.userInfo = ["threadID": task.id]

        let request = UNNotificationRequest(
            identifier: "codex-notch.\(transitionKey)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    private func message(
        for task: CodexTaskSnapshot
    ) -> (publicText: String, privateText: String)? {
        switch task.state {
        case .needsAttention:
            if task.activityLabel == "Needs approval" {
                return ("Approval required", "A task needs approval")
            }
            if task.activityLabel == "Needs answer" {
                return ("Answer required", "A task needs an answer")
            }
            return ("Needs you", "A task needs you")
        case .completed:
            return ("Finished", "A task finished")
        case .interrupted:
            return ("Stopped before completion", "A task stopped before completion")
        case .working, .idle, .unverified, .stale:
            return nil
        }
    }
}
