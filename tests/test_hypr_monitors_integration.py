import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsIntegration(unittest.TestCase):
    def test_panel_and_widget_structure(self):
        panel_path = os.path.join(PLUGIN_DIR, "panel.luau")
        widget_path = os.path.join(PLUGIN_DIR, "widget.luau")

        self.assertTrue(os.path.isfile(panel_path), "Missing panel.luau")
        self.assertTrue(os.path.isfile(widget_path), "Missing widget.luau")

        with open(panel_path, "r", encoding="utf-8") as f:
            panel_content = f.read()
        with open(widget_path, "r", encoding="utf-8") as f:
            widget_content = f.read()

        # Panel tests
        self.assertIn("function render()", panel_content)
        self.assertIn("state.subscribe", panel_content)
        self.assertIn("computeCanvasProjection", panel_content)
        self.assertIn("renderSafetyModal", panel_content)
        self.assertIn("writeConfig", panel_content)

        # Widget tests
        self.assertIn("barWidget.setText", widget_content)
        self.assertIn("device-desktop", widget_content)
        self.assertIn("togglePanel", widget_content)


if __name__ == "__main__":
    unittest.main()
