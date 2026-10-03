import UIKit

final class GameHaptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let perfect = UIImpactFeedbackGenerator(style: .medium)
    private let success = UINotificationFeedbackGenerator()
    private let failure = UINotificationFeedbackGenerator()

    func prepare() { light.prepare(); perfect.prepare(); success.prepare(); failure.prepare() }
    func placement() { light.impactOccurred(intensity: 0.6); light.prepare() }
    func perfectPlacement() { perfect.impactOccurred(intensity: 0.9); perfect.prepare() }
    func gatePassed() { light.impactOccurred(intensity: 0.32); light.prepare() }
    func milestone() { perfect.impactOccurred(intensity: 0.7); perfect.prepare() }
    func newHighScore() { success.notificationOccurred(.success); success.prepare() }
    func gameOver() { failure.notificationOccurred(.error) }
}
