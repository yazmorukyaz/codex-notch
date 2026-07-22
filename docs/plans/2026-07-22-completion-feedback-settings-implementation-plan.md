# Completion Feedback Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add persistent completion-effect preferences, Codex-active behavior,
preview support, urgent Quiet Mode alerts, and clearer approval-versus-answer
labels.

**Architecture:** Keep persisted user preferences in the existing observable
DashboardStore. Put the combinatorial completion and notification decisions in
CodexNotchCore, then let AppRuntime apply those decisions using the frontmost
macOS application. Keep SwiftUI declarative by binding Settings controls
directly to the store.

**Tech Stack:** Swift 6, SwiftUI, Observation, AppKit NSWorkspace, UserDefaults,
XCTest, XcodeGen.

---

### Task 1: Add testable feedback policies

**Files:**
- Create: `Sources/Core/Feedback/CompletionFeedbackPolicy.swift`
- Create: `Tests/CoreTests/CompletionFeedbackPolicyTests.swift`

**Steps:**

1. Write failing matrix tests for Full screen, Notch only, and Off with each
   Codex-active behavior.
2. Write failing tests for Quiet Mode notification delivery with urgent bypass
   enabled and disabled.
3. Run `xcodebuild -project CodexNotch.xcodeproj -scheme CodexNotchCoreTests -destination 'platform=macOS' -derivedDataPath build/Tests test` and confirm the new types are missing.
4. Add raw-value preference enums, a completion presentation result, and pure
   completion/notification policies.
5. Rerun the Core tests and confirm they pass.

### Task 2: Persist preferences and refine attention labels

**Files:**
- Modify: `Sources/App/State/DashboardStore.swift`
- Modify: `Sources/Core/Services/RolloutParser.swift`
- Modify: `Sources/App/Services/NotificationCoordinator.swift`
- Modify: `Tests/CoreTests/RolloutParserTests.swift`
- Create: `Tests/CoreTests/FeedbackPreferencesTests.swift`

**Steps:**

1. Add failing parser tests for Needs approval and Needs answer.
2. Add preference round-trip tests with an isolated UserDefaults suite.
3. Persist Full screen, Notch only while Codex is active, and urgent Quiet Mode
   alerts as defaults.
4. Route notification transitions through the new Quiet Mode policy.
5. Use the safe activity label to produce Approval required or Answer required
   notification copy without exposing request contents.
6. Run the focused Core tests and confirm they pass.

### Task 3: Apply runtime presentation policy

**Files:**
- Create: `Sources/App/Services/CodexApplicationDetector.swift`
- Modify: `Sources/App/State/AppRuntime.swift`
- Modify: `Sources/App/Window/CompletionOverlayCoordinator.swift`

**Steps:**

1. Detect Codex using its bundle identifier when available and a conservative
   localized-name fallback.
2. Resolve each completion through CompletionFeedbackPolicy.
3. Set compact celebration state only when notch feedback is allowed.
4. Present the overlay only when full-screen feedback is allowed.
5. Add a preview method that uses the selected base effect and demo project
   data.
6. Build the app and fix any actor-isolation or Observation errors.

### Task 4: Build the settings interface

**Files:**
- Modify: `Sources/App/Views/SettingsView.swift`
- Modify: `Sources/App/Views/NotchRootView.swift`
- Modify: `Tests/UITests/ExpandedSurfaceTransitionUITests.swift`

**Steps:**

1. Add failing UI assertions for Completion feedback, Completion effect, While
   Codex is active, Preview animation, and Urgent alerts in Quiet Mode.
2. Add compact segmented-control rows and the preview action.
3. Disable the Codex-active picker and preview when the completion effect is
   Off.
4. Preserve adaptive settings height and confirm no clipping at the geometry
   maximum.
5. Build and run the UI test when GUI automation is available.

### Task 5: Verify and publish

**Files:**
- Modify: `README.md`
- Modify: `docs/technical-notes.md`

**Steps:**

1. Document the completion preferences and exact Needs You event boundary.
2. Run Core tests, the app build, and `git diff --check`.
3. Launch the Settings demo and capture a deterministic preview if the live GUI
   is available.
4. Commit the implementation and push `main` only after all required checks
   pass.
