import SpriteKit

final class StackBlock: SKNode {
    let width: CGFloat
    let color: SKColor
    var span: StackSpan { StackSpan(center: position.x, width: width) }

    init(width: CGFloat, color: SKColor) {
        self.width = width
        self.color = color
        super.init()
        let rect = CGRect(x: -width / 2, y: -SkyStackConfig.blockHeight / 2,
                          width: width, height: SkyStackConfig.blockHeight)
        let body = SKShapeNode(rect: rect, cornerRadius: min(3, width / 2))
        body.fillColor = color
        body.strokeColor = color.withAlphaComponent(0.65)
        body.lineWidth = 0.5
        addChild(body)
        let highlight = SKShapeNode(rect: CGRect(x: -width / 2 + min(2, width / 4),
                                               y: SkyStackConfig.blockHeight / 2 - 3,
                                               width: max(0.1, width - min(4, width / 2)), height: 1))
        highlight.fillColor = .white.withAlphaComponent(0.25)
        highlight.strokeColor = .clear
        addChild(highlight)
    }

    required init?(coder: NSCoder) { nil }

    static func color(level: Int) -> SKColor {
        SKColor(hue: (0.48 + CGFloat(level % 90) * 0.006).truncatingRemainder(dividingBy: 1),
                saturation: 0.48, brightness: 0.91, alpha: 1)
    }
}
