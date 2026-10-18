import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsComponents(unittest.TestCase):
    def test_components_file_structure(self):
        comp_path = os.path.join(PLUGIN_DIR, "components.luau")
        self.assertTrue(os.path.isfile(comp_path), "Missing components.luau")
        with open(comp_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function components.renderCanvasCard", content)
        self.assertIn("function components.renderCanvasToolbar", content)
        self.assertIn("function components.renderScaleSelector", content)
        self.assertIn("function components.renderOrientationSelector", content)
        self.assertIn("function components.renderSafetyModal", content)


if __name__ == "__main__":
    unittest.main()
