import CoreGraphics
import Foundation

enum PulseConfig {
    static let orbRadius: CGFloat = 14
    // Use a deterministic velocity instead of a mass-dependent physics impulse.
    // These values leave enough reaction time for a one-touch arcade rhythm.
    static let gravity: CGFloat = -8
    static let tapVelocity: CGFloat = 205
    static let maxDownwardVelocity: CGFloat = 220
    static let maxUpwardVelocity: CGFloat = 225

    static let initialObstacleSpeed: CGFloat = 142
    static let maximumObstacleSpeed: CGFloat = 238
    static let speedIncrease: CGFloat = 10
    static let speedIncreaseInterval = 5

    static let obstacleWidth: CGFloat = 68
    static let initialGapHeight: CGFloat = 194
    static let minimumGapHeight: CGFloat = 154
    static let gapReduction: CGFloat = 4
    static let gapReductionInterval = 8

    static let initialSpawnInterval: TimeInterval = 1.92
    static let minimumSpawnInterval: TimeInterval = 1.58
    static let spawnIntervalReduction: TimeInterval = 0.035
    static let spawnIntervalReductionStep = 9

    static let floorY: CGFloat = 42
    static let ceilingInset: CGFloat = 18
    static let topGapClearance: CGFloat = 94
    static let gapEdgeClearance: CGFloat = 18
    static let playerXFraction: CGFloat = 0.31
    static let readyYFraction: CGFloat = 0.54
    static let firstGateInset: CGFloat = 16
    static let particleIntensity: CGFloat = 20
    static let milestones: Set<Int> = [10, 25, 50, 100]

    static func obstacleSpeed(score: Int) -> CGFloat {
        let steps = max(0, score) / speedIncreaseInterval
        return min(maximumObstacleSpeed, initialObstacleSpeed + CGFloat(steps) * speedIncrease)
    }

    static func gapHeight(score: Int) -> CGFloat {
        let steps = max(0, score) / gapReductionInterval
        return max(minimumGapHeight, initialGapHeight - CGFloat(steps) * gapReduction)
    }

    static func spawnInterval(score: Int) -> TimeInterval {
        let steps = max(0, score) / spawnIntervalReductionStep
        return max(minimumSpawnInterval, initialSpawnInterval - Double(steps) * spawnIntervalReduction)
    }

    static func playableTop(sceneHeight: CGFloat) -> CGFloat {
        max(floorY + initialGapHeight + 40, sceneHeight - ceilingInset)
    }

    static func gapCenterRange(sceneHeight: CGFloat, gapHeight: CGFloat) -> ClosedRange<CGFloat> {
        let halfGap = gapHeight / 2
        let minimum = floorY + halfGap + gapEdgeClearance
        let requestedMaximum = playableTop(sceneHeight: sceneHeight) - topGapClearance - halfGap
        return minimum...max(minimum, requestedMaximum)
    }

    static func readyPosition(sceneSize: CGSize) -> CGPoint {
        let range = gapCenterRange(sceneHeight: sceneSize.height, gapHeight: initialGapHeight)
        return CGPoint(x: sceneSize.width * playerXFraction,
                       y: min(range.upperBound, max(range.lowerBound, sceneSize.height * readyYFraction)))
    }
}

enum PulsePhysicsCategory {
    static let player: UInt32 = 1 << 0
    static let obstacle: UInt32 = 1 << 1
    static let scoreZone: UInt32 = 1 << 2
    static let boundary: UInt32 = 1 << 3
}
