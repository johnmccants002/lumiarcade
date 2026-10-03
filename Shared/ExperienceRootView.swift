import SwiftUI

struct ExperienceRootView: View {
    @State private var invocation = AppInvocation()
    private let router = ExperienceRouter()

    var body: some View {
        ArcadeExperienceView(experience: router.resolve(invocation))
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            LaunchMeasurement.invoked()
            invocation = AppInvocation(url: activity.webpageURL)
        }
        .onOpenURL { url in
            LaunchMeasurement.invoked()
            invocation = AppInvocation(url: url)
        }
        #if DEBUG
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-LumiArcadeInvocationURL"),
               arguments.indices.contains(index + 1) {
                invocation = AppInvocation(url: URL(string: arguments[index + 1]))
            }
        }
        #endif
    }
}
