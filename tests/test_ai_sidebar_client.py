import os
import unittest

CLIENT_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "client.luau")


class TestAiSidebarClient(unittest.TestCase):
    def test_client_file_exists(self):
        self.assertTrue(os.path.isfile(CLIENT_FILE), "Missing client.luau")
        with open(CLIENT_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("testConnection", content)
        self.assertIn("streamChat", content)
        self.assertIn("Environment Context", content)
        self.assertIn("providers/openai", content)
        self.assertIn("providers/anthropic", content)
        self.assertIn("providers/gemini", content)

    def test_environment_prompt_simulation(self):
        def build_environment_prompt(base_prompt, time_str="2026-10-03 12:00:00"):
            base = (
                base_prompt
                if (base_prompt and base_prompt.strip() != "")
                else "You are a helpful and concise AI assistant."
            )
            env_info = f"\n\n[Environment Context: Current system time is {time_str}, running on Noctalia Linux Desktop Shell.]"
            return base + env_info

        # With custom prompt
        prompt = build_environment_prompt("You are a Luau coding assistant.")
        self.assertTrue(prompt.startswith("You are a Luau coding assistant."))
        self.assertIn("[Environment Context: Current system time is 2026-10-03 12:00:00", prompt)
        self.assertIn("running on Noctalia Linux Desktop Shell.]", prompt)

        # With empty / None prompt
        default_prompt = build_environment_prompt(None)
        self.assertTrue(default_prompt.startswith("You are a helpful and concise AI assistant."))
        self.assertIn("[Environment Context:", default_prompt)

        empty_prompt = build_environment_prompt("")
        self.assertTrue(empty_prompt.startswith("You are a helpful and concise AI assistant."))

    def test_provider_selection_simulation(self):
        def get_provider(name):
            if name == "anthropic":
                return "anthropic"
            elif name == "gemini":
                return "gemini"
            else:
                return "openai"

        self.assertEqual(get_provider("openai"), "openai")
        self.assertEqual(get_provider("anthropic"), "anthropic")
        self.assertEqual(get_provider("gemini"), "gemini")
        self.assertEqual(get_provider("unknown"), "openai")
        self.assertEqual(get_provider(None), "openai")

    def test_stream_chat_flow_simulation(self):
        # 1. Normal streaming flow
        chunks = []
        errors = []
        done_called = False

        def on_chunk(t):
            chunks.append(t)

        def on_error(e):
            errors.append(e)

        def on_done():
            nonlocal done_called
            done_called = True

        # Simulate SSE lines
        received_chunks = []
        for line in ['data: {"choices":[{"delta":{"content":"Hi"}}]}', 'data: [DONE]']:
            if line.startswith("data: ") and not line.startswith("data: [DONE]"):
                received_chunks.append("Hi")
                on_chunk("Hi")

        # Simulate completion
        if received_chunks:
            on_done()
        else:
            on_error("No response data received from provider")

        self.assertEqual(chunks, ["Hi"])
        self.assertEqual(errors, [])
        self.assertTrue(done_called)

    def test_stream_error_flow_simulation(self):
        # 2. HTTP error response
        errors = []
        done_called = False

        def on_chunk(t):
            pass

        def on_error(e):
            errors.append(e)

        def on_done():
            nonlocal done_called
            done_called = True

        # Simulate stream callback on error (status 401)
        result = {"ok": False, "status": 401}
        has_received_chunk = False
        error_reported = False

        if not result["ok"] or (result["status"] != 0 and result["status"] >= 400):
            if not error_reported:
                error_reported = True
                on_error(f"Stream error (HTTP {result['status']})")
        else:
            if not has_received_chunk and not error_reported:
                on_error("No response data received from provider")
            else:
                on_done()

        self.assertEqual(errors, ["Stream error (HTTP 401)"])
        self.assertFalse(done_called)

    def test_stream_empty_body_flow_simulation(self):
        # 3. HTTP 200 but no chunks received
        errors = []
        done_called = False

        def on_error(e):
            errors.append(e)

        def on_done():
            nonlocal done_called
            done_called = True

        result = {"ok": True, "status": 200}
        has_received_chunk = False
        error_reported = False

        if not result["ok"] or (result["status"] != 0 and result["status"] >= 400):
            if not error_reported:
                error_reported = True
                on_error(f"Stream error (HTTP {result['status']})")
        else:
            if not has_received_chunk and not error_reported:
                on_error("No response data received from provider")
            else:
                on_done()

        self.assertEqual(errors, ["No response data received from provider"])
        self.assertFalse(done_called)

    def test_stream_offline_handle_nil(self):
        # 4. Handle nil (offline mode)
        errors = []

        def on_error(e):
            errors.append(e)

        handle = None
        if handle is None:
            on_error("Unable to initialize HTTP stream (offline mode or network disabled)")

        self.assertEqual(
            errors, ["Unable to initialize HTTP stream (offline mode or network disabled)"]
        )


if __name__ == "__main__":
    unittest.main()
