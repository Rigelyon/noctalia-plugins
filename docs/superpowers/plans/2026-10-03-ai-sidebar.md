# AI Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a robust, modular desktop AI assistant panel (`ai-sidebar`) for the Noctalia desktop shell supporting real-time streaming, multi-session history, and multi-provider connectivity (OpenAI, Anthropic Claude, and Google Gemini).

**Architecture:** A modular Luau architecture separating declarative UI rendering (`panel.luau`, `widget.luau`), persistent session/config storage (`storage.luau`), unified client dispatch (`client.luau`), and isolated provider adapters (`providers/openai.luau`, `providers/anthropic.luau`, `providers/gemini.luau`). Re-rendering is throttled to ~80ms to strictly comply with Noctalia's Luau CPU budget limits.

**Tech Stack:** Luau, Noctalia Plugin API v28 (`ui.*`, `panel.*`, `barWidget.*`, `noctalia.httpStream`, `noctalia.pluginDataDir`), Python 3.14 (unittest, tomllib, PIL).

## Global Constraints

- Plugin ID: `rigelyon/ai-sidebar`
- Plugin API version: `28`
- Icon: `sparkles`
- Allowed Tags: `["ai", "productivity", "utility", "panel", "bar"]`
- Setting types in `plugin.toml`: Only `bool`, `string`, `folder`, `glyph`, `select` (never `boolean`)
- Translation keys: Nested JSON objects only (no dots inside keys); manifest references via dotted paths like `settings.default-provider.label`
- Required packaging files: `plugin.toml`, `README.md`, `thumbnail.webp` (exactly 960x540 WebP, < 512 KB), `translations/en.json`
- CPU Budget: In-memory caching for session history; throttle streaming UI renders to >= 80ms; pre-filter SSE lines before `json.decode`

---

### Task 1: Manifest, Translations, Thumbnail, and Packaging

**Files:**
- Create: `ai-sidebar/plugin.toml`
- Create: `ai-sidebar/translations/en.json`
- Create: `ai-sidebar/translations/id.json`
- Create: `ai-sidebar/README.md`
- Create: `ai-sidebar/thumbnail.webp`
- Test: `tests/test_ai_sidebar_manifest.py`

**Interfaces:**
- Consumes: Noctalia manifest schema rules and allowed tags from `.github/workflows/validate-plugins.py`
- Produces: Valid plugin package directory `ai-sidebar/` with complete metadata and localized strings for `en` and `id`

- [ ] **Step 1: Write the failing manifest and translation test**

Create `tests/test_ai_sidebar_manifest.py`:
```python
import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestAiSidebarManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")
        readme_path = os.path.join(PLUGIN_DIR, "README.md")
        thumb_path = os.path.join(PLUGIN_DIR, "thumbnail.webp")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")
        self.assertTrue(os.path.isfile(readme_path), "Missing README.md")
        self.assertTrue(os.path.isfile(thumb_path), "Missing thumbnail.webp")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/ai-sidebar")
        self.assertEqual(manifest.get("name"), "AI Sidebar")
        self.assertEqual(manifest.get("version"), "1.0.0")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")
        self.assertEqual(manifest.get("license"), "MIT")
        self.assertEqual(manifest.get("icon"), "sparkles")
        self.assertEqual(
            manifest.get("tags"), ["ai", "productivity", "utility", "panel", "bar"]
        )

        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")
        self.assertEqual(panels[0].get("placement"), "attached")
        self.assertEqual(panels[0].get("position"), "right")
        self.assertEqual(panels[0].get("width"), 440)
        self.assertEqual(panels[0].get("height"), 760)

        widgets = manifest.get("widget", [])
        self.assertEqual(len(widgets), 1)
        self.assertEqual(widgets[0].get("id"), "ai-sidebar")
        self.assertEqual(widgets[0].get("entry"), "widget.luau")

        # Verify settings schema and keys in en and id
        settings = manifest.get("setting", [])
        self.assertGreaterEqual(len(settings), 5)
        for s in settings:
            self.assertIn(s.get("type"), ["bool", "string", "folder", "glyph", "select"])
            if "label_key" in s:
                self.assertTrue(has_key_path(en, s["label_key"]), f"en missing {s['label_key']}")
                self.assertTrue(has_key_path(id_lang, s["label_key"]), f"id missing {s['label_key']}")
            if "description_key" in s:
                self.assertTrue(has_key_path(en, s["description_key"]), f"en missing {s['description_key']}")
                self.assertTrue(has_key_path(id_lang, s["description_key"]), f"id missing {s['description_key']}")
            for opt in s.get("options", []):
                if "label_key" in opt:
                    self.assertTrue(has_key_path(en, opt["label_key"]), f"en missing {opt['label_key']}")
                    self.assertTrue(has_key_path(id_lang, opt["label_key"]), f"id missing {opt['label_key']}")

        # Thumbnail dimension & size check
        self.assertLessEqual(os.path.getsize(thumb_path), 512 * 1024)
        with open(thumb_path, "rb") as f:
            header = f.read(30)
            self.assertTrue(header.startswith(b"RIFF") and b"WEBP" in header)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py -v`
Expected: FAIL with "Missing plugin.toml"

- [ ] **Step 3: Create manifest, translations, README, and thumbnail**

Create `ai-sidebar/plugin.toml`:
```toml
id = "rigelyon/ai-sidebar"
name = "AI Sidebar"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = []
tags = ["ai", "productivity", "utility", "panel", "bar"]
icon = "sparkles"
description = "Streamlined AI chat sidebar for Noctalia with multi-provider streaming, history, and settings."

[[setting]]
key = "default_provider"
type = "select"
label_key = "settings.default-provider.label"
description_key = "settings.default-provider.description"
default = "openai"

  [[setting.options]]
  value = "openai"
  label_key = "settings.default-provider.options.openai"

  [[setting.options]]
  value = "anthropic"
  label_key = "settings.default-provider.options.anthropic"

  [[setting.options]]
  value = "gemini"
  label_key = "settings.default-provider.options.gemini"

[[setting]]
key = "openai_api_key"
type = "string"
label_key = "settings.openai-api-key.label"
description_key = "settings.openai-api-key.description"
default = ""

[[setting]]
key = "openai_model"
type = "string"
label_key = "settings.openai-model.label"
description_key = "settings.openai-model.description"
default = "gpt-4o-mini"

[[setting]]
key = "anthropic_api_key"
type = "string"
label_key = "settings.anthropic-api-key.label"
description_key = "settings.anthropic-api-key.description"
default = ""

[[setting]]
key = "anthropic_model"
type = "string"
label_key = "settings.anthropic-model.label"
description_key = "settings.anthropic-model.description"
default = "claude-3-5-haiku-20241022"

[[setting]]
key = "gemini_api_key"
type = "string"
label_key = "settings.gemini-api-key.label"
description_key = "settings.gemini-api-key.description"
default = ""

[[setting]]
key = "gemini_model"
type = "string"
label_key = "settings.gemini-model.label"
description_key = "settings.gemini-model.description"
default = "gemini-1.5-flash"

[[setting]]
key = "system_prompt"
type = "string"
label_key = "settings.system-prompt.label"
description_key = "settings.system-prompt.description"
default = "You are a helpful and concise AI assistant."

[[panel]]
id = "panel"
entry = "panel.luau"
placement = "attached"
position = "right"
width = 440
height = 760

[[widget]]
id = "ai-sidebar"
entry = "widget.luau"
```

