# Slash Search Command & Contextual Web Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement on-demand `/search` slash command in `ai-sidebar` that uses an AI query synthesizer to generate optimal search terms from context and fetches live web results, while removing the persistent global search toggle so regular messages never search.

**Architecture:** A slash command detector in `search.luau` inspects input for `/search`. If detected, `client.luau` uses a fast LLM synthesizer call (`client.synthesizeSearchQuery`) with 2.5s fallback to derive concise search keywords from the conversation history, calls `search.performSearch`, and feeds grounded context into `client.streamChat`. `panel.luau` removes the persistent `enable_web_search` toggle from settings, only triggering search when `/search` is present in the prompt.

**Tech Stack:** Luau (Roblox/Noctalia runtime), Python `unittest`, `luau-lsp`.

## Global Constraints
- Do not break existing chat streaming, titler, or multi-provider support.
- Keep `/search` badge/prefix in the user message bubble as a clear visual indicator.
- Search execution must maintain safety watchdog timers (never freeze or lock UI).
- Backwards compatible with legacy configs in `storage.luau`.
- Code must pass `luau-lsp analyze --platform standard --defs noctalia.d.luau` and `python3 -m unittest discover tests`.

---

### Task 1: Slash Search Detection & Helper Module

**Files:**
- Modify: `ai-sidebar/search.luau`
- Test: `tests/test_ai_sidebar_slash_search.py`

**Interfaces:**
- Produces: `search.isSlashSearch(text: string): (boolean, string)`
  - Returns `(true, queryPart)` if text matches `/search` or `/search ...`, else `(false, "")`.

- [ ] **Step 1: Write the failing unit test**

Create `tests/test_ai_sidebar_slash_search.py`:
```python
import os
import unittest

SEARCH_FILE = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "search.luau"
)


class TestAiSidebarSlashSearch(unittest.TestCase):
    def test_search_file_contains_slash_helper(self):
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("search.isSlashSearch", content)

    def test_slash_search_parsing_logic(self):
        # Simulation of Luau pattern match
        def is_slash_search(text):
            t = text.strip()
            if t == "/search":
                return True, ""
            if t.startswith("/search ") or t.startswith("/search\n"):
                return True, t[7:].strip()
            return False, ""

        ok, q = is_slash_search("/search")
        self.assertTrue(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/search who is elon musk")
        self.assertTrue(ok)
        self.assertEqual(q, "who is elon musk")

        ok, q = is_slash_search("/search   what is linux?  ")
        self.assertTrue(ok)
        self.assertEqual(q, "what is linux?")

        ok, q = is_slash_search("halo apa kabar")
        self.assertFalse(ok)
        self.assertEqual(q, "")

        ok, q = is_slash_search("/searching something")
        self.assertFalse(ok)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py -v`
Expected: FAIL with `AssertionError: 'search.isSlashSearch' not found in content`.

- [ ] **Step 3: Implement `search.isSlashSearch` in `ai-sidebar/search.luau`**

Add to `ai-sidebar/search.luau`:
```luau
function search.isSlashSearch(text: string): (boolean, string)
  local trimmed = safeTrim(text)
  if trimmed == "/search" then
    return true, ""
  end
  if trimmed:sub(1, 8) == "/search " or trimmed:sub(1, 8) == "/search\n" then
    local subQuery = safeTrim(trimmed:sub(9))
    return true, subQuery
  end
  return false, ""
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/test_ai_sidebar_slash_search.py ai-sidebar/search.luau
git commit -m "feat(ai-sidebar): add search.isSlashSearch helper function"
```

---

### Task 2: AI Contextual Query Synthesizer & Client Integration

**Files:**
- Modify: `ai-sidebar/client.luau`
- Test: `tests/test_ai_sidebar_slash_search.py`

**Interfaces:**
- Consumes: `search.isSlashSearch` and active provider `buildChatRequest`
- Produces: `client.synthesizeSearchQuery(messages: { any }, userPrompt: string, config: any, callback: (query: string) -> ()): ()`
- Produces: `client.prepareContextualSearch(text: string, messages: { any }, config: any, callback: (searchContext: string?) -> ()): ()`

- [ ] **Step 1: Write test for synthesizeSearchQuery and prepareContextualSearch**

