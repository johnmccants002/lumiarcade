import XCTest
import SpriteKit
@testable import SkyStack

final class SkyStackTests: XCTestCase {
    func testOverlapAndOffcutsConserveWidth() throws {
        for offset: CGFloat in [-180, -90, -7, 7, 90, 180] {
            let result = StackPlacement.resolve(moving: .init(center: 200 + offset, width: 228),
                                                supporting: .init(center: 200, width: 228))
            let overlap = try XCTUnwrap(result.overlap)
            XCTAssertEqual(overlap.width, 228 - abs(offset), accuracy: 0.001)
            XCTAssertEqual(overlap.width + result.offcuts.reduce(0) { $0 + $1.width }, 228, accuracy: 0.001)
            XCTAssertFalse(result.isPerfect)
        }
    }

    func testPerfectBoundaryAndMiss() {
        let base = StackSpan(center: 195, width: 228)
        for offset: CGFloat in [-6, 0, 6] {
            let result = StackPlacement.resolve(moving: .init(center: 195 + offset, width: 228), supporting: base)
            XCTAssertEqual(result.overlap, base)
            XCTAssertTrue(result.isPerfect)
            XCTAssertTrue(result.offcuts.isEmpty)
        }
        for offset: CGFloat in [-250, -228, 228, 250] {
            XCTAssertNil(StackPlacement.resolve(moving: .init(center: 195 + offset, width: 228), supporting: base).overlap)
        }
        XCTAssertFalse(StackPlacement.resolve(moving: .init(center: 201.01, width: 228), supporting: base).isPerfect)
    }

    func testArcadotRoutesAndUnknownGamePolicies() {
        let router = ExperienceRouter(unknownGamePolicy: .fallback)
        for id in ["00001", "A72K9", "X82K4"] {
            let url = URL(string: "https://play.lumiarcade.com/g/sky-stack/\(id)?source=nfc")
            let result = router.resolve(AppInvocation(url: url))
            XCTAssertEqual(result, .game(GameInvocation(game: .skyStack, arcadotID: id)))
        }
        XCTAssertEqual(
            router.resolve(AppInvocation(url: URL(string: "https://play.lumiarcade.com/g/pulse/00025"))),
            .game(GameInvocation(game: .pulse, arcadotID: "00025"))
        )
        for raw in ["https://play.lumiarcade.com/g/sky-stack/", "https://play.lumiarcade.com/g/sky-stack/A%2FB",
                    "https://play.lumiarcade.com/g/sky-stack/00001/extra", "http://play.lumiarcade.com/g/sky-stack/00001",
                    "https://other.example/g/sky-stack/00001", "https://play.lumiarcade.com/g/sky-stack/__local__",
                    "https://play.lumiarcade.com/game/sky-stack"] {
            XCTAssertEqual(router.resolve(AppInvocation(url: URL(string: raw))), .game(.localPlay))
        }
        XCTAssertEqual(router.resolve(AppInvocation()), .game(.localPlay))
        let unknown = AppInvocation(url: URL(string: "https://play.lumiarcade.com/g/bounce/00001"))
        XCTAssertEqual(router.resolve(unknown), .game(.localPlay))
        XCTAssertEqual(ExperienceRouter(unknownGamePolicy: .unsupported).resolve(unknown), .unsupported)
    }

    func testQueryGameRoutesAndSafeFallback() throws {
        let router = ExperienceRouter(unknownGamePolicy: .fallback)
        XCTAssertEqual(
            router.route(from: try XCTUnwrap(URL(string: "https://play.lumiarcade.com/play?game=sky-stack"))),
            .game(GameInvocation(game: .skyStack, arcadotID: nil))
        )
        XCTAssertEqual(
            router.route(from: try XCTUnwrap(URL(string: "https://play.lumiarcade.com/play?game=pulse"))),
            .game(GameInvocation(game: .pulse, arcadotID: nil))
        )
        for raw in [
            "https://play.lumiarcade.com/play",
            "https://play.lumiarcade.com/play?game=",
            "https://play.lumiarcade.com/play?game=unknown",
            "https://play.lumiarcade.com/play?game=%25"
        ] {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertEqual(router.route(from: url), .fallback, raw)
        }
    }

    func testGameRegistryContainsEveryImplementedGame() {
        XCTAssertEqual(Set(GameType.allCases), Set([.skyStack, .pulse]))
        for game in GameType.allCases {
            XCTAssertFalse(game.displayName.isEmpty)
            XCTAssertFalse(game.gameNumber.isEmpty)
            XCTAssertFalse(game.summary.isEmpty)
            XCTAssertFalse(game.systemImageName.isEmpty)
        }
    }

