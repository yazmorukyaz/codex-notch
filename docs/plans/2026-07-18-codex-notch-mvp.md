# Codex Notch MVP Implementation Plan

> **For Codex:** Implement this plan task-by-task in the current workspace, verifying after each slice.

**Goal:** Build a native macOS quiet supervisor that shows recent Codex tasks across projects, distinguishes working/done/interrupted/stale states honestly, displays real account limit windows, and expands from the MacBook notch with a menu-bar fallback.

**Architecture:** A SwiftUI dashboard is hosted in a small AppKit panel positioned from the active screen's top safe-area geometry. `CodexNotchCore` owns the models, conservative state classification, SQLite catalog reader, and bounded rollout JSONL parser. The app reads Codex's existing local state in read-only mode, records freshness on every snapshot, and hands a task back to Codex through the installed `codex://threads/<id>` route.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Observation, UserNotifications, SQLite3, XcodeGen, XCTest. No third-party dependencies and no network service.

---

### Task 1: Document the local Codex contract

**Files:**
- Create: `docs/technical-notes.md`

1. Record which SQLite and rollout fields are used.
2. Define the conservative working/completed/interrupted/stale rules.
3. Document freshness, schema-drift, privacy, and deep-link boundaries.

Expected: every user-visible claim has a local evidence source and fallback.

### Task 2: Scaffold app and test targets

**Files:**
- Create: `project.yml`
- Create: `Resources/Info.plist`
- Create: `Sources/Core/Models/*.swift`
- Create: `Sources/App/CodexNotchApp.swift`
- Create: `Tests/CoreTests/*.swift`

1. Define `CodexNotchCore`, `CodexNotch`, and `CodexNotchCoreTests` targets in XcodeGen.
2. Set macOS 14+, `LSUIElement`, Swift 6, and no app sandbox so the app can read the user's local Codex state.
3. Generate the Xcode project and confirm all targets are visible.

Expected: the generated project builds a menu-bar application and the core test bundle runs independently of `@main`.

### Task 3: Implement and test the local repository

**Files:**
- Create: `Sources/Core/Services/CodexStateDatabase.swift`
- Create: `Sources/Core/Services/RolloutParser.swift`
- Create: `Sources/Core/Services/CodexLocalRepository.swift`
- Create: `Sources/Core/Services/TaskStateClassifier.swift`
- Test: `Tests/CoreTests/RolloutParserTests.swift`
- Test: `Tests/CoreTests/TaskStateClassifierTests.swift`

1. Open `~/.codex/state_5.sqlite` with `SQLITE_OPEN_READONLY`.
2. Query only unarchived primary user tasks and never modify Codex state.
3. Read only a bounded tail of each rollout and accept unknown/additive JSON fields.
4. Derive working only from an unmatched `task_started`; derive done/interrupted only from explicit terminal events.
5. Extract the latest real `token_count.rate_limits` snapshot.
6. Cache file modification metadata and expose source health/freshness.

Expected: the repository follows live Desktop tasks without launching another Codex runtime.

### Task 4: Build the quiet-supervisor dashboard

**Files:**
- Create: `Sources/App/State/DashboardStore.swift`
- Create: `Sources/App/Views/DashboardView.swift`
- Create: `Sources/App/Views/CompactStatusView.swift`
- Create: `Sources/App/Views/TaskRowView.swift`
- Create: `Sources/App/Views/UsageLimitsView.swift`
- Create: `Sources/App/Views/SettingsView.swift`

1. Render collapsed counts for working and recently finished tasks.
2. Render expanded groups in priority order: Needs You, Working, Recently Finished, Other.
3. Show task/project identity, child-agent count, safe activity labels, and relative last activity.
4. Show primary/secondary usage windows with explicit “used” labels, reset times, and freshness.
5. Add loading, empty, unavailable, stale, demo, and privacy-redacted states.

Expected: demo mode covers every important visual state without requiring a live Codex task.

### Task 5: Implement the notch shell and menu-bar fallback

**Files:**
- Create: `Sources/App/Window/NotchPanel.swift`
- Create: `Sources/App/Window/PanelGeometry.swift`
- Create: `Sources/App/Window/PanelCoordinator.swift`
- Test: `Tests/CoreTests/PanelGeometryTests.swift`

1. Test frame calculations for notched, notchless, external, and negatively positioned displays.
2. Host the dashboard in a borderless `NSPanel` at status-bar level.
3. Anchor to the screen's top safe area instead of hard-coded physical notch dimensions.
4. Provide click/keyboard expansion, Escape/outside-click collapse, Reduce Motion behavior, and a menu-bar fallback.

Expected: the compact surface remains unobtrusive and the expanded surface is reachable on every display.

### Task 6: Add handoff, notifications, and privacy controls

1. Open exact tasks with `codex://threads/<thread-id>`.
2. Notify only on new completed/interrupted transitions and deduplicate them.
3. Add privacy mode, quiet mode, refresh, and Quit/Open Dashboard actions.
4. Render only known safe activity labels, never raw tool output or hidden reasoning.

Expected: healthy activity remains quiet and task details can be hidden instantly.

### Task 7: Verify behavior and appearance

1. Run `xcodegen generate`.
2. Run the core test scheme and expect zero failures.
3. Build the app and expect `** BUILD SUCCEEDED **`.
4. Launch demo mode and inspect a screenshot.
5. Launch live mode and compare its task states and limits against the current rollout evidence.

Expected: tests pass, the app launches, the panel is legible, and unavailable state is labeled rather than guessed.
