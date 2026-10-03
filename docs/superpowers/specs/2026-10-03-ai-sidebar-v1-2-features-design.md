# AI Sidebar v1.2.0: Prompt Library, Auto-Titler, Chat Export, Metrics & IPC Integration

## 1. Overview & Objectives

This specification defines the feature upgrade for **AI Sidebar (`rigelyon/ai-sidebar`)** to version `1.2.0`. The release introduces advanced conversational productivity tools, performance telemetry, and external script integration via the Noctalia IPC bus:

### Core Goals:
1. **Prompt Library (`#` Trigger - Option B)**:
   - Curated template repository stored in persistent JSON (`prompts.json`).
   - Triggered inside the message input area when typing `#` (or clicking the dedicated `#` button).
   - Shows a clean, compact autocomplete popover; selecting a prompt replaces the active `#tag` with full template text.
2. **AI Background Auto-Titler**:
   - Following turn 1 (first assistant response completes), triggers a lightweight, single-turn background request to generate a concise 3–5 word title.
   - Updates session title smoothly in storage and UI without blocking user interaction or throwing invasive errors on network failure.
3. **Export Chat to Markdown**:
   - One-click export from the UI header and IPC command.
   - Formats conversation into standard Markdown with YAML frontmatter (title, timestamp, provider, model).
   - Saves to `~/Documents/ai-sidebar/<timestamp>-<sanitized-title>.md` (with fallback to plugin data directory) and triggers a system notification.
4. **Token & Response Speed Metrics**:
   - Calculates duration (`durationMs`), estimated tokens (`context.estimateTokens`), and speed (`tok/s`).
   - Renders subtle telemetry below assistant bubbles (`~245 tokens · 1.4s · 175 tok/s`).
   - Stored in session history for persistent inspection.
5. **Noctalia IPC Integration**:
   - Implements global `onIpc(event, payload)` callback in `panel.luau`.
   - Supports `clear` / `new_session`: Saves the active conversation to `sessions.json`, resets active session state, and sets a background flag `startFresh = true` so the panel opens to a clean new chat even when reset while closed.
   - Supports `ask <text>`: Injects a user prompt directly from CLI or external keybinding and initiates AI response streaming.
   - Supports `export`: Triggers immediate background Markdown export of the active session.
   - Supports `toggle`: Toggles panel open/closed.
6. **Versioning**:
   - Bump version from `1.1.0` to `1.2.0` across `plugin.toml`, `catalog.toml`, and translation files.

---

## 2. Architecture & File Structure

```text
ai-sidebar/
├── plugin.toml                      # Version bump to 1.2.0
├── storage.luau                     # MessageMetrics type, updated Message schema, startFresh session helpers
├── prompts.luau                     # NEW: Prompt library manager, prompts.json persistence, query filter
├── export.luau                      # NEW: Markdown formatter and file export engine
├── client.luau                      # Non-streaming prompt helper for background auto-titling
├── context.luau                     # Token estimation & context condensation (from v1.1.0)
├── markdown.luau                    # Code block parsing & container rendering (from v1.1.0)
├── panel.luau                       # UI: `#` autocomplete popover, metrics display, export button, onIpc handler
├── providers/
│   ├── openai.luau
│   ├── anthropic.luau
│   ├── gemini.luau
│   └── custom.luau
└── translations/
    ├── en.json                      # Added strings for prompts, export, metrics, and IPC
    └── id.json                      # Indonesian translations
