import json
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "scratchpad")
LAUNCHER_FILE = os.path.join(PLUGIN_DIR, "launcher.luau")


def simulate_launcher_results(query, notes, pinned_set):
    trimmed = query.strip()
    results = []

    if trimmed != "":
        # Offer quick capture
        results.append({
            "id": f"capture:{trimmed}",
            "title": f"Quick Capture: {trimmed}",
            "subtitle": "Save immediately to Scratchpad",
            "glyph": "plus",
        })

    matched_notes = []
    # Filter notes
    for note in notes:
        title = note["title"]
        content = note["content"]
        is_pinned = note["filename"] in pinned_set

        matched = False
        if trimmed == "":
            matched = True
        else:
            q_lower = trimmed.lower()
            if q_lower in title.lower() or q_lower in content.lower():
                matched = True
            else:
                tokens = [t for t in q_lower.split() if t]
                if any(t in title.lower() or t in content.lower() for t in tokens):
                    matched = True

        if matched:
            matched_notes.append((is_pinned, note["filename"], title))

    # Sort: pinned first, then alphabetical filename
    matched_notes.sort(key=lambda item: (not item[0], item[1].lower()))

    for is_pinned, filename, title in matched_notes:
        results.append({
            "id": f"note:{filename}",
            "title": title,
            "subtitle": "Pinned note" if is_pinned else "Saved note",
            "glyph": "pinned" if is_pinned else "file-text",
        })

    return results


class TestScratchpadLauncher(unittest.TestCase):
    def setUp(self):
        self.notes = [
            {"filename": "Project ideas.md", "title": "Project ideas", "content": "Build noctalia plugins"},
            {"filename": "Groceries.md", "title": "Groceries", "content": "Milk, eggs, coffee"},
        ]
        self.pinned = {"Project ideas.md"}

    def test_empty_query_lists_all(self):
        res = simulate_launcher_results("", self.notes, self.pinned)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["id"], "note:Project ideas.md")
        self.assertEqual(res[0]["glyph"], "pinned")

    def test_query_with_text_has_quick_capture(self):
        res = simulate_launcher_results("buy milk", self.notes, self.pinned)
        self.assertGreaterEqual(len(res), 1)
        self.assertTrue(res[0]["id"].startswith("capture:"))
        self.assertEqual(res[0]["title"], "Quick Capture: buy milk")
        # Second item should be Groceries (matches "milk")
        self.assertEqual(res[1]["id"], "note:Groceries.md")

    def test_pinned_sorting_order(self):
        notes = [
            {"filename": "Alpha.md", "title": "Alpha", "content": ""},
            {"filename": "Beta.md", "title": "Beta", "content": ""},
            {"filename": "Gamma.md", "title": "Gamma", "content": ""},
        ]
        pinned = {"Beta.md"}
        res = simulate_launcher_results("", notes, pinned)
        self.assertEqual(res[0]["id"], "note:Beta.md")
        self.assertEqual(res[0]["glyph"], "pinned")
        self.assertEqual(res[1]["id"], "note:Alpha.md")
        self.assertEqual(res[2]["id"], "note:Gamma.md")

    def test_translation_keys_exist(self):
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(en_path))
        self.assertTrue(os.path.isfile(id_path))

        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        required_keys = [
            "quick_capture_prompt",
            "archive_note",
            "pinned_section",
            "tab_saved_notes",
            "title",
            "note_archived",
        ]
        for key in required_keys:
            self.assertIn(key, en, f"Missing key in en.json: {key}")
            self.assertIn(key, id_lang, f"Missing key in id.json: {key}")

    def test_launcher_file_structure(self):
        self.assertTrue(os.path.isfile(LAUNCHER_FILE), "scratchpad/launcher.luau must exist")
        with open(LAUNCHER_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("function onQuery(", content)
        self.assertIn("function onActivate(", content)
        self.assertIn("launcher.setResults(", content)
        self.assertIn('capture:', content)
        self.assertIn('note:', content)
        self.assertIn('scratchpad_bump', content)
        self.assertIn('scratchpad_open_file', content)
        self.assertIn('noctalia.togglePanel("rigelyon/scratchpad:panel")', content)


if __name__ == "__main__":
    unittest.main()