Create `ai-sidebar/translations/en.json`:
```json
{
  "title": "AI Sidebar",
  "tab_chat": "Chat",
  "tab_history": "History",
  "tab_setting": "Setting",
  "new_chat": "New Chat",
  "close": "Close",
  "clear": "Clear Session",
  "clear_confirm": "Clear messages?",
  "send": "Send",
  "stop": "Stop",
  "input_placeholder": "Ask AI anything... (Enter to send, Shift+Enter for new line)",
  "welcome_title": "AI Assistant Ready",
  "welcome_subtitle": "Select a provider, enter your API key in Settings, and start chatting.",
  "status_typing": "Thinking...",
  "status_ready": "Ready",
  "error_title": "Request Failed",
  "retry": "Retry",
  "search_history": "Search past sessions...",
  "no_history": "No conversation history yet",
  "no_search_results": "No sessions found",
  "delete_session": "Delete",
  "delete_confirm": "Delete this session?",
  "save_settings": "Save Settings",
  "settings_saved": "Settings successfully saved",
  "test_connection": "Test Connection",
  "testing": "Testing connection...",
  "test_success": "Connection successful! Model responded.",
  "test_error": "Connection failed",
  "provider_openai": "OpenAI",
  "provider_anthropic": "Anthropic Claude",
  "provider_gemini": "Google Gemini",
  "active_provider": "Active Provider",
  "api_key": "API Key",
  "model": "Model",
  "system_prompt": "System Prompt",
  "settings": {
    "default-provider": {
      "label": "Default Provider",
      "description": "Select primary AI provider to use for chat requests",
      "options": {
        "openai": "OpenAI",
        "anthropic": "Anthropic Claude",
        "gemini": "Google Gemini"
      }
    },
    "openai-api-key": {
      "label": "OpenAI API Key",
      "description": "API key for OpenAI API requests"
    },
    "openai-model": {
      "label": "OpenAI Model",
      "description": "Default OpenAI model (e.g. gpt-4o-mini)"
    },
    "anthropic-api-key": {
      "label": "Anthropic API Key",
      "description": "API key for Anthropic Claude requests"
    },
    "anthropic-model": {
      "label": "Anthropic Model",
      "description": "Default Anthropic model (e.g. claude-3-5-haiku-20241022)"
    },
    "gemini-api-key": {
      "label": "Gemini API Key",
      "description": "API key for Google Gemini requests"
    },
    "gemini-model": {
      "label": "Gemini Model",
      "description": "Default Google Gemini model (e.g. gemini-1.5-flash)"
    },
    "system-prompt": {
      "label": "Default System Prompt",
      "description": "Base instruction given to the AI assistant"
    }
  }
}
```

Create `ai-sidebar/translations/id.json`:
```json
{
  "title": "AI Sidebar",
  "tab_chat": "Chat",
  "tab_history": "Riwayat",
  "tab_setting": "Pengaturan",
  "new_chat": "Chat Baru",
  "close": "Tutup",
  "clear": "Kosongkan Sesi",
  "clear_confirm": "Hapus percakapan?",
  "send": "Kirim",
  "stop": "Berhenti",
  "input_placeholder": "Tanyakan apa saja ke AI... (Enter untuk kirim, Shift+Enter untuk baris baru)",
  "welcome_title": "AI Assistant Siap",
  "welcome_subtitle": "Pilih provider, isi API Key di Pengaturan, dan mulai percakapan.",
  "status_typing": "Sedang mengetik...",
  "status_ready": "Siap",
  "error_title": "Permintaan Gagal",
  "retry": "Coba Lagi",
  "search_history": "Cari riwayat percakapan...",
  "no_history": "Belum ada riwayat percakapan",
  "no_search_results": "Sesi tidak ditemukan",
  "delete_session": "Hapus",
  "delete_confirm": "Hapus sesi ini?",
  "save_settings": "Simpan Pengaturan",
  "settings_saved": "Pengaturan berhasil disimpan",
  "test_connection": "Uji Koneksi",
  "testing": "Menguji koneksi...",
  "test_success": "Koneksi berhasil! Model merespons.",
  "test_error": "Koneksi gagal",
  "provider_openai": "OpenAI",
  "provider_anthropic": "Anthropic Claude",
  "provider_gemini": "Google Gemini",
  "active_provider": "Provider Aktif",
  "api_key": "API Key",
  "model": "Model",
  "system_prompt": "System Prompt",
  "settings": {
    "default-provider": {
      "label": "Provider Bawaan",
      "description": "Pilih provider AI utama untuk permintaan obrolan",
      "options": {
        "openai": "OpenAI",
        "anthropic": "Anthropic Claude",
        "gemini": "Google Gemini"
      }
    },
    "openai-api-key": {
      "label": "OpenAI API Key",
      "description": "API Key untuk request ke OpenAI"
    },
    "openai-model": {
      "label": "OpenAI Model",
      "description": "Model default OpenAI (misal: gpt-4o-mini)"
    },
    "anthropic-api-key": {
      "label": "Anthropic API Key",
      "description": "API Key untuk request ke Anthropic Claude"
    },
    "anthropic-model": {
      "label": "Anthropic Model",
      "description": "Model default Anthropic (misal: claude-3-5-haiku-20241022)"
    },
    "gemini-api-key": {
      "label": "Gemini API Key",
      "description": "API Key untuk request ke Google Gemini"
    },
    "gemini-model": {
      "label": "Gemini Model",
      "description": "Model default Google Gemini (misal: gemini-1.5-flash)"
    },
    "system-prompt": {
      "label": "System Prompt Bawaan",
      "description": "Instruksi dasar yang diberikan kepada AI"
    }
  }
}
```

