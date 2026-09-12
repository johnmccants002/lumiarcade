import Foundation
import os

/// Local Instruments events only; no analytics, storage, identifiers, or networking.
enum LaunchMeasurement {
    private static let log = OSLog(subsystem: "game001.performance", category: .pointsOfInterest)
    private static var started = false
    private static var firstFrame = false
    private static var firstTap = false

    static func begin() {
        guard !started else { return }
        started = true
        os_signpost(.begin, log: log, name: "Game launch to frame")
    }

    static func frameSubmitted() {
        guard !firstFrame else { return }
        firstFrame = true
        os_signpost(.end, log: log, name: "Game launch to frame")
        os_signpost(.event, log: log, name: "First frame submitted")
    }

    static func placedFirstBlock() {
        guard !firstTap else { return }
        firstTap = true
        os_signpost(.event, log: log, name: "First placement")
    }

    static func invoked() { os_signpost(.event, log: log, name: "Invocation received") }
}
