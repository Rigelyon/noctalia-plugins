# AI Sidebar Plugin Design Specification

## 1. Overview & Objectives

**AI Sidebar (`rigelyon/ai-sidebar`)** is a sleek, vertical desktop AI assistant panel for the Noctalia desktop shell. It enables users to have persistent, multi-turn AI conversations directly from their desktop panel with real-time streaming responses, multi-session history, and multi-provider connectivity.

### Core Goals (Phase 1 / v1):
- **Robust Multi-Provider AI Connectivity**: Native support with specific schemas for OpenAI, Anthropic Claude, and Google Gemini.
- **Low-Latency Streaming**: Real-time token streaming via `noctalia.httpStream`, with user-initiated cancellation (stop streaming).
- **Clean Vertical Panel UI**:
  - Three top tabs: **`Chat`**, **`History`**, and **`Setting`**.
  - Markdown-rendered assistant bubbles with code formatting, lists, and syntax blocks.
  - Dedicated "Test Connection" tool in the Setting tab to verify API keys and network connectivity.
- **Strict Luau CPU Budget Compliance**: Throttled UI rendering (`~80ms`), pre-filtered JSON decoding in SSE handlers, and in-memory session caching.
- **Session & History Persistence**: Multi-session management with auto-generated session titles, session switching, and safe deletion.

---

## 2. Architecture & Directory Structure

Adopting a modular multi-file architecture to ensure strict separation of concerns, maintainability, and testability.

```text
ai-sidebar/
├── plugin.toml              # Noctalia manifest (panel, widget, fallback settings)
├── README.md                # User & developer documentation
├── thumbnail.webp           # 960x540 WebP catalog thumbnail
├── panel.luau               # Panel entry point, UI tree rendering, and event handlers
├── widget.luau              # Bar widget entry point (toggles the sidebar panel)
├── storage.luau             # Session management, persistence, and config loading
├── client.luau              # HTTP streaming router & provider abstraction
├── providers/
│   ├── openai.luau          # OpenAI request formatter, test connection, & SSE parser
│   ├── anthropic.luau       # Anthropic request formatter, test connection, & SSE parser
│   └── gemini.luau          # Google Gemini request formatter, test connection, & SSE parser
└── translations/
    ├── en.json              # English localization strings
    └── id.json              # Indonesian localization strings
```

---

## 3. Manifest Specification (`plugin.toml`)

- **Manifest Metadata**:
  - `id = "rigelyon/ai-sidebar"`
  - `name = "AI Sidebar"`
  - `version = "1.0.0"`
  - `plugin_api = 28`
  - `author = "rigelyon"`
  - `license = "MIT"`
  - `icon = "sparkles"`
  - `tags = ["productivity", "utility", "panel", "bar"]`
  - `description = "Streamlined AI chat sidebar for Noctalia with multi-provider streaming, history, and configurable settings."`

- **Panel Definition (`[[panel]]`)**:
  - `id = "panel"`
  - `entry = "panel.luau"`
  - `placement = "attached"`
  - `position = "right"`
  - `width = 440`
  - `height = 760`

- **Widget Definition (`[[widget]]`)**:
  - `id = "ai-sidebar"`
  - `entry = "widget.luau"`
  - Displays `sparkles` glyph; left-click toggles `rigelyon/ai-sidebar:panel`.

- **Settings Fallback (`[[setting]]`)**:
  - `default_provider` (`type = "select"`, options: `["openai", "anthropic", "gemini"]`, default: `"openai"`)
  - `openai_api_key` (`type = "string"`, default: `""`)
  - `openai_model` (`type = "string"`, default: `"gpt-4o-mini"`)
  - `anthropic_api_key` (`type = "string"`, default: `""`)
  - `anthropic_model` (`type = "string"`, default: `"claude-3-5-haiku-20241022"`)
  - `gemini_api_key` (`type = "string"`, default: `""`)
  - `gemini_model` (`type = "string"`, default: `"gemini-1.5-flash"`)
  - `system_prompt` (`type = "string"`, default: `"You are a helpful and concise AI assistant."`)

---

## 4. UI Layout & User Interaction

### 4.1 Header & Tab Bar
- **Top Header**:
  - Left: `sparkles` glyph + "AI Sidebar" title label.
  - Center/Right: Current model chip (e.g., `openai · gpt-4o-mini`).
  - Right: Quick "+ New Chat" button (`plus`) and Close panel button (`x`).
