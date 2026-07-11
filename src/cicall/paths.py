from __future__ import annotations

import os
from pathlib import Path


def data_dir() -> Path:
    override = os.environ.get("CICALL_HOME")
    if override:
        return Path(override).expanduser()
    xdg = os.environ.get("XDG_STATE_HOME")
    if xdg:
        return Path(xdg).expanduser() / "cicall"
    return Path.home() / ".local" / "state" / "cicall"


def socket_path() -> Path:
    return Path(os.environ.get("CICALL_SOCKET", data_dir() / "cicall.sock")).expanduser()


def pid_path() -> Path:
    return data_dir() / "cicall.pid"


def log_path() -> Path:
    return data_dir() / "cicall.log"