tests/
├── test_ai_sidebar_prompts.py       # Unit tests for prompt loading, filtering, saving, fallback
├── test_ai_sidebar_export.py        # Unit tests for markdown export format, filename sanitation
├── test_ai_sidebar_metrics.py       # Unit tests for token telemetry & speed computation
└── test_ai_sidebar_ipc.py           # Unit tests for onIpc event handling and background session reset
```

---

## 3. Detailed Component Specifications

### 3.1 Prompt Library (`ai-sidebar/prompts.luau`)

#### Schema & Types
```luau
export type PromptTemplate = {
  tag: string,          -- Unique slug without hash, e.g. "explain", "code-review"
  label: string,        -- Human-readable name, e.g. "Explain Code or Concept"
  description: string,  -- Short explanation of prompt utility
  content: string,      -- Inserted prompt text template
}
```

#### Default Preset Templates
When `~/.local/share/noctalia/ai-sidebar/prompts.json` does not exist, initialize with 6 presets:
1. `explain`: "Explain Code or Concept" -> "Please explain the following code or concept step-by-step:\n\n"
2. `code-review`: "Review & Optimize" -> "Please review the following code for bugs, edge cases, and performance optimizations:\n\n"
3. `summarize`: "Summarize Key Points" -> "Summarize the key takeaways and actionable points from the text below:\n\n"
4. `fix-grammar`: "Fix Grammar & Tone" -> "Please fix grammar, spelling, and enhance clarity and professional tone:\n\n"
5. `translate`: "Translate Language" -> "Please translate the following text into [target]:\n\n"
6. `write-test`: "Generate Unit Tests" -> "Generate comprehensive unit tests covering happy paths and edge cases for:\n\n"

#### Core Functions
- `prompts.load(): { PromptTemplate }`: Loads JSON; on decode failure or missing file, writes and returns default presets.
- `prompts.save(templates: { PromptTemplate }): boolean`: Persists templates to JSON.
- `prompts.filter(query: string): { PromptTemplate }`: Filters templates by matching `query` case-insensitively against `tag`, `label`, or `description`. Returns at most 5 matches.

#### Input Trigger UX (`panel.luau`)
- Typing `#` or `#<query>` at the start of input or after whitespace triggers active match detection:
  ```luau
  local hashMatch = inputBuffer:match("(^|%s)#([%w%-_]*)$")
  ```
- Renders an autocomplete popover box directly above the input textarea.
- Clicking an item replaces `#<query>` with `template.content`.
- A small `#` icon button in the input toolbar toggles the prompt list manually.

---

### 3.2 Export to Markdown (`ai-sidebar/export.luau`)

#### Markdown Formatting
Constructs Markdown containing YAML frontmatter and clearly delineated turn headings:
```markdown
---
title: "Optimizing Luau State Engine"
date: "2026-10-03 19:50:00"
provider: "anthropic"
model: "claude-3-5-haiku-20241022"
---

### User
How can I improve state updates in Luau?

### Assistant
You can debounce renders and batch table updates...
```

#### Core Functions
- `export.formatMarkdown(session: storage.Session): string`: Formats the session messages into clean Markdown.
- `export.generateFilename(title: string, timestamp: number): string`: Generates sanitized filename format: `YYYY-MM-DD_<timestamp>_<sanitized_title>.md`. Strips invalid characters (`[/\\%%:*?\"<>|]`).
- `export.saveSession(session: storage.Session): (boolean, string)`: Writes file to `~/Documents/ai-sidebar/` (or plugin data dir fallback if inaccessible). Dispatches `noctalia.notify(tr("export_success_title"), filePath)`.

---

### 3.3 Response Token & Speed Metrics

#### Data Schema (`storage.luau`)
```luau
export type MessageMetrics = {
  tokens: number?,
  durationMs: number?,
  tokensPerSec: number?,
}

export type Message = {
  role: string,
  content: string,
  timestamp: number?,
  metrics: MessageMetrics?,
}
```

#### Computation & Lifecycle (`panel.luau`)
1. On assistant stream start: `streamStartMs = noctalia.nowMs()`.
2. On assistant stream finish:
   ```luau
   local durationMs = math.max(100, noctalia.nowMs() - streamStartMs)
   local tokens = context.estimateTokens(assistantMsg.content)
   local durationSec = durationMs / 1000
   local tokensPerSec = math.round((tokens / durationSec) * 10) / 10
   assistantMsg.metrics = {
     tokens = tokens,
     durationMs = durationMs,
     tokensPerSec = tokensPerSec,
   }
   storage.saveSessions(sessions)
   ```
3. UI Presentation:
   - Renders in the assistant bubble footer beside timestamp:
     `ui.label({ text = string.format("~%d tokens · %.1fs · %.1f tok/s", m.tokens, m.durationMs / 1000, m.tokensPerSec), fontSize = 11, color = "outline" })`
   - User message bubble remains clean (no metrics).

---

