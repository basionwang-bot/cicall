from __future__ import annotations

import json
import os
import shlex
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from . import __version__
from .client import CicallError, request
from .paths import data_dir, socket_path


CLIENTS = ("generic", "hermes", "claude", "codex")


def server_args(project: str, cwd: str) -> list[str]:
    return ["--project", project, "--cwd", str(Path(cwd).expanduser().resolve())]


def json_config(executable: str, project: str, cwd: str) -> str:
    return json.dumps(
        {
            "mcpServers": {
                "cicall": {
                    "command": executable,
                    "args": server_args(project, cwd),
                }
            }
        },
        indent=2,
        ensure_ascii=False,
    )


def codex_command(executable: str, project: str, cwd: str) -> list[str]:
    return ["codex", "mcp", "add", "cicall", "--", executable, *server_args(project, cwd)]


def codex_toml(executable: str, project: str, cwd: str) -> str:
    args = ", ".join(json.dumps(item, ensure_ascii=False) for item in server_args(project, cwd))
    return "\n".join(
        [
            "[mcp_servers.cicall]",
            f"command = {json.dumps(executable, ensure_ascii=False)}",
            f"args = [{args}]",
            "startup_timeout_sec = 15",
            "tool_timeout_sec = 120",
        ]
    )


def setup_instructions(client: str, executable: str, project: str, cwd: str) -> str:
    if client == "codex":
        command = shlex.join(codex_command(executable, project, cwd))
        return (
            "Cicall is ready. Register it with Codex using:\n\n"
            f"{command}\n\n"
            "Or add this block to ~/.codex/config.toml:\n\n"
            f"{codex_toml(executable, project, cwd)}"
        )
    label = {"hermes": "HermesPet", "claude": "Claude-compatible", "generic": "your MCP client"}[client]
    return f"Cicall is ready. Add this server to {label}:\n\n{json_config(executable, project, cwd)}"


def apply_setup(client: str, executable: str, project: str, cwd: str) -> str:
    if client != "codex":
        raise CicallError(f"automatic setup is not available for {client}; copy the generated JSON instead")
    command = codex_command(executable, project, cwd)
    try:
        completed = subprocess.run(command, text=True, capture_output=True, timeout=30)
    except FileNotFoundError as exc:
        raise CicallError("Codex CLI is not installed or is not on PATH") from exc
    except subprocess.TimeoutExpired as exc:
        raise CicallError("Codex MCP registration timed out") from exc
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise CicallError(f"Codex MCP registration failed: {detail}")
    return (completed.stdout or "Cicall was registered with Codex.").strip()


def _check(name: str, action: Any) -> dict[str, Any]:
    try:
        detail = action()
        return {"name": name, "ok": True, "detail": str(detail)}
    except Exception as exc:
        return {"name": name, "ok": False, "detail": str(exc)}


def run_doctor(executable: str) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    checks.append(
        _check(
            "platform",
            lambda: f"{sys.platform} (supported)" if os.name == "posix" else (_ for _ in ()).throw(RuntimeError("Cicall requires macOS or Linux")),
        )
    )
    checks.append(
        _check(
            "python",
            lambda: f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
            if sys.version_info >= (3, 9)
            else (_ for _ in ()).throw(RuntimeError("Python 3.9 or newer is required")),
        )
    )
    checks.append(
        _check(
            "mcp executable",
            lambda: executable if Path(executable).is_file() and os.access(executable, os.X_OK) else (_ for _ in ()).throw(RuntimeError(f"not executable: {executable}")),
        )
    )

    def writable_state() -> str:
        data_dir().mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=data_dir()):
            pass
        return str(data_dir())

    checks.append(_check("state directory", writable_state))
    checks.append(_check("daemon", lambda: f"pid={request('ping')['pid']} version={request('ping')['version']}"))

    def secure_socket() -> str:
        path = socket_path()
        mode = stat.S_IMODE(path.stat().st_mode)
        if mode & 0o077:
            raise RuntimeError(f"unsafe permissions {oct(mode)} on {path}; expected 0o600")
        return f"{path} mode={oct(mode)}"

    checks.append(_check("socket permissions", secure_socket))

    def handshake() -> str:
        message = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "cicall-doctor", "version": __version__},
            },
        }
        completed = subprocess.run(
            [executable, "--project", "cicall-doctor", "--no-auto-start"],
            input=(json.dumps(message, separators=(",", ":")) + "\n").encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
        )
        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.decode(errors="replace").strip() or "MCP process failed")
        response = json.loads(completed.stdout)
        if response.get("result", {}).get("serverInfo", {}).get("name") != "cicall":
            raise RuntimeError("invalid MCP initialize response")
        return f"MCP {response['result']['protocolVersion']}"

    checks.append(_check("MCP handshake", handshake))
    return checks
