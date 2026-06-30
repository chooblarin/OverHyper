# Presentation Mode Design

OverHyper's primary venue-talk model is a transparent, click-through overlay placed
above live presentation content on one or more physical displays.

## Target Use Case

- A presenter runs Keynote or another presentation app on macOS.
- A projector or sub display shows the audience-facing slide show.
- The presenter's built-in display may show notes, timers, or a presenter view.
- Effects should be easy to test before the talk and should fire only on the
  intended audience-facing display when configured that way.

Window-specific online meeting sharing is out of scope for this mode. That use case
requires a composited share window or virtual camera pipeline.

## Rendering Model

The app keeps its existing overlay-window architecture:

1. Create full-screen, click-through overlay windows for connected displays.
2. Keep overlay surface topology synchronized with the current display IDs.
3. Refresh existing window placement when Spaces change instead of recreating
   windows.
4. At effect fire time, ensure the surface topology before resolving the target.
5. Resolve the target from fresh display snapshots and keep any warning in the
   resolution value.
6. Render the effect only into surfaces that match the target.

This preserves compatibility with Keynote full-screen playback and avoids coupling
individual effects to display selection logic.

## Presentation Target

The presentation target is persisted in settings and currently supports:

- `All Displays`: preserve the original behavior.
- `External Displays`: projector/sub-display oriented mode.
- `Main Display`: local testing or single-screen use.
- `Selected Display`: explicit routing to one display ID.

If a selected display is disconnected, no selected-display surfaces are matched. The
settings UI should make that state visible instead of silently falling back to a
different display.

## Target Resolution

Target resolution is explicit so presentation failures are diagnosable:

- `PresentationDisplayResolution` is used by overlay rendering and settings UI
  display state.
- `PresentationTargetWarning` explains zero-target states such as no external
  displays, a disconnected selected display, or unavailable display IDs.

`OverlaySurfaceManager` owns overlay window lifecycle. It checks display ID
topology before each render, and refreshes window frames and z-order only after
rebuilds or Space changes. This keeps target resolution independent from window
placement and avoids repeated order-front work during effect rendering.

External displays are resolved by physical display type rather than by main-display
status, so a projector can still be targeted when macOS treats it as the main
display.

External-display targeting expects an extended desktop where the projector or sub
display is available as its own `NSScreen`. In mirroring mode, macOS may expose only
one logical screen. In that case, `External Displays` cannot address the projector
separately; use `All Displays` or switch macOS to extended display mode.

Some virtual or adapter-backed displays can also report unexpected physical display
metadata. When multiple independent `NSScreen` values are present but none reports
as a physical external display, OverHyper treats non-main displays as external
targets for venue use.

## Next Steps

1. Add a dedicated projector preset that switches to `External Displays`.
2. Add a preflight panel with target display count, Screen Recording status, and
   one-click test effects.
3. Add a menu bar quick toggle for `All Displays` and `External Displays`.
4. Consider per-effect routing only if venue workflows prove that some effects
   should stay local while others go to the projector.
