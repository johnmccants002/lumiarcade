import SwiftUI

struct ExperienceRootView: View {
    @State private var invocation = AppInvocation()
    @State private var fallbackSelection: GameInvocation?
    private let router = ExperienceRouter()

    var body: some View {
        Group {
            switch fallbackSelection.map(ExperienceRouter.Experience.game) ?? router.resolve(invocation) {
            case .game(let game):
                ArcadeGameView(invocation: game)
                    // Reinvoking the same object preserves a run. Switching to a
                    // different Arcadot creates a fresh scene and score context.
                    .id(game)
            case .fallback:
                fallbackView(message: "Choose an available Lumi Arcade game.")
            case .unsupported:
                fallbackView(message: "This game isn’t supported by this version of Lumi Arcade.")
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            LaunchMeasurement.invoked()
            fallbackSelection = nil
            invocation = AppInvocation(url: activity.webpageURL)
        }
        .onOpenURL { url in
            LaunchMeasurement.invoked()
            fallbackSelection = nil
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
    private func fallbackView(message: String) -> some View {
        VStack(spacing: 20) {
            Text(Product.displayName).font(.title2)
            Text(message).multilineTextAlignment(.center)
            ForEach(GameType.allCases, id: \.self) { game in
                Button("PLAY \(game.displayName.uppercased())") {
                    fallbackSelection = GameInvocation(game: game, arcadotID: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .preferredColorScheme(.dark)
    }
}
