import Foundation

struct ExperienceRouter {
    enum Experience: Equatable {
        case game(GameInvocation)
        case fallback
        case unsupported
    }
    enum UnknownGamePolicy { case fallback, unsupported }
    private let unknownGamePolicy: UnknownGamePolicy

    init(unknownGamePolicy: UnknownGamePolicy? = nil) {
        #if DEBUG
        self.unknownGamePolicy = unknownGamePolicy ?? .fallback
        #else
        self.unknownGamePolicy = unknownGamePolicy ?? .unsupported
        #endif
    }

    func resolve(_ invocation: AppInvocation) -> Experience {
        guard let url = invocation.url else { return .game(.localPlay) }
        return route(from: url)
    }

    /// The single boundary between external invocation URLs and internal game state.
    /// Future short-code resolution can feed a GameInvocation through this same router
    /// without exposing URL details to an individual game.
    func route(from url: URL) -> Experience {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == Product.invocationHost,
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return .game(.localPlay) }
        let path = url.pathComponents.filter { $0 != "/" }

        if path == ["play"] {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let rawGame = components.queryItems?.first(where: { $0.name == "game" })?.value,
                  !rawGame.isEmpty,
                  let game = GameType(rawValue: rawGame) else { return .fallback }
            return .game(GameInvocation(game: game, arcadotID: nil))
        }

        // Retain the early game-only links; opaque legacy /c/ codes are not
        // promoted to Arcadot identities because their meaning was never defined.
        if path == ["game", "sky-stack"] { return .game(.localPlay) }
        guard path.count == 3, path[0] == "g", Arcadot.isValidID(path[2]) else {
            return .game(.localPlay)
        }
        guard let game = GameType(rawValue: path[1]) else {
            // Never attribute a fallback game's scores to another game's Arcadot.
            return unknownGamePolicy == .fallback ? .game(.localPlay) : .unsupported
        }
        return .game(GameInvocation(game: game, arcadotID: path[2]))
    }
}
