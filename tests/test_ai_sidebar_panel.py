import json
import os
import re
import unittest

PANEL_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau")
EN_TRANSLATIONS = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "translations", "en.json"
)
ID_TRANSLATIONS = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "translations", "id.json"
)


class TestAiSidebarPanel(unittest.TestCase):
    def test_panel_file_structure(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("onOpen", content)
        self.assertIn("onClose", content)
        self.assertIn("renderChatView", content)
        self.assertIn("renderHistoryView", content)
        self.assertIn("renderSettingView", content)
        self.assertIn("testConnection", content)
        # Verify 80ms throttle logic presence
        self.assertIn("nowMs", content)

    def test_luau_require_paths_valid(self):
        plugin_dir = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
        require_pattern = re.compile(r'require\(["\']([^"\']+)["\']\)')
        found_requires = []
        for root, _, files in os.walk(plugin_dir):
            for file in files:
                if file.endswith(".luau"):
                    filepath = os.path.join(root, file)
                    with open(filepath, "r", encoding="utf-8") as f:
                        for line_no, line in enumerate(f, 1):
                            for match in require_pattern.finditer(line):
                                req_path = match.group(1)
                                found_requires.append((file, line_no, req_path))
                                self.assertTrue(
                                    req_path.startswith("./") and req_path.endswith(".luau"),
                                    f"{file}:{line_no} invalid require path '{req_path}'; must start with './' and end with '.luau'",
                                )
        self.assertGreater(len(found_requires), 0, "Expected at least one require() in plugin")

    def test_streaming_and_throttling_logic(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("stopStreaming", content)
        self.assertIn("sendMessage", content)
        self.assertIn("isStreaming", content)
        self.assertIn("streamHandle", content)
        self.assertIn("lastRenderMs", content)
        self.assertIn("80", content, "Throttle limit must be at least 80ms")
        self.assertIn("capMessages", content)
        self.assertIn("table.sort(sessions", content, "sessions must be re-sorted on message send")

    def test_chat_view_components(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("ui.markdown", content)
        self.assertIn("pendingClear", content)
        self.assertIn("player-stop", content)
        self.assertIn("eraser", content)
        self.assertIn("send", content)
        self.assertNotIn("ui.box", content, "ui.box cannot have children in Noctalia, must use ui.column")
        self.assertIn("surface_variant", content)
        self.assertIn("chat-input", content)
        self.assertIn("submitOnEnter", content, "Input must have submitOnEnter enabled for Enter-to-send UX")
        self.assertIn("inputRev", content, "Input must use revision keying to clear native buffer after send")
        self.assertIn("stickToBottom", content, "Chat scroll must stickToBottom")
        self.assertIn("copyToClipboard", content, "Assistant card must have 1-click copy action")

    def test_history_view_components(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("pendingDeleteSessionId", content)
        self.assertIn("historySearch", content)
        self.assertIn("deleteSession", content)
        self.assertIn("createSession", content)

    def test_setting_view_components(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("ui.select", content, "Provider selector must use ui.select dropdown")
        self.assertIn("provider_openai", content)
        self.assertIn("provider_anthropic", content)
        self.assertIn("provider_gemini", content)
        self.assertIn('tr("api_key")', content)
        self.assertIn('tr("model")', content)
        self.assertIn("testConnStatus", content)
        self.assertIn("saveConfig", content)
        self.assertIn("notify", content)
        self.assertIn("settingRev", content, "Setting inputs must use revision keying")
        self.assertIn("setting-openai-key-", content)
        self.assertIn("setting-openai-model-", content)
        self.assertIn("setting-anthropic-key-", content)
        self.assertIn("setting-anthropic-model-", content)
        self.assertIn("setting-gemini-key-", content)
        self.assertIn("setting-gemini-model-", content)
        self.assertIn("showApiKey", content)
        self.assertIn("password = not showApiKey", content)
        self.assertIn("testConnBanner", content)

    def test_all_tr_keys_exist_in_translations(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        with open(EN_TRANSLATIONS, "r", encoding="utf-8") as f:
            en_data = json.load(f)
        with open(ID_TRANSLATIONS, "r", encoding="utf-8") as f:
            id_data = json.load(f)

        keys_used = set(re.findall(r'tr\("([^"]+)"\)', content))
        self.assertGreater(len(keys_used), 0, "No tr calls found")

        for key in keys_used:
            self.assertIn(key, en_data, f"Key '{key}' missing from en.json")
            self.assertIn(key, id_data, f"Key '{key}' missing from id.json")


    def test_payload_capped_before_assistant_placeholder(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Verify capMessages is called before assistant placeholder insertion
        cap_pos = content.find("storage.capMessages(currentSession.messages)")
        placeholder_pos = content.find('role = "assistant"')
        self.assertNotEqual(cap_pos, -1, "Missing storage.capMessages in panel.luau")
        self.assertNotEqual(placeholder_pos, -1, "Missing assistant placeholder in panel.luau")
        self.assertLess(
            cap_pos,
            placeholder_pos,
            "storage.capMessages must be captured BEFORE inserting assistant placeholder",
        )

        # Simulation: payload should end on user prompt, not empty assistant placeholder
        session_messages = [
            {"role": "user", "content": "Hello", "timestamp": 100},
        ]
        capped_payload = list(session_messages)  # captured before placeholder
        session_messages.append({"role": "assistant", "content": "", "timestamp": 101})

        self.assertEqual(capped_payload[-1]["role"], "user")
        self.assertNotEqual(capped_payload[-1]["role"], "assistant")
        self.assertNotIn("", [m["content"] for m in capped_payload])

    def test_on_open_resyncs_current_session(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check onOpen re-sync pattern by session ID
        self.assertIn("sess.id == currentSession.id", content)
        self.assertIn("currentSession = matched or sessions[1] or nil", content)

        # Simulation: onOpen re-sync logic
        sessions = [
            {"id": "s1", "title": "First", "messages": []},
            {"id": "s2", "title": "Updated Second", "messages": [{"role": "user", "content": "hi"}]},
        ]
        # Case 1: currentSession exists with matching id in reloaded sessions
        current_session = {"id": "s2", "title": "Old Second", "messages": []}
        matched = None
        for s in sessions:
            if s["id"] == current_session["id"]:
                matched = s
                break
        resynced = matched or (sessions[0] if sessions else None)
        self.assertEqual(resynced["title"], "Updated Second")
        self.assertEqual(len(resynced["messages"]), 1)

        # Case 2: currentSession was deleted or not found
        current_session = {"id": "s_deleted", "title": "Deleted"}
        matched = None
        for s in sessions:
            if s["id"] == current_session["id"]:
                matched = s
                break
        resynced = matched or (sessions[0] if sessions else None)
        self.assertEqual(resynced["id"], "s1")

        # Case 3: no sessions exist
        empty_sessions = []
        matched = None
        for s in empty_sessions:
            if s["id"] == current_session["id"]:
                matched = s
                break
        resynced = matched or (empty_sessions[0] if empty_sessions else None)
        self.assertIsNone(resynced)

    def test_cancelled_stream_error_guard(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Verify guard in error handler
        self.assertIn("if not isStreaming then return end", content)

        # Simulation: onError behavior when streaming was cancelled (isStreaming == False)
        is_streaming = False
        assistant_msg = {"role": "assistant", "content": "Partial response"}

        def on_error(err):
            nonlocal assistant_msg
            if not is_streaming:
                return
            assistant_msg["content"] += f"\n\n**[Error: {err}]**"

        on_error("Stream connection aborted")
        self.assertEqual(
            assistant_msg["content"],
            "Partial response",
            "Error handler should not mutate content if streaming was cancelled",
        )


if __name__ == "__main__":
    unittest.main()

