import SwiftUI

enum FullAppTab: Hashable {
    case arcade, leaderboards, profile
}

struct FullAppRootView: View {
    @StateObject private var model = FullAppModel()
    @State private var selectedTab: FullAppTab = .arcade
    @State private var activeExperience: ExperienceRouter.Experience?
    @State private var didHandleDebugInvocation = false
    private let router = ExperienceRouter()

    var body: some View {
        Group {
            if let experience = activeExperience {
                gamePresentation(experience)
                    .id(experience)
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

    private func gamePresentation(_ experience: ExperienceRouter.Experience) -> some View {
        ArcadeExperienceView(experience: experience) {
                activeExperience = nil
                selectedTab = .arcade
                model.refresh()
            }
    }

    private func launch(_ game: GameType) {
        model.recordGameLaunch(game)
        activeExperience = .game(GameInvocation(game: game, arcadotID: nil))
    }

    private func open(_ url: URL) {
        let experience = router.route(from: url)
        switch experience {
        case .game(let invocation):
            model.recordGameLaunch(invocation.game)
            activeExperience = experience
        case .arcadot:
            activeExperience = experience
        case .fallback, .unsupported:
            activeExperience = nil
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
