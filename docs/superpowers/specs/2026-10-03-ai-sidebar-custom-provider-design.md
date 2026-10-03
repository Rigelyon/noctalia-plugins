# AI Sidebar: Custom & Local LLM Provider Design Specification

## 1. Overview & Objectives

This specification defines the extension of **AI Sidebar (`rigelyon/ai-sidebar`)** to support local LLMs (via Ollama, LocalAI, LM Studio, vLLM) and arbitrary OpenAI-compatible custom endpoints (such as DeepSeek, OpenRouter, and Groq).

### Core Goals:
- **Local & Privacy-Focused LLM Support**: Allow users to run AI chat completely offline or on local infrastructure (e.g., `http://localhost:11434/v1`) without requiring paid cloud API keys.
- **Generic OpenAI-Compatible Standard**: Connect to any endpoint adhering to the `/chat/completions` REST and SSE specification.
- **Quick Endpoint Presets**: One-click preset buttons for common providers (Ollama, DeepSeek, OpenRouter, LM Studio) that automatically populate the Base URL while keeping model and key inputs user-controlled.
- **Optional Authentication**: Allow leaving API keys empty for local engines that do not require authentication, while supporting Bearer token headers when configured.
- **Robust Error & Stream Handling**: Handle trailing slashes in URLs, network errors, and streaming chunks smoothly with Noctalia's 80ms CPU budget throttle.

---

## 2. Architecture & Directory Changes

The existing modular architecture of `ai-sidebar` is extended with a new provider module `providers/custom.luau`.

```text
ai-sidebar/
├── plugin.toml                      # Manifest with 'custom' provider option & custom settings
├── storage.luau                     # ConfigTable extended with custom_base_url, custom_key, custom_model
├── client.luau                      # Routes 'custom' provider to providers/custom.luau
├── providers/
│   ├── openai.luau                  # Existing OpenAI provider
│   ├── anthropic.luau               # Existing Anthropic provider
│   ├── gemini.luau                  # Existing Gemini provider
│   └── custom.luau                  # NEW: Generic OpenAI-compatible local/custom provider
├── panel.luau                       # UI setting view updated with presets, base URL input, and key toggle
└── translations/
    ├── en.json                      # English translation keys
    └── id.json                      # Indonesian translation keys
```

---

## 3. Configuration & Manifest Specification (`plugin.toml`)

### 3.1 Provider Option
The `default_provider` select setting options list in `plugin.toml` will include `"custom"`:

```toml
[[setting]]
key = "default_provider"
type = "select"
label_key = "settings.default-provider.label"
description_key = "settings.default-provider.description"
default = "openai"
options = [
  { value = "openai", label_key = "settings.default-provider.options.openai" },
  { value = "anthropic", label_key = "settings.default-provider.options.anthropic" },
  { value = "gemini", label_key = "settings.default-provider.options.gemini" },
  { value = "custom", label_key = "settings.default-provider.options.custom" },
]
```

### 3.2 Custom Provider Settings
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

---

## 4. Storage Layer (`storage.luau`)

### 4.1 Config Model
The `ConfigTable` type definition is updated:
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

### 4.2 Config Loading & Saving
- `storage.loadConfig()`:
  - `custom_base_url = (noctalia.getConfig("custom_base_url") or "http://localhost:11434/v1") :: string`
  - `custom_key = (noctalia.getConfig("custom_api_key") or "") :: string`
  - `custom_model = (noctalia.getConfig("custom_model") or "llama3.2") :: string`
- `storage.saveConfig(cfg)`:
  - Saves `custom_base_url`, `custom_api_key`, and `custom_model` via `noctalia.setConfig()`.

---

## 5. Provider Implementation (`providers/custom.luau`)

### 5.1 URL Normalization
Local and custom base URLs can vary widely:
- `http://localhost:11434`
- `http://localhost:11434/`
- `http://localhost:11434/v1`
- `http://localhost:11434/v1/`
- `https://api.deepseek.com`
- `https://api.deepseek.com/v1`

A normalization helper ensures proper endpoint resolution:
```lua
local function normalizeUrl(baseUrl: string, endpoint: string): string
  local trimmed = noctalia.string.trim(baseUrl)
  if trimmed == "" then
    trimmed = "http://localhost:11434/v1"
  end
  -- Strip trailing slashes
  while trimmed:sub(-1) == "/" do
    trimmed = trimmed:sub(1, #trimmed - 1)
  end
  -- If endpoint is /chat/completions, ensure baseUrl ends with /v1 unless explicitly specified
  if not trimmed:find("/v1$") and not trimmed:find("/v%d+$") then
    trimmed = trimmed .. "/v1"
  end
  return trimmed .. endpoint
end
```

