import AppKit

@MainActor
enum CodexHandoff {
    @discardableResult
    static func open(threadID: String) -> Bool {
        guard UUID(uuidString: threadID) != nil,
              let url = URL(string: "codex://threads/\(threadID)") else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }

    @discardableResult
    static func openApplication() -> Bool {
        guard let url = URL(string: "codex://") else { return false }
        return NSWorkspace.shared.open(url)
    }
}
