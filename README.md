# Cicall

**Run and orchestrate CLI agents from any terminal.**

Cicall is a terminal-independent, local MCP runtime for CLI agents. It owns the
agent processes and their pseudo-terminals in a small background daemon. Your
terminal, editor, desktop app, or MCP client is only a replaceable frontend.

```text
Claude Code / Codex / Kimi / OpenCode
                  │ MCP (stdio)
             cicall-mcp
                  │ local Unix socket
             cicall daemon
                  │ PTY
          any CLI agent or command
```

This repository is an independent extraction of the session-orchestration idea
first prototyped in Helios. Cicall does not depend on Helios, Ghostty, AppKit,
or any particular terminal emulator.

## Status

Cicall is an early, usable MVP for macOS and Linux. The current release is
local-only and has no network listener. Do not expose its Unix socket to users
you do not trust: a connected client can launch commands with your account.

## Install

Python 3.9 or newer is required. The simplest install keeps Cicall in its own
environment and exposes the commands through `~/.local/bin`:

```bash
curl -fsSL https://raw.githubusercontent.com/basionwang-bot/cicall/main/scripts/install.sh | sh
~/.local/bin/cicall setup --client hermes --project my-app --cwd "$PWD"
```

You can inspect [scripts/install.sh](scripts/install.sh) before running it. A
manual installation from the GitHub release is documented in
[docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md).

`cicall setup` starts the local runtime and prints the exact MCP configuration
for the current installation. The MCP server also starts the daemon automatically,
so users do not have to manage it before opening their MCP client.

For development from a source checkout:

```bash
cd ~/Desktop/cicall
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
pip install -e .
cicall setup --client generic --project my-app
```

No Python package is required at runtime beyond the standard library.

## Use it from any terminal

Start an interactive CLI and stay attached:

```bash
cicall run --project my-app --cwd ~/code/my-app -- claude
```

Start it in the background:

```bash
cicall run --detach --project my-app --cwd ~/code/my-app -- codex
cicall list --project my-app
cicall attach s-xxxxxxxxxxxx
```

Read or drive a session without attaching a terminal UI:

```bash
cicall read s-xxxxxxxxxxxx
cicall send s-xxxxxxxxxxxx "Please run the tests" --enter
cicall key s-xxxxxxxxxxxx ctrl-c
cicall close s-xxxxxxxxxxxx
```

Switching from Terminal.app to iTerm, Ghostty, Warp, VS Code, or SSH does not
change the managed process. Run `cicall attach SESSION_ID` from the new terminal.

## Connect an MCP client

Running `cicall setup` prints a ready-to-paste configuration. A manual example:

```bash
cicall setup --client hermes --project my-app --cwd "$PWD"
```

Supported setup targets are `generic`, `hermes`, `claude`, and `codex`. Codex
can be registered automatically:

```bash
cicall setup --client codex --project my-app --cwd "$PWD" --apply
```

Check an installation at any time:

```bash
cicall doctor --fix
```

Then register the server with a fixed project scope:

```json
{
  "mcpServers": {
    "cicall": {
      "command": "/absolute/path/to/cicall-mcp",
      "args": ["--project", "my-app", "--cwd", "/absolute/path/to/my-app"]
    }
  }
}
```

The MCP server exposes:

- `list_sessions`
- `read_output`
- `send_text`
- `send_key`
- `start_session`
- `close_session`

Cicall follows the standard newline-delimited MCP stdio transport. It also
auto-detects LSP-style `Content-Length` framing for compatibility with hosts
such as HermesPet; replies use the same framing selected by the client.

An MCP server started with `--project my-app` cannot read, control, or close
sessions belonging to another project.

With `--cwd` configured, an agent can start a CLI with only its argv:

```json
{"command": ["claude"]}
```

## Configuration

| Variable | Meaning | Default |
|---|---|---|
| `CICALL_HOME` | Runtime state directory | `~/.local/state/cicall` |
| `CICALL_SOCKET` | Unix socket path | `$CICALL_HOME/cicall.sock` |
| `CICALL_PROJECT` | Default MCP project scope | current directory name |

The daemon passes `CICALL_SOCKET`, `CICALL_PROJECT`, and `CICALL_SESSION_ID` to
every managed child. An MCP client launched inside a managed session therefore
inherits the correct runtime and project automatically.

## Architecture and boundaries

Cicall deliberately separates three concerns:

1. `daemon.py` owns PTYs, process lifetime, output buffers, and the local socket.
2. `mcp.py` translates MCP tool calls into runtime operations.
3. `cli.py` is one human-facing client; it can be replaced by a GUI or web UI.

The PTY is an execution backend, not a terminal emulator. Cicall does not render
terminal output. This is what makes it independent from the terminal application.

## Roadmap

- Persist and restore session metadata across daemon restarts.
- Add task/delegation tools above the session primitives.
- Add structured activity detection and `wait_until_idle`.
- Add Docker, SSH, tmux, and remote-agent backends behind a backend interface.
- Add HTTP/SSE MCP transport with authentication for remote deployments.
- Ship signed binaries, Homebrew packaging, and Linux packages.
- Add a protocol SDK so third-party GUIs can become Cicall frontends.

## Contributing

Issues and pull requests are welcome. Keep the local runtime dependency-light,
make dangerous capabilities explicit, and preserve project isolation.

## License

MIT License. See [LICENSE](LICENSE).
