import SpriteKit

final class PulseObstaclePair: SKNode {
    private(set) var hasScored = false
    let gapCenterY: CGFloat
    let gapHeight: CGFloat

    init(sceneHeight: CGFloat, gapCenterY: CGFloat, gapHeight: CGFloat) {
        self.gapCenterY = gapCenterY
        self.gapHeight = gapHeight
        super.init()
        name = "pulseGate"
        zPosition = 8

        let topY = PulseConfig.playableTop(sceneHeight: sceneHeight)
        let bottomY = PulseConfig.floorY
        let gapBottom = gapCenterY - gapHeight / 2
        let gapTop = gapCenterY + gapHeight / 2
        let bottomHeight = max(1, gapBottom - bottomY)
        let topHeight = max(1, topY - gapTop)

        addWall(size: CGSize(width: PulseConfig.obstacleWidth, height: bottomHeight),
                centerY: bottomY + bottomHeight / 2, capY: gapBottom)
        addWall(size: CGSize(width: PulseConfig.obstacleWidth, height: topHeight),
                centerY: gapTop + topHeight / 2, capY: gapTop)

        let scoreNode = SKNode()
        scoreNode.name = "scoreZone"
        scoreNode.position = CGPoint(x: PulseConfig.obstacleWidth / 2 + PulseConfig.orbRadius + 4,
                                     y: (bottomY + topY) / 2)
        let scoreBody = SKPhysicsBody(rectangleOf: CGSize(width: 4, height: topY - bottomY))
        scoreBody.isDynamic = false
        scoreBody.categoryBitMask = PulsePhysicsCategory.scoreZone
        scoreBody.collisionBitMask = 0
        scoreBody.contactTestBitMask = PulsePhysicsCategory.player
        scoreNode.physicsBody = scoreBody
        addChild(scoreNode)
    }

    required init?(coder: NSCoder) { nil }

    func claimScore() -> Bool {
        guard !hasScored else { return false }
        hasScored = true
        return true
    }

    private func addWall(size: CGSize, centerY: CGFloat, capY: CGFloat) {
        let wall = SKShapeNode(rectOf: size, cornerRadius: 7)
        wall.position.y = centerY
        wall.fillColor = SKColor(red: 0.035, green: 0.07, blue: 0.12, alpha: 0.96)
        wall.strokeColor = SKColor(red: 0.25, green: 0.77, blue: 0.92, alpha: 0.75)
        wall.lineWidth = 2
        wall.glowWidth = 4
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.categoryBitMask = PulsePhysicsCategory.obstacle
        body.collisionBitMask = PulsePhysicsCategory.player
        body.contactTestBitMask = PulsePhysicsCategory.player
        wall.physicsBody = body
        addChild(wall)

        let cap = SKShapeNode(rectOf: CGSize(width: size.width + 8, height: 7), cornerRadius: 3.5)
        cap.position.y = capY
        cap.fillColor = SKColor(red: 0.2, green: 0.88, blue: 1, alpha: 0.82)
        cap.strokeColor = SKColor(red: 0.72, green: 0.97, blue: 1, alpha: 0.9)
        cap.lineWidth = 1
        cap.glowWidth = 7
        addChild(cap)
    }
}
