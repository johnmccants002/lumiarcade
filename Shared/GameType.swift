import Foundation

enum GameType: String, Codable, CaseIterable, Identifiable {
    case skyStack = "sky-stack"
    case pulse = "pulse"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skyStack: return "Sky Stack"
        case .pulse: return "Pulse"
        }
    }

    var gameNumber: String {
        switch self {
        case .skyStack: return "GAME #001"
        case .pulse: return "GAME #002"
        }
    }

    var summary: String {
        switch self {
        case .skyStack: return "Build higher with precise one-touch timing."
        case .pulse: return "Guide a glowing orb through shifting energy gates."
        }
    }

    var systemImageName: String {
        switch self {
        case .skyStack: return "square.3.layers.3d"
        case .pulse: return "waveform.path.ecg"
        }
    }
}
