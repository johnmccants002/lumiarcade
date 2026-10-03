import Combine
import Foundation

enum ArcadeResultStage { case initials, leaderboard }

/// Shared score, initials, and leaderboard lifecycle for every Lumi Arcade game.
/// Individual games own only their gameplay state and call these hooks.
class ArcadeGameSession: ObservableObject {
    let arcadot: Arcadot?
    let game: GameType
    var arcadotID: String { arcadot?.id ?? Product.localScoreID }
    var identityLabel: String { arcadot.map { "ARCADOT #\($0.id)" } ?? "LOCAL PLAY" }

    @Published private(set) var score = 0
    @Published private(set) var bestScore: Int
    @Published private(set) var leaderboard: [ArcadeScore]
    @Published private(set) var resultStage: ArcadeResultStage = .leaderboard
    @Published private(set) var isSaving = false
    @Published var saveError: String?
    @Published var initials: String
    private(set) var targetBest: Int
    var isNewBest: Bool { score > targetBest }

    private let service: any LeaderboardService
    private let profileStore: PlayerProfileStore?
    private var runID = UUID()
    private var finishedAt = Date()
    private var didRecordFinishedRun = false

    init(game: GameType, arcadot: Arcadot? = nil, defaults: UserDefaults = .standard) {
        let local = LocalLeaderboardService(defaults: defaults)
        let snapshot = Result {
            try local.snapshot(game: game, arcadotID: arcadot?.id ?? Product.localScoreID)
        }
        self.game = game
        self.arcadot = arcadot
        self.service = local
        let profileStore = PlayerProfileStore(defaults: defaults)
        self.profileStore = profileStore
        profileStore.recordGameLaunch(game)
        let scores = Array(LeaderboardRules.ranked((try? snapshot.get()) ?? []).prefix(LeaderboardRules.limit))
        leaderboard = scores
        bestScore = scores.first?.score ?? 0
        targetBest = scores.first?.score ?? 0
        initials = local.lastInitials
        if case .failure(let error) = snapshot { saveError = error.localizedDescription }
    }

    init(game: GameType, arcadot: Arcadot? = nil, service: any LeaderboardService,
         initialScores: [ArcadeScore] = [], initials: String = "AAA") {
        self.game = game
        self.arcadot = arcadot
        self.service = service
        self.profileStore = nil
        let scores = Array(LeaderboardRules.ranked(initialScores).prefix(LeaderboardRules.limit))
        leaderboard = scores
        bestScore = scores.first?.score ?? 0
        targetBest = scores.first?.score ?? 0
        self.initials = ArcadeInitials.isValid(initials) ? initials : "AAA"
    }

    @discardableResult
    func recordPoint() -> Int {
        score += 1
        bestScore = max(bestScore, score)
        return score
    }

    func prepareGameOver() {
        if !didRecordFinishedRun {
            profileStore?.recordCompletedGame()
            didRecordFinishedRun = true
        }
        finishedAt = Date()
        resultStage = LeaderboardRules.qualifies(score, among: leaderboard) ? .initials : .leaderboard
    }

    @MainActor
    func saveScore() async {
        guard resultStage == .initials, !isSaving, ArcadeInitials.isValid(initials) else { return }
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

    func resetArcadeRun() {
        runID = UUID()
        didRecordFinishedRun = false
        bestScore = leaderboard.first?.score ?? 0
        targetBest = bestScore
        score = 0
        isSaving = false
        resultStage = .leaderboard
    }
}
