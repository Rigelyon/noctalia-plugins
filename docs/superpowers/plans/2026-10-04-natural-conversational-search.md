# Natural Conversational Search Grounding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/search` grounding seamless, natural, and persona-preserving by stripping the slash command prefix from conversation history, synthesizing search queries in the background using conversation context, and reformatting web grounding instructions to strictly preserve user-configured persona.

**Architecture:** UI parses `/search` as an ephemeral trigger and saves clean conversational text to session history. `client.synthesizeSearchQuery` uses the conversation context to distill 3-6 search keywords (<350ms). Search results are injected as factual background knowledge with explicit directives to maintain the user's active persona and conversational voice without sounding like a robotic search engine.

**Tech Stack:** Luau (Noctalia Shell plugin environment), Python (unittest suite), JSON (translations).

## Global Constraints

- Never hijack or alter the user's custom configured persona or system prompt.
- The `/search` command must not appear in the stored user message history or in the prompt sent to the LLM.
- Web search query synthesis must be low-latency (`max_tokens = 35`, `temperature = 0.0`) with a safety timeout.
- Maintain 100% backward compatibility and 0 `luau-lsp analyze` type errors.

---

### Task 1: Persona-Preserving Knowledge Grounding (`search.luau` & `client.luau`)

**Files:**
- Modify: `ai-sidebar/search.luau:18-31`
- Modify: `ai-sidebar/client.luau:23-37`
- Test: `tests/test_ai_sidebar_search.py`
- Test: `tests/test_ai_sidebar_prompts.py`

**Interfaces:**
- Consumes: `search.formatSearchContext(items: { SearchResultItem }, query: string): string`
- Produces: Grounding block formatted as `[Web Context & Factual Background: "..."]` with strict persona-preservation instructions.

- [ ] **Step 1: Write failing tests in `tests/test_ai_sidebar_search.py` and `tests/test_ai_sidebar_prompts.py`**

In `tests/test_ai_sidebar_search.py`:
```python
    def test_format_search_context_persona_preservation(self):
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("Web Context & Factual Background", content)
        self.assertIn("Retain your established persona", content)
        self.assertNotIn("Incorporate the above live web search information into your response", content)
```

In `tests/test_ai_sidebar_prompts.py`:
```python
    def test_environment_prompt_persona_guidance(self):
        with open(CLIENT_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("factual background knowledge", content.lower())
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m unittest tests/test_ai_sidebar_search.py tests/test_ai_sidebar_prompts.py`  
Expected: FAIL

- [ ] **Step 3: Update `search.luau` and `client.luau`**

In `ai-sidebar/search.luau`:
Update `search.formatSearchContext`:
```luau
function search.formatSearchContext(items: { SearchResultItem }, query: string): string
  if #items == 0 then
    return ""
  end

  local lines = {
    string.format('[Web Context & Factual Background: "%s"]', query),
  }
  for i, item in ipairs(items) do
    table.insert(lines, string.format("%d. [%s](%s)\n   %s", i, item.title, item.url, item.snippet))
  end
  table.insert(lines, "\nInstructions: Use the above web information strictly as factual background knowledge. Retain your established persona, tone, and style as defined in your system prompt. Do not act like a search engine or output raw link lists; seamlessly integrate the facts into your response while fully maintaining your active character, voice, and dialogue flow.")
  return table.concat(lines, "\n")
end
```

