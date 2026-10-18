import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsIPC(unittest.TestCase):
    def test_ipc_file_structure(self):
        hypr_path = os.path.join(PLUGIN_DIR, "hypr.luau")
        self.assertTrue(os.path.isfile(hypr_path), "Missing hypr.luau")
        with open(hypr_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function hypr.init", content)
        self.assertIn("function hypr.refreshMonitors", content)
        self.assertIn("function hypr.applyLive", content)
        self.assertIn("function hypr.applyBatch", content)
        self.assertIn("hyprctl monitors all -j", content)
        self.assertIn("keyword monitor", content)
        self.assertIn("socket2.sock", content)


if __name__ == "__main__":
    unittest.main()
