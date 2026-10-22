import Foundation

struct AgentAttempt: Codable, Equatable {
    var agent: AgentKind
    var instruction: String
    var sentAt: Date
    var result: RemoteAttempt
}

struct PublishedTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var instruction: String
    var createdAt: Date
    var attempts: [AgentAttempt]

    func attempt(for agent: AgentKind) -> AgentAttempt? {
        attempts.last { $0.agent == agent }
    }
}

enum AppTab: Hashable {
    case compose
    case roster
    case sessions
}
