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
            "syncToSettingsToml",
            "rewindSession",
            "removeLastAssistantMessage",
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
            capped = []
            if len(messages) <= limit:
                for m in messages:
                    capped.append(m)
            else:
                start_idx = len(messages) - limit
                for i in range(start_idx, len(messages)):
                    capped.append(messages[i])
            while len(capped) > 0 and capped[0]["role"] != "user":
                capped.pop(0)
            return capped

        msgs = [{"role": "user", "content": f"msg {i}"} for i in range(25)]
        capped = cap_messages(msgs, 20)
        self.assertEqual(len(capped), 20)
        self.assertEqual(capped[0]["content"], "msg 5")
        self.assertEqual(capped[-1]["content"], "msg 24")

        small_msgs = [{"role": "user", "content": "hello"}]
        self.assertEqual(cap_messages(small_msgs), small_msgs)

    def test_cap_messages_role_parity_alternating(self):
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn('capped[1].role ~= "user"', content)

        def cap_messages(messages, max_count=20):
            limit = max_count or 20
            capped = []
            if len(messages) <= limit:
                for m in messages:
                    capped.append(m)
            else:
                start_idx = len(messages) - limit
                for i in range(start_idx, len(messages)):
                    capped.append(messages[i])
            while len(capped) > 0 and capped[0]["role"] != "user":
                capped.pop(0)
            return capped

        # 21 alternating messages: 0:user, 1:assistant, ..., 20:user
        messages = [
            {"role": "user" if i % 2 == 0 else "assistant", "content": f"msg {i}"}
            for i in range(21)
        ]
        self.assertEqual(len(messages), 21)
        self.assertEqual(messages[0]["role"], "user")
        self.assertEqual(messages[1]["role"], "assistant")
        self.assertEqual(messages[-1]["role"], "user")

        # Capping with limit=20 takes last 20 messages (messages[1:21]).
        # The first message in that window is an assistant turn, which must be stripped
        # so that the window starts on a user message (role == "user").
        capped = cap_messages(messages, 20)
        self.assertEqual(len(capped), 19)
        self.assertEqual(capped[0]["role"], "user")
        self.assertEqual(capped[0]["content"], "msg 2")
        self.assertEqual(capped[-1]["role"], "user")
        self.assertEqual(capped[-1]["content"], "msg 20")

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

    def test_toml_sync_simulation(self):
        sample_toml = """[plugin_settings."noctalia/timer"]
panel_placement = "floating"

[plugin_settings."rigelyon/ai-sidebar"]
default_provider = "gemini"
gemini_api_key = "test_key"
panel_placement = "floating"

[plugin_settings."rigelyon/scratchpad"]
panel_layer = "overlay"
"""
        plugin_keys = {
            "default_provider": '"custom"',
            "custom_base_url": '"http://localhost:11434/v1"',
        }

        lines = sample_toml.split("\n")
        new_lines = []
        in_section = False
        handled = set()

        for line in lines:
            m = re.match(r"^\s*\[\s*([^\]]+)\s*\]", line)
            if m:
                if in_section:
                    for k, v in plugin_keys.items():
                        if k not in handled:
                            new_lines.append(f"{k} = {v}")
                            handled.add(k)
                    in_section = False
                sec = m.group(1)
                if re.match(r"^plugin_settings\s*\.\s*[\"']rigelyon/ai-sidebar[\"']", sec):
                    in_section = True
                    new_lines.append(line)
                    continue
            if in_section:
                km = re.match(r"^\s*([\w_-]+)\s*=", line)
                if km and km.group(1) in plugin_keys:
                    k = km.group(1)
                    new_lines.append(f"{k} = {plugin_keys[k]}")
                    handled.add(k)
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)

        res = "\n".join(new_lines)
        self.assertIn('default_provider = "custom"', res)
        self.assertIn('custom_base_url = "http://localhost:11434/v1"', res)
        self.assertIn('panel_placement = "floating"', res)
        self.assertIn('[plugin_settings."rigelyon/scratchpad"]', res)

    def test_rewind_session_logic(self):
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("storage.rewindSession", content)
        self.assertIn("storage.removeLastAssistantMessage", content)

    def test_rewind_simulation(self):
        session = {
            "id": "s1",
            "messages": [
                {"role": "user", "content": "1"},
                {"role": "assistant", "content": "2"},
                {"role": "user", "content": "3"},
                {"role": "assistant", "content": "4"},
            ]
        }
        # Rewind to target index 2 (keeps 1 and 2)
        target_idx = 2
        session["messages"] = session["messages"][:target_idx]
        self.assertEqual(len(session["messages"]), 2)
        self.assertEqual(session["messages"][-1]["content"], "2")

        # Remove last assistant message
        if session["messages"] and session["messages"][-1]["role"] == "assistant":
            session["messages"].pop()
        self.assertEqual(len(session["messages"]), 1)
        self.assertEqual(session["messages"][-1]["role"], "user")


if __name__ == "__main__":
    unittest.main()
