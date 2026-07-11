# 在另一台电脑测试 Cicall v0.1.0

当前支持 macOS 和 Linux，需要 Python 3.9 或更新版本。

## 一键安装

建议先打开安装脚本确认内容：

```bash
curl -fsSL https://raw.githubusercontent.com/basionwang-bot/cicall/main/scripts/install.sh
```

确认后安装：

```bash
curl -fsSL https://raw.githubusercontent.com/basionwang-bot/cicall/main/scripts/install.sh | sh
```

## 自检

```bash
~/.local/bin/cicall doctor --fix
```

所有检查项应显示 `✓`。

## HermesPet

进入准备测试的项目目录：

```bash
cd /path/to/your/project
~/.local/bin/cicall setup --client hermes --project test-project --cwd "$PWD"
```

将输出的 `mcpServers` JSON 复制到 HermesPet，然后刷新 MCP Server。

依次测试：

1. `list_sessions`
2. `start_session`，参数为 `{"command":["/bin/sh","-c","printf cicall-ok"]}`
3. 使用返回的 session id 调用 `read_output`
4. 调用 `close_session`

`read_output` 应返回 `cicall-ok`。

## Codex

如果电脑上已经安装 Codex CLI：

```bash
cd /path/to/your/project
~/.local/bin/cicall setup --client codex --project test-project --cwd "$PWD" --apply
codex mcp list
```

然后在 Codex 中使用 `/mcp` 检查 `cicall`。

## 手动安装 release wheel

如果不使用安装脚本：

```bash
python3 -m venv ~/.local/share/cicall/venv
~/.local/share/cicall/venv/bin/pip install \
  https://github.com/basionwang-bot/cicall/releases/download/v0.1.0/cicall-0.1.0-py3-none-any.whl
~/.local/share/cicall/venv/bin/cicall doctor --fix
```

## 卸载

```bash
~/.local/bin/cicall daemon stop || true
rm -f ~/.local/bin/cicall ~/.local/bin/cicall-mcp ~/.local/bin/cicall-daemon
rm -rf ~/.local/share/cicall ~/.local/state/cicall
```
