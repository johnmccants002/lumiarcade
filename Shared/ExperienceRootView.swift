import SwiftUI

struct ExperienceRootView: View {
    @State private var invocation = AppInvocation()
    private let router = ExperienceRouter()

    var body: some View {
        Group {
            switch router.resolve(invocation) {
            case .game(let game):
                gameView(game)
                    // Reinvoking the same object preserves a run. Switching to a
                    // different Arcadot creates a fresh scene and score context.
                    .id(game)
            case .unsupported:
                VStack(spacing: 20) {
                    Text(Product.displayName).font(.title2)
                    Text("This game isn’t supported by this version of Lumi Arcade.")
                        .multilineTextAlignment(.center)
                    Button("PLAY SKY STACK") { invocation = AppInvocation() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(32)
                .preferredColorScheme(.dark)
            }
        }
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
    @ViewBuilder
    private func gameView(_ invocation: GameInvocation) -> some View {
        switch invocation.game {
        case .skyStack: SkyStackView(arcadot: invocation.arcadot)
        }
    }

}
