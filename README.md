# Lumen — native iOS app (SwiftUI + HealthKit)

The native version of Lumen. It reads your Apple Watch / iPhone health data
**live** through HealthKit (no exports) and rolls it into the same six-pillar
daily **Life Score**. Everything stays on your device.

## Run it on your iPhone

1. **Open the project**
   ```
   open ~/Workspace/lumen-ios/Lumen.xcodeproj
   ```
   If this is the first time you've opened Xcode, let it finish "Installing
   components" (it sets up the iOS platform). One time only.

2. **Set signing** — select the **Lumen** target → **Signing & Capabilities** →
   Team = your Apple ID (Add an Account… if needed; a free Apple ID works for
   your own phone). If the bundle id `com.lyonecho.lumen` is taken, change it to
   anything unique, e.g. `com.yourname.lumen`.

3. **Plug in your iPhone**, select it as the run destination (top bar), and press
   **▶ Run**. First launch: tap **Connect Apple Health** and **Allow** the data
   categories. On the phone, trust the developer profile if prompted:
   Settings → General → VPN & Device Management → your Apple ID → Trust.

4. Pull to refresh any time to re-read Health.

### If you hit an "iOS 26.5 / simulator runtime" or asset error
Your Xcode has the SDK but not the matching **simulator runtime** yet. Building
to a real device shouldn't need it, but if it complains:
- Xcode → **Settings → Components** → download the **iOS 26.5 Simulator**, or
- run `xcodebuild -downloadPlatform iOS`.

This was verified to compile cleanly for device (`BUILD SUCCEEDED`); the runtime
is only an asset-catalog convenience.

## What's inside

| Area | Files |
|---|---|
| Scoring engine (ported from the web app) | `Models/Pillars.swift`, `Models/Scoring.swift` |
| Live HealthKit reads → daily metrics | `Health/HealthStore.swift` |
| State + persisted weights | `ViewModel/LumenModel.swift` |
| Today / Trends / Settings + onboarding | `Views/` |
| Look (dark theme, pillar colors) | `Views/Theme.swift` |

- **Deployment target:** iOS 17.0.  **Distribution:** personal device (free
  Apple ID). For other phones or 1-year installs you'd need the $99 Apple
  Developer Program.
- **Screen Time** is intentionally absent — Apple doesn't expose it through
  HealthKit even to native apps, so the Focus pillar is omitted from the score
  (the engine renormalizes the remaining weights automatically).

## Regenerating the project

The `.xcodeproj` is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):
```
xcodegen generate
```
Edit Swift files freely; only re-run that if you add/remove files or change
build settings.

## Focus pillar via Screen Time (this branch only)

The `screen-time` branch adds automatic Focus-pillar tracking using Apple's
Screen Time API (FamilyControls + DeviceActivity). A `DeviceActivityReport`
extension reads your daily total and passes it to the app through a shared App
Group, where it folds into your Life Score (open the **Focus** tab → *Connect
Screen Time*).

**Requires a paid Apple Developer Program membership ($99/yr).** App Groups and
Family Controls cannot be provisioned with a free Apple ID, so this branch will
fail to sign on a free account — that's why `main` stays HealthKit-only and
free-installable. Switch to this branch once you have a paid account.
