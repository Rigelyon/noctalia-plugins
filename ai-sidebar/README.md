# AI Sidebar

A sleek, robust AI chat sidebar panel for the Noctalia desktop shell. Connect directly to OpenAI, Anthropic Claude, or Google Gemini with real-time streaming responses, persistent multi-session history, and quick desktop access.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/ai-sidebar` |
| Entries | Panel: `panel`; Bar widget: `ai-sidebar` |

## Features

- **Multi-Provider Support**: Native API integrations for OpenAI, Anthropic Claude, and Google Gemini.
- **Real-Time Streaming**: Watch responses generate smoothly in real-time, with an instant "Stop" button to cancel generation.
- **Rich Markdown Formatting**: Read responses rendered with formatted code blocks, bold text, bullet points, and headers.
- **Multi-Session History**: Conversations are organized by session, searchable, and stored locally for privacy.
- **In-Panel Settings & Connection Testing**: Easily configure API keys, switch models, adjust system prompts, and test connection directly within the panel.
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
3. Navigate to the **Setting** tab, choose your provider, enter your API key, and click **Test Connection**.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `default_provider` | `select` | `openai` | Primary AI provider (`openai`, `anthropic`, `gemini`). |
| `openai_api_key` | `string` | `""` | API key for OpenAI API requests. |
| `openai_model` | `string` | `gpt-4o-mini` | Default OpenAI model. |
| `anthropic_api_key` | `string` | `""` | API key for Anthropic Claude requests. |
| `anthropic_model` | `string` | `claude-3-5-haiku-20241022` | Default Anthropic model. |
| `gemini_api_key` | `string` | `""` | API key for Google Gemini requests. |
| `gemini_model` | `string` | `gemini-1.5-flash` | Default Google Gemini model. |
| `system_prompt` | `string` | `You are a helpful and concise AI assistant.` | Base instruction given to the AI assistant. |
