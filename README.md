# Lumi Arcade

Lumi Arcade turns physical NFC-enabled **Arcadots** into lightweight arcade machines. An Arcadot launches a specific game through the Lumi Arcade App Clip. **Sky Stack is Game #001.**

- **Lumi Arcade:** the gaming platform, App Store app, and App Clip identity.
- **Arcadot:** an individual physical NFC game object with a string identifier, such as `00001` or `A72K9`.
- **Sky Stack:** the first game. Its existing SpriteKit gameplay and stack artwork are preserved.

This is a dedicated gaming product under the broader Lumi name. There are no social profiles, relationship features, messaging, accounts, onboarding, backend dependencies, or game-selection screens.

## Open and run

Open `SkyStack.xcodeproj` in Xcode 16.3 or later. The existing project, module, and scheme names remain **SkyStack** and **SkyStackClip** to avoid unnecessary build/signing changes. Both installed products display **Lumi Arcade**, while the in-game title remains **Sky Stack**. Deployment target: iOS 17.0, iPhone, portrait.

- Run **SkyStack** on an iPhone Simulator for immediate Local Play.
- Run **SkyStackClip** for the App Clip. Its shared scheme supplies `_XCAppClipURL=https://play.lumiarcade.com/g/sky-stack/00001`.
- Edit Scheme → Run → Arguments to change the URL to another Arcadot, or disable `_XCAppClipURL` for Local Play.
- For deterministic routing in a Debug full-app run, pass `-LumiArcadeInvocationURL` followed by the complete URL. This testing argument is absent from Release behavior.
- Product → Test with the **SkyStack** scheme runs logic, gameplay, persistence, and UI tests.

No manual target creation is necessary. The full app embeds the App Clip; both compile the same shared routing, game, leaderboard code, and asset catalog.

```sh
xcodebuild -project SkyStack.xcodeproj -scheme SkyStack \
  -sdk iphonesimulator -derivedDataPath /tmp/SkyStackBuild \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project SkyStack.xcodeproj -scheme SkyStack \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/SkyStackBuild CODE_SIGNING_ALLOWED=NO test
```

`python3 Scripts/generate_project.py` regenerates the checked-in project and schemes with no dependencies. Keep this script in sync with any manual Xcode target edits before regenerating.

## Arcadot URLs and routing

The intended production format is:

```text
https://play.lumiarcade.com/g/{gameSlug}/{arcadotID}
https://play.lumiarcade.com/g/sky-stack/00001
https://play.lumiarcade.com/g/sky-stack/A72K9
```

`sky-stack` identifies the game. `00001` identifies the Arcadot; leading zeroes and case are preserved. Current valid IDs contain 1–64 ASCII letters or digits. IDs are never parsed as integers. This identifies a local score context; it does not claim to verify physical ownership or look up an object on a server.

`AppInvocation` carries the incoming URL. `ExperienceRouter` resolves it to a `GameInvocation` containing `GameType` and an optional Arcadot ID. `Arcadot` is a lightweight `Identifiable`, `Equatable`, `Codable` model with an ID and game. `SkyStackView` receives the Arcadot; SpriteKit never parses a URL.

| Input | Behavior |
| --- | --- |
| Valid `/g/sky-stack/00001` on the intended HTTPS host | Immediately plays Sky Stack for Arcadot `00001` |
| Same route received again | Keeps the current scene/run |
| Different valid Arcadot route | Creates a fresh scene with that Arcadot's own scores |
| No URL, malformed route/ID, wrong scheme/host | Immediately plays Sky Stack in Local Play |
| Unknown game on a well-formed Arcadot URL, Debug | Falls back to Local Play, without attributing scores to that unknown game's object |
| Unknown game on a well-formed Arcadot URL, Release | Shows a compact unsupported-experience state with an explicit Play Sky Stack action |
| Legacy `/game/sky-stack` or unrecognized `/c/…` | Local Play; legacy opaque codes are not treated as Arcadot IDs |

HTTPS callbacks use SwiftUI `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` and `onOpenURL` in the common root. Only `play.lumiarcade.com` is accepted for Arcadot attribution; credentials and nonstandard ports are rejected. Query parameters do not alter the object ID. No network request occurs before rendering or play.

## Sky Stack gameplay

The first block is already moving on launch; the first tap places it. Preserved mechanics include overlap cutting, falling offcuts, perfect snapping and streaks, score feedback, native haptics, rising perfect tones, speed progression, smooth camera tracking, the raised starting tower/sky gradient, best-score markers, and an instant clean restart. A 250 ms fall makes the final miss visible before results.