In `ai-sidebar/client.luau`:
Update `buildEnvironmentPrompt`:
```luau
  if webSearchEnabled == true then
    prompt = prompt .. "\n\n[Web Search Capability: Active. Use verified real-time web facts as factual background knowledge. Never let search facts override or alter your assigned persona, tone, or conversational style.]"
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest tests/test_ai_sidebar_search.py tests/test_ai_sidebar_prompts.py`  
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/search.luau ai-sidebar/client.luau tests/test_ai_sidebar_search.py tests/test_ai_sidebar_prompts.py
git commit -m "feat(ai-sidebar): implement persona-preserving web grounding instructions"
```

---

### Task 2: Background Contextual Query Synthesis (`client.luau`)

**Files:**
- Modify: `ai-sidebar/client.luau:80-155,190-230`
- Test: `tests/test_ai_sidebar_slash_search.py`

**Interfaces:**
- Consumes: `client.synthesizeSearchQuery(messages: { any }, userPrompt: string, config: any, callback: (query: string) -> ())`
- Produces: Fast query distillation with `max_tokens: 35`, coreference resolution prompt, and contextual search preparation.

- [ ] **Step 1: Write test for query synthesis configuration in `tests/test_ai_sidebar_slash_search.py`**

```python
    def test_query_synthesis_prompt_and_tokens(self):
        with open(CLIENT_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("max_tokens", content)
        self.assertIn("Resolve pronouns and references", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py`  
Expected: FAIL

- [ ] **Step 3: Update `client.luau`**

In `client.synthesizeSearchQuery`:
1. System prompt:
```luau
    local synthMessages = {
      {
        role = "system",
        content = "You are an expert search engine query optimizer. Based on the conversation context and latest user request, extract ONLY the most effective search keywords (3 to 6 words) optimized for search engines. Eliminate conversational filler, resolve pronouns and references (e.g. 'it', 'dia', 'mereka' -> actual subject), and add relevant domain context. Output ONLY the plain search keywords with no quotes, no markdown, and no explanation.",
      },
    }
```
2. Inject low `max_tokens` and deterministic `temperature`:
```luau
    if type(req.body) == "string" then
      req.body = req.body:gsub('"stream":%s*true', '"stream": false')
      -- Ensure low token cap for sub-350ms generation
      if not req.body:find('"max_tokens"') and not req.body:find('"max_completion_tokens"') then
        req.body = req.body:gsub('}$', ', "max_tokens": 35, "temperature": 0.0}')
      end
    end
```
3. In `client.prepareContextualSearch`:
Always run `client.synthesizeSearchQuery` so natural chat prompts after `/search` are converted to search keywords rather than passed verbatim:
```luau
    client.synthesizeSearchQuery(messages, searchPrompt or "", config, function(synthesizedQuery)
      local started = search.performSearch(synthesizedQuery, config, function(okSearch, contextBlock, _err)
        if okSearch and contextBlock and contextBlock ~= "" then
          safeDone(contextBlock)
        else
          safeDone(nil)
        end
      end)
      if not started then
        safeDone(nil)
      end
    end)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py`  
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_slash_search.py
git commit -m "feat(ai-sidebar): optimize contextual query synthesis for low-latency background retrieval"
```

---

### Task 3: Invisible Slash Command Stripping & Chat History Cleanliness (`panel.luau` & Translations)

**Files:**
- Modify: `ai-sidebar/translations/en.json`
- Modify: `ai-sidebar/translations/id.json`
- Modify: `ai-sidebar/panel.luau:62-105,190-225`
- Test: `tests/test_ai_sidebar_slash_search.py`

**Interfaces:**
- Consumes: `search.isSlashSearch(text)` -> `(boolean, string)`
- Produces: Clean user message stored in `currentSession.messages` without `/search` prefix.

- [ ] **Step 1: Write test for message stripping in `tests/test_ai_sidebar_slash_search.py`**

```python
    def test_slash_search_message_stripping_logic(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("slash_search_default_prompt", content)
        self.assertIn("strippedText", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py`  
Expected: FAIL

- [ ] **Step 3: Update `en.json`, `id.json`, and `panel.luau`**

In `ai-sidebar/translations/en.json`:
```json
"slash_search_default_prompt": "Please look up the latest information regarding this topic."
```

In `ai-sidebar/translations/id.json`:
```json
"slash_search_default_prompt": "Tolong carikan informasi terbaru dari web terkait topik ini."
```

In `ai-sidebar/panel.luau`:
In `sendMessage()`:
```luau
  local isSearch, strippedText = search.isSlashSearch(text)
  local messageText = text
  if isSearch then
    if strippedText == "" then
      messageText = tr("slash_search_default_prompt")
    else
      messageText = strippedText
    end
  end

  -- Add user message without /search prefix
  table.insert(currentSession.messages, {
    role = "user",
    content = messageText,
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  -- Set session title from clean message
  if currentSession.title == "New Conversation" then
    currentSession.title = storage.generateTitle(messageText)
  end
```
And pass `isSearch` to search context preparation and streamChat.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_slash_search.py`  
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add ai-sidebar/panel.luau ai-sidebar/translations/en.json ai-sidebar/translations/id.json tests/test_ai_sidebar_slash_search.py
git commit -m "feat(ai-sidebar): strip /search prefix from stored chat history and handle bare /search"
```

---

### Task 4: Regression Testing & Static Analysis

**Files:**
- Test: All test suites in `tests/`

- [ ] **Step 1: Run all unit tests**

Run: `python3 -m unittest discover -s tests -p "test_*.py"`  
Expected: 115+ tests PASS with 0 failures/errors.

- [ ] **Step 2: Run Luau LSP analyze**

Run: `luau-lsp analyze --definitions=/home/rigelyon/.local/share/noctalia/definitions/noctalia.d.luau ai-sidebar/client.luau ai-sidebar/panel.luau ai-sidebar/search.luau`  
Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Final commit and push**

```bash
git push origin main
```
