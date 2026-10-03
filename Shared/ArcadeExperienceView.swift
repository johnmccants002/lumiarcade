import SwiftUI

/// Shared launch and game chrome for both the full app and App Clip.
/// Individual games remain unaware of routing, assignment networking, and navigation.
struct ArcadeExperienceView: View {
    let experience: ExperienceRouter.Experience
    var onExit: (() -> Void)?

    private let assignmentService: any ArcadotAssignmentService
    private let assignmentCache: any ArcadotAssignmentCaching

    @State private var activeGame: GameInvocation?
    @State private var assignmentArcadotID: String?
    @State private var selectionArcadotID: String?
    @State private var selectorCurrentGame: GameType?
    @State private var isResolving = false
    @State private var isSelecting = false
    @State private var isSaving = false
    @State private var selectorMessage: String?
    @State private var saveError: String?
    @State private var pendingGame: GameType?
    @State private var showSwitchConfirmation = false
    @State private var isSessionOnlySelection = false

    init(experience: ExperienceRouter.Experience,
         onExit: (() -> Void)? = nil,
         assignmentService: any ArcadotAssignmentService = ArcadotAssignmentServiceFactory.live(),
         assignmentCache: any ArcadotAssignmentCaching = UserDefaultsArcadotAssignmentCache()) {
        self.experience = experience
        self.onExit = onExit
        self.assignmentService = assignmentService
        self.assignmentCache = assignmentCache
    }

    var body: some View {
        ZStack {
            ArcadeTheme.background.ignoresSafeArea()

            if let activeGame {
                ArcadeGameView(invocation: activeGame)
                    .id(activeGame)
            } else if isResolving {
                resolvingView
            } else if isSelecting {
                ArcadeGameSelectorView(
                    arcadotID: selectionArcadotID,
                    currentGame: selectorCurrentGame,
                    message: selectorMessage,
                    error: saveError,
                    isSaving: isSaving,
                    select: choose,
                    retry: retryPendingGame,
                    playOnce: playPendingGameOnce
                )
            } else {
                unsupportedView
            }

            controls
        }
        .preferredColorScheme(.dark)
        .tint(.cyan)
        .confirmationDialog(
            "Switch games? Your current run will end.",
            isPresented: $showSwitchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Switch Games", role: .destructive) { beginSwitching() }
            Button("Keep Playing", role: .cancel) {}
        }
        .task(id: experience) {
            await activate(experience)
        }
    }

    @ViewBuilder
    private var controls: some View {
        VStack {
            HStack {
                if let onExit {
                    chromeButton(systemName: "xmark", label: "Return to Arcade",
                                 identifier: "exitGame", action: onExit)
                }
                Spacer()
                if activeGame != nil {
                    chromeButton(systemName: "square.grid.2x2", label: "Switch games",
                                 identifier: "switchGame") {
                        showSwitchConfirmation = true
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private func chromeButton(systemName: String, label: String, identifier: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var resolvingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("LOADING ARCADOT")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.65))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resolvingArcadot")
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Text(Product.displayName)
                .font(.title2.weight(.semibold))
            Text("This experience isn’t supported by this version of Lumi Arcade.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
    }

    @MainActor
    private func activate(_ experience: ExperienceRouter.Experience) async {
        resetPresentation()
        switch experience {
        case .game(let invocation):
            selectionArcadotID = invocation.arcadotID
            activeGame = invocation
        case .arcadot(let id):
            assignmentArcadotID = id
            selectionArcadotID = id
            isResolving = true
            let resolver = ArcadotAssignmentResolver(service: assignmentService,
                                                      cache: assignmentCache)
            let resolution = await resolver.resolve(id)
            guard !Task.isCancelled else { return }
            isResolving = false
            switch resolution {
            case .remote(let game), .cached(let game):
                activeGame = GameInvocation(game: game, arcadotID: id)
            case .unavailable:
                selectorMessage = "Choose a game to play. This selection will be session-only until the necklace service is available."
                isSessionOnlySelection = true
                isSelecting = true
            }
        case .fallback:
            selectorMessage = "Choose an available Lumi Arcade game."
            isSelecting = true
        case .unsupported:
            break
        }
    }

    @MainActor
    private func resetPresentation() {
        activeGame = nil
        assignmentArcadotID = nil
        selectionArcadotID = nil
        selectorCurrentGame = nil
        isResolving = false
        isSelecting = false
        isSaving = false
        selectorMessage = nil
        saveError = nil
        pendingGame = nil
        isSessionOnlySelection = false
    }

    private func beginSwitching() {
        selectorCurrentGame = activeGame?.game
        selectionArcadotID = activeGame?.arcadotID
        activeGame = nil
        selectorMessage = assignmentArcadotID == nil
            ? "Choose a game for this play session."
            : "Choose the game this necklace should open."
        saveError = nil
        pendingGame = nil
        isSessionOnlySelection = false
        isSelecting = true
    }

    private func choose(_ game: GameType) {
        pendingGame = game
        saveError = nil
        guard !isSessionOnlySelection, let id = assignmentArcadotID else {
            play(game, arcadotID: selectionArcadotID)
            return
        }
        save(game, for: id)
    }

    private func save(_ game: GameType, for id: String) {
        isSaving = true
        Task {
            do {
                let assignment = try await assignmentService.update(game: game, for: id)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    assignmentCache.save(game: assignment.game, for: id)
                    isSaving = false
                    play(assignment.game, arcadotID: id)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isSaving = false
                    saveError = "Couldn’t save this game to the necklace. Retry or play it once."
                }
            }
        }
    }

    private func retryPendingGame() {
        guard let pendingGame, let id = assignmentArcadotID else { return }
        saveError = nil
        save(pendingGame, for: id)
    }

    private func playPendingGameOnce() {
        guard let pendingGame else { return }
        play(pendingGame, arcadotID: selectionArcadotID)
    }

    private func play(_ game: GameType, arcadotID: String?) {
        selectorCurrentGame = game
        pendingGame = nil
        saveError = nil
        isSelecting = false
        activeGame = GameInvocation(game: game, arcadotID: arcadotID)
    }
}

private struct ArcadeGameSelectorView: View {
    let arcadotID: String?
    let currentGame: GameType?
    let message: String?
    let error: String?
    let isSaving: Bool
    let select: (GameType) -> Void
    let retry: () -> Void
    let playOnce: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Product.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.cyan)
                    Text("Choose a Game")
                        .font(.largeTitle.bold())
                    if let arcadotID {
                        Text("ARCADOT #\(arcadotID)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                ForEach(GameType.allCases) { game in
                    Button { select(game) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: game.systemImageName)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(ArcadeTheme.accent(for: game))
                                .frame(width: 54, height: 54)
                                .background(ArcadeTheme.accent(for: game).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.gameNumber)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .tracking(1.6)
                                    .foregroundStyle(.white.opacity(0.42))
                                Text(game.displayName)
                                    .font(.title3.weight(.semibold))
                                Text(game.summary)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            Spacer()
                            if currentGame == game {
                                Text("CURRENT")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(ArcadeTheme.accent(for: game))
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .padding(18)
                        .background(ArcadeTheme.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(ArcadeTheme.accent(for: game).opacity(0.18), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .accessibilityIdentifier("select-\(game.rawValue)")
                }

                if isSaving {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Saving to necklace…")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .accessibilityIdentifier("savingAssignment")
                }

                if let error {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        HStack {
                            Button("Retry", action: retry)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("retryAssignment")
                            Button("Play Once", action: playOnce)
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("playOnce")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 74)
            .padding(.bottom, 36)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
        .accessibilityIdentifier("gameSelector")
    }
}
