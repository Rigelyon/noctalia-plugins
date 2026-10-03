import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestAiSidebarManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")
        self.assertTrue(os.path.isfile(readme_path), "Missing README.md")
        self.assertTrue(os.path.isfile(thumb_path), "Missing thumbnail.webp")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/ai-sidebar")
        self.assertEqual(manifest.get("name"), "AI Sidebar")
        self.assertEqual(manifest.get("version"), "1.0.0")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("license"), "MIT")
        self.assertEqual(manifest.get("icon"), "sparkles")
        self.assertEqual(
            manifest.get("tags"), ["ai", "productivity", "utility", "panel", "bar"]
        )

        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "floating")
        self.assertEqual(panels[0].get("position"), "center_right")
        self.assertEqual(panels[0].get("width"), 440)
        self.assertEqual(panels[0].get("height"), "fill")

        widgets = manifest.get("widget", [])
        self.assertGreaterEqual(len(widgets), 1)
        widget_ids = [w.get("id") for w in widgets]
        self.assertIn("ai-sidebar", widget_ids)
        self.assertIn("bar_widget", widget_ids)

        # Verify settings schema and keys in en and id
        settings = manifest.get("setting", [])
        self.assertGreaterEqual(len(settings), 5)
        for s in settings:
            self.assertIn(s.get("type"), ["bool", "string", "folder", "glyph", "select"])
            if "label_key" in s:
                self.assertTrue(has_key_path(en, s["label_key"]), f"en missing {s['label_key']}")
                self.assertTrue(has_key_path(id_lang, s["label_key"]), f"id missing {s['label_key']}")
            if "description_key" in s:
                self.assertTrue(has_key_path(en, s["description_key"]), f"en missing {s['description_key']}")
                self.assertTrue(has_key_path(id_lang, s["description_key"]), f"id missing {s['description_key']}")
            for opt in s.get("options", []):
                if "label_key" in opt:
                    self.assertTrue(has_key_path(en, opt["label_key"]), f"en missing {opt['label_key']}")
                    self.assertTrue(has_key_path(id_lang, opt["label_key"]), f"id missing {opt['label_key']}")

        provider_setting = next(
            s for s in settings if s.get("key") == "default_provider"
        )
        provider_options = [opt["value"] for opt in provider_setting.get("options", [])]
        self.assertIn("custom", provider_options)

        setting_keys = [s.get("key") for s in settings]
        self.assertIn("custom_base_url", setting_keys)
        self.assertIn("custom_api_key", setting_keys)
        self.assertIn("custom_model", setting_keys)

        # Thumbnail dimension & size check
        self.assertLessEqual(os.path.getsize(thumb_path), 512 * 1024)
        with open(thumb_path, "rb") as f:
            header = f.read(30)
            self.assertTrue(header.startswith(b"RIFF") and b"WEBP" in header)


if __name__ == "__main__":
    unittest.main()
