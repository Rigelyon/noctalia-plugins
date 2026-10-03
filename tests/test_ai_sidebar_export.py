import os
import re
import unittest

EXPORT_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "export.luau")


class TestAiSidebarExport(unittest.TestCase):
    def test_export_file_structure(self):
        self.assertTrue(os.path.isfile(EXPORT_FILE), f"Missing {EXPORT_FILE}")
        with open(EXPORT_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check exports
        self.assertIn("export.formatMarkdown", content)
        self.assertIn("export.generateFilename", content)
        self.assertIn("export.saveSession", content)
        self.assertIn("export.getExportDir", content)

        # Check frontmatter and layout patterns
        self.assertIn('"---"', content)
        self.assertIn('title: "', content)
        self.assertIn('provider: "', content)
        self.assertIn('model: "', content)
        self.assertIn("### User", content)
        self.assertIn("### Assistant", content)

    def test_markdown_format_simulation(self):
        def format_markdown(session: dict) -> str:
            lines = [
                "---",
                f'title: "{session["title"]}"',
                f'date: "{session["date"]}"',
                f'provider: "{session["provider"]}"',
                f'model: "{session["model"]}"',
                "---",
                "",
            ]
            for msg in session["messages"]:
                heading = "### User" if msg["role"] == "user" else "### Assistant"
                lines.append(heading)
                lines.append(msg["content"])
                lines.append("")
            return "\n".join(lines)

        mock_session = {
            "title": "Optimizing Luau",
            "date": "2026-10-03 20:00:00",
            "provider": "anthropic",
            "model": "claude-3-5-haiku-20241022",
            "messages": [
                {"role": "user", "content": "How to optimize tables?"},
                {"role": "assistant", "content": "Preallocate table sizes."},
            ],
        }

        md = format_markdown(mock_session)
        self.assertIn('title: "Optimizing Luau"', md)
        self.assertIn('provider: "anthropic"', md)
        self.assertIn("### User\nHow to optimize tables?", md)
        self.assertIn("### Assistant\nPreallocate table sizes.", md)

    def test_filename_sanitization_simulation(self):
        def generate_filename(title: str, timestamp: int) -> str:
            clean = re.sub(r'[/\\%:*?"<>|]', "", title)
            clean = re.sub(r"\s+", "-", clean).strip()
            if not clean:
                clean = "conversation"
            if len(clean) > 40:
                clean = clean[:40]
            return f"20261003_{clean}_{timestamp}.md"

        self.assertEqual(
            generate_filename("Testing / Optimization: Speed?", 1727961000),
            "20261003_Testing-Optimization-Speed_1727961000.md",
        )
        self.assertEqual(
            generate_filename("???///:::", 1727961000),
            "20261003_conversation_1727961000.md",
        )

    def test_notify_export_with_actions(self):
        with open(EXPORT_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("export.notifyExport", content)
        self.assertIn('"notify-send"', content)
        self.assertIn('"view="', content)
        self.assertIn('"folder="', content)
        self.assertIn('"delete="', content)
        self.assertIn('"xdg-open"', content)
        self.assertIn("noctalia.removeFile", content)

    def test_export_action_translations(self):
        import json

        en_path = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "translations", "en.json"
        )
        id_path = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "translations", "id.json"
        )

        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_data = json.load(f)

        for key in ["action_view", "action_open_folder", "action_delete", "export_deleted"]:
            self.assertIn(key, en, f"Missing {key} in en.json")
            self.assertIn(key, id_data, f"Missing {key} in id.json")


if __name__ == "__main__":
    unittest.main()
