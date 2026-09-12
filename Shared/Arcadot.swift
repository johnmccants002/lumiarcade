import Foundation

/// A physical NFC arcade object. IDs preserve case and leading zeroes.
struct Arcadot: Identifiable, Equatable, Codable {
    let id: String
    let game: GameType

    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 64 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
    }
}
