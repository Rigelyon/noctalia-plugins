# AI Sidebar: Proper Modern Chat Engine & Interactive Actions Specification

## 1. Overview & Objectives

This specification defines the comprehensive upgrade of **AI Sidebar (`rigelyon/ai-sidebar`)** from a basic chat drawer into a proper, production-grade conversational AI assistant (version `1.1.0`).

### Core Goals:
- **Under-the-Hood Resilience**:
  - **Heuristic Token Counter**: Deterministic character-to-token estimation (~4 chars/token + overhead) to calculate payload safety without external runtime dependencies.
  - **Smart Rolling Context Summarization**: Prevent conversational amnesia by maintaining the initial anchor topic/prompt, condensing intermediate turns into a structured context recap, and allocating the bulk of the token budget to the active recent turn window.
  - **Auto-Retry & Stream Resilience**: Seamless exponential backoff (1s, 2s delays; max 2 retries) on transient network disconnects and HTTP rate limit/service errors (429, 503) before the stream yields content.
- **Modern Chat Actions**:
  - **Regenerate Response**: One-click action on assistant messages to discard the latest response and re-query the LLM with the previous user prompt.
  - **Edit User Message**: Pencil action on user messages to rewind history to that turn and restore the prompt into the input buffer for modification.
  - **Rewind / Revert to Here**: Ability to rollback history to any selected message checkpoint.
  - **Dedicated Code Block Copy**: Custom container rendering for fenced code blocks (` ```lang ... ``` `) featuring language badges and standalone "Copy Code" buttons with visual feedback.
- **Clean Aesthetic & Versioning**:
  - Header remains clean and uncluttered (no header model switcher; model selection remains in Settings).
  - Version bump from `1.0.0` to `1.1.0` in `plugin.toml`, `catalog.toml`, and localization files.

---

## 2. Architecture & File Structure

```text
ai-sidebar/
├── plugin.toml                      # Version 1.1.0 bump & metadata
├── storage.luau                     # Session rewind & assistant removal helpers
├── client.luau                      # Auto-retry stream wrapper with exponential backoff
├── context.luau                     # NEW: Heuristic token counter & rolling context builder
├── markdown.luau                    # NEW: Markdown code block parser & styled copy container
├── panel.luau                       # UI integration: chat actions & code block renderer
├── providers/
│   ├── openai.luau
│   ├── anthropic.luau
│   ├── gemini.luau
│   └── custom.luau
└── translations/
    ├── en.json                      # Added action labels & status strings
    └── id.json                      # Indonesian translations
tests/
├── test_ai_sidebar_context.py       # Unit tests for token estimation & rolling context
├── test_ai_sidebar_markdown.py      # Unit tests for markdown segmentation & code parsing
└── test_ai_sidebar_storage.py       # Unit tests for session rewind & message removal
```

---

## 3. Detailed Component Specifications

### 3.1 Token Counter & Context Management (`ai-sidebar/context.luau`)

#### Heuristic Token Estimation
Because Noctalia runs embedded Luau without heavy native tokenizer bindings (e.g. tiktoken), token usage is estimated deterministically:
- Text tokens: `math.max(1, math.ceil(string.len(text) / 4))`
- Message overhead: 4 tokens per message (standard chat template framing).
- `estimateTokens(text: string): number`
- `estimateMessageTokens(msg: { role: string, content: string }): number`
- `estimateTotalTokens(messages: { { role: string, content: string } }): number`

#### Smart Rolling Context & Condensation
When preparing messages for LLM request (`prepareContext(messages, maxTokens, systemPrompt)`):
1. **System Prompt**: Always placed first.
2. **Anchor Message**: If conversation has $\ge 2$ messages, the very first user message (`messages[1]`) is treated as the conversation anchor/goal and preserved.
3. **Budget Allocation**:
   - Total budget: `maxTokens` (default 4096 tokens).
   - System prompt & anchor message are deducted first.
4. **Active Recent Window**:
   - Messages are selected backwards from the most recent message (`#messages`) until the remaining token budget is saturated (leaving at least 250 tokens reserved for summary recap).
5. **Condensed Intermediate Recap**:
   - If there are messages between the anchor message and the active recent window, they are condensed into a single synthetic system context recap message:
     ```text
     [Previous conversation summary: User requested <brief>; Assistant answered <brief>...]
     ```
   - Each intermediate turn is compacted into a single summary line (capped at 120 characters per turn).
   - This prevents conversational amnesia while guaranteeing the payload remains well within model token limits.

---

### 3.2 Auto-Retry & Network Resilience (`ai-sidebar/client.luau`)

#### Retry Mechanics
- Applicable when `noctalia.httpStream` fails to connect, drops immediately, or receives HTTP 429 / 503 before receiving the first SSE chunk.
- Non-retryable conditions:
  - HTTP 400 (Bad Request), 401 (Unauthorized / Invalid API Key), 404 (Not Found).
  - Any stream that has already started receiving and emitting chunks (`hasReceivedChunk == true`).
- Retry Parameters:
  - Max retries: 2.
  - Backoff delay: Attempt 1 = 1000ms, Attempt 2 = 2000ms.
- Transient UI Feedback:
  - Optional `onStatus(status: string, attempt: number, maxRetries: number)` callback allows displaying a transient message (e.g., `status_retrying` in translations).

---

### 3.3 Markdown Code Segmentation & Copy Container (`ai-sidebar/markdown.luau`)

#### Segment Parser
`parseMarkdownSegments(text: string): { Segment }`
Where `Segment` is:
- `{ type: "text", content: string }`
- `{ type: "code", language: string, code: string }`

