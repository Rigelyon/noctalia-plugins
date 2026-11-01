import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
WIDGET_FILE = os.path.join(PLUGIN_DIR, "widget.luau")


class TestNetRadarWidget(unittest.TestCase):
    def test_widget_file_exists(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "Missing widget.luau")

    def test_widget_contains_icon_only_check(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must inspect show_text_in_bar config
        self.assertIn("show_text_in_bar", content)
        # Must call barWidget.setGlyph
        self.assertIn("barWidget.setGlyph", content)
        # Must support setting empty text for icon-only mode
        self.assertIn('barWidget.setText("")', content)
        # Must register tooltip
        self.assertIn("barWidget.setTooltip", content)

    def test_widget_status_glyphs_and_colors(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Glyphs for statuses
        self.assertIn("device-gamepad", content)
        self.assertIn("wifi-2", content)
        self.assertIn("alert-triangle", content)
        self.assertIn("wifi-off", content)
        self.assertIn("login", content)

        # Color roles
        self.assertIn('"primary"', content)
        self.assertIn('"warning"', content)
        self.assertIn('"destructive"', content)
        self.assertIn('"outline"', content)

    def test_widget_dirty_checking(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Dirty check variables and conditional update
        self.assertIn("lastRenderedGlyph", content)
        self.assertIn("lastRenderedStatus", content)
        self.assertIn("barWidget.setGlyphColor", content)

    def test_widget_adaptive_polling_and_backoff(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Polling intervals and offline backoff
        self.assertIn("idle_poll_interval_sec", content)
        self.assertIn("OFFLINE", content)
        self.assertIn("10000", content)
        self.assertIn("executeProbe", content)
        self.assertIn("function update(", content)

    def test_widget_panel_toggle_and_state_subscription(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("state.subscribe", content)
        self.assertIn("function onClick()", content)
        self.assertIn("rigelyon/net-radar:panel", content)


if __name__ == "__main__":
    unittest.main()
