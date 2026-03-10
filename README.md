# OverHyper

OverHyper is a macOS menu bar app for live talks.
It renders stage effects such as confetti, flash, and shader-based overlays across all connected displays.

## Stack

- Overlay windows: AppKit (`NSWindow`, `NSStatusItem`)
- Settings UI: SwiftUI
- Effects: Core Animation (`CAEmitterLayer`) and Metal (`MTKView`, shaders)
- Global shortcut: in-house Carbon hotkey registrar
- Persistence: UserDefaults
- Screen capture: ScreenCaptureKit

## Implemented Features

- Menu bar resident app (agent app, no Dock icon)
- Full-screen, click-through overlay windows on all displays
- Confetti effect
- Flash effect
- Glitch effect with frozen-frame shader animation
- CRT Burst effect
- Shockwave effect
- Cracked Glass effect
- Neon Edge effect
- Preset global hotkey slots (`Control + Option + Command + 1...5`)
- Screen Recording permission flow for shader effect capture
- Settings window with:
  - Effect test fire buttons
  - Hotkey slot assignment for all available effects
- Runtime screen/space change handling

## Run

1. Open `OverHyper.xcodeproj` in Xcode.
2. Select the `OverHyper` scheme.
3. Install SwiftLint with `brew install swiftlint`.
4. Build and run.

## Lint

SwiftLint is wired into the `OverHyper` target as an Xcode Run Script build phase.
Initial rollout is warning-first, so violations are surfaced in build logs without failing the build.

Run it manually from the project root:

```bash
scripts/swiftlint.sh
```

## Build For Self Use

If you only use the app on your own Mac, use the local build flow:

```bash
export PATH="$(brew --prefix ruby)/bin:$PATH"
bundle config set --local path vendor/bundle
bundle install
cp fastlane/.env.default fastlane/.env.local
# Edit fastlane/.env.local with your own values
bundle exec fastlane self_use_build
open dist/OverHyper.app
```

This does not require notarization.
Environment setup and build steps are documented in `docs/LOCAL_SELF_USE.md`.

## Documentation

- Local self-use setup and build: `docs/LOCAL_SELF_USE.md`
- External distribution signing/notarization notes: `docs/NOTARIZATION.md`
- Swift style review checklist: `docs/STYLE_CHECKLIST.md`

## Operation

- Menu bar icon: `⚡️`
- Menu actions:
  - `Fire Confetti`
  - `Fire Flash`
  - `Fire Glitch`
  - `Fire CRT Burst`
  - `Fire Shockwave`
  - `Fire Cracked Glass`
  - `Fire Neon Edge`
  - `Settings...`
  - `Quit OverHyper`
- Preset hotkey defaults are `Control + Option + Command + 1 = Confetti`, `2 = Flash`, `3 = Glitch`.

## Project Structure

```text
OverHyper/
├── App/
│   ├── OverHyperApp.swift          # App entry point and explicit settings window
│   ├── AppDelegate.swift           # Status item lifecycle and menu actions
│   └── AppRuntime.swift            # Runtime wiring (overlay/effects/hotkey)
├── Overlay/
│   └── OverlayWindowController.swift
├── Effects/
│   ├── EffectKind.swift
│   ├── EffectOrchestrator.swift
│   ├── EffectSettings.swift
│   ├── EffectSettingsStore.swift
│   ├── OverlayEffect.swift
│   ├── ScreenShaderEffect.swift
│   ├── ConfettiEffect.swift
│   ├── FlashEffect.swift
│   ├── GlitchEffect.swift
│   ├── CRTBurstEffect.swift
│   ├── ShockwaveEffect.swift
│   ├── CrackedGlassEffect.swift
│   └── NeonEdgeEffect.swift
├── Metal/
│   ├── ShaderEffectStyle.swift
│   ├── MetalOverlayView.swift
│   ├── MetalRenderer.swift
│   └── Shaders.metal
├── Capture/
│   └── ScreenCaptureService.swift
├── Hotkeys/
│   ├── Hotkey.swift
│   ├── GlobalHotkeyRegistrar.swift
│   ├── HotkeyService.swift
│   └── HotkeySlot.swift
└── UI/
    └── SettingsView.swift
```

### Data Flow (High Level)

1. `AppDelegate` receives menu actions.
2. `AppRuntime` forwards actions to `EffectOrchestrator`.
3. `EffectOrchestrator` selects an effect and calls `OverlayWindowController`.
4. `OverlayWindowController` renders the selected effect on each display surface.
5. `EffectSettingsStore` provides current settings and persists updates to `UserDefaults`.

## Manual E2E Checklist

1. Confetti appears on all connected displays.
2. Flash appears when triggered.
3. Glitch, CRT Burst, Shockwave, Cracked Glass, and Neon Edge capture the current display image and play cleanly.
4. Shader effects request Screen Recording permission when needed and abort cleanly if denied.
5. Repeated shader triggers replace the prior shader surface without crashing.
6. Preset hotkey slots trigger their assigned effects even when another app is focused.
7. Changing displays or spaces does not break effects.
8. Settings are persisted after app restart.

## Style Guide

Implementation follows Google Swift Style Guide for new and edited files:
<https://google.github.io/swift/>

The practical baseline is enforced by `.swiftlint.yml`.
