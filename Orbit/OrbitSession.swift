import Combine
import CoreGraphics
import Foundation

enum OrbitGameState { case ready, playing, gameOver }

final class OrbitSession: ArcadeGameSession {
    @Published private(set) var state: OrbitGameState = .ready
    @Published private(set) var hasReversed = false
    private(set) var playerAngle: CGFloat = .pi / 2
    private(set) var direction: CGFloat = 1
    private(set) var survivalTime: TimeInterval = 0

    init(defaults: UserDefaults = .standard, arcadot: Arcadot? = nil) {
        super.init(game: .orbit, arcadot: arcadot, defaults: defaults)
    }

    init(arcadot: Arcadot? = nil, service: any LeaderboardService,
         initialScores: [ArcadeScore] = [], initials: String = "AAA") {
        super.init(game: .orbit, arcadot: arcadot, service: service,
                   initialScores: initialScores, initials: initials)
    }

    func begin() {
        guard state == .ready else { return }
        state = .playing
    }

    func reverseDirection() {
        guard state == .playing else { return }
        direction *= -1
        hasReversed = true
    }

    /// Advances movement and survival scoring from elapsed time, never frame count.
    /// Returns the new score only when at least one whole survival second was crossed.
    @discardableResult
    func advance(deltaTime: TimeInterval) -> Int? {
        guard state == .playing, deltaTime.isFinite, deltaTime > 0 else { return nil }
        survivalTime += deltaTime
        let speed = OrbitConfig.angularSpeed(survivalTime: survivalTime)
        playerAngle = OrbitConfig.normalizedAngle(
            playerAngle + speed * direction * CGFloat(deltaTime)
        )

        let targetScore = Int(survivalTime.rounded(.down))
        guard targetScore > score else { return nil }
        while score < targetScore { recordPoint() }
        return score
    }

    func end() {
        guard state == .playing else { return }
        prepareGameOver()
        state = .gameOver
    }

    func reset() {
        resetArcadeRun()
        state = .ready
        hasReversed = false
        playerAngle = .pi / 2
        direction = 1
        survivalTime = 0
    }

    #if DEBUG
    func preparePreview(score: Int) {
        begin()
        for _ in 0..<max(0, score) { recordPoint() }
        survivalTime = TimeInterval(max(0, score))
        end()
    }
    #endif
}
