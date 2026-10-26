import SpriteKit
import UIKit

final class OrbitScene: SKScene {
    let session: OrbitSession
    private let haptics = GameHaptics()
    private let audio = GameAudio()
    private let arenaLayer = SKNode()
    private let hazardLayer = SKNode()
    private let effectLayer = SKNode()
    private let player = SKNode()
    private let playerGlow = SKShapeNode(circleOfRadius: OrbitConfig.playerRadius * 1.8)
    private let playerCore = SKShapeNode(circleOfRadius: OrbitConfig.playerRadius)

    private var hazards: [OrbitHazard] = []
    private var orbitCenter = CGPoint.zero
    private var orbitRadius: CGFloat = 120
    private var lastUpdate: TimeInterval?
    private var spawnElapsed: TimeInterval = 0
    private var nextSpawnDelay = OrbitConfig.initialGracePeriod
    private var spawnCount = 0
    private var configured = false
    private var collisionHandled = false
    private var audioPrepared = false
    private var previewUsed = false
    var reduceMotion = false { didSet { updateMotionPreferences() } }

    init(session: OrbitSession) {
        self.session = session
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard !configured else { return }
        configured = true
        addChild(arenaLayer)
        addChild(hazardLayer)
        addChild(effectLayer)
        buildPlayer()
        restart()
        #if DEBUG
        view.showsFPS = ProcessInfo.processInfo.arguments.contains("-OrbitDiagnostics")
        view.showsNodeCount = ProcessInfo.processInfo.arguments.contains("-OrbitDiagnostics")
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard configured else { return }
        buildArena()
        hazards.forEach { $0.rebuild(orbitRadius: orbitRadius) }
        updatePlayerPosition()
    }

    override func didFinishUpdate() {
        LaunchMeasurement.frameSubmitted()
        guard !audioPrepared else { return }
        audioPrepared = true
        audio.prepare()
    }

    func resumeClock() { lastUpdate = nil }

    func suspend() {
        isPaused = true
        lastUpdate = nil
        audio.suspend()
    }

    func restart() {
        removeAllActions()
        hazardLayer.removeAllActions()
        hazardLayer.removeAllChildren()
        effectLayer.removeAllActions()
        effectLayer.removeAllChildren()
        hazards.removeAll(keepingCapacity: true)
        player.removeAllActions()
        player.alpha = 1
        player.setScale(1)
        playerCore.fillColor = SKColor(red: 0.72, green: 0.42, blue: 1, alpha: 1)
        playerCore.strokeColor = .white

        session.reset()
        collisionHandled = false
        spawnElapsed = 0
        nextSpawnDelay = OrbitConfig.initialGracePeriod
        spawnCount = 0
        lastUpdate = nil
        buildArena()
        updatePlayerPosition()
        beginReadyAnimation()
        haptics.prepare()

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let previewIndex = arguments.firstIndex(of: "-OrbitPreviewScore")
        let previewScore: Int? = previewIndex.flatMap { index in
            guard arguments.indices.contains(index + 1), let score = Int(arguments[index + 1]),
                  (0...300).contains(score) else { return nil }
            return score
        }
        if !previewUsed && (arguments.contains("-OrbitGameOverPreview") || previewScore != nil) {
            previewUsed = true
            session.preparePreview(score: previewScore ?? 12)
        }
        #endif
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else { return }
        tap()
    }

    func tap() {
        guard session.state != .gameOver else { return }
        if session.state == .ready {
            player.removeAction(forKey: "readyPulse")
            player.setScale(1)
            session.begin()
            lastUpdate = nil
            haptics.placement()
            audio.play(.orbitReverse)
            return
        }
        guard session.state == .playing else { return }
        session.reverseDirection()
        haptics.reverse()
        audio.play(.orbitReverse)
        showReversePulse()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isPaused else { lastUpdate = nil; return }
        guard let previous = lastUpdate else { lastUpdate = currentTime; return }
        let deltaTime = min(max(currentTime - previous, 0), 1.0 / 30.0)
        lastUpdate = currentTime
        guard session.state == .playing else { return }

        let previousScore = session.score
        if let score = session.advance(deltaTime: deltaTime) {
            handleScoreChange(from: previousScore, to: score)
        }

        for hazard in hazards { hazard.update(deltaTime: deltaTime) }
        hazards.removeAll { hazard in
            guard hazard.isExpired else { return false }
            hazard.node.removeFromParent()
            return true
        }

        spawnElapsed += deltaTime
        if spawnElapsed >= nextSpawnDelay {
            spawnElapsed = 0
            if spawnHazard() {
                nextSpawnDelay = OrbitConfig.spawnInterval(survivalTime: session.survivalTime)
            } else {
                nextSpawnDelay = 0.65
            }
        }

        updatePlayerPosition()
        detectCollision()
    }

