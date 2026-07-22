# Completion Feedback Settings Design

## Goal

Give users predictable control over completion feedback without weakening the
persistent signals for approval and answer requests.

## Decisions

Completion feedback has two independent settings:

- **Completion effect:** Full screen, Notch only, or Off.
- **While Codex is active:** Keep selected effect, Notch only, or Hide.

The defaults are Full screen and Notch only while Codex is active. This keeps
the celebration visible without covering the interface the user is currently
working in. Reduce Motion continues to replace particle-heavy motion with the
existing restrained treatment.

The runtime resolves those preferences for every completion batch. A full-screen
decision may also show the notch treatment when the compact surface is visible.
Notch-only decisions never create the screen overlay. Hidden and Off decisions
create neither presentation. Simultaneous completions remain coalesced into the
existing single batch event.

## Approval and quiet-mode behavior

Explicit command and patch approval events are labeled **Needs approval**.
Explicit user-input and elicitation events are labeled **Needs answer**. Both
remain classified as Needs You until later safe progress or terminal evidence
arrives.

Quiet Mode suppresses ordinary completion and interruption notifications. A new
**Urgent alerts in Quiet Mode** preference, enabled by default, allows Needs You
notifications through because they block ongoing work. Turning it off makes
Quiet Mode fully silent while the notch and dashboard continue showing state.

## Settings interface

Settings keeps the existing Notifications, Quiet Mode, and Privacy Mode group.
A new Completion Feedback group contains two segmented controls and a Preview
button. The Codex-active control is disabled when the completion effect is Off.
The preview uses demo content and exercises the selected base completion effect
without requiring a real task to finish.

Preferences remain in the existing DashboardStore and persist through
UserDefaults. Pure presentation and notification policies live in the Core
framework so their combinations can be tested without AppKit.

## Non-goals

This iteration does not add scheduled quiet hours, per-project muting, launch at
login, custom animation duration, or display selection. Those are useful future
options, but they should not block a clear and testable interruption model.
