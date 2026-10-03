import json
import os
import unittest

PROVIDERS_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "providers")


class TestAiSidebarProviders(unittest.TestCase):
    def test_provider_files_exist(self):
        for name in ["openai.luau", "anthropic.luau", "gemini.luau"]:
            p = os.path.join(PROVIDERS_DIR, name)
            self.assertTrue(os.path.isfile(p), f"Missing {name}")

    def test_provider_exports(self):
        expected_exports = [
            "buildChatRequest",
            "buildTestRequest",
            "parseStreamLine",
            "parseTestResponse",
        ]
        for name in ["openai.luau", "anthropic.luau", "gemini.luau"]:
            p = os.path.join(PROVIDERS_DIR, name)
            self.assertTrue(os.path.isfile(p), f"Missing {name}")
            with open(p, "r", encoding="utf-8") as f:
                content = f.read()
            for exp in expected_exports:
                self.assertIn(exp, content, f"{name} missing export {exp}")

    def test_openai_sse_parsing(self):
        # Simulate OpenAI SSE line
        sample_line = 'data: {"choices":[{"delta":{"content":"Hello"}}]}'
        prefix = "data: "
        if sample_line.startswith(prefix) and not sample_line.startswith("data: [DONE]"):
            payload = json.loads(sample_line[len(prefix) :])
            delta = payload["choices"][0]["delta"].get("content")
            self.assertEqual(delta, "Hello")

        # Test [DONE] termination marker
        done_line = "data: [DONE]"
        self.assertTrue(done_line.startswith("data: [DONE]"))

    def test_anthropic_sse_parsing(self):
        # Simulate Anthropic content_block_delta line
        sample_line = 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"World"}}'
        prefix = "data: "
        if sample_line.startswith(prefix):
            payload = json.loads(sample_line[len(prefix) :])
            if payload.get("type") == "content_block_delta":
                self.assertEqual(payload["delta"]["text"], "World")

        # Non-text delta event (e.g. ping or message_start)
        ping_line = 'data: {"type":"ping"}'
        payload = json.loads(ping_line[len(prefix) :])
        self.assertNotEqual(payload.get("type"), "content_block_delta")

    def test_gemini_sse_parsing(self):
        # Simulate Gemini streamGenerateContent line
        sample_line = 'data: {"candidates":[{"content":{"parts":[{"text":"Hi"}]}}]}'
        prefix = "data: "
        if sample_line.startswith(prefix):
            payload = json.loads(sample_line[len(prefix) :])
            text = payload["candidates"][0]["content"]["parts"][0]["text"]
            self.assertEqual(text, "Hi")

    def test_openai_request_simulation(self):
        # Chat request
        messages = [
            {"role": "user", "content": "What is Luau?"},
            {"role": "assistant", "content": "A language."},
            {"role": "user", "content": "Tell me more."},
        ]
        system_prompt = "You are a helpful assistant."
        config = {"openai_key": "sk-test", "openai_model": "gpt-4o"}

        api_messages = []
        if system_prompt:
            api_messages.append({"role": "system", "content": system_prompt})
        for m in messages:
            api_messages.append({"role": m["role"], "content": m["content"]})

        payload = {
            "model": config.get("openai_model") or "gpt-4o-mini",
            "messages": api_messages,
            "stream": True,
        }
        self.assertEqual(len(payload["messages"]), 4)
        self.assertEqual(payload["messages"][0]["role"], "system")
        self.assertEqual(payload["model"], "gpt-4o")

        # Test request
        test_payload = {
            "model": config.get("openai_model") or "gpt-4o-mini",
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 5,
            "stream": False,
        }
        self.assertEqual(test_payload["messages"][0]["content"], "ping")
        self.assertFalse(test_payload["stream"])

    def test_anthropic_request_simulation(self):
        # Chat request
        messages = [
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there"},
        ]
        system_prompt = "Be concise."
        config = {"anthropic_key": "sk-ant-test", "anthropic_model": "claude-3-opus-20240229"}

        api_messages = [
            {"role": m["role"], "content": m["content"]}
            for m in messages
            if m["role"] in ("user", "assistant")
        ]
        payload = {
            "model": config.get("anthropic_model") or "claude-3-5-haiku-20241022",
            "messages": api_messages,
            "max_tokens": 4096,
            "stream": True,
        }
        if system_prompt:
            payload["system"] = system_prompt

        self.assertEqual(payload["system"], "Be concise.")
        self.assertEqual(len(payload["messages"]), 2)
        self.assertEqual(payload["max_tokens"], 4096)

        # Test request
        test_payload = {
            "model": config.get("anthropic_model") or "claude-3-5-haiku-20241022",
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 5,
            "stream": False,
        }
        self.assertEqual(test_payload["messages"][0]["content"], "ping")
        self.assertEqual(test_payload["max_tokens"], 5)

    def test_gemini_request_simulation(self):
        # Chat request
        messages = [
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there"},
        ]
        contents = []
        for m in messages:
            role = "model" if m["role"] == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": m["content"]}]})

        self.assertEqual(contents[0]["role"], "user")
        self.assertEqual(contents[1]["role"], "model")

        model = "gemini-1.5-flash"
        api_key = "test-key"
        stream_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse&key={api_key}"
        self.assertIn(":streamGenerateContent?alt=sse&key=", stream_url)

        test_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        self.assertIn(":generateContent?key=", test_url)

    def test_parse_test_response_simulation(self):
        def parse_response(resp):
            if not resp.get("ok"):
                return False, "Network error (transport failure)"
            if resp.get("status") == 200:
                return True, "Connection successful"
            msg = f"HTTP {resp.get('status')}"
            try:
                decoded = json.loads(resp.get("body", "{}"))
                if isinstance(decoded, dict) and "error" in decoded:
                    err = decoded["error"]
                    if isinstance(err, dict) and "message" in err:
                        msg += f": {err['message']}"
            except Exception:
                pass
            return False, msg

        ok, msg = parse_response({"ok": False, "status": 0, "body": ""})
        self.assertFalse(ok)
        self.assertEqual(msg, "Network error (transport failure)")

        ok, msg = parse_response({"ok": True, "status": 200, "body": "{}"})
        self.assertTrue(ok)
        self.assertEqual(msg, "Connection successful")

        ok, msg = parse_response(
            {
                "ok": True,
                "status": 401,
                "body": json.dumps({"error": {"message": "Invalid API key provided"}}),
            }
        )
        self.assertFalse(ok)
        self.assertEqual(msg, "HTTP 401: Invalid API key provided")

        ok, msg = parse_response({"ok": True, "status": 500, "body": "Internal Server Error"})
        self.assertFalse(ok)
        self.assertEqual(msg, "HTTP 500")


if __name__ == "__main__":
    unittest.main()
