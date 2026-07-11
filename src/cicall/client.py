from __future__ import annotations

import json
import socket
from typing import Any

from .paths import socket_path


class CicallError(RuntimeError):
    pass


def request(method: str, **params: Any) -> Any:
    path = str(socket_path())
    payload = json.dumps({"method": method, "params": params}, separators=(",", ":")) + "\n"
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(5)
            sock.connect(path)
            sock.sendall(payload.encode())
            stream = sock.makefile("rb")
            line = stream.readline()
    except OSError as exc:
        raise CicallError(f"cannot reach cicall daemon at {path}: {exc}") from exc
    if not line:
        raise CicallError("daemon closed the connection without a response")
    response = json.loads(line)
    if not response.get("ok"):
        raise CicallError(response.get("error", "unknown daemon error"))
    return response.get("result")
