# Scratchpad

Fast, private Markdown scratchpad for the Noctalia desktop shell with zero-click instant capture, auto-archive privacy, rendered preview, quick-capture toolbar, and note library.

## Plugin

| Field | Value |
| --- | --- |
| ID | `rigelyon/scratchpad` |
| Entries | Panel: `panel`; Launcher provider: `launcher`; Bar widget: `scratchpad` |
| Launcher Prefix | `/sp` |

## Features

- **Zero-Click Instant Capture:** Opening the panel immediately presents an empty, auto-focused editor ready for `Ctrl+V` pasting or typing.
- **Privacy First (Auto-Archive on Close):** Unsaved drafts are automatically saved to your notes library when the panel closes, ensuring the scratchpad opens clean without exposing private notes in public.
- **1-Click Markdown Preview:** Toggle smoothly between raw editing and beautiful rendered Markdown (`ui.markdown`).
- **Quick Formatting Toolbar:** One-click chips to insert Headings (`H1`, `H2`), Bold, Italic, Checklists (`- [ ]`), Code blocks, Quotes, and Lists.
- **Saved Notes Library:** Full-height tab with instant search, pinned notes, 1-click clipboard copy without opening, and safe inline deletion.
- **Status Bar Widget:** Quick-toggle panel button with live note count tooltip.
- **Launcher Provider (`/sp`):** Search your notes library or type `/sp <text>` to quick-capture notes instantly from the launcher.

## Usage

### 1. Opening the Scratchpad

Click the Scratchpad icon in your Noctalia status bar or execute the panel toggle command from a keybind or terminal:

```sh
noctalia msg panel-toggle rigelyon/scratchpad:panel
```

When opened, the editor is immediately focused so you can start typing or paste clipboard content without any extra clicks.

### 2. Markdown Formatting & Preview

The quick formatting toolbar above the editor provides one-click formatting helpers:
- **H1 / H2**: Insert top-level or section headings.
- **B / I**: Wrap selected text in bold (`**text**`) or italic (`*text*`).
- **Checklist**: Insert an interactive task item (`- [ ]`).
- **Code**: Insert code syntax (` ``` `).
- **Quote**: Insert blockquote syntax (`> `).
- **Preview**: Toggle between raw Markdown editing and live rendered Markdown.

### 3. Auto-Archive & Privacy

Scratchpad is designed for privacy:
- When you close the panel or switch away, the active draft is automatically archived to your notes directory.
- The title is automatically derived from the first `# Heading` in your text, or assigned a timestamped name if no heading is present.
- The next time you open the Scratchpad, you are greeted with a clean, blank editor ready for new thoughts, preventing sensitive notes from remaining visible on screen.

### 4. Saved Notes Library

Switch to the **Library** tab in the panel header to manage your saved notes:
- **Search**: Type in the search box to filter notes instantly by filename or title.
- **Pin / Unpin**: Click the pin icon on any note to keep important references at the top of your list.
- **Quick Copy**: Click the copy icon to copy a note's full contents to your clipboard without having to open it.
- **Delete**: Click the trash icon to remove notes you no longer need.

### 5. Launcher Quick-Capture & Search (`/sp`)

Access your notes directly from Noctalia's launcher:
- Type `/sp` to list your notes library, with pinned notes automatically highlighted at the top.
- Type `/sp <search terms>` to quickly filter notes. Selecting a note copies its content or opens it.
- Type `/sp <new note text>` and press `Enter` on the top action item to instantly capture a note without opening the panel.

## Settings

### Global Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `notes_dir` | `folder` | `~/Documents/Scratchpad` | Directory where markdown notes and pins are saved. |
| `extension` | `string` | `md` | Note file extension without leading dot. |
| `auto_archive` | `bool` | `true` | Automatically save draft on close to preserve privacy. |
| `split_view` | `bool` | `false` | Enable live rendered Markdown preview below the editor while typing. |

### Bar Widget Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `glyph` | `glyph` | `notebook` | Icon displayed on the status bar widget. |

## License

MIT
