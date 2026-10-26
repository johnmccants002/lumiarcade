import CoreGraphics
import Foundation

enum OrbitConfig {
    static let playerRadius: CGFloat = 10
    static let blockerHalfSpan: CGFloat = 0.18
    static let movingBlockerHalfSpan: CGFloat = 0.16
    static let sweeperHalfSpan: CGFloat = 0.075

    static let baseAngularSpeed: CGFloat = 1.04
    static let maximumAngularSpeed: CGFloat = 2.05
    static let angularSpeedIncreasePerSecond: CGFloat = 0.015

    static let initialGracePeriod: TimeInterval = 2.4
    static let warningDuration: TimeInterval = 0.9
    static let initialSpawnInterval: TimeInterval = 5.0
    static let minimumSpawnInterval: TimeInterval = 2.65
    static let spawnIntervalReductionPerSecond: TimeInterval = 0.045
    static let stationaryLifetime: TimeInterval = 4.3
    static let movingLifetime: TimeInterval = 5.2
    static let sweeperLifetime: TimeInterval = 4.7

    static let movingBlockerSpeed: CGFloat = 0.18
    static let sweeperSpeed: CGFloat = 0.48
    static let minimumPlayerSpawnSeparation: CGFloat = 1.35
    static let minimumHazardSeparation: CGFloat = 0.82
    static let milestones: Set<Int> = [10, 20, 30, 45, 60, 90]

    static func orbitRadius(sceneSize: CGSize) -> CGFloat {
        min(142, sceneSize.width * 0.32, sceneSize.height * 0.205)
    }

    static func orbitCenter(sceneSize: CGSize) -> CGPoint {
        CGPoint(x: sceneSize.width / 2, y: sceneSize.height * 0.49)
    }

    static func angularSpeed(survivalTime: TimeInterval) -> CGFloat {
        min(maximumAngularSpeed,
            baseAngularSpeed + CGFloat(max(0, survivalTime)) * angularSpeedIncreasePerSecond)
    }

    static func spawnInterval(survivalTime: TimeInterval) -> TimeInterval {
        max(minimumSpawnInterval,
            initialSpawnInterval - max(0, survivalTime) * spawnIntervalReductionPerSecond)
    }

    static func maximumConcurrentHazards(survivalTime: TimeInterval) -> Int {
        if survivalTime < 25 { return 1 }
        if survivalTime < 40 { return 2 }
        return 3
    }

    static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if result < 0 { result += 2 * .pi }
        return result
    }

    static func angularDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let difference = abs(normalizedAngle(lhs) - normalizedAngle(rhs))
        return min(difference, 2 * .pi - difference)
    }
}
