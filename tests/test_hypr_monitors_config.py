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
        self.assertIn("hypr-monitors.lua", content)
        self.assertIn(".bak", content)
        self.assertIn("hl.monitor", content)

    def test_hyprland_lua_rule_formatting_regex(self):
        # Sample Lua rule outputs for Hyprland 0.56+
        normal_lua = (
            'hl.monitor({\n'
            '    output   = "DP-1",\n'
            '    mode     = "2560x1440@165.00",\n'
            '    position = "1920x0",\n'
            '    scale    = 1.25,\n'
            '    vrr      = 1,\n'
            '})'
        )
        disabled_lua = (
            'hl.monitor({\n'
            '    output   = "eDP-1",\n'
            '    disabled = true,\n'
            '})'
        )
        mirror_lua = (
            'hl.monitor({\n'
            '    output   = "HDMI-A-1",\n'
            '    mode     = "1920x1080@60.00",\n'
            '    position = "0x0",\n'
            '    scale    = 1,\n'
            '    mirror   = "DP-1",\n'
            '})'
        )

        self.assertIn('output   = "DP-1"', normal_lua)
        self.assertIn('mode     = "2560x1440@165.00"', normal_lua)
        self.assertIn('disabled = true', disabled_lua)
        self.assertIn('mirror   = "DP-1"', mirror_lua)


if __name__ == "__main__":
    unittest.main()
