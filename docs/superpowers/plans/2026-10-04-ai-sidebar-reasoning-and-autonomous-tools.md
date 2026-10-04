# AI Sidebar Reasoning UI & Autonomous Tool Calling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement reasoning token streaming with collapsible thinking UI, autonomous web search tool calling, toolbar button for slash commands, and keyboard navigation for popovers in `ai-sidebar`.

**Architecture:** Extend provider stream parsers (`custom.luau`, `openai.luau`, `gemini.luau`) to separate reasoning tokens (`reasoning_content` and `<think>` tags) and extract `tool_calls`. Update `client.luau` to orchestrate autonomous tool execution and multi-pass streaming. In `panel.luau`, render an interactive thinking accordion, a `/` slash command button, capture keys (`Escape`, `Up`, `Down`, `Tab`) for popover navigation, and add a master web search toggle in Settings.

**Tech Stack:** Luau, Noctalia Plugin API v28, Python 3 unittest, JSON SSE stream parsing.

## Global Constraints
* Preserve custom system prompts, user personas, and conversational style unconditionally.
* Support both `delta.reasoning_content` (Ollama/DeepSeek/vLLM/OpenRouter) and inline `<think>...</think>` tags.
* Copy action on assistant messages copies ONLY `msg.content`, never raw thinking tokens.
* Bound autonomous search to a maximum of 1 tool call round-trip per turn.
* Retain panel open state on settings save (`syncToml = false`).
* All unit tests in `tests/test_*.py` must pass at every task boundary.

---

### Task 1: Update Storage Data Model & Translations

**Files:**
- Modify: `ai-sidebar/storage.luau:10-50`
- Modify: `ai-sidebar/translations/en.json`
- Modify: `ai-sidebar/translations/id.json`
- Create: `tests/test_ai_sidebar_reasoning_and_tools.py`

**Interfaces:**
- Produces: `storage.Message` with `reasoning: string?`, `reasoningDurationMs: number?`, `tool_calls: { any }?`, `tool_call_id: string?`.
- Produces: Translation keys for thinking UI, slash command toolbar button, and web search toggle state.

- [ ] **Step 1: Write failing unit tests for storage message extensions and translation keys**

```python
# tests/test_ai_sidebar_reasoning_and_tools.py
import unittest
import json
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent

class TestAIReasoningAndToolsStorage(unittest.TestCase):
    def test_storage_message_type_contains_reasoning_fields(self):
        storage_path = REPO_ROOT / "ai-sidebar" / "storage.luau"
        content = storage_path.read_text(encoding="utf-8")
        self.assertIn("reasoning: string?", content)
        self.assertIn("reasoningDurationMs: number?", content)
        self.assertIn("tool_calls: { any }?", content)
        self.assertIn("tool_call_id: string?", content)

    def test_translations_contain_reasoning_and_toolbar_keys(self):
        en_path = REPO_ROOT / "ai-sidebar" / "translations" / "en.json"
        id_path = REPO_ROOT / "ai-sidebar" / "translations" / "id.json"
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_trans = json.load(f)

        required_keys = [
            "thinking_active",
            "thinking_done",
            "thinking_seconds",
            "action_slash_commands",
            "search_disabled_notice",
        ]
        for key in required_keys:
            self.assertIn(key, en, f"Missing {key} in en.json")
            self.assertIn(key, id_trans, f"Missing {key} in id.json")

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: FAIL (fields missing from `storage.luau` and translation keys missing)

- [ ] **Step 3: Implement storage type extensions and translations**

Update `ai-sidebar/storage.luau`:
```luau
export type Message = {
  role: string, -- "user" | "assistant" | "system" | "tool"
  content: string,
  timestamp: number?,
  metrics: MessageMetrics?,
  reasoning: string?,
  reasoningDurationMs: number?,
  tool_calls: { any }?,
  tool_call_id: string?,
}
```

Update `ai-sidebar/translations/en.json`:
```json
  "thinking_active": "Thinking...",
  "thinking_done": "Thought for {sec}s",
  "thinking_seconds": "{sec}s",
  "action_slash_commands": "Slash Commands",
  "search_disabled_notice": "Web search is disabled in Settings"
```

Update `ai-sidebar/translations/id.json`:
```json
  "thinking_active": "Sedang berpikir...",
  "thinking_done": "Telah berpikir selama {sec} detik",
  "thinking_seconds": "{sec} dtk",
  "action_slash_commands": "Perintah Slash",
  "search_disabled_notice": "Pencarian web dinonaktifkan di Pengaturan"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/storage.luau ai-sidebar/translations/en.json ai-sidebar/translations/id.json tests/test_ai_sidebar_reasoning_and_tools.py