`SkyStackConfig` centralizes logical width, block size/spacing, initial height, speed curve, tolerance, camera tracking, and accessible timing. Reduce Motion removes decorative animations. VoiceOver slows motion and holds briefly at alignment with an announcement, sound, and haptic cue. The new initials columns support adjustable accessibility actions as well as labeled up/down buttons. Important results stay inside safe areas, with scrolling available on compact screens and for long IDs.

`GameAudio` synthesizes tiny PCM cues off the render/touch path and uses an ambient session. Check silent-switch behavior, haptic sensation, and VoiceOver usability on physical hardware. `LaunchMeasurement` emits local Instruments markers only; it never logs URLs or sends analytics. See [launch and physical testing](Documentation/LaunchMeasurements.md).

## Local arcade leaderboard

Each combination of **game + Arcadot ID** has its own top five, serialized as a small Codable array in UserDefaults. IDs are encoded in namespaced storage keys so score groups cannot collide. There is no shared online board yet; each app/Clip installation owns its own local data.

`ArcadeScore` stores UUID, Arcadot ID, `GameType`, exactly three initials, integer score, and creation timestamp. Scores sort descending; ties retain the earlier timestamp, with UUID as a deterministic final ordering. A positive score qualifies when fewer than five entries exist, or it strictly exceeds the fifth score. Ties at a full board's cutoff do not qualify; zero scores do not prompt for initials.

At game over:

1. A qualifying score shows **NEW HIGH SCORE!** if it beats the previous best, or **TOP FIVE SCORE!** for another qualifying entry.
2. Three columns cycle through `A–Z` then `0–9`, wrapping in either direction. No keyboard appears. Default initials are `AAA`, or the last saved initials on this installation.
3. **SAVE SCORE** submits once, refreshes the board, then displays **HIGH SCORES** and **PLAY AGAIN**.
4. A nonqualifying score goes directly to the results/leaderboard. Arcadot identity is a small `ARCADOT #00001` line in this overlay, not a gameplay heading.

Scores are committed when Save is pressed. Leaving before saving does not create an entry. The save button is disabled while saving. A stable UUID per run makes retries idempotent; a run token prevents an old async completion from changing a restarted game. Save/read errors leave existing data intact, permit retry, and offer a continue-without-saving action rather than trapping the player.

Local Play uses an internal `__local__` namespace, which cannot be supplied by a valid Arcadot URL, and displays **LOCAL PLAY**. The previous `game001.bestScore` integer migrates once into this group with initials `AAA` and the migration timestamp; it is never copied onto an Arcadot, and the legacy value is retained. App Clip data may be removed by iOS. The full app and App Clip do not share a container or synchronize scores in this MVP.

## Architecture and extension points

| File | Responsibility |
| --- | --- |
| `App/LumiArcadeApp.swift`, `AppClip/LumiArcadeClipApp.swift` | Platform entry points |
| `AppClip/AppClipRootView.swift` | Focused App Clip root |
| `Shared/Product.swift`, `Configuration/Product.xcconfig` | Platform identity, intended host, display name, placeholder signing ID |
| `Shared/GameType.swift`, `Arcadot.swift`, `GameInvocation.swift` | Game and physical-object models |
| `Shared/ExperienceRouter.swift`, `ExperienceRootView.swift` | Parse URLs, select experience, own route identity |
| `Shared/ArcadeScore.swift` | Score entries and initials validation/cycling |
| `Shared/LeaderboardService.swift` | Small async service protocol, local persistence, ranking rules |
| `SkyStack/SkyStackView.swift`, `SkyStackGameState.swift` | Stable scene ownership, run state, results workflow |
| `SkyStack/ArcadeInitialsPicker.swift`, `ArcadeResultsView.swift` | Initials controls and compact leaderboard |
| `SkyStack/SkyStackScene.swift`, `StackPlacement.swift`, related files | Existing game mechanics and rendering |
| `Shared/Assets.xcassets` | Preserved stack icon shared by both targets |
| `Tests/`, `UITests/` | Gameplay regression and arcade flow coverage |

The game directory remains `SkyStack/`; moving it into `Games/` would add churn without improving sharing. There is no duplicated game implementation.

`LeaderboardService` exposes only async `scores(game:arcadotID:)` and `submit(_:)`. `LocalLeaderboardService` also provides a synchronous local snapshot so the first frame never waits on asynchronous work. Session initialization accepts a service and initial snapshot; a future remote implementation can provide cached data there, then refresh through the same async service. No endpoints, networking clients, credentials, or backend are implemented.

To add a game, add a `GameType` case and the corresponding view branch in `ExperienceRootView`. The router and score namespace then have a common identifier. Do not make the SpriteKit scene responsible for routing or networking.

