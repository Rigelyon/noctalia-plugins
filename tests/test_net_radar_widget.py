import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")
WIDGET_FILE = os.path.join(PLUGIN_DIR, "widget.luau")


class TestNetRadarWidget(unittest.TestCase):
    def test_widget_file_exists(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "Missing widget.luau")

    def test_widget_declarative_render_and_progress_bar(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use declarative barWidget.render
        self.assertIn("barWidget.render", content)
        # Must render single dedicated logo glyph "radar"
        self.assertIn('"radar"', content)
        # Must NOT use confusing wifi fan glyphs on the bar widget
        self.assertNotIn('"wifi-2"', content)
        self.assertNotIn('"wifi-off"', content)
        # Must render vertical progress bar matching Noctalia system monitor
        self.assertIn("ui.progress", content)
        self.assertIn("width = 6", content)
        self.assertIn("height = 14", content)
        self.assertIn("radius = 3", content)
        # Must register tooltip
        self.assertIn("barWidget.setTooltip", content)

    def test_widget_status_colors_and_progress(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Status progress levels
        self.assertIn("1.0", content)  # OPTIMAL
        self.assertIn("0.6", content)  # FAIR
        self.assertIn("0.25", content) # POOR / CAPTIVE
        self.assertIn("0.0", content)  # OFFLINE

        # Color roles (Noctalia MD3 palette)
        self.assertIn('"primary"', content)
        self.assertIn('"tertiary"', content)
        self.assertIn('"error"', content)
        self.assertIn('"outline"', content)

    def test_widget_dirty_checking(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Dirty check variables and conditional update
        self.assertIn("lastRenderedStatus", content)
        self.assertIn("barWidget.render", content)

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

    def test_widget_probe_timeout_accounting(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Must record timed-out probes as dropped samples
        self.assertIn('state.processProbe("none|none|none|none|0|0|0")', content)

    def test_widget_config_sync_and_notifications(self):
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("state.syncConfig()", content)
        self.assertIn("function onConfigChanged()", content)
        self.assertIn("enable_loss_desktop_notification", content)
        self.assertIn("noctalia.notify", content)
        self.assertIn("packet_loss_alert_threshold", content)


if __name__ == "__main__":
    unittest.main()
