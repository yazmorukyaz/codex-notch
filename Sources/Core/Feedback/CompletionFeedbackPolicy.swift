import Foundation

public enum CompletionEffect: String, CaseIterable, Codable, Hashable, Sendable {
    case fullScreen
    case notchOnly
    case off
}

public enum CodexActiveCompletionBehavior: String, CaseIterable, Codable, Hashable, Sendable {
    case keepSelectedEffect
    case notchOnly
    case hide
}

public struct CompletionFeedbackPresentation: Equatable, Sendable {
    public let showsNotch: Bool
    public let showsFullScreen: Bool

    public init(showsNotch: Bool, showsFullScreen: Bool) {
        self.showsNotch = showsNotch
        self.showsFullScreen = showsFullScreen
    }

    public static let hidden = CompletionFeedbackPresentation(
        showsNotch: false,
        showsFullScreen: false
    )
}

public struct CompletionFeedbackPolicy: Sendable {
    public init() {}

    public func resolve(
        effect: CompletionEffect,
        codexActiveBehavior: CodexActiveCompletionBehavior,
        isCodexActive: Bool
    ) -> CompletionFeedbackPresentation {
        guard effect != .off else { return .hidden }

        if isCodexActive {
            switch codexActiveBehavior {
            case .keepSelectedEffect:
                break
            case .notchOnly:
                return CompletionFeedbackPresentation(
                    showsNotch: true,
                    showsFullScreen: false
                )
            case .hide:
                return .hidden
            }
        }

        switch effect {
        case .fullScreen:
            return CompletionFeedbackPresentation(
                showsNotch: true,
                showsFullScreen: true
            )
        case .notchOnly:
            return CompletionFeedbackPresentation(
                showsNotch: true,
                showsFullScreen: false
            )
        case .off:
            return .hidden
        }
    }
}

public struct TransitionNotificationPolicy: Sendable {
    public init() {}

    public func shouldDeliver(
        state: CodexTaskDisplayState,
        notificationsEnabled: Bool,
        quietMode: Bool,
        urgentAlertsInQuietMode: Bool
    ) -> Bool {
        guard notificationsEnabled, isNotificationWorthy(state) else {
            return false
        }
        guard quietMode else { return true }
        return urgentAlertsInQuietMode && state == .needsAttention
    }

    private func isNotificationWorthy(_ state: CodexTaskDisplayState) -> Bool {
        switch state {
        case .needsAttention, .completed, .interrupted:
            return true
        case .working, .idle, .stale, .unverified:
            return false
        }
    }
}

public struct FeedbackPreferences: Equatable, Sendable {
    public let completionEffect: CompletionEffect
    public let codexActiveBehavior: CodexActiveCompletionBehavior
    public let urgentAlertsInQuietMode: Bool

    public init(
        completionEffect: CompletionEffect,
        codexActiveBehavior: CodexActiveCompletionBehavior,
        urgentAlertsInQuietMode: Bool
    ) {
        self.completionEffect = completionEffect
        self.codexActiveBehavior = codexActiveBehavior
        self.urgentAlertsInQuietMode = urgentAlertsInQuietMode
    }

    public static func load(from defaults: UserDefaults) -> FeedbackPreferences {
        FeedbackPreferences(
            completionEffect: CompletionEffect(
                rawValue: defaults.string(forKey: Key.completionEffect) ?? ""
            ) ?? .fullScreen,
            codexActiveBehavior: CodexActiveCompletionBehavior(
                rawValue: defaults.string(forKey: Key.codexActiveBehavior) ?? ""
            ) ?? .notchOnly,
            urgentAlertsInQuietMode: defaults.object(
                forKey: Key.urgentAlertsInQuietMode
            ) as? Bool ?? true
        )
    }

    public func persist(to defaults: UserDefaults) {
        defaults.set(completionEffect.rawValue, forKey: Key.completionEffect)
        defaults.set(codexActiveBehavior.rawValue, forKey: Key.codexActiveBehavior)
        defaults.set(urgentAlertsInQuietMode, forKey: Key.urgentAlertsInQuietMode)
    }

    public enum Key {
        public static let completionEffect = "dashboard.completionEffect"
        public static let codexActiveBehavior = "dashboard.codexActiveBehavior"
        public static let urgentAlertsInQuietMode = "dashboard.urgentAlertsInQuietMode"
    }
}
