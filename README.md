# Lumi Arcade

Lumi Arcade turns physical NFC-enabled **Arcadots** into lightweight arcade machines. An Arcadot launches a specific game through the Lumi Arcade App Clip.

| Game | Style |
| --- | --- |
| **Game #001 — Sky Stack** | Precision / stacking |
| **Game #002 — Pulse** | One-touch gravity / survival |

- **Lumi Arcade:** the gaming platform, App Store app, and App Clip identity.
- **Arcadot:** an individual physical NFC game object with a string identifier, such as `00001` or `A72K9`.
- **Sky Stack:** Game #001. Its existing SpriteKit gameplay and stack artwork are preserved.
- **Pulse:** Game #002. A glowing energy orb pulses through geometric gates with one-touch gravity gameplay.

This is a dedicated gaming product under the broader Lumi name. There are no social feeds, relationships, messaging, accounts, or onboarding. The installed app is a permanent local arcade with Arcade, Leaderboards, and Profile tabs. Supabase stores only the active game assigned to each Arcadot; initials, profiles, and leaderboards remain local to the app or App Clip installation.

## Open and run

Open `SkyStack.xcodeproj` in Xcode 16.3 or later. The existing project, module, and scheme names remain **SkyStack** and **SkyStackClip** to avoid unnecessary build/signing changes. Both installed products display **Lumi Arcade**, while the in-game title remains **Sky Stack**. Deployment target: iOS 17.0, iPhone, portrait.

- Run **SkyStack** on an iPhone Simulator to open the full Lumi Arcade app. It starts on the Arcade tab, where either game can be launched.
- Run **SkyStackClip** for the project's single App Clip target. Its shared scheme supplies `_XCAppClipURL=https://play.lumiarcade.com/a/00025`.
- Use `/a/{arcadotID}` to test the necklace assignment flow. Set `_XCAppClipURL` to a legacy `/g/{game}/{arcadotID}` URL to test deterministic routing, or disable it for Local Play.
- For deterministic routing in a Debug full-app run, pass `-LumiArcadeInvocationURL` followed by the complete URL. This testing argument is absent from Release behavior.
- Add `-LumiArcadeAssignmentGame pulse` or `-LumiArcadeAssignmentGame sky-stack` to simulate a successful assignment without Supabase. Add `-LumiArcadeAssignmentUnavailable` to exercise cache and offline behavior.
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

## Full app

The installed app has three native tabs:

- **Arcade** is the default home. It lists every `GameType`, each game's best locally stored score, and a Play action. A lightweight Continue Playing card uses one persisted `lastPlayedGame` identifier.
- **Leaderboards** aggregates the existing top-five boards for the selected game across Local Play and known Arcadot IDs on this installation. It has loading, empty, and storage-error states; it does not claim to be an online global board.
- **Profile** reuses the three-character `ArcadeInitialsPicker`, persists the selected initials, shows completed games recorded from this version onward, and shows each game's local high score.

Selecting a game creates a normal `GameInvocation` and presents the same shared experience container used by the App Clip. During an active or unsaved run, a 44-point control in the top-right corner confirms that the run will end before opening the scrollable game selector. Once results are finalized by saving the score or continuing without saving, that control opens the selector immediately. The close control is full-app-only and returns to Arcade. Sky Stack and Pulse contain no full-app navigation, assignment, or URL logic.

## Arcadot URLs and routing

New necklaces use a stable, game-neutral URL:

```text
https://play.lumiarcade.com/a/{arcadotID}
https://play.lumiarcade.com/a/00025
```

Supabase resolves the Arcadot ID to `sky-stack` or `pulse`. Choosing another game from the in-game switcher updates that assignment before a fresh scene launches, so the next NFC tap—including on another phone—resolves to the new game. The Arcadot ID is retained, and score storage remains namespaced by game + Arcadot ID.

Legacy deterministic and local-play routes remain supported:

```text
https://play.lumiarcade.com/g/{gameSlug}/{arcadotID}
https://play.lumiarcade.com/g/sky-stack/00001
https://play.lumiarcade.com/g/pulse/00025
https://play.lumiarcade.com/g/sky-stack/A72K9
https://play.lumiarcade.com/play?game=sky-stack
https://play.lumiarcade.com/play?game=pulse
```

