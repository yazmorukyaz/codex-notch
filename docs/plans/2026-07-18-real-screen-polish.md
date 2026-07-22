# Real-screen notch polish

The first live build proved the two-window hardware attachment, but the screenshots exposed four product problems: the compact body was too wide and cryptic, the expanded body was a fixed black slab, incomplete lifecycle evidence was mislabeled as stale, and notification permission was requested without intent.

## Accepted direction

- Keep the physical 185 × 32 pt neck exactly anchored to the camera housing.
- Superseded after live-screen review: the 268 × 42 pt body still covered too much workspace. See `2026-07-18-native-resting-state-design.md`.
- Use a 720 pt expanded body whose height follows its content between 300 and 520 pt.
- Reserve red/amber for actions or failures; describe recent incomplete evidence as `unverified`, never `working` or `stale`.
- Show limits as compact progress bars and keep task rows to two readable lines.
- Never ask for notification permission at launch. Make it an explicit Settings opt-in.

## Verification criteria

- Compact body must match the detected hardware-notch width and extend no more than 18 pt below it.
- Expanded body has no large dead region with only one or two visible tasks.
- The neck frame does not move while the body height changes.
- Recent unknown lifecycle data reads `Recent activity · status unverified`.
- A clean launch does not trigger a notification authorization prompt.
