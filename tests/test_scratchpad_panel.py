import json
import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "scratchpad")
PANEL_FILE = os.path.join(PLUGIN_DIR, "panel.luau")


def simulate_generate_archive_name(
    content: str,
    existing_files: set[str],
    suffix: str = ".md",
    timestamp: str = "2026-10-02 12.00.00",
) -> str:
    trimmed = content.strip()
    first_line = trimmed.splitlines()[0] if trimmed else ""
    first_line = re.sub(r"^#+\s*", "", first_line)
    first_line = re.sub(r'[/%\\:*?"<>|]', "", first_line)
    first_line = re.sub(r"^\.+", "", first_line).strip()
    first_line = re.sub(r"^\.+", "", first_line).strip()
    if 0 < len(first_line) <= 40:
        candidate = first_line + suffix
        if candidate not in existing_files:
            return candidate
    base = timestamp
    name = base + suffix
    counter = 2
    while name in existing_files:
        name = f"{base} ({counter}){suffix}"
        counter += 1
    return name


def simulate_filter_and_sort_notes(
    files: list[str], pins: dict[str, bool], suffix: str = ".md"
) -> list[str]:
    valid_files = [
        f
        for f in files
        if len(f) > len(suffix) and f.endswith(suffix) and not f.startswith(".")
    ]
    valid_files.sort(key=lambda x: (not pins.get(x, False), x))
    return valid_files


class TestScratchpadPanel(unittest.TestCase):
    def test_panel_file_exists_and_callbacks_defined(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "scratchpad/panel.luau must exist")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check export lifecycle callbacks
        self.assertIn("function onOpen(", content)
        self.assertIn("function onClose()", content)

        # Check UI rendering calls
        self.assertIn("panel.render(", content)
        self.assertIn("ui.markdown(", content)
        self.assertIn("ui.input(", content)
        self.assertIn("ui.scroll(", content)
        self.assertIn("ui.button(", content)

        # Check markdown toolbar actions
        self.assertIn('text = "#"', content)
        self.assertIn('text = "B"', content)
        self.assertIn('text = "I"', content)
        self.assertIn('text = "[✓]"', content)
        self.assertIn('text = "</>"', content)
        self.assertIn('text = ">"', content)
        self.assertIn('text = "•"', content)

        # Check action button ordering (Save before Copy)
        floppy_pos = content.find('"device-floppy"')
        copy_pos = content.find('"copy"')
        self.assertTrue(floppy_pos > 0 and copy_pos > 0)
        self.assertLess(floppy_pos, copy_pos, "Save button must come before Copy button")

        # Check 2-step clear confirmation and caching
        self.assertIn("pendingClear", content)
        self.assertIn("clear_confirm", content)
        self.assertIn("noteContentCache", content)

        # Check inter-component state coordination
        self.assertIn("scratchpad_bump", content)
        self.assertIn("scratchpad_open_file", content)

        # Check auto-archive configuration check
        self.assertIn('noctalia.getConfig("auto_archive")', content)

        # Check rename state variables and functions
        self.assertIn("commitRename(", content)
        self.assertIn("renamingFile", content)
        self.assertIn("renameInput", content)
        self.assertIn("isEditingActiveTitle", content)

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
            "title",
            "tab_scratchpad",
            "tab_saved_notes",
            "editor_placeholder",
            "search_placeholder",
            "no_notes",
            "no_search_results",
            "ready",
            "status_counts",
            "copied_all",
            "copied_note",
            "clear_confirm",
            "confirm_delete",
            "editing_note",
            "new_draft",
            "new_draft_tooltip",
            "note_saved",
            "scratchpad_subtitle",
            "rename_note",
            "rename_placeholder",
            "confirm_rename",
            "cancel",
            "note_renamed",
            "rename_empty_error",
            "rename_exists_error",
        ]
        for key in required_keys:
            self.assertIn(key, en, f"Missing key in en.json: {key}")
            self.assertIn(key, id_lang, f"Missing key in id.json: {key}")

        # Ensure parameterized status_counts contains expected tokens
        self.assertIn("{words}", en["status_counts"])
        self.assertIn("{chars}", en["status_counts"])
        self.assertIn("{words}", id_lang["status_counts"])
        self.assertIn("{chars}", id_lang["status_counts"])

    def test_generate_archive_name_from_heading(self):
        existing = {"Existing.md"}
        name = simulate_generate_archive_name("# Shopping List\n- Milk\n- Apples", existing)
        self.assertEqual(name, "Shopping List.md")

    def test_generate_archive_name_sanitization(self):
        existing = set()
        name = simulate_generate_archive_name("Draft: Review / Plan * 2026?", existing)
        self.assertEqual(name, "Draft Review  Plan  2026.md")

        name_dot = simulate_generate_archive_name("# .env.local", existing)
        self.assertEqual(name_dot, "env.local.md")

        name_dots = simulate_generate_archive_name("...notes", existing)
        self.assertEqual(name_dots, "notes.md")

    def test_panel_draft_protection_and_delete_handling(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Draft protection before loading note
        self.assertIn("archiveCurrentDraft()", content)
        self.assertIn("currentNoteFile == nil", content)

        # Editor reset on delete open note
        self.assertIn("if currentNoteFile == file then", content)
        self.assertIn('buffer = ""', content)

    def test_generate_archive_name_fallback_on_empty_or_existing(self):
        existing = {"Shopping List.md"}
        name = simulate_generate_archive_name("# Shopping List", existing, timestamp="2026-10-02 12.00.00")
        self.assertEqual(name, "2026-10-02 12.00.00.md")

        # Collision with timestamp
        existing.add("2026-10-02 12.00.00.md")
        name2 = simulate_generate_archive_name("", existing, timestamp="2026-10-02 12.00.00")
        self.assertEqual(name2, "2026-10-02 12.00.00 (2).md")

    def test_filter_and_sort_notes_with_pins(self):
        files = [
            ".pinned.json",
            "zebra.md",
            "apple.md",
            "pinned_beta.md",
            "notes.txt",
            ".hidden.md",
        ]
        pins = {"pinned_beta.md": True}
        result = simulate_filter_and_sort_notes(files, pins)
        self.assertEqual(result, ["pinned_beta.md", "apple.md", "zebra.md"])

    def test_view_state_persistence_and_title_display(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check title bar and tab bar separation
        self.assertIn("function renderTitleBar()", content)
        self.assertIn("function renderTabBar()", content)
        self.assertIn("renderTitleBar()", content)
        self.assertIn("renderTabBar()", content)

        # Check view state persistence (.state.json, loadState, saveState)
        self.assertIn(".state.json", content)
        self.assertIn("function loadState()", content)
        self.assertIn("function saveState()", content)
        self.assertIn("loadState()", content)

        # Ensure viewMode is not unconditionally overwritten in onOpen
        self.assertIn("if viewMode == nil then", content)
        self.assertNotIn('viewMode = defaultView', content)

        # Ensure note click in saved notes does not forcibly reset viewMode to edit
        # Search the onClick block of the note row
        self.assertIn("currentNoteFile = file", content)
        # Ensure active note banner was removed per user directive (clean scratchpad)
        self.assertNotIn("noteBanner", content)

        # Check title bar rename action and inline renaming
        self.assertIn("isEditingActiveTitle", content)
        self.assertIn("header-rename-input", content)
        self.assertIn("inline-rename-", content)
        self.assertIn("commitRename(", content)


if __name__ == "__main__":
    unittest.main()
