# Lumi Arcade launch and Arcadot measurement

`LaunchMeasurement` emits local Instruments signposts under subsystem `game001.performance`. There is no upload, analytics service, URL logging, or persistent measurement storage.

- **Game launch to frame**: SwiftUI app initialization through SpriteKit's first `didFinishUpdate`. This is a CPU preparation interval, not a guarantee that the frame has reached the display. It excludes process startup before app initialization, OS card handling, and downloads.
- **First frame submitted**: marks that first scene update completion.
- **First placement**: the first accepted placement input in this process.
- **Invocation received**: receipt of a URL lifecycle callback, without recording the URL.

Use Xcode Product → Profile with the App Clip scheme and a physical iPhone. Record App Launch and Points of Interest in Instruments. Run Release configuration without the debugger for representative measurements. In Xcode's test report, `testLaunchPerformance` records the full app's Simulator application-launch metric across three measured iterations as a local regression baseline. Simulator times are not NFC launch times.

## Physical end-to-end procedure

Prerequisites: signed Clip on a supported iPhone, configured local or published App Clip experience, an Arcadot with the matching HTTPS NDEF URI, and working invocation-domain association. These require the owner's identifiers and hardware.

1. Record model, iOS version, build, network type, and whether this is a local experience or a published distribution.
2. Film the device and Arcadot with a second camera. Mark Arcadot detection, card presentation, the user's Open action, the first moving block, and the first successful placement. Keep human time-to-press-Open separate from system time.
3. For first-use measurements, use a device where this Clip is not already cached. Note that Xcode-installed/local experiences do not measure production download performance.
4. Repeat at least five times with an already available Clip for repeat-use measurements. Keep network and device conditions comparable; report median and slowest sample.
5. Repeat on cellular and Wi-Fi. Capture failures separately instead of omitting them.
6. Export the signed archive's app-size report from Organizer. Record the applicable per-device Clip variant and both compressed and uncompressed size. The local `.app` directory is only a rough development footprint.

| Condition | Tag → card | Open → first moving block | First placement | Status |
| --- | --- | --- | --- | --- |
| First use, Wi-Fi | — | — | — | Requires physical setup |
| Repeat use, Wi-Fi | — | — | — | Requires physical setup |
| First use, cellular | — | — | — | Requires physical setup |
| Repeat use, cellular | — | — | — | Requires physical setup |

## Physical game-feel checks

- Compare early runs with a new player: the first eight placements increase by 2.5 logical points/second per point; subsequent placements increase by 4.5, capped at 315.
- Perfect timing is approximately 80 ms before reaching the 10-point tolerance cap, then narrows to about 63 ms at maximum speed. Very thin blocks use a width-based tolerance cap to prevent snapping a total miss.
- Normal click and perfect tones should be quiet and remain silent with the hardware silent switch enabled. Existing music should continue. Check interruption/resume during a call or Control Center visit.
- Perfect tones rise over the first five consecutive perfects, then stay capped.
- Enable VoiceOver: motion slows to 65%, alignment holds for 1.3 seconds, and one announcement/chime/haptic occurs per alignment pass. Double-tap during the hold. Confirm cue timing and restart focus with an actual VoiceOver user; Simulator logic tests do not establish usability.
- Enable Reduce Motion: no score-number animation, block squash, feedback drift, offcut rotation/fall, or scaled game-over entrance. Camera tracking remains because it is necessary to keep the tower playable.

## Recorded development baseline — September 12, 2026

Xcode 16.3, iPhone 16 Pro Simulator, iOS 18.4, Debug full-app build, XCTest `XCTApplicationLaunchMetric`: **0.753 seconds average** across measured values **0.753309, 0.755183, 0.750735 seconds**. This is an installed-app Simulator metric; it includes neither NFC/card latency nor the production App Clip download. This is the earlier Sky Stack baseline, before the Lumi Arcade routing/leaderboard update. No device or NFC timing has been measured here.

Lumi Arcade routing/leaderboard update, same full-app Simulator metric: **0.759 seconds average**, measured values **0.765712, 0.767444, 0.742975 seconds**. This remains a Simulator baseline, not a physical Arcadot or download measurement.