- **Tab Bar (`ui.row`)**:
  - Three buttons: **`Chat`**, **`History`**, **`Setting`**.
  - Active tab uses `variant = "primary"`, inactive tabs use `variant = "ghost"`.

### 4.2 Tab: `Chat`
- **Message List (`ui.scroll`)**:
  - **Empty State**: Friendly greeting with `sparkles` glyph and prompt suggestion hint when a new session has 0 messages.
  - **User Messages**: Right-aligned box, padded, filled with `surface_variant` or card fill, showing plain text.
  - **Assistant Messages**: Left-aligned box, filled with `surface`, rendering content via `ui.markdown({ text = ... })`.
  - **Streaming State**: Shows live-updating assistant bubble with an animated/subtle "Streaming..." indicator label underneath.
  - **Error Bubble**: When a request fails, renders a dedicated red/error callout with error details and a Retry button.
- **Input Area (`ui.column`)**:
  - Multiline `ui.input` with placeholder `tr("input_placeholder")`.
  - Action row below input:
    - Normal state: **Send** button (`send`, primary) and **Clear** session button (`eraser`, ghost).
    - Streaming state: **Stop** button (`player-stop`, destructive/primary) that invokes `handle.stop()`.

### 4.3 Tab: `History`
- Top bar with "+ New Chat" button and a search filter input (`searchQuery`).
- In-memory list of sessions sorted in descending order of `updated_at`.
- Each session item displays:
  - Session title (first 40 characters of first user message).
  - Subtitle with formatted date (`noctalia.formatTime`) and message count.
  - Click to select and resume session in `Chat` tab.
  - Inline Delete button (`trash`) with 2-step confirmation (`check` and `x`).

### 4.4 Tab: `Setting`
- Scrollable form for configuration:
  - Active Provider Selector (`ui.select` or button pills: OpenAI, Anthropic, Gemini).
  - Provider Config Sections:
    - OpenAI: API Key input & Model input.
    - Anthropic: API Key input & Model input.
    - Gemini: API Key input & Model input.
  - System Prompt text area.
  - Action Row:
    - **Test Connection** button: sends a minimal prompt (`max_tokens: 5`) and displays immediate inline status (Success with green text / Error with HTTP status code and details).
    - **Save Settings** button: persists to `config.json` and issues a `noctalia.notify` toast.

---

## 5. Storage & Persistence (`storage.luau`)

Data is persisted in the dedicated plugin directory (`noctalia.pluginDataDir()`):
1. **`config.json`**:
   ```json
   {
     "active_provider": "openai",
     "openai_key": "...",
     "openai_model": "gpt-4o-mini",
     "anthropic_key": "...",
     "anthropic_model": "claude-3-5-haiku-20241022",
     "gemini_key": "...",
     "gemini_model": "gemini-1.5-flash",
     "system_prompt": "You are a helpful and concise AI assistant."
   }
   ```
   *Fallback rule*: When any field is empty or missing, fallback to `noctalia.getConfig(settingKey)` from `plugin.toml`.

2. **`sessions.json`**:
   ```json
   [
     {
       "id": "sess_1727932800",
       "title": "Explain Luau Coroutines",
       "created_at": 1727932800,
       "updated_at": 1727933100,
       "provider": "openai",
       "model": "gpt-4o-mini",
       "messages": [
         { "role": "user", "content": "Explain Luau coroutines" },
         { "role": "assistant", "content": "..." }
       ]
     }
   ]
   ```

---

## 6. Provider Implementations & Protocols

### 6.1 Unified Client Interface (`client.luau`)
- `client.testConnection(provider: string, config: ConfigTable, callback: (ok: boolean, msg: string) -> ())`
- `client.streamChat(messages: {Message}, config: ConfigTable, onChunk: (text: string) -> (), onError: (err: string) -> (), onDone: () -> ()) -> HttpStreamHandle?`

### 6.2 OpenAI Provider (`providers/openai.luau`)
- **Endpoint**: `POST https://api.openai.com/v1/chat/completions`
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <key>`
- **Body**:
  ```json
  {
    "model": "gpt-4o-mini",
    "messages": [
      { "role": "system", "content": "<system_prompt_with_environment>" },
      { "role": "user", "content": "..." }
    ],
    "stream": true
  }
  ```
- **SSE Stream Parsing**:
  - Ignore empty lines or `data: [DONE]`.
  - Only parse lines starting with `data: `.
  - Extract text delta: `choices[1].delta.content`.

### 6.3 Anthropic Claude Provider (`providers/anthropic.luau`)
- **Endpoint**: `POST https://api.anthropic.com/v1/messages`
- **Headers**:
  - `Content-Type: application/json`
  - `x-api-key: <key>`
  - `anthropic-version: 2023-06-01`
