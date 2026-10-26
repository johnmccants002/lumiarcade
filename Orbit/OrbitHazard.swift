import SpriteKit

final class OrbitHazard {
    enum Kind: Equatable {
        case stationaryBlocker
        case movingBlocker
        case sweeper
    }

    let kind: Kind
    let node = SKNode()
    private(set) var angle: CGFloat
    let halfSpan: CGFloat
    private let angularVelocity: CGFloat
    private var warningRemaining: TimeInterval
    private var activeRemaining: TimeInterval
    private var radius: CGFloat
    private var shape = SKShapeNode()
    private var endpoint = SKShapeNode()

    var isActive: Bool { warningRemaining <= 0 && activeRemaining > 0 }
    var isExpired: Bool { warningRemaining <= 0 && activeRemaining <= 0 }

    init(kind: Kind, angle: CGFloat, angularVelocity: CGFloat, orbitRadius: CGFloat,
         warningDuration: TimeInterval, activeDuration: TimeInterval) {
        self.kind = kind
        self.angle = OrbitConfig.normalizedAngle(angle)
        self.angularVelocity = angularVelocity
        radius = orbitRadius
        warningRemaining = warningDuration
        activeRemaining = activeDuration
        switch kind {
        case .stationaryBlocker: halfSpan = OrbitConfig.blockerHalfSpan
        case .movingBlocker: halfSpan = OrbitConfig.movingBlockerHalfSpan
        case .sweeper: halfSpan = OrbitConfig.sweeperHalfSpan
        }
        node.name = "orbitHazard"
        node.zPosition = 10
        rebuild(orbitRadius: orbitRadius)
        updateAppearance()
    }

    func rebuild(orbitRadius: CGFloat) {
        radius = orbitRadius
        node.removeAllChildren()

        let path = CGMutablePath()
        switch kind {
        case .stationaryBlocker, .movingBlocker:
            path.addArc(center: .zero, radius: radius,
                        startAngle: -halfSpan, endAngle: halfSpan, clockwise: false)
        case .sweeper:
            path.move(to: CGPoint(x: 20, y: 0))
            path.addLine(to: CGPoint(x: radius + 28, y: 0))
        }

        shape = SKShapeNode(path: path)
        shape.lineWidth = kind == .sweeper ? 8 : 14
        shape.lineCap = .round
        shape.glowWidth = 7
        node.addChild(shape)

        if kind == .sweeper {
            endpoint = SKShapeNode(circleOfRadius: 6)
            endpoint.position = CGPoint(x: radius, y: 0)
            endpoint.lineWidth = 1.5
            endpoint.glowWidth = 5
            node.addChild(endpoint)
        }
        node.zRotation = angle
        updateAppearance()
    }

    func update(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        if warningRemaining > 0 {
            warningRemaining -= deltaTime
        } else {
            activeRemaining -= deltaTime
            angle = OrbitConfig.normalizedAngle(angle + angularVelocity * CGFloat(deltaTime))
        }
        node.zRotation = angle
        updateAppearance()
    }

    private func updateAppearance() {
        let activeColor = kind == .sweeper
            ? SKColor(red: 1, green: 0.35, blue: 0.58, alpha: 1)
            : SKColor(red: 1, green: 0.28, blue: 0.38, alpha: 1)
        if isActive {
            shape.strokeColor = activeColor
            endpoint.strokeColor = .white
            endpoint.fillColor = activeColor
            node.alpha = CGFloat(min(1, max(0, activeRemaining / 0.22)))
        } else {
            shape.strokeColor = activeColor.withAlphaComponent(0.48)
            endpoint.strokeColor = activeColor.withAlphaComponent(0.65)
            endpoint.fillColor = activeColor.withAlphaComponent(0.35)
            let pulse = 0.42 + 0.2 * sin(CGFloat(max(0, warningRemaining)) * 16)
            node.alpha = pulse
        }
    }
}
