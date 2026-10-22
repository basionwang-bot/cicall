import Foundation

/// Official Claude Code routine fire endpoint.
/// https://platform.claude.com/docs/en/api/claude-code/routines-fire
enum ClaudeCodeEndpoint {
    static let host = "api.anthropic.com"
    static let sessionHost = "claude.ai"
    static let apiVersion = "2026-10-21"
    static let maxTextLength = 65_536
    static let tokenPrefix = "sk-ant-oat01-"
    static let routinePrefix = "trig_"

    static func composedText(_ instruction: RemoteInstruction) -> String {
        let title = instruction.trimmedTitle
        let text = instruction.trimmedText
        if title.isEmpty { return text }
        return "任务：\(title)\n\n\(text)"
    }

    static func isPlausibleRoutineID(_ id: String) -> Bool {
        guard id.hasPrefix(routinePrefix), id.count > routinePrefix.count, id.count <= 128 else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static func isRoutineToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == token else { return false }
        guard trimmed.hasPrefix(tokenPrefix), trimmed.count > tokenPrefix.count, trimmed.count <= 400 else {
            return false
        }
        return trimmed.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 0x21 && scalar.value <= 0x7E
        }
    }

    /// Accepts a `trig_…` id or the exact fire URL the Claude Code UI shows.
    /// Any other host is rejected so the bearer token is not sent there.
    static func fireURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("https://") {
            guard let url = URL(string: trimmed),
                  url.scheme == "https",
                  url.host?.lowercased() == host,
                  url.port == nil,
                  url.user == nil,
                  url.password == nil,
                  url.query == nil,
                  url.fragment == nil
            else { return nil }
            let parts = url.path.split(separator: "/").map(String.init)
            guard parts.count == 5,
                  parts[0] == "v1",
                  parts[1] == "claude_code",
                  parts[2] == "routines",
                  parts[4] == "fire",
                  isPlausibleRoutineID(parts[3])
            else { return nil }
            return URL(string: "https://\(host)/v1/claude_code/routines/\(parts[3])/fire")
        }
        guard isPlausibleRoutineID(trimmed) else { return nil }
        return URL(string: "https://\(host)/v1/claude_code/routines/\(trimmed)/fire")
    }

    static func acceptedSessionURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              url.scheme == "https",
              url.host?.lowercased() == sessionHost,
              url.user == nil
        else { return nil }
        return url
    }
}

struct FireBody: Encodable {
    var text: String
}

struct FireResponse: Decodable {
    var type: String
    var claudeCodeSessionId: String
    var claudeCodeSessionUrl: String

    enum CodingKeys: String, CodingKey {
        case type
        case claudeCodeSessionId = "claude_code_session_id"
        case claudeCodeSessionUrl = "claude_code_session_url"
    }
}

struct AnthropicErrorEnvelope: Decodable {
    struct Body: Decodable {
        var type: String?
        var message: String?
    }

    var error: Body?
}

final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    private let lock = NSLock()
    private var refused = false

    func consumeRefused() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let value = refused
        refused = false
        return value
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let host = request.url?.host?.lowercased()
        if request.url?.scheme == "https", host == ClaudeCodeEndpoint.host {
            completionHandler(request)
        } else {
            lock.lock()
            refused = true
            lock.unlock()
            completionHandler(nil)
        }
    }
}

enum ClaudeCredentialLoad {
    case missing
    case routineMissing
    case tokenMissing
    case loaded(routineID: String, token: String)
    case unavailable(message: String)
}

final class ClaudeCodeClient: AgentRemote {
    let kind: AgentKind = .claudeCode

    var availability: AgentAvailability {
        switch loadCredentials() {
        case .missing:
            return AgentAvailability(state: .notConnected, reason: AgentCopy.claudeMissing)
        case .routineMissing:
            return AgentAvailability(state: .notConnected, reason: AgentCopy.claudeRoutineMissing)
        case .tokenMissing:
            return AgentAvailability(state: .notConnected, reason: AgentCopy.claudeTokenMissing)
        case .unavailable(let message):
            return AgentAvailability(state: .notConnected, reason: message)
        case .loaded(let routineID, let token):
            if ClaudeCodeEndpoint.fireURL(from: routineID) == nil || !ClaudeCodeEndpoint.isRoutineToken(token) {
                let reason = ClaudeCodeEndpoint.fireURL(from: routineID) == nil
                    ? AgentCopy.claudeBadRoutine
                    : AgentCopy.claudeBadToken
                return AgentAvailability(state: .credentialInvalid, reason: reason)
            }
            return AgentAvailability(state: .credentialSaved, reason: AgentCopy.claudeCredentialSaved)
        }
    }

