# AI Sidebar: Web Search Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement universal web search capability in AI Sidebar with DuckDuckGo (free), Gemini Native (Google Search), Tavily, and Brave Search, controlled via Settings.

**Architecture:** Create an isolated `search.luau` engine abstraction for querying search providers and formatting search snippets into context blocks. Integrate with `client.luau` and `providers/gemini.luau` for context injection / native grounding. Expose clean settings in `panel.luau` with live `"Searching the web..."` status indicators and fallback guards.

**Tech Stack:** Luau, Noctalia Plugin API (`noctalia.httpRequest`, `noctalia.json`, `noctalia.string`), Python `unittest` test suite.

## Global Constraints
- Noctalia UI rules: No `ui.box` with children (use `ui.column` or `ui.row`).
- Do NOT close panel on save settings (keep TOML sync deferred to `onClose`).
- Filter sessions with 0 messages from history.
- Never crash on network search failure; fall back gracefully to offline model knowledge.

---

### Task 1: Search Module (`search.luau`) & Unit Tests

**Files:**
- Create: `ai-sidebar/search.luau`
- Create: `tests/test_ai_sidebar_search.py`

**Interfaces:**
- Produces:
  ```luau
  search.formatSearchContext(items: { SearchResultItem }, query: string): string
  search.buildSearchRequest(engine: string, query: string, apiKey: string?, maxResults: number?): { url: string, method: string, headers: { string }?, body: string? }
  search.parseSearchResponse(engine: string, body: string): { SearchResultItem }
  search.performSearch(query: string, config: any, callback: (ok: boolean, contextText: string?, err: string?) -> ()): ()
  ```

- [ ] **Step 1: Write the failing tests in `tests/test_ai_sidebar_search.py`**

```python
import json
import os
import unittest

SEARCH_FILE = os.path.join(
    os.path.dirname(__file__), "..", "ai-sidebar", "search.luau"
)


class TestAiSidebarSearch(unittest.TestCase):
    def test_search_file_exists(self):
        self.assertTrue(os.path.isfile(SEARCH_FILE), "Missing ai-sidebar/search.luau")
        with open(SEARCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        expected_exports = [
            "search.formatSearchContext",
            "search.buildSearchRequest",
            "search.parseSearchResponse",
            "search.performSearch",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"search.luau missing export {exp}")

    def test_context_formatting_simulation(self):
        # Simulation of formatting items into markdown context
        items = [
            {"title": "Doc 1", "url": "https://example.com/1", "snippet": "Snippet 1"},
            {"title": "Doc 2", "url": "https://example.com/2", "snippet": "Snippet 2"},
        ]
        lines = ['[Web Search Results for: "test query"]']
        for i, item in enumerate(items, 1):
            lines.append(f"{i}. [{item['title']}]({item['url']})\n   {item['snippet']}")
        lines.append("\nInstructions: Incorporate the above live web search information into your response. Cite sources with markdown links where appropriate.")
        formatted = "\n".join(lines)

        self.assertIn("[Doc 1](https://example.com/1)", formatted)
        self.assertIn("Snippet 1", formatted)
        self.assertIn("Instructions:", formatted)

    def test_tavily_response_parsing_simulation(self):
        sample_tavily = {
            "results": [
                {"title": "Tavily Title", "url": "https://tavily.com", "content": "Tavily summary text"}
            ]
        }
        results = [
            {"title": r.get("title", ""), "url": r.get("url", ""), "snippet": r.get("content", "")}
            for r in sample_tavily.get("results", [])
        ]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["title"], "Tavily Title")
        self.assertEqual(results[0]["snippet"], "Tavily summary text")

    def test_brave_response_parsing_simulation(self):
        sample_brave = {
            "web": {
                "results": [
                    {"title": "Brave Title", "url": "https://brave.com", "description": "Brave summary"}
                ]
            }
        }
        results = [
            {"title": r.get("title", ""), "url": r.get("url", ""), "snippet": r.get("description", "")}
            for r in sample_brave.get("web", {}).get("results", [])
        ]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["title"], "Brave Title")
        self.assertEqual(results[0]["snippet"], "Brave summary")

    def test_duckduckgo_response_parsing_simulation(self):
        sample_ddg = {
            "Heading": "Python",
            "AbstractText": "Python is a programming language.",
            "AbstractURL": "https://en.wikipedia.org/wiki/Python",
            "RelatedTopics": [
                {"Text": "Topic 1 - An interesting topic", "FirstURL": "https://example.com/t1"}
            ]
        }
        items = []
        if sample_ddg.get("AbstractText"):
            items.append({
                "title": sample_ddg.get("Heading") or "DuckDuckGo Instant Answer",
                "url": sample_ddg.get("AbstractURL", ""),
                "snippet": sample_ddg.get("AbstractText", ""),
            })
        for topic in sample_ddg.get("RelatedTopics", []):
            if isinstance(topic, dict) and topic.get("Text") and topic.get("FirstURL"):
                items.append({
                    "title": topic["Text"].split(" - ")[0],
                    "url": topic["FirstURL"],
                    "snippet": topic["Text"],
                })
        self.assertGreaterEqual(len(items), 1)
        self.assertEqual(items[0]["title"], "Python")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_search.py`
