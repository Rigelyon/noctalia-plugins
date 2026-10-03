import os
import re
import unittest

STORAGE_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "storage.luau")


class TestAiSidebarStorage(unittest.TestCase):
    def test_storage_file_exists(self):
        self.assertTrue(os.path.isfile(STORAGE_FILE), "Missing storage.luau")
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check required function exports
        expected_exports = [
            "loadConfig",
            "saveConfig",
            "loadSessions",
            "saveSessions",
            "createSession",
            "deleteSession",
            "capMessages",
            "generateTitle",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"storage.luau missing export {exp}")

        # Check type exports
        expected_types = [
            "export type Message",
            "export type Session",
            "export type ConfigTable",
        ]
        for t in expected_types:
            self.assertIn(t, content, f"storage.luau missing type definition {t}")

    def test_title_generation_logic(self):
        # Simulate Luau title sanitization
        def generate_title(text):
            if not text:
                return "New Conversation"
            cleaned = text.strip()
            first_line = cleaned.split("\n")[0].strip() if cleaned else ""
            first_line = re.sub(r"^#+\s*", "", first_line)
            first_line = re.sub(r'[/%\\:*?"<>|]', "", first_line)
            first_line = re.sub(r"^\.+", "", first_line).strip()
            if not first_line:
                return "New Conversation"
            if len(first_line) > 40:
                return first_line[:37] + "..."
            return first_line

        self.assertEqual(generate_title("# Hello World"), "Hello World")
        self.assertEqual(generate_title("...dot title"), "dot title")
        self.assertEqual(
            generate_title("This is a very long prompt that should definitely be truncated nicely"),
            "This is a very long prompt that shoul...",
        )
        self.assertEqual(
            generate_title("### Complex: Title with / forbidden \\ chars?"),
            "Complex Title with  forbidden  chars",
        )
        self.assertEqual(generate_title(""), "New Conversation")
        self.assertEqual(generate_title("   ###   "), "New Conversation")
        self.assertEqual(
            generate_title("First line\nSecond line should be ignored"),
            "First line",
        )

    def test_sliding_window_cap_messages_simulation(self):
        def cap_messages(messages, max_count=20):
            limit = max_count or 20
            if len(messages) <= limit:
                return messages
            return messages[-limit:]

        msgs = [{"role": "user", "content": f"msg {i}"} for i in range(25)]
        capped = cap_messages(msgs, 20)
        self.assertEqual(len(capped), 20)
        self.assertEqual(capped[0]["content"], "msg 5")
        self.assertEqual(capped[-1]["content"], "msg 24")

        small_msgs = [{"role": "user", "content": "hello"}]
        self.assertEqual(cap_messages(small_msgs), small_msgs)

    def test_session_sorting_simulation(self):
        sessions = [
            {"id": "1", "updated_at": 100},
            {"id": "2", "updated_at": 300},
            {"id": "3", "updated_at": 200},
        ]
        sorted_sessions = sorted(sessions, key=lambda s: s["updated_at"], reverse=True)
        self.assertEqual([s["id"] for s in sorted_sessions], ["2", "3", "1"])

    def test_delete_session_simulation(self):
        sessions = [
            {"id": "sess_1", "title": "A"},
            {"id": "sess_2", "title": "B"},
            {"id": "sess_3", "title": "C"},
        ]
        updated = [s for s in sessions if s["id"] != "sess_2"]
        self.assertEqual(len(updated), 2)
        self.assertEqual([s["id"] for s in updated], ["sess_1", "sess_3"])


if __name__ == "__main__":
    unittest.main()
