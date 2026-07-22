# Codex Notch Local Data Contract

## Scope

Codex Notch is a read-only companion for the installed Codex Desktop app. It does not start tasks, answer approval requests, edit Codex state, or proxy authenticated network traffic.

## Sources

### Task catalog

`~/.codex/state_5.sqlite` is opened with `SQLITE_OPEN_READONLY`. The app reads recent rows from `threads` where:

- `archived = 0`
- `source = 'vscode'`
- `thread_source = 'user'`

Only these fields are consumed: `id`, `rollout_path`, `updated_at`, `cwd`, `title`, and `preview`. Child relationships are read from `thread_spawn_edges`; its `status` column is not treated as live-state evidence.

### Live lifecycle and limits

Each catalog row points to an append-only rollout JSONL file. The parser reads a bounded tail, accepts unknown event types, and consumes only these known envelopes:

- `event_msg.payload.type == task_started`
- `event_msg.payload.type == task_complete`
- `event_msg.payload.type == turn_aborted`
- `event_msg.payload.type == token_count`
- selected event types mapped to fixed, non-sensitive activity labels

Persisted approval requests are labeled **Needs approval**. Persisted user-input
or elicitation requests are labeled **Needs answer**. Both remain attention
states until later rollout evidence changes the task lifecycle.

The latest `token_count.payload.rate_limits` value supplies the real usage windows. The UI labels these values as “used,” displays their reset time, and includes snapshot freshness.

Rollouts may contain user prompts, tool arguments, command output, hidden reasoning metadata, and other sensitive content. Codex Notch never presents those raw values. Unknown fields and event types are ignored.

## State rules

- **Working:** the newest known turn has `task_started` and no later matching `task_complete` or `turn_aborted`.
- **Completed:** the latest explicit terminal event is `task_complete`.
- **Interrupted:** the latest explicit terminal event is `turn_aborted`.
- **Needs approval / Needs answer:** explicit persisted request evidence. The
  app does not infer attention from inactivity.
- **Stale:** a turn still appears open but no new rollout evidence has arrived within the configured threshold. The label says “No recent activity,” not “stuck.”
- **Idle:** there is no current open turn and no terminal state suitable for the recent-finished window.

There is no synthetic completion percentage or guessed ETA.

## Freshness and schema drift

SQLite and rollout files are internal Codex implementation details. Every dashboard refresh has an observation timestamp and source-health state. Missing tables, inaccessible files, malformed tails, or an unknown schema degrade to a visible unavailable/stale state; they do not become “all done.”

The repository polls locally every two seconds and skips unchanged rollout files. It never writes to the database or session files.

## Desktop handoff

The installed Codex application registers the `codex` URL scheme and its packaged UI constructs exact task links in this form:

```text
codex://threads/<thread-id>
```

Codex Notch uses this route for “Open in Codex.” Approval/deny actions remain in Codex Desktop.

## Rejected adapter path

A separately launched `codex app-server --stdio` is not the Desktop app's embedded runtime. In the installed versions tested here, it returned no loaded Desktop tasks and its catalog request degraded on an unknown `automation` source. It also initiates authenticated product connections. The MVP therefore does not launch or attach to app-server.
