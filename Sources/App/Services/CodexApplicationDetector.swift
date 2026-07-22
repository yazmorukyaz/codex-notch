import AppKit

@MainActor
enum CodexApplicationDetector {
    private static let knownBundleIdentifiers: Set<String> = [
        "com.openai.codex",
    ]

    static func isCodexFrontmost(
        workspace: NSWorkspace = .shared
    ) -> Bool {
        guard let application = workspace.frontmostApplication else {
            return false
        }
        return isCodex(
            bundleIdentifier: application.bundleIdentifier,
            localizedName: application.localizedName
        )
    }

    static func isCodex(
        bundleIdentifier: String?,
        localizedName: String?
    ) -> Bool {
        if let bundleIdentifier,
           knownBundleIdentifiers.contains(bundleIdentifier.lowercased()) {
            return true
        }
        return localizedName?.localizedCaseInsensitiveCompare("Codex") == .orderedSame
    }
}
