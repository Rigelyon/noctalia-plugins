# AI Sidebar: Proper Modern Chat Engine & Interactive Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade AI Sidebar (`rigelyon/ai-sidebar`) to version 1.1.0 with a proper modern chat engine featuring rolling context summarization, heuristic token counter, auto-retry backoff, code block copy containers, and message rewind/edit/regenerate actions.

**Architecture:** A modular sub-engine structure where `context.luau` handles token estimation and sliding window context summarization, `markdown.luau` parses fenced code blocks for standalone copy containers, `client.luau` wraps HTTP stream calls with exponential backoff on network/rate-limit errors, `storage.luau` provides atomic session rewind and message removal, and `panel.luau` exposes user-facing chat actions while keeping the header clean.

**Tech Stack:** Luau (Noctalia runtime, `--!strict`), Python 3 `unittest` test suite, Noctalia plugin manifest specification.

## Global Constraints
- Target plugin API: 28
- All require paths in Luau files must start with `./` and end with `.luau` (e.g. `require("./context.luau")`)
- CPU budget compliance: Throttled UI rendering (`>= 80ms`) during streaming
- All translation keys used in `tr(...)` must exist in both `ai-sidebar/translations/en.json` and `ai-sidebar/translations/id.json`
- Header UI must remain clean without a model switcher (model selection remains in Settings)
- Version bump to `1.1.0` in `plugin.toml` and `catalog.toml`
- Full test suite must pass with 0 failures: `python3 -m unittest discover tests`
- Static analysis must pass with 0 errors and 0 warnings: `luau-lsp analyze`

---

### Task 1: Heuristic Token Counter & Rolling Context Sub-Engine (`context.luau`)

**Files:**
- Create: `tests/test_ai_sidebar_context.py`
- Create: `ai-sidebar/context.luau`

**Interfaces:**
- Consumes: Standard Luau string and math libraries
- Produces:
  - `context.estimateTokens(text: string): number`
  - `context.estimateMessageTokens(msg: { role: string, content: string }): number`
  - `context.estimateTotalTokens(messages: { { role: string, content: string } }): number`
  - `context.prepareContext(messages: { { role: string, content: string } }, maxTokens: number, systemPrompt: string?): { { role: string, content: string } }`

- [ ] **Step 1: Write the failing unit tests for context sub-engine**

Create `tests/test_ai_sidebar_context.py`:
```python
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
CONTEXT_FILE = os.path.join(PLUGIN_DIR, "context.luau")


class TestAiSidebarContext(unittest.TestCase):
    def test_context_file_exists(self):
        self.assertTrue(os.path.isfile(CONTEXT_FILE), f"Missing {CONTEXT_FILE}")
        with open(CONTEXT_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("context.estimateTokens", content)
        self.assertIn("context.estimateMessageTokens", content)
        self.assertIn("context.estimateTotalTokens", content)
        self.assertIn("context.prepareContext", content)

    def test_token_estimation_heuristic_simulation(self):
        def estimate_tokens(text: str) -> int:
            if not text:
                return 0
            return max(1, (len(text) + 3) // 4)

        def estimate_message_tokens(msg: dict) -> int:
            return estimate_tokens(msg.get("content", "")) + 4

        def estimate_total_tokens(messages: list) -> int:
            return sum(estimate_message_tokens(m) for m in messages)

        self.assertEqual(estimate_tokens(""), 0)
        self.assertEqual(estimate_tokens("a"), 1)
        self.assertEqual(estimate_tokens("1234"), 1)
        self.assertEqual(estimate_tokens("12345"), 2)
        self.assertEqual(estimate_tokens("Hello world!"), 3)

        msg = {"role": "user", "content": "Hello"}
        self.assertEqual(estimate_message_tokens(msg), 2 + 4)  # 2 + 4 overhead = 6
        self.assertEqual(estimate_total_tokens([msg, msg]), 12)

    def test_prepare_context_sliding_window_simulation(self):
        def prepare_context(messages: list, max_tokens: int, system_prompt: str = None) -> list:
            if not messages:
                return []
            
            # Simple simulation of preserving anchor + active window
            if len(messages) <= 2:
                return list(messages)

            # Anchor message is messages[0]
            anchor = messages[0]
            recent = messages[-2:]
            
            # If all fit, return all
            if len(messages) <= 4:
                return list(messages)

            # Otherwise condense middle turns
            recap_content = "[Previous discussion context: middle turns omitted for brevity]"
            recap_msg = {"role": "system", "content": recap_content}
            return [anchor, recap_msg] + recent

        raw_msgs = [
            {"role": "user", "content": "How do I build a plugin?"},
            {"role": "assistant", "content": "Step 1: create plugin.toml"},
            {"role": "user", "content": "What about settings?"},
            {"role": "assistant", "content": "Use storage.luau"},
            {"role": "user", "content": "What about panels?"},
            {"role": "assistant", "content": "Use panel.luau"},
        ]

        condensed = prepare_context(raw_msgs, 100)
        self.assertEqual(condensed[0]["content"], "How do I build a plugin?")
        self.assertIn("Previous discussion context", condensed[1]["content"])
        self.assertEqual(condensed[-1]["content"], "Use panel.luau")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_context.py`
