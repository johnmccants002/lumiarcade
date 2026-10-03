import Foundation

enum SkyStackGameState { case ready, playing, falling, gameOver }

final class SkyStackSession: ArcadeGameSession {
    @Published private(set) var state: SkyStackGameState = .ready
    @Published private(set) var consecutivePerfects = 0

    init(defaults: UserDefaults = .standard, arcadot: Arcadot? = nil) {
        super.init(game: .skyStack, arcadot: arcadot, defaults: defaults)
    }

    init(arcadot: Arcadot? = nil, service: any LeaderboardService,
         initialScores: [ArcadeScore] = [], initials: String = "AAA") {
        super.init(game: .skyStack, arcadot: arcadot, service: service,
                   initialScores: initialScores, initials: initials)
    }

    func begin() { state = .playing }

    func recordPlacement(perfect: Bool) {
        recordPoint()
        consecutivePerfects = perfect ? consecutivePerfects + 1 : 0
    }

    func miss() { state = .falling }

    func end() {
        consecutivePerfects = 0
        prepareGameOver()
        state = .gameOver
    }

    func reset() {
        resetArcadeRun()
        consecutivePerfects = 0
        state = .ready
    }
}