### 5.2 Header Composition
Headers dynamically include `Authorization: Bearer <key>` only when an API key is non-empty:
```lua
local headers = {
  "Content-Type: application/json",
}
if config.custom_key and noctalia.string.trim(config.custom_key) ~= "" then
  table.insert(headers, "Authorization: Bearer " .. noctalia.string.trim(config.custom_key))
end
```

### 5.3 Streaming Chat Request (`buildChatRequest`)
Formats payload according to standard OpenAI completions format:
```json
{
  "model": "llama3.2",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "stream": true
}
```

### 5.4 Test Connection Request (`buildTestRequest`)
Sends a non-streaming test payload with minimal token generation:
```json
{
  "model": "llama3.2",
  "messages": [
    { "role": "user", "content": "ping" }
  ],
  "stream": false
}
```

### 5.5 Response & Stream Parsers
- `parseStreamLine(line)`:
  - Looks for `data: ` prefix.
  - Skips `[DONE]`.
  - Decodes JSON and extracts `choices[1].delta.content`.
- `parseTestResponse(response)`:
  - If `response.status == 200`: returns `(true, "Connection successful")`.
  - Else: attempts to decode error body and returns `(false, "HTTP <status>: <details>")`.

---

## 6. UI / UX Design (`panel.luau`)

### 6.1 Provider Selector
The `ui.select` dropdown in the `Setting` tab includes:
1. OpenAI
2. Anthropic Claude
3. Google Gemini
4. Custom / Local (OpenAI-compatible)

### 6.2 Preset Buttons
When `"custom"` is selected, a row of quick preset buttons appears above the Base URL input:
- **Ollama**: sets `Base URL` to `http://localhost:11434/v1`
- **DeepSeek**: sets `Base URL` to `https://api.deepseek.com/v1`
- **OpenRouter**: sets `Base URL` to `https://openrouter.ai/api/v1`
- **LM Studio**: sets `Base URL` to `http://localhost:1234/v1`

*(Per design requirement: Clicking a preset updates ONLY the Base URL. Model name and API key remain user-configured).*

### 6.3 Settings Form Fields
1. **Presets Row**: `ui.row` with compact ghost buttons.
2. **Base URL Input**: `key = "setting-custom-url-" .. settingRev`, placeholder `"http://localhost:11434/v1"`.
3. **API Key Input**: `key = "setting-custom-key-" .. settingRev .. "-" .. (showApiKey and "vis" or "hid")`, with `password = not showApiKey` and eye toggle button. Placeholder: `"Optional for local models (e.g. Ollama)"`.
4. **Model Input**: `key = "setting-custom-model-" .. settingRev`, placeholder `"llama3.2"`.
5. **System Prompt**: Shared multiline input.
6. **Test Connection Section**:
   - `Test Connection` button.
   - Dedicated multiline banner below the button displaying success or the complete formatted error without clipping.

---

## 7. Localization Strings

### 7.1 English (`translations/en.json`)
```json
{
  "provider_custom": "Custom / Local (OpenAI-compatible)",
  "base_url": "Base URL",
  "presets": "Presets",
  "api_key_optional": "API Key (Optional for local)",
  "settings": {
    "default-provider": {
      "options": {
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
  }
}
```

### 7.2 Indonesian (`translations/id.json`)
```json
{
  "provider_custom": "Kustom / Lokal (Kompatibel OpenAI)",
  "base_url": "Base URL",
  "presets": "Preset",
  "api_key_optional": "API Key (Opsional untuk lokal)",
  "settings": {
    "default-provider": {
      "options": {
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
  }
}
```

---

## 8. Testing & Validation Strategy

1. **Dedicated Provider Unit Tests (`tests/test_ai_sidebar_custom_provider.py`)**:
   - Verify `buildChatRequest` produces valid OpenAI-format body and SSE stream flags.
   - Verify URL normalization correctly resolves trailing slashes and missing `/v1`.
   - Verify `Authorization` header is present when key is non-empty, and omitted when key is empty.
   - Verify `parseStreamLine` extracts content tokens and ignores keepalive / `[DONE]` lines.
   - Verify `parseTestResponse` handles HTTP 200, HTTP 401, HTTP 404, and network errors.

2. **Panel UI & Translation Tests (`tests/test_ai_sidebar_panel.py`)**:
   - Verify `provider_custom` is rendered in `renderSettingView`.
   - Verify all translation keys exist in both `en.json` and `id.json`.
   - Verify custom setting keys (`custom_base_url`, `custom_api_key`, `custom_model`) use revision keying.

3. **Manifest Validation (`tests/test_ai_sidebar_manifest.py` & `.github/workflows/validate-plugins.py`)**:
   - Verify `plugin.toml` setting declarations conform to Noctalia plugin API schema.
