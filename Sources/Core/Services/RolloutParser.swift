import Foundation

struct RolloutTailSnapshot: Sendable {
    let evidence: TaskStateEvidence
    let activeTurnID: String?
    let activityLabel: String?
    let usageLimits: UsageLimitsSnapshot?
    let hasLifecycleEvidence: Bool
    let lifecycleIsKnown: Bool

    var hasActiveTurn: Bool {
        guard let startedAt = evidence.latestTurnStartedAt else { return false }
        guard let finishedAt = evidence.latestTurnFinishedAt else { return true }
        return startedAt > finishedAt
    }
}

enum RolloutParserError: Error, Sendable {
    case unreadableFile
}

struct RolloutParser: Sendable {
    let tailByteLimit: Int
    let lifecycleScanByteLimit: Int

    private static let lifecycleMarkers = [
        Data("\"task_started\"".utf8),
        Data("\"task_complete\"".utf8),
        Data("\"turn_aborted\"".utf8)
    ]

    init(
        tailByteLimit: Int = 256 * 1_024,
        lifecycleScanByteLimit: Int = 4 * 1_024 * 1_024
    ) {
        self.tailByteLimit = max(1_024, tailByteLimit)
        self.lifecycleScanByteLimit = max(self.tailByteLimit, lifecycleScanByteLimit)
    }

    func parseTail(
        at url: URL,
        sourceThreadID: String,
        previousSnapshot: RolloutTailSnapshot? = nil,
        previousFileSize: UInt64? = nil
    ) throws -> RolloutTailSnapshot {
        let initialTail = try readTail(at: url, maximumBytes: tailByteLimit)
        let parsed = parse(initialTail.data, sourceThreadID: sourceThreadID)

        guard !parsed.hasLifecycleEvidence, initialTail.wasTruncated else {
            return parsed.withLifecycleKnown(true)
        }

        if let previousSnapshot,
           previousSnapshot.lifecycleIsKnown,
           let previousFileSize,
           previousFileSize <= initialTail.fileSize {
            let lookback = UInt64(lifecycleScanByteLimit)
            let lowerBound = previousFileSize > lookback
                ? previousFileSize - lookback
                : 0
            if let lifecycle = try latestLifecycleSnapshot(
                at: url,
                sourceThreadID: sourceThreadID,
                lowerBound: lowerBound,
                upperBound: initialTail.fileSize
            ) {
                return parsed.applyingLifecycle(from: lifecycle)
            }
            return parsed.applyingLifecycle(from: previousSnapshot)
        }

        if let lifecycle = try latestLifecycleSnapshot(
            at: url,
            sourceThreadID: sourceThreadID,
            lowerBound: 0,
            upperBound: initialTail.fileSize
        ) {
            return parsed.applyingLifecycle(from: lifecycle)
        }

        return parsed.withLifecycleKnown(true)
    }

    func parse(_ data: Data, sourceThreadID: String) -> RolloutTailSnapshot {
        var latestStartedAt: Date?
        var latestStartedTurnID: String?
        var latestFinishedAt: Date?
        var terminalKind: TaskTerminalKind?
        var lastActivityAt: Date?
        var activityLabel: String?
        var activityLabelAt: Date?
        var latestUsageLimits: UsageLimitsSnapshot?
        var hasLifecycleEvidence = false

        for rawLine in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard let envelope = try? JSONSerialization.jsonObject(with: Data(rawLine)),
                  let object = envelope as? [String: Any] else {
                continue
            }

            let envelopeTimestamp = date(fromISO8601: object["timestamp"] as? String)
            if let envelopeTimestamp,
               envelopeTimestamp > (lastActivityAt ?? .distantPast) {
                lastActivityAt = envelopeTimestamp
            }

            guard object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let eventType = payload["type"] as? String else {
                continue
            }

            switch eventType {
            case "task_started":
                guard let startedAt = epochDate(payload["started_at"]) ?? envelopeTimestamp else {
                    break
                }
                if startedAt >= (latestStartedAt ?? .distantPast) {
                    latestStartedAt = startedAt
                    latestStartedTurnID = payload["turn_id"] as? String
                }
                hasLifecycleEvidence = true

            case "task_complete":
                guard let completedAt = epochDate(payload["completed_at"]) ?? envelopeTimestamp else {
                    break
                }
                if completedAt >= (latestFinishedAt ?? .distantPast) {
                    latestFinishedAt = completedAt
                    terminalKind = .completed
                }
                hasLifecycleEvidence = true

            case "turn_aborted":
                guard let completedAt = epochDate(payload["completed_at"]) ?? envelopeTimestamp else {
                    break
                }
                if completedAt >= (latestFinishedAt ?? .distantPast) {
                    latestFinishedAt = completedAt
                    terminalKind = .interrupted
                }
                hasLifecycleEvidence = true

            case "token_count":
                if let envelopeTimestamp {
                    latestUsageLimits = usageLimits(
                        from: payload["rate_limits"],
                        capturedAt: envelopeTimestamp,
                        sourceThreadID: sourceThreadID
                    )
                }

            default:
                break
            }

            if let label = safeActivityLabel(for: eventType),
               let labelTimestamp = envelopeTimestamp,
               labelTimestamp >= (activityLabelAt ?? .distantPast) {
                activityLabel = label
                activityLabelAt = labelTimestamp
            }
        }

