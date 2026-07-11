from __future__ import annotations

import argparse
import errno
import fcntl
import json
import os
import pty
import selectors
import signal
import socket
import subprocess
import struct
import termios
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import __version__
from .paths import data_dir, pid_path, socket_path

MAX_SCROLLBACK = 2 * 1024 * 1024


@dataclass
class Session:
    id: str
    project: str
    cwd: str
    command: list[str]
    pid: int
    master_fd: int
    created_at: float = field(default_factory=time.time)
    exited_at: float | None = None
    exit_code: int | None = None
    output: bytearray = field(default_factory=bytearray)
    base_offset: int = 0
    total_output: int = 0

    def append(self, chunk: bytes) -> None:
        self.output.extend(chunk)
        self.total_output += len(chunk)
        overflow = len(self.output) - MAX_SCROLLBACK
        if overflow > 0:
            del self.output[:overflow]
            self.base_offset += overflow

    def info(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "project": self.project,
            "cwd": self.cwd,
            "command": self.command,
            "pid": self.pid,
            "status": "exited" if self.exited_at else "running",
            "exit_code": self.exit_code,
            "created_at": self.created_at,
            "output_cursor": self.total_output,
        }


class Runtime:
    def __init__(self) -> None:
        self.selector = selectors.DefaultSelector()
        self.sessions: dict[str, Session] = {}
        self.running = True

    def start(self, project: str, cwd: str, command: list[str], cols: int = 120, rows: int = 40) -> dict[str, Any]:
        if not command:
            raise ValueError("command must not be empty")
        workdir = str(Path(cwd).expanduser().resolve())
        if not Path(workdir).is_dir():
            raise ValueError(f"cwd does not exist: {workdir}")
        master, slave = pty.openpty()
        self.resize_fd(slave, cols, rows)
        session_id = "s-" + uuid.uuid4().hex[:12]
        env = os.environ.copy()
        env.update({
            "CICALL_SOCKET": str(socket_path()),
            "CICALL_PROJECT": project,
            "CICALL_SESSION_ID": session_id,
            "TERM": env.get("TERM", "xterm-256color"),
        })
        try:
            proc = subprocess.Popen(
                command,
                cwd=workdir,
                env=env,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                start_new_session=True,
                close_fds=True,
            )
        except Exception:
            os.close(master)
            raise
        finally:
            os.close(slave)
        os.set_blocking(master, False)
        session = Session(session_id, project, workdir, command, proc.pid, master)
        self.sessions[session_id] = session
        self.selector.register(master, selectors.EVENT_READ, ("pty", session_id))
        return session.info()

    @staticmethod
    def resize_fd(fd: int, cols: int, rows: int) -> None:
        cols = max(20, min(int(cols), 1000))
        rows = max(5, min(int(rows), 1000))
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    def stop_session(self, session: Session) -> None:
        if session.exited_at:
            return
        try:
            os.killpg(session.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    def reap(self) -> None:
        for session in self.sessions.values():
            if session.exited_at:
                continue
            try:
                pid, status = os.waitpid(session.pid, os.WNOHANG)
            except ChildProcessError:
                pid, status = session.pid, 0
            if pid:
                session.exited_at = time.time()
                session.exit_code = os.waitstatus_to_exitcode(status)

    def read_pty(self, session_id: str) -> None:
        session = self.sessions.get(session_id)
        if not session:
            return
        try:
            chunk = os.read(session.master_fd, 65536)
            if chunk:
                session.append(chunk)
                return
        except OSError as exc:
            if exc.errno not in (errno.EIO, errno.EBADF):
                raise
        try:
            self.selector.unregister(session.master_fd)
        except Exception:
            pass
        try:
            os.close(session.master_fd)
        except OSError:
            pass

    def dispatch(self, method: str, params: dict[str, Any]) -> Any:
        if method == "ping":
            return {"version": __version__, "pid": os.getpid()}
        if method == "shutdown":
            self.running = False
            return {"stopping": True}
        if method == "list":
            project = params.get("project")
            return [s.info() for s in self.sessions.values() if not project or s.project == project]
        if method == "start":
            return self.start(
                params.get("project", "default"),
                params["cwd"],
                params["command"],
                params.get("cols", 120),
                params.get("rows", 40),
            )
        session_id = params.get("session_id")
        session = self.sessions.get(session_id)
        if not session:
            raise ValueError(f"unknown session: {session_id}")
        if method == "read":
            requested = int(params.get("after", session.base_offset))
            start = max(requested, session.base_offset)
            index = start - session.base_offset
            data = bytes(session.output[index:])
            max_bytes = int(params.get("max_bytes", 65536))
            if len(data) > max_bytes:
                data = data[-max_bytes:]
            return {
                "text": data.decode("utf-8", errors="replace"),
                "cursor": session.total_output,
                "truncated": requested < session.base_offset or len(data) == max_bytes,
                "status": session.info()["status"],
            }
        if method == "input":
            if session.exited_at:
                raise ValueError("session has exited")
            os.write(session.master_fd, params.get("text", "").encode())
            return {"sent": True}
        if method == "resize":
            if session.exited_at:
                raise ValueError("session has exited")
            self.resize_fd(session.master_fd, params.get("cols", 120), params.get("rows", 40))
            return {"resized": True}
        if method == "close":
            self.stop_session(session)
            return {"closed": True}
        raise ValueError(f"unknown method: {method}")


def serve(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lock = open(str(path) + ".lock", "a+")
    try:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as exc:
        lock.close()
        raise RuntimeError(f"another cicall daemon owns {path}") from exc
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    os.chmod(path, 0o600)
    server.listen(64)
    server.setblocking(False)
    runtime = Runtime()
    runtime.selector.register(server, selectors.EVENT_READ, ("server", None))
    pid_path().write_text(str(os.getpid()))

    def stop(_signum: int, _frame: Any) -> None:
        runtime.running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while runtime.running:
            for key, _ in runtime.selector.select(timeout=0.2):
                kind, value = key.data
                if kind == "pty":
                    runtime.read_pty(value)
                    continue
                conn, _ = server.accept()
                with conn:
                    conn.settimeout(5)
                    try:
                        line = conn.makefile("rb").readline()
                        message = json.loads(line)
                        result = runtime.dispatch(message["method"], message.get("params", {}))
                        response = {"ok": True, "result": result}
                    except Exception as exc:
                        response = {"ok": False, "error": str(exc)}
                    conn.sendall((json.dumps(response, separators=(",", ":")) + "\n").encode())
            runtime.reap()
    finally:
        for session in runtime.sessions.values():
            runtime.stop_session(session)
        server.close()
        path.unlink(missing_ok=True)
        pid_path().unlink(missing_ok=True)
        lock.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Cicall background runtime")
    parser.add_argument("--socket", help="override the Unix socket path")
    args = parser.parse_args()
    if args.socket:
        os.environ["CICALL_SOCKET"] = args.socket
    data_dir().mkdir(parents=True, exist_ok=True)
    serve(socket_path())


if __name__ == "__main__":
    main()
