import Foundation

enum AgentKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case grokBot
    case muse
    case codex
    case claudeCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grokBot: "Grok Bot"
        case .muse: "Muse"
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    var blurb: String {
        switch self {
        case .grokBot: AgentCopy.grokBlurb
        case .muse: AgentCopy.museBlurb
        case .codex: AgentCopy.codexBlurb
        case .claudeCode: AgentCopy.claudeBlurb
        }
    }
}
