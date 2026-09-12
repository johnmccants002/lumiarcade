import Foundation
import CoreGraphics

struct SkyStackConfig {
    // A fixed logical width keeps timing/tolerance consistent across iPhones.
    static let worldWidth: CGFloat = 390
    static let initialBlockWidth: CGFloat = 228
    static let blockHeight: CGFloat = 25
    static let verticalSpacing: CGFloat = 2
    static let horizontalMargin: CGFloat = 14
    static let initialSpeed: CGFloat = 145
    static let speedIncrement: CGFloat = 4.5
    static let earlySpeedIncrement: CGFloat = 2.5
    static let gentlePlacements = 8
    static let startingHeightFraction: CGFloat = 0.24
    static let failureDelay: TimeInterval = 0.25
    static let perfectWindow: CGFloat = 0.080
    static let maxPerfectTolerance: CGFloat = 10
    static let voiceOverSpeedScale: CGFloat = 0.65
    static let alignmentHold: CGFloat = 1.3
    static let maxSpeed: CGFloat = 315
    static let perfectTolerance: CGFloat = 6
    static let cameraThreshold: CGFloat = 0.53
    static let cameraResponse: CGFloat = 8

    static func speed(score: Int) -> CGFloat {
        let score = max(0, score)
        return min(maxSpeed, initialSpeed
                   + CGFloat(min(score, gentlePlacements)) * earlySpeedIncrement
                   + CGFloat(max(0, score - gentlePlacements)) * speedIncrement)
    }

    static func tolerance(score: Int, width: CGFloat) -> CGFloat {
        // Keep the timing window fair, but never snap a completely missed sliver.
        min(width * 0.45, min(maxPerfectTolerance, max(perfectTolerance, speed(score: score) * perfectWindow / 2)))
    }

    #if DEBUG
    // Enable in the scheme's launch arguments. Never included in release builds.
    static var showsDiagnostics: Bool {
        ProcessInfo.processInfo.arguments.contains("-SkyStackDiagnostics")
    }
    #endif
}
