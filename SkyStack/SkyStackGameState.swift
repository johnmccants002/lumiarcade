import Combine
import Foundation

enum SkyStackGameState { case ready, playing, falling, gameOver }
enum ArcadeResultStage { case initials, leaderboard }

final class SkyStackSession: ObservableObject {
    let arcadot: Arcadot?
    let game: GameType = .skyStack
    var arcadotID: String { arcadot?.id ?? Product.localScoreID }
    var identityLabel: String { arcadot.map { "ARCADOT #\($0.id)" } ?? "LOCAL PLAY" }

    @Published private(set) var state: SkyStackGameState = .ready
    @Published private(set) var score = 0
    @Published private(set) var bestScore: Int
    @Published private(set) var consecutivePerfects = 0
    @Published private(set) var leaderboard: [ArcadeScore]
    @Published private(set) var resultStage: ArcadeResultStage = .leaderboard
    @Published private(set) var isSaving = false
    @Published private(set) var saveError: String?
    @Published var initials: String
    private(set) var targetBest: Int
    var isNewBest: Bool { score > targetBest }
    private let service: any LeaderboardService
    private var runID = UUID()
    private var finishedAt = Date()

    convenience init(defaults: UserDefaults = .standard, arcadot: Arcadot? = nil) {
        let local = LocalLeaderboardService(defaults: defaults)
        let snapshot = Result { try local.snapshot(game: .skyStack, arcadotID: arcadot?.id ?? Product.localScoreID) }
        self.init(arcadot: arcadot, service: local, initialScores: (try? snapshot.get()) ?? [], initials: local.lastInitials)
        if case .failure(let error) = snapshot { saveError = error.localizedDescription }
    }

    init(arcadot: Arcadot? = nil, service: any LeaderboardService,
         initialScores: [ArcadeScore] = [], initials: String = "AAA") {
        self.arcadot = arcadot
        self.service = service
        let scores = Array(LeaderboardRules.ranked(initialScores).prefix(LeaderboardRules.limit))
        self.leaderboard = scores
        self.bestScore = scores.first?.score ?? 0
        self.targetBest = scores.first?.score ?? 0
        self.initials = ArcadeInitials.isValid(initials) ? initials : "AAA"
    }

    func begin() { state = .playing }

    func recordPlacement(perfect: Bool) {
        score += 1
        consecutivePerfects = perfect ? consecutivePerfects + 1 : 0
        bestScore = max(bestScore, score)
    }

    func miss() { state = .falling }

    func end() {
        consecutivePerfects = 0
        finishedAt = Date()
        resultStage = LeaderboardRules.qualifies(score, among: leaderboard) ? .initials : .leaderboard
        state = .gameOver
    }

    @MainActor
    func saveScore() async {
        guard state == .gameOver, resultStage == .initials, !isSaving,
              ArcadeInitials.isValid(initials) else { return }
        isSaving = true
        saveError = nil
        let savingRun = runID
        let entry = ArcadeScore(id: savingRun, arcadotID: arcadotID, game: game,
                                initials: initials, score: score, createdAt: finishedAt)
        defer { if savingRun == runID { isSaving = false } }
        do {
            try await service.submit(entry)
            let scores = try await service.scores(game: game, arcadotID: arcadotID)
            guard savingRun == runID else { return }
            leaderboard = scores
            bestScore = scores.first?.score ?? 0
            resultStage = .leaderboard
        } catch {
            guard savingRun == runID else { return }
            saveError = error.localizedDescription
        }
    }

    func continueWithoutSaving() { resultStage = .leaderboard }

    func reset() {
        runID = UUID()
        bestScore = leaderboard.first?.score ?? 0
        targetBest = bestScore
        score = 0
        consecutivePerfects = 0
        isSaving = false
        resultStage = .leaderboard
        state = .ready
    }
}
