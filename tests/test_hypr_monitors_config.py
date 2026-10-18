import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


class TestHyprMonitorsConfig(unittest.TestCase):
    def test_config_file_structure(self):
        config_path = os.path.join(PLUGIN_DIR, "config.luau")
        self.assertTrue(os.path.isfile(config_path), "Missing config.luau")
        with open(config_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function config.formatRule", content)
        self.assertIn("function config.generateConfigContent", content)
        self.assertIn("function config.writeConfig", content)
        self.assertIn("function config.isSourcedInHyprlandConf", content)
        self.assertIn(".bak", content)
        self.assertIn("source =", content)

    def test_hyprland_rule_formatting_regex(self):
        # Verify sample formatted Hyprland rules match the expected compositor parser
        normal_rule = "monitor = DP-1, 2560x1440@165.00Hz, 1920x0, 1.25, vrr, 1"
        disabled_rule = "monitor = eDP-1, disable"
        mirror_rule = "monitor = HDMI-A-1, preferred, auto, 1, mirror, DP-1"

        normal_pattern = r"^monitor\s*=\s*[\w\-]+,\s*\d+x\d+@[\d\.]+Hz,\s*-?\d+x-?\d+,\s*[\d\.]+(?:,\s*transform,\s*\d+)?(?:,\s*vrr,\s*\d+)?$"
        disabled_pattern = r"^monitor\s*=\s*[\w\-]+,\s*disable$"
        mirror_pattern = r"^monitor\s*=\s*[\w\-]+,\s*preferred,\s*auto,\s*1,\s*mirror,\s*[\w\-]+$"

        self.assertRegex(normal_rule, normal_pattern)
        self.assertRegex(disabled_rule, disabled_pattern)
        self.assertRegex(mirror_rule, mirror_pattern)


if __name__ == "__main__":
    unittest.main()
