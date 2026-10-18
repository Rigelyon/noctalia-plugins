import json
import os
import re
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "sleepy-time")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestSleepyTimeManifestAndConfig(unittest.TestCase):
    def setUp(self):
        self.manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        self.en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        self.id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(self.manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(self.en_path), "Missing translations/en.json")

        with open(self.manifest_path, "rb") as f:
            self.manifest = tomllib.load(f)
        with open(self.en_path, "r", encoding="utf-8") as f:
            self.en = json.load(f)

    def test_basic_plugin_metadata(self):
        self.assertEqual(self.manifest.get("id"), "rigelyon/sleepy-time")
        self.assertEqual(self.manifest.get("name"), "Sleepy Time")
        self.assertEqual(self.manifest.get("author"), "rigelyon")
        self.assertEqual(self.manifest.get("license"), "MIT")

        # Check entries exist
        services = self.manifest.get("service", [])
        self.assertEqual(len(services), 1)
        self.assertEqual(services[0].get("id"), "service")
        self.assertEqual(services[0].get("entry"), "service.luau")

        widgets = self.manifest.get("widget", [])
        self.assertEqual(len(widgets), 1)
        self.assertEqual(widgets[0].get("id"), "widget")

        panels = self.manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")

        desktop_widgets = self.manifest.get("desktop_widget", [])
        self.assertEqual(len(desktop_widgets), 1)
        self.assertEqual(desktop_widgets[0].get("id"), "desktop")

    def test_actions_include_screen_off_and_lock(self):
        settings = self.manifest.get("setting", [])
        default_action_setting = next(
            (s for s in settings if s.get("key") == "default_action"), None
        )
        self.assertIsNotNone(default_action_setting)
        options = default_action_setting.get("options", [])
        option_values = [opt["value"] for opt in options]

        self.assertIn("lock", option_values)
        self.assertIn("screen-off", option_values)
        self.assertIn("media-control", option_values)
        self.assertIn("suspend", option_values)
        self.assertIn("shutdown", option_values)
        self.assertIn("reboot", option_values)
        self.assertIn("logout", option_values)
        self.assertIn("kill-process", option_values)
        self.assertIn("custom-command", option_values)

    def test_media_command_settings_exist(self):
        settings = self.manifest.get("setting", [])
        pause_setting = next(
            (s for s in settings if s.get("key") == "media_pause_command"), None
        )
        stop_setting = next(
            (s for s in settings if s.get("key") == "media_stop_command"), None
        )
        self.assertIsNotNone(pause_setting, "Missing media_pause_command setting in plugin.toml")
        self.assertIsNotNone(stop_setting, "Missing media_stop_command setting in plugin.toml")
        self.assertEqual(pause_setting.get("type"), "string")
        self.assertEqual(stop_setting.get("type"), "string")

    def test_inhibit_idle_setting_exists(self):
        settings = self.manifest.get("setting", [])
        inhibit_setting = next(
            (s for s in settings if s.get("key") == "inhibit_idle"), None
        )
        self.assertIsNotNone(inhibit_setting, "Missing inhibit_idle setting in plugin.toml")
        self.assertEqual(inhibit_setting.get("type"), "bool")
        self.assertEqual(inhibit_setting.get("default"), True)

    def test_translations_coverage(self):
        # All manifest setting label/description keys must exist in en.json
        all_settings = list(self.manifest.get("setting", []))
        for w in self.manifest.get("widget", []):
            all_settings.extend(w.get("setting", []))
        for d in self.manifest.get("desktop_widget", []):
            all_settings.extend(d.get("setting", []))

        for setting in all_settings:
            if "label_key" in setting:
                self.assertTrue(
                    has_key_path(self.en, setting["label_key"]),
                    f"Missing label_key in en.json: {setting['label_key']}",
                )
            if "description_key" in setting:
                self.assertTrue(
                    has_key_path(self.en, setting["description_key"]),
                    f"Missing description_key in en.json: {setting['description_key']}",
                )
            for opt in setting.get("options", []):
                if "label_key" in opt:
                    self.assertTrue(
                        has_key_path(self.en, opt["label_key"]),
                        f"Missing option label_key in en.json: {opt['label_key']}",
                    )

        # Check action labels in en.json
        expected_actions = [
            "lock",
            "screen-off",
            "media-control",
            "suspend",
            "shutdown",
            "reboot",
            "logout",
            "kill-process",
            "custom-command",
        ]
        for act in expected_actions:
            self.assertIn(act, self.en.get("action", {}), f"Missing action.{act} in en.json")

        self.assertIn("media-pause", self.en.get("action", {}), "Missing action.media-pause in en.json")
        self.assertIn("media-stop", self.en.get("action", {}), "Missing action.media-stop in en.json")

    def test_indonesian_translation_coverage(self):
        self.assertTrue(os.path.isfile(self.id_path), "Missing translations/id.json")
        with open(self.id_path, "r", encoding="utf-8") as f:
            id_trans = json.load(f)

        expected_actions = [
            "lock",
            "screen-off",
            "media-control",
            "suspend",
            "shutdown",
            "reboot",
            "logout",
            "kill-process",
            "custom-command",
        ]
        for act in expected_actions:
            self.assertIn(act, id_trans.get("action", {}), f"Missing action.{act} in id.json")

        self.assertIn("media-pause", id_trans.get("action", {}), "Missing action.media-pause in id.json")
        self.assertIn("media-stop", id_trans.get("action", {}), "Missing action.media-stop in id.json")


