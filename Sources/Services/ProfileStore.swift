import Foundation

struct ProfileStore: Sendable {
    var stateURL: URL = AppPaths.stateURL

    func load() -> AgentsHubState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? Data(contentsOf: stateURL),
              let state = try? decoder.decode(AgentsHubState.self, from: data)
        else {
            return .empty
        }

        return state
    }

    func save(_ state: AgentsHubState) throws {
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }
}
