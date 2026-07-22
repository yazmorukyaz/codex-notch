import XCTest
@testable import CodexNotchCore

final class CompletionFeedbackPolicyTests: XCTestCase {
    private let policy = CompletionFeedbackPolicy()

    func testFullScreenEffectOutsideCodexShowsBothPresentations() {
        XCTAssertEqual(
            policy.resolve(
                effect: .fullScreen,
                codexActiveBehavior: .notchOnly,
                isCodexActive: false
            ),
            CompletionFeedbackPresentation(showsNotch: true, showsFullScreen: true)
        )
    }

    func testCodexActiveBehaviorCanKeepFullScreenEffect() {
        XCTAssertEqual(
            policy.resolve(
                effect: .fullScreen,
                codexActiveBehavior: .keepSelectedEffect,
                isCodexActive: true
            ),
            CompletionFeedbackPresentation(showsNotch: true, showsFullScreen: true)
        )
    }

    func testCodexActiveBehaviorCanReduceFullScreenEffectToNotch() {
        XCTAssertEqual(
            policy.resolve(
                effect: .fullScreen,
                codexActiveBehavior: .notchOnly,
                isCodexActive: true
            ),
            CompletionFeedbackPresentation(showsNotch: true, showsFullScreen: false)
        )
    }

    func testCodexActiveBehaviorCanHideEffect() {
        XCTAssertEqual(
            policy.resolve(
                effect: .fullScreen,
                codexActiveBehavior: .hide,
                isCodexActive: true
            ),
            .hidden
        )
    }

    func testNotchOnlyAndOffEffectsRemainBounded() {
        XCTAssertEqual(
            policy.resolve(
                effect: .notchOnly,
                codexActiveBehavior: .keepSelectedEffect,
                isCodexActive: false
            ),
            CompletionFeedbackPresentation(showsNotch: true, showsFullScreen: false)
        )
        XCTAssertEqual(
            policy.resolve(
                effect: .off,
                codexActiveBehavior: .keepSelectedEffect,
                isCodexActive: false
            ),
            .hidden
        )
    }

    func testNotificationPolicyAllowsUrgentAttentionDuringQuietMode() {
        let notificationPolicy = TransitionNotificationPolicy()

        XCTAssertTrue(
            notificationPolicy.shouldDeliver(
                state: .needsAttention,
                notificationsEnabled: true,
                quietMode: true,
                urgentAlertsInQuietMode: true
            )
        )
        XCTAssertFalse(
            notificationPolicy.shouldDeliver(
                state: .completed,
                notificationsEnabled: true,
                quietMode: true,
                urgentAlertsInQuietMode: true
            )
        )
        XCTAssertFalse(
            notificationPolicy.shouldDeliver(
                state: .needsAttention,
                notificationsEnabled: true,
                quietMode: true,
                urgentAlertsInQuietMode: false
            )
        )
    }
}
