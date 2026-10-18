import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsState(unittest.TestCase):
    def test_state_file_structure(self):
        state_path = os.path.join(PLUGIN_DIR, "state.luau")
        self.assertTrue(os.path.isfile(state_path), "Missing state.luau")
        with open(state_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function state.subscribe", content)
        self.assertIn("function state.notify", content)
        self.assertIn("function state.selectMonitor", content)
        self.assertIn("function state.setWorkingProperty", content)
        self.assertIn("function state.startSafetyCountdown", content)
        self.assertIn("function state.keepChanges", content)
        self.assertIn("function state.revertToSafe", content)


if __name__ == "__main__":
    unittest.main()
