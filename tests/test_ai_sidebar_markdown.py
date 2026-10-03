import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
MARKDOWN_FILE = os.path.join(PLUGIN_DIR, "markdown.luau")


class TestAiSidebarMarkdown(unittest.TestCase):
    def test_markdown_file_exists(self):
        self.assertTrue(os.path.isfile(MARKDOWN_FILE), f"Missing {MARKDOWN_FILE}")
        with open(MARKDOWN_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("markdown.parseSegments", content)

    def test_segment_parser_simulation(self):
        def parse_segments(text: str):
            segments = []
            if not text:
                return segments

            pattern = re.compile(r"```([a-zA-Z0-9_\-\+]*)\n?(.*?)```", re.DOTALL)
            last_end = 0

            for match in pattern.finditer(text):
                start, end = match.span()
                if start > last_end:
                    prefix = text[last_end:start]
                    if prefix.strip():
                        segments.append({"type": "text", "content": prefix})
                lang = match.group(1).strip() or "text"
                code = match.group(2)
                segments.append({"type": "code", "language": lang, "code": code})
                last_end = end

            if last_end < len(text):
                remaining = text[last_end:]
                unclosed = re.search(r"```([a-zA-Z0-9_\-\+]*)\n?(.*)", remaining, re.DOTALL)
                if unclosed:
                    u_start = unclosed.start()
                    if u_start > 0:
                        prefix = remaining[:u_start]
                        if prefix.strip():
                            segments.append({"type": "text", "content": prefix})
                    lang = unclosed.group(1).strip() or "text"
                    code = unclosed.group(2)
                    segments.append({"type": "code", "language": lang, "code": code})
                else:
                    if remaining.strip():
                        segments.append({"type": "text", "content": remaining})

            return segments

        # 1. Plain text without code blocks
        s1 = parse_segments("Hello world, this is a plain message.")
        self.assertEqual(len(s1), 1)
        self.assertEqual(s1[0]["type"], "text")

        # 2. Text with single code block
        s2 = parse_segments("Here is code:\n```python\nprint('hi')\n```\nDone.")
        self.assertEqual(len(s2), 3)
        self.assertEqual(s2[0]["type"], "text")
        self.assertEqual(s2[1]["type"], "code")
        self.assertEqual(s2[1]["language"], "python")
        self.assertEqual(s2[1]["code"], "print('hi')\n")
        self.assertEqual(s2[2]["type"], "text")

        # 3. Unclosed streaming code block
        s3 = parse_segments("Generating:\n```luau\nlocal x = 10")
        self.assertEqual(len(s3), 2)
        self.assertEqual(s3[1]["type"], "code")
        self.assertEqual(s3[1]["language"], "luau")
        self.assertEqual(s3[1]["code"], "local x = 10")


if __name__ == "__main__":
    unittest.main()