    private func buildPlayer() {
        player.name = "orbitPlayer"
        player.zPosition = 30
        playerGlow.fillColor = SKColor(red: 0.65, green: 0.36, blue: 1, alpha: 0.14)
        playerGlow.strokeColor = SKColor(red: 0.75, green: 0.52, blue: 1, alpha: 0.38)
        playerGlow.lineWidth = 1
        playerGlow.glowWidth = 12
        playerCore.fillColor = SKColor(red: 0.72, green: 0.42, blue: 1, alpha: 1)
        playerCore.strokeColor = .white
        playerCore.lineWidth = 2
        playerCore.glowWidth = 5
        player.addChild(playerGlow)
        player.addChild(playerCore)
        addChild(player)
    }

    private func buildArena() {
        arenaLayer.removeAllChildren()
        orbitCenter = OrbitConfig.orbitCenter(sceneSize: size)
        orbitRadius = OrbitConfig.orbitRadius(sceneSize: size)

        let outerGlow = SKShapeNode(circleOfRadius: orbitRadius)
        outerGlow.position = orbitCenter
        outerGlow.strokeColor = SKColor(red: 0.62, green: 0.38, blue: 1, alpha: 0.12)
        outerGlow.lineWidth = 8
        outerGlow.glowWidth = 10
        outerGlow.zPosition = 1
        arenaLayer.addChild(outerGlow)

        let track = SKShapeNode(circleOfRadius: orbitRadius)
        track.position = orbitCenter
        track.strokeColor = SKColor(red: 0.72, green: 0.63, blue: 1, alpha: 0.48)
        track.lineWidth = 1.5
        track.zPosition = 2
        arenaLayer.addChild(track)

        let coreGlow = SKShapeNode(circleOfRadius: 30)
        coreGlow.position = orbitCenter
        coreGlow.fillColor = SKColor(red: 0.36, green: 0.16, blue: 0.68, alpha: 0.2)
        coreGlow.strokeColor = SKColor(red: 0.73, green: 0.5, blue: 1, alpha: 0.28)
        coreGlow.lineWidth = 1
        coreGlow.glowWidth = 15
        coreGlow.zPosition = 2
        arenaLayer.addChild(coreGlow)

        let core = SKShapeNode(circleOfRadius: 13)
        core.position = orbitCenter
        core.fillColor = SKColor(red: 0.5, green: 0.28, blue: 0.86, alpha: 0.95)
        core.strokeColor = SKColor(red: 0.91, green: 0.82, blue: 1, alpha: 0.9)
        core.lineWidth = 2
        core.glowWidth = 7
        core.zPosition = 3
        arenaLayer.addChild(core)

        hazardLayer.position = orbitCenter
        effectLayer.position = .zero
    }

    private func updatePlayerPosition() {
        player.position = CGPoint(
            x: orbitCenter.x + cos(session.playerAngle) * orbitRadius,
            y: orbitCenter.y + sin(session.playerAngle) * orbitRadius
        )
    }

    private func spawnHazard() -> Bool {
        let maximum = OrbitConfig.maximumConcurrentHazards(survivalTime: session.survivalTime)
        guard hazards.count < maximum else { return false }

        let kind = nextHazardKind()
        let offsets: [CGFloat] = spawnCount.isMultiple(of: 2)
            ? [1.72, -1.9, 2.4, -2.45]
            : [-1.78, 1.95, -2.35, 2.5]
        let direction = session.direction
        guard let angle = offsets
            .map({ OrbitConfig.normalizedAngle(session.playerAngle + direction * $0) })
            .first(where: isFairSpawnAngle) else { return false }

        let velocity: CGFloat
        let lifetime: TimeInterval
        switch kind {
        case .stationaryBlocker:
            velocity = 0
            lifetime = OrbitConfig.stationaryLifetime
        case .movingBlocker:
            velocity = -direction * OrbitConfig.movingBlockerSpeed
            lifetime = OrbitConfig.movingLifetime
        case .sweeper:
            velocity = spawnCount.isMultiple(of: 2)
                ? OrbitConfig.sweeperSpeed : -OrbitConfig.sweeperSpeed
            lifetime = OrbitConfig.sweeperLifetime
        }

        let hazard = OrbitHazard(kind: kind, angle: angle, angularVelocity: velocity,
                                 orbitRadius: orbitRadius,
                                 warningDuration: OrbitConfig.warningDuration,
                                 activeDuration: lifetime)
        hazards.append(hazard)
        hazardLayer.addChild(hazard.node)
        spawnCount += 1
        return true
    }

    private func nextHazardKind() -> OrbitHazard.Kind {
        let elapsed = session.survivalTime
        if elapsed < 15 { return .stationaryBlocker }
        if elapsed < 40 {
            return spawnCount.isMultiple(of: 3) ? .movingBlocker : .stationaryBlocker
        }
        switch spawnCount % 4 {
        case 1: return .movingBlocker
        case 3: return .sweeper
        default: return .stationaryBlocker
        }
    }