    func testPlayerProfilePersistence() throws {
        let name = "LumiArcadeProfile.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let profile = PlayerProfileStore(defaults: defaults)
        XCTAssertEqual(profile.initials, "AAA")
        XCTAssertNil(profile.lastPlayedGame)
        XCTAssertEqual(profile.gamesPlayed, 0)
        XCTAssertTrue(profile.saveInitials("JM9"))
        XCTAssertFalse(profile.saveInitials("bad"))
        profile.recordGameLaunch(.pulse)
        profile.recordCompletedGame()
        profile.recordCompletedGame()

        let restored = PlayerProfileStore(defaults: defaults)
        XCTAssertEqual(restored.initials, "JM9")
        XCTAssertEqual(restored.lastPlayedGame, .pulse)
        XCTAssertEqual(restored.gamesPlayed, 2)
    }

    @MainActor
    func testGameLeaderboardBrowsingAggregatesExistingArcadotBoards() async throws {
        let name = "LumiArcadeGlobalBoard.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let local = LocalLeaderboardService(defaults: defaults)
        for entry in [
            ArcadeScore(arcadotID: "00001", game: .pulse, initials: "ONE", score: 12),
            ArcadeScore(arcadotID: "00002", game: .pulse, initials: "TWO", score: 30),
            ArcadeScore(arcadotID: "00001", game: .skyStack, initials: "SKY", score: 99)
        ] {
            try await local.submit(entry)
        }
        let pulse = try await local.scores(game: .pulse)
        XCTAssertEqual(pulse.map(\.score), [30, 12])
        XCTAssertEqual(pulse.map(\.initials), ["TWO", "ONE"])
        let skyStack = try await local.scores(game: .skyStack)
        XCTAssertEqual(skyStack.map(\.score), [99])
    }

    @MainActor
    func testCompletedRunsAreCountedOnceAndRestore() throws {
        let name = "LumiArcadeGamesPlayed.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let session = SkyStackSession(defaults: defaults)
        session.begin()
        session.end()
        session.end()
        XCTAssertEqual(PlayerProfileStore(defaults: defaults).gamesPlayed, 1)
        session.reset()
        session.begin()
        session.end()
        XCTAssertEqual(PlayerProfileStore(defaults: defaults).gamesPlayed, 2)
        XCTAssertEqual(PlayerProfileStore(defaults: defaults).lastPlayedGame, .skyStack)
    }

    @MainActor
    func testPulseLeaderboardIsSeparatedByGameAndArcadot() async throws {
        let name = "LumiArcadePulseBoard.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let local = LocalLeaderboardService(defaults: defaults)
        let pulse25 = ArcadeScore(arcadotID: "00025", game: .pulse, initials: "PLS", score: 12)
        let pulse26 = ArcadeScore(arcadotID: "00026", game: .pulse, initials: "ORB", score: 20)
        let stack25 = ArcadeScore(arcadotID: "00025", game: .skyStack, initials: "SKY", score: 40)
        try await local.submit(pulse25)
        try await local.submit(pulse26)
        try await local.submit(stack25)

        let pulse25Scores = try await local.scores(game: .pulse, arcadotID: "00025")
        let pulse26Scores = try await local.scores(game: .pulse, arcadotID: "00026")
        let stack25Scores = try await local.scores(game: .skyStack, arcadotID: "00025")
        XCTAssertEqual(pulse25Scores, [pulse25])
        XCTAssertEqual(pulse26Scores, [pulse26])
        XCTAssertEqual(stack25Scores, [stack25])
        XCTAssertTrue(LeaderboardRules.qualifies(13, among: [pulse25]))
    }

