import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "hypr-monitors")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestHyprMonitorsManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/hypr-monitors")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("icon"), "device-desktop")
        self.assertIn("hyprland", manifest.get("dependencies", []))

        # Verify panel
        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "floating")
        self.assertEqual(panels[0].get("position"), "center")
        self.assertEqual(panels[0].get("width"), 800)
        self.assertEqual(panels[0].get("height"), 660)
        self.assertIn("Escape", panels[0].get("capture_keys", []))

        # Verify widget
        widgets = manifest.get("widget", [])
        self.assertEqual(len(widgets), 1)
        self.assertEqual(widgets[0].get("id"), "widget")
        self.assertEqual(widgets[0].get("entry"), "widget.luau")

        # Verify translation keys for all settings
        for setting in manifest.get("setting", []):
            for key_prop in ["label_key", "description_key"]:
                if key_prop in setting:
                    k = setting[key_prop]
                    self.assertTrue(has_key_path(en, k), f"en.json missing {k}")
                    self.assertTrue(has_key_path(id_lang, k), f"id.json missing {k}")
            for opt in setting.get("options", []):
                if "label_key" in opt:
                    k = opt["label_key"]
                    self.assertTrue(has_key_path(en, k), f"en.json missing {k}")
                    self.assertTrue(has_key_path(id_lang, k), f"id.json missing {k}")


if __name__ == "__main__":
    unittest.main()
