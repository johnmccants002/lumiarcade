import SpriteKit
import UIKit

final class PulseScene: SKScene, SKPhysicsContactDelegate {
    let session: PulseSession
    private let haptics = GameHaptics()
    private let audio = GameAudio()
    private let obstacleLayer = SKNode()
    private let effectLayer = SKNode()
    private let ambientLayer = SKNode()
    private var orb: PulseOrb?
    private var lastUpdate: TimeInterval?
    private var spawnElapsed: TimeInterval = 0
    private var configured = false
    private var collisionHandled = false
    private var audioPrepared = false
    private var previewUsed = false
    var reduceMotion = false { didSet { updateMotionPreferences() } }

    init(session: PulseSession) {
        self.session = session
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = .clear
        physicsWorld.contactDelegate = self
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard !configured else { return }
        configured = true
        addChild(ambientLayer)
        addChild(obstacleLayer)
        addChild(effectLayer)
        buildAmbientField()
        restart()
        #if DEBUG
        view.showsFPS = ProcessInfo.processInfo.arguments.contains("-PulseDiagnostics")
        view.showsNodeCount = ProcessInfo.processInfo.arguments.contains("-PulseDiagnostics")
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard configured else { return }
        buildBoundaries()
        if session.state == .ready {
            orb?.position = PulseConfig.readyPosition(sceneSize: size)
        }
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
        removeAction(forKey: "gameOver")
        obstacleLayer.removeAllActions()
        obstacleLayer.removeAllChildren()
        effectLayer.removeAllActions()
        effectLayer.removeAllChildren()
        childNode(withName: "pulseBoundary")?.removeFromParent()
        orb?.removeAllActions()
        orb?.removeFromParent()
        orb = nil

        session.reset()
        collisionHandled = false
        spawnElapsed = 0
        lastUpdate = nil
        physicsWorld.gravity = .zero
        buildBoundaries()

        let newOrb = PulseOrb()
        newOrb.position = PulseConfig.readyPosition(sceneSize: size)
        newOrb.setTrailTarget(self)
        newOrb.setReduceMotion(reduceMotion)
        addChild(newOrb)
        orb = newOrb
        beginReadyAnimation()
        spawnGate(initial: true)
        haptics.prepare()

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let previewIndex = arguments.firstIndex(of: "-PulsePreviewScore")
        let previewScore: Int? = previewIndex.flatMap { index in
            guard arguments.indices.contains(index + 1), let score = Int(arguments[index + 1]),
                  (0...100).contains(score) else { return nil }
            return score
        }
        if !previewUsed && (arguments.contains("-PulseGameOverPreview") || previewScore != nil) {
            previewUsed = true
            session.begin()
            for _ in 0..<(previewScore ?? 4) { session.passGate() }
            session.end()
        }
        #endif
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else { return }
        pulse()
    }

