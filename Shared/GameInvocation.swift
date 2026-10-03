import Foundation

struct GameInvocation: Equatable, Hashable, Identifiable {
    let game: GameType
    let arcadotID: String?

    var id: String { "\(game.rawValue)/\(arcadotID ?? Product.localScoreID)" }
    var arcadot: Arcadot? { arcadotID.map { Arcadot(id: $0, game: game) } }
    static let localPlay = GameInvocation(game: .skyStack, arcadotID: nil)
}