git commit -m "feat(ai-sidebar): extend storage message schema and add translations for reasoning and tools"
```

---

### Task 2: Provider Stream Parsers for Reasoning & Tool Calls

**Files:**
- Modify: `ai-sidebar/providers/custom.luau`
- Modify: `ai-sidebar/providers/openai.luau`
- Modify: `ai-sidebar/providers/gemini.luau`
- Modify: `tests/test_ai_sidebar_reasoning_and_tools.py`

**Interfaces:**
- Produces: `parseStreamEvent(line: string, state: any?): { type: "content"|"reasoning"|"tool_call"|"done", text: string?, toolCalls: { any }? }?`
- Produces: `buildChatRequest` with `tools` definition when `config.enable_web_search == true`.

- [ ] **Step 1: Write failing unit tests for reasoning and tool call stream parsing**

Add to `tests/test_ai_sidebar_reasoning_and_tools.py`:
```python
    def test_custom_provider_includes_tools_when_search_enabled(self):
        custom_path = REPO_ROOT / "ai-sidebar" / "providers" / "custom.luau"
        content = custom_path.read_text(encoding="utf-8")
        self.assertIn("web_search", content)
        self.assertIn("parseStreamEvent", content)

    def test_openai_provider_includes_tools_and_reasoning_parsing(self):
        openai_path = REPO_ROOT / "ai-sidebar" / "providers" / "openai.luau"
        content = openai_path.read_text(encoding="utf-8")
        self.assertIn("web_search", content)
        self.assertIn("parseStreamEvent", content)

    def test_gemini_provider_handles_thinking_parts(self):
        gemini_path = REPO_ROOT / "ai-sidebar" / "providers" / "gemini.luau"
        content = gemini_path.read_text(encoding="utf-8")
        self.assertIn("thought", content)
        self.assertIn("parseStreamEvent", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: FAIL (`parseStreamEvent` not found in providers)

- [ ] **Step 3: Implement `tools` attachment and `parseStreamEvent` in providers**

1. In `custom.luau`:
   - In `buildChatRequest`: if `config and config.enable_web_search == true`, attach `bodyObj.tools = { { type = "function", function = { name = "web_search", description = "Search the live web for real-time information, recent events, facts, documentation, or queries needing current data.", parameters = { type = "object", properties = { query = { type = "string", description = "Targeted search keywords" } }, required = { "query" } } } } }`.
   - Implement `custom.parseStreamEvent(line: string, state: any?)`:
     - Checks `data: [DONE]` -> `{ type = "done" }`.
     - Decodes JSON:
       - If `choice.delta.reasoning_content` or `choice.delta.reasoning` -> `{ type = "reasoning", text = val }`.
       - If `choice.delta.tool_calls` -> `{ type = "tool_call", toolCalls = choice.delta.tool_calls }`.
       - If `choice.delta.content`:
         Handle `<think>` and `</think>` tags:
         If `state.inThink`:
           Check if `content` contains `</think>`. Split tokens before `</think>` as `reasoning`, transition `state.inThink = false`, and tokens after as `content`.
         Else if `content` contains `<think>`:
           Transition `state.inThink = true`, route inside `<think>` to `reasoning`.
         Else: return `{ type = "content", text = choice.delta.content }`.
   - Maintain backward-compatible `custom.parseStreamLine(line: string): string?` that delegates to `parseStreamEvent`.

2. In `openai.luau`:
   - Similarly attach `tools` when `config.enable_web_search == true`.
   - Implement `openai.parseStreamEvent(line: string, state: any?)` with `reasoning_content`, `tool_calls`, and `<think>` detection.
   - Maintain `openai.parseStreamLine(line: string): string?`.

3. In `gemini.luau`:
   - Implement `gemini.parseStreamEvent(line: string, state: any?)`:
     - If `cand.content.parts`: inspect `part.thought == true` -> `{ type = "reasoning", text = part.text }`.
     - If normal text -> `{ type = "content", text = part.text }`.
     - If `part.functionCall` -> `{ type = "tool_call", toolCalls = { { id = "gemini_call", function = { name = part.functionCall.name, arguments = noctalia.json.encode(part.functionCall.args) } } } }`.
   - Maintain `gemini.parseStreamLine(line: string): string?`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/providers/custom.luau ai-sidebar/providers/openai.luau ai-sidebar/providers/gemini.luau tests/test_ai_sidebar_reasoning_and_tools.py
git commit -m "feat(ai-sidebar): implement dual-format reasoning and tool calls parsing in providers"
```

---

### Task 3: Client Autonomous Tool Execution & Streaming Coordinator

**Files:**
- Modify: `ai-sidebar/client.luau`
- Modify: `tests/test_ai_sidebar_reasoning_and_tools.py`

**Interfaces:**
- Consumes: `prov.parseStreamEvent(line, state)`
- Consumes: `search.performSearch(query, config, callback)`
- Produces: `client.streamChat` with callbacks for content, reasoning, tool execution status, and follow-up grounded synthesis.

- [ ] **Step 1: Write failing unit tests for client autonomous tool execution and reasoning stream callbacks**

Add to `tests/test_ai_sidebar_reasoning_and_tools.py`:
```python
    def test_client_stream_chat_supports_reasoning_and_tools(self):
        client_path = REPO_ROOT / "ai-sidebar" / "client.luau"
        content = client_path.read_text(encoding="utf-8")
        self.assertIn("onReasoning", content)
        self.assertIn("web_search", content)
        self.assertIn("performSearch", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: FAIL (`onReasoning` not yet in `client.luau`)

- [ ] **Step 3: Implement reasoning and autonomous tool calling in `client.luau`**

1. Update `client.streamChat`:
   - Signature:
     ```luau
     function client.streamChat(
       messages: { any },
       config: any,
       onChunk: (text: string) -> (),
       onError: (err: string) -> (),
       onDone: () -> (),
       onStatus: ((status: string, attempt: number, maxRetries: number) -> ())?,
       searchContext: string?,
       isSlashSearch: boolean?,
       onReasoning: ((text: string) -> ())?,
       onToolStatus: ((statusText: string) -> ())?
     ): any
     ```
2. State & Streaming Event Loop:
   - Initialize `parserState = { inThink = false }`.
   - Maintain `accumulatedToolCalls = {}`.
   - When `prov.parseStreamEvent(line, parserState)` returns:
     - `type == "reasoning"`: call `onReasoning(event.text)`.
     - `type == "content"`: call `onChunk(event.text)`.
     - `type == "tool_call"`: accumulate tool call fragments by index/id.
3. Stream Completion & Tool Execution:
   - In stream finish callback:
     - If `accumulatedToolCalls` has a `web_search` call (and we haven't already performed a tool hop in this turn):
       - Extract query from tool call arguments (parse JSON).
       - Notify `onToolStatus("🔍 " .. tr("status_searching_web") .. ": \"" .. query .. "\"")`.
       - Invoke `search.performSearch(query, config, function(okSearch, contextBlock, _err) ... )`.
       - On search completion:
         - Append assistant message with `tool_calls` to conversation.
         - Append tool result message `{ role = "tool", tool_call_id = callId, content = contextBlock or "No search results found" }`.
         - Trigger second-pass stream with `isSecondPass = true` so model synthesizes final grounded answer.
     - Else: call `onDone()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_reasoning_and_tools.py
git commit -m "feat(ai-sidebar): implement autonomous tool calling and reasoning stream handling in client"
```

---

### Task 4: UI Thinking Accordion, Slash Button & Keyboard Navigation

**Files:**
- Modify: `ai-sidebar/plugin.toml`
- Modify: `ai-sidebar/panel.luau`
- Modify: `tests/test_ai_sidebar_reasoning_and_tools.py`

**Interfaces:**
- Produces: Slash command toolbar button (`glyph = "slash"`, toggling `showSlashPicker`).
- Produces: Popover keyboard navigation via `onKey("Escape" | "Up" | "Down" | "Tab", pressed)`.
- Produces: Thinking Accordion UI rendering `msg.reasoning` with expandable duration and live timer.
- Produces: Master Settings Toggle for `enable_web_search`.

- [ ] **Step 1: Write failing unit tests for panel UI features**

Add to `tests/test_ai_sidebar_reasoning_and_tools.py`:
```python
    def test_plugin_toml_has_capture_keys(self):
        toml_path = REPO_ROOT / "ai-sidebar" / "plugin.toml"
        content = toml_path.read_text(encoding="utf-8")
        self.assertIn("capture_keys", content)
        self.assertIn("Escape", content)
        self.assertIn("Tab", content)

    def test_panel_has_on_key_and_slash_button(self):
        panel_path = REPO_ROOT / "ai-sidebar" / "panel.luau"
        content = panel_path.read_text(encoding="utf-8")
        self.assertIn("function onKey(", content)
        self.assertIn("showSlashPicker", content)
        self.assertIn("expandedThinking", content)
        self.assertIn("enable_web_search", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: FAIL (`capture_keys`, `onKey`, `showSlashPicker`, `expandedThinking` not yet present)

- [ ] **Step 3: Implement panel and manifest updates**

1. In `ai-sidebar/plugin.toml`:
   Under `[[panel]]`:
   ```toml
   capture_keys = ["Escape", "Up", "Down", "Tab"]
   ```

2. In `ai-sidebar/panel.luau`:
   - State variables:
     - `showSlashPicker = false`
     - `selectedSlashIndex = 1`
     - `selectedPromptIndex = 1`
     - `expandedThinking: { [number]: boolean } = {}`
     - `isThinkingActive = false`
     - `thinkingStartMs = 0`
   - In `actionButtons`:
     - Add slash command button:
       ```luau
       table.insert(actionButtons, ui.button({
         glyph = "slash",
         variant = showSlashPicker and "primary" or "ghost",
         tooltip = tr("action_slash_commands"),
         onClick = function()
           showSlashPicker = not showSlashPicker
           if showSlashPicker then showPromptPicker = false end
           render()
         end,
       }))
       ```
   - Implement global `onKey(chord: string, pressed: boolean)`:
     - If `pressed == true`:
       - If popover active (`showSlashPicker` or `isSlashActive`):
         - `chord == "Down"`: `selectedSlashIndex = (selectedSlashIndex % #matchingSlashCommands) + 1; render()`
         - `chord == "Up"`: `selectedSlashIndex = ((selectedSlashIndex - 2 + #matchingSlashCommands) % #matchingSlashCommands) + 1; render()`
         - `chord == "Tab"`: select item at `selectedSlashIndex`
         - `chord == "Escape"`: `showSlashPicker = false; render()`
       - If prompt picker active (`showPromptPicker` or `isPromptActive`):
         - Arrow Up/Down navigates `selectedPromptIndex`.
         - Tab selects item at `selectedPromptIndex`.
         - Escape closes prompt picker.
   - In `onSubmit` of `ui.input`:
     - If slash popover is active: apply selected slash command instead of `sendMessage()`.
     - If prompt popover is active: apply selected prompt instead of `sendMessage()`.
     - Else: `sendMessage()`.
   - In assistant message rendering:
     - If `msg.reasoning and msg.reasoning ~= ""` (or `isThinkingActive` for last assistant):
       - Render collapsible accordion box:
         - Header: `🧠 [thinking title with duration]` + toggle glyph `chevron-down` / `chevron-up`.
         - Content (when `expandedThinking[idx]` is true):
           `ui.markdown({ text = msg.reasoning })` in muted text.
   - In Settings Tab:
     - Add master toggle switch: `Aktifkan Pencarian Web` (`enable_web_search`).
     - When toggled, updates `config.enable_web_search`.
     - If false, dim or hide search provider details.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_reasoning_and_tools.py`
Expected: PASS

- [ ] **Step 5: Run full test suite for regression verification**

Run: `python3 -m unittest discover -s tests -p "test_*.py"`
Expected: ALL PASS (100% test passing)

- [ ] **Step 6: Commit changes**

```bash
git add ai-sidebar/plugin.toml ai-sidebar/panel.luau tests/test_ai_sidebar_reasoning_and_tools.py
git commit -m "feat(ai-sidebar): add thinking accordion UI, slash button, popover keybinds, and web search toggle"
```

---

### Task 5: Integration & End-to-End Verification

**Files:**
- Modify: `tests/test_ai_sidebar_reasoning_and_tools.py`

- [ ] **Step 1: Write integration tests covering edge cases**
  - Model without reasoning: renders normal markdown immediately.
  - Web search disabled in settings: slash command informs user, model receives no tools.
  - Arrow navigation clamp and wrap-around.
  - Copy button text isolation (ensure `msg.content` is copied, excluding `msg.reasoning`).

- [ ] **Step 2: Run test suite**
  Run: `python3 -m unittest discover -s tests -p "test_*.py"`
  Expected: ALL PASS

- [ ] **Step 3: Commit final test verifications**
```bash
git add tests/test_ai_sidebar_reasoning_and_tools.py
git commit -m "test(ai-sidebar): add integration and edge case tests for reasoning and tools"
```
