from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import termios
import time
import tty
from pathlib import Path

from .client import CicallError, request
from .onboarding import CLIENTS, apply_setup, run_doctor, setup_instructions
from .paths import data_dir, log_path, socket_path


KEYS = {
    "enter": "\r",
    "escape": "\x1b",
    "tab": "\t",
    "backspace": "\x7f",
    "ctrl-c": "\x03",
    "ctrl-d": "\x04",
    "up": "\x1b[A",
    "down": "\x1b[B",
    "right": "\x1b[C",
    "left": "\x1b[D",
}


def mcp_executable() -> str:
    candidates = [
        Path(sys.argv[0]).expanduser().resolve().with_name("cicall-mcp"),
        Path(sys.executable).resolve().parent / "cicall-mcp",
    ]
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    found = shutil.which("cicall-mcp")
    if found:
        return found
    raise CicallError("cannot locate cicall-mcp; reinstall Cicall and run setup again")


def start_daemon(quiet: bool = False) -> None:
    try:
        request("ping")
        if not quiet:
            print(f"cicall daemon is already running at {socket_path()}")
        return
    except CicallError:
        pass
    data_dir().mkdir(parents=True, exist_ok=True)
    with open(log_path(), "ab", buffering=0) as log:
        subprocess.Popen(
            [sys.executable, "-m", "cicall.daemon"],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
            start_new_session=True,
            close_fds=True,
        )
    for _ in range(50):
        try:
            info = request("ping")
            if not quiet:
                print(f"started cicall daemon pid={info['pid']} socket={socket_path()}")
            return
        except CicallError:
            time.sleep(0.1)
    raise CicallError(f"daemon did not start; see {log_path()}")


def attach(session_id: str) -> None:
    cursor = 0
    old_settings = None
    last_size: tuple[int, int] | None = None
    if sys.stdin.isatty():
        old_settings = termios.tcgetattr(sys.stdin.fileno())
        tty.setraw(sys.stdin.fileno())
    try:
        while True:
            if sys.stdin.isatty():
                size = os.get_terminal_size(sys.stdin.fileno())
                current_size = (size.columns, size.lines)
                if current_size != last_size:
                    request("resize", session_id=session_id, cols=size.columns, rows=size.lines)
                    last_size = current_size
            result = request("read", session_id=session_id, after=cursor, max_bytes=262144)
            if result["text"]:
                sys.stdout.write(result["text"])
                sys.stdout.flush()
            cursor = result["cursor"]
            if result["status"] == "exited":
                break
            ready, _, _ = select.select([sys.stdin], [], [], 0.08)
            if ready:
                data = os.read(sys.stdin.fileno(), 4096)
                if not data:
                    break
                request("input", session_id=session_id, text=data.decode("utf-8", errors="replace"))
    finally:
        if old_settings is not None:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, old_settings)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="cicall", description="Run and orchestrate CLI agents from any terminal")
    sub = parser.add_subparsers(dest="action", required=True)
    daemon = sub.add_parser("daemon", help="manage the background runtime")
    daemon.add_argument("operation", choices=["start", "status", "stop", "logs"])
    setup = sub.add_parser("setup", help="start Cicall and print an MCP configuration")
    setup.add_argument("--project", default=Path.cwd().name)
    setup.add_argument("--cwd", default=str(Path.cwd()))
    setup.add_argument("--client", choices=CLIENTS, default="generic")
    setup.add_argument("--apply", action="store_true", help="register automatically when supported")
    doctor = sub.add_parser("doctor", help="diagnose the local Cicall installation")
    doctor.add_argument("--fix", action="store_true", help="start the daemon before running checks")
    doctor.add_argument("--json", action="store_true", help="print machine-readable results")

    run = sub.add_parser("run", help="start a managed CLI session")
    run.add_argument("--project", default=Path.cwd().name)
    run.add_argument("--cwd", default=str(Path.cwd()))
    run.add_argument("--detach", action="store_true")
    run.add_argument("command", nargs=argparse.REMAINDER)

    ls = sub.add_parser("list", help="list managed sessions")
    ls.add_argument("--project")
    read = sub.add_parser("read", help="read recent output")
    read.add_argument("session_id")
    read.add_argument("--max-bytes", type=int, default=8000)
    at = sub.add_parser("attach", help="interactively attach from the current terminal")
    at.add_argument("session_id")
    send = sub.add_parser("send", help="send text to a session")
    send.add_argument("session_id")
    send.add_argument("text")
    send.add_argument("--enter", action="store_true")
    key = sub.add_parser("key", help="send a special key")
    key.add_argument("session_id")
    key.add_argument("key", choices=sorted(KEYS))
    close = sub.add_parser("close", help="terminate a session")
    close.add_argument("session_id")
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        if args.action == "setup":
            start_daemon(quiet=True)
            executable = mcp_executable()
            if args.apply:
                print(apply_setup(args.client, executable, args.project, args.cwd))
            else:
                print(setup_instructions(args.client, executable, args.project, args.cwd))
            return
        if args.action == "doctor":
            if args.fix:
                start_daemon(quiet=True)
            executable = mcp_executable()
            results = run_doctor(executable)
            if args.json:
                print(json.dumps({"ok": all(item["ok"] for item in results), "checks": results}, indent=2))
            else:
                for item in results:
                    marker = "✓" if item["ok"] else "✗"
                    print(f"{marker} {item['name']}: {item['detail']}")
            if not all(item["ok"] for item in results):
                raise SystemExit(1)
            return
        if args.action == "daemon":
            if args.operation == "start":
                start_daemon()
            elif args.operation == "status":
                info = request("ping")
                print(f"running pid={info['pid']} socket={socket_path()}")
            elif args.operation == "stop":
                request("shutdown")
                print("stopping cicall daemon")
            else:
                print(log_path().read_text(errors="replace") if log_path().exists() else "(no logs)")
            return
        if args.action == "run":
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            if not command:
                raise CicallError("missing command; example: cicall run -- claude")
            size = os.get_terminal_size() if sys.stdin.isatty() else os.terminal_size((120, 40))
            info = request(
                "start",
                project=args.project,
                cwd=args.cwd,
                command=command,
                cols=size.columns,
                rows=size.lines,
            )
            print(info["id"])
            if not args.detach:
                attach(info["id"])
            return
        if args.action == "list":
            rows = request("list", project=args.project)
            for row in rows:
                command = " ".join(row["command"])
                print(f"{row['id']}\t{row['status']}\t{row['project']}\t{command}")
            return
        if args.action == "read":
            result = request("read", session_id=args.session_id, max_bytes=args.max_bytes)
            print(result["text"], end="")
            return
        if args.action == "attach":
            attach(args.session_id)
            return
        if args.action == "send":
            request("input", session_id=args.session_id, text=args.text + ("\r" if args.enter else ""))
            return
        if args.action == "key":
            request("input", session_id=args.session_id, text=KEYS[args.key])
            return
        if args.action == "close":
            request("close", session_id=args.session_id)
            return
    except CicallError as exc:
        print(f"cicall: {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
