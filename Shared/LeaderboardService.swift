import Foundation

protocol LeaderboardService {
    func scores(game: GameType, arcadotID: String) async throws -> [ArcadeScore]
    func submit(_ score: ArcadeScore) async throws
}

/// Full-app browsing over all locally stored Arcadot boards for a game.
/// The per-Arcadot service API remains unchanged for gameplay.
protocol GameLeaderboardBrowsing {
    func scores(game: GameType) async throws -> [ArcadeScore]
}

enum LeaderboardRules {
    static let limit = 5
    static func ranked(_ scores: [ArcadeScore]) -> [ArcadeScore] {
        scores.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    static func qualifies(_ score: Int, among scores: [ArcadeScore]) -> Bool {
        score > 0 && (scores.count < limit || score > (ranked(scores).prefix(limit).last?.score ?? 0))
    }
}

/// The async interface can be implemented by a future API; the game scene has
/// no knowledge of persistence. The local snapshot keeps initial rendering immediate.
final class LocalLeaderboardService: LeaderboardService, GameLeaderboardBrowsing {
    enum StorageError: LocalizedError {
        case invalidScore, unreadableScores
        var errorDescription: String? {
            switch self {
            case .invalidScore: return "Enter three letters or numbers to save this score."
            case .unreadableScores: return "Saved scores couldn’t be read. Your existing data has been kept."
            }
        }
    }
    private let defaults: UserDefaults
    private let prefix = "lumiarcade.leaderboard.v1."
    var lastInitials: String {
        PlayerProfileStore(defaults: defaults).initials
    }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(game: GameType, arcadotID: String) -> String {
        // Encoding the ID keeps the storage boundary unambiguous even for callers
        // other than the URL router.
        prefix + game.rawValue + "." + Data(arcadotID.utf8).base64EncodedString()
    }

    func snapshot(game: GameType, arcadotID: String) throws -> [ArcadeScore] {
        let key = key(game: game, arcadotID: arcadotID)
        if defaults.data(forKey: key) == nil, game == .skyStack, arcadotID == Product.localScoreID {
            let legacy = defaults.integer(forKey: Product.legacyBestScoreKey)
            if legacy > 0 {
                // The old score has no initials/date/object. Migrate to Local Play
                // only, with AAA and the migration timestamp; retain the old key.
                let score = ArcadeScore(arcadotID: arcadotID, game: game, initials: "AAA", score: legacy)
                defaults.set(try JSONEncoder().encode([score]), forKey: key)
            }
        }
        guard let data = defaults.data(forKey: key) else { return [] }
        guard let scores = try? JSONDecoder().decode([ArcadeScore].self, from: data),
              scores.allSatisfy({ $0.game == game && $0.arcadotID == arcadotID && $0.score > 0 && ArcadeInitials.isValid($0.initials) }) else {
            throw StorageError.unreadableScores
        }
        return Array(LeaderboardRules.ranked(scores).prefix(LeaderboardRules.limit))
    }

    func scores(game: GameType, arcadotID: String) async throws -> [ArcadeScore] {
        try await MainActor.run { try snapshot(game: game, arcadotID: arcadotID) }
    }

    func scores(game: GameType) async throws -> [ArcadeScore] {
        try await MainActor.run { try gameSnapshot(game: game) }
    }

    func gameSnapshot(game: GameType) throws -> [ArcadeScore] {
        // Trigger the existing one-time legacy migration before enumerating boards.
        _ = try snapshot(game: game, arcadotID: Product.localScoreID)
        let gamePrefix = prefix + game.rawValue + "."
        var scores: [ArcadeScore] = []
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(gamePrefix) {
            guard let data = defaults.data(forKey: key),
                  let board = try? JSONDecoder().decode([ArcadeScore].self, from: data),
                  board.allSatisfy({
                      $0.game == game && $0.score > 0 && ArcadeInitials.isValid($0.initials)
                  }) else {
                throw StorageError.unreadableScores
            }
            scores.append(contentsOf: board)
        }
        let unique = Dictionary(scores.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return Array(LeaderboardRules.ranked(Array(unique.values)).prefix(LeaderboardRules.limit))
    }

    func submit(_ score: ArcadeScore) async throws {
        try await MainActor.run { try store(score) }
    }

    private func store(_ score: ArcadeScore) throws {
        guard score.score > 0, ArcadeInitials.isValid(score.initials) else { throw StorageError.invalidScore }
        var scores = try snapshot(game: score.game, arcadotID: score.arcadotID)
        guard !scores.contains(where: { $0.id == score.id }) else { return }
        scores.append(score)
        let data = try JSONEncoder().encode(Array(LeaderboardRules.ranked(scores).prefix(LeaderboardRules.limit)))
        defaults.set(data, forKey: key(game: score.game, arcadotID: score.arcadotID))
        _ = PlayerProfileStore(defaults: defaults).saveInitials(score.initials)
    }
}
