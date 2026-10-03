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

    def test_chat_view_components(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("ui.markdown", content)
        self.assertIn("pendingClear", content)
        self.assertIn("player-stop", content)
        self.assertIn("eraser", content)
        self.assertIn("send", content)

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
        self.assertIn("provider_openai", content)
        self.assertIn("provider_anthropic", content)
        self.assertIn("provider_gemini", content)
        self.assertIn("testConnStatus", content)
        self.assertIn("saveConfig", content)
        self.assertIn("notify", content)

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


if __name__ == "__main__":
    unittest.main()
