# Local Self-Use Build Guide

This guide is for personal use on your own Mac.
It does not require Developer ID signing or notarization.

## Goal

Build `OverHyper.app` and launch it like a normal application from Finder.

## Prerequisites

1. Xcode is installed.
2. You can build the project in Xcode at least once.

## Build

Run from project root:

```bash
./scripts/build-local-app.sh
```

This creates:

- `dist/OverHyper.app`

## Launch

```bash
open dist/OverHyper.app
```

You can also drag `dist/OverHyper.app` into `/Applications` and launch it from there.

## Notes

1. This flow is intended only for your own machine.
2. For distribution to other users, use Developer ID signing + notarization.
3. If you see a Gatekeeper warning after copying from external storage,
   remove quarantine on your own machine only:

```bash
xattr -dr com.apple.quarantine /Applications/OverHyper.app
```