class TestSleepyTimeServiceLogic(unittest.TestCase):
    def setUp(self):
        self.service_path = os.path.join(PLUGIN_DIR, "service.luau")
        self.panel_path = os.path.join(PLUGIN_DIR, "panel.luau")
        self.widget_path = os.path.join(PLUGIN_DIR, "widget.luau")
        self.assertTrue(os.path.isfile(self.service_path), "Missing service.luau")
        self.assertTrue(os.path.isfile(self.panel_path), "Missing panel.luau")
        self.assertTrue(os.path.isfile(self.widget_path), "Missing widget.luau")
        with open(self.service_path, "r", encoding="utf-8") as f:
            self.service_code = f.read()
        with open(self.panel_path, "r", encoding="utf-8") as f:
            self.panel_code = f.read()
        with open(self.widget_path, "r", encoding="utf-8") as f:
            self.widget_code = f.read()

    def test_uses_wall_clock_timestamp_for_countdown(self):
        # Must not rely purely on remaining = remaining - 1 without wall-clock anchoring
        self.assertIn("targetEndTime", self.service_code, "service.luau must use targetEndTime for wall-clock tracking")
        self.assertIn("os.time()", self.service_code, "service.luau must reference os.time() for real wall-clock tracking")

    def test_noctalia_session_lock_fallback(self):
        # Lock command must include noctalia msg session lock
        self.assertIn("noctalia msg session lock", self.service_code, "Lock command must include noctalia msg session lock")

    def test_screen_off_action_handled(self):
        self.assertIn("screen-off", self.service_code, "service.luau must handle screen-off action")
        self.assertIn("hl.dsp.dpms", self.service_code, "Screen off command must support hyprland dpms")

    def test_media_control_action_handled(self):
        self.assertIn("media-control", self.service_code, "service.luau must handle media-control action")
        self.assertIn("playerctl", self.service_code, "service.luau should use playerctl for media control")
        self.assertIn("noctalia msg media", self.service_code, "service.luau should support noctalia media IPC fallback")

    def test_panel_has_media_control_and_options(self):
        self.assertIn('"media-control"', self.panel_code, "panel.luau must include media-control in ACTIONS")
        self.assertIn("mediaSubAction", self.panel_code, "panel.luau must have mediaSubAction state for pause vs stop")

    def test_widget_has_media_control_glyph(self):
        self.assertIn('"media-control"', self.widget_code, "widget.luau must handle media-control glyph")

    def test_caffeine_idle_inhibition_supported(self):
        self.assertIn("caffeine-enable", self.service_code, "service.luau must enable caffeine when timer runs")
        self.assertIn("caffeine-disable", self.service_code, "service.luau must disable caffeine when timer stops")

    def test_ipc_implemented(self):
        self.assertIn("function onIpc(", self.service_code, "service.luau must implement onIpc")


if __name__ == "__main__":
    unittest.main()

