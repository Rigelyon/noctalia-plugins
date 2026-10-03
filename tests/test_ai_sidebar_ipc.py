import os
import unittest

PANEL_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau")


class TestAiSidebarIpc(unittest.TestCase):
    def test_ipc_handler_structure(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), f"Missing {PANEL_FILE}")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check onIpc declaration
        self.assertIn("function onIpc(event", content)

        # Check supported events
        self.assertIn('event == "clear"', content)
        self.assertIn('event == "new_session"', content)
        self.assertIn('event == "ask"', content)
        self.assertIn('event == "export"', content)
        self.assertIn('event == "toggle"', content)

        # Check background session reset logic
        self.assertIn("startFreshOnOpen", content)
        self.assertIn("storage.saveSessions", content)

    def test_ipc_dispatch_simulation(self):
        state = {
            "current_session": {"id": "s1", "messages": [{"role": "user", "content": "hi"}]},
            "start_fresh_on_open": False,
            "sessions_saved": False,
            "stream_stopped": False,
            "input_buffer": "",
            "active_tab": "history",
            "message_sent": False,
            "exported": False,
            "toggled": False,
        }

        def handle_ipc(event: str, payload: str = None):
            if event in ("clear", "new_session"):
                state["stream_stopped"] = True
                if state["current_session"] and state["current_session"]["messages"]:
                    state["sessions_saved"] = True
                state["current_session"] = None
                state["start_fresh_on_open"] = True
                state["input_buffer"] = ""
            elif event == "ask":
                if payload and payload.strip():
                    state["stream_stopped"] = True
                    state["input_buffer"] = payload.strip()
                    state["active_tab"] = "chat"
                    state["message_sent"] = True
            elif event == "export":
                state["exported"] = True
            elif event == "toggle":
                state["toggled"] = True

        # Test clear / new_session
        handle_ipc("clear")
        self.assertIsNone(state["current_session"])
        self.assertTrue(state["start_fresh_on_open"])
        self.assertTrue(state["sessions_saved"])

        # Test ask
        handle_ipc("ask", "Explain Luau types")
        self.assertEqual(state["input_buffer"], "Explain Luau types")
        self.assertEqual(state["active_tab"], "chat")
        self.assertTrue(state["message_sent"])

        # Test export
        handle_ipc("export")
        self.assertTrue(state["exported"])

        # Test toggle
        handle_ipc("toggle")
        self.assertTrue(state["toggled"])


if __name__ == "__main__":
    unittest.main()
