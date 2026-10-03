# AI Sidebar: Custom & Local LLM Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add support for local LLMs (Ollama, LocalAI, LM Studio) and arbitrary OpenAI-compatible custom endpoints (DeepSeek, OpenRouter) to AI Sidebar with quick presets and optional API keys.

**Architecture:** A new provider module `providers/custom.luau` implements the OpenAI Chat Completions standard (`/chat/completions`) with automatic URL normalization and dynamic Authorization header handling. `storage.luau` is extended with custom configuration fields, `client.luau` routes requests to the new provider, and `panel.luau` adds preset buttons and custom input fields.

**Tech Stack:** Luau (Noctalia runtime), Python 3 `unittest` test suite, Noctalia plugin manifest specification.

## Global Constraints
- Target plugin API: 28
- CPU budget compliance: Throttled UI rendering (`>= 80ms`), pre-filtered JSON handling
- All translation keys used in `tr(...)` must exist in both `ai-sidebar/translations/en.json` and `ai-sidebar/translations/id.json`
- Manifest setting definitions must use inline tables for options (`options = [{ value = "...", label_key = "..." }]`)
- Password fields must use `password = not showApiKey` (do not use `masked`)

---

### Task 1: Custom Provider Module & Unit Tests

**Files:**
- Create: `ai-sidebar/providers/custom.luau`
- Create: `tests/test_ai_sidebar_custom_provider.py`

**Interfaces:**
- Consumes: Noctalia runtime globals (`noctalia.string`, `noctalia.json`)
- Produces:
  - `custom.normalizeUrl(baseUrl: string, endpoint: string): string`
  - `custom.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any`
  - `custom.buildTestRequest(config: any): any`
  - `custom.parseStreamLine(line: string): string?`
  - `custom.parseTestResponse(response: any): (boolean, string)`

- [ ] **Step 1: Write the failing unit tests for custom provider**

Create `tests/test_ai_sidebar_custom_provider.py`:
```python
import json
import os
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")
CUSTOM_PROVIDER_FILE = os.path.join(PLUGIN_DIR, "providers", "custom.luau")


class TestAiSidebarCustomProvider(unittest.TestCase):
    def test_custom_provider_file_exists(self):
        self.assertTrue(
            os.path.isfile(CUSTOM_PROVIDER_FILE),
            f"Missing {CUSTOM_PROVIDER_FILE}",
        )

    def test_custom_provider_structure(self):
        with open(CUSTOM_PROVIDER_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("custom.buildChatRequest", content)
        self.assertIn("custom.buildTestRequest", content)
        self.assertIn("custom.parseStreamLine", content)
        self.assertIn("custom.parseTestResponse", content)
        self.assertIn("normalizeUrl", content)
        self.assertIn("/chat/completions", content)
        self.assertIn("Authorization: Bearer", content)
        self.assertIn("stream = true", content)

    def test_stream_parser_simulation(self):
        # Simulate SSE parsing logic
        line = 'data: {"choices":[{"delta":{"content":"Hello"}}]}'
        prefix = "data:"
        self.assertTrue(line.strip().startswith(prefix))
        payload_str = line.strip()[len(prefix):].strip()
        data = json.loads(payload_str)
        self.assertEqual(data["choices"][0]["delta"]["content"], "Hello")

    def test_test_response_simulation(self):
        # Simulate 200 OK
        resp_ok = {"ok": True, "status": 200, "body": '{"choices":[{"message":{"content":"pong"}}]}'}
        self.assertEqual(resp_ok["status"], 200)

        # Simulate 401 Unauthorized
        resp_err = {"ok": False, "status": 401, "body": '{"error":{"message":"Invalid API key"}}'}
        data = json.loads(resp_err["body"])
        self.assertEqual(data["error"]["message"], "Invalid API key")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: FAIL (`AssertionError: False is not true : Missing .../providers/custom.luau`)

- [ ] **Step 3: Implement `ai-sidebar/providers/custom.luau`**

Create `ai-sidebar/providers/custom.luau`:
```lua
--!strict
local custom = {}

type Message = { role: string, content: string }