Arcadot IDs preserve leading zeroes and case. Current valid IDs contain 1–64 ASCII letters or digits and are never parsed as integers. Each game + Arcadot ID combination owns a separate local leaderboard, so Pulse Arcadots `00025` and `00026` do not share scores with each other or with Sky Stack.

`/g/{game}/{arcadotID}` remains a deterministic legacy route and does not read or change Supabase. `/play?game=…` selects a game without an Arcadot ID, so scores use that game's Local Play namespace. Missing, empty, or unknown games return the installed app to Arcade; the App Clip shows the selector.

`AppInvocation` carries the incoming URL. `ExperienceRouter` resolves `/a/…` to an asynchronous Arcadot assignment or resolves direct routes to a `GameInvocation` containing `GameType` and an optional Arcadot ID. `Arcadot` is a lightweight `Identifiable`, `Equatable`, `Codable` model with an ID and game. Game views receive the resolved Arcadot; SpriteKit never parses a URL or contacts Supabase.

| Input | Behavior |
| --- | --- |
| Valid `/a/00025`, server available | Resolves and caches the active game, then launches it for Arcadot `00025` |
| Valid `/a/00025`, server unavailable | Launches the last cached assignment for `00025` |
| Valid `/a/00025`, no server result or cache | Shows the selector and permits session-only play |
| Confirmed switch on `/a/00025` | Updates Supabase, caches the result, and launches a fresh scene for the selected game |
| Failed switch update | Keeps the existing assignment and offers Retry or Play Once |
| Valid `/g/sky-stack/00001` on the intended HTTPS host | Immediately plays Sky Stack for Arcadot `00001` |
| Valid `/play?game=sky-stack` or `/play?game=pulse` | Immediately plays the requested game in either installed target |
| `/play` with a missing, empty, or unknown `game` | Full app returns to Arcade; App Clip shows its minimal picker |
| Same route received again | Keeps the current scene/run |
| Different valid Arcadot route | Creates a fresh scene with that Arcadot's own scores |
| Normal full-app launch with no URL | Opens the Arcade tab |
| App Clip with no URL, malformed route/ID, or wrong scheme/host | Uses its existing safe Local Play behavior |
| Unknown game on a well-formed Arcadot URL, Debug | Falls back to Local Play, without attributing scores to that unknown game's object |
| Unknown game on a well-formed Arcadot URL, Release | Shows a compact unsupported-experience state with an explicit Play Sky Stack action |
| Legacy `/game/sky-stack` or unrecognized `/c/…` | Local Play; legacy opaque codes are not treated as Arcadot IDs |

HTTPS callbacks use SwiftUI `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` and `onOpenURL` in both thin target roots. Both pass the URL to the same `ExperienceRouter`; games never parse it. Only `play.lumiarcade.com` is accepted for Arcadot attribution; credentials and nonstandard ports are rejected. On `/g/…` routes, query parameters do not alter the object ID. Only `/a/…` assignment resolution and confirmed necklace switches require the network.

## Sky Stack gameplay

The first block is already moving on launch; the first tap places it. Preserved mechanics include overlap cutting, falling offcuts, perfect snapping and streaks, score feedback, native haptics, rising perfect tones, speed progression, smooth camera tracking, the raised starting tower/sky gradient, best-score markers, and an instant clean restart. A 250 ms fall makes the final miss visible before results.

`SkyStackConfig` centralizes logical width, block size/spacing, initial height, speed curve, tolerance, camera tracking, and accessible timing. Reduce Motion removes decorative animations. VoiceOver slows motion and holds briefly at alignment with an announcement, sound, and haptic cue. The new initials columns support adjustable accessibility actions as well as labeled up/down buttons. Important results stay inside safe areas, with scrolling available on compact screens and for long IDs.

`GameAudio` synthesizes tiny PCM cues off the render/touch path and uses an ambient session. Check silent-switch behavior, haptic sensation, and VoiceOver usability on physical hardware. `LaunchMeasurement` emits local Instruments markers only; it never logs URLs or sends analytics. See [launch and physical testing](Documentation/LaunchMeasurements.md).

## Pulse gameplay

Pulse is a one-touch SpriteKit survival game. A glowing orb waits at the left third of the screen with the first energy gate visible; the first tap starts gravity and applies the first upward pulse. Gates move right-to-left, safe gap positions adapt to the current screen height, and a trailing score sensor awards exactly one point only after the orb clears each gate. Gate or boundary contact ends the run.

