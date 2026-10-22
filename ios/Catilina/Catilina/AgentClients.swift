import Foundation

/// No URLSession. Grok Bot has no official token-authenticated task API.
struct GrokBotClient: AgentRemote {
    let kind: AgentKind = .grokBot

    var availability: AgentAvailability {
        AgentAvailability(state: .notConnected, reason: AgentCopy.grokNotConnected)
    }

    func preflight(_ instruction: RemoteInstruction) -> RemoteAttempt? {
        .notConnected(reason: AgentCopy.grokNotConnected)
    }

    func send(_ instruction: RemoteInstruction) async -> RemoteAttempt {
        .notConnected(reason: AgentCopy.grokNotConnected)
    }
}

/// No URLSession. Muse Code is a local `muse` / `muse serve` host.
/// The Meta Model API is inference, not remote control of Muse.
struct MuseClient: AgentRemote {
    let kind: AgentKind = .muse

    var availability: AgentAvailability {
        AgentAvailability(state: .notConnected, reason: AgentCopy.museNotConnected)
    }

    func preflight(_ instruction: RemoteInstruction) -> RemoteAttempt? {
        .notConnected(reason: AgentCopy.museNotConnected)
    }

    func send(_ instruction: RemoteInstruction) async -> RemoteAttempt {
        .notConnected(reason: AgentCopy.museNotConnected)
    }
}

/// No URLSession. Codex cloud is ChatGPT sign-in, not a third-party token API.
struct CodexClient: AgentRemote {
    let kind: AgentKind = .codex

    var availability: AgentAvailability {
        AgentAvailability(state: .notConnected, reason: AgentCopy.codexNotConnected)
    }

    func preflight(_ instruction: RemoteInstruction) -> RemoteAttempt? {
        .notConnected(reason: AgentCopy.codexNotConnected)
    }

    func send(_ instruction: RemoteInstruction) async -> RemoteAttempt {
        .notConnected(reason: AgentCopy.codexNotConnected)
    }
}

final class AgentRegistry {
    private let grokBot = GrokBotClient()
    private let muse = MuseClient()
    private let codex = CodexClient()
    private let claudeCode = ClaudeCodeClient()

    func client(for kind: AgentKind) -> any AgentRemote {
        switch kind {
        case .grokBot: grokBot
        case .muse: muse
        case .codex: codex
        case .claudeCode: claudeCode
        }
    }
}
