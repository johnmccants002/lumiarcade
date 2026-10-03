import Foundation

struct ArcadotAssignment: Equatable, Codable {
    let arcadotID: String
    let game: GameType
    let updatedAt: Date?
}

enum ArcadotAssignmentError: LocalizedError, Equatable {
    case unavailable
    case invalidConfiguration
    case invalidResponse
    case arcadotNotFound
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The necklace service is unavailable."
        case .invalidConfiguration:
            return "Necklace service configuration is missing."
        case .invalidResponse:
            return "The necklace service returned an invalid response."
        case .arcadotNotFound:
            return "This necklace has not been configured yet."
        case .server:
            return "The necklace service could not complete the request."
        }
    }
}

protocol ArcadotAssignmentService {
    func assignment(for arcadotID: String) async throws -> ArcadotAssignment
    func update(game: GameType, for arcadotID: String) async throws -> ArcadotAssignment
}

protocol ArcadotAssignmentCaching {
    func game(for arcadotID: String) -> GameType?
    func save(game: GameType, for arcadotID: String)
}

final class UserDefaultsArcadotAssignmentCache: ArcadotAssignmentCaching {
    private let defaults: UserDefaults
    private let keyPrefix = "lumi.arcadot.activeGame."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func game(for arcadotID: String) -> GameType? {
        defaults.string(forKey: keyPrefix + arcadotID).flatMap(GameType.init(rawValue:))
    }

    func save(game: GameType, for arcadotID: String) {
        defaults.set(game.rawValue, forKey: keyPrefix + arcadotID)
    }
}

enum ArcadotAssignmentResolution: Equatable {
    case remote(GameType)
    case cached(GameType)
    case unavailable
}

struct ArcadotAssignmentResolver {
    let service: any ArcadotAssignmentService
    let cache: any ArcadotAssignmentCaching

    func resolve(_ arcadotID: String) async -> ArcadotAssignmentResolution {
        do {
            let assignment = try await service.assignment(for: arcadotID)
            cache.save(game: assignment.game, for: arcadotID)
            return .remote(assignment.game)
        } catch {
            if let cached = cache.game(for: arcadotID) {
                return .cached(cached)
            }
            return .unavailable
        }
    }
}

struct SupabaseArcadotAssignmentConfiguration: Equatable {
    let projectURL: URL
    let publishableKey: String

    static func bundled(_ bundle: Bundle = .main) -> SupabaseArcadotAssignmentConfiguration? {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "LumiSupabaseURL") as? String,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https",
              let key = bundle.object(forInfoDictionaryKey: "LumiSupabasePublishableKey") as? String,
              !key.isEmpty,
              !rawURL.contains("YOUR_PROJECT"),
              !key.contains("REPLACE_ME") else { return nil }
        return SupabaseArcadotAssignmentConfiguration(projectURL: url, publishableKey: key)
    }

    var functionURL: URL {
        projectURL.appending(path: "functions/v1/arcadot-game")
    }
}

struct SupabaseArcadotAssignmentService: ArcadotAssignmentService {
    private struct AssignmentResponse: Decodable {
        let id: String
        let activeGame: String
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case activeGame = "active_game"
            case updatedAt = "updated_at"
        }
    }

    private struct UpdateRequest: Encodable {
        let id: String
        let game: String
    }

    private let configuration: SupabaseArcadotAssignmentConfiguration
    private let session: URLSession

    init(configuration: SupabaseArcadotAssignmentConfiguration,
         session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func assignment(for arcadotID: String) async throws -> ArcadotAssignment {
        guard Arcadot.isValidID(arcadotID),
              var components = URLComponents(url: configuration.functionURL,
                                             resolvingAgainstBaseURL: false) else {
            throw ArcadotAssignmentError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "id", value: arcadotID)]
        guard let url = components.url else { throw ArcadotAssignmentError.invalidResponse }
        var request = configuredRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request, expectedID: arcadotID)
    }

    func update(game: GameType, for arcadotID: String) async throws -> ArcadotAssignment {
        guard Arcadot.isValidID(arcadotID) else {
            throw ArcadotAssignmentError.invalidResponse
        }
        var request = configuredRequest(url: configuration.functionURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UpdateRequest(id: arcadotID, game: game.rawValue))
        let assignment = try await perform(request, expectedID: arcadotID)
        guard assignment.game == game else { throw ArcadotAssignmentError.invalidResponse }
        return assignment
    }

    private func configuredRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest, expectedID: String) async throws -> ArcadotAssignment {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ArcadotAssignmentError.invalidResponse
            }
            switch http.statusCode {
            case 200...299:
                let response = try JSONDecoder().decode(AssignmentResponse.self, from: data)
                guard response.id == expectedID,
                      let game = GameType(rawValue: response.activeGame) else {
                    throw ArcadotAssignmentError.invalidResponse
                }
                return ArcadotAssignment(arcadotID: response.id, game: game,
                                          updatedAt: Self.date(from: response.updatedAt))
            case 404:
                throw ArcadotAssignmentError.arcadotNotFound
            default:
                throw ArcadotAssignmentError.server(statusCode: http.statusCode)
            }
        } catch let error as ArcadotAssignmentError {
            throw error
        } catch is DecodingError {
            throw ArcadotAssignmentError.invalidResponse
        } catch {
            throw ArcadotAssignmentError.unavailable
        }
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct UnavailableArcadotAssignmentService: ArcadotAssignmentService {
    func assignment(for arcadotID: String) async throws -> ArcadotAssignment {
        throw ArcadotAssignmentError.unavailable
    }

    func update(game: GameType, for arcadotID: String) async throws -> ArcadotAssignment {
        throw ArcadotAssignmentError.unavailable
    }
}

#if DEBUG
struct DebugArcadotAssignmentService: ArcadotAssignmentService {
    let initialGame: GameType

    func assignment(for arcadotID: String) async throws -> ArcadotAssignment {
        ArcadotAssignment(arcadotID: arcadotID, game: initialGame, updatedAt: Date())
    }

    func update(game: GameType, for arcadotID: String) async throws -> ArcadotAssignment {
        ArcadotAssignment(arcadotID: arcadotID, game: game, updatedAt: Date())
    }
}
#endif

enum ArcadotAssignmentServiceFactory {
    static func live(bundle: Bundle = .main,
                     arguments: [String] = ProcessInfo.processInfo.arguments) -> any ArcadotAssignmentService {
        #if DEBUG
        if arguments.contains("-LumiArcadeAssignmentUnavailable") {
            return UnavailableArcadotAssignmentService()
        }
        if let index = arguments.firstIndex(of: "-LumiArcadeAssignmentGame"),
           arguments.indices.contains(index + 1),
           let game = GameType(rawValue: arguments[index + 1]) {
            return DebugArcadotAssignmentService(initialGame: game)
        }
        #endif
        guard let configuration = SupabaseArcadotAssignmentConfiguration.bundled(bundle) else {
            return UnavailableArcadotAssignmentService()
        }
        return SupabaseArcadotAssignmentService(configuration: configuration)
    }
}
