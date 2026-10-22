import Foundation

struct RemoteInstruction: Equatable {
    var taskTitle: String
    var text: String

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTitle: String {
        taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum RemoteAttempt: Codable, Equatable {
    case notConnected(reason: String)
    case failed(message: String)
    case sessionCreated(sessionID: String, sessionURL: String)
}

struct AgentAvailability: Equatable {
    enum State: Equatable {
        case notConnected
        case credentialSaved
        case credentialInvalid
    }

    var state: State
    var reason: String

    var shortStatus: String {
        switch state {
        case .notConnected:
            return AgentCopy.statusNotConnected
        case .credentialSaved:
            return AgentCopy.shortCredentialSaved
        case .credentialInvalid:
            return AgentCopy.shortBadCredential
        }
    }
}

protocol AgentRemote {
    var kind: AgentKind { get }
    var availability: AgentAvailability { get }

    /// A non-nil value means the attempt can be decided locally and must not hit the network.
    func preflight(_ instruction: RemoteInstruction) -> RemoteAttempt?

    func send(_ instruction: RemoteInstruction) async -> RemoteAttempt

    func statusTitle(for result: RemoteAttempt?) -> String
    func statusDetail(for result: RemoteAttempt?) -> String
    func approvalNote(for result: RemoteAttempt?) -> String
    func resultSummary(for result: RemoteAttempt?) -> String
}

extension AgentRemote {
    func statusTitle(for result: RemoteAttempt?) -> String {
        AgentCopy.statusTitle(for: result)
    }

    func statusDetail(for result: RemoteAttempt?) -> String {
        AgentCopy.statusDetail(for: result)
    }

    func approvalNote(for result: RemoteAttempt?) -> String {
        AgentCopy.approvalNote(for: result)
    }

    func resultSummary(for result: RemoteAttempt?) -> String {
        AgentCopy.resultSummary(for: result)
    }
}