    func pulse() {
        guard let orb, session.state != .gameOver else { return }
        if session.state == .ready {
            session.begin()
            orb.removeAction(forKey: "readyBob")
            orb.physicsBody?.affectedByGravity = true
            physicsWorld.gravity = CGVector(dx: 0, dy: PulseConfig.gravity)
            spawnElapsed = 0
        }
        guard session.state == .playing, let body = orb.physicsBody else { return }
        // A fixed vertical velocity makes every tap immediately responsive,
        // independent of SpriteKit's automatically calculated body mass.
        body.velocity = CGVector(dx: 0, dy: PulseConfig.tapVelocity)
        orb.pulse(reduceMotion: reduceMotion)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isPaused else { lastUpdate = nil; return }
        guard let previous = lastUpdate else { lastUpdate = currentTime; return }
        let dt = min(max(currentTime - previous, 0), 1.0 / 30.0)
        lastUpdate = currentTime
        guard session.state == .playing, let orb, let body = orb.physicsBody else { return }

        body.velocity.dy = min(PulseConfig.maxUpwardVelocity,
                               max(-PulseConfig.maxDownwardVelocity, body.velocity.dy))
        let targetTilt = max(-0.42, min(0.28, body.velocity.dy / 850))
        orb.zRotation += (targetTilt - orb.zRotation) * CGFloat(1 - exp(-8 * dt))

        let speed = PulseConfig.obstacleSpeed(score: session.score)
        for case let gate as PulseObstaclePair in obstacleLayer.children {
            gate.position.x -= speed * CGFloat(dt)
            if gate.position.x < -PulseConfig.obstacleWidth { gate.removeFromParent() }
        }

        spawnElapsed += dt
        let interval = PulseConfig.spawnInterval(score: session.score)
        if spawnElapsed >= interval {
            spawnElapsed -= interval
            spawnGate(initial: false)
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        let playerAndObstacle = PulsePhysicsCategory.player | PulsePhysicsCategory.obstacle
        let playerAndBoundary = PulsePhysicsCategory.player | PulsePhysicsCategory.boundary
        let playerAndScore = PulsePhysicsCategory.player | PulsePhysicsCategory.scoreZone

        if categories == playerAndObstacle || categories == playerAndBoundary {
            endGame(at: contact.contactPoint)
            return
        }
        guard categories == playerAndScore else { return }
        let scoreBody = contact.bodyA.categoryBitMask == PulsePhysicsCategory.scoreZone ? contact.bodyA : contact.bodyB
        if let gate = scoreBody.node?.parent as? PulseObstaclePair { score(gate) }
    }

    private func score(_ gate: PulseObstaclePair) {
        guard session.state == .playing, gate.claimScore() else { return }
        let previousScore = session.score
        let score = session.passGate()
        let becameHighScore = previousScore <= session.targetBest && score > session.targetBest

        if becameHighScore {
            haptics.newHighScore()
            audio.play(.pulseHigh)
            showMessage("NEW HIGH SCORE", color: SKColor(red: 0.55, green: 0.96, blue: 1, alpha: 1))
        } else if PulseConfig.milestones.contains(score) {
            haptics.milestone()
            audio.play(.pulseHigh)
            showMessage("PULSE  \(score)", color: .white)
        } else {
            haptics.gatePassed()
            audio.play(.pulseGate)
        }
        showGatePulse(at: CGPoint(x: orb?.position.x ?? size.width * PulseConfig.playerXFraction,
                                  y: orb?.position.y ?? size.height / 2))
    }

    private func endGame(at point: CGPoint) {
        guard session.state == .playing, !collisionHandled else { return }
        collisionHandled = true
        session.end()
        orb?.physicsBody?.velocity = .zero
        orb?.physicsBody?.affectedByGravity = false
        orb?.physicsBody?.isDynamic = false
        orb?.setReduceMotion(true)
        haptics.gameOver()
        audio.play(.pulseCollision)
        showCollision(at: point)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Game over. Score \(session.score). Best \(session.bestScore).")
        }
    }

    private func spawnGate(initial: Bool) {
        guard session.state != .gameOver else { return }
        let gapHeight = PulseConfig.gapHeight(score: session.score)
        let range = PulseConfig.gapCenterRange(sceneHeight: size.height, gapHeight: gapHeight)
        let center = initial ? PulseConfig.readyPosition(sceneSize: size).y
                             : CGFloat.random(in: range)
        let gate = PulseObstaclePair(sceneHeight: size.height, gapCenterY: center, gapHeight: gapHeight)
        gate.position.x = initial
            ? size.width + PulseConfig.obstacleWidth / 2 - PulseConfig.firstGateInset
            : size.width + PulseConfig.obstacleWidth / 2
        obstacleLayer.addChild(gate)
    }