    func preflight(_ instruction: RemoteInstruction) -> RemoteAttempt? {
        switch loadCredentials() {
        case .missing:
            return .notConnected(reason: AgentCopy.claudeMissing)
        case .routineMissing:
            return .notConnected(reason: AgentCopy.claudeRoutineMissing)
        case .tokenMissing:
            return .notConnected(reason: AgentCopy.claudeTokenMissing)
        case .unavailable(let message):
            return .failed(message: message)
        case .loaded(let routineID, let token):
            if ClaudeCodeEndpoint.fireURL(from: routineID) == nil {
                return .failed(message: AgentCopy.claudeBadRoutine)
            }
            if !ClaudeCodeEndpoint.isRoutineToken(token) {
                return .failed(message: AgentCopy.claudeBadToken)
            }
            if ClaudeCodeEndpoint.composedText(instruction).count > ClaudeCodeEndpoint.maxTextLength {
                return .failed(message: AgentCopy.claudeTextTooLong)
            }
            return nil
        }
    }

    func send(_ instruction: RemoteInstruction) async -> RemoteAttempt {
        if let local = preflight(instruction) {
            return local
        }
        guard case .loaded(let routineID, let token) = loadCredentials(),
              let url = ClaudeCodeEndpoint.fireURL(from: routineID)
        else {
            return .failed(message: "凭证在发送前失效。没有发送。")
        }
        let text = ClaudeCodeEndpoint.composedText(instruction)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ClaudeCodeEndpoint.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Catilina/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        do {
            request.httpBody = try JSONEncoder().encode(FireBody(text: text))
        } catch {
            return .failed(message: "请求体无法编码。没有发送。")
        }

        let redirectGuard = RedirectGuard()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (data, response) = try await session.data(for: request)
            return Self.interpret(data: data, response: response)
        } catch {
            if redirectGuard.consumeRefused() {
                return .failed(message: "服务器要求跳转到 api.anthropic.com 以外的地址。已拒绝跳转，避免把 token 送到别的主机。没有当成成功。")
            }
            return .failed(message: "网络错误：\(error.localizedDescription)。没有把这次调用当成成功。")
        }
    }

    func approvalNote(for result: RemoteAttempt?) -> String {
        if case .sessionCreated = result {
            return AgentCopy.claudeSessionApproval
        }
        return AgentCopy.approvalNote(for: result)
    }

    func resultSummary(for result: RemoteAttempt?) -> String {
        if case .sessionCreated(_, let sessionURL) = result {
            return AgentCopy.claudeResult(sessionURL: sessionURL)
        }
        return AgentCopy.resultSummary(for: result)
    }

    static func interpret(data: Data, response: URLResponse) -> RemoteAttempt {
        guard let http = response as? HTTPURLResponse else {
            return .failed(message: "没有 HTTP 响应。没有把这次调用当成成功。")
        }
        if http.statusCode == 200 {
            guard let decoded = try? JSONDecoder().decode(FireResponse.self, from: data),
                  decoded.type == "routine_fire",
                  !decoded.claudeCodeSessionId.isEmpty,
                  ClaudeCodeEndpoint.acceptedSessionURL(decoded.claudeCodeSessionUrl) != nil
            else {
                return .failed(message: "HTTP 200，但响应不是带 claude.ai 会话地址的 routine_fire。没有把它当成成功。")
            }
            return .sessionCreated(
                sessionID: decoded.claudeCodeSessionId,
                sessionURL: decoded.claudeCodeSessionUrl
            )
        }

        let envelope = try? JSONDecoder().decode(AnthropicErrorEnvelope.self, from: data)
        var text = "HTTP \(http.statusCode)"
        if let type = envelope?.error?.type, !type.isEmpty {
            text += " \(type)"
        }
        if let message = envelope?.error?.message, !message.isEmpty {
            text += "：\(message)"
        }
        if http.statusCode == 429, let retry = http.value(forHTTPHeaderField: "Retry-After"), !retry.isEmpty {
            text += "。Retry-After: \(retry)。没有自动重试，避免重复开会话。"
        }
        text += "。没有把这次调用当成成功。"
        return .failed(message: text)
    }

    func loadCredentials() -> ClaudeCredentialLoad {
        do {
            let routine = try KeychainStore.get(account: KeychainStore.routineAccount)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let token = try KeychainStore.get(account: KeychainStore.tokenAccount)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasRoutine = !(routine ?? "").isEmpty
            let hasToken = !(token ?? "").isEmpty
            switch (hasRoutine, hasToken) {
            case (false, false):
                return .missing
            case (false, true):
                return .routineMissing
            case (true, false):
                return .tokenMissing
            case (true, true):
                return .loaded(routineID: routine ?? "", token: token ?? "")
            }
        } catch let error as KeychainError {
            return .unavailable(message: error.message)
        } catch {
            return .unavailable(message: AgentCopy.claudeKeychainUnavailable)
        }
    }
}