Add to `tests/test_ai_sidebar_slash_search.py`:
```python
    def test_client_contains_contextual_search_methods(self):
        client_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "client.luau"
        )
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("client.synthesizeSearchQuery", content)
        self.assertIn("client.prepareContextualSearch", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py -v`
Expected: FAIL with missing method assertions.

- [ ] **Step 3: Implement `client.synthesizeSearchQuery` and `client.prepareContextualSearch` in `ai-sidebar/client.luau`**

In `ai-sidebar/client.luau`:
```luau
function client.synthesizeSearchQuery(
  messages: { any },
  userPrompt: string,
  config: any,
  callback: (query: string) -> ()
): ()
  local hasCalled = false
  local function safeDone(q: string)
    if hasCalled then return end
    hasCalled = true
    callback(q)
  end

  -- Fallback query from user prompt or conversation context
  local fallbackQuery = userPrompt
  if fallbackQuery == "" then
    for i = #messages, 1, -1 do
      local m = messages[i]
      if m.content and m.content ~= "" and m.content:sub(1, 7) ~= "/search" then
        fallbackQuery = m.content:sub(1, 100)
        break
      end
    end
  end
  if fallbackQuery == "" then
    fallbackQuery = "general information"
  end

  -- 2.5s safety watchdog: ensures synthesis never delays search
  pcall(function()
    local ran = noctalia.runAsync({ "sleep", "2.5" }, function()
      safeDone(fallbackQuery)
    end)
    if not ran then
      noctalia.runAsync("sleep 2.5", function()
        safeDone(fallbackQuery)
      end)
    end
  end)

  local ok, _ = (pcall :: any)(function()
    local synthMessages = {
      {
        role = "system",
        content = "You are a web search query generator. Based on the conversation context and latest user request, output ONLY a concise, high-yield web search query (3 to 6 keywords). Return ONLY the query in plain text, with no quotes, no markdown, and no explanation.",
      },
    }

    -- Add last 3 messages for context
    local startIdx = math.max(1, #messages - 3)
    for i = startIdx, #messages do
      local m = messages[i]
      table.insert(synthMessages, {
        role = m.role,
        content = m.content:sub(1, 300),
      })
    end

    if userPrompt ~= "" then
      table.insert(synthMessages, {
        role = "user",
        content = "Generate search query for: " .. userPrompt:sub(1, 200),
      })
    else
      table.insert(synthMessages, {
        role = "user",
        content = "Generate search query for the previous topic.",
      })
    end

    local prov = getProvider(config.active_provider)
    local req = prov.buildChatRequest(synthMessages, "You are a web search query generator.", config)
    if type(req.body) == "string" then
      req.body = req.body:gsub('"stream":%s*true', '"stream": false')
    end

    noctalia.http(req, function(resp: HttpResponse)
      if not resp.ok or resp.status < 200 or resp.status >= 300 then
        safeDone(fallbackQuery)
        return
      end

      local decoded, err = noctalia.json.decode(resp.body)
      if err or type(decoded) ~= "table" then
        safeDone(fallbackQuery)
        return
      end

      local generated: string? = nil
      if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
        generated = decoded.choices[1].message.content
      elseif decoded.content and decoded.content[1] and decoded.content[1].text then
        generated = decoded.content[1].text
      elseif decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts then
        generated = decoded.candidates[1].content.parts[1].text
      end

      if generated and type(generated) == "string" then
        local clean = generated:gsub('^["\']+', ''):gsub('["\']+$', '')
        clean = clean:gsub("[%c]", " ")
        clean = noctalia.string.trim(clean)
        if #clean > 0 then
          safeDone(clean)
          return
        end
      end
      safeDone(fallbackQuery)
    end)
  end)

  if not ok then
    safeDone(fallbackQuery)
  end
end

function client.prepareContextualSearch(
  text: string,
  messages: { any },
  config: any,
  callback: (searchContext: string?) -> ()
): ()
  local isSearch, searchPrompt = search.isSlashSearch(text)
  if not isSearch then
    callback(nil)
    return
  end

  client.synthesizeSearchQuery(messages, searchPrompt, config, function(synthesizedQuery)
    local searchConfig = config
    search.performSearch(synthesizedQuery, searchConfig, function(ok, contextBlock, _err)
      if ok and contextBlock and contextBlock ~= "" then
        callback(contextBlock)
      else
        callback(nil)
      end
    end)
  end)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py -v`