Difficulty advances in bounded steps through gate speed, gap height, and spawn cadence. `Pulse/PulseConfig.swift` contains every gameplay value, including gravity, deterministic tap velocity, velocity caps, gate dimensions, gap bounds, spawn timing, particles, and milestone scores. Reduce Motion disables the decorative trail and ready-state bob without changing the required gate motion or tap physics.

Pulse uses the same `ArcadeGameSession`, `LocalLeaderboardService`, `ArcadeResultsView`, and `ArcadeInitialsPicker` flow as Sky Stack. The leaderboard key includes both `pulse` and the Arcadot ID, so every physical Pulse Arcadot maintains its own top five.

## Local arcade leaderboard

Each combination of **game + Arcadot ID** has its own top five, serialized as a small Codable array in UserDefaults. IDs are encoded in namespaced storage keys so score groups cannot collide. There is no shared online board yet; each app/Clip installation owns its own local data.

`ArcadeScore` stores UUID, Arcadot ID, `GameType`, exactly three initials, integer score, and creation timestamp. Scores sort descending; ties retain the earlier timestamp, with UUID as a deterministic final ordering. A positive score qualifies when fewer than five entries exist, or it strictly exceeds the fifth score. Ties at a full board's cutoff do not qualify; zero scores do not prompt for initials.

At game over:

1. A qualifying score shows **NEW HIGH SCORE!** if it beats the previous best, or **TOP FIVE SCORE!** for another qualifying entry.
2. Three columns cycle through `A–Z` then `0–9`, wrapping in either direction. No keyboard appears. Default initials are `AAA`, or the initials last saved from a score or the full-app Profile tab on this installation.
3. **SAVE SCORE** submits once, refreshes the board, then displays **HIGH SCORES** and **PLAY AGAIN**.
4. A nonqualifying score goes directly to the results/leaderboard. Arcadot identity is a small `ARCADOT #00001` line in this overlay, not a gameplay heading.

Scores are committed when Save is pressed. Leaving before saving does not create an entry. The save button is disabled while saving. A stable UUID per run makes retries idempotent; a run token prevents an old async completion from changing a restarted game. Save/read errors leave existing data intact, permit retry, and offer a continue-without-saving action rather than trapping the player.

Local Play uses an internal `__local__` namespace, which cannot be supplied by a valid Arcadot URL, and displays **LOCAL PLAY**. The previous `game001.bestScore` integer migrates once into this group with initials `AAA` and the migration timestamp; it is never copied onto an Arcadot, and the legacy value is retained. App Clip data may be removed by iOS. The full app and App Clip use the same local persistence code and keys but remain in separate iOS containers, so scores and identity do not synchronize. Supabase persists only the necklace's active game assignment; it does not receive scores, initials, or profile data.

## Architecture and extension points

| File | Responsibility |
| --- | --- |
| `App/LumiArcadeApp.swift`, `AppClip/LumiArcadeClipApp.swift` | Platform entry points |
| `App/FullAppRootView.swift`, `ArcadeHomeView.swift`, `LeaderboardsView.swift`, `PlayerProfileView.swift` | Full-app-only navigation and screens |
| `App/FullAppModel.swift` | Full-app presentation model over shared local services |
| `AppClip/AppClipRootView.swift` | Focused App Clip root |
| `Shared/Product.swift`, `Configuration/Product.xcconfig` | Platform identity, intended host, display name, placeholder signing ID |
| `Shared/GameType.swift`, `Arcadot.swift`, `GameInvocation.swift` | Canonical game registry and physical-object models |
| `Shared/ExperienceRouter.swift`, `ExperienceRootView.swift` | Shared URL parsing and focused App Clip routing |
| `Shared/ArcadotAssignmentService.swift` | Native URLSession Supabase client, resolver, and resilient assignment cache |
| `Shared/ArcadeExperienceView.swift` | Shared assignment loading, game container, switch confirmation, selector, and retry UI |
| `Shared/ArcadeGameView.swift` | Single mapping from `GameType` to existing game roots |
| `Shared/PlayerProfileStore.swift` | Local initials, last-played game, and completed-game count |
| `Shared/ArcadeScore.swift` | Score entries and initials validation/cycling |
| `Shared/LeaderboardService.swift` | Small async service protocol, local persistence, ranking rules |
| `SkyStack/SkyStackView.swift`, `SkyStackGameState.swift` | Stable scene ownership, run state, results workflow |
| `SkyStack/ArcadeInitialsPicker.swift`, `ArcadeResultsView.swift` | Initials controls and compact leaderboard |
| `SkyStack/SkyStackScene.swift`, `StackPlacement.swift`, related files | Existing game mechanics and rendering |
| `Shared/Assets.xcassets` | Preserved stack icon shared by both targets |
| `supabase/` | Arcadot table migration plus tested `arcadot-game` Edge Function |
| `Tests/`, `UITests/` | Gameplay regression, routing, assignment, persistence, and arcade flow coverage |

