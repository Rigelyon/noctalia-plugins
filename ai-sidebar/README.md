# AI Sidebar

A sleek, robust AI chat sidebar panel for the Noctalia desktop shell. Connect directly to OpenAI, Anthropic Claude, or Google Gemini with real-time streaming responses, persistent multi-session history, and quick desktop access.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/ai-sidebar` |
| Entries | Panel: `panel`; Bar widget: `ai-sidebar`, `bar_widget` |

## Features

- **Multi-Provider Support**: Native API integrations for OpenAI, Anthropic Claude, Google Gemini, and Custom / Local OpenAI-compatible endpoints (e.g. Ollama, LM Studio).
- **Real-Time Streaming**: Watch responses generate smoothly in real-time, with an instant "Stop" button to cancel generation.
- **Prompt Library (`#`)**: Type `#` or click the prompt icon to access curated, customizable prompt templates (`explain`, `code-review`, `summarize`, `fix-grammar`, `translate`, `write-test`).
- **AI Background Auto-Titler**: Conversations are automatically summarized into clean 3–5 word titles after the first turn in the background.
- **Export to Markdown**: Export full conversations with YAML metadata to `~/Documents/ai-sidebar/` with a single click or IPC command.
- **Response Telemetry Metrics**: Inspect subtle token counts, response durations, and generation speeds (`tok/s`) below assistant responses.
- **Interactive Chat Actions**: Regenerate responses, edit user prompts, rewind to any turn, and copy individual code blocks with syntax badges.
- **Multi-Session History**: Conversations are organized by session, searchable, and stored locally for privacy.
- **In-Panel Settings & Connection Testing**: Easily configure API keys, switch models, adjust system prompts, and test connection directly within the panel.
- **Live Web Search**: Fetch real-time internet context before generating answers using DuckDuckGo (free, no key required), Gemini Native Google Search grounding, Tavily Search, or Brave Search.
- **Low CPU Footprint**: Throttled UI rendering and in-memory caching engineered specifically for Noctalia's Luau instruction budget.

## Usage

1. Enable the plugin:
   ```bash
   noctalia msg plugins enable rigelyon/ai-sidebar
   ```
2. Open the AI Sidebar from the bar widget or via IPC:
   ```bash
   noctalia msg panel-toggle rigelyon/ai-sidebar:panel
   ```
3. Navigate to the **Setting** tab, choose your provider, enter your API key, optionally toggle **Enable Web Search**, and click **Test Connection**.

## IPC Commands

Interact with AI Sidebar from terminal scripts or window manager shortcuts:

```bash
# Clear active chat and prepare a clean session (even in the background)
noctalia msg plugin rigelyon/ai-sidebar:panel all clear

# Send a prompt directly from the shell or hotkey
noctalia msg plugin rigelyon/ai-sidebar:panel all ask "Explain how to write Luau plugins"

# Export the active conversation to a Markdown file
noctalia msg plugin rigelyon/ai-sidebar:panel all export

# Toggle panel visibility (direct toggle or via plugin event)
noctalia msg panel-toggle rigelyon/ai-sidebar:panel
noctalia msg plugin rigelyon/ai-sidebar:panel all toggle
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `default_provider` | `select` | `openai` | Primary AI provider (`openai`, `anthropic`, `gemini`, `custom`). |
| `openai_api_key` | `string` | `""` | API key for OpenAI API requests. |
| `openai_model` | `string` | `gpt-4o-mini` | Default OpenAI model. |
| `anthropic_api_key` | `string` | `""` | API key for Anthropic Claude requests. |
| `anthropic_model` | `string` | `claude-3-5-haiku-20241022` | Default Anthropic model. |
| `gemini_api_key` | `string` | `""` | API key for Google Gemini requests. |
| `gemini_model` | `string` | `gemini-1.5-flash` | Default Google Gemini model. |
| `custom_base_url` | `string` | `http://localhost:11434/v1` | Base URL for OpenAI-compatible endpoint. |
| `custom_api_key` | `string` | `""` | API key for custom endpoint (optional for local models). |
| `custom_model` | `string` | `llama3.2` | Model identifier for custom provider. |
| `system_prompt` | `string` | `You are a helpful and concise AI assistant.` | Base instruction given to the AI assistant. |
| `search_engine` | `select` | `duckduckgo` | Search engine for `/search` (`duckduckgo`, `gemini_native`, `tavily`, `brave`). |
| `search_api_key` | `string` | `""` | API key for Tavily or Brave Search. |
| `search_max_results` | `select` | `3` | Max search snippets included in context (`3`, `5`, `7`). |

### Web Search (`/search` Slash Command)

Live internet search is triggered on-demand using the `/search` slash command:
- `/search`: The AI automatically synthesizes a concise search query based on the ongoing conversation context.
- `/search <question>`: The AI searches for information based on the specified question and context.
- Regular messages sent without `/search` stream immediately from the AI model with zero search overhead.

