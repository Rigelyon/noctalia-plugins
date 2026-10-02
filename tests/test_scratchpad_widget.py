import json
import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "scratchpad")
WIDGET_FILE = os.path.join(PLUGIN_DIR, "widget.luau")


def simulate_count_notes(files: list[str] | None, ext_config: str = "md") -> int:
    if files is None:
        return 0
    ext = "." + re.sub(r"^\.", "", str(ext_config or "md"))
    count = 0
    for file in files:
        if len(file) > len(ext) and file.endswith(ext) and not file.startswith("."):
            count += 1
    return count


class TestScratchpadWidget(unittest.TestCase):
    def test_widget_file_exists(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "scratchpad/widget.luau must exist")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertTrue(content.startswith("--!strict"), "widget.luau must start with --!strict")
        self.assertIn('barWidget.setGlyph', content)
        self.assertIn('barWidget.setTooltip', content)
        self.assertIn('noctalia.togglePanel("rigelyon/scratchpad:panel")', content)
        self.assertIn('noctalia.state.watch("scratchpad_bump"', content)
        self.assertIn('function onClick()', content)
        self.assertIn('function update()', content)

    def test_count_notes_simulation(self):
        # Empty or None list
        self.assertEqual(simulate_count_notes(None), 0)
        self.assertEqual(simulate_count_notes([]), 0)

        # Standard notes
        files = ["idea1.md", "idea2.md", "todo.md"]
        self.assertEqual(simulate_count_notes(files), 3)

        # Mixed files and hidden files
        files = [
            "note.md",
            ".hidden.md",
            ".md",
            "other.txt",
            "image.png",
            "draft.md",
            ".git",
        ]
        self.assertEqual(simulate_count_notes(files), 2)

        # With leading dot in extension config
        self.assertEqual(simulate_count_notes(files, ext_config=".md"), 2)

        # Custom extension
        txt_files = ["note.txt", "doc.txt", "readme.md", ".hidden.txt"]
        self.assertEqual(simulate_count_notes(txt_files, ext_config="txt"), 2)

    def test_tooltip_translation_keys(self):
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertIn("widget_tooltip", en)
        self.assertIn("{count}", en["widget_tooltip"])
        self.assertIn("widget_tooltip", id_lang)
        self.assertIn("{count}", id_lang["widget_tooltip"])


if __name__ == "__main__":
    unittest.main()
