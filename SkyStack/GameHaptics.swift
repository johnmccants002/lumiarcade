import UIKit

final class GameHaptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let perfect = UIImpactFeedbackGenerator(style: .medium)
    private let failure = UINotificationFeedbackGenerator()

    func prepare() { light.prepare(); perfect.prepare(); failure.prepare() }
    func placement() { light.impactOccurred(intensity: 0.6); light.prepare() }
    func perfectPlacement() { perfect.impactOccurred(intensity: 0.9); perfect.prepare() }
    func gameOver() { failure.notificationOccurred(.error) }
}
