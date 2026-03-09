# OverHyper

OverHyper is a macOS menu bar app for live talks.
It renders stage effects such as confetti, flash, and glitch overlays across all connected displays.

## Stack

- Overlay windows: AppKit (`NSWindow`, `NSStatusItem`)
- Settings UI: SwiftUI
- Effects: Core Animation (`CAEmitterLayer`) and Metal (`MTKView`, shaders)
- Global shortcut: MASShortcut
- Persistence: UserDefaults
- Screen capture: ScreenCaptureKit

## Implemented Features

- Menu bar resident app (agent app, no Dock icon)
- Full-screen, click-through overlay windows on all displays
- Confetti effect
- Flash effect
- Glitch effect with frozen-frame shader animation
- Global hotkey (`Control + Option + Command + G` by default)
- Screen Recording permission flow for glitch capture
- Settings window with:
  - Intensity preset (`Low`, `Standard`, `High`)
  - Confetti duration
  - Flash enable/disable
  - Hotkey recorder
- Runtime screen/space change handling

## Run

1. Open `OverHyper.xcodeproj` in Xcode.
2. Select the `OverHyper` scheme.
3. Build and run.

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
  - `Settings...`
  - `Quit OverHyper`
- Global hotkey defaults to `Control + Option + Command + G` and is configurable in Settings.

## Project Structure

```text
OverHyper/
├── App/
│   ├── OverHyperApp.swift          # App entry point and Settings scene
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
│   ├── ConfettiEffect.swift
│   ├── FlashEffect.swift
│   └── GlitchEffect.swift
├── Metal/
│   ├── MetalOverlayView.swift
│   ├── MetalRenderer.swift
│   └── Shaders.metal
├── Capture/
│   └── ScreenCaptureService.swift
└── UI/
    ├── HotkeyService.swift
    ├── SettingsView.swift
    └── MASShortcutRecorderField.swift
```

### Data Flow (High Level)

1. `AppDelegate` receives menu actions.
2. `AppRuntime` forwards actions to `EffectOrchestrator`.
3. `EffectOrchestrator` selects an effect and calls `OverlayWindowController`.
4. `OverlayWindowController` renders the selected effect on each display surface.
5. `EffectSettingsStore` provides current settings and persists updates to `UserDefaults`.

## Manual E2E Checklist

1. Confetti appears on all connected displays.
2. Flash appears when enabled.
3. Glitch captures the current display image and plays for about one second.
4. Glitch requests Screen Recording permission when needed and aborts cleanly if denied.
5. Repeated triggers stack without crashing.
6. Hotkey triggers glitch even when another app is focused.
7. Changing displays or spaces does not break effects.
8. Settings are persisted after app restart.

## Style Guide

Implementation follows Google Swift Style Guide for new and edited files:
<https://google.github.io/swift/>
