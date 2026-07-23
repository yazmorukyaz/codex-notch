import Foundation
import XCTest
@testable import CodexNotchCore

final class RolloutParserTests: XCTestCase {
    func testExplicitStartAndLatestRateLimitsProduceActiveSnapshot() throws {
        let data = joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started",
                "turn_id": "turn-1",
                "started_at": 1_000,
                "unknown": "ignored"
            ]),
            eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
                "type": "agent_reasoning",
                "text": "private reasoning must not be surfaced"
            ]),
            tokenCountLine(timestamp: "1970-01-01T00:16:42.000Z", usedPercent: 2),
            tokenCountLine(timestamp: "1970-01-01T00:16:43.000Z", usedPercent: 7)
        ])

        let snapshot = RolloutParser().parse(data, sourceThreadID: "thread-1")

        XCTAssertTrue(snapshot.hasLifecycleEvidence)
        XCTAssertTrue(snapshot.hasActiveTurn)
        XCTAssertEqual(snapshot.activeTurnID, "turn-1")
        XCTAssertEqual(snapshot.activityLabel, "Thinking")
        XCTAssertEqual(snapshot.usageLimits?.primary?.usedPercent, 7)
        XCTAssertEqual(snapshot.usageLimits?.sourceThreadID, "thread-1")
    }

    func testTerminalLifecycleUsesOnlyExplicitEventTypes() throws {
        let data = joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started", "turn_id": "turn-1", "started_at": 1_000
            ]),
            eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
                "type": "unknown_event",
                "message": "task_complete turn_aborted Completed"
            ]),
            eventLine(timestamp: "1970-01-01T00:16:50.000Z", payload: [
                "type": "turn_aborted", "turn_id": "turn-1", "completed_at": 1_010
            ])
        ])

        let snapshot = RolloutParser().parse(data, sourceThreadID: "thread-1")

        XCTAssertFalse(snapshot.hasActiveTurn)
        if case .interrupted? = snapshot.evidence.terminalKind {
            // Expected.
        } else {
            XCTFail("Expected the explicit turn_aborted event to mark the task interrupted")
        }
        XCTAssertEqual(snapshot.activityLabel, "Interrupted")
    }

    func testMalformedLinesAndUnknownFieldsAreIgnoredAndLabelsStayFixed() throws {
        var data = Data("not-json-at-the-tail-boundary\n".utf8)
        data.append(joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "agent_message",
                "message": "SECRET USER CONTENT"
            ]),
            "{malformed-json",
            eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
                "type": "future_event",
                "activity_label": "SECRET USER CONTENT"
            ])
        ]))

        let snapshot = RolloutParser().parse(data, sourceThreadID: "thread-1")

        XCTAssertEqual(snapshot.activityLabel, "Responding")
        XCTAssertNotEqual(snapshot.activityLabel, "SECRET USER CONTENT")
        XCTAssertFalse(snapshot.hasLifecycleEvidence)
    }

    func testExplicitAttentionEventSetsAttentionUntilSafeProgressResumes() throws {
        let start = eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
            "type": "task_started", "turn_id": "turn-1", "started_at": 1_000
        ])
        let request = eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
            "type": "exec_approval_request",
            "command": "private command must not be surfaced"
        ])
        let parser = RolloutParser()

        let waiting = parser.parse(joinedLines([start, request]), sourceThreadID: "thread-1")

        XCTAssertEqual(waiting.activityLabel, "Needs approval")
        XCTAssertNotNil(waiting.evidence.attentionSince)
        XCTAssertEqual(
            TaskStateClassifier().classify(
                waiting.evidence,
                now: Date(timeIntervalSince1970: 1_003)
            ),
            .needsAttention
        )

        let resumed = parser.parse(joinedLines([
            start,
            request,
            eventLine(timestamp: "1970-01-01T00:16:42.000Z", payload: [
                "type": "exec_command_begin",
                "command": "private command must not be surfaced"
            ])
        ]), sourceThreadID: "thread-1")

        XCTAssertEqual(resumed.activityLabel, "Running command")
        XCTAssertNil(resumed.evidence.attentionSince)
    }

    func testUserInputAttentionIsLabeledNeedsAnswer() throws {
        let data = joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started", "turn_id": "turn-1", "started_at": 1_000
            ]),
            eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
                "type": "request_user_input",
                "questions": "private question content must not be surfaced"
            ])
        ])

        let snapshot = RolloutParser().parse(data, sourceThreadID: "thread-1")

        XCTAssertEqual(snapshot.activityLabel, "Needs answer")
        XCTAssertNotNil(snapshot.evidence.attentionSince)
        XCTAssertEqual(
            TaskStateClassifier().classify(
                snapshot.evidence,
                now: Date(timeIntervalSince1970: 1_003)
            ),
            .needsAttention
        )
    }

    func testRealFunctionCallApprovalIsAttentionUntilMatchingOutputArrives() throws {
        let start = eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
            "type": "task_started", "turn_id": "turn-1", "started_at": 1_000
        ])
        let approval = responseItemLine(
            timestamp: "1970-01-01T00:16:41.000Z",
            payload: [
                "type": "function_call",
                "name": "exec_command",
                "call_id": "call-approval",
                "arguments": jsonString([
                    "cmd": "private command must not be surfaced",
                    "sandbox_permissions": "require_escalated",
                    "justification": "Approval is required"
                ])
            ]
        )
        let parser = RolloutParser()

        let waiting = parser.parse(joinedLines([start, approval]), sourceThreadID: "thread-1")

        XCTAssertEqual(waiting.activityLabel, "Needs approval")
        XCTAssertNotNil(waiting.evidence.attentionSince)
        XCTAssertEqual(
            TaskStateClassifier().classify(
                waiting.evidence,
                now: Date(timeIntervalSince1970: 1_003)
            ),
            .needsAttention
        )

        let resolved = parser.parse(joinedLines([
            start,
            approval,
            responseItemLine(
                timestamp: "1970-01-01T00:16:42.000Z",
                payload: [
                    "type": "function_call_output",
                    "call_id": "call-approval",
                    "output": "private output must not be surfaced"
                ]
            )
        ]), sourceThreadID: "thread-1")

        XCTAssertEqual(resolved.activityLabel, "Working")
        XCTAssertNil(resolved.evidence.attentionSince)
    }

    func testRealRequestUserInputFunctionCallIsLabeledNeedsAnswer() throws {
        let snapshot = RolloutParser().parse(joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started", "turn_id": "turn-1", "started_at": 1_000
            ]),
            responseItemLine(
                timestamp: "1970-01-01T00:16:41.000Z",
                payload: [
                    "type": "function_call",
                    "name": "request_user_input",
                    "call_id": "call-input",
                    "arguments": jsonString([
                        "questions": "private question content must not be surfaced"
                    ])
                ]
            )
        ]), sourceThreadID: "thread-1")

        XCTAssertEqual(snapshot.activityLabel, "Needs answer")
        XCTAssertNotNil(snapshot.evidence.attentionSince)
    }

    func testExpandedBoundedScanFindsLongRunningStart() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutURL = directory.appendingPathComponent("rollout.jsonl")
        let start = eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
            "type": "task_started", "turn_id": "turn-long", "started_at": 1_000
        ])
        let filler = String(repeating: "x", count: 2_000)
        let later = eventLine(timestamp: "1970-01-01T00:16:45.000Z", payload: [
            "type": "future_event", "padding": filler
        ])
        try joinedLines([start, later]).write(to: rolloutURL)

        let parser = RolloutParser(tailByteLimit: 1_024, lifecycleScanByteLimit: 4_096)
        let snapshot = try parser.parseTail(at: rolloutURL, sourceThreadID: "thread-1")

        XCTAssertTrue(snapshot.lifecycleIsKnown)
        XCTAssertTrue(snapshot.hasActiveTurn)
        XCTAssertEqual(snapshot.activeTurnID, "turn-long")
    }

    func testBackwardScanFindsLifecycleBeyondChunkSize() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutURL = directory.appendingPathComponent("rollout.jsonl")
        let oldStart = eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
            "type": "task_started", "turn_id": "turn-old", "started_at": 1_000
        ])
        let oldComplete = eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
            "type": "task_complete", "turn_id": "turn-old", "completed_at": 1_001
        ])
        let activeStart = eventLine(timestamp: "1970-01-01T00:16:42.000Z", payload: [
            "type": "task_started", "turn_id": "turn-active", "started_at": 1_002
        ])
        let filler = eventLine(timestamp: "1970-01-01T00:16:45.000Z", payload: [
            "type": "future_event", "padding": String(repeating: "x", count: 5_000)
        ])
        try joinedLines([oldStart, oldComplete, activeStart, filler]).write(to: rolloutURL)

        let parser = RolloutParser(tailByteLimit: 1_024, lifecycleScanByteLimit: 2_048)
        let snapshot = try parser.parseTail(at: rolloutURL, sourceThreadID: "thread-1")

        XCTAssertTrue(snapshot.lifecycleIsKnown)
        XCTAssertTrue(snapshot.hasLifecycleEvidence)
        XCTAssertTrue(snapshot.hasActiveTurn)
        XCTAssertEqual(snapshot.activeTurnID, "turn-active")
    }

    func testIncrementalScanFindsTerminalEventOutsideRecentTail() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutURL = directory.appendingPathComponent("rollout.jsonl")
        let initialData = joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started", "turn_id": "turn-active", "started_at": 1_000
            ]),
            eventLine(timestamp: "1970-01-01T00:16:41.000Z", payload: [
                "type": "future_event", "padding": String(repeating: "x", count: 5_000)
            ])
        ])
        try initialData.write(to: rolloutURL)

        let parser = RolloutParser(tailByteLimit: 1_024, lifecycleScanByteLimit: 2_048)
        let active = try parser.parseTail(at: rolloutURL, sourceThreadID: "thread-1")
        XCTAssertTrue(active.hasActiveTurn)

        let appendedData = joinedLines([
            eventLine(timestamp: "1970-01-01T00:16:42.000Z", payload: [
                "type": "task_complete", "turn_id": "turn-active", "completed_at": 1_002
            ]),
            eventLine(timestamp: "1970-01-01T00:16:43.000Z", payload: [
                "type": "future_event", "padding": String(repeating: "y", count: 5_000)
            ])
        ])
        let handle = try FileHandle(forWritingTo: rolloutURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: appendedData)
        try handle.close()

        let completed = try parser.parseTail(
            at: rolloutURL,
            sourceThreadID: "thread-1",
            previousSnapshot: active,
            previousFileSize: UInt64(initialData.count)
        )

        XCTAssertFalse(completed.hasActiveTurn)
        if case .completed? = completed.evidence.terminalKind {
            // Expected.
        } else {
            XCTFail("Expected the appended task_complete event to win")
        }
    }

    private func tokenCountLine(timestamp: String, usedPercent: Double) -> String {
        eventLine(timestamp: timestamp, payload: [
            "type": "token_count",
            "rate_limits": [
                "limit_id": "codex",
                "plan_type": "pro",
                "primary": [
                    "used_percent": usedPercent,
                    "window_minutes": 10_080,
                    "resets_at": 2_000
                ]
            ]
        ])
    }

    private func eventLine(timestamp: String, payload: [String: Any]) -> String {
        let object: [String: Any] = [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": payload
        ]
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func responseItemLine(timestamp: String, payload: [String: Any]) -> String {
        let object: [String: Any] = [
            "timestamp": timestamp,
            "type": "response_item",
            "payload": payload
        ]
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func jsonString(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func joinedLines(_ lines: [String]) -> Data {
        Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