The game directory remains `SkyStack/`; moving it into `Games/` would add churn without improving sharing. There is no duplicated game implementation.

`LeaderboardService` retains its gameplay-facing `scores(game:arcadotID:)` and `submit(_:)` API. `GameLeaderboardBrowsing` adds the full app's read-only, per-game aggregate view, implemented by the same `LocalLeaderboardService`. Assignment networking is isolated behind `ArcadotAssignmentService`, uses native `URLSession`, and does not change the leaderboard architecture.

To add a game, add a `GameType` case with metadata and the corresponding view branch in `ArcadeGameView`. The Arcade, Leaderboards, Profile, router, and score namespace then use the same canonical identifier. Do not make the SpriteKit scene responsible for routing or networking.

## Supabase assignment setup

The app ships no secret key. Set only the project URL and client publishable key in `Configuration/Product.xcconfig`:

```xcconfig
LUMI_SUPABASE_URL = https:/$()/YOUR_PROJECT.supabase.co
LUMI_SUPABASE_PUBLISHABLE_KEY = sb_publishable_REPLACE_ME
```

The `$()` construct preserves `//` in xcconfig syntax. Do not replace the publishable key with a Supabase secret/service-role key. The release build treats the checked-in placeholders as unconfigured and uses cache/session-only behavior.

Link the local Supabase directory to the intended project, then apply the migration and deploy the function:

```sh
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy arcadot-game
```

The migration creates `public.arcadots` with `id`, `active_game`, and `updated_at`, enables row-level security, and prevents clients from reading or writing the table directly. The `arcadot-game` Edge Function uses the server-side secret key and exposes:

- `GET /functions/v1/arcadot-game?id=00025`
- `PUT /functions/v1/arcadot-game` with `{ "id": "00025", "game": "pulse" }`

Both calls require the configured publishable key in the `apikey` header. GET returns the current row, PUT validates the ID and game and updates an existing row, missing rows return `404`, and invalid values return `400`.

Create each physical necklace row manually before provisioning its NFC tag:

```sql
insert into public.arcadots (id, active_game)
values ('00025', 'pulse');
```

For this version, knowing a valid Arcadot ID is sufficient authorization to switch it. There is no login, PIN, or ownership claim flow, so do not treat the identifier as a secret or use this design for security-sensitive state. Supabase is authoritative; the local assignment cache is resilience-only.

The pure Edge Function handler tests are in `supabase/functions/arcadot-game/handler_test.ts`. Run them with `deno test supabase/functions/arcadot-game/handler_test.ts` when Deno is available.

## Physical NFC → App Clip setup still required

`play.lumiarcade.com` is the intended host supplied for this product. Declaring it in source does **not** establish DNS, hosting, ownership, App Store availability, or successful domain association.

1. Set `SKY_STACK_BUNDLE_ID` in `Configuration/Product.xcconfig` to your registered full-app identifier and choose your Apple development team for both targets. The existing `com.example.skystack` and derived `.Clip` identifiers are retained development placeholders; no production identifiers have been invented. Register the Clip with the correct parent app. Both installed display names are already Lumi Arcade.
2. The checked-in entitlements now declare `appclips:play.lumiarcade.com` for both targets and `applinks:play.lumiarcade.com` for the full app. Ensure these capabilities are enabled in your signing profiles. Parent/Clip relationships use the configured bundle-ID variables.
3. Configure DNS/HTTPS and serve `https://play.lumiarcade.com/.well-known/apple-app-site-association` without redirects. Start from `Deployment/apple-app-site-association.example.json`, replacing every identifier with the actual signed application identifier. Its matching paths are:

   ```json
   {
     "appclips": { "apps": ["TEAM_ID.your.registered.bundle.Clip"] },
     "applinks": {
       "details": [{
         "appIDs": ["TEAM_ID.your.registered.bundle"],
         "components": [
           {"/": "/a/*"},
           {"/": "/g/*"},
           {"/": "/play"}
         ]
       }]
     }
   }
   ```