        let hasOpenTurn: Bool
        if let latestStartedAt {
            hasOpenTurn = latestStartedAt > (latestFinishedAt ?? .distantPast)
        } else {
            hasOpenTurn = false
        }

        return RolloutTailSnapshot(
            evidence: TaskStateEvidence(
                latestTurnStartedAt: latestStartedAt,
                latestTurnFinishedAt: latestFinishedAt,
                terminalKind: terminalKind,
                attentionSince: activityLabel == "Needs attention" ? activityLabelAt : nil,
                lastActivityAt: lastActivityAt
            ),
            activeTurnID: hasOpenTurn ? latestStartedTurnID : nil,
            activityLabel: activityLabel,
            usageLimits: latestUsageLimits,
            hasLifecycleEvidence: hasLifecycleEvidence,
            lifecycleIsKnown: true
        )
    }

    private func readTail(at url: URL, maximumBytes: Int) throws -> TailRead {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw RolloutParserError.unreadableFile
        }
        defer { try? handle.close() }

        do {
            let endOffset = try handle.seekToEnd()
            let boundedBytes = UInt64(maximumBytes)
            let wasTruncated = endOffset > boundedBytes
            let startOffset = wasTruncated ? endOffset - boundedBytes : 0
            let readOffset = startOffset > 0 ? startOffset - 1 : 0
            try handle.seek(toOffset: readOffset)

            let requestedBytes = maximumBytes + (startOffset > 0 ? 1 : 0)
            var data = try handle.read(upToCount: requestedBytes) ?? Data()
            if startOffset > 0, !data.isEmpty {
                let precedingByte = data.removeFirst()
                if precedingByte != 0x0A {
                    if let newline = data.firstIndex(of: 0x0A) {
                        data.removeSubrange(data.startIndex...newline)
                    } else {
                        data.removeAll(keepingCapacity: false)
                    }
                }
            }
            return TailRead(
                data: data,
                wasTruncated: wasTruncated,
                fileSize: endOffset
            )
        } catch {
            throw RolloutParserError.unreadableFile
        }
    }

    /// Walks fixed-size chunks toward the beginning of an append-only rollout
    /// and stops as soon as the newest explicit lifecycle record is found.
    /// Raw prompt, reasoning, command, and tool-output fields are never retained.
    private func latestLifecycleSnapshot(
        at url: URL,
        sourceThreadID: String,
        lowerBound: UInt64,
        upperBound: UInt64
    ) throws -> RolloutTailSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw RolloutParserError.unreadableFile
        }
        defer { try? handle.close() }

        do {
            let fileSize = try handle.seekToEnd()
            let scanEnd = min(fileSize, upperBound)
            let scanStart = min(lowerBound, scanEnd)
            let chunkSize = UInt64(lifecycleScanByteLimit)
            var cursor = scanEnd
            var trailingFragment = Data()

            while cursor > scanStart {
                let available = cursor - scanStart
                let chunkStart = cursor - min(available, chunkSize)
                try handle.seek(toOffset: chunkStart)
                let byteCount = Int(cursor - chunkStart)
                let chunk = try handle.read(upToCount: byteCount) ?? Data()
                guard !chunk.isEmpty else {
                    throw RolloutParserError.unreadableFile
                }

                var combined = chunk
                combined.append(trailingFragment)

                let completeLines: Data
                if chunkStart == 0 {
                    completeLines = combined
                    trailingFragment.removeAll(keepingCapacity: false)
                } else if let firstNewline = combined.firstIndex(of: 0x0A) {
                    let firstCompleteByte = combined.index(after: firstNewline)
                    completeLines = Data(combined[firstCompleteByte...])
                    trailingFragment = Data(combined[..<firstCompleteByte])
                } else {
                    trailingFragment = combined
                    cursor = chunkStart
                    continue
                }

                if let lifecycle = latestLifecycleSnapshot(
                    in: completeLines,
                    sourceThreadID: sourceThreadID
                ) {
                    return lifecycle
                }
                cursor = chunkStart
            }

            return nil
        } catch let error as RolloutParserError {
            throw error
        } catch {
            throw RolloutParserError.unreadableFile
        }
    }

    private func latestLifecycleSnapshot(
        in data: Data,
        sourceThreadID: String
    ) -> RolloutTailSnapshot? {
        var candidateLines = Data()

        for rawLine in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            let line = Data(rawLine)
            guard Self.lifecycleMarkers.contains(where: { marker in
                line.range(of: marker) != nil
            }) else {
                continue
            }
            candidateLines.append(line)
            candidateLines.append(0x0A)
        }

        guard !candidateLines.isEmpty else { return nil }
        let snapshot = parse(candidateLines, sourceThreadID: sourceThreadID)
        return snapshot.hasLifecycleEvidence ? snapshot : nil
    }

    private func safeActivityLabel(for eventType: String) -> String? {
        switch eventType {
        case "task_started":
            return "Working"
        case "task_complete":
            return "Completed"
        case "turn_aborted":
            return "Interrupted"
        case "agent_reasoning":
            return "Thinking"
        case "agent_message":
            return "Responding"
        case "exec_command_begin", "exec_command_end":
            return "Running command"
        case "patch_apply_begin", "patch_apply_end":
            return "Editing files"
        case "mcp_tool_call_begin", "mcp_tool_call_end":
            return "Using tool"
        case "sub_agent_activity",
             "collab_agent_spawn_begin", "collab_agent_spawn_end",
             "collab_agent_interaction_begin", "collab_agent_interaction_end",
             "collab_waiting_begin", "collab_waiting_end":
            return "Coordinating agents"
        case "exec_approval_request", "apply_patch_approval_request",
             "request_user_input", "elicitation_request":
            return "Needs attention"
        default:
            return nil
        }
    }

    private func usageLimits(
        from value: Any?,
        capturedAt: Date,
        sourceThreadID: String
    ) -> UsageLimitsSnapshot? {
        guard let rateLimits = value as? [String: Any],
              let limitID = rateLimits["limit_id"] as? String else {
            return nil
        }

        return UsageLimitsSnapshot(
            limitID: limitID,
            planType: rateLimits["plan_type"] as? String,
            primary: usageWindow(from: rateLimits["primary"]),
            secondary: usageWindow(from: rateLimits["secondary"]),
            capturedAt: capturedAt,
            sourceThreadID: sourceThreadID
        )
    }

    private func usageWindow(from value: Any?) -> UsageWindowSnapshot? {
        guard let window = value as? [String: Any],
              let usedPercent = number(window["used_percent"]),
              let windowMinutes = number(window["window_minutes"]) else {
            return nil
        }

        return UsageWindowSnapshot(
            usedPercent: usedPercent,
            windowMinutes: Int(windowMinutes),
            resetsAt: epochDate(window["resets_at"])
        )
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func epochDate(_ value: Any?) -> Date? {
        guard let seconds = number(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private func date(fromISO8601 value: String?) -> Date? {
        guard let value else { return nil }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }
}

private struct TailRead {
    let data: Data
    let wasTruncated: Bool
    let fileSize: UInt64
}

private extension RolloutTailSnapshot {
    func withLifecycleKnown(_ lifecycleIsKnown: Bool) -> RolloutTailSnapshot {
        RolloutTailSnapshot(
            evidence: evidence,
            activeTurnID: activeTurnID,
            activityLabel: activityLabel,
            usageLimits: usageLimits,
            hasLifecycleEvidence: hasLifecycleEvidence,
            lifecycleIsKnown: lifecycleIsKnown
        )
    }

    func applyingLifecycle(from lifecycle: RolloutTailSnapshot) -> RolloutTailSnapshot {
        RolloutTailSnapshot(
            evidence: TaskStateEvidence(
                latestTurnStartedAt: lifecycle.evidence.latestTurnStartedAt,
                latestTurnFinishedAt: lifecycle.evidence.latestTurnFinishedAt,
                terminalKind: lifecycle.evidence.terminalKind,
                attentionSince: evidence.attentionSince,
                lastActivityAt: evidence.lastActivityAt
            ),
            activeTurnID: lifecycle.activeTurnID,
            activityLabel: activityLabel ?? lifecycle.activityLabel,
            usageLimits: usageLimits,
            hasLifecycleEvidence: lifecycle.hasLifecycleEvidence,
            lifecycleIsKnown: lifecycle.lifecycleIsKnown
        )
    }
}
