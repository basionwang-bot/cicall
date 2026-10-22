# Catilina（iOS）

手机上的**入口 / 遥控器**。人在这里发布任务、看进度、做批准；重活在各引擎自己的后端。这台手机不是执行主机。

这一版能遥控的名字是四个，客户端各一个，都走同一个 `AgentRemote` 协议：

- Grok Bot
- Muse
- Codex
- Claude Code

难易、能不能协作，这一版不判断。

本目录不连 cicall daemon。daemon 只有本机 Unix socket，没有可带 token 的远程接口。

## 在 Mac 上打开

需要 macOS、Xcode 15 或更新（iOS 17 SDK）、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
cd ios/Catilina
xcodegen generate
open Catilina.xcodeproj
```

`project.yml` 是工程描述。生成的 `Catilina.xcodeproj` 不要提交。

用 iOS 17 或更高的模拟器运行。真机的话，在 Signing & Capabilities 里选自己的 Team。不需要付费账号也能跑模拟器；Xcode 若提示签名，选 Personal Team 即可。

凭证只放在本机钥匙串（service `bot.basionwang.catilina`）。不要把 token 写进仓库、截图或任务正文。

这台 Linux 云主机没有 Xcode，也没有 iOS 模拟器，所以这里没有编译过这个工程。

## 三个画面

- **发布**：写下标题和说明。发布只把任务记在手机上，不联系任何引擎。
- **引擎**：勾选一个或多个。每一行写明现在能不能遥控，以及原因。
- **会话**：编辑远程指令，确认后发送。每个引擎给出状态、批准操作、结果摘要。

发送前会说明这次会不会真的发网络请求。未连接或凭证不可用时，不会发请求，也不会把结果写成成功。

## 今天每个引擎能做什么

| 引擎 | 手机上的真实行为 | 不能做的 |
|---|---|---|
| Claude Code | 钥匙串里有有效凭证时，`POST https://api.anthropic.com/v1/claude_code/routines/{routine_id}/fire`。请求头是 `Authorization: Bearer`、`anthropic-version: 2026-10-21`。正文 `text` 为 `任务：{标题}` 加空行再加指令，最长 65536 字。HTTP 200 且 `type == routine_fire`、带 `claude.ai` 会话 id 和 URL 时，才显示「已创建云端会话」。 | token 没有读权限。不能拉进度，不能代为批准，响应里没有结果正文。拒绝跳转到 `api.anthropic.com` 以外的地址。非 200、字段不全、会话 URL 不是 `https://claude.ai`，都不会当成成功。每次成功的 fire 都会新建一个会话，失败不会自动重试。 |
| Grok Bot | 未连接。 | 没有可用用户 token 发任务的官方 HTTP API。给 Bot 发消息要在 Grok Bot 应用里做。公开的 Admin / Organization API 只管理团队策略和云电脑，不发送任务。本应用不调用未公开的云电脑网关。 |
| Muse | 未连接。 | 没有可用用户 token 从手机把任务交给 Muse 的官方 HTTP API。Muse Code 要在执行机上跑 `muse` / `muse serve`。Meta 个人 Muse 没有公开的发任务接口。Model API 只做模型推理，不能当作已经遥控 Muse。 |
| Codex | 未连接。 | Codex 云端任务要求 ChatGPT 登录，不是可粘贴的 API token。官方 API key 和 access token 用于本机 CLI。没有公开的第三方云端任务 HTTP 接口，所以这里不发送，也不调用 CLI 源码里的未公开路径。 |

Claude Code 的官方说明：<https://platform.claude.com/docs/en/api/claude-code/routines-fire>。凭证在 claude.ai/code/routines 里给已有 routine 加 API 触发器后生成，id 以 `trig_` 开头，token 以 `sk-ant-oat01-` 开头，只显示一次。在「引擎」页的「Claude Code 凭证」里保存。没有凭证时，发送不会出网。

Claude Code 的 Remote Control 需要本机已登录的 `claude` 会话，不是第三方用 token 能调用的接口，所以没有接。

## 协议

`AgentRemote`（`RemoteModels.swift`）上每个引擎提供：

- `availability`：现在能不能发，以及给人看的原因
- `preflight`：能在本地做完的结论。返回非空就**不会**发网络
- `send`：只有 preflight 为空时才会出网
- 状态、批准说明、结果摘要：由该客户端给出，界面不另写「已成功」

Grok Bot、Muse、Codex 的 `send` 固定返回未连接，文件里没有 `URLSession`。