4. Create the **Lumi Arcade** App Store Connect record. Archive the containing app with its Clip, validate/upload, and configure an App Clip experience/card whose matching URL covers `https://play.lumiarcade.com/a/`. The supplied stack artwork is already the app/Clip icon; choose card artwork and metadata separately. Verify the distributed Clip size using the archive report.
5. For development, run the signed Clip on an iPhone and register a Local Experience in Settings → Developer using `https://play.lumiarcade.com/a/00025`, the actual Clip bundle ID, and card metadata. Xcode URL injection exercises the handler; Local Experiences exercise the card and physical launch.
6. Create the matching row in Supabase, then program the necklace with a standard NFC NDEF URI containing its stable URL, for example `https://play.lumiarcade.com/a/00025`. Changing games does not require rewriting the NFC tag. No Core NFC reader or in-app scan screen is needed.
7. Verify initial resolution, game switching, a second NFC tap, another phone, cache fallback while offline, an unknown ID, and Play Once after a failed update. Also test legacy `/g/{game}/{arcadotID}` score separation and `/play` Local Play. Check both the full-app-installed and Clip-only cases; iOS routes future invocations to the installed full app after it replaces its App Clip. Real NFC and haptics require hardware.

Apple references: [invocation lifecycle](https://developer.apple.com/documentation/appclip/responding-to-invocations), [website association](https://developer.apple.com/documentation/appclip/associating-your-app-clip-with-your-website), [local launch testing](https://developer.apple.com/documentation/appclip/testing-the-launch-experience-of-your-app-clip).

## Debug checks and assets

- `-SkyStackDiagnostics`: FPS/node counters.
- `-SkyStackGameOverPreview`: four successful placements followed by a miss, once per scene, for testing.
- `-SkyStackPreviewScore N`: an explicit 0–100 point completed-run preview, useful for zero/qualifying result states.
- `-SkyStackVoiceOverTest`: assisted alignment timing for local development.
- `-PulseDiagnostics`: FPS/node counters for Pulse.
- `-PulseGameOverPreview`: four scored gates followed by the Pulse results flow.
- `-PulsePreviewScore N`: an explicit 0–100 point Pulse results preview.
- `-LumiArcadeInvocationURL URL`: passes a route through the same shared router without external infrastructure.
- `-LumiArcadeAssignmentGame GAME`: supplies a successful Debug assignment (`pulse` or `sky-stack`) without a server.
- `-LumiArcadeAssignmentUnavailable`: forces Debug assignment requests offline to verify cache and session-only behavior.

These test flags are excluded from Release behavior. The supplied icon is unchanged in `Shared/Assets.xcassets/AppIcon.appiconset`, and its original is retained in `Documentation/app-icon-original.png`. Both targets include a privacy manifest declaring app-local UserDefaults use and no collected data or tracking.

## Verification

- Debug Simulator builds succeed for the full app and embedded App Clip; both generated bundle display names are **Lumi Arcade**.
- **27 unit tests pass.** Coverage includes necklace and legacy routing, remote success, cache isolation/fallback, timeout/unavailable/malformed/unknown responses, request validation, top-five isolation and cutoff ties, legacy migration, invalid initials, and gameplay regressions.
- **10 UI tests pass.** They cover active-run switch confirmation, direct switching after a saved score, fresh game selection, persisted reopening through cache fallback, failed-update Play Once recovery, offline session-only play, per-necklace cache isolation, both games, initials, local boards, and scene restarts.
- The original game regression includes an 81-placement tower and 20 repeated restarts. The revised results backdrop was rebuilt and visually checked after the flow tests.
- The icon artwork is preserved. No third-party iOS package, account system, or remote leaderboard was added.
- Xcode emits its standard App Intents metadata notice; no Swift source warnings were introduced.
- Supabase linking/deployment, physical NFC/card invocation, signing/provisioning, distribution, haptic sensation, and real VoiceOver usability remain environment/device checks.

Current previews: [initials entry](Documentation/initials-iPhoneSE.png) and [leaderboard](Documentation/leaderboard-iPhoneSE.png). Internal test IDs in board previews are test-only; production Arcadots use their actual alphanumeric identifiers.
