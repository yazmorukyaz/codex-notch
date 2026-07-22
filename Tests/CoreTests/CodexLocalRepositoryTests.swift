import Foundation
import SQLite3
import XCTest
@testable import CodexNotchCore

final class CodexLocalRepositoryTests: XCTestCase {
    func testSnapshotFiltersCatalogAndVerifiesChildrenFromRollouts() async throws {
        let home = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let parentRollout = home.appendingPathComponent("parent.jsonl")
        let activeChildRollout = home.appendingPathComponent("active-child.jsonl")
        let completedChildRollout = home.appendingPathComponent("completed-child.jsonl")
        try writeRollout([
            eventLine(timestamp: "1970-01-01T00:16:40.000Z", payload: [
                "type": "task_started", "turn_id": "parent-turn", "started_at": 1_000
            ]),
            tokenCountLine(timestamp: "1970-01-01T00:16:41.000Z", usedPercent: 31)
        ], to: parentRollout)
        try writeRollout([
            eventLine(timestamp: "1970-01-01T00:16:42.000Z", payload: [
                "type": "task_started", "turn_id": "child-active-turn", "started_at": 1_002
            ])
        ], to: activeChildRollout)
        try writeRollout([
            eventLine(timestamp: "1970-01-01T00:16:42.000Z", payload: [
                "type": "task_started", "turn_id": "child-done-turn", "started_at": 1_002
            ]),
            eventLine(timestamp: "1970-01-01T00:16:43.000Z", payload: [
                "type": "task_complete", "turn_id": "child-done-turn", "completed_at": 1_003
            ])
        ], to: completedChildRollout)

        try createDatabase(
            at: home.appendingPathComponent("state_5.sqlite"),
            parentRollout: parentRollout.path,
            activeChildRollout: activeChildRollout.path,
            completedChildRollout: completedChildRollout.path
        )

        let now = Date(timeIntervalSince1970: 1_050)
        let repository = CodexLocalRepository(
            codexHome: home,
            recentThreadLimit: 10,
            staleAfter: 120,
            clock: { now }
        )

        let snapshot = await repository.snapshot()

        XCTAssertEqual(snapshot.health, .healthy)
        XCTAssertEqual(snapshot.tasks.count, 1)
        let task = try XCTUnwrap(snapshot.tasks.first)
        XCTAssertEqual(task.id, "parent")
        XCTAssertEqual(task.title, "Parent task")
        XCTAssertEqual(task.projectName, "Project")
        XCTAssertEqual(task.state, .working)
        XCTAssertEqual(task.activeTurnID, "parent-turn")
        XCTAssertEqual(task.childAgentCount, 1)
        XCTAssertEqual(snapshot.usageLimits?.primary?.usedPercent, 31)
        XCTAssertEqual(snapshot.usageLimits?.sourceThreadID, "parent")
    }

    func testMissingRolloutUsesCatalogFreshnessForUnverifiedThenStale() async throws {
        let home = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let missingRollout = home.appendingPathComponent("missing.jsonl")
        try createDatabase(
            at: home.appendingPathComponent("state_5.sqlite"),
            parentRollout: missingRollout.path,
            activeChildRollout: home.appendingPathComponent("unused-a.jsonl").path,
            completedChildRollout: home.appendingPathComponent("unused-b.jsonl").path,
            includeChildren: false
        )

        let recentRepository = CodexLocalRepository(
            codexHome: home,
            staleAfter: 120,
            clock: { Date(timeIntervalSince1970: 1_120) }
        )
        let recentSnapshot = await recentRepository.snapshot()

        XCTAssertEqual(recentSnapshot.tasks.count, 1)
        XCTAssertEqual(recentSnapshot.tasks.first?.state, .unverified)
        if case .degraded = recentSnapshot.health {
            // Expected.
        } else {
            XCTFail("Expected degraded source health")
        }

        let staleRepository = CodexLocalRepository(
            codexHome: home,
            staleAfter: 120,
            clock: { Date(timeIntervalSince1970: 1_121) }
        )
        let staleSnapshot = await staleRepository.snapshot()

        XCTAssertEqual(staleSnapshot.tasks.first?.state, .stale)
    }

