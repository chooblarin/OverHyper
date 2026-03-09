# Signing and Notarization Notes

This project is a macOS agent app distributed outside the App Store.
Use this checklist before external distribution.

## 1. Signing Preconditions

1. Ensure a valid Apple Developer Team is selected in target settings.
2. Keep `ENABLE_HARDENED_RUNTIME = YES` for Release.
3. Confirm bundle identifier and version are finalized.

## 2. Archive

1. Build Release archive in Xcode.
2. Validate archive with Organizer.

## 3. Notarize

1. Export signed app.
2. Submit with `notarytool`.
3. Wait for accepted status.

## 4. Staple and Verify

1. Staple ticket to app.
2. Verify stapling.
3. Test launch on a clean machine profile.

## 5. Pre-Ship Runtime Checks

1. App launches as status bar app.
2. Global hotkey works.
3. Confetti and flash effects render across displays.
4. Glitch captures the current display image and plays cleanly across displays.
5. Screen Recording permission request and denied-path behavior are understandable.
6. Settings persistence works after relaunch.
