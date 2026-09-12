import SwiftUI

@main
struct LumiArcadeClipApp: App {
    init() { LaunchMeasurement.begin() }

    var body: some Scene {
        WindowGroup { AppClipRootView() }
    }
}
