import SpriteKit

final class SkyStackScene: SKScene {
    let session: SkyStackSession
    private let haptics = GameHaptics()
    private let audio = GameAudio()
    private let milestones = SKNode()
    var reduceMotion = false
    private var previewUsed = false
    private var audioPrepared = false
    private var failureRemaining: CGFloat = 0
    private var alignmentRemaining: CGFloat = 0
    private var alignmentArmed = true
    private var baseY: CGFloat = 110
    private var voiceOverEnabled: Bool {
        #if DEBUG
        if let debugVoiceOverOverride { return debugVoiceOverOverride }
        if ProcessInfo.processInfo.arguments.contains("-SkyStackVoiceOverTest") { return true }
        #endif
        return UIAccessibility.isVoiceOverRunning
    }
    private let tower = SKNode()
    private let debris = SKNode()
    private let gameCamera = SKCameraNode()
    private var topBlock: StackBlock?
    private var movingBlock: StackBlock?
    private var direction: CGFloat = 1
    private var lastUpdate: TimeInterval?
    private var cameraTarget: CGFloat = 0
    private var configured = false

    init(session: SkyStackSession) {
        self.session = session
        super.init(size: CGSize(width: SkyStackConfig.worldWidth, height: 844))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard !configured else { return }
        configured = true
        addChild(milestones)
        addChild(tower)
        addChild(debris)
        addChild(gameCamera)
        camera = gameCamera
        restart()
        #if DEBUG
        view.showsFPS = SkyStackConfig.showsDiagnostics
        view.showsNodeCount = SkyStackConfig.showsDiagnostics
        #endif
    }

    // Keep world geometry stable when the view changes size; only the camera's
    // framing changes. This avoids modifying block widths in the middle of a run.
    private var worldHeight: CGFloat {
        SkyStackConfig.worldWidth * size.height / max(1, size.width)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard configured else { return }
        updateFraming(immediately: true)
    }

    func resumeClock() { lastUpdate = nil }

    func suspend() {
        isPaused = true
        lastUpdate = nil
        audio.suspend()
    }

    override func didFinishUpdate() {
        LaunchMeasurement.frameSubmitted()
        guard !audioPrepared else { return }
        audioPrepared = true
        // Audio preparation is queued only after the first scene update.
        audio.prepare()
    }

    func restart() {
        removeAllActions()
        milestones.removeAllActions()
        milestones.alpha = 1
        milestones.removeAllChildren()
        tower.removeAllChildren()
        debris.removeAllChildren()
        gameCamera.removeAllActions()
        gameCamera.removeAllChildren()
        movingBlock = nil
        lastUpdate = nil
        direction = 1
        failureRemaining = 0
        alignmentRemaining = 0
        alignmentArmed = true
        session.reset()
        baseY = max(140, worldHeight * SkyStackConfig.startingHeightFraction)
        let base = StackBlock(width: SkyStackConfig.initialBlockWidth, color: .init(white: 0.37, alpha: 1))
        base.position = CGPoint(x: SkyStackConfig.worldWidth / 2, y: baseY)
        tower.addChild(base)
        topBlock = base
        addBestMarker()
        spawnBlock()
        updateFraming(immediately: true)
        haptics.prepare()
        tower.alpha = 1
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let previewIndex = arguments.firstIndex(of: "-SkyStackPreviewScore")
        let previewScore: Int? = previewIndex.flatMap { index in
            guard arguments.indices.contains(index + 1), let score = Int(arguments[index + 1]),
                  (0...100).contains(score) else { return nil }
            return score
        }
        if !previewUsed && (arguments.contains("-SkyStackGameOverPreview") || previewScore != nil) {
            previewUsed = true
            for _ in 0..<(previewScore ?? 4) { debugPlace(offset: 0) }
            debugPlace(offset: 400)
        }
        #endif
    }