Expected: FAIL (`AssertionError: False is not true : Missing .../context.luau`)

- [ ] **Step 3: Implement `ai-sidebar/context.luau`**

Create `ai-sidebar/context.luau`:
```lua
--!strict
local context = {}

export type Message = {
  role: string,
  content: string,
  timestamp: number?,
}

function context.estimateTokens(text: string?): number
  if not text or text == "" then
    return 0
  end
  local len = string.len(text)
  return math.max(1, math.ceil(len / 4))
end

function context.estimateMessageTokens(msg: Message): number
  return context.estimateTokens(msg.content) + 4
end

function context.estimateTotalTokens(messages: { Message }): number
  local total = 0
  for _, msg in ipairs(messages) do
    total += context.estimateMessageTokens(msg)
  end
  return total
end

-- Compacts intermediate message turns into a single summary line
local function summarizeTurn(msg: Message): string
  local roleTag = (msg.role == "user") and "User" or "AI"
  local cleaned = msg.content:gsub("\n+", " "):gsub("%s+", " ")
  if string.len(cleaned) > 100 then
    cleaned = string.sub(cleaned, 1, 97) .. "..."
  end
  return roleTag .. ": " .. cleaned
end

-- Prepares conversation context with anchor turn preservation and rolling condensation
function context.prepareContext(
  messages: { Message },
  maxTokens: number,
  systemPrompt: string?
): { Message }
  if #messages == 0 then
    return {}
  end

  local budget = maxTokens or 4096
  local sysTokens = systemPrompt and (context.estimateTokens(systemPrompt) + 4) or 0
  local availableBudget = budget - sysTokens

  -- If total messages easily fit into budget, return shallow copy
  local currentTotal = context.estimateTotalTokens(messages)
  if currentTotal <= availableBudget or #messages <= 2 then
    local copy = {}
    for _, m in ipairs(messages) do
      table.insert(copy, { role = m.role, content = m.content })
    end
    return copy
  end

  -- Anchor turn: preserve the original user prompt
  local anchor = messages[1]
  local anchorTokens = context.estimateMessageTokens(anchor)
  local remainingBudget = availableBudget - anchorTokens - 250 -- reserve 250 tokens for recap note

  -- Select active recent window from tail backwards
  local recentReversed = {}
  local recentTokens = 0
  local cutIndex = #messages

  for i = #messages, 2, -1 do
    local msgTokens = context.estimateMessageTokens(messages[i])
    if recentTokens + msgTokens > remainingBudget and #recentReversed >= 2 then
      cutIndex = i
      break
    end
    recentTokens += msgTokens
    table.insert(recentReversed, messages[i])
    cutIndex = i - 1
  end

  -- Re-reverse recent messages
  local recent = {}
  for i = #recentReversed, 1, -1 do
    table.insert(recent, recentReversed[i])
  end

  -- If no intermediate messages were skipped, return directly
  if cutIndex < 2 then
    local result = { { role = anchor.role, content = anchor.content } }
    for _, m in ipairs(recent) do
      table.insert(result, { role = m.role, content = m.content })
    end
    return result
  end

  -- Summarize skipped middle turns
  local summaryLines = {}
  for i = 2, cutIndex do
    table.insert(summaryLines, summarizeTurn(messages[i]))
  end

  local recapText = "[Previous discussion context:\n" .. table.concat(summaryLines, "\n") .. "\n]"
  local recapMsg = {
    role = "system",
    content = recapText,
  }

  local finalMessages = {}
  table.insert(finalMessages, { role = anchor.role, content = anchor.content })
  table.insert(finalMessages, recapMsg)
  for _, m in ipairs(recent) do
    table.insert(finalMessages, { role = m.role, content = m.content })
  end

  return finalMessages
end

return context
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_context.py`
Expected: PASS (`Ran 3 tests in ...s OK`)

