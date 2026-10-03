import SwiftUI

@main
struct LumiArcadeApp: App {
    init() { LaunchMeasurement.begin() }

    var body: some Scene {
        WindowGroup { FullAppRootView() }
    }
}
