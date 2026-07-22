# True Notch Surface Redesign

## Outcome

Replace the floating top-center capsule/card with a surface that is visually and geometrically attached to the MacBook camera notch. The hardware gap is the anchor; the dashboard grows downward from it.

## Measured display contract

On the current built-in display:

- Screen size: 1728 x 1117 pt
- Top safe-area inset: 32 pt
- Left auxiliary top region ends at x = 771 pt
- Right auxiliary top region begins at x = 956 pt
- Camera gap: 185 pt, centered at x = 863.5 pt

The app must derive these values from `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea`. Hard-coded values are fallback geometry only.

## Selected silhouette

Two coordinated windows avoid covering usable menu-bar space. A narrow, noninteractive neck panel fills only the camera gap in the top reserved region. An interactive body panel begins below that region, where concave shoulder curves flare outward into the compact or expanded body. No app window covers the first 32 pt outside the physical camera gap, so the surface reads as an extension of the notch without stealing menu-bar clicks.

- Compact: approximately 316 x 70 pt, with a hardware-derived neck and a small status shelf below it.
- Expanded: approximately 760 x 600 pt, with the same neck and shoulder transition above the dashboard body.
- External or notchless display: use a centered synthetic neck while retaining the menu-bar fallback.

## Data and ownership

`PanelCoordinator` reads the selected screen geometry, positions the narrow neck panel, and publishes display metrics to the SwiftUI body. `NotchRootView` passes those metrics into a reusable notch shape. The same metrics determine AppKit placement and the SwiftUI shoulder width, preventing the two pieces from drifting apart.

## Interaction

- The neck remains fixed while compact and expanded body frames animate downward.
- Clicking the compact status shelf expands the dashboard.
- Escape, outside click, and the close control collapse it.
- Menu-bar shoulders contain no panel window and remain clickable.
- Reduce Motion uses the existing non-spring transition.

## Acceptance checks

1. Only the neck is filled in the top 32 pt of a notched display.
2. The neck spans the measured camera gap with a small visual allowance.
3. The compact surface is connected to the neck and never reads as a capsule.
4. The expanded dashboard begins below a curved shoulder transition, with no rounded top card corners.
5. The top anchor does not move between compact and expanded states.
6. Negative-origin and multi-display positioning remain correct.
7. Geometry tests cover hardware-notch and fallback cases.
8. An app-only exported preview confirms the silhouette before replacing the running Release build.