    private func isFairSpawnAngle(_ angle: CGFloat) -> Bool {
        guard OrbitConfig.angularDistance(angle, session.playerAngle)
                >= OrbitConfig.minimumPlayerSpawnSeparation else { return false }
        return hazards.allSatisfy {
            OrbitConfig.angularDistance(angle, $0.angle) >= OrbitConfig.minimumHazardSeparation
        }
    }

    private func detectCollision() {
        let playerAngularRadius = asin(min(1, OrbitConfig.playerRadius / orbitRadius))
        guard let collision = hazards.first(where: {
            $0.isActive && OrbitConfig.angularDistance(session.playerAngle, $0.angle)
                <= $0.halfSpan + playerAngularRadius * 0.72
        }) else { return }
        endGame(at: player.position, hazard: collision)
    }

    private func endGame(at point: CGPoint, hazard: OrbitHazard) {
        guard session.state == .playing, !collisionHandled else { return }
        collisionHandled = true
        session.end()
        player.removeAllActions()
        haptics.gameOver()
        audio.play(.orbitCollision)
        showCollision(at: point)
        hazard.node.run(.sequence([.fadeAlpha(to: 0.25, duration: 0.05),
                                   .fadeAlpha(to: 1, duration: 0.08)]))
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Game over. Score \(session.score). Best \(session.bestScore).")
        }
    }

    private func handleScoreChange(from previousScore: Int, to score: Int) {
        if previousScore <= session.targetBest && score > session.targetBest {
            haptics.newHighScore()
            audio.play(.orbitMilestone)
        } else if OrbitConfig.milestones.contains(score) {
            haptics.milestone()
            audio.play(.orbitMilestone)
            showMilestone(score)
        }
    }

    private func beginReadyAnimation() {
        guard !reduceMotion else { return }
        player.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.7),
            .scale(to: 1, duration: 0.7)
        ])), withKey: "readyPulse")
    }

    private func showReversePulse() {
        guard !reduceMotion else { return }
        let ring = SKShapeNode(circleOfRadius: OrbitConfig.playerRadius * 1.2)
        ring.position = player.position
        ring.strokeColor = SKColor(red: 0.8, green: 0.62, blue: 1, alpha: 0.9)
        ring.lineWidth = 2
        ring.zPosition = 24
        effectLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.2, duration: 0.22),
                                    .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
    }

    private func showCollision(at point: CGPoint) {
        playerCore.fillColor = SKColor(red: 1, green: 0.3, blue: 0.48, alpha: 1)
        guard !reduceMotion else { return }
        for index in 0..<10 {
            let fragment = SKShapeNode(circleOfRadius: 2.2)
            fragment.position = point
            fragment.fillColor = SKColor(red: 0.9, green: 0.62, blue: 1, alpha: 1)
            fragment.strokeColor = .clear
            fragment.zPosition = 35
            effectLayer.addChild(fragment)
            let angle = CGFloat(index) / 10 * 2 * .pi
            let distance: CGFloat = 32 + CGFloat(index % 3) * 7
            fragment.run(.sequence([.group([
                .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.28),
                .fadeOut(withDuration: 0.28),
                .scale(to: 0.25, duration: 0.28)
            ]), .removeFromParent()]))
        }
    }

    private func showMilestone(_ score: Int) {
        guard !reduceMotion else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "ORBIT  \(score)"
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.86, green: 0.72, blue: 1, alpha: 1)
        label.position = CGPoint(x: orbitCenter.x, y: orbitCenter.y - orbitRadius - 48)
        label.zPosition = 40
        effectLayer.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 12, duration: 0.6),
                                    .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
    }

    private func updateMotionPreferences() {
        playerGlow.glowWidth = reduceMotion ? 4 : 12
        if reduceMotion {
            player.removeAction(forKey: "readyPulse")
            player.setScale(1)
        } else if session.state == .ready {
            beginReadyAnimation()
        }
    }

    #if DEBUG
    var debugHazardCount: Int { hazards.count }
    var debugPlayerAngle: CGFloat { session.playerAngle }
    func debugAdvance(_ deltaTime: TimeInterval) { _ = session.advance(deltaTime: deltaTime); updatePlayerPosition() }
    func debugEndGame() {
        guard session.state == .playing else { return }
        endGame(at: player.position,
                hazard: hazards.first ?? OrbitHazard(kind: .stationaryBlocker,
                                                     angle: session.playerAngle,
                                                     angularVelocity: 0,
                                                     orbitRadius: orbitRadius,
                                                     warningDuration: 0,
                                                     activeDuration: 1))
    }
    #endif
}