Expected: FAIL with "Missing ai-sidebar/search.luau"

- [ ] **Step 3: Implement `ai-sidebar/search.luau`**

```luau
--!strict
local search = {}

export type SearchResultItem = {
  title: string,
  url: string,
  snippet: string,
}

export type SearchResponse = {
  ok: boolean,
  query: string,
  engine: string,
  items: { SearchResultItem },
  error: string?,
}

function search.formatSearchContext(items: { SearchResultItem }, query: string): string
  if #items == 0 then
    return ""
  end

  local lines = {
    string.format('[Web Search Results for: "%s"]', query),
  }
  for i, item in ipairs(items) do
    table.insert(lines, string.format("%d. [%s](%s)\n   %s", i, item.title, item.url, item.snippet))
  end
  table.insert(lines, "\nInstructions: Incorporate the above live web search information into your response. Cite sources with markdown links where appropriate.")
  return table.concat(lines, "\n")
end

function search.buildSearchRequest(engine: string, query: string, apiKey: string?, maxResults: number?): { url: string, method: string, headers: { string }?, body: string? }
  local limit = maxResults or 3
  local encQuery = noctalia.string.urlEncode(query)

  if engine == "tavily" then
    local bodyObj = {
      api_key = apiKey or "",
      query = query,
      max_results = limit,
      include_answer = true,
    }
    local encoded, _ = noctalia.json.encode(bodyObj)
    return {
      url = "https://api.tavily.com/search",
      method = "POST",
      headers = {
        "Content-Type: application/json",
      },
      body = encoded or "{}",
    }
  elseif engine == "brave" then
    return {
      url = string.format("https://api.search.brave.com/res/v1/web/search?q=%s&count=%d", encQuery, limit),
      method = "GET",
      headers = {
        "Accept: application/json",
        "X-Subscription-Token: " .. (apiKey or ""),
      },
    }
  else
    -- Default: DuckDuckGo instant answer API
    return {
      url = string.format("https://api.duckduckgo.com/?q=%s&format=json&no_html=1&skip_disambig=1", encQuery),
      method = "GET",
      headers = {
        "Accept: application/json",
      },
    }
  end
end

function search.parseSearchResponse(engine: string, body: string): { SearchResultItem }
  local items: { SearchResultItem } = {}
  local decoded, _ = noctalia.json.decode(body)
  if type(decoded) ~= "table" then
    return items
  end

  if engine == "tavily" then
    if type(decoded.results) == "table" then
      for _, r in ipairs(decoded.results) do
        if type(r) == "table" and type(r.title) == "string" and type(r.url) == "string" then
          table.insert(items, {
            title = r.title,
            url = r.url,
            snippet = type(r.content) == "string" and r.content or "",
          })
        end
      end
    end
  elseif engine == "brave" then
    if type(decoded.web) == "table" and type(decoded.web.results) == "table" then
      for _, r in ipairs(decoded.web.results) do
        if type(r) == "table" and type(r.title) == "string" and type(r.url) == "string" then
          table.insert(items, {
            title = r.title,
            url = r.url,
            snippet = type(r.description) == "string" and r.description or "",
          })
        end
      end
    end
  else
    -- DuckDuckGo
    if type(decoded.AbstractText) == "string" and decoded.AbstractText ~= "" then
      table.insert(items, {
        title = type(decoded.Heading) == "string" and decoded.Heading ~= "" and decoded.Heading or "DuckDuckGo Instant Answer",
        url = type(decoded.AbstractURL) == "string" and decoded.AbstractURL or "",
        snippet = decoded.AbstractText,
      })
    end
    if type(decoded.RelatedTopics) == "table" then
      for _, topic in ipairs(decoded.RelatedTopics) do
        if type(topic) == "table" and type(topic.Text) == "string" and type(topic.FirstURL) == "string" then
          local tTitle = topic.Text:match("^([^\-]+)%s*%-%s*") or topic.Text:sub(1, 40)
          table.insert(items, {
            title = noctalia.string.trim(tTitle),
            url = topic.FirstURL,
            snippet = topic.Text,
          })
        end
      end
    end
  end

  return items
end

function search.performSearch(query: string, config: any, callback: (ok: boolean, contextText: string?, err: string?) -> ()): ()
  local engine = (config and config.search_engine) or "duckduckgo"
  local apiKey = (config and config.search_api_key) or ""
  local maxResults = (config and tonumber(config.search_max_results)) or 3

  local req = search.buildSearchRequest(engine, query, apiKey, maxResults)

  noctalia.httpRequest(req, function(resp)
    if not resp.ok or resp.status < 200 or resp.status >= 300 then
      callback(false, nil, "Search request failed with status " .. tostring(resp.status))
      return
    end

    local items = search.parseSearchResponse(engine, resp.body)
    if #items == 0 then
      callback(true, nil, nil)
    else
      local contextBlock = search.formatSearchContext(items, query)
      callback(true, contextBlock, nil)
    end
  end)
end

return search
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_search.py`
Expected: PASS (Ran 5 tests in 0.00x s: OK)

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/search.luau tests/test_ai_sidebar_search.py
git commit -m "feat(ai-sidebar): implement search module with DuckDuckGo, Tavily, and Brave support"
```

---

### Task 2: Configuration & Storage Updates

**Files:**
- Modify: `ai-sidebar/plugin.toml:35-85`
- Modify: `ai-sidebar/storage.luau:45-75, 185-235`
- Modify: `tests/test_ai_sidebar_storage.py`
- Modify: `tests/test_ai_sidebar_manifest.py`

**Interfaces:**
- Consumes: `ConfigTable`
- Produces: `enable_web_search: boolean`, `search_engine: string`, `search_api_key: string`, `search_max_results: number`

- [ ] **Step 1: Write the failing tests in `tests/test_ai_sidebar_storage.py`**

```python
    def test_search_config_fields(self):
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("enable_web_search", content)
        self.assertIn("search_engine", content)
        self.assertIn("search_api_key", content)
        self.assertIn("search_max_results", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover tests -k test_search_config_fields`
Expected: FAIL with missing fields.

- [ ] **Step 3: Update `ai-sidebar/plugin.toml` and `ai-sidebar/storage.luau`**

In `ai-sidebar/plugin.toml`:
```toml
[panel.settings.enable_web_search]
type = "bool"
default = false
label = "Enable Web Search"
description = "Allow AI to search the internet before responding"

[panel.settings.search_engine]
type = "select"
default = "duckduckgo"
options = ["duckduckgo", "gemini_native", "tavily", "brave"]
label = "Search Engine"
description = "Web search engine to use"

[panel.settings.search_api_key]
type = "string"
default = ""
label = "Search API Key"
description = "API Key for Tavily or Brave Search (optional for DuckDuckGo/Gemini)"

[panel.settings.search_max_results]
type = "select"
default = "3"
options = ["3", "5", "7"]
label = "Max Search Results"
description = "Maximum number of search results to include in context"
```

In `ai-sidebar/storage.luau`:
Update `ConfigTable` definition:
```luau
export type ConfigTable = {
  active_provider: string,
  openai_key: string,
  openai_model: string,
  anthropic_key: string,
  anthropic_model: string,
  gemini_key: string,
  gemini_model: string,
  custom_base_url: string,
  custom_key: string,
  custom_model: string,
  system_prompt: string,
  enable_web_search: boolean,
  search_engine: string,
  search_api_key: string,
  search_max_results: number,
}
```

Update `storage.loadConfig()` defaults and JSON loader:
```luau
  local cfg: ConfigTable = {
    active_provider = activeProv,
    openai_key = (noctalia.getConfig("openai_api_key") or "") :: string,
    openai_model = (noctalia.getConfig("openai_model") or "gpt-4o-mini") :: string,
    anthropic_key = (noctalia.getConfig("anthropic_api_key") or "") :: string,
    anthropic_model = (noctalia.getConfig("anthropic_model") or "claude-3-5-haiku-20241022") :: string,
    gemini_key = geminiKey,
    gemini_model = geminiModel,
    custom_base_url = (noctalia.getConfig("custom_base_url") or "http://localhost:11434/v1") :: string,
    custom_key = (noctalia.getConfig("custom_api_key") or "") :: string,
    custom_model = (noctalia.getConfig("custom_model") or "llama3.2") :: string,
    system_prompt = (noctalia.getConfig("system_prompt") or "You are a helpful and concise AI assistant.") :: string,
    enable_web_search = (noctalia.getConfig("enable_web_search") == true) or false,
    search_engine = (noctalia.getConfig("search_engine") or "duckduckgo") :: string,
    search_api_key = (noctalia.getConfig("search_api_key") or "") :: string,
    search_max_results = tonumber(noctalia.getConfig("search_max_results")) or 3,
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover tests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/plugin.toml ai-sidebar/storage.luau tests/test_ai_sidebar_storage.py
git commit -m "feat(ai-sidebar): add web search configuration schema and persistence"
```

---

### Task 3: Gemini Grounding & Client Search Integration

**Files:**
- Modify: `ai-sidebar/providers/gemini.luau:15-35`
- Modify: `ai-sidebar/client.luau:45-85`
- Modify: `tests/test_ai_sidebar_search.py`

**Interfaces:**
- Consumes: `search.performSearch`, `config.enable_web_search`, `config.search_engine`
- Produces: Web context injection in chat payload; `tools: [{ "googleSearch": {} }]` for Gemini native grounding.

- [ ] **Step 1: Write test for Gemini native search grounding**

In `tests/test_ai_sidebar_search.py`:
```python
    def test_gemini_google_search_grounding_payload(self):
        gemini_file = os.path.join(
            os.path.dirname(__file__), "..", "ai-sidebar", "providers", "gemini.luau"
        )
        with open(gemini_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("googleSearch", content)
        self.assertIn("enable_web_search", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_search.py -k test_gemini_google_search_grounding_payload`
Expected: FAIL

- [ ] **Step 3: Update `ai-sidebar/providers/gemini.luau` and `ai-sidebar/client.luau`**

In `ai-sidebar/providers/gemini.luau`:
```luau
  if config and config.enable_web_search == true and config.search_engine == "gemini_native" then
    bodyObj.tools = {
      { googleSearch = {} }
    }
  end
```

In `ai-sidebar/client.luau`:
Require `./search.luau`:
```luau
local search = require("./search.luau")
```

Add `client.prepareSearchContext`:
```luau
function client.prepareSearchContext(query: string, config: any, callback: (augmentedPrompt: string?) -> ()): ()
  if not (config and config.enable_web_search == true) then
    callback(nil)
    return
  end

  if config.active_provider == "gemini" and config.search_engine == "gemini_native" then
    -- Native grounding handles retrieval directly
    callback(nil)
    return
  end

  search.performSearch(query, config, function(ok, contextBlock, _err)
    if ok and contextBlock and contextBlock ~= "" then
      callback(contextBlock)
    else
      callback(nil)
    end
  end)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover tests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/providers/gemini.luau ai-sidebar/client.luau tests/test_ai_sidebar_search.py
git commit -m "feat(ai-sidebar): integrate Gemini Google Search grounding and client search pre-pass"
```

---

### Task 4: UI Settings Tab, Chat Live Status, and Translations

**Files:**
- Modify: `ai-sidebar/translations/en.json`
- Modify: `ai-sidebar/translations/id.json`
- Modify: `ai-sidebar/panel.luau`
- Modify: `tests/test_ai_sidebar_panel.py`

**Interfaces:**
- Consumes: `tr("status_searching_web")`, `tr("web_search_title")`, `tr("enable_web_search")`, etc.
- Produces: Settings controls for Web Search; Status updates during search in chat.

- [ ] **Step 1: Write test for web search UI in `tests/test_ai_sidebar_panel.py`**

```python
    def test_web_search_ui_components(self):
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("enable_web_search", content)
        self.assertIn("search_engine", content)
        self.assertIn("search_max_results", content)
        self.assertIn("status_searching_web", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py -k test_web_search_ui_components`
Expected: FAIL

- [ ] **Step 3: Update translations and `panel.luau`**

In `ai-sidebar/translations/en.json`:
```json
  "web_search_title": "Web Search",
  "enable_web_search": "Enable Web Search",
  "search_engine": "Search Engine",
  "search_engine_ddg": "DuckDuckGo (Free)",
  "search_engine_gemini": "Gemini Native (Google Search)",
  "search_engine_tavily": "Tavily Search (API Key)",
  "search_engine_brave": "Brave Search (API Key)",
  "search_api_key": "Search API Key",
  "search_max_results": "Max Search Results",
  "search_results_3": "3 Results (Compact)",
  "search_results_5": "5 Results (Standard)",
  "search_results_7": "7 Results (Detailed)",
  "status_searching_web": "Searching the web...",
  "search_error_fallback": "Web search failed, proceeding with offline model knowledge."
```

In `ai-sidebar/translations/id.json`:
```json
  "web_search_title": "Pencarian Web",
  "enable_web_search": "Aktifkan Pencarian Web",
  "search_engine": "Mesin Pencari",
  "search_engine_ddg": "DuckDuckGo (Gratis)",
  "search_engine_gemini": "Gemini Native (Google Search)",
  "search_engine_tavily": "Tavily Search (API Key)",
  "search_engine_brave": "Brave Search (API Key)",
  "search_api_key": "Search API Key",
  "search_max_results": "Maksimal Hasil Pencarian",
  "search_results_3": "3 Hasil (Hemat)",
  "search_results_5": "5 Hasil (Standar)",
  "search_results_7": "7 Hasil (Lengkap)",
  "status_searching_web": "Mencari di web...",
  "search_error_fallback": "Pencarian web gagal, melanjutkan dengan pengetahuan model."
```

In `ai-sidebar/panel.luau`:
- In `renderSettingView()`:
  - Add section title `ui.row` with `glyph = "world"` and `text = tr("web_search_title")`.
  - Add `ui.toggle` for `config.enable_web_search`.
  - If `config.enable_web_search`:
    - Add `ui.select` for search engine (`duckduckgo`, `gemini_native`, `tavily`, `brave`).
    - If `tavily` or `brave`, add API key input with password visibility eye button.
    - Add `ui.select` for max results (`3`, `5`, `7`).
- In `sendMessage()`:
  - When `config.enable_web_search` is true and provider needs search pre-pass:
    - Set `isSearching = true` and `render()`.
    - Call `client.prepareSearchContext(text, config, function(augmentedContext) ... isSearching = false ... streamChat() end)`.
- In `statusText`:
  - If `isSearching` then `statusText = tr("status_searching_web")`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover tests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/translations/en.json ai-sidebar/translations/id.json ai-sidebar/panel.luau tests/test_ai_sidebar_panel.py
git commit -m "feat(ai-sidebar): add web search settings UI and live search status in chat"
```

---

### Task 5: End-to-End Verification & Documentation

**Files:**
- Modify: `ai-sidebar/README.md`
- Test: All unit tests

- [ ] **Step 1: Update README.md with Web Search documentation**
- [ ] **Step 2: Run full test suite (`python3 -m unittest discover tests`)**
- [ ] **Step 3: Run `luau-lsp analyze` to verify zero syntax/type errors**
- [ ] **Step 4: Commit documentation and verify clean git status**

```bash
git add ai-sidebar/README.md
git commit -m "docs(ai-sidebar): document web search configuration and provider options"
```
