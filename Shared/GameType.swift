import Foundation

enum GameType: String, Codable, CaseIterable {
    case skyStack = "sky-stack"

    var displayName: String {
        switch self {
        case .skyStack: return "Sky Stack"
        }
    }
}
