import os
import unittest

COMPONENTS_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "components.luau")


class TestPinboardComponents(unittest.TestCase):
    def test_components_file_exists_and_exports(self):
        self.assertTrue(os.path.isfile(COMPONENTS_FILE), "Missing components.luau")
        with open(COMPONENTS_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        expected_exports = [
            "components.badge",
            "components.iconButton",
            "components.floatingToolbar",
            "components.stashCard",
            "components.quadrantSelector",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"components.luau missing export {exp}")

        # Ensure no hardcoded raw emojis used for structural icons (ui-ux-pro-max standard)
        emojis = ["📌", "🖼️", "📝", "🔒", "⚙️", "❌", "🗑️"]
        for emoji in emojis:
            self.assertNotIn(emoji, content, f"Found emoji {emoji} in components.luau")


if __name__ == "__main__":
    unittest.main()
