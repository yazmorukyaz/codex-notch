# Natural compact presence

## Decision

The physical MacBook notch is the complete idle UI. Codex Notch does not draw
an `All quiet` label, black chin, invisible hit shelf, or hover tracker when no
state needs the user's attention.

The compact surface appears only for one prioritized semantic state:

1. Local status is unavailable.
2. One or more tasks need attention.
3. One or more tasks are working.
4. A task finished or stopped within the last four seconds.

Finished and stopped work use distinct green and red transient states. After the
four-second grace period, both app-owned notch windows are ordered out.
The existing menu-bar item is the native idle access point and can always open
the expanded dashboard.

## Alternatives considered

- An always-visible micro-indicator still permanently covers app content.
- A transparent hover strip would intercept clicks below the notch.
- A global pointer monitor adds privacy, energy, and reliability costs for an
  interaction already covered by the menu-bar item.
- A zero-height window is not a valid hover or click target and fights AppKit's
  positive-size window geometry.

## Interaction and motion

The revealed surface stays exactly as wide as the hardware notch and 18 points
tall. It shows one dot and one short system-font label. It fades in over 140 ms,
while Reduce Motion reveals it immediately. Hover only increases label contrast;
it does not resize the window. Clicking opens the dashboard.

Escape, outside click, dashboard collapse, and menu actions all return through
the same compact-presence policy. An idle collapse hides the app windows; an
active collapse reveals the compact status. Automatic state changes never close
an expanded dashboard or settings surface.

## Acceptance criteria

- Idle, stale, unverified, and old terminal states show no app pixels below the
  physical notch.
- Working, needs-attention, unavailable, and fresh completion states reveal the
  exact `notchWidth × 18pt` compact surface.
- No compact pixels extend into the menu-bar shoulders.
- Completion and interruption retract after four seconds.
- A dormant app remains accessible through its menu-bar item.
- Expanded UI remains visible when task activity becomes idle.
- Notchless and external displays use only the menu-bar item while compact.
