import Foundation

struct ArcadeScore: Identifiable, Codable, Equatable {
    let id: UUID
    let arcadotID: String
    let game: GameType
    let initials: String
    let score: Int
    let createdAt: Date

    init(id: UUID = UUID(), arcadotID: String, game: GameType, initials: String,
         score: Int, createdAt: Date = Date()) {
        self.id = id
        self.arcadotID = arcadotID
        self.game = game
        self.initials = initials
        self.score = score
        self.createdAt = createdAt
    }
}

enum ArcadeInitials {
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    static func isValid(_ value: String) -> Bool {
        value.count == 3 && value.allSatisfy { alphabet.contains($0) }
    }

    static func cycling(_ value: String, column: Int, direction: Int) -> String {
        var letters = Array(isValid(value) ? value : "AAA")
        guard letters.indices.contains(column), let index = alphabet.firstIndex(of: letters[column]) else { return "AAA" }
        letters[column] = alphabet[(index + direction % alphabet.count + alphabet.count) % alphabet.count]
        return String(letters)
    }
}
