from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from . import __version__
from .client import CicallError, request
from .cli import KEYS, start_daemon


TOOLS = [
    {
        "name": "list_sessions",
        "description": "List CLI sessions in this Cicall project.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "read_output",
        "description": "Read the recent output of a managed CLI session.",
        "inputSchema": {
            "type": "object",
            "properties": {"session_id": {"type": "string"}, "max_bytes": {"type": "integer", "default": 8000}},
            "required": ["session_id"],
            "additionalProperties": False,
        },
    },
    {
        "name": "send_text",
        "description": "Type text into a session. Set submit=true to append Enter.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "session_id": {"type": "string"},
                "text": {"type": "string"},
                "submit": {"type": "boolean", "default": False},
            },
            "required": ["session_id", "text"],
            "additionalProperties": False,
        },
    },
    {
        "name": "send_key",
        "description": "Send a special key such as enter, escape, arrows, or ctrl-c.",
        "inputSchema": {
            "type": "object",
            "properties": {"session_id": {"type": "string"}, "key": {"type": "string", "enum": sorted(KEYS)}},
            "required": ["session_id", "key"],
            "additionalProperties": False,
        },
    },
    {
        "name": "start_session",
        "description": "Start any CLI program in a managed PTY in this project. cwd defaults to the MCP server's configured working directory. Returns only the new session id for easy follow-up calls.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "cwd": {"type": "string"},
                "command": {"type": "array", "items": {"type": "string"}, "minItems": 1},
                "cols": {"type": "integer", "default": 120, "minimum": 20},
                "rows": {"type": "integer", "default": 40, "minimum": 5},
            },
            "required": ["command"],
            "additionalProperties": False,
        },
    },
    {
        "name": "close_session",
        "description": "Terminate a managed CLI session in this project.",
        "inputSchema": {
            "type": "object",
            "properties": {"session_id": {"type": "string"}},
            "required": ["session_id"],
            "additionalProperties": False,
        },
    },
]


SUPPORTED_PROTOCOL_VERSIONS = {"2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"}
LATEST_PROTOCOL_VERSION = "2025-11-25"


class Server:
    def __init__(self, project: str, cwd: str) -> None:
        self.project = project
        self.cwd = str(Path(cwd).expanduser().resolve())

    def session(self, session_id: str) -> dict[str, Any]:
        sessions = request("list", project=self.project)
        found = next((row for row in sessions if row["id"] == session_id), None)
        if not found:
            raise CicallError(f"session {session_id} is outside project scope or does not exist")
        return found

    def call(self, name: str, args: dict[str, Any]) -> str:
        if name == "list_sessions":
            return json.dumps(request("list", project=self.project), indent=2, ensure_ascii=False)
        if name == "start_session":
            result = request(
                "start",
                project=self.project,
                cwd=args.get("cwd", self.cwd),
                command=args["command"],
                cols=args.get("cols", 120),
                rows=args.get("rows", 40),
            )
            return result["id"]
        session_id = args.get("session_id", "")
        self.session(session_id)
        if name == "read_output":
            return request("read", session_id=session_id, max_bytes=args.get("max_bytes", 8000))["text"]
        if name == "send_text":
            text = args["text"] + ("\r" if args.get("submit") else "")
            request("input", session_id=session_id, text=text)
            return f"sent {len(args['text'])} characters to {session_id}"
        if name == "send_key":
            key = args["key"]
            if key not in KEYS:
                raise CicallError(f"unknown key: {key}")
            request("input", session_id=session_id, text=KEYS[key])
            return f"sent {key} to {session_id}"
        if name == "close_session":
            request("close", session_id=session_id)
            return f"closed {session_id}"
        raise CicallError(f"unknown tool: {name}")


def emit(message: dict[str, Any], transport: str) -> None:
    body = json.dumps(message, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if transport == "content-length":
        payload = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii") + body
    else:
        payload = body + b"\n"
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def _read_message() -> tuple[dict[str, Any], str] | None:
    """Read standard newline MCP or legacy Content-Length framing.

    MCP's stdio specification uses one JSON-RPC message per line. Some hosts,
    including HermesPet versions in the wild, use LSP-style Content-Length
    framing. Detect the first bytes and reply using the client's framing.
    """
    first = sys.stdin.buffer.readline()
    if not first:
        return None
    if first.lower().startswith(b"content-length:"):
        headers: dict[str, str] = {}
        line = first
        while line not in (b"\r\n", b"\n", b""):
            key, separator, value = line.decode("ascii", errors="strict").partition(":")
            if separator:
                headers[key.strip().lower()] = value.strip()
            line = sys.stdin.buffer.readline()
        length = int(headers.get("content-length", "0"))
        if length <= 0:
            raise ValueError("missing or invalid Content-Length")
        data = sys.stdin.buffer.read(length)
        if len(data) != length:
            raise ValueError("unexpected EOF in Content-Length message")
        return json.loads(data.decode("utf-8")), "content-length"
    return json.loads(first.decode("utf-8")), "newline"


def main() -> None:
    parser = argparse.ArgumentParser(description="Cicall MCP server")
    parser.add_argument("--project", default=os.environ.get("CICALL_PROJECT", Path.cwd().name))
    parser.add_argument("--cwd", default=str(Path.cwd()), help="default working directory for start_session")
    parser.add_argument("--no-auto-start", action="store_true", help="fail instead of starting the local daemon")
    args = parser.parse_args()
    if not args.no_auto_start:
        try:
            start_daemon(quiet=True)
        except CicallError as exc:
            print(f"cicall-mcp: {exc}", file=sys.stderr)
    server = Server(args.project, args.cwd)
    transport = "newline"
    while True:
        try:
            framed = _read_message()
            if framed is None:
                break
            message, transport = framed
            request_id = message.get("id")
            method = message.get("method")
            if method == "initialize":
                requested_version = message.get("params", {}).get("protocolVersion")
                negotiated_version = (
                    requested_version if requested_version in SUPPORTED_PROTOCOL_VERSIONS else LATEST_PROTOCOL_VERSION
                )
                result = {
                    "protocolVersion": negotiated_version,
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "cicall", "version": __version__},
                    "instructions": "Use start_session to launch a CLI, then use its returned session id with read_output, send_text, send_key, or close_session.",
                }
            elif method == "notifications/initialized":
                continue
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                params = message.get("params", {})
                try:
                    text = server.call(params.get("name", ""), params.get("arguments", {}))
                    result = {"content": [{"type": "text", "text": text}], "isError": False}
                except (CicallError, KeyError, ValueError) as exc:
                    result = {"content": [{"type": "text", "text": str(exc)}], "isError": True}
            else:
                if request_id is not None:
                    emit({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": "method not found"}}, transport)
                continue
            if request_id is not None:
                emit({"jsonrpc": "2.0", "id": request_id, "result": result}, transport)
        except Exception as exc:
            emit({"jsonrpc": "2.0", "id": None, "error": {"code": -32603, "message": str(exc)}}, transport)


if __name__ == "__main__":
    main()
