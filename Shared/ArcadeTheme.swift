import SwiftUI

enum ArcadeTheme {
    static let background = Color(red: 0.025, green: 0.04, blue: 0.075)
    static let card = Color.white.opacity(0.065)

    static func accent(for game: GameType) -> Color {
        switch game {
        case .skyStack: return Color(red: 0.98, green: 0.78, blue: 0.42)
        case .pulse: return Color(red: 0.38, green: 0.9, blue: 1)
        }
    }
}
