import Combine
import Foundation

enum PulseGameState { case ready, playing, gameOver }

final class PulseSession: ArcadeGameSession {
    @Published private(set) var state: PulseGameState = .ready

    init(defaults: UserDefaults = .standard, arcadot: Arcadot? = nil) {
        super.init(game: .pulse, arcadot: arcadot, defaults: defaults)
    }

    init(arcadot: Arcadot? = nil, service: any LeaderboardService,
         initialScores: [ArcadeScore] = [], initials: String = "AAA") {
        super.init(game: .pulse, arcadot: arcadot, service: service,
                   initialScores: initialScores, initials: initials)
    }

    func begin() {
        guard state == .ready else { return }
        state = .playing
    }

    @discardableResult
    func passGate() -> Int {
        guard state == .playing else { return score }
        return recordPoint()
    }

    func end() {
        guard state == .playing else { return }
        prepareGameOver()
        state = .gameOver
    }

    func reset() {
        resetArcadeRun()
        state = .ready
    }
}
