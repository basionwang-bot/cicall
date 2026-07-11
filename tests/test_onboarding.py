import json
import unittest
from pathlib import Path

from cicall.onboarding import codex_command, codex_toml, json_config, setup_instructions


class OnboardingTests(unittest.TestCase):
    def test_generic_json_config_is_ready_to_paste(self):
        config = json.loads(json_config("/tmp/bin/cicall-mcp", "demo", "/tmp/project"))
        server = config["mcpServers"]["cicall"]
        self.assertEqual(server["command"], "/tmp/bin/cicall-mcp")
        self.assertEqual(server["args"], ["--project", "demo", "--cwd", str(Path("/tmp/project").resolve())])

    def test_codex_cli_registration_uses_stdio_separator(self):
        command = codex_command("/tmp/bin/cicall-mcp", "demo", "/tmp/project")
        self.assertEqual(command[:5], ["codex", "mcp", "add", "cicall", "--"])
        self.assertEqual(command[5], "/tmp/bin/cicall-mcp")

    def test_codex_toml_uses_official_server_table(self):
        config = codex_toml("/tmp/bin/cicall-mcp", "demo", "/tmp/project")
        self.assertIn("[mcp_servers.cicall]", config)
        self.assertIn('command = "/tmp/bin/cicall-mcp"', config)

    def test_hermes_instructions_name_the_client(self):
        output = setup_instructions("hermes", "/tmp/bin/cicall-mcp", "demo", "/tmp/project")
        self.assertIn("HermesPet", output)
