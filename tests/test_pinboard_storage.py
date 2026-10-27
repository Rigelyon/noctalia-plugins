import os
import re
import unittest

STORAGE_FILE = os.path.join(os.path.dirname(__file__), "..", "pinboard", "storage.luau")


class TestPinboardStorage(unittest.TestCase):
    def test_storage_file_exists(self):
        self.assertTrue(os.path.isfile(STORAGE_FILE), "Missing storage.luau")
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check required function exports
        expected_exports = [
            "storage.load",
            "storage.save",
            "storage.ensureImagesDir",
            "storage.validateClipboard",
            "storage.defaultData",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"storage.luau missing export {exp}")

        # Check type exports
        expected_types = [
            "export type StashItem",
            "export type PinboardData",
            "export type ClipboardValidationResult",
        ]
        for t in expected_types:
            self.assertIn(t, content, f"storage.luau missing type definition {t}")

    def test_clipboard_validation_rules(self):
        # Python mirror test of the clipboard validation rules
        IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp")

        def validate_clipboard(raw_text):
            if not raw_text:
                return {"valid": False, "reason": "empty"}
            text = raw_text.strip()
            if not text:
                return {"valid": False, "reason": "whitespace_only"}

            # File path or file:// URI check
            lower = text.lower()
            if lower.startswith("file://"):
                path = text[7:]
                if any(path.lower().endswith(ext) for ext in IMAGE_EXTS):
                    return {"valid": True, "type": "image", "value": path}

            if lower.startswith("/") or lower.startswith("~/"):
                if any(lower.endswith(ext) for ext in IMAGE_EXTS):
                    return {"valid": True, "type": "image", "value": text}

            # HTTP / HTTPS Image URL
            if lower.startswith("http://") or lower.startswith("https://"):
                if any(lower.split("?")[0].endswith(ext) for ext in IMAGE_EXTS):
                    return {"valid": True, "type": "image", "value": text}

            # Markdown checklist or structured notes
            lines = [line.strip() for line in text.split("\n") if line.strip()]
            has_checklist = any(re.match(r"^[-*]\s*\[[ xX]\]", line) for line in lines)
            has_headings = any(re.match(r"^#{1,6}\s+", line) for line in lines)

            if has_checklist or has_headings or len(lines) >= 3:
                return {"valid": True, "type": "note", "value": text}

            # Reject random short text, URLs without images, passwords, single words
            return {"valid": False, "reason": "unstructured_text"}

        # Positive tests
        self.assertTrue(validate_clipboard("/home/user/Pictures/sketch.png")["valid"])
        self.assertTrue(validate_clipboard("~/Pictures/ref.webp")["valid"])
        self.assertTrue(validate_clipboard("file:///home/user/Art/pose.jpg")["valid"])
        self.assertTrue(validate_clipboard("https://example.com/art/character.png?v=2")["valid"])
        self.assertTrue(validate_clipboard("- [ ] Obsidian\n- [ ] Flint and steel")["valid"])
        self.assertTrue(validate_clipboard("### Nether Coordinates\nX: 120, Z: -450")["valid"])

        # Negative tests
        self.assertFalse(validate_clipboard("")["valid"])
        self.assertFalse(validate_clipboard("   ")["valid"])
        self.assertFalse(validate_clipboard("mySecretPassword123!")["valid"])
        self.assertFalse(validate_clipboard("https://google.com")["valid"])
        self.assertFalse(validate_clipboard("Just a random sentence copied from a chat.")["valid"])


if __name__ == "__main__":
    unittest.main()