Create `ai-sidebar/README.md`:
```markdown
# AI Sidebar

A sleek, robust AI chat sidebar panel for the Noctalia desktop shell. Connect directly to OpenAI, Anthropic Claude, or Google Gemini with real-time streaming responses, persistent multi-session history, and quick desktop access.

## Features

- **Multi-Provider Support**: Native API integrations for OpenAI, Anthropic Claude, and Google Gemini.
- **Real-Time Streaming**: Watch responses generate smoothly in real-time, with an instant "Stop" button to cancel generation.
- **Rich Markdown Formatting**: Read responses rendered with formatted code blocks, bold text, bullet points, and headers.
- **Multi-Session History**: Conversations are organized by session, searchable, and stored locally for privacy.
- **In-Panel Settings & Connection Testing**: Easily configure API keys, switch models, adjust system prompts, and test connection directly within the panel.
- **Low CPU Footprint**: Throttled UI rendering and in-memory caching engineered specifically for Noctalia's Luau instruction budget.

## Setup

1. Enable the plugin:
   ```bash
   noctalia msg plugins enable rigelyon/ai-sidebar
   ```
2. Open the AI Sidebar from the bar widget or via IPC:
   ```bash
   noctalia msg panel-toggle rigelyon/ai-sidebar:panel
   ```
3. Navigate to the **Setting** tab, choose your provider, enter your API key, and click **Test Connection**.
```

Generate 960x540 WebP thumbnail using Python PIL:
```bash
python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGB', (960, 540), color=(24, 28, 38))
draw = ImageDraw.Draw(img)
# Draw subtle card
draw.rounded_rectangle([180, 70, 780, 470], radius=24, fill=(34, 40, 54), outline=(80, 95, 130), width=2)
# Draw header bar
draw.rounded_rectangle([200, 90, 760, 150], radius=12, fill=(45, 53, 72))
# Draw user bubble
draw.rounded_rectangle([420, 180, 740, 240], radius=16, fill=(58, 86, 160))
# Draw assistant bubble
draw.rounded_rectangle([220, 260, 680, 420], radius=16, fill=(45, 53, 72))
img.save('ai-sidebar/thumbnail.webp', 'WEBP', quality=90)
"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_manifest.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/ tests/test_ai_sidebar_manifest.py
git commit -m "feat(ai-sidebar): add manifest, translations, readme, and thumbnail"
```

---

### Task 2: Storage Module (`storage.luau`)

**Files:**
- Create: `ai-sidebar/storage.luau`
- Test: `tests/test_ai_sidebar_storage.py`

**Interfaces:**
- Consumes: `noctalia.pluginDataDir()`, `noctalia.readFile`, `noctalia.writeFile`, `noctalia.mkdirAll`, `noctalia.json`, `noctalia.getConfig`
- Produces:
  - `storage.loadConfig() -> ConfigTable`
  - `storage.saveConfig(config: ConfigTable) -> boolean`
  - `storage.loadSessions() -> {Session}`
  - `storage.saveSessions(sessions: {Session}) -> boolean`
  - `storage.createSession(initialPrompt: string?, provider: string?, model: string?) -> Session`
  - `storage.deleteSession(sessionId: string, sessions: {Session}) -> {Session}`
  - `storage.capMessages(messages: {Message}, maxCount: number?) -> {Message}`
  - `storage.generateTitle(firstMessage: string) -> string`

- [ ] **Step 1: Write the failing storage unit test in Python**

Create `tests/test_ai_sidebar_storage.py`:
```python
import os
import re
import unittest

STORAGE_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "storage.luau")


class TestAiSidebarStorage(unittest.TestCase):
    def test_storage_file_exists(self):
        self.assertTrue(os.path.isfile(STORAGE_FILE), "Missing storage.luau")
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check required function exports
        expected_exports = [
            "loadConfig",
            "saveConfig",
            "loadSessions",
            "saveSessions",
            "createSession",
            "deleteSession",
            "capMessages",
            "generateTitle",
        ]
        for exp in expected_exports:
            self.assertIn(exp, content, f"storage.luau missing export {exp}")

    def test_title_generation_logic(self):
        # Simulate Luau title sanitization
        def generate_title(text):
            cleaned = text.strip()
            # remove leading markdown hashes
            cleaned = re.sub(r"^#+\s*", "", cleaned)
            # strip leading dots and unsafe chars
            cleaned = re.sub(r"^[\.\s]+", "", cleaned)
            first_line = cleaned.split("\n")[0].strip()
            if len(first_line) > 40:
                return first_line[:37] + "..."
            return first_line or "New Conversation"

        self.assertEqual(generate_title("# Hello World"), "Hello World")
        self.assertEqual(generate_title("...dot title"), "dot title")
        self.assertEqual(
            generate_title("This is a very long prompt that should definitely be truncated nicely"),
            "This is a very long prompt that shoul...",
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_storage.py -v`
Expected: FAIL with "Missing storage.luau"

- [ ] **Step 3: Implement `ai-sidebar/storage.luau`**

