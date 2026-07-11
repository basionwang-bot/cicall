import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from cicall.client import CicallError, request


ROOT = Path(__file__).resolve().parents[1]


class RuntimeIntegrationTests(unittest.TestCase):
    def test_start_read_and_close(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(
            os.environ,
            {"CICALL_HOME": tmp, "PYTHONPATH": str(ROOT / "src")},
            clear=False,
        ):
            env = os.environ.copy()
            daemon = subprocess.Popen(
                [sys.executable, "-m", "cicall.daemon"],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            try:
                for _ in range(50):
                    try:
                        request("ping")
                        break
                    except CicallError:
                        time.sleep(0.05)
                else:
                    self.fail("daemon did not start")
                session = request(
                    "start",
                    project="integration",
                    cwd=tmp,
                    command=["/bin/sh", "-c", "printf 'cicall-integration-ok'"],
                )
                output = ""
                for _ in range(50):
                    result = request("read", session_id=session["id"], max_bytes=8000)
                    output = result["text"]
                    if result["status"] == "exited":
                        break
                    time.sleep(0.05)
                self.assertIn("cicall-integration-ok", output)
                self.assertEqual(request("list", project="integration")[0]["id"], session["id"])
                request("close", session_id=session["id"])
            finally:
                try:
                    request("shutdown")
                except CicallError:
                    daemon.terminate()
                daemon.wait(timeout=5)
