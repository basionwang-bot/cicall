import json
import os
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_mcp(payload: bytes) -> bytes:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(ROOT / "src")
    proc = subprocess.run(
        [sys.executable, "-m", "cicall.mcp", "--project", "测试", "--no-auto-start"],
        input=payload,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=True,
        timeout=5,
    )
    return proc.stdout


class TransportTests(unittest.TestCase):
    def test_standard_newline_transport(self):
        message = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"protocolVersion": "2024-11-05", "clientInfo": {"name": "测试", "version": "1"}},
        }
        output = run_mcp((json.dumps(message, ensure_ascii=False) + "\n").encode())
        response = json.loads(output)
        self.assertEqual(response["result"]["serverInfo"]["name"], "cicall")

    def test_content_length_compatibility_transport_with_unicode(self):
        message = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "initialize",
            "params": {"protocolVersion": "2024-11-05", "clientInfo": {"name": "中文客户端", "version": "1"}},
        }
        body = json.dumps(message, ensure_ascii=False).encode("utf-8")
        output = run_mcp(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
        header, response_body = output.split(b"\r\n\r\n", 1)
        length = int(header.split(b":", 1)[1].strip())
        self.assertEqual(length, len(response_body))
        self.assertEqual(json.loads(response_body)["id"], 2)
