import Combine
import Foundation

@MainActor
final class FullAppModel: ObservableObject {
    @Published private(set) var scoresByGame: [GameType: [ArcadeScore]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published var initials: String
    @Published private(set) var lastPlayedGame: GameType?
    @Published private(set) var gamesPlayed: Int
    @Published private(set) var profileMessage: String?

    private let leaderboardService: any GameLeaderboardBrowsing
    private let profileStore: PlayerProfileStore

    init(defaults: UserDefaults = .standard) {
        let profileStore = PlayerProfileStore(defaults: defaults)
        self.profileStore = profileStore
        leaderboardService = LocalLeaderboardService(defaults: defaults)
        initials = profileStore.initials
        lastPlayedGame = profileStore.lastPlayedGame
        gamesPlayed = profileStore.gamesPlayed
    }

    func refresh() {
        isLoading = true
        loadError = nil
        initials = profileStore.initials
        lastPlayedGame = profileStore.lastPlayedGame
        gamesPlayed = profileStore.gamesPlayed

        Task {
            do {
                var loaded: [GameType: [ArcadeScore]] = [:]
                for game in GameType.allCases {
                    loaded[game] = try await leaderboardService.scores(game: game)
                }
                scoresByGame = loaded
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }

    func highScore(for game: GameType) -> Int {
        scoresByGame[game]?.first?.score ?? 0
    }

    func leaderboard(for game: GameType) -> [ArcadeScore] {
        scoresByGame[game] ?? []
    }

    func recordGameLaunch(_ game: GameType) {
        profileStore.recordGameLaunch(game)
        lastPlayedGame = game
        profileMessage = nil
    }

    func saveInitials() {
        if profileStore.saveInitials(initials) {
            initials = profileStore.initials
            profileMessage = "Initials saved."
        } else {
            initials = profileStore.initials
            profileMessage = "Initials must contain three letters or numbers."
        }
    }
}