    func testReadableRolloutWithoutLifecycleIsIdle() async throws {
        let home = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let rollout = home.appendingPathComponent("unknown-lifecycle.jsonl")
        try writeRollout([
            String(repeating: "x", count: 2_048),
            eventLine(timestamp: "1970-01-01T00:17:30.000Z", payload: [
                "type": "agent_reasoning"
            ])
        ], to: rollout)
        try createDatabase(
            at: home.appendingPathComponent("state_5.sqlite"),
            parentRollout: rollout.path,
            activeChildRollout: home.appendingPathComponent("unused-a.jsonl").path,
            completedChildRollout: home.appendingPathComponent("unused-b.jsonl").path,
            includeChildren: false
        )

        let repository = CodexLocalRepository(
            codexHome: home,
            rolloutTailByteLimit: 1_024,
            lifecycleScanByteLimit: 1_024,
            staleAfter: 120,
            clock: { Date(timeIntervalSince1970: 1_060) }
        )

        let snapshot = await repository.snapshot()

        XCTAssertEqual(snapshot.tasks.first?.state, .idle)
        XCTAssertEqual(snapshot.tasks.first?.activityLabel, "Thinking")
        XCTAssertEqual(snapshot.health, .healthy)
    }

    func testUnavailableDatabaseReturnsUnavailableSnapshot() async {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = CodexLocalRepository(codexHome: home)

        let snapshot = await repository.snapshot()

        XCTAssertTrue(snapshot.tasks.isEmpty)
        if case .unavailable = snapshot.health {
            // Expected.
        } else {
            XCTFail("Expected unavailable source health")
        }
    }

    private func createDatabase(
        at url: URL,
        parentRollout: String,
        activeChildRollout: String,
        completedChildRollout: String,
        includeChildren: Bool = true
    ) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw TestDatabaseError.openFailed
        }
        defer { sqlite3_close(database) }

        try execute("""
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            rollout_path TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            updated_at_ms INTEGER,
            recency_at_ms INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL,
            cwd TEXT NOT NULL,
            title TEXT NOT NULL,
            preview TEXT NOT NULL DEFAULT '',
            archived INTEGER NOT NULL DEFAULT 0,
            thread_source TEXT
        );
        CREATE TABLE thread_spawn_edges (
            parent_thread_id TEXT NOT NULL,
            child_thread_id TEXT NOT NULL PRIMARY KEY,
            status TEXT NOT NULL
        );
        """, in: database)

        let parentPath = escaped(parentRollout)
        try execute("""
        INSERT INTO threads VALUES
            ('parent', '\(parentPath)', 1000, 1000000, 1000000, 'vscode', '/tmp/Project', 'Parent task', '', 0, 'user'),
            ('excluded-cli', '\(parentPath)', 1001, 1001000, 1001000, 'cli', '/tmp/Project', 'CLI task', '', 0, 'user'),
            ('excluded-automation', '\(parentPath)', 1002, 1002000, 1002000, 'vscode', '/tmp/Project', 'Automation', '', 0, 'automation'),
            ('excluded-archived', '\(parentPath)', 1003, 1003000, 1003000, 'vscode', '/tmp/Project', 'Archived', '', 1, 'user');
        """, in: database)

        guard includeChildren else { return }
        try execute("""
        INSERT INTO threads VALUES
            ('child-active', '\(escaped(activeChildRollout))', 1004, 1004000, 1004000, 'subagent', '/tmp/Project', 'Active child', '', 0, 'subagent'),
            ('child-complete', '\(escaped(completedChildRollout))', 1005, 1005000, 1005000, 'subagent', '/tmp/Project', 'Complete child', '', 0, 'subagent');
        INSERT INTO thread_spawn_edges VALUES
            ('parent', 'child-active', 'completed'),
            ('parent', 'child-complete', 'running');
        """, in: database)
    }

    private func execute(_ sql: String, in database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            if let errorMessage { sqlite3_free(errorMessage) }
            throw TestDatabaseError.statementFailed
        }
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func writeRollout(_ lines: [String], to url: URL) throws {
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url)
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
        let data = try! JSONSerialization.data(withJSONObject: [
            "timestamp": timestamp,
            "type": "event_msg",
            "payload": payload
        ], options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum TestDatabaseError: Error {
    case openFailed
    case statementFailed
}