    private func addBestMarker() {
        guard session.targetBest > 0 else { return }
        let y = baseY + CGFloat(session.targetBest) * (SkyStackConfig.blockHeight + SkyStackConfig.verticalSpacing)
        let path = CGMutablePath()
        for x in stride(from: CGFloat(20), to: SkyStackConfig.worldWidth - 20, by: 10) {
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + 4, y: y))
        }
        let line = SKShapeNode(path: path)
        line.strokeColor = .white.withAlphaComponent(0.18)
        line.lineWidth = 1
        milestones.addChild(line)
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "BEST  \(session.targetBest)"
        label.fontSize = 10
        label.fontColor = .white.withAlphaComponent(0.5)
        label.horizontalAlignmentMode = .right
        label.position = CGPoint(x: SkyStackConfig.worldWidth - 20, y: y + 9)
        milestones.addChild(label)
    }

    private func spawnBlock() {
        guard let topBlock else { return }
        let block = StackBlock(width: topBlock.width, color: StackBlock.color(level: session.score))
        alignmentRemaining = 0
        alignmentArmed = true
        direction = session.score.isMultiple(of: 2) ? 1 : -1
        let margin = SkyStackConfig.horizontalMargin + block.width / 2
        block.position = CGPoint(x: direction > 0 ? margin : SkyStackConfig.worldWidth - margin,
                                 y: topBlock.position.y + SkyStackConfig.blockHeight + SkyStackConfig.verticalSpacing)
        tower.addChild(block)
        movingBlock = block
        updateFraming(immediately: false)
    }

    private func updateFraming(immediately: Bool) {
        let height = worldHeight
        let nextY = movingBlock?.position.y ?? topBlock?.position.y ?? 110
        cameraTarget = max(height / 2, nextY + height * (0.5 - SkyStackConfig.cameraThreshold))
        gameCamera.setScale(SkyStackConfig.worldWidth / max(1, size.width))
        gameCamera.position.x = SkyStackConfig.worldWidth / 2
        if immediately { gameCamera.position.y = cameraTarget }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isPaused else { lastUpdate = nil; return }
        guard let previous = lastUpdate else { lastUpdate = currentTime; return }
        let dt = CGFloat(min(max(currentTime - previous, 0), 1.0 / 30.0))
        lastUpdate = currentTime
        gameCamera.position.y += (cameraTarget - gameCamera.position.y) * (1 - exp(-SkyStackConfig.cameraResponse * dt))
        if session.state == .falling {
            failureRemaining -= dt
            if failureRemaining <= 0 {
                session.end()
                if voiceOverEnabled {
                    UIAccessibility.post(notification: .announcement, argument: "Game over. Score \(session.score). Best \(session.bestScore).")
                }
            }
            return
        }
        guard session.state != .gameOver, let block = movingBlock else { return }
        if voiceOverEnabled, alignmentRemaining > 0 {
            alignmentRemaining -= dt
            return
        }
        let previousX = block.position.x
        let left = SkyStackConfig.horizontalMargin + block.width / 2
        let right = SkyStackConfig.worldWidth - left
        block.position.x += direction * SkyStackConfig.speed(score: session.score) * dt * (voiceOverEnabled ? SkyStackConfig.voiceOverSpeedScale : 1)
        if block.position.x > right {
            block.position.x = right - (block.position.x - right)
            direction = -1
        } else if block.position.x < left {
            block.position.x = left + (left - block.position.x)
            direction = 1
        }
        if voiceOverEnabled, let topBlock {
            let target = topBlock.position.x
            if alignmentArmed && (previousX - target) * (block.position.x - target) <= 0 {
                block.position.x = target
                alignmentRemaining = SkyStackConfig.alignmentHold
                alignmentArmed = false
                audio.play(.alignment)
                haptics.placement()
                UIAccessibility.post(notification: .announcement, argument: "Aligned. Stack now.")
            } else if abs(block.position.x - target) > 18 {
                alignmentArmed = true
            }
        }
        // Cull invisible history to keep long runs inexpensive.
        let cutoff = gameCamera.position.y - worldHeight / 2 - 80
        for node in tower.children where node !== topBlock && node !== movingBlock && node.position.y < cutoff {
            node.removeFromParent()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else { return }
        placeMovingBlock()
    }

    func placeMovingBlock() {
        guard session.state == .ready || session.state == .playing, let moving = movingBlock, let supporting = topBlock else { return }
        LaunchMeasurement.placedFirstBlock()
        session.begin()
        let placement = StackPlacement.resolve(moving: moving.span, supporting: supporting.span,
                                               tolerance: SkyStackConfig.tolerance(score: session.score, width: moving.width))
        let y = moving.position.y
        moving.removeFromParent()
        movingBlock = nil
        for offcut in placement.offcuts {
            drop(offcut, at: y, color: moving.color, toward: offcut.center < supporting.position.x ? -1 : 1)
        }
        guard let overlap = placement.overlap else {
            session.miss()
            failureRemaining = CGFloat(SkyStackConfig.failureDelay)
            haptics.gameOver()
            return
        }
        let landed = StackBlock(width: overlap.width, color: moving.color)
        landed.position = CGPoint(x: overlap.center, y: y)
        tower.addChild(landed)
        topBlock = landed
        session.recordPlacement(perfect: placement.isPerfect)
        if placement.isPerfect {
            haptics.perfectPlacement()
            audio.play(.perfect(min(5, session.consecutivePerfects)))
            showPerfect(at: landed.position)
            if !reduceMotion { landed.run(.sequence([.scaleY(to: 1.12, duration: 0.07), .scaleY(to: 1, duration: 0.12)])) }
        } else {
            haptics.placement()
            audio.play(.placement)
        }
        if session.isNewBest && session.score == session.targetBest + 1 {
            milestones.run(.fadeOut(withDuration: 0.25))
            showNewBest(at: landed.position)
        }
        spawnBlock()
    }

    private func drop(_ span: StackSpan, at y: CGFloat, color: SKColor, toward sign: CGFloat) {
        let piece = StackBlock(width: span.width, color: color)
        piece.position = CGPoint(x: span.center, y: y)
        debris.addChild(piece)
        if reduceMotion {
            piece.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
            return
        }
        // Analytic fall avoids physics bodies, contact listeners, and extra timers.
        let fall = SKAction.customAction(withDuration: 1.1) { node, elapsed in
            let t = elapsed
            node.position = CGPoint(x: span.center + sign * 55 * t, y: y - 520 * t * t)
            node.zRotation = -sign * t * 1.8
            node.alpha = max(0, 1 - t / 1.1)
        }
        piece.run(.sequence([fall, .removeFromParent()]))
    }

    private func showPerfect(at point: CGPoint) {
        debris.childNode(withName: "perfect")?.removeFromParent()
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.name = "perfect"
        label.text = session.consecutivePerfects > 1 ? "PERFECT ×\(session.consecutivePerfects)" : "PERFECT"
        label.fontSize = 12
        label.fontColor = .white.withAlphaComponent(0.9)
        label.position = CGPoint(x: SkyStackConfig.worldWidth / 2, y: point.y + 42)
        label.zPosition = 10
        debris.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: reduceMotion ? 0 : 16, duration: 0.55),
                                    .sequence([.wait(forDuration: 0.2), .fadeOut(withDuration: 0.35)])]),
                             .removeFromParent()]))
    }

    private func showNewBest(at point: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "NEW BEST"
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.98, green: 0.84, blue: 0.55, alpha: 1)
        label.position = CGPoint(x: SkyStackConfig.worldWidth / 2, y: point.y + 70)
        debris.addChild(label)
        label.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    #if DEBUG
    // Used by lifecycle tests to exercise the real placement/reset pipeline.
    func debugPlace(offset: CGFloat) {
        guard let topBlock else { return }
        movingBlock?.position.x = topBlock.position.x + offset
        placeMovingBlock()
    }
    var debugVoiceOverOverride: Bool?
    var debugPerfectText: String? { (debris.childNode(withName: "perfect") as? SKLabelNode)?.text }
    var debugFailureRemaining: CGFloat { failureRemaining }
    var debugMovingX: CGFloat? { movingBlock?.position.x }
    var debugTopWidth: CGFloat? { topBlock?.width }
    var debugCameraY: CGFloat { gameCamera.position.y }
    var debugDebrisCount: Int { debris.children.count }
    #endif
}