## Physical NFC → App Clip setup still required

`play.lumiarcade.com` is the intended host supplied for this product. Declaring it in source does **not** establish DNS, hosting, ownership, App Store availability, or successful domain association.

1. Set `SKY_STACK_BUNDLE_ID` in `Configuration/Product.xcconfig` to your registered full-app identifier and choose your Apple development team for both targets. The existing `com.example.skystack` and derived `.Clip` identifiers are retained development placeholders; no production identifiers have been invented. Register the Clip with the correct parent app. Both installed display names are already Lumi Arcade.
2. The checked-in entitlements now declare `appclips:play.lumiarcade.com` for both targets and `applinks:play.lumiarcade.com` for the full app. Ensure these capabilities are enabled in your signing profiles. Parent/Clip relationships use the configured bundle-ID variables.
3. Configure DNS/HTTPS and serve `https://play.lumiarcade.com/.well-known/apple-app-site-association` without redirects. Replace every identifier below with the actual signed application identifier:

   ```json
   {
     "appclips": { "apps": ["TEAM_ID.your.registered.bundle.Clip"] },
     "applinks": {
       "details": [{
         "appIDs": ["TEAM_ID.your.registered.bundle"],
         "components": [{"/": "/g/*"}]
       }]
     }
   }
   ```

4. Create the **Lumi Arcade** App Store Connect record. Archive the containing app with its Clip, validate/upload, and configure the App Clip experience/card and matching URL prefix. The supplied stack artwork is already the app/Clip icon; choose card artwork and metadata separately. Verify the distributed Clip size using the archive report.
5. For development, run the signed Clip on an iPhone and register a Local Experience in Settings → Developer using `https://play.lumiarcade.com/g/sky-stack/00001`, the actual Clip bundle ID, and card metadata. Xcode URL injection exercises the handler; Local Experiences exercise the card/physical launch.
6. Program the Arcadot with a standard NFC NDEF URI containing that HTTPS URL. Give another Arcadot `/g/sky-stack/00002` to verify score separation. No Core NFC reader or in-app scan screen is needed for this invocation flow.
7. Test Arcadot → card → moving Sky Stack block → first placement → qualifying score → initials → saved local board → restart. Check both the full-app-installed and Clip-only cases. Real NFC and haptics require hardware.

Apple references: [invocation lifecycle](https://developer.apple.com/documentation/appclip/responding-to-invocations), [website association](https://developer.apple.com/documentation/appclip/associating-your-app-clip-with-your-website), [local launch testing](https://developer.apple.com/documentation/appclip/testing-the-launch-experience-of-your-app-clip).

## Debug checks and assets

- `-SkyStackDiagnostics`: FPS/node counters.
- `-SkyStackGameOverPreview`: four successful placements followed by a miss, once per scene, for testing.
- `-SkyStackPreviewScore N`: an explicit 0–100 point completed-run preview, useful for zero/qualifying result states.
- `-SkyStackVoiceOverTest`: assisted alignment timing for local development.
- `-LumiArcadeInvocationURL URL`: passes a route through the same shared router without external infrastructure.

These test flags are excluded from Release behavior. The supplied icon is unchanged in `Shared/Assets.xcassets/AppIcon.appiconset`, and its original is retained in `Documentation/app-icon-original.png`. Both targets include a privacy manifest declaring app-local UserDefaults use and no collected data or tracking.

## Verification of the Lumi Arcade update

- Debug Simulator builds and unsigned Release iPhone builds succeed for the full app and embedded App Clip; both generated bundle display names are **Lumi Arcade**.
- **13 unit tests and 4 UI tests pass across iPhone 16 Pro / iOS 18.4 and iPhone SE / iOS 17.4.** Coverage includes URL policy/ID preservation, top-five isolation and cutoff ties, legacy migration, invalid initials, corrupt-data preservation, save/reload/restart, a complete five-row compact leaderboard, and existing gameplay/camera/perfect/motion tests.
- The original game regression includes an 81-placement tower and 20 repeated restarts. The revised results backdrop was rebuilt and visually checked after the flow tests.
- The icon artwork is preserved. No new artwork, third-party packages, networking, accounts, or game selection were added.
- Xcode emits its standard App Intents metadata notice; no Swift source warnings were introduced.
- Physical NFC/card invocation, provisioning, distribution, haptic sensation, and real VoiceOver usability remain device/deployment checks.

Current previews: [initials entry](Documentation/initials-iPhoneSE.png) and [leaderboard](Documentation/leaderboard-iPhoneSE.png). Internal test IDs in board previews are test-only; production Arcadots use their actual alphanumeric identifiers.
