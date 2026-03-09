# Local Self-Use Setup And Build

This document is the single guide for local environment setup and self-use builds.
It targets local app launch on your own Mac and does not include notarization.

## 1. Environment Setup

### 1.1 Prerequisites

1. Xcode is installed.
2. Apple Development certificate is available in your login keychain.
3. Homebrew is available.

### 1.2 Ruby And Bundler

Use Homebrew Ruby to avoid system Ruby/Bundler drift.

```bash
brew install ruby
export PATH="$(brew --prefix ruby)/bin:$PATH"
ruby -v
bundle -v
```

### 1.3 Project Dependencies

Run from project root:

```bash
bundle config set --local path vendor/bundle
bundle install
```

## 2. fastlane Env File Setup

Create local env file:

```bash
cp fastlane/.env.default fastlane/.env.local
```

Check your signing identity:

```bash
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db
```

Set `fastlane/.env.local`:

```dotenv
OVERHYPER_TEAM_ID=YOUR_TEAM_ID
OVERHYPER_CODE_SIGN_IDENTITY=Apple Development: Your Name (TEAMID)
OVERHYPER_APP_IDENTIFIER=com.sotahatakeyama.OverHyper
```

Notes:
- `OVERHYPER_TEAM_ID` must match the team in your certificate.
- `OVERHYPER_CODE_SIGN_IDENTITY` must exactly match one line from `security find-identity`.
- `fastlane/.env.local` is git-ignored.

## 3. Build

Run:

```bash
bundle exec fastlane self_use_build
```

Expected output:
- `dist/OverHyper.app`

`fastlane/.env.local` is loaded automatically.
`--env local` is optional if you prefer dotenv switching.

## 4. Launch

```bash
open dist/OverHyper.app
```

Optional:
- Move `dist/OverHyper.app` into `/Applications`.

### First launch notes

- The app runs as a menu bar utility with the `⚡️` icon.
- `Glitch`, `CRT Burst`, `Shockwave`, and `Neon Edge` require Screen Recording permission because they capture a single frame of the display with ScreenCaptureKit.
- Default hotkey slots are `Control + Option + Command + 1 = Confetti`, `2 = Flash`, `3 = Glitch`.

## 5. Troubleshooting

### Missing env vars

`before_all` stops with a message indicating the missing key.

### Template values are still set

Replace `YOUR_TEAM_ID` or `Apple Development: Your Name (TEAMID)` in `fastlane/.env.local`.

### Signing identity not found

Make `OVERHYPER_CODE_SIGN_IDENTITY` match:

```bash
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db
```

### 0 valid identities found

No usable Apple Development certificate is installed in your login keychain.
Create one from Xcode:

1. Xcode > Settings > Accounts
2. Select your Apple ID and team
3. Manage Certificates...
4. Add `Apple Development`

### No certificate for team matching identity

The team ID and certificate are inconsistent.
Use the team ID that belongs to the selected certificate.

### Xcode CLI missing

Install/fix command line tools and rerun.

### Shader effect shows a permission alert

Allow Screen Recording for OverHyper in System Settings and relaunch if needed.
The confetti and flash effects do not require Screen Recording permission.
