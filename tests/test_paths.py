import os
import tempfile
import unittest
from unittest.mock import patch

from cicall.paths import data_dir, socket_path


class PathTests(unittest.TestCase):
    def test_home_override(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(
            os.environ, {"CICALL_HOME": tmp}, clear=True
        ):
            self.assertEqual(str(data_dir()), tmp)
            self.assertEqual(str(socket_path()), f"{tmp}/cicall.sock")