    private func buildBoundaries() {
        childNode(withName: "pulseBoundary")?.removeFromParent()
        let boundaries = SKNode()
        boundaries.name = "pulseBoundary"
        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -40, y: PulseConfig.floorY),
                                          to: CGPoint(x: size.width + 40, y: PulseConfig.floorY))
        configureBoundary(floor.physicsBody)
        boundaries.addChild(floor)
        let ceilingY = PulseConfig.playableTop(sceneHeight: size.height)
        let ceiling = SKNode()
        ceiling.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -40, y: ceilingY),
                                            to: CGPoint(x: size.width + 40, y: ceilingY))
        configureBoundary(ceiling.physicsBody)
        boundaries.addChild(ceiling)
        addChild(boundaries)
    }

    private func configureBoundary(_ body: SKPhysicsBody?) {
        body?.isDynamic = false
        body?.categoryBitMask = PulsePhysicsCategory.boundary
        body?.collisionBitMask = PulsePhysicsCategory.player
        body?.contactTestBitMask = PulsePhysicsCategory.player
        body?.friction = 0
        body?.restitution = 0
    }

    private func beginReadyAnimation() {
        guard !reduceMotion, let orb else { return }
        orb.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.8),
                                          .moveBy(x: 0, y: -6, duration: 0.8)])),
                withKey: "readyBob")
    }

    private func updateMotionPreferences() {
        orb?.setReduceMotion(reduceMotion)
        if reduceMotion {
            orb?.removeAction(forKey: "readyBob")
        } else if session.state == .ready, orb?.action(forKey: "readyBob") == nil {
            beginReadyAnimation()
        }
    }

    private func showGatePulse(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: PulseConfig.orbRadius * 1.3)
        ring.position = point
        ring.strokeColor = SKColor(red: 0.35, green: 0.9, blue: 1, alpha: 0.7)
        ring.lineWidth = 2
        ring.fillColor = .clear
        effectLayer.addChild(ring)
        let scale: CGFloat = reduceMotion ? 1.35 : 2.25
        ring.run(.sequence([.group([.scale(to: scale, duration: 0.32),
                                    .fadeOut(withDuration: 0.32)]),
                            .removeFromParent()]))
    }

    private func showMessage(_ text: String, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 12
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        label.zPosition = 40
        effectLayer.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: reduceMotion ? 0 : 14, duration: 0.7),
                                    .sequence([.wait(forDuration: 0.28), .fadeOut(withDuration: 0.42)])]),
                             .removeFromParent()]))
    }

    private func showCollision(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: PulseConfig.orbRadius)
        ring.position = point
        ring.strokeColor = SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 0.85)
        ring.lineWidth = 3
        ring.glowWidth = 7
        effectLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: reduceMotion ? 1.4 : 3.2, duration: 0.28),
                                    .fadeOut(withDuration: 0.28)]),
                            .removeFromParent()]))
    }

    private func buildAmbientField() {
        ambientLayer.removeAllChildren()
        for index in 0..<18 {
            let dot = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 1.4 : 0.8)
            dot.fillColor = .white.withAlphaComponent(index.isMultiple(of: 4) ? 0.18 : 0.1)
            dot.strokeColor = .clear
            let x = CGFloat((index * 73) % 389) / 389 * max(size.width, 1)
            let y = CGFloat((index * 137 + 41) % 823) / 823 * max(size.height, 1)
            dot.position = CGPoint(x: x, y: y)
            ambientLayer.addChild(dot)
        }
    }

    #if DEBUG
    var debugObstacleCount: Int { obstacleLayer.children.count }
    var debugOrbPosition: CGPoint? { orb?.position }
    var debugOrbVelocity: CGVector? { orb?.physicsBody?.velocity }
    func debugSetOrbVelocity(_ velocity: CGVector) { orb?.physicsBody?.velocity = velocity }
    func debugPassGate() {
        if session.state == .ready { pulse() }
        guard let gate = obstacleLayer.children.compactMap({ $0 as? PulseObstaclePair }).first else { return }
        score(gate)
    }
    func debugCrash() { endGame(at: orb?.position ?? .zero) }
    #endif
}
