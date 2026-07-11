import unittest

from cicall.cli import KEYS
from cicall.mcp import TOOLS


class MCPTests(unittest.TestCase):
    def test_tool_names_are_unique(self):
        names = [tool["name"] for tool in TOOLS]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(names, [
            "list_sessions",
            "read_output",
            "send_text",
            "send_key",
            "start_session",
            "close_session",
        ])

    def test_expected_control_keys_exist(self):
        self.assertEqual(KEYS["enter"], "\r")
        self.assertEqual(KEYS["ctrl-c"], "\x03")
