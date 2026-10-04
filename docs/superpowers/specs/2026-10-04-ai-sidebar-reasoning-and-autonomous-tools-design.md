# Design Specification: AI Sidebar Reasoning UI & Autonomous Tool Calling

**Date**: 2026-10-04  
**Status**: Approved / Ready for Implementation  
**Component**: `ai-sidebar` (`panel.luau`, `client.luau`, `storage.luau`, `providers/custom.luau`, `providers/openai.luau`, `providers/gemini.luau`)

---

## 1. Problem Statement & Motivation

1. **Reasoning Models (Chain-of-Thought)**:
   Modern reasoning models (such as DeepSeek-R1, Qwen QwQ, Gemini 2.0 Flash Thinking, and OpenAI o-series) output their internal thought process before generating their final response. Currently:
   * Providers drop `choice.delta.reasoning_content` completely, resulting in empty responses or long periods of silence during generation.
   * If a model streams inline `<think>...</think>` tags in `delta.content`, the raw tags and thinking tokens pollute the chat bubble, make responses unwieldy, and break clean clipboard copying.
   * Users lack visibility into whether the model is actively thinking or frozen, and cannot inspect or hide the reasoning steps.

2. **Web Search Interaction (Manual vs. Autonomous)**:
   * Web search currently requires manual invocation via the `/search` slash command.
   * Users expect intelligent AI models to autonomously identify when they need real-time facts, documentation, or recent news, and call search tools dynamically without requiring user intervention every time.
   * At the same time, users must retain control: the ability to force search upfront with `/search <query>` if desired, and a master setting toggle to disable web search entirely for privacy, offline use, or token economy.

---

## 2. Key Requirements & Design Decisions

### 2.1 Dual-Format Reasoning Token Parser
The system must support the two major reasoning output conventions used across LLM endpoints:
1. **Dedicated Field (`reasoning_content`)**:
   * OpenAI-compatible providers (Ollama, vLLM, DeepSeek API, OpenRouter, Groq) provide reasoning tokens in `choice.delta.reasoning_content` or `choice.delta.reasoning`.
   * Parsers in `custom.luau` and `openai.luau` will extract reasoning tokens separately from standard `content`.
2. **Inline XML Tags (`<think> ... </think>`)**:
   * Certain local or quantized models stream thoughts directly in `choice.delta.content` surrounded by `<think>` and `</think>` tags.
   * A streaming state machine will capture tokens inside `<think>...</think>` into the reasoning accumulator and transition back to content once `</think>` is passed.
3. **Gemini Thinking (`candidates[].content.parts[].thought`)**:
   * Gemini 2.0 Thinking models mark thinking parts with `thought = true`. These are routed directly to reasoning.

### 2.2 Collapsible Reasoning UI (Accordion Component)
* **Visual Presentation**:
  * Located immediately above the assistant's response bubble.
  * **During Active Thinking**:
    * Displays `🧠 Berpikir... (X.Xs)` with an animated spinner (`loader-2` / pulse).
    * Thinking text is expanded by default during generation so the user can observe the reasoning in real time.
    * Uses compact, dimmed typography (`fontSize = 11`, `color = "on_surface_variant"`, `fill = "surface_variant/0.15"`).
  * **When Content Starts or Thinking Completes**:
    * Automatically collapses into a sleek single-line summary: `🧠 Telah berpikir selama 3 detik ▾` (`Thought for 3 seconds ▾`).
    * Clickable header to expand/collapse at will.
* **Clipboard Isolation**:
  * The message "Copy" button copies **only** `msg.content` (the final response), never copying internal reasoning thoughts to the user clipboard.
* **Storage Persistence**:
  * `storage.Message` persists `reasoning: string?` and `reasoningDurationMs: number?` to `sessions.json`.
  * Historical sessions preserve the expandable reasoning block upon reopening.

### 2.3 Autonomous Web Search Tool Calling Protocol
* **OpenAI Function Calling Schema (`web_search`)**:
  * When `enable_web_search == true`, the client supplies a standard function tool definition:
    ```json
    {
      "type": "function",
      "function": {
        "name": "web_search",
        "description": "Cari informasi terkini di web secara real-time untuk berita, dokumentasi, fakta, atau pertanyaan yang memerlukan data mutakhir.",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Kata kunci pencarian yang ringkas dan efektif."
            }
          },
          "required": ["query"]
        }
      }
    }
    ```
  * Attached for Custom provider and OpenAI provider requests.
  * For Gemini provider: If `search_engine == "gemini_native"`, native `{ googleSearch = {} }` tool is attached. If external engine is configured, standard tool definition is used.

### 2.4 Autonomous Execution Loop & Multi-Pass Synthesis
1. **Model Emits Tool Call**:
   * Stream parser detects `delta.tool_calls` specifying `web_search` with argument `query`.
2. **Visual Progress Indicator**:
   * UI status updates to: `🔍 Mencari web: "<query>"...`
3. **Tool Execution**:
   * Client invokes `search.performSearch(query, config, callback)`.
