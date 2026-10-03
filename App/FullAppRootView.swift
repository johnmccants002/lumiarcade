import SwiftUI

enum FullAppTab: Hashable {
    case arcade, leaderboards, profile
}

struct FullAppRootView: View {
    @StateObject private var model = FullAppModel()
    @State private var selectedTab: FullAppTab = .arcade
    @State private var activeGame: GameInvocation?
    @State private var didHandleDebugInvocation = false
    private let router = ExperienceRouter()

    var body: some View {
        Group {
            if let invocation = activeGame {
                gamePresentation(invocation)
                    .id(invocation)
            } else {
                tabs
            }
        }
        .preferredColorScheme(.dark)
        .tint(.cyan)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            LaunchMeasurement.invoked()
            if let url = activity.webpageURL { open(url) }
        }
        .onOpenURL { url in
            LaunchMeasurement.invoked()
            open(url)
        }
        .onAppear {
            model.refresh()
            handleDebugInvocationOnce()
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            ArcadeHomeView(model: model, play: launch)
                .tabItem { Label("Arcade", systemImage: "arcade.stick.console") }
                .tag(FullAppTab.arcade)
            LeaderboardsView(model: model)
                .tabItem { Label("Leaderboards", systemImage: "trophy") }
                .tag(FullAppTab.leaderboards)
            PlayerProfileView(model: model)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(FullAppTab.profile)
        }
    }

    private func gamePresentation(_ invocation: GameInvocation) -> some View {
        ZStack(alignment: .topTrailing) {
            ArcadeGameView(invocation: invocation)
            Button {
                activeGame = nil
                selectedTab = .arcade
                model.refresh()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.white)
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityLabel("Return to Arcade")
            .accessibilityIdentifier("exitGame")
        }
    }

    private func launch(_ game: GameType) {
        model.recordGameLaunch(game)
        activeGame = GameInvocation(game: game, arcadotID: nil)
    }

    private func open(_ url: URL) {
        switch router.route(from: url) {
        case .game(let invocation):
            model.recordGameLaunch(invocation.game)
            activeGame = invocation
        case .fallback, .unsupported:
            activeGame = nil
            selectedTab = .arcade
            model.refresh()
        }
    }

    private func handleDebugInvocationOnce() {
        #if DEBUG
        guard !didHandleDebugInvocation else { return }
        didHandleDebugInvocation = true
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-LumiArcadeInvocationURL"),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]) {
            open(url)
        }
        #endif
    }
}