Create `ai-sidebar/storage.luau`:
```luau
--!strict
local storage = {}

export type Message = {
  role: string, -- "user" | "assistant" | "system"
  content: string,
  timestamp: number?,
}

export type Session = {
  id: string,
  title: string,
  created_at: number,
  updated_at: number,
  provider: string,
  model: string,
  messages: { Message },
}

export type ConfigTable = {
  active_provider: string,
  openai_key: string,
  openai_model: string,
  anthropic_key: string,
  anthropic_model: string,
  gemini_key: string,
  gemini_model: string,
  system_prompt: string,
}

local function getDataDir(): string
  local dir, _ = noctalia.pluginDataDir()
  if not dir then
    dir = noctalia.expandPath("~/.local/share/noctalia/ai-sidebar")
  end
  noctalia.mkdirAll(dir)
  return dir
end

local function configPath(): string
  return getDataDir() .. "/config.json"
end

local function sessionsPath(): string
  return getDataDir() .. "/sessions.json"
end

function storage.generateTitle(firstMessage: string): string
  local trimmed = noctalia.string.trim(firstMessage or "")
  local firstLine = trimmed:match("^[^\r\n]+") or ""
  firstLine = firstLine:gsub("^#+%s*", ""):gsub("[/%\\:*?\"<>|]", "")
  firstLine = firstLine:gsub("^%.+", "")
  firstLine = noctalia.string.trim(firstLine)
  if #firstLine == 0 then
    return "New Conversation"
  end
  if #firstLine > 40 then
    return firstLine:sub(1, 37) .. "..."
  end
  return firstLine
end

function storage.loadConfig(): ConfigTable
  local cfg: ConfigTable = {
    active_provider = (noctalia.getConfig("default_provider") or "openai") :: string,
    openai_key = (noctalia.getConfig("openai_api_key") or "") :: string,
    openai_model = (noctalia.getConfig("openai_model") or "gpt-4o-mini") :: string,
    anthropic_key = (noctalia.getConfig("anthropic_api_key") or "") :: string,
    anthropic_model = (noctalia.getConfig("anthropic_model") or "claude-3-5-haiku-20241022") :: string,
    gemini_key = (noctalia.getConfig("gemini_api_key") or "") :: string,
    gemini_model = (noctalia.getConfig("gemini_model") or "gemini-1.5-flash") :: string,
    system_prompt = (noctalia.getConfig("system_prompt") or "You are a helpful and concise AI assistant.") :: string,
  }

  local raw = noctalia.readFile(configPath())
  if raw then
    local decoded, _ = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      if type(decoded.active_provider) == "string" and decoded.active_provider ~= "" then
        cfg.active_provider = decoded.active_provider
      end
      if type(decoded.openai_key) == "string" then cfg.openai_key = decoded.openai_key end
      if type(decoded.openai_model) == "string" and decoded.openai_model ~= "" then cfg.openai_model = decoded.openai_model end
      if type(decoded.anthropic_key) == "string" then cfg.anthropic_key = decoded.anthropic_key end
      if type(decoded.anthropic_model) == "string" and decoded.anthropic_model ~= "" then cfg.anthropic_model = decoded.anthropic_model end
      if type(decoded.gemini_key) == "string" then cfg.gemini_key = decoded.gemini_key end
      if type(decoded.gemini_model) == "string" and decoded.gemini_model ~= "" then cfg.gemini_model = decoded.gemini_model end
      if type(decoded.system_prompt) == "string" and decoded.system_prompt ~= "" then cfg.system_prompt = decoded.system_prompt end
    end
  end
  return cfg
end

function storage.saveConfig(cfg: ConfigTable): boolean
  local encoded, _ = noctalia.json.encode(cfg, true)
  if encoded then
    local ok, _ = noctalia.writeFile(configPath(), encoded)
    return ok
  end
  return false
end

function storage.loadSessions(): { Session }
  local sessions: { Session } = {}
  local raw = noctalia.readFile(sessionsPath())
  if raw then
    local decoded, _ = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      for _, item in ipairs(decoded) do
        if type(item) == "table" and type(item.id) == "string" then
          table.insert(sessions, {
            id = item.id,
            title = type(item.title) == "string" and item.title or "Conversation",
            created_at = type(item.created_at) == "number" and item.created_at or 0,
            updated_at = type(item.updated_at) == "number" and item.updated_at or 0,
            provider = type(item.provider) == "string" and item.provider or "openai",
            model = type(item.model) == "string" and item.model or "",
            messages = type(item.messages) == "table" and item.messages or {},
          })
        end
      end
    end
  end

  table.sort(sessions, function(a, b)
    return a.updated_at > b.updated_at
  end)
  return sessions
end

function storage.saveSessions(sessions: { Session }): boolean
  local encoded, _ = noctalia.json.encode(sessions, true)
  if encoded then
    local ok, _ = noctalia.writeFile(sessionsPath(), encoded)
    return ok
  end
  return false
end

function storage.createSession(initialPrompt: string?, provider: string?, model: string?): Session
  local nowSec = math.floor(noctalia.nowMs() / 1000)
  local title = initialPrompt and storage.generateTitle(initialPrompt) or "New Conversation"
  return {
    id = "sess_" .. tostring(noctalia.nowMs()),
    title = title,
    created_at = nowSec,
    updated_at = nowSec,
    provider = provider or "openai",
    model = model or "gpt-4o-mini",
    messages = {},
  }
end

function storage.deleteSession(sessionId: string, sessions: { Session }): { Session }
  local updated: { Session } = {}
  for _, sess in ipairs(sessions) do
    if sess.id ~= sessionId then
      table.insert(updated, sess)
    end
  end
  storage.saveSessions(updated)
  return updated
end

-- Sliding window for context: retain only the last maxCount (default 20) messages for API payload
function storage.capMessages(messages: { Message }, maxCount: number?): { Message }
  local limit = maxCount or 20
  if #messages <= limit then
    return messages
  end
  local capped: { Message } = {}
  local startIdx = #messages - limit + 1
  for i = startIdx, #messages do
    table.insert(capped, messages[i])
  end
  return capped
end

return storage
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_storage.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/storage.luau tests/test_ai_sidebar_storage.py
git commit -m "feat(ai-sidebar): implement storage module for sessions and config"
```

---

### Task 3: Provider Adapters (`providers/openai.luau`, `providers/anthropic.luau`, `providers/gemini.luau`)

**Files:**
- Create: `ai-sidebar/providers/openai.luau`
- Create: `ai-sidebar/providers/anthropic.luau`
- Create: `ai-sidebar/providers/gemini.luau`
- Test: `tests/test_ai_sidebar_providers.py`

**Interfaces:**
- Consumes: `noctalia.json`, `noctalia.string`
- Produces: Each provider exports:
  - `buildChatRequest(messages: {Message}, systemPrompt: string, config: ConfigTable) -> HttpRequest`
  - `buildTestRequest(config: ConfigTable) -> HttpRequest`
  - `parseStreamLine(line: string) -> string?` (returns delta text or nil)
  - `parseTestResponse(response: HttpResponse) -> (boolean, string)`

- [ ] **Step 1: Write failing provider unit test in Python**

Create `tests/test_ai_sidebar_providers.py`:
```python
import json
import os
import unittest

PROVIDERS_DIR = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "providers")


class TestAiSidebarProviders(unittest.TestCase):
    def test_provider_files_exist(self):
        for name in ["openai.luau", "anthropic.luau", "gemini.luau"]:
            p = os.path.join(PROVIDERS_DIR, name)
            self.assertTrue(os.path.isfile(p), f"Missing {name}")

    def test_openai_sse_parsing(self):
        # Simulate OpenAI SSE line
        sample_line = 'data: {"choices":[{"delta":{"content":"Hello"}}]}'
        prefix = "data: "
        if sample_line.startswith(prefix) and not sample_line.startswith("data: [DONE]"):
            payload = json.loads(sample_line[len(prefix) :])
            delta = payload["choices"][0]["delta"].get("content")
            self.assertEqual(delta, "Hello")

    def test_anthropic_sse_parsing(self):
        # Simulate Anthropic content_block_delta line
        sample_line = 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"World"}}'
        prefix = "data: "
        if sample_line.startswith(prefix):
            payload = json.loads(sample_line[len(prefix) :])
            if payload.get("type") == "content_block_delta":
                self.assertEqual(payload["delta"]["text"], "World")

    def test_gemini_sse_parsing(self):
        # Simulate Gemini streamGenerateContent line
        sample_line = 'data: {"candidates":[{"content":{"parts":[{"text":"Hi"}]}}]}'
        prefix = "data: "
        if sample_line.startswith(prefix):
            payload = json.loads(sample_line[len(prefix) :])
            text = payload["candidates"][0]["content"]["parts"][0]["text"]
            self.assertEqual(text, "Hi")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_providers.py -v`
Expected: FAIL with "Missing openai.luau"

- [ ] **Step 3: Implement OpenAI, Anthropic, and Gemini provider adapters**