4. **Follow-Up Grounding Request**:
   * Once results arrive, the client appends:
     1. `{ role = "assistant", content = "", tool_calls = [...] }`
     2. `{ role = "tool", tool_call_id = id, content = searchResultContext }`
   * The client initiates the second streaming pass so the LLM synthesizes the final grounded answer.
5. **Guardrail (Max 1 Hop)**:
   * To prevent runaway token consumption or infinite tool loops, autonomous search is capped at 1 tool invocation per chat turn.

### 2.5 Hybrid Harmony with `/search` Slash Command
* **Normal Chat**: LLM autonomously decides when to trigger `web_search`.
* **Manual `/search <query>`**: If the user explicitly types `/search`, the existing pre-retrieval pipeline immediately executes search before invoking the LLM, bypassing the LLM's decision step.
* **Persona Preservation**: Factual web context is strictly treated as background facts; the assistant's assigned persona, character, and conversational style are unconditionally preserved.

### 2.6 Master Settings Toggle
* **Setting Option**: `enable_web_search: boolean` (Default: `true`).
* **In Settings UI**:
  * Toggle switch: `Aktifkan Pencarian Web` / `Enable Web Search`.
* **When Disabled (`false`)**:
  * Tool schema is NOT included in LLM requests (autonomous tool calling is inactive).
  * If the user attempts `/search`, the UI alerts the user: `[Pencarian web dinonaktifkan di Pengaturan]`.
  * Search engine configuration controls in Settings are dimmed or disabled.

---

## 3. Architecture & Data Flow

```
[User Message Submitted]
       │
       ▼
[Check Master Toggle: enable_web_search]
  ├── OFF: Standard prompt, no tools attached ──► [Normal Stream (no search)]
  └── ON:
       ├── If user used "/search <query>":
       │     └── Pre-retrieval search ──► Inject search context ──► [Stream with Grounding]
       │
       └── Normal dialogue without /search:
             └── Attach "web_search" tool schema ──► [First Stream Pass]
                   │
                   ├── Case A: Model outputs content directly (math/coding/chat)
                   │     └── Stream & render content normally
                   │
                   └── Case B: Model calls "web_search"
                         │
                         ▼
                   [UI shows: "🔍 Mencari web: '<query>'..."]
                         │
                         ▼
                   [search.performSearch(query)]
                         │
                         ▼
                   [Append tool result message]
                         │
                         ▼
                   [Second Stream Pass] ──► [Model synthesizes grounded response]
```

---

## 4. Storage & Types Specification

### `storage.luau`
```luau
export type Message = {
  role: string,                     -- "user" | "assistant" | "system" | "tool"
  content: string,
  timestamp: number?,
  metrics: MessageMetrics?,
  reasoning: string?,               -- Internal chain-of-thought text
  reasoningDurationMs: number?,     -- Time spent in reasoning phase
  tool_calls: { any }?,             -- Optional tool call metadata if applicable
  tool_call_id: string?,            -- For tool response messages
}
```

### Provider Parsers Output Specification
Stream lines emit a structured parsed event:
```luau
export type StreamChunk = {
  type: "content" | "reasoning" | "tool_call" | "done",
  text: string?,
  toolCall: {
    id: string?,
    name: string?,
    argumentsChunk: string?,
  }?,
}
```

---

## 5. UI / UX Design

### Accordion State Machine in `panel.luau`
* `isThinking: boolean` — true while reasoning tokens are actively arriving.
* `thinkingElapsedMs: number` — live timer updated via `noctalia.nowMs()`.
* `expandedThinking: { [number]: boolean }` — dictionary of message indices mapping to accordion open/close state.
* Default states:
  * During stream: `expandedThinking[msgIdx] = true` (visible progress).
  * On transition to content: `expandedThinking[msgIdx] = false` (auto-collapsed, unobtrusive).
  * Clicking header toggles `expandedThinking[msgIdx] = not expandedThinking[msgIdx]`.

---

## 6. Error Handling & Edge Cases

1. **Model Doesn't Support Reasoning**:
   * No reasoning tokens are emitted; response renders immediately as normal text without empty blocks.
2. **Web Search Fails or Times Out**:
   * If search errors during an autonomous tool call, error text is returned as the tool response (`"Search error: network timeout"`). The LLM gracefully informs the user rather than hanging.
3. **Premature User Cancellation (Stop Button)**:
   * Clicking the Stop button stops the active HTTP stream and terminates any pending background search process cleanly.
4. **Backward Compatibility**:
   * Existing sessions lacking `reasoning` load seamlessly without errors.

---

## 7. Verification & Testing Plan

1. **Unit Tests (`tests/test_ai_sidebar_reasoning_and_tools.py`)**:
   * Test parsing `delta.reasoning_content` across Ollama, DeepSeek, vLLM formats.
   * Test inline `<think>...</think>` state machine parser.
   * Test `delta.tool_calls` extraction and accumulation.
   * Test tool execution and multi-pass message construction.
   * Test storage serialization and deserialization of `reasoning` and `reasoningDurationMs`.
   * Test `enable_web_search` toggle disabling tools and `/search`.
2. **Regression Testing**:
   * Run existing test suite (`python3 -m unittest discover -s tests -p "test_*.py"`) to guarantee 100% pass rate.
