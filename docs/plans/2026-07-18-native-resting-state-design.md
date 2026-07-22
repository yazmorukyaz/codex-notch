# Native resting-state design

The 268 × 42 pt compact surface was attached correctly but was not a native resting state. On the current Retina display it rendered as roughly 536 × 84 pixels, 45% wider than the physical notch, and permanently covered document content.

## Chosen design

- Keep the two-window AppKit architecture.
- Derive resting width from the real hardware gap instead of using a fixed width.
- Use an 18 pt interactive body below the reserved camera area.
- Continue straight down from the physical notch edges with no flare or outer shoulders.
- Round only the two bottom corners with a 9 pt radius.
- Show one prioritized 10.5 pt status: needs you, working, briefly finished, then all quiet.
- Remove the chevron, multiple metrics, wrapping, and shadow.
- Keep the full dashboard click-only.

On the current display this produces a 185 × 18 pt body beneath the existing 185 × 32 pt camera gap, reducing the permanent black body area by about 70%.

## Alternatives rejected

- Hidden body: visually ideal, but the physical camera gap has no drawable pixels and its bridge window must remain mouse-transparent. It would lose the direct notch click target.
- Thin color rail: too small for legible status and still requires an interaction strategy outside the hardware gap.
- Hover-expanding shelf: useful later, but introduces a third window state and pointer tracking before the resting geometry is proven.

## Acceptance criteria

- Resting body width equals the detected hardware gap on every notched Mac.
- Resting body height is exactly 18 pt.
- Neck and body have identical horizontal origin and width with a flush seam.
- No outward flare, chevron, second row, or persistent history label.
- Recent completed work appears for only eight seconds; older history stays in the dashboard.
- The compact window remains nonactivating and directly clickable.
- Notchless displays use a 220 × 18 pt conventional fallback below the menu bar.