    func testPulseDifficultyIsBoundedAndGateScoresOnce() {
        var previousSpeed = PulseConfig.obstacleSpeed(score: 0)
        var previousGap = PulseConfig.gapHeight(score: 0)
        var previousInterval = PulseConfig.spawnInterval(score: 0)
        for score in 0...200 {
            let speed = PulseConfig.obstacleSpeed(score: score)
            let gap = PulseConfig.gapHeight(score: score)
            let interval = PulseConfig.spawnInterval(score: score)
            XCTAssertGreaterThanOrEqual(speed, previousSpeed)
            XCTAssertLessThanOrEqual(speed, PulseConfig.maximumObstacleSpeed)
            XCTAssertLessThanOrEqual(gap, previousGap)
            XCTAssertGreaterThanOrEqual(gap, PulseConfig.minimumGapHeight)
            XCTAssertLessThanOrEqual(interval, previousInterval)
            XCTAssertGreaterThanOrEqual(interval, PulseConfig.minimumSpawnInterval)
            previousSpeed = speed
            previousGap = gap
            previousInterval = interval
        }
        let range = PulseConfig.gapCenterRange(sceneHeight: 568, gapHeight: PulseConfig.initialGapHeight)
        XCTAssertLessThan(range.lowerBound, range.upperBound)
        let gate = PulseObstaclePair(sceneHeight: 568, gapCenterY: range.lowerBound, gapHeight: PulseConfig.initialGapHeight)
        XCTAssertTrue(gate.claimScore())
        XCTAssertFalse(gate.claimScore())
    }

    @MainActor
    func testPulseSessionSaveAndRepeatedSceneRestart() async throws {
        let name = "LumiArcadePulseSession.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let arcadot = Arcadot(id: "00025", game: .pulse)
        let session = PulseSession(defaults: defaults, arcadot: arcadot)
        let scene = PulseScene(session: session)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        scene.update(0)
        scene.pulse()
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(scene.debugOrbVelocity?.dy, PulseConfig.tapVelocity)
        scene.debugSetOrbVelocity(CGVector(dx: 0, dy: -PulseConfig.maxDownwardVelocity))
        scene.pulse()
        XCTAssertEqual(scene.debugOrbVelocity?.dy, PulseConfig.tapVelocity)
        scene.debugPassGate()
        scene.debugPassGate()
        XCTAssertEqual(session.score, 1)
        scene.debugCrash()
        XCTAssertEqual(session.state, .gameOver)
        session.initials = "PLS"
        await session.saveScore()
        XCTAssertEqual(session.leaderboard.map(\.score), [1])
        for _ in 0..<12 {
            scene.restart()
            XCTAssertEqual(session.state, .ready)
            XCTAssertEqual(session.score, 0)
            XCTAssertEqual(scene.debugObstacleCount, 1)
            scene.pulse()
            scene.debugPassGate()
            XCTAssertEqual(session.score, 1)
        }
        view.presentScene(nil)
    }

    @MainActor
    func testPersistenceAndSpeedCap() async throws {
        let suite = "SkyStackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = SkyStackSession(defaults: defaults)
        session.begin()
        session.recordPlacement(perfect: true)
        session.recordPlacement(perfect: true)
        XCTAssertEqual(session.consecutivePerfects, 2)
        session.recordPlacement(perfect: false)
        XCTAssertEqual(session.consecutivePerfects, 0)
        session.end()
        await session.saveScore()
        session.reset()
        XCTAssertEqual(session.score, 0)
        XCTAssertEqual(session.bestScore, 3)
        XCTAssertEqual(SkyStackSession(defaults: defaults).bestScore, 3)
        XCTAssertGreaterThan(SkyStackConfig.speed(score: 1), SkyStackConfig.speed(score: 0))
        XCTAssertEqual(SkyStackConfig.speed(score: 10000), SkyStackConfig.maxSpeed)
    }

    func testDifficultyAndNarrowBlockTolerance() {
        var lastSpeed: CGFloat = 0
        for score in 0...100 {
            let speed = SkyStackConfig.speed(score: score)
            XCTAssertGreaterThanOrEqual(speed, lastSpeed)
            XCTAssertLessThanOrEqual(speed, SkyStackConfig.maxSpeed)
            let tolerance = SkyStackConfig.tolerance(score: score, width: 200)
            XCTAssertGreaterThanOrEqual(2 * tolerance / speed, 0.06)
            lastSpeed = speed
        }
        let narrow = StackSpan(center: 100, width: 2)
        let missed = StackPlacement.resolve(moving: .init(center: 103, width: 2), supporting: narrow,
                                            tolerance: SkyStackConfig.tolerance(score: 40, width: 2))
        XCTAssertNil(missed.overlap)
    }

    @MainActor
    func testBestTargetStaysFixedUntilRestart() async throws {
        let name = "SkyStackTarget.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(2, forKey: Product.legacyBestScoreKey)
        let session = SkyStackSession(defaults: defaults)
        for _ in 0..<3 { session.recordPlacement(perfect: true) }
        XCTAssertEqual(session.targetBest, 2)
        XCTAssertEqual(session.bestScore, 3)
        XCTAssertTrue(session.isNewBest)
        session.end()
        await session.saveScore()
        session.reset()
        XCTAssertEqual(session.targetBest, 3)
        XCTAssertFalse(session.isNewBest)
    }

