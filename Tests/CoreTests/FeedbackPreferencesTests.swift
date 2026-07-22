import Foundation
import XCTest
@testable import CodexNotchCore

final class FeedbackPreferencesTests: XCTestCase {
    func testDefaultsUseFullScreenWithNotchOnlyWhileCodexIsActive() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            FeedbackPreferences.load(from: defaults),
            FeedbackPreferences(
                completionEffect: .fullScreen,
                codexActiveBehavior: .notchOnly,
                urgentAlertsInQuietMode: true
            )
        )
    }

    func testPreferencesRoundTripThroughUserDefaults() {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let expected = FeedbackPreferences(
            completionEffect: .notchOnly,
            codexActiveBehavior: .keepSelectedEffect,
            urgentAlertsInQuietMode: false
        )

        expected.persist(to: defaults)

        XCTAssertEqual(FeedbackPreferences.load(from: defaults), expected)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "FeedbackPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
