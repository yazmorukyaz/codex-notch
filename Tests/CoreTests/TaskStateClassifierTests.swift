import XCTest
@testable import CodexNotchCore

final class TaskStateClassifierTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)
    private let classifier = TaskStateClassifier(staleAfter: 120)

    func testOpenRecentTurnIsWorking() {
        let evidence = TaskStateEvidence(
            latestTurnStartedAt: now.addingTimeInterval(-60),
            lastActivityAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(classifier.classify(evidence, now: now), .working)
    }

    func testOpenInactiveTurnIsStale() {
        let evidence = TaskStateEvidence(
            latestTurnStartedAt: now.addingTimeInterval(-300),
            lastActivityAt: now.addingTimeInterval(-180)
        )

        XCTAssertEqual(classifier.classify(evidence, now: now), .stale)
    }

    func testExplicitAttentionWinsForOpenTurn() {
        let evidence = TaskStateEvidence(
            latestTurnStartedAt: now.addingTimeInterval(-60),
            attentionSince: now.addingTimeInterval(-20),
            lastActivityAt: now.addingTimeInterval(-20)
        )

        XCTAssertEqual(classifier.classify(evidence, now: now), .needsAttention)
    }

    func testExplicitCompletionIsCompleted() {
        let evidence = TaskStateEvidence(
            latestTurnStartedAt: now.addingTimeInterval(-60),
            latestTurnFinishedAt: now.addingTimeInterval(-10),
            terminalKind: .completed,
            lastActivityAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(classifier.classify(evidence, now: now), .completed)
    }

    func testExplicitAbortIsInterrupted() {
        let evidence = TaskStateEvidence(
            latestTurnStartedAt: now.addingTimeInterval(-60),
            latestTurnFinishedAt: now.addingTimeInterval(-10),
            terminalKind: .interrupted,
            lastActivityAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(classifier.classify(evidence, now: now), .interrupted)
    }

    func testMissingEvidenceIsIdle() {
        XCTAssertEqual(classifier.classify(TaskStateEvidence(), now: now), .idle)
    }
}
