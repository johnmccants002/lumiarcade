import Foundation

struct GameInvocation: Equatable, Hashable {
    let game: GameType
    let arcadotID: String?

    var arcadot: Arcadot? { arcadotID.map { Arcadot(id: $0, game: game) } }
    static let localPlay = GameInvocation(game: .skyStack, arcadotID: nil)
}