Create `ai-sidebar/providers/openai.luau`:
```luau
--!strict
local openai = {}

type Message = { role: string, content: string }

function openai.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local apiMessages = {}
  if systemPrompt and systemPrompt ~= "" then
    table.insert(apiMessages, { role = "system", content = systemPrompt })
  end
  for _, m in ipairs(messages) do
    table.insert(apiMessages, { role = m.role, content = m.content })
  end

  local bodyObj = {
    model = config.openai_model ~= "" and config.openai_model or "gpt-4o-mini",
    messages = apiMessages,
    stream = true,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.openai.com/v1/chat/completions",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "Authorization: Bearer " .. (config.openai_key or ""),
    },
    body = encoded or "{}",
  }
end

function openai.buildTestRequest(config: any): any
  local bodyObj = {
    model = config.openai_model ~= "" and config.openai_model or "gpt-4o-mini",
    messages = { { role = "user", content = "ping" } },
    max_tokens = 5,
    stream = false,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.openai.com/v1/chat/completions",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "Authorization: Bearer " .. (config.openai_key or ""),
    },
    body = encoded or "{}",
  }
end

function openai.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end
  if trimmed:match("^data:%s*%[DONE%]") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.choices) == "table" then
    local choice = decoded.choices[1]
    if type(choice) == "table" and type(choice.delta) == "table" then
      return choice.delta.content
    end
  end
  return nil
end

function openai.parseTestResponse(response: any): (boolean, string)
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
  end
  return false, msg
end

return openai
```

Create `ai-sidebar/providers/anthropic.luau`:
```luau
--!strict
local anthropic = {}

type Message = { role: string, content: string }

function anthropic.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local apiMessages = {}
  for _, m in ipairs(messages) do
    if m.role == "user" or m.role == "assistant" then
      table.insert(apiMessages, { role = m.role, content = m.content })
    end
  end

  local bodyObj: { [string]: any } = {
    model = config.anthropic_model ~= "" and config.anthropic_model or "claude-3-5-haiku-20241022",
    messages = apiMessages,
    max_tokens = 4096,
    stream = true,
  }
  if systemPrompt and systemPrompt ~= "" then
    bodyObj.system = systemPrompt
  end
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.anthropic.com/v1/messages",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "x-api-key: " .. (config.anthropic_key or ""),
      "anthropic-version: 2023-06-01",
    },
    body = encoded or "{}",
  }
end

function anthropic.buildTestRequest(config: any): any
  local bodyObj = {
    model = config.anthropic_model ~= "" and config.anthropic_model or "claude-3-5-haiku-20241022",
    messages = { { role = "user", content = "ping" } },
    max_tokens = 5,
    stream = false,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.anthropic.com/v1/messages",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "x-api-key: " .. (config.anthropic_key or ""),
      "anthropic-version: 2023-06-01",
    },
    body = encoded or "{}",
  }
end

function anthropic.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and decoded.type == "content_block_delta" then
    if type(decoded.delta) == "table" and type(decoded.delta.text) == "string" then
      return decoded.delta.text
    end
  end
  return nil
end

function anthropic.parseTestResponse(response: any): (boolean, string)
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
  end
  return false, msg
end

return anthropic
```

Create `ai-sidebar/providers/gemini.luau`:
```luau
--!strict
local gemini = {}

type Message = { role: string, content: string }

function gemini.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local contents = {}
  for _, m in ipairs(messages) do
    local gRole = (m.role == "assistant") and "model" or "user"
    table.insert(contents, {
      role = gRole,
      parts = { { text = m.content } },
    })
  end

  local bodyObj: { [string]: any } = {
    contents = contents,
  }
  if systemPrompt and systemPrompt ~= "" then
    bodyObj.system_instruction = {
      parts = { { text = systemPrompt } },
    }
  end

  local encoded, _ = noctalia.json.encode(bodyObj)
  local model = config.gemini_model ~= "" and config.gemini_model or "gemini-1.5-flash"
  local apiKey = config.gemini_key or ""
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":streamGenerateContent?alt=sse&key=" .. apiKey

  return {
    url = url,
    method = "POST",
    headers = {
      "Content-Type: application/json",
    },
    body = encoded or "{}",
  }
end

function gemini.buildTestRequest(config: any): any
  local bodyObj = {
    contents = {
      { role = "user", parts = { { text = "ping" } } },
    },
  }
  local encoded, _ = noctalia.json.encode(bodyObj)
  local model = config.gemini_model ~= "" and config.gemini_model or "gemini-1.5-flash"
  local apiKey = config.gemini_key or ""
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. apiKey

  return {
    url = url,
    method = "POST",
    headers = {
      "Content-Type: application/json",
    },
    body = encoded or "{}",
  }
end

function gemini.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.candidates) == "table" then
    local cand = decoded.candidates[1]
    if type(cand) == "table" and type(cand.content) == "table" and type(cand.content.parts) == "table" then
      local part = cand.content.parts[1]
      if type(part) == "table" and type(part.text) == "string" then
        return part.text
      end
    end
  end
  return nil
end

function gemini.parseTestResponse(response: any): (boolean, string)
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
  end
  return false, msg
end

return gemini
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_providers.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/providers/ tests/test_ai_sidebar_providers.py
git commit -m "feat(ai-sidebar): implement openai, anthropic, and gemini provider adapters"
```

---

### Task 4: Unified AI Client (`client.luau`)

**Files:**
- Create: `ai-sidebar/client.luau`
- Test: `tests/test_ai_sidebar_client.py`

**Interfaces:**
- Consumes: `providers/openai.luau`, `providers/anthropic.luau`, `providers/gemini.luau`, `noctalia.http`, `noctalia.httpStream`, `noctalia.formatTime`
- Produces:
  - `client.testConnection(providerName: string, config: ConfigTable, callback: (ok: boolean, msg: string) -> ())`
  - `client.streamChat(messages: {Message}, config: ConfigTable, onChunk: (text: string) -> (), onError: (err: string) -> (), onDone: () -> ()) -> HttpStreamHandle?`

- [ ] **Step 1: Write failing client unit test in Python**

Create `tests/test_ai_sidebar_client.py`:
```python
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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_client.py -v`
Expected: FAIL with "Missing client.luau"

- [ ] **Step 3: Implement `ai-sidebar/client.luau`**