Regex / Pattern Matching:
- Matches fenced code blocks: ```` ```([%w_-]*)\n?(.-)``` ````
- If an unclosed code block is encountered at the end of text (common during streaming), it is safely closed or treated as an active code segment with syntax intact.

#### UI Renderer Integration
For each assistant message in `panel.luau`:
- Non-code segments are rendered using Noctalia's built-in `ui.markdown(segment.content)`.
- Code segments are rendered in a dedicated box:
  - **Header Row**:
    - Left: Monospace badge for `segment.language` (defaults to `"text"` if unspecified).
    - Right: Button with clipboard icon and text `"Copy"`.
  - **Code Body**:
    - Preformatted monospace text block with horizontal scrolling support.
  - **Copy Action**:
    - Invokes `noctalia.copyToClipboard(segment.code, "text/plain")`.
    - Button text flips to `"Copied!"` for 2.0 seconds via a local timer, then resets.

---

### 3.4 History Manipulation & Chat Actions (`ai-sidebar/storage.luau` & `panel.luau`)

#### 1. Rewind Functionality
In `storage.luau`:
```lua
function storage.rewindSession(sessionId: string, targetMessageIndex: number): boolean
```
- Truncates `session.messages` to retain items from index `1` to `targetMessageIndex`.
- Persists session file immediately via `storage.saveSession(session)`.

#### 2. Remove Last Assistant Message
In `storage.luau`:
```lua
function storage.removeLastAssistantMessage(sessionId: string): boolean
```
- If `#session.messages > 0` and `session.messages[#session.messages].role == "assistant"`:
  - Removes the last message.
  - Saves the session.

#### 3. Regenerate Response (Action)
- Located beneath the latest assistant response.
- On click:
  1. Calls `storage.removeLastAssistantMessage(sessionId)`.
  2. Retrieves the trailing user prompt.
  3. Re-invokes stream generation (`client.sendMessageStream`).

#### 4. Edit User Message (Action)
- Located on user message cards (pencil icon).
- On click:
  1. Copies the target user message content into the panel input state (`setText(msg.content)`).
  2. Rewinds conversation history to immediately prior to that message: `storage.rewindSession(sessionId, messageIndex - 1)`.
  3. Focuses the text input field for the user to revise and send.

#### 5. Rewind to Here (Action)
- Located on any message card (rewind/rollback icon).
- On click:
  1. Prompts or executes `storage.rewindSession(sessionId, messageIndex)`.
  2. Rerenders message list immediately.

---

## 4. Manifest & Catalog Versioning

### `ai-sidebar/plugin.toml`
```toml
[plugin]
id = "rigelyon/ai-sidebar"
name = "AI Sidebar"
version = "1.1.0"
description = "Fast, customizable AI assistant in your sidebar supporting OpenAI, Anthropic, Gemini, and Local LLMs (Ollama, LM Studio, DeepSeek)."
author = "Rigel Yon"
license = "MIT"
entrypoint = "panel.luau"
```

### `catalog.toml`
```toml
[[plugins]]
id = "rigelyon/ai-sidebar"
name = "AI Sidebar"
version = "1.1.0"
description = "Fast, customizable AI assistant in your sidebar supporting OpenAI, Anthropic, Gemini, and Local LLMs (Ollama, LM Studio, DeepSeek)."
author = "Rigel Yon"
source = "ai-sidebar"
```

---

## 5. Localization Additions

### `ai-sidebar/translations/en.json`
```json
{
  "action_regenerate": "Regenerate",
  "action_edit": "Edit",
  "action_rewind": "Rewind to here",
  "action_copy_code": "Copy",
  "code_copied": "Copied!",
  "status_retrying": "Reconnecting... ({attempt}/{max})"
}
```

### `ai-sidebar/translations/id.json`
```json
{
  "action_regenerate": "Buat Ulang",
  "action_edit": "Edit",
  "action_rewind": "Kembalikan ke sini",
  "action_copy_code": "Salin",
  "code_copied": "Tersalin!",
  "status_retrying": "Menghubungkan kembali... ({attempt}/{max})"
}
```

---

## 6. Testing & Quality Verification Plan

1. **Python Unit Tests**:
   - `tests/test_ai_sidebar_context.py`:
     - Test token estimation accuracy on short, medium, and code-heavy text.
     - Test context windowing with within-budget messages.
     - Test context condensation when message history exceeds token budget.
     - Verify anchor message preservation.
   - `tests/test_ai_sidebar_markdown.py`:
     - Test segmentation of mixed text and code blocks.
     - Test language tag extraction.
     - Test unclosed code blocks handling during streaming.
   - `tests/test_ai_sidebar_storage.py`:
     - Test `rewindSession` boundary conditions (rewind to 0, rewind to middle, rewind to end).
     - Test `removeLastAssistantMessage` behavior with empty session, user-last session, and assistant-last session.

2. **Luau Static Type Checking**:
   - Run `/home/rigelyon/.antigravity-ide/extensions/johnnymorganz.luau-lsp-1.70.1-linux-x64/bin/server analyze --definitions:noctalia=/home/rigelyon/Repository/noctalia-plugins/noctalia.d.luau ai-sidebar/*.luau ai-sidebar/providers/*.luau`.
   - Must achieve 0 errors and 0 warnings.

3. **Plugin Manifest Validation**:
   - Run `python3 .github/workflows/validate-plugins.py`.
   - Ensure catalog and plugin manifests match version `1.1.0` and schema requirements.
