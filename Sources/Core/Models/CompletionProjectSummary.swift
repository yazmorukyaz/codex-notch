import Foundation

/// Produces the bounded, privacy-safe project label shown when one or more
/// Codex tasks finish in the same refresh cycle.
public enum CompletionProjectSummary {
    public static func text(
        for projectNames: [String],
        privacyMode: Bool
    ) -> String {
        guard !privacyMode else { return "Private project" }

        var seenNames = Set<String>()
        var uniqueNames: [String] = []

        for rawName in projectNames {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let comparisonKey = name.lowercased()
            guard seenNames.insert(comparisonKey).inserted else { continue }
            uniqueNames.append(name)
        }

        guard !uniqueNames.isEmpty else { return "Unknown project" }
        guard uniqueNames.count > 1 else { return uniqueNames[0] }

        let visibleNames = uniqueNames.prefix(2)
        let hiddenCount = uniqueNames.count - visibleNames.count
        let visibleSummary = visibleNames.joined(separator: " + ")

        guard hiddenCount > 0 else { return visibleSummary }
        return "\(visibleSummary) + \(hiddenCount) more"
    }
}