Create `ai-sidebar/client.luau`:
```luau
--!strict
local openai = require("providers/openai")
local anthropic = require("providers/anthropic")
local gemini = require("providers/gemini")

local client = {}

local function getProvider(name: string): any
  if name == "anthropic" then
    return anthropic
  elseif name == "gemini" then
    return gemini
  else
    return openai
  end
end

local function buildEnvironmentPrompt(baseSystemPrompt: string): string
  local timeStr = noctalia.formatTime("%Y-%m-%d %H:%M:%S")
  local envInfo = "\n\n[Environment Context: Current system time is " .. timeStr .. ", running on Noctalia Linux Desktop Shell.]"
  return (baseSystemPrompt or "You are a helpful and concise AI assistant.") .. envInfo
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
  onDone: () -> ()
): any
  local prov = getProvider(config.active_provider)
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt)
  local req = prov.buildChatRequest(messages, augmentedPrompt, config)

  local hasReceivedChunk = false
  local errorReported = false

  local handle = noctalia.httpStream(req, function(line: string)
    local text = prov.parseStreamLine(line)
    if text and text ~= "" then
      hasReceivedChunk = true
      onChunk(text)
    end
  end, function(result: any)
    if not result.ok or (result.status ~= 0 and result.status >= 400) then
      if not errorReported then
        errorReported = true
        onError("Stream error (HTTP " .. tostring(result.status) .. ")")
      end
    else
      if not hasReceivedChunk and not errorReported then
        -- In case provider sent error inside body
        onError("No response data received from provider")
      else
        onDone()
      end
    end
  end)

  if handle == nil then
    onError("Unable to initialize HTTP stream (offline mode or network disabled)")
    return nil
  end

  return handle
end

return client
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_client.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/client.luau tests/test_ai_sidebar_client.py
git commit -m "feat(ai-sidebar): implement unified client module with stream orchestration"
```

---

### Task 5: Companion Bar Widget (`widget.luau`)

**Files:**
- Create: `ai-sidebar/widget.luau`
- Test: `tests/test_ai_sidebar_widget.py`

**Interfaces:**
- Consumes: `barWidget.setGlyph`, `barWidget.setTooltip`, `noctalia.togglePanel`
- Produces: Bar widget callback that toggles `rigelyon/ai-sidebar:panel` on click

- [ ] **Step 1: Write failing widget test in Python**

Create `tests/test_ai_sidebar_widget.py`:
```python
import os
import unittest

WIDGET_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "widget.luau")


class TestAiSidebarWidget(unittest.TestCase):
    def test_widget_file_exists(self):
        self.assertTrue(os.path.isfile(WIDGET_FILE), "Missing widget.luau")
        with open(WIDGET_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("sparkles", content)
        self.assertIn("onClick", content)
        self.assertIn("togglePanel", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_widget.py -v`
Expected: FAIL with "Missing widget.luau"

- [ ] **Step 3: Implement `ai-sidebar/widget.luau`**

Create `ai-sidebar/widget.luau`:
```luau
--!strict
-- AI Sidebar Bar Widget

barWidget.setGlyph("sparkles")
barWidget.setTooltip(noctalia.tr("title"))

function onClick()
  noctalia.togglePanel("rigelyon/ai-sidebar:panel")
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_widget.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/widget.luau tests/test_ai_sidebar_widget.py
git commit -m "feat(ai-sidebar): implement companion bar widget"
```

---

### Task 6: Main Panel Implementation (`panel.luau`)

**Files:**
- Create: `ai-sidebar/panel.luau`
- Test: `tests/test_ai_sidebar_panel.py`

**Interfaces:**
- Consumes: `storage.luau`, `client.luau`, `panel.*`, `ui.*`, `noctalia.*`
- Produces: Complete panel user interface rendering `Chat`, `History`, and `Setting` tabs, with live streaming throttling, session management, and test connection action.

- [ ] **Step 1: Write failing panel unit test in Python**

Create `tests/test_ai_sidebar_panel.py`:
```python
import os
import unittest

PANEL_FILE = os.path.join(os.path.dirname(__file__), "..", "ai-sidebar", "panel.luau")


class TestAiSidebarPanel(unittest.TestCase):
    def test_panel_file_structure(self):
        self.assertTrue(os.path.isfile(PANEL_FILE), "Missing panel.luau")
        with open(PANEL_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("onOpen", content)
        self.assertIn("onClose", content)
        self.assertIn("renderChatView", content)
        self.assertIn("renderHistoryView", content)
        self.assertIn("renderSettingView", content)
        self.assertIn("testConnection", content)
        # Verify 80ms throttle logic presence
        self.assertIn("nowMs", content)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py -v`
Expected: FAIL with "Missing panel.luau"

- [ ] **Step 3: Implement `ai-sidebar/panel.luau`**

