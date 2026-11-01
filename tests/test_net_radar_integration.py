import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "net-radar")


class TestNetRadarIntegration(unittest.TestCase):
    def test_complete_plugin_structure(self):
        required_files = [
            "plugin.toml",
            "widget.luau",
            "panel.luau",
            "state.luau",
            "presets.luau",
            "probe.sh",
            "README.md",
            "thumbnail.webp",
            "translations/en.json",
            "translations/id.json",
        ]
        for f in required_files:
            p = os.path.join(PLUGIN_DIR, f)
            self.assertTrue(os.path.isfile(p), f"Missing required file: {f}")

    def test_readme_mentions_dependencies_and_usage(self):
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("NetRadar", content)
        self.assertIn("ping", content)
        self.assertIn("nmcli", content)


if __name__ == "__main__":
    unittest.main()