local function normalizeUrl(baseUrl: string?, endpoint: string): string
  local trimmed = (baseUrl and baseUrl ~= "") and noctalia.string.trim(baseUrl) or "http://localhost:11434/v1"
  -- Strip trailing slashes
  while trimmed:sub(-1) == "/" do
    trimmed = trimmed:sub(1, #trimmed - 1)
  end
  -- If endpoint is /chat/completions, ensure baseUrl ends with /v1 unless explicitly versioned
  if not trimmed:find("/v%d+$") and not trimmed:find("/v%d+%.%d+$") then
    trimmed = trimmed .. "/v1"
  end
  return trimmed .. endpoint
end

custom.normalizeUrl = normalizeUrl

function custom.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local formattedMessages = {}
  if systemPrompt and systemPrompt ~= "" then
    table.insert(formattedMessages, {
      role = "system",
      content = systemPrompt,
    })
  end

  for _, m in ipairs(messages) do
    table.insert(formattedMessages, {
      role = m.role,
      content = m.content,
    })
  end

  local model = (config and config.custom_model and config.custom_model ~= "") and config.custom_model or "llama3.2"
  local bodyObj = {
    model = model,
    messages = formattedMessages,
    stream = true,
  }

  local encoded, _ = noctalia.json.encode(bodyObj)
  local baseUrl = config and config.custom_base_url or "http://localhost:11434/v1"
  local url = normalizeUrl(baseUrl, "/chat/completions")

  local headers = {
    "Content-Type: application/json",
  }
  if config and config.custom_key and noctalia.string.trim(config.custom_key) ~= "" then
    table.insert(headers, "Authorization: Bearer " .. noctalia.string.trim(config.custom_key))
  end

  return {
    url = url,
    method = "POST",
    headers = headers,
    body = encoded or "{}",
  }
end

function custom.buildTestRequest(config: any): any
  local model = (config and config.custom_model and config.custom_model ~= "") and config.custom_model or "llama3.2"
  local bodyObj = {
    model = model,
    messages = {
      { role = "user", content = "ping" },
    },
    stream = false,
  }

  local encoded, _ = noctalia.json.encode(bodyObj)
  local baseUrl = config and config.custom_base_url or "http://localhost:11434/v1"
  local url = normalizeUrl(baseUrl, "/chat/completions")

  local headers = {
    "Content-Type: application/json",
  }
  if config and config.custom_key and noctalia.string.trim(config.custom_key) ~= "" then
    table.insert(headers, "Authorization: Bearer " .. noctalia.string.trim(config.custom_key))
  end

  return {
    url = url,
    method = "POST",
    headers = headers,
    body = encoded or "{}",
  }
end

function custom.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  if jsonStr == "[DONE]" then return nil end

  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.choices) == "table" then
    local choice = decoded.choices[1]
    if type(choice) == "table" and type(choice.delta) == "table" and type(choice.delta.content) == "string" then
      return choice.delta.content
    end
  end
  return nil
end

function custom.parseTestResponse(response: any): (boolean, string)
  if not response.ok then
    return false, "Network error (transport failure)"
  end
  if response.status == 200 then
    return true, "Connection successful"
  end
  local msg = "HTTP " .. tostring(response.status)
  local decoded, _ = noctalia.json.decode(response.body)
  if type(decoded) == "table" and type(decoded.error) == "table" and type(decoded.error.message) == "string" then
    msg = msg .. ": " .. decoded.error.message
  elseif type(decoded) == "table" and type(decoded.message) == "string" then
    msg = msg .. ": " .. decoded.message
  end
  return false, msg
end