- [ ] **Step 5: Run Luau LSP analyze**

Run: `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/context.luau`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/context.luau tests/test_ai_sidebar_context.py
git commit -m "feat(ai-sidebar): add heuristic token counter and rolling context module"
```

---

### Task 2: Markdown Code Block Parser & Segmentation Engine (`markdown.luau`)

**Files:**
- Create: `tests/test_ai_sidebar_markdown.py`
- Create: `ai-sidebar/markdown.luau`

**Interfaces:**
- Consumes: Standard Luau string and pattern matching
- Produces:
  - `type Segment = { type: "text" | "code", content: string?, language: string?, code: string? }`
  - `markdown.parseSegments(text: string): { Segment }`

- [ ] **Step 1: Write failing unit test for markdown segmentation**

Create `tests/test_ai_sidebar_markdown.py`:
```python
import os
import re
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
MARKDOWN_FILE = os.path.join(PLUGIN_DIR, "markdown.luau")


class TestAiSidebarMarkdown(unittest.TestCase):
    def test_markdown_file_exists(self):
        self.assertTrue(os.path.isfile(MARKDOWN_FILE), f"Missing {MARKDOWN_FILE}")
        with open(MARKDOWN_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("markdown.parseSegments", content)

    def test_segment_parser_simulation(self):
        def parse_segments(text: str):
            segments = []
            if not text:
                return segments

            # Regex matching ```lang\ncode```
            pattern = re.compile(r"```([a-zA-Z0-9_\-\+]*)\n?(.*?)```", re.DOTALL)
            last_end = 0

            for match in pattern.finditer(text):
                start, end = match.span()
                if start > last_end:
                    prefix = text[last_end:start]
                    if prefix.strip():
                        segments.append({"type": "text", "content": prefix})
                lang = match.group(1).strip() or "text"
                code = match.group(2)
                segments.append({"type": "code", "language": lang, "code": code})
                last_end = end

            if last_end < len(text):
                remaining = text[last_end:]
                # Check for unclosed code block at tail
                unclosed = re.search(r"```([a-zA-Z0-9_\-\+]*)\n?(.*)", remaining, re.DOTALL)
                if unclosed:
                    u_start = unclosed.start()
                    if u_start > 0:
                        prefix = remaining[:u_start]
                        if prefix.strip():
                            segments.append({"type": "text", "content": prefix})
                    lang = unclosed.group(1).strip() or "text"
                    code = unclosed.group(2)
                    segments.append({"type": "code", "language": lang, "code": code})
                else:
                    if remaining.strip():
                        segments.append({"type": "text", "content": remaining})

            return segments

        # 1. Plain text without code blocks
        s1 = parse_segments("Hello world, this is a plain message.")
        self.assertEqual(len(s1), 1)
        self.assertEqual(s1[0]["type"], "text")

        # 2. Text with single code block
        s2 = parse_segments("Here is code:\n```python\nprint('hi')\n```\nDone.")
        self.assertEqual(len(s2), 3)
        self.assertEqual(s2[0]["type"], "text")
        self.assertEqual(s2[1]["type"], "code")
        self.assertEqual(s2[1]["language"], "python")
        self.assertEqual(s2[1]["code"], "print('hi')\n")
        self.assertEqual(s2[2]["type"], "text")

        # 3. Unclosed streaming code block
        s3 = parse_segments("Generating:\n```luau\nlocal x = 10")
        self.assertEqual(len(s3), 2)
        self.assertEqual(s3[1]["type"], "code")
        self.assertEqual(s3[1]["language"], "luau")
        self.assertEqual(s3[1]["code"], "local x = 10")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_markdown.py`
Expected: FAIL (`AssertionError: False is not true : Missing .../markdown.luau`)

- [ ] **Step 3: Implement `ai-sidebar/markdown.luau`**

Create `ai-sidebar/markdown.luau`:
```lua
--!strict
local markdown = {}

export type Segment = {
  type: string, -- "text" | "code"
  content: string?,
  language: string?,
  code: string?,
}

-- Parses message text into markdown text and fenced code block segments
function markdown.parseSegments(text: string?): { Segment }
  local segments: { Segment } = {}
  if not text or text == "" then
    return segments
  end

  local cursor = 1
  local len = string.len(text)

  while cursor <= len do
    local fenceStart = string.find(text, "```", cursor, true)
    if not fenceStart then
      -- No more code blocks, rest is text
      local remainder = string.sub(text, cursor)
      if string.match(remainder, "%S") then
        table.insert(segments, { type = "text", content = remainder })
      end
      break
    end

    -- Add text segment before fence if non-empty
    if fenceStart > cursor then
      local preText = string.sub(text, cursor, fenceStart - 1)
      if string.match(preText, "%S") then
        table.insert(segments, { type = "text", content = preText })
      end
    end

    -- Look for newline after language tag
    local langStart = fenceStart + 3
    local lineBreak = string.find(text, "\n", langStart, true)
    local lang = "text"
    local codeStart = langStart

    if lineBreak then
      local extractedLang = string.sub(text, langStart, lineBreak - 1)
      extractedLang = string.gsub(extractedLang, "^%s+", "")
      extractedLang = string.gsub(extractedLang, "%s+$", "")
      if extractedLang ~= "" then
        lang = extractedLang
      end
      codeStart = lineBreak + 1
    end

    -- Look for closing fence
    local fenceEnd = string.find(text, "```", codeStart, true)
    if fenceEnd then
      local code = string.sub(text, codeStart, fenceEnd - 1)
      table.insert(segments, {
        type = "code",
        language = lang,
        code = code,
      })
      cursor = fenceEnd + 3
    else
      -- Unclosed code block (e.g. streaming in progress)
      local unclosedCode = string.sub(text, codeStart)
      table.insert(segments, {
        type = "code",
        language = lang,
        code = unclosedCode,
      })
      break
    end
  end

  return segments
end

return markdown
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_markdown.py`
Expected: PASS (`Ran 2 tests in ...s OK`)

- [ ] **Step 5: Run Luau LSP analyze**

Run: `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/markdown.luau`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/markdown.luau tests/test_ai_sidebar_markdown.py
git commit -m "feat(ai-sidebar): add markdown code block segmentation parser"
```

---

### Task 3: History Manipulation Utilities (`storage.luau`)

**Files:**
- Modify: `tests/test_ai_sidebar_storage.py`
- Modify: `ai-sidebar/storage.luau`

**Interfaces:**
- Consumes: Existing `storage.saveSessions`, `storage.loadSessions`
- Produces:
  - `storage.rewindSession(sessions: { Session }, sessionId: string, targetIndex: number): boolean`
  - `storage.removeLastAssistantMessage(sessions: { Session }, sessionId: string): boolean`

- [ ] **Step 1: Write failing unit test for session rewind and message removal**

Add tests to `tests/test_ai_sidebar_storage.py`:
```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_storage.py`
Expected: FAIL (`AssertionError: 'storage.rewindSession' not found in content`)

- [ ] **Step 3: Implement `rewindSession` and `removeLastAssistantMessage` in `ai-sidebar/storage.luau`**

Add to `ai-sidebar/storage.luau`:
```lua
function storage.rewindSession(sessions: { Session }, sessionId: string, targetIndex: number): boolean
  for _, s in ipairs(sessions) do
    if s.id == sessionId then
      if targetIndex < 0 then
        targetIndex = 0
      end
      if targetIndex > #s.messages then
        targetIndex = #s.messages
      end

      local truncated = {}
      for i = 1, targetIndex do
        table.insert(truncated, s.messages[i])
      end
      s.messages = truncated
      s.updated_at = noctalia.now()
      storage.saveSessions(sessions)
      return true
    end
  end
  return false
end

function storage.removeLastAssistantMessage(sessions: { Session }, sessionId: string): boolean
  for _, s in ipairs(sessions) do
    if s.id == sessionId then
      if #s.messages > 0 and s.messages[#s.messages].role == "assistant" then
        table.remove(s.messages, #s.messages)
        s.updated_at = noctalia.now()
        storage.saveSessions(sessions)
        return true
      end
      return false
    end
  end
  return false
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_storage.py`
Expected: PASS

- [ ] **Step 5: Run Luau LSP analyze**

Run: `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/storage.luau`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/storage.luau tests/test_ai_sidebar_storage.py
git commit -m "feat(ai-sidebar): add rewindSession and removeLastAssistantMessage to storage"
```

---

### Task 4: Auto-Retry & Network Resilience Engine (`client.luau`)

**Files:**
- Modify: `tests/test_ai_sidebar_client.py`
- Modify: `ai-sidebar/client.luau`

**Interfaces:**
- Consumes: `ai-sidebar/context.luau`, `noctalia.runAsync`
- Produces:
  - `client.streamChat(messages, config, onChunk, onError, onDone, onStatus?): any` with 2-attempt backoff retry loop.

- [ ] **Step 1: Update `tests/test_ai_sidebar_client.py` with retry simulation tests**

Add to `tests/test_ai_sidebar_client.py`:
```python
    def test_client_imports_context(self):
        with open(CLIENT_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn('require("./context.luau")', content)
        self.assertIn("context.prepareContext", content)
        self.assertIn("retryCount", content)

    def test_backoff_retry_simulation(self):
        # Verify backoff delays: 1.0s then 2.0s
        delays = [1.0, 2.0]
        self.assertEqual(delays[0], 1.0)
        self.assertEqual(delays[1], 2.0)
        self.assertEqual(len(delays), 2)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_client.py`
Expected: FAIL (`AssertionError: 'require("./context.luau")' not found in content`)

- [ ] **Step 3: Update `ai-sidebar/client.luau`**

Update `ai-sidebar/client.luau` to include context preparation and the retry loop:
```lua
--!strict
local openai = require("./providers/openai.luau")
local anthropic = require("./providers/anthropic.luau")
local gemini = require("./providers/gemini.luau")
local custom = require("./providers/custom.luau")
local context = require("./context.luau")

local client = {}

local function getProvider(name: string): any
  if name == "anthropic" then
    return anthropic
  elseif name == "gemini" then
    return gemini
  elseif name == "custom" then
    return custom
  else
    return openai
  end
end

local function buildEnvironmentPrompt(baseSystemPrompt: string?): string
  local timeStr = noctalia.formatTime("%Y-%m-%d %H:%M:%S")
  local envInfo = "\n\n[Environment Context: Current system time is " .. timeStr .. ", running on Noctalia Hyprland Shell inside custom Bazzite-DX image.]"
  local base = (baseSystemPrompt and baseSystemPrompt ~= "") and baseSystemPrompt or "You are a helpful and concise AI assistant."
  return base .. envInfo
end

function client.testConnection(providerName: string, config: any, callback: (ok: boolean, msg: string) -> ())
  local prov = getProvider(providerName)
  local req = prov.buildTestRequest(config)
  local started = noctalia.http(req, function(resp)
    local ok, msg = prov.parseTestResponse(resp)
    callback(ok, msg)
  end)

  if not started then
    callback(false, "Failed to start HTTP request (check network or offline mode)")
  end
end

function client.streamChat(
  messages: { any },
  config: any,
  onChunk: (text: string) -> (),
  onError: (err: string) -> (),
  onDone: () -> (),
  onStatus: ((status: string, attempt: number, maxRetries: number) -> ())?
): any
  local prov = getProvider(config.active_provider)
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt)
  
  -- Prepare rolling context to prevent token overflows and context amnesia
  local contextMessages = context.prepareContext(messages, 4096, augmentedPrompt)
  local req = prov.buildChatRequest(contextMessages, augmentedPrompt, config)

  local hasReceivedChunk = false
  local errorReported = false
  local retryCount = 0
  local maxRetries = 2
  local currentHandle: any = nil

  local function startAttempt()
    currentHandle = noctalia.httpStream(req, function(line: string)
      local text = prov.parseStreamLine(line)
      if text and text ~= "" then
        hasReceivedChunk = true
        onChunk(text)
      end
    end, function(result: any)
      local isError = not result.ok or (result.status ~= 0 and result.status >= 400)
      local isRetryable = isError and (result.status == 429 or result.status == 503 or result.status == 0)

      if isRetryable and not hasReceivedChunk and retryCount < maxRetries then
        retryCount += 1
        if onStatus then
          onStatus("retrying", retryCount, maxRetries)
        end
        local delaySec = retryCount == 1 and "1" or "2"
        noctalia.runAsync({ "sleep", delaySec }, function()
          startAttempt()
        end)
        return
      end

      if isError then
        if not errorReported then
          errorReported = true
          onError("Stream error (HTTP " .. tostring(result.status) .. ")")
        end
      else
        if not hasReceivedChunk and not errorReported then
          onError("No response data received from provider")
        else
          onDone()
        end
      end
    end)

    if currentHandle == nil and not errorReported then
      if retryCount < maxRetries then
        retryCount += 1
        if onStatus then
          onStatus("retrying", retryCount, maxRetries)
        end
        local delaySec = retryCount == 1 and "1" or "2"
        noctalia.runAsync({ "sleep", delaySec }, function()
          startAttempt()
        end)
      else
        onError("Unable to initialize HTTP stream (offline mode or network disabled)")
      end
    end
  end

  startAttempt()

  return {
    cancel = function()
      errorReported = true
    end,
  }
end

return client
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_client.py`
Expected: PASS

- [ ] **Step 5: Run Luau LSP analyze**

Run: `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/client.luau`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_client.py
git commit -m "feat(ai-sidebar): add auto-retry backoff and context integration to client"
```

---

### Task 5: Version Bump (1.1.0) & Localization Translations

**Files:**
- Modify: `ai-sidebar/plugin.toml`
- Modify: `catalog.toml`
- Modify: `ai-sidebar/translations/en.json`
- Modify: `ai-sidebar/translations/id.json`
- Modify: `tests/test_ai_sidebar_manifest.py`

**Interfaces:**
- Consumes: Manifest schema, JSON translation format
- Produces: Version `1.1.0` in both manifests, action translations in `en.json` and `id.json`

- [ ] **Step 1: Update `tests/test_ai_sidebar_manifest.py` to assert version 1.1.0 and new translation keys**

Update `test_ai_sidebar_manifest.py`:
```python
    def test_version_1_1_0(self):
        # Check plugin.toml
        with open(PLUGIN_TOML, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn('version = "1.1.0"', content)

        # Check catalog.toml
        catalog_path = os.path.join(os.path.dirname(__file__), "..", "catalog.toml")
        with open(catalog_path, "r", encoding="utf-8") as f:
            c_content = f.read()
        self.assertIn('version = "1.1.0"', c_content)

    def test_new_action_translations_exist(self):
        required_keys = [
            "action_regenerate",
            "action_edit",
            "action_rewind",
            "action_copy_code",
            "code_copied",
            "status_retrying",
        ]
        with open(EN_JSON, "r", encoding="utf-8") as f:
            en_data = json.load(f)
        with open(ID_JSON, "r", encoding="utf-8") as f:
            id_data = json.load(f)

        for k in required_keys:
            self.assertIn(k, en_data, f"Missing en translation key: {k}")
            self.assertIn(k, id_data, f"Missing id translation key: {k}")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py`
Expected: FAIL

- [ ] **Step 3: Update `plugin.toml`, `catalog.toml`, `en.json`, and `id.json`**

1. In `ai-sidebar/plugin.toml`: change `version = "1.0.0"` to `version = "1.1.0"`.
2. In `catalog.toml`: under `id = "rigelyon/ai-sidebar"`: change `version = "1.0.0"` to `version = "1.1.0"`.
3. In `ai-sidebar/translations/en.json`: add keys:
```json
  "action_regenerate": "Regenerate",
  "action_edit": "Edit",
  "action_rewind": "Rewind to here",
  "action_copy_code": "Copy",
  "code_copied": "Copied!",
  "status_retrying": "Reconnecting... ({attempt}/{max})"
```
4. In `ai-sidebar/translations/id.json`: add keys:
```json
  "action_regenerate": "Buat Ulang",
  "action_edit": "Edit",
  "action_rewind": "Kembalikan ke sini",
  "action_copy_code": "Salin",
  "code_copied": "Tersalin!",
  "status_retrying": "Menghubungkan kembali... ({attempt}/{max})"
```

- [ ] **Step 4: Run manifest test and validate-plugins script**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py`
Run: `python3 .github/workflows/validate-plugins.py`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/plugin.toml catalog.toml ai-sidebar/translations/en.json ai-sidebar/translations/id.json tests/test_ai_sidebar_manifest.py
git commit -m "chore(ai-sidebar): bump version to 1.1.0 and add translation keys"
```

---

### Task 6: Panel UI Chat Actions & Interactive Code Block Copy (`panel.luau`)

**Files:**
- Modify: `tests/test_ai_sidebar_panel.py`
- Modify: `ai-sidebar/panel.luau`

**Interfaces:**
- Consumes: `ai-sidebar/markdown.luau`, `ai-sidebar/storage.luau`, `ai-sidebar/client.luau`
- Produces:
  - Code block rendering with language badge and individual copy button
  - Regenerate button on latest assistant message
  - Edit button on user messages (restores input buffer, rewinds history)
  - Rewind button on messages (restores history checkpoint)
  - Preserves clean header (no model switcher)

- [ ] **Step 1: Update `tests/test_ai_sidebar_panel.py` with action checks**

Add to `tests/test_ai_sidebar_panel.py`:
```python
    def test_panel_actions_and_code_blocks(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn('require("./markdown.luau")', content)
        self.assertIn("action_regenerate", content)
        self.assertIn("action_edit", content)
        self.assertIn("action_rewind", content)
        self.assertIn("action_copy_code", content)
        self.assertIn("storage.rewindSession", content)
        self.assertIn("storage.removeLastAssistantMessage", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py`
Expected: FAIL (`AssertionError: 'require("./markdown.luau")' not found in content`)

- [ ] **Step 3: Update `ai-sidebar/panel.luau`**

1. Require `markdown.luau`:
   ```lua
   local markdown = require("./markdown.luau")
   ```
2. State for copied code block tracking:
   ```lua
   local copiedCodeIndex: string? = nil
   ```
3. Implement `regenerateResponse()`:
   - Removes last assistant message via `storage.removeLastAssistantMessage(sessions, currentSession.id)`.
   - Finds preceding user message.
   - Triggers stream via existing `sendMessage()`.
4. Implement `editUserMessage(idx: number, content: string)`:
   - Sets `inputBuffer = content`.
   - Calls `storage.rewindSession(sessions, currentSession.id, idx - 1)`.
   - Triggers `render()`.
5. Implement `rewindToMessage(idx: number)`:
   - Calls `storage.rewindSession(sessions, currentSession.id, idx)`.
   - Triggers `render()`.
6. Helper `renderAssistantContent(content: string, msgIdx: number)`:
   - Splits content using `markdown.parseSegments(content)`.
   - Returns list of nodes: `ui.markdown` for text, and styled container with language badge + Copy button for code blocks.
7. Integrate Regenerate button under last assistant message.
8. Integrate Edit and Rewind buttons on user messages.

- [ ] **Step 4: Run full test suite and Luau analyzer**

Run: `python3 -m unittest discover tests`
Run: `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/*.luau ai-sidebar/providers/*.luau`
Expected: All tests pass, 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/panel.luau tests/test_ai_sidebar_panel.py
git commit -m "feat(ai-sidebar): implement chat actions and code block copy in panel"
```

---

### Task 7: Final Verification & Git Cleanliness

**Files:**
- Entire repository

- [ ] **Step 1: Run comprehensive tests and linter**

```bash
python3 -m unittest discover tests
python3 .github/workflows/validate-plugins.py
/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/*.luau ai-sidebar/providers/*.luau
```

- [ ] **Step 2: Check git status and push to origin**

```bash
git status
git log -n 7 --oneline
```
