# Design Specification: Natural Conversational Search Grounding

**Date**: 2026-10-04  
**Status**: Draft / Under Review  
**Component**: `ai-sidebar` (`panel.luau`, `search.luau`, `client.luau`)

---

## 1. Problem Statement & Motivation

When users activate web search using the `/search` slash command (e.g. `/search tolong carikan laptop yang bagus buat coding budget 15 jutaan`), the assistant currently exhibits several behavioral flaws:

1. **Persona Disruption (Robotic Search Bot)**: The LLM suddenly changes persona from a warm, conversational AI companion into a robotic search engine indexer, often replying with clinical summaries like *"Berikut adalah hasil pencarian dari web:"* followed by numbered lists of links.
2. **Slash Command Pollution in Dialogue**: The prefix `/search` remains in the stored conversation history. The LLM sees `/search <text>` as a CLI command or prompt prefix rather than a natural user message.
3. **Lack of Contextual Fluidity**: If the user asks a follow-up referring to previous chat context (e.g. *"/search bagaimana dengan performa baterainya?"*), taking the search text literally loses the subject (which laptop or device was being discussed).
4. **Rigid Grounding Instructions**: The search context injection in `search.luau` uses rigid commands (*"Incorporate the above live web search information into your response. Cite sources with markdown links where appropriate"*), which prompts the LLM to format its response like a search engine indexer.

The goal is to make web search a **silent, natural grounding assistant** behind the scenes. The LLM should maintain its conversational tone, seamlessly weave verified up-to-date facts into its dialogue, and feel like a well-informed conversational partner.

---

## 2. Key Requirements & Design Decisions

### 2.1 Invisible Slash Command (Clean Dialogue History)
* The `/search` command is solely a UI trigger.
* When the user submits `/search <message>`:
  * The message saved in `currentSession.messages` will have the `/search` prefix stripped cleanly. E.g., `/search tolong carikan laptop...` becomes `tolong carikan laptop...`.
  * The conversation title generator uses the clean text.
  * If the user submits a bare `/search`, the message is saved as a natural inquiry (e.g., `tr("slash_search_default_prompt")` -> *"Tolong carikan info terbaru dari web terkait topik ini"* / *"Please look up the latest information regarding this topic"*).

### 2.2 Intelligent Background Query Synthesis (Silent Retrieval)
* Rather than searching raw conversational sentences or missing pronouns:
  * `client.synthesizeSearchQuery` analyzes the last few messages of the conversation alongside the current request.
  * Resolves pronouns and references (e.g. "dia", "itu", "kedua framework tadi" -> actual named entities).
  * Strips conversational filler ("tolong carikan", "kira-kira", "menurutmu", etc.).
  * Produces 3 to 6 high-yield keywords optimized for web search engines.
  * Runs with `max_tokens = 35` and `temperature = 0.0` for sub-350ms execution speed.
  * Safety fallback: If synthesis times out or errors, gracefully extracts significant words locally without blocking.

### 2.3 Conversational Grounding Prompting (Natural Voice)
* Update `search.formatSearchContext` and `buildEnvironmentPrompt`:
  * Rename the block from `[Web Search Results for: "..."]` to `[Web Context & Current Information: "..."]`.
  * Replace the rigid instruction with natural conversational guidance:
    > *"Instructions: Use the above web information as your up-to-date factual background. Maintain a natural, friendly, and engaging conversational flow. Do not act like a search engine or output raw link lists; instead, discuss and explain the findings organically as part of your conversation, referencing sources smoothly only when relevant."*
* When Gemini Native Grounding is used (`tools = { { googleSearch = {} } }`), provide similar system prompt guidance so Gemini synthesizes responses conversationally rather than mechanically dumping search chips.

---

## 3. Architecture & Data Flow

```
User types in UI:
"/search bagaimana menurutmu tentang performa baterainya?"
         │
         ▼
[panel.luau]
- Parse slash command -> isSlashSearch = true, cleanText = "bagaimana menurutmu tentang performa baterainya?"
- Store cleanText into currentSession.messages (NO "/search" in history)
- Set UI status to searching
         │
         ▼
[client.prepareContextualSearch]
- Send cleanText + recent conversation history to client.synthesizeSearchQuery
- LLM outputs: "ThinkPad T14 AMD battery life test benchmark" (<300ms)
         │
         ▼
[search.performSearch]
- Executes search engine (Wikipedia / DuckDuckGo / Tavily / Brave)
- Formats results with Natural Conversational Grounding instructions
         │
         ▼
[client.streamChat]
- Streams LLM response with clean chat history + background factual context
- LLM responds in natural conversational tone:
  "Untuk daya tahan baterainya, berdasarkan pengujian terbaru..."
```

---

## 4. Component Changes

1. **`ai-sidebar/panel.luau`**:
   * In `sendMessage()`:
     * When `search.isSlashSearch(text)` returns `true, strippedText`:
     * If `strippedText == ""` -> set text to localized default conversational query (`tr("slash_search_default_prompt")`).
     * Otherwise -> set text to `strippedText`.
     * Save clean text in `currentSession.messages`.
     * Pass `isSlashSearch = true` to `client.prepareContextualSearch` and `client.streamChat`.
   * In `regenerateLastMessage()`:
     * Correctly identify if the last turn was a search or if the user asks for search grounding.
2. **`ai-sidebar/search.luau`**:
   * In `search.formatSearchContext(items, query)`:
     * Update phrasing and instructions to focus on natural conversational synthesis.
3. **`ai-sidebar/client.luau`**:
   * In `buildEnvironmentPrompt()`:
     * Provide clear guidance that web search data should be integrated smoothly into the assistant's personality.
   * In `client.prepareContextualSearch()`:
     * Always synthesize search keywords from conversation context + clean user prompt (removing fast-path raw dump of user chat).
   * In `client.synthesizeSearchQuery()`:
     * Pass `max_tokens: 35` and `temperature: 0.0` to ensure fast synthesis.
4. **`ai-sidebar/translations/en.json` & `id.json`**:
   * Add `slash_search_default_prompt` ("Please look up the latest information regarding this topic." / "Tolong carikan informasi terbaru dari web terkait topik ini.").

---

## 5. Testing & Verification

1. **Unit Tests**:
   * Add test verifying `/search` prefix is stripped from stored message history.
   * Add test verifying bare `/search` is converted to localized conversational prompt.
   * Add test verifying `search.formatSearchContext` contains conversational instructions instead of robotic search directives.
   * Add test verifying `client.luau` context synthesis prompt constraints.
2. **Regression Testing**:
   * Run all existing 115 tests in `tests/test_*.py` to ensure zero regressions.
   * Run `luau-lsp analyze` to ensure strict type compliance.
