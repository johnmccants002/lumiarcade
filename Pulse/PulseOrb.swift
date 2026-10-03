import SpriteKit
import UIKit

final class PulseOrb: SKNode {
    private let glow: SKShapeNode
    private let core: SKShapeNode
    private let highlight: SKShapeNode
    private let trail = SKEmitterNode()

    override init() {
        glow = SKShapeNode(circleOfRadius: PulseConfig.orbRadius * 1.65)
        core = SKShapeNode(circleOfRadius: PulseConfig.orbRadius)
        highlight = SKShapeNode(circleOfRadius: PulseConfig.orbRadius * 0.32)
        super.init()

        name = "pulseOrb"
        zPosition = 20

        glow.fillColor = SKColor(red: 0.15, green: 0.85, blue: 1, alpha: 0.13)
        glow.strokeColor = SKColor(red: 0.18, green: 0.9, blue: 1, alpha: 0.34)
        glow.lineWidth = 1
        glow.glowWidth = 13
        addChild(glow)

        core.fillColor = SKColor(red: 0.12, green: 0.78, blue: 0.98, alpha: 1)
        core.strokeColor = SKColor(red: 0.72, green: 0.97, blue: 1, alpha: 1)
        core.lineWidth = 2
        core.glowWidth = 5
        addChild(core)

        highlight.fillColor = .white.withAlphaComponent(0.9)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -4, y: 5)
        addChild(highlight)

        trail.particleTexture = Self.particleTexture
        trail.particleBirthRate = PulseConfig.particleIntensity
        trail.particleLifetime = 0.42
        trail.particleLifetimeRange = 0.12
        trail.particlePositionRange = CGVector(dx: 2, dy: PulseConfig.orbRadius)
        trail.emissionAngle = .pi
        trail.emissionAngleRange = 0.28
        trail.particleSpeed = 48
        trail.particleSpeedRange = 16
        trail.particleAlpha = 0.5
        trail.particleAlphaRange = 0.18
        trail.particleAlphaSpeed = -1.15
        trail.particleScale = 0.7
        trail.particleScaleRange = 0.25
        trail.particleScaleSpeed = -1.2
        trail.particleColor = SKColor(red: 0.18, green: 0.88, blue: 1, alpha: 1)
        trail.particleColorBlendFactor = 1
        trail.position.x = -PulseConfig.orbRadius
        trail.zPosition = -1
        addChild(trail)

        let body = SKPhysicsBody(circleOfRadius: PulseConfig.orbRadius * 0.82)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0.08
        body.restitution = 0
        body.friction = 0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PulsePhysicsCategory.player
        body.collisionBitMask = PulsePhysicsCategory.obstacle | PulsePhysicsCategory.boundary
        body.contactTestBitMask = PulsePhysicsCategory.obstacle | PulsePhysicsCategory.boundary | PulsePhysicsCategory.scoreZone
        physicsBody = body
    }

    required init?(coder: NSCoder) { nil }

    func setTrailTarget(_ node: SKNode) { trail.targetNode = node }

    func setReduceMotion(_ reduceMotion: Bool) {
        trail.particleBirthRate = reduceMotion ? 0 : PulseConfig.particleIntensity
        glow.glowWidth = reduceMotion ? 5 : 13
    }

    func pulse(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        glow.removeAction(forKey: "pulse")
        glow.setScale(1)
        glow.run(.sequence([.scale(to: 1.24, duration: 0.07),
                            .scale(to: 1, duration: 0.16)]), withKey: "pulse")
    }

    func prepareForRestart() {
        removeAllActions()
        glow.removeAllActions()
        core.removeAllActions()
        setScale(1)
        zRotation = 0
        alpha = 1
        physicsBody?.velocity = .zero
        physicsBody?.affectedByGravity = false
        physicsBody?.isDynamic = true
    }

    private static let particleTexture: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: 6, height: 6))
        }
        return SKTexture(image: image)
    }()
}