- **Body**:
  - `system`: String containing system prompt with environment context.
  - `messages`: Filtered to contain only `user` and `assistant` roles.
  - `max_tokens`: 4096.
  - `stream`: true.
- **SSE Stream Parsing**:
  - Process `event: content_block_delta` lines followed by `data: ...`.
  - Extract delta text: `delta.text`.

### 6.4 Google Gemini Provider (`providers/gemini.luau`)
- **Endpoint**: `POST https://generativelanguage.googleapis.com/v1beta/models/<model>:streamGenerateContent?alt=sse&key=<key>`
- **Headers**: `Content-Type: application/json`
- **Body**:
  - `system_instruction`: `{ "parts": [{ "text": "<system_prompt>" }] }`
  - `contents`: Array mapping `role: "user"` -> `"user"` and `role: "assistant"` -> `"model"`, with `parts: [{ "text": content }]`.
- **SSE Stream Parsing**:
  - Parse lines with `data: `.
  - Extract delta text: `candidates[1].content.parts[1].text`.

---

## 7. Context Windowing & Dynamic Environment Prompt

### Dynamic System Prompt Injection
Before sending context to the provider, the system prompt is augmented with current environment awareness:
```text
<system_prompt>

[Environment Context: Current system time is <YYYY-MM-DD HH:MM:SS>, running on Noctalia Linux Shell.]
```

### Sliding Window Context
To prevent context overflow and reduce latency/costs:
- When a session exceeds 20 messages, only the last **20 messages** are included in the API payload.
- All historical messages remain fully preserved on disk in `sessions.json` and visible in the chat UI.

---

## 8. Luau CPU Budget Optimizations

1. **Throttled Re-rendering (`~80ms`)**:
   - During streaming, incoming SSE lines buffer text into memory.
   - `panel.render()` is called only if `noctalia.nowMs() - lastRenderMs >= 80`.
   - A guaranteed final render is invoked on stream completion (`onClose`).
2. **Fast Pre-filter Before JSON Decoding**:
   - `noctalia.json.decode` is called strictly on lines with `data: ` and skipping `[DONE]`. Non-data lines (keep-alives, event metadata) are filtered out via lightweight string slicing.
3. **In-Memory Session Caching**:
   - `sessions` and `config` are loaded once in `onOpen`.
   - History filtering (`History` tab) runs entirely in memory without disk I/O per keystroke.
   - Persistence writes are triggered only when a message finishes streaming or a setting is saved.

---

## 9. Future Advanced Features Roadmap (Catatan Fitur Lanjutan)

*These features are out-of-scope for v1 but explicitly documented here for subsequent passes:*
1. **Dynamic RAG & File Context**:
   - Drag-and-drop or select files from filesystem (e.g. logs, markdown notes, code snippets) to attach as attachments in chat.
2. **Context Summarization**:
   - Background LLM call to summarize conversation history beyond the sliding window to maintain long-term memory.
3. **Noctalia Tool Calling / Desktop Automation**:
   - Allow the LLM to invoke Noctalia IPC commands (e.g. toggle panel, check system stats, launch app, set wallpaper).
4. **Prompt Templates & Custom Presets**:
   - Quick prompt shortcuts (e.g., "Summarize", "Fix Grammar", "Explain Code", "Generate Bash Script").
5. **Local LLM Preset**:
   - Dedicated local provider preset for Ollama (`http://localhost:11434/v1`) or LocalAI without requiring external API keys.

---

## 10. Testing & Verification Plan

1. **Manifest & Translation Validation**:
   - Verify `plugin.toml` adheres to schema and allowed tags (`["productivity", "utility", "panel", "bar"]`).
   - Validate translation key parity between `translations/en.json` and `translations/id.json`.
2. **Unit Tests (`tests/test_ai_sidebar.py`)**:
   - Test SSE payload generation and parsing logic for OpenAI, Anthropic, and Gemini.
   - Test sliding window truncation (20 messages cap).
   - Test configuration fallback hierarchy (`config.json` -> `plugin.toml`).
   - Test session title generation sanitization.
3. **Catalog & Lint Verification**:
   - Ensure `thumbnail.webp` conforms to 960x540 WebP under 512 KB.
   - Verify `noctalia plugins lint` and catalog update script compatibility.
