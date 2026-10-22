import SwiftUI

/// User-visible copy for remote-control honesty. Screens and clients share these strings.
enum AgentCopy {
    static let discriminationNote = "难易和是否可协作，这一版不判断。手机只负责把任务交给所选引擎，重活在各引擎自己的后端。"
    static let publishFootnote = "发布只把任务记在这台手机上，不会联系任何引擎。"
    static let rosterIntro = "选择一个或多个引擎。手机不是执行主机，重活在各引擎自己的后端。"
    static let retryCaption = "再发送会再试一次。Claude Code 每次成功的 fire 都会新建一个会话。"
    static let confirmLocal = "所选引擎目前都不会收到网络请求。会话页会记下未连接或凭证错误，不会显示成遥控成功。"
    static let confirmNetwork = "Claude Code 将 POST 官方 fire 接口。成功会新建一个云端会话，并且只返回会话 id 和 URL。这个 token 不能读进度，也不能代你批准。未连接的引擎不会发请求。"
    static let emptySessions = "还没有发布的任务。在「发布」里写一条，再到这里发送。"
    static let credentialHelp = "只保存 Claude Code routine 的 fire 凭证。routine id 形如 trig_…，token 形如 sk-ant-oat01-…，在 claude.ai/code/routines 的 API 触发器里生成。token 只进钥匙串，不进任务记录。"
    static let previewBlockedNetwork = "凭证看起来可用，但这是不联网的预览。没有调用 fire，没有新建会话。"

    static let grokBlurb = "xAI 的持久队友。执行在它的云电脑上。"
    static let museBlurb = "Meta 的 Muse。执行在 Muse 自己的环境里。"
    static let codexBlurb = "OpenAI Codex。执行在 Codex 云端或本机 CLI。"
    static let claudeBlurb = "Anthropic 的编码代理。云端会话在 Anthropic 的机器上。"

    static let grokNotConnected = "未连接：Grok Bot 没有可用用户 token 发任务的官方 HTTP API。给 Bot 发消息要在 Grok Bot 应用里做。公开的 Admin / Organization API 只管理团队策略和云电脑，不发送任务。"
    static let museNotConnected = "未连接：没有可用用户 token 从手机把任务交给 Muse 的官方 HTTP API。Muse Code 要在执行机上跑 muse / muse serve。Meta 个人 Muse 没有公开的发任务接口。Model API 只做模型推理，不能当作已经遥控 Muse。"
    static let codexNotConnected = "未连接：Codex 云端任务要求 ChatGPT 登录，不是可粘贴的 API token。官方 API key 和 access token 用于本机 CLI。没有公开的第三方云端任务 HTTP 接口，所以这里不发送。"
    static let claudeMissing = "未连接：钥匙串里还没有 Claude Code routine 凭证。官方实验接口是 POST /v1/claude_code/routines/{routine_id}/fire，需要你在 claude.ai/code/routines 生成的 trig_… 和一次性 Bearer token。没有凭证时不会发请求。"
    static let claudeTokenMissing = "未连接：钥匙串里有 routine id，但没有 Bearer token。没有发送。"
    static let claudeRoutineMissing = "未连接：钥匙串里有 token，但没有 routine id。没有发送。"
    static let claudeCredentialSaved = "凭证在本机钥匙串。尚未向 Anthropic 发探测。发送时才会 POST fire；成功只返回新会话的 id 和 URL，不含进度、批准或结果正文。"
    static let claudeBadRoutine = "routine id 不能构成官方 fire URL。需要 trig_ 开头的 id，或 https://api.anthropic.com/v1/claude_code/routines/trig_…/fire。没有发送。"
    static let claudeBadToken = "token 不是文档里的 routine token（应以 sk-ant-oat01- 开头），或者含有空白。没有发送。"
    static let claudeTextTooLong = "指令超过 65536 字，超过官方 text 上限。没有发送。"
    static let claudeKeychainUnavailable = "钥匙串读取失败。没有发送。"

    static let notSentDetail = "还没有向这个引擎发送。"
    static let notSentApproval = "不能批准。还没有发到这个引擎，没有远程会话。"
    static let notConnectedApproval = "不能批准。这个引擎未连接，没有远程会话。"
    static let failedApproval = "不能批准。上次发送没有建立可批准的远程会话。"
    static let genericSessionApproval = "不能在手机上批准。当前客户端没有批准接口。"
    static let claudeSessionApproval = "不能在手机上批准。routine token 没有读权限，fire 接口也不接受批准。进度和批准在返回的 claude.ai 会话页。"
    static let noResultNotSent = "无结果。还没有发送。"
    static let noResultNotConnected = "无结果。任务没有发到这个引擎。"
    static let noResultFailed = "无结果正文。发送没有成功。"

    static let statusNotSent = "尚未发送"
    static let statusNotConnected = "未连接"
    static let statusFailed = "发送失败"
    static let statusSessionCreated = "已创建云端会话"
    static let shortCredentialSaved = "凭证已保存，尚未验证"
    static let shortBadCredential = "凭证格式不对"

    static func statusTitle(for result: RemoteAttempt?) -> String {
        switch result {
        case nil:
            return statusNotSent
        case .notConnected:
            return statusNotConnected
        case .failed:
            return statusFailed
        case .sessionCreated:
            return statusSessionCreated
        }
    }

    static func statusDetail(for result: RemoteAttempt?) -> String {
        switch result {
        case nil:
            return notSentDetail
        case .notConnected(let reason):
            return reason
        case .failed(let message):
            return message
        case .sessionCreated(let sessionID, let sessionURL):
            return "会话 \(sessionID)。\(sessionURL)"
        }
    }

    static func approvalNote(for result: RemoteAttempt?) -> String {
        switch result {
        case nil:
            return notSentApproval
        case .notConnected:
            return notConnectedApproval
        case .failed:
            return failedApproval
        case .sessionCreated:
            return genericSessionApproval
        }
    }

    static func resultSummary(for result: RemoteAttempt?) -> String {
        switch result {
        case nil:
            return noResultNotSent
        case .notConnected:
            return noResultNotConnected
        case .failed:
            return noResultFailed
        case .sessionCreated(_, let sessionURL):
            return "无结果正文。客户端没有拿到输出。\(sessionURL)"
        }
    }

    static func claudeResult(sessionURL: String) -> String {
        "无结果正文。接口在创建会话后就返回，不包含输出。打开会话查看：\(sessionURL)"
    }
}

enum PreviewData {
    static let title = "整理本周发布说明"
    static let instruction = "根据 main 上这一周的提交写发布说明。不要改代码，做完把摘要交回来。"
}