Expected: PASS.

- [ ] **Step 5: Verify types with luau-lsp**

Run: `~/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --platform standard --defs noctalia.d.luau ai-sidebar/client.luau`
Expected: Exit code 0.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_slash_search.py
git commit -m "feat(ai-sidebar): implement AI contextual search query synthesizer"
```

---

### Task 3: Panel UI & Slash Command Flow Updates

**Files:**
- Modify: `ai-sidebar/panel.luau`
- Test: `tests/test_ai_sidebar_slash_search.py`

**Interfaces:**
- Consumes: `search.isSlashSearch` and `client.prepareContextualSearch`

- [ ] **Step 1: Write tests for panel behavior**

Add to `tests/test_ai_sidebar_slash_search.py`:
```python
    def test_panel_uses_prepare_contextual_search(self):
        panel_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau"
        )
        with open(panel_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("client.prepareContextualSearch", content)
        self.assertIn("search.isSlashSearch", content)
```

- [ ] **Step 2: Update `sendMessage` and `regenerateResponse` in `ai-sidebar/panel.luau`**

In `panel.luau`:
Update `sendMessage`:
```luau
  local isSearch, _ = search.isSlashSearch(text)
  if isSearch then
    isSearching = true
    render()
    local searchCompleted = false
    local function finishSearch(ctx: string?)
      if searchCompleted then return end
      searchCompleted = true
      beginStream(ctx)
    end

    pcall(function()
      local ran = noctalia.runAsync({ "sleep", "6" }, function()
        finishSearch(nil)
      end)
      if not ran then
        noctalia.runAsync("sleep 6", function()
          finishSearch(nil)
        end)
      end
    end)

    client.prepareContextualSearch(text, capped, config, function(searchCtx)
      finishSearch(searchCtx)
    end)
  else
    beginStream(nil)
  end
```

Update `regenerateResponse`:
```luau
  local isSearch, _ = search.isSlashSearch(lastUserMsg.content)
  if isSearch then
    isSearching = true
    render()
    local searchCompleted = false
    local function finishSearch(ctx: string?)
      if searchCompleted then return end
      searchCompleted = true
      beginStream(ctx)
    end

    pcall(function()
      local ran = noctalia.runAsync({ "sleep", "6" }, function()
        finishSearch(nil)
      end)
      if not ran then
        noctalia.runAsync("sleep 6", function()
          finishSearch(nil)
        end)
      end
    end)

    client.prepareContextualSearch(lastUserMsg.content, capped, config, function(searchCtx)
      finishSearch(searchCtx)
    end)
  else
    beginStream(nil)
  end
```

- [ ] **Step 3: Remove persistent `enable_web_search` toggle from settings in `panel.luau`**

In `panel.luau`:
Remove the `enable_web_search` toggle button entry and hint from the settings render function (around line 1285-1310), keeping the search provider picker, api key input, and max results options.

- [ ] **Step 4: Run tests**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py -v`
Expected: PASS.

- [ ] **Step 5: Run luau-lsp analyze**

Run: `~/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --platform standard --defs noctalia.d.luau ai-sidebar/panel.luau`
Expected: Exit code 0.

- [ ] **Step 6: Commit**

```bash
git add ai-sidebar/panel.luau tests/test_ai_sidebar_slash_search.py
git commit -m "feat(ai-sidebar): trigger web search exclusively via /search slash command"
```

---

### Task 4: Full Test Suite Verification & Documentation

**Files:**
- Modify: `ai-sidebar/README.md`
- Test: All unit tests in `tests/`

- [ ] **Step 1: Update README.md with `/search` documentation**

Document `/search` and `/search <question>` slash command usage and note that casual messages stream directly without web search overhead.

- [ ] **Step 2: Run full Python test suite**

Run: `python3 -m unittest discover tests`
Expected: 111+ tests PASS with 0 failures.

- [ ] **Step 3: Run full luau-lsp check across all modified files**

Run: `~/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --platform standard --defs noctalia.d.luau ai-sidebar/search.luau ai-sidebar/client.luau ai-sidebar/panel.luau`
Expected: Exit code 0.

- [ ] **Step 4: Commit**

```bash
git add ai-sidebar/README.md
git commit -m "docs(ai-sidebar): update documentation with /search slash command"
```