    func testInitialsCycleAndValidation() {
        XCTAssertEqual(ArcadeInitials.cycling("AAA", column: 0, direction: -1), "9AA")
        XCTAssertEqual(ArcadeInitials.cycling("9AA", column: 0, direction: 1), "AAA")
        XCTAssertEqual(ArcadeInitials.cycling("AZA", column: 1, direction: 1), "A0A")
        for value in ["", "AA", "AAAA", "aBC", "A A", "ÉAA", "💙AA"] { XCTAssertFalse(ArcadeInitials.isValid(value)) }
        XCTAssertTrue(ArcadeInitials.isValid("JM9"))
    }

    @MainActor
    func testLocalTopFiveIsolationReloadAndIdempotency() async throws {
        let name = "LumiArcadeBoard.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let local = LocalLeaderboardService(defaults: defaults)
        for score in [10, 80, 20, 30, 40, 50, 60] {
            try await local.submit(ArcadeScore(arcadotID: "00001", game: .skyStack, initials: "JMC", score: score))
        }
        let other = ArcadeScore(arcadotID: "A72K9", game: .skyStack, initials: "A09", score: 99)
        try await local.submit(other)
        try await local.submit(other)
        let reloaded = LocalLeaderboardService(defaults: defaults)
        let scores = try await reloaded.scores(game: .skyStack, arcadotID: "00001")
        XCTAssertEqual(scores.map(\.score), [80, 60, 50, 40, 30])
        XCTAssertFalse(LeaderboardRules.qualifies(30, among: scores))
        XCTAssertTrue(LeaderboardRules.qualifies(31, among: scores))
        XCTAssertFalse(LeaderboardRules.qualifies(0, among: []))
        let isolated = try await reloaded.scores(game: .skyStack, arcadotID: "A72K9")
        XCTAssertEqual(isolated, [other])
        XCTAssertEqual(reloaded.lastInitials, "A09")
        let empty = try await reloaded.scores(game: .skyStack, arcadotID: "00002")
        XCTAssertTrue(empty.isEmpty)
        do {
            try await local.submit(ArcadeScore(arcadotID: "00001", game: .skyStack, initials: "ab!", score: 100))
            XCTFail("Invalid initials must not be stored")
        } catch { }
    }

    @MainActor
    func testLegacyMigrationOnlyAffectsLocalPlay() async throws {
        let name = "LumiArcadeMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(42, forKey: Product.legacyBestScoreKey)
        let local = LocalLeaderboardService(defaults: defaults)
        XCTAssertTrue(try local.snapshot(game: .skyStack, arcadotID: "00001").isEmpty)
        let migrated = try local.snapshot(game: .skyStack, arcadotID: Product.localScoreID)
        XCTAssertEqual(migrated.map(\.score), [42])
        XCTAssertEqual(migrated.first?.initials, "AAA")
        XCTAssertEqual(try local.snapshot(game: .skyStack, arcadotID: Product.localScoreID), migrated)
    }

    @MainActor
    func testSaveFlowAndNonQualifyingScore() async throws {
        let name = "LumiArcadeSession.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let arcadot = Arcadot(id: "00001", game: .skyStack)
        let local = LocalLeaderboardService(defaults: defaults)
        for score in [50, 40, 30, 20, 10] {
            try await local.submit(ArcadeScore(arcadotID: arcadot.id, game: .skyStack, initials: "ACE", score: score))
        }
        let session = SkyStackSession(defaults: defaults, arcadot: arcadot)
        for _ in 0..<11 { session.recordPlacement(perfect: false) }
        session.end()
        XCTAssertEqual(session.resultStage, .initials)
        XCTAssertFalse(session.isNewBest)
        session.initials = "JM9"
        await session.saveScore()
        await session.saveScore()
        XCTAssertEqual(session.resultStage, .leaderboard)
        XCTAssertEqual(session.leaderboard.map(\.score), [50, 40, 30, 20, 11])
        XCTAssertEqual(session.leaderboard.last?.initials, "JM9")
        XCTAssertEqual(session.identityLabel, "ARCADOT #00001")
        session.reset()
        session.recordPlacement(perfect: false)
        session.end()
        XCTAssertEqual(session.resultStage, .leaderboard)
    }

