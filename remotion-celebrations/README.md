# Codex Notch completion motion lab

Frame-driven Remotion studies for the native completion feedback in Codex
Notch. These compositions make timing, density, color, and reduced-intensity
variants easy to compare before the selected motion is implemented in SwiftUI.

## Compositions

- `CompletionQuiet` — checkmark and soft completion pulse.
- `CompletionSpark` — restrained six-spark micro-celebration.
- `CompletionConfetti` — compact ribbon designed for the notch surface.
- `CompletionAllDone` — warmer treatment for the final active task.
- `CompletionScreenConfetti` — full-display burst used as the native effect's
  timing and trajectory reference.

The shipping macOS renderer does not embed Remotion or a web view. It uses
`TimelineView` and ordinary SwiftUI particle views in a transparent,
click-through panel.

## Run the studio

```sh
npm ci
npm run dev
```

## Validate

```sh
npm run lint
```

## Render studies

```sh
npm run render:quiet
npm run render:spark
npm run render:confetti
npm run render:screen-confetti
npm run render:all-done
```

Generated media is written to `out/` and intentionally ignored. Curated static
and animated previews used by the main repository live under `docs/assets/`.