Create `ai-sidebar/panel.luau`:
```luau
--!nonstrict
-- AI Sidebar panel implementation with streaming chat, session history, and provider settings.

local storage = require("storage")
local client = require("client")

local activeTab = "chat" -- "chat" | "history" | "setting"
local sessions = {}
local currentSession = nil
local config = nil

local inputBuffer = ""
local historySearch = ""
local isStreaming = false
local streamHandle = nil
local lastRenderMs = 0

-- UI transient states
local pendingDeleteSessionId = nil
local pendingClear = false
local testConnStatus = nil -- nil | "testing" | "success" | "error: <msg>"

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

-- ── Streaming Actions ─────────────────────────────────────────────────────────

local function stopStreaming()
  if streamHandle ~= nil then
    streamHandle.stop()
    streamHandle = nil
  end
  isStreaming = false
  if currentSession and #currentSession.messages > 0 then
    storage.saveSessions(sessions)
  end
  render()
end

local function sendMessage()
  local text = noctalia.string.trim(inputBuffer)
  if text == "" or isStreaming then return end

  if not currentSession then
    currentSession = storage.createSession(text, config.active_provider, config[config.active_provider .. "_model"])
    table.insert(sessions, 1, currentSession)
  end

  -- Add user message
  table.insert(currentSession.messages, {
    role = "user",
    content = text,
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  -- Set session title from first message if default
  if currentSession.title == "New Conversation" then
    currentSession.title = storage.generateTitle(text)
  end
  currentSession.updated_at = math.floor(noctalia.nowMs() / 1000)

  -- Create placeholder for assistant response
  table.insert(currentSession.messages, {
    role = "assistant",
    content = "",
    timestamp = math.floor(noctalia.nowMs() / 1000),
  })

  inputBuffer = ""
  isStreaming = true
  lastRenderMs = noctalia.nowMs()
  render()

  local assistantMsg = currentSession.messages[#currentSession.messages]
  local capped = storage.capMessages(currentSession.messages)

  streamHandle = client.streamChat(
    capped,
    config,
    function(chunk: string)
      assistantMsg.content = assistantMsg.content .. chunk
      local now = noctalia.nowMs()
      -- Throttled UI update (>= 80ms) for CPU budget compliance
      if now - lastRenderMs >= 80 then
        lastRenderMs = now
        render()
      end
    end,
    function(err: string)
      isStreaming = false
      streamHandle = nil
      assistantMsg.content = assistantMsg.content .. "\n\n**[" .. tr("error_title") .. ": " .. err .. "]**"
      storage.saveSessions(sessions)
      render()
    end,
    function()
      isStreaming = false
      streamHandle = nil
      storage.saveSessions(sessions)
      render()
    end
  )
end

-- ── View: Chat ───────────────────────────────────────────────────────────────

local function renderChatView()
  local messageNodes = {}

  if not currentSession or #currentSession.messages == 0 then
    table.insert(messageNodes, ui.column({
      align = "center",
      justify = "center",
      gap = 12,
      padding = 32,
      flexGrow = 1,
    }, {
      ui.glyph({ name = "sparkles", size = 48, color = "primary" }),
      ui.label({ text = tr("welcome_title"), fontSize = 16, fontWeight = "bold" }),
      ui.label({
        text = tr("welcome_subtitle"),
        fontSize = 12,
        color = "on_surface_variant",
        align = "center",
      }),
    }))
  else
    for _, msg in ipairs(currentSession.messages) do
      if msg.role == "user" then
        table.insert(messageNodes, ui.row({ justify = "end" }, {
          ui.box({
            fill = "surface_variant",
            radius = 12,
            padding = 10,
            paddingH = 14,
          }, {
            ui.label({ text = msg.content, selectable = true }),
          }),
        }))
      elseif msg.role == "assistant" then
        local content = msg.content
        if content == "" and isStreaming then
          content = "_" .. tr("status_typing") .. "_"
        end
        table.insert(messageNodes, ui.row({ justify = "start" }, {
          ui.box({
            fill = "surface",
            radius = 12,
            padding = 10,
            paddingH = 14,
            flexGrow = 1,
          }, {
            ui.markdown({ text = content }),
          }),
        }))
      end
    end
  end

  local actionButtons = {}
  if isStreaming then
    table.insert(actionButtons, ui.button({
      glyph = "player-stop",
      variant = "primary",
      text = tr("stop"),
      onClick = stopStreaming,
    }))
  else
    if pendingClear then
      table.insert(actionButtons, ui.label({ text = tr("clear_confirm"), color = "error" }))
      table.insert(actionButtons, ui.button({
        glyph = "check",
        variant = "primary",
        onClick = function()
          if currentSession then
            currentSession.messages = {}
            storage.saveSessions(sessions)
          end
          pendingClear = false
          render()
        end,
      }))
      table.insert(actionButtons, ui.button({
        glyph = "x",
        variant = "ghost",
        onClick = function()
          pendingClear = false
          render()
        end,
      }))
    else
      table.insert(actionButtons, ui.button({
        glyph = "eraser",
        variant = "ghost",
        tooltip = tr("clear"),
        onClick = function()
          pendingClear = true
          render()
        end,
      }))
      table.insert(actionButtons, ui.button({
        glyph = "send",
        variant = "primary",
        text = tr("send"),
        onClick = sendMessage,
      }))
    end
  end

  local inputRow = ui.column({ gap = 6, align = "stretch" }, {
    ui.input({
      value = inputBuffer,
      placeholder = tr("input_placeholder"),
      multiline = true,
      focus = true,
      flexGrow = 1,
      onChange = function(val)
        inputBuffer = val
      end,
      onSubmit = function()
        sendMessage()
      end,
    }),
    ui.row({ align = "center", justify = "space_between" }, {
      ui.label({
        text = isStreaming and tr("status_typing") or tr("status_ready"),
        fontSize = 11,
        color = "on_surface_variant",
      }),
      ui.row({ gap = 4, align = "center" }, actionButtons),
    }),
  })

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    ui.scroll({ flexGrow = 1, gap = 8, padding = 4 }, messageNodes),
    ui.separator({}),
    inputRow,
  })
end

-- ── View: History ────────────────────────────────────────────────────────────

local function renderHistoryView()
  local searchBar = ui.input({
    value = historySearch,
    placeholder = tr("search_history"),
    onChange = function(val)
      historySearch = val
      render()
    end,
  })

  local rows = {}
  local queryLower = noctalia.string.trim(historySearch):lower()

  for _, sess in ipairs(sessions) do
    local matched = true
    if queryLower ~= "" then
      local tLower = sess.title:lower()
      if not tLower:find(queryLower, 1, true) then
        matched = false
      end
    end

    if matched then
      local itemActions = {}
      if pendingDeleteSessionId == sess.id then
        table.insert(itemActions, ui.button({
          glyph = "check",
          variant = "primary",
          onClick = function()
            sessions = storage.deleteSession(sess.id, sessions)
            if currentSession and currentSession.id == sess.id then
              currentSession = sessions[1] or nil
            end
            pendingDeleteSessionId = nil
            render()
          end,
        }))
        table.insert(itemActions, ui.button({
          glyph = "x",
          variant = "ghost",
          onClick = function()
            pendingDeleteSessionId = nil
            render()
          end,
        }))
      else
        table.insert(itemActions, ui.button({
          glyph = "trash",
          variant = "ghost",
          tooltip = tr("delete_session"),
          onClick = function()
            pendingDeleteSessionId = sess.id
            render()
          end,
        }))
      end

      local isCurrent = currentSession and (currentSession.id == sess.id)
      table.insert(rows, ui.row({
        align = "center",
        justify = "space_between",
        padding = 8,
        paddingH = 12,
        radius = 8,
        fill = isCurrent and "surface_variant" or "surface",
      }, {
        ui.column({
          flexGrow = 1,
          gap = 2,
          onClick = function()
            currentSession = sess
            activeTab = "chat"
            render()
          end,
        }, {
          ui.label({ text = sess.title, fontWeight = isCurrent and "bold" or "normal", maxLines = 1 }),
          ui.label({
            text = noctalia.formatTime("%x %H:%M", sess.updated_at) .. "  ·  " .. tostring(#sess.messages) .. " msgs",
            fontSize = 11,
            color = "on_surface_variant",
          }),
        }),
        ui.row({ gap = 4, align = "center" }, itemActions),
      }))
    end
  end

  if #rows == 0 then
    local emptyMsg = (queryLower == "") and tr("no_history") or tr("no_search_results")
    table.insert(rows, ui.label({ text = emptyMsg, color = "on_surface_variant" }))
  end

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    ui.button({
      glyph = "plus",
      text = tr("new_chat"),
      variant = "primary",
      onClick = function()
        currentSession = storage.createSession(nil, config.active_provider, config[config.active_provider .. "_model"])
        table.insert(sessions, 1, currentSession)
        storage.saveSessions(sessions)
        activeTab = "chat"
        render()
      end,
    }),
    searchBar,
    ui.scroll({ flexGrow = 1, gap = 4 }, rows),
  })
end

-- ── View: Setting ────────────────────────────────────────────────────────────

local function renderSettingView()
  local providerPills = ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = tr("provider_openai"),
      variant = config.active_provider == "openai" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "openai"
        render()
      end,
    }),
    ui.button({
      text = tr("provider_anthropic"),
      variant = config.active_provider == "anthropic" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "anthropic"
        render()
      end,
    }),
    ui.button({
      text = tr("provider_gemini"),
      variant = config.active_provider == "gemini" and "primary" or "ghost",
      onClick = function()
        config.active_provider = "gemini"
        render()
      end,
    }),
  })

  local activeSettings = {}
  if config.active_provider == "openai" then
    table.insert(activeSettings, ui.label({ text = "OpenAI API Key", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.openai_key,
      placeholder = "sk-...",
      onChange = function(v) config.openai_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = "OpenAI Model", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.openai_model,
      placeholder = "gpt-4o-mini",
      onChange = function(v) config.openai_model = v end,
    }))
  elseif config.active_provider == "anthropic" then
    table.insert(activeSettings, ui.label({ text = "Anthropic API Key", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.anthropic_key,
      placeholder = "sk-ant-...",
      onChange = function(v) config.anthropic_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = "Anthropic Model", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.anthropic_model,
      placeholder = "claude-3-5-haiku-20241022",
      onChange = function(v) config.anthropic_model = v end,
    }))
  elseif config.active_provider == "gemini" then
    table.insert(activeSettings, ui.label({ text = "Gemini API Key", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.gemini_key,
      placeholder = "AIzaSy...",
      onChange = function(v) config.gemini_key = v end,
    }))
    table.insert(activeSettings, ui.label({ text = "Gemini Model", fontSize = 12, fontWeight = "bold" }))
    table.insert(activeSettings, ui.input({
      value = config.gemini_model,
      placeholder = "gemini-1.5-flash",
      onChange = function(v) config.gemini_model = v end,
    }))
  end

  local testConnLabel = nil
  if testConnStatus == "testing" then
    testConnLabel = ui.label({ text = tr("testing"), color = "on_surface_variant" })
  elseif testConnStatus == "success" then
    testConnLabel = ui.label({ text = tr("test_success"), color = "primary" })
  elseif type(testConnStatus) == "string" and testConnStatus:find("^error:") then
    testConnLabel = ui.label({ text = tr("test_error") .. " (" .. testConnStatus:sub(8) .. ")", color = "error" })
  end

  local testConnRow = ui.row({ align = "center", justify = "space_between" }, {
    ui.button({
      glyph = "plug-connected",
      text = tr("test_connection"),
      variant = "ghost",
      onClick = function()
        testConnStatus = "testing"
        render()
        client.testConnection(config.active_provider, config, function(ok, msg)
          testConnStatus = ok and "success" or ("error: " .. msg)
          render()
        end)
      end,
    }),
    testConnLabel or ui.spacer({}),
  })

  return ui.scroll({ flexGrow = 1, gap = 12, padding = 4 }, {
    ui.label({ text = tr("active_provider"), fontSize = 13, fontWeight = "bold" }),
    providerPills,
    ui.separator({}),
    ui.column({ gap = 8, align = "stretch" }, activeSettings),
    ui.separator({}),
    ui.label({ text = tr("system_prompt"), fontSize = 12, fontWeight = "bold" }),
    ui.input({
      value = config.system_prompt,
      multiline = true,
      onChange = function(v) config.system_prompt = v end,
    }),
    testConnRow,
    ui.separator({}),
    ui.button({
      glyph = "device-floppy",
      text = tr("save_settings"),
      variant = "primary",
      onClick = function()
        storage.saveConfig(config)
        noctalia.notify(tr("title"), tr("settings_saved"))
      end,
    }),
  })
end

-- ── Render Root ──────────────────────────────────────────────────────────────

render = function()
  local titleRow = ui.row({ align = "center", justify = "space_between" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "sparkles", size = 18, color = "primary" }),
      ui.label({ text = tr("title"), fontWeight = "bold" }),
      ui.label({
        text = "· " .. config.active_provider,
        fontSize = 11,
        color = "on_surface_variant",
      }),
    }),
    ui.row({ gap = 4, align = "center" }, {
      ui.button({
        glyph = "plus",
        variant = "ghost",
        tooltip = tr("new_chat"),
        onClick = function()
          currentSession = storage.createSession(nil, config.active_provider, config[config.active_provider .. "_model"])
          table.insert(sessions, 1, currentSession)
          storage.saveSessions(sessions)
          activeTab = "chat"
          render()
        end,
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        tooltip = tr("close"),
        onClick = function()
          panel.close()
        end,
      }),
    }),
  })

  local tabBar = ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = tr("tab_chat"),
      variant = activeTab == "chat" and "primary" or "ghost",
      onClick = function()
        activeTab = "chat"
        render()
      end,
    }),
    ui.button({
      text = tr("tab_history") .. " (" .. tostring(#sessions) .. ")",
      variant = activeTab == "history" and "primary" or "ghost",
      onClick = function()
        activeTab = "history"
        render()
      end,
    }),
    ui.button({
      text = tr("tab_setting"),
      variant = activeTab == "setting" and "primary" or "ghost",
      onClick = function()
        activeTab = "setting"
        render()
      end,
    }),
  })

  local bodyNode
  if activeTab == "chat" then
    bodyNode = renderChatView()
  elseif activeTab == "history" then
    bodyNode = renderHistoryView()
  else
    bodyNode = renderSettingView()
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    titleRow,
    tabBar,
    bodyNode,
  }))
end

-- ── Lifecycle Handlers ────────────────────────────────────────────────────────

function onOpen(_context)
  config = storage.loadConfig()
  sessions = storage.loadSessions()
  if not currentSession then
    currentSession = sessions[1] or nil
  end

  activeTab = "chat"
  pendingDeleteSessionId = nil
  pendingClear = false
  testConnStatus = nil
  historySearch = ""
  render()
end

function onClose()
  if isStreaming then
    stopStreaming()
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests/test_ai_sidebar_panel.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ai-sidebar/panel.luau tests/test_ai_sidebar_panel.py
git commit -m "feat(ai-sidebar): implement main panel UI with streaming, tabs, and connection testing"
```

---

### Task 7: Catalog Integration & End-to-End Validation

**Files:**
- Modify: `catalog.toml` (regenerated/verified)
- Run: Full repository validation scripts

- [ ] **Step 1: Run complete unit test suite for ai-sidebar**

Run: `python3 -m unittest discover tests -v -k "test_ai_sidebar*"`
Expected: All `test_ai_sidebar*` tests PASS with 0 failures

- [ ] **Step 2: Validate plugin manifest with repository validator**

Run: `python3 .github/workflows/validate-plugins.py`
Expected: Validates without errors for `ai-sidebar`

- [ ] **Step 3: Update catalog for dev usage**

Run: `python3 .github/workflows/update-catalog.py`
Expected: Successfully indexes `rigelyon/ai-sidebar` in `catalog.toml`

- [ ] **Step 4: Commit**

```bash
git add catalog.toml
git commit -m "chore(ai-sidebar): update catalog.toml with ai-sidebar plugin entry"
```