    @MainActor
    func testUnreadableBoardIsNotOverwritten() async throws {
        let name = "LumiArcadeCorrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let local = LocalLeaderboardService(defaults: defaults)
        try await local.submit(ArcadeScore(arcadotID: "00001", game: .skyStack, initials: "AAA", score: 5))
        let key = try XCTUnwrap(defaults.dictionaryRepresentation().keys.first { $0.hasPrefix("lumiarcade.leaderboard.v1.") })
        let corrupt = Data("unreadable".utf8)
        defaults.set(corrupt, forKey: key)
        let session = SkyStackSession(defaults: defaults, arcadot: Arcadot(id: "00001", game: .skyStack))
        session.recordPlacement(perfect: true)
        session.end()
        await session.saveScore()
        XCTAssertNotNil(session.saveError)
        XCTAssertEqual(session.resultStage, .initials)
        XCTAssertEqual(defaults.data(forKey: key), corrupt)
        XCTAssertFalse(session.isSaving)
    }

    @MainActor
    func testAssistedAlignmentAndRestartDuringFailure() throws {
        let suite = "SkyStackAssist.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = SkyStackSession(defaults: defaults)
        let scene = SkyStackScene(session: session)
        scene.debugVoiceOverOverride = true
        scene.reduceMotion = true
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        scene.update(0)
        for index in 1...60 { scene.update(Double(index) / 60) }
        XCTAssertEqual(try XCTUnwrap(scene.debugMovingX), 195, accuracy: 0.001)
        scene.placeMovingBlock()
        XCTAssertEqual(session.consecutivePerfects, 1)
        scene.debugPlace(offset: 400)
        XCTAssertEqual(session.state, .falling)
        scene.restart()
        for index in 1...40 { scene.update(1 + Double(index) / 60) }
        XCTAssertEqual(session.state, .ready)
        XCTAssertEqual(session.score, 0)
        view.presentScene(nil)
    }

    @MainActor
    func testSceneMotionCropCameraMissAndRepeatedRestart() async throws {
        let suite = "SkyStackSceneTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = SkyStackSession(defaults: defaults)
        let scene = SkyStackScene(session: session)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        let initialX = try XCTUnwrap(scene.debugMovingX)
        scene.update(1)
        scene.update(1.016)
        XCTAssertGreaterThan(try XCTUnwrap(scene.debugMovingX), initialX)
        scene.debugPlace(offset: 20)
        XCTAssertEqual(session.score, 1)
        XCTAssertEqual(try XCTUnwrap(scene.debugTopWidth), 208)
        XCTAssertGreaterThan(scene.debugDebrisCount, 0)
        for _ in 0..<80 { scene.debugPlace(offset: 0) }
        for index in 1...120 { scene.update(1.016 + Double(index) / 60) }
        XCTAssertEqual(session.score, 81)
        XCTAssertEqual(session.consecutivePerfects, 80)
        XCTAssertEqual(scene.debugPerfectText, "PERFECT ×80")
        XCTAssertGreaterThan(scene.debugCameraY, 2000)
        XCTAssertLessThan(scene.children.flatMap(\.children).count, 120)
        let widthBeforeResize = scene.debugTopWidth
        scene.size = CGSize(width: 320, height: 568)
        XCTAssertEqual(scene.debugTopWidth, widthBeforeResize)
        scene.debugPlace(offset: 300)
        XCTAssertEqual(session.state, .falling)
        XCTAssertGreaterThan(scene.debugFailureRemaining, 0)
        for index in 1...20 { scene.update(3.016 + Double(index) / 60) }
        XCTAssertEqual(session.state, .gameOver)
        XCTAssertNil(scene.debugMovingX)
        scene.placeMovingBlock()
        XCTAssertEqual(session.score, 81)
        await session.saveScore()
        for _ in 0..<20 {
            scene.restart()
            XCTAssertEqual(session.state, .ready)
            XCTAssertEqual(session.score, 0)
            XCTAssertEqual(session.consecutivePerfects, 0)
            XCTAssertEqual(scene.debugDebrisCount, 0)
            XCTAssertEqual(scene.children.count, 4)
            XCTAssertEqual(scene.debugTopWidth, SkyStackConfig.initialBlockWidth)
            scene.debugPlace(offset: 0)
            XCTAssertEqual(session.score, 1)
        }
        XCTAssertEqual(session.bestScore, 81)
        view.presentScene(nil)
    }
}
