import Foundation

/// Small local identity/activity store shared by game sessions and the full app.
/// App and App Clip instances use their own standard container unless an App Group
/// is deliberately configured later.
final class PlayerProfileStore {
    private enum Key {
        static let initials = "lumiarcade.lastInitials"
        static let lastPlayedGame = "lumiarcade.lastPlayedGame"
        static let gamesPlayed = "lumiarcade.gamesPlayed"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var initials: String {
        let value = defaults.string(forKey: Key.initials) ?? "AAA"
        return ArcadeInitials.isValid(value) ? value : "AAA"
    }

    var lastPlayedGame: GameType? {
        defaults.string(forKey: Key.lastPlayedGame).flatMap(GameType.init(rawValue:))
    }

    var gamesPlayed: Int {
        max(0, defaults.integer(forKey: Key.gamesPlayed))
    }

    @discardableResult
    func saveInitials(_ value: String) -> Bool {
        guard ArcadeInitials.isValid(value) else { return false }
        defaults.set(value, forKey: Key.initials)
        return true
    }

    func recordGameLaunch(_ game: GameType) {
        defaults.set(game.rawValue, forKey: Key.lastPlayedGame)
    }

    func recordCompletedGame() {
        defaults.set(gamesPlayed + 1, forKey: Key.gamesPlayed)
    }
}
