import XCTest
@testable import CodexNotchCore

final class CompletionProjectSummaryTests: XCTestCase {
    func testSingleProjectUsesItsName() {
        XCTAssertEqual(
            CompletionProjectSummary.text(
                for: ["Codex Notch"],
                privacyMode: false
            ),
            "Codex Notch"
        )
    }

    func testDuplicateProjectsAreShownOnce() {
        XCTAssertEqual(
            CompletionProjectSummary.text(
                for: ["Codex Notch", "Codex Notch"],
                privacyMode: false
            ),
            "Codex Notch"
        )
    }

    func testDuplicatesIgnoreCaseAndSurroundingWhitespace() {
        XCTAssertEqual(
            CompletionProjectSummary.text(
                for: [" Codex Notch ", "codex notch", "Blurify"],
                privacyMode: false
            ),
            "Codex Notch + Blurify"
        )
    }

    func testMultipleProjectsPreserveOrderAndBoundTheLabel() {
        XCTAssertEqual(
            CompletionProjectSummary.text(
                for: ["Codex Notch", "Blurify", "SmartTask", "Etsy Machine"],
                privacyMode: false
            ),
            "Codex Notch + Blurify + 2 more"
        )
    }

    func testBlankProjectsUseGenericFallback() {
        XCTAssertEqual(
            CompletionProjectSummary.text(
                for: ["", "  ", "\n"],
                privacyMode: false
            ),
            "Unknown project"
        )
    }

    func testPrivacyModeNeverReturnsAProjectName() {
        let summary = CompletionProjectSummary.text(
            for: ["Secret Client", "Personal Project"],
            privacyMode: true
        )

        XCTAssertEqual(summary, "Private project")
        XCTAssertFalse(summary.contains("Secret Client"))
        XCTAssertFalse(summary.contains("Personal Project"))
    }
}
