import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-layout")


class TestHyprLayoutIPC(unittest.TestCase):
    def test_ipc_file_structure(self):
        hypr_path = os.path.join(PLUGIN_DIR, "hypr.luau")
        self.assertTrue(os.path.isfile(hypr_path), "Missing hypr.luau")
        with open(hypr_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function hypr.init", content)
        self.assertIn("function hypr.refresh", content)
        self.assertIn("function hypr.setLayout", content)
        self.assertIn("function hypr.resetWorkspaceToGlobal", content)
        self.assertIn("function hypr.dispatchSubAction", content)
        self.assertIn("socket2.sock", content)
        self.assertIn("hl.config", content)
        self.assertIn("hl.workspace_rule", content)
        self.assertIn("tiledLayout", content)


if __name__ == "__main__":
    unittest.main()