### 3.4 AI Background Auto-Titler

#### Trigger & Workflow
- After turn 1 completes (`#currentSession.messages == 2` and role is "assistant"):
- Execute non-streaming background prompt via `client.requestNonStreaming`:
  - **Prompt**: `"You are a conversation summarizer. Summarize this conversation in a concise 3-5 word title. Return ONLY the title text, no quotes, no markdown, no punctuation."`
  - Sends initial user message and first assistant response.
- On success:
  - Trim result, sanitize to max 45 characters.
  - Update `currentSession.title = title`.
  - Save to `sessions.json` and call `render()`.
- On error / timeout / rate limit:
  - Silently retain default heuristic title (`storage.generateTitle(firstMessage)`). Never display an error alert to the user.

---

### 3.5 Noctalia IPC & Background Session Reset

#### Global Handler
In `panel.luau`:
```luau
function onIpc(event: string, payload: string?)
```

#### Event Specifications:
1. **`clear` / `new_session`**:
   - If `currentSession` contains messages, persist to `sessions.json`.
   - Set `currentSession = nil` (or create new empty session).
   - Set `startFreshOnOpen = true`.
   - If panel is open: update UI to clean empty session immediately.
   - If panel is closed: when user later triggers `onOpen()`, `startFreshOnOpen` is detected and cleared, opening a blank new session rather than auto-selecting `sessions[1]`.
2. **`ask`**:
   - Requires non-empty payload string.
   - If `isStreaming` is active, cancel active stream cleanly.
   - Set `inputBuffer = payload`, immediately call `sendMessage()`.
3. **`export`**:
   - If `currentSession` has messages, invoke `export.saveSession(currentSession)`.
   - If empty, issue notification `noctalia.notify(tr("export_empty_title"), tr("export_empty_body"))`.
4. **`toggle`**:
   - Invokes `noctalia.togglePanel("rigelyon/ai-sidebar:panel")`.
5. **Unknown events**:
   - Log warning `noctalia.log("AI Sidebar: Unknown IPC event " .. tostring(event))`.

---

## 4. Error Handling & Edge Cases

1. **Prompt Library Corrupted File**:
   - If `prompts.json` contains invalid JSON syntax or is truncated, `prompts.load()` catches the error, restores default presets, and re-writes the file.
2. **Regex URL False Positives**:
   - Hash `#` matches only when at index 1 of the string or preceded by whitespace (`(^|%s)#([%w%-_]*)$`). URLs like `https://example.com#section` are ignored.
3. **Export Directory Permissions**:
   - If creating `~/Documents/ai-sidebar/` fails with filesystem permission errors, `export.luau` falls back to `noctalia.pluginDataDir() .. "/exports"`.
4. **Zero-Division in Metrics**:
   - Clamps duration to minimum 100ms (`math.max(100, elapsed)`), preventing `inf` or `NaN`.
5. **Concurrent IPC Streams**:
   - Receiving an IPC `ask` while streaming aborts the previous stream handle before sending the new request, preventing socket leakage.

---

## 5. Testing & Validation Plan

1. **`tests/test_ai_sidebar_prompts.py`**:
   - Validates default preset initialization.
   - Tests query filtering (case-insensitive, partial matching, 5-item limit).
   - Tests custom template addition and JSON persistence.
   - Tests fallback behavior on corrupted JSON.
2. **`tests/test_ai_sidebar_export.py`**:
   - Validates Markdown YAML frontmatter and structure.
   - Tests filename sanitation across special characters.
   - Tests handling of empty or 1-message sessions.
3. **`tests/test_ai_sidebar_metrics.py`**:
   - Validates calculation of tokens, duration, and tokens/sec.
   - Tests zero duration clamp protection.
   - Validates serialization and deserialization of `metrics` table.
4. **`tests/test_ai_sidebar_ipc.py`**:
   - Tests `onIpc("clear")` and `onIpc("new_session")` lifecycle and `startFreshOnOpen` flag.
   - Tests `onIpc("ask")` with payload dispatching message.
   - Tests `onIpc("export")` file generation.
5. **Static Analysis**:
   - Run `luau-lsp analyze` to verify zero errors and zero warnings across all updated `.luau` files.
