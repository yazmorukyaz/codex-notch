import Foundation
import SQLite3

struct CodexCatalogChild: Sendable {
    let id: String
    let rolloutPath: String
}

struct CodexCatalogThread: Sendable {
    let id: String
    let title: String
    let workingDirectory: String
    let rolloutPath: String
    let updatedAt: Date
    let children: [CodexCatalogChild]
    let childListIsComplete: Bool
}

enum CodexStateDatabaseError: Error, Sendable {
    case openFailed
    case prepareFailed
    case bindFailed
    case queryFailed
}

struct CodexStateDatabase: Sendable {
    let databaseURL: URL

    func recentThreads(limit: Int, maximumChildrenPerThread: Int) throws -> [CodexCatalogThread] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            if let database {
                sqlite3_close(database)
            }
            throw CodexStateDatabaseError.openFailed
        }
        defer { sqlite3_close(database) }

        let boundedLimit = max(1, min(limit, 100))
        let childLimit = max(1, min(maximumChildrenPerThread, 100))
        var threadStatement: OpaquePointer?
        let threadSQL = """
        SELECT
            t.id,
            CASE
                WHEN TRIM(t.title) <> '' THEN t.title
                WHEN TRIM(t.preview) <> '' THEN t.preview
                ELSE 'Untitled task'
            END,
            t.cwd,
            t.rollout_path,
            COALESCE(NULLIF(t.updated_at_ms, 0), t.updated_at * 1000)
        FROM threads AS t
        WHERE t.archived = 0
          AND t.source = 'vscode'
          AND t.thread_source = 'user'
        ORDER BY
            COALESCE(NULLIF(t.recency_at_ms, 0), NULLIF(t.updated_at_ms, 0), t.updated_at * 1000) DESC,
            t.id DESC
        LIMIT ?
        """

        guard sqlite3_prepare_v2(database, threadSQL, -1, &threadStatement, nil) == SQLITE_OK,
              let threadStatement else {
            throw CodexStateDatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(threadStatement) }

        guard sqlite3_bind_int(threadStatement, 1, Int32(boundedLimit)) == SQLITE_OK else {
            throw CodexStateDatabaseError.bindFailed
        }

        var rows: [(id: String, title: String, cwd: String, rolloutPath: String, updatedAt: Date)] = []
        while true {
            switch sqlite3_step(threadStatement) {
            case SQLITE_ROW:
                let milliseconds = sqlite3_column_int64(threadStatement, 4)
                rows.append((
                    id: text(in: threadStatement, column: 0),
                    title: text(in: threadStatement, column: 1),
                    cwd: text(in: threadStatement, column: 2),
                    rolloutPath: text(in: threadStatement, column: 3),
                    updatedAt: Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
                ))
            case SQLITE_DONE:
                break
            default:
                throw CodexStateDatabaseError.queryFailed
            }

            if sqlite3_data_count(threadStatement) == 0 {
                break
            }
        }

        var childStatement: OpaquePointer?
        let childSQL = """
        SELECT child.id, child.rollout_path
        FROM thread_spawn_edges AS edge
        JOIN threads AS child ON child.id = edge.child_thread_id
        WHERE edge.parent_thread_id = ?
        ORDER BY COALESCE(NULLIF(child.updated_at_ms, 0), child.updated_at * 1000) DESC,
                 child.id DESC
        LIMIT ?
        """
        guard sqlite3_prepare_v2(database, childSQL, -1, &childStatement, nil) == SQLITE_OK,
              let childStatement else {
            throw CodexStateDatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(childStatement) }

        return try rows.map { row in
            sqlite3_reset(childStatement)
            sqlite3_clear_bindings(childStatement)

            let bindTextResult = row.id.withCString { pointer in
                sqlite3_bind_text(
                    childStatement,
                    1,
                    pointer,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }
            guard bindTextResult == SQLITE_OK,
                  sqlite3_bind_int(childStatement, 2, Int32(childLimit + 1)) == SQLITE_OK else {
                throw CodexStateDatabaseError.bindFailed
            }

            var children: [CodexCatalogChild] = []
            while true {
                let result = sqlite3_step(childStatement)
                if result == SQLITE_ROW {
                    children.append(CodexCatalogChild(
                        id: text(in: childStatement, column: 0),
                        rolloutPath: text(in: childStatement, column: 1)
                    ))
                } else if result == SQLITE_DONE {
                    break
                } else {
                    throw CodexStateDatabaseError.queryFailed
                }
            }

            let isComplete = children.count <= childLimit
            if !isComplete {
                children.removeAll()
            }
            return CodexCatalogThread(
                id: row.id,
                title: row.title,
                workingDirectory: row.cwd,
                rolloutPath: row.rolloutPath,
                updatedAt: row.updatedAt,
                children: children,
                childListIsComplete: isComplete
            )
        }
    }

    private func text(in statement: OpaquePointer, column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }
}
