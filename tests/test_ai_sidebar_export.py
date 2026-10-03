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


if __name__ == "__main__":
    unittest.main()