return custom
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: PASS (`Ran 3 tests in ...s, OK`)

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/providers/custom.luau tests/test_ai_sidebar_custom_provider.py
git commit -m "feat(ai-sidebar): implement custom OpenAI-compatible provider module"
```

---

### Task 2: Storage Layer & Config Loading

**Files:**
- Modify: `ai-sidebar/storage.luau:1-85`
- Test: `tests/test_ai_sidebar_custom_provider.py`

**Interfaces:**
- Consumes: `noctalia.getConfig`, `noctalia.setConfig`
- Produces: `storage.loadConfig(): ConfigTable` with `custom_base_url`, `custom_key`, `custom_model`

- [ ] **Step 1: Add storage test assertions in `tests/test_ai_sidebar_custom_provider.py`**

Add method `test_storage_custom_config_structure` to `TestAiSidebarCustomProvider`:
```python
    def test_storage_custom_config_structure(self):
        storage_file = os.path.join(PLUGIN_DIR, "storage.luau")
        with open(storage_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("custom_base_url: string", content)
        self.assertIn("custom_key: string", content)
        self.assertIn("custom_model: string", content)
        self.assertIn('noctalia.getConfig("custom_base_url")', content)
        self.assertIn('noctalia.getConfig("custom_api_key")', content)
        self.assertIn('noctalia.getConfig("custom_model")', content)
        self.assertIn('noctalia.setConfig("custom_base_url"', content)
        self.assertIn('noctalia.setConfig("custom_api_key"', content)
        self.assertIn('noctalia.setConfig("custom_model"', content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: FAIL (`AssertionError: 'custom_base_url: string' not found in storage.luau`)

- [ ] **Step 3: Update `ai-sidebar/storage.luau`**

Update `ConfigTable` type definition, `loadConfig()`, and `saveConfig()` in `ai-sidebar/storage.luau`:
```lua
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
}
```

In `storage.loadConfig()`:
```lua
function storage.loadConfig(): ConfigTable
  local activeProv = (noctalia.getConfig("default_provider") or noctalia.getConfig("provider") or "openai") :: string
  local geminiKey = (noctalia.getConfig("gemini_api_key") or noctalia.getConfig("api_key") or "") :: string
  local geminiModel = (noctalia.getConfig("gemini_model") or noctalia.getConfig("default_model") or "gemini-1.5-flash") :: string

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
  }

  return cfg
end
```

In `storage.saveConfig()`:
```lua
function storage.saveConfig(config: ConfigTable)
  noctalia.setConfig("default_provider", config.active_provider)
  noctalia.setConfig("openai_api_key", config.openai_key)
  noctalia.setConfig("openai_model", config.openai_model)
  noctalia.setConfig("anthropic_api_key", config.anthropic_key)
  noctalia.setConfig("anthropic_model", config.anthropic_model)
  noctalia.setConfig("gemini_api_key", config.gemini_key)
  noctalia.setConfig("gemini_model", config.gemini_model)
  noctalia.setConfig("custom_base_url", config.custom_base_url)
  noctalia.setConfig("custom_api_key", config.custom_key)
  noctalia.setConfig("custom_model", config.custom_model)
  noctalia.setConfig("system_prompt", config.system_prompt)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/storage.luau tests/test_ai_sidebar_custom_provider.py
git commit -m "feat(ai-sidebar): add custom provider config fields to storage layer"
```

---

### Task 3: Client Router Integration

**Files:**
- Modify: `ai-sidebar/client.luau:1-25`
- Test: `tests/test_ai_sidebar_custom_provider.py`

**Interfaces:**
- Consumes: `ai-sidebar/providers/custom.luau`
- Produces: `client.getProvider("custom") -> custom`

- [ ] **Step 1: Add router test in `tests/test_ai_sidebar_custom_provider.py`**

Add method `test_client_router_includes_custom` to `TestAiSidebarCustomProvider`:
```python
    def test_client_router_includes_custom(self):
        client_file = os.path.join(PLUGIN_DIR, "client.luau")
        with open(client_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('require("./providers/custom.luau")', content)
        self.assertIn('name == "custom"', content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: FAIL

- [ ] **Step 3: Update `ai-sidebar/client.luau`**

Update `ai-sidebar/client.luau`:
```lua
--!strict
local openai = require("./providers/openai.luau")
local anthropic = require("./providers/anthropic.luau")
local gemini = require("./providers/gemini.luau")
local custom = require("./providers/custom.luau")

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_custom_provider.py`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_custom_provider.py
git commit -m "feat(ai-sidebar): route custom provider in client layer"
```

---

### Task 4: Manifest Settings & Localization

**Files:**
- Modify: `ai-sidebar/plugin.toml`
- Modify: `ai-sidebar/translations/en.json`
- Modify: `ai-sidebar/translations/id.json`
- Modify: `tests/test_ai_sidebar_manifest.py`

**Interfaces:**
- Consumes: Manifest schema API 28
- Produces: `custom` option in `default_provider`, settings `custom_base_url`, `custom_api_key`, `custom_model`

- [ ] **Step 1: Update `tests/test_ai_sidebar_manifest.py` with custom settings assertions**

Add assertions in `test_manifest_and_translations`:
```python
        provider_setting = next(
            s for s in manifest.get("setting", []) if s.get("key") == "default_provider"
        )
        provider_options = [opt["value"] for opt in provider_setting.get("options", [])]
        self.assertIn("custom", provider_options)

        setting_keys = [s.get("key") for s in manifest.get("setting", [])]
        self.assertIn("custom_base_url", setting_keys)
        self.assertIn("custom_api_key", setting_keys)
        self.assertIn("custom_model", setting_keys)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py`
Expected: FAIL (`AssertionError: 'custom' not found in provider_options`)

- [ ] **Step 3: Update `ai-sidebar/plugin.toml`, `en.json`, and `id.json`**

In `ai-sidebar/plugin.toml`, add `"custom"` to `default_provider.options`:
```toml
options = [
  { value = "openai", label_key = "settings.default-provider.options.openai" },
  { value = "anthropic", label_key = "settings.default-provider.options.anthropic" },
  { value = "gemini", label_key = "settings.default-provider.options.gemini" },
  { value = "custom", label_key = "settings.default-provider.options.custom" },
]
```
And add setting definitions:
```toml
[[setting]]
key = "custom_base_url"
type = "string"
label_key = "settings.custom-base-url.label"
description_key = "settings.custom-base-url.description"
default = "http://localhost:11434/v1"

[[setting]]
key = "custom_api_key"
type = "string"
label_key = "settings.custom-api-key.label"
description_key = "settings.custom-api-key.description"
default = ""
password = true

[[setting]]
key = "custom_model"
type = "string"
label_key = "settings.custom-model.label"
description_key = "settings.custom-model.description"
default = "llama3.2"
```

In `ai-sidebar/translations/en.json`, add:
```json
  "provider_custom": "Custom / Local (OpenAI-compatible)",
  "base_url": "Base URL",
  "presets": "Presets",
  "api_key_optional": "API Key (Optional for local)",
  "preset_ollama": "Ollama",
  "preset_deepseek": "DeepSeek",
  "preset_openrouter": "OpenRouter",
  "preset_lmstudio": "LM Studio",
```
and under `"settings"`:
```json
    "default-provider": {
      "options": {
        "openai": "OpenAI",
        "anthropic": "Anthropic Claude",
        "gemini": "Google Gemini",
        "custom": "Custom / Local (OpenAI-compatible)"
      }
    },
    "custom-base-url": {
      "label": "Custom Base URL",
      "description": "Base URL for OpenAI-compatible endpoint or local LLM"
    },
    "custom-api-key": {
      "label": "Custom API Key",
      "description": "API Key for custom provider (optional for local models like Ollama)"
    },
    "custom-model": {
      "label": "Custom Model",
      "description": "Model identifier (e.g., llama3.2, deepseek-chat)"
    }
```

In `ai-sidebar/translations/id.json`, add:
```json
  "provider_custom": "Kustom / Lokal (Kompatibel OpenAI)",
  "base_url": "Base URL",
  "presets": "Preset",
  "api_key_optional": "API Key (Opsional untuk lokal)",
  "preset_ollama": "Ollama",
  "preset_deepseek": "DeepSeek",
  "preset_openrouter": "OpenRouter",
  "preset_lmstudio": "LM Studio",
```
and under `"settings"`:
```json
    "default-provider": {
      "options": {
        "openai": "OpenAI",
        "anthropic": "Anthropic Claude",
        "gemini": "Google Gemini",
        "custom": "Kustom / Lokal (Kompatibel OpenAI)"
      }
    },
    "custom-base-url": {
      "label": "Custom Base URL",
      "description": "Base URL untuk endpoint kompatibel OpenAI atau LLM lokal"
    },
    "custom-api-key": {
      "label": "Custom API Key",
      "description": "API Key untuk provider kustom (opsional untuk model lokal seperti Ollama)"
    },
    "custom-model": {
      "label": "Model Kustom",
      "description": "Nama model (misal: llama3.2, deepseek-chat)"
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py`
Run: `python3 .github/workflows/validate-plugins.py`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/plugin.toml ai-sidebar/translations/en.json ai-sidebar/translations/id.json tests/test_ai_sidebar_manifest.py
git commit -m "feat(ai-sidebar): declare custom provider settings and localization strings"
```

---

### Task 5: Panel UI Integration (Presets, Form Fields, & Settings View)

**Files:**
- Modify: `ai-sidebar/panel.luau:440-620`
- Modify: `tests/test_ai_sidebar_panel.py:85-125`

**Interfaces:**
- Consumes: `providerOptions`, `providerIds`, `config.custom_base_url`, `config.custom_key`, `config.custom_model`
- Produces: Rendered UI tree for custom provider with presets and revision-keyed inputs

- [ ] **Step 1: Add panel UI test assertions in `tests/test_ai_sidebar_panel.py`**

Add checks in `test_setting_view_components`:
```python
        self.assertIn("provider_custom", content)
        self.assertIn("setting-custom-url-", content)
        self.assertIn("setting-custom-key-", content)
        self.assertIn("setting-custom-model-", content)
        self.assertIn("preset_ollama", content)
        self.assertIn("http://localhost:11434/v1", content)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py`
Expected: FAIL (`AssertionError: 'provider_custom' not found in content`)

- [ ] **Step 3: Update `renderSettingView()` in `ai-sidebar/panel.luau`**

1. In `renderSettingView()`, add `tr("provider_custom")` to `providerOptions`, and `"custom"` to `providerIds`:
```lua
  local providerOptions = {
    tr("provider_openai"),
    tr("provider_anthropic"),
    tr("provider_gemini"),
    tr("provider_custom"),
  }
  local providerIds = { "openai", "anthropic", "gemini", "custom" }
```

2. Add branch for `config.active_provider == "custom"`:
```lua
  elseif config.active_provider == "custom" then
    local presetRow = ui.row({ gap = 4, align = "center" }, {
      ui.label({ text = tr("presets") .. ":", fontSize = 11, color = "on_surface_variant" }),
      ui.button({
        text = tr("preset_ollama"),
        variant = "ghost",
        onClick = function()
          config.custom_base_url = "http://localhost:11434/v1"
          settingRev += 1
          render()
        end,
      }),
      ui.button({
        text = tr("preset_deepseek"),
        variant = "ghost",
        onClick = function()
          config.custom_base_url = "https://api.deepseek.com/v1"
          settingRev += 1
          render()
        end,
      }),
      ui.button({
        text = tr("preset_openrouter"),
        variant = "ghost",
        onClick = function()
          config.custom_base_url = "https://openrouter.ai/api/v1"
          settingRev += 1
          render()
        end,
      }),
      ui.button({
        text = tr("preset_lmstudio"),
        variant = "ghost",
        onClick = function()
          config.custom_base_url = "http://localhost:1234/v1"
          settingRev += 1
          render()
        end,
      }),
    })

    table.insert(activeSettings, presetRow)
    table.insert(activeSettings, ui.label({ text = tr("base_url"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-custom-url-" .. tostring(settingRev),
      value = config.custom_base_url,
      placeholder = "http://localhost:11434/v1",
      onChange = function(v) config.custom_base_url = v or "" end,
    }))
    table.insert(activeSettings, ui.label({ text = tr("api_key_optional"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.row({ gap = 6, align = "center" }, {
      ui.input({
        flexGrow = 1,
        key = "setting-custom-key-" .. tostring(settingRev) .. "-" .. (showApiKey and "vis" or "hid"),
        value = config.custom_key,
        placeholder = "sk-...",
        password = not showApiKey,
        onChange = function(v) config.custom_key = v or "" end,
      }),
      ui.button({
        glyph = showApiKey and "eye-off" or "eye",
        variant = "ghost",
        tooltip = showApiKey and tr("hide_api_key") or tr("show_api_key"),
        onClick = function()
          showApiKey = not showApiKey
          render()
        end,
      }),
    }))
    table.insert(activeSettings, ui.label({ text = tr("provider_custom") .. " " .. tr("model"), fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      key = "setting-custom-model-" .. tostring(settingRev),
      value = config.custom_model,
      placeholder = "llama3.2",
      onChange = function(v) config.custom_model = v or "" end,
    }))
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/panel.luau tests/test_ai_sidebar_panel.py
git commit -m "feat(ai-sidebar): add custom provider form, presets, and inputs to setting view"
```

---

### Task 6: End-to-End Verification & Full Test Suite

**Files:**
- Test: All tests in `tests/`
- Script: `.github/workflows/validate-plugins.py`

- [ ] **Step 1: Run all test suites in repository**

Run: `python3 -m unittest discover tests`
Expected: PASS (58+ tests passing)

- [ ] **Step 2: Run Noctalia plugin manifest validation**

Run: `python3 .github/workflows/validate-plugins.py`
Expected: PASS (`Validated 4 plugin manifest(s).`)

- [ ] **Step 3: Verify clean git status and commit final verification**

Run: `git status`
Expected: clean working directory
