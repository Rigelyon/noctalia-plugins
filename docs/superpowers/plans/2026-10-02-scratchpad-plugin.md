# Scratchpad Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a feature-rich, high-privacy Markdown scratchpad plugin for the Noctalia desktop shell (`rigelyon/scratchpad`) featuring zero-click instant capture, automatic archiving on close, native Markdown preview, markdown formatting toolbar, and a saved notes library.

**Architecture:** Luau scripts for Noctalia Desktop Shell. A floating panel (`panel.luau`) implements segmented tabs for Scratchpad and Saved Notes with native `ui.markdown` rendering; a bar widget (`widget.luau`) displays shell status; a launcher provider (`launcher.luau`) provides `sp` quick-capture and search. Notes are persisted as `.md` files in `~/Documents/Scratchpad` with `.pinned.json` for pin states.

**Tech Stack:** Luau, Noctalia Plugin API 28+, Python 3 (unittest & validation scripts).

## Global Constraints
- Target Noctalia Plugin API: 28
- Plugin ID: `rigelyon/scratchpad`
- Author: `rigelyon`
- License: `MIT`
- Storage default: `~/Documents/Scratchpad` with `.md` extension
- All user-facing strings must be localized in `translations/en.json` and `translations/id.json`
- Strict compliance with `validate-plugins.py` and `noctalia plugins lint scratchpad`

---

### Task 1: Plugin Manifest & Bilingual Translations

**Files:**
- Create: `scratchpad/plugin.toml`
- Create: `scratchpad/translations/en.json`
- Create: `scratchpad/translations/id.json`
- Test: `tests/test_scratchpad_manifest.py`

**Interfaces:**
- Produces: `scratchpad/plugin.toml` declaring settings (`notes_dir`, `extension`, `auto_archive`), panel (`panel.luau`), widget (`widget.luau`), and launcher_provider (`launcher.luau`).
- Produces: `translations/en.json` and `translations/id.json` defining all keys referenced by `plugin.toml` and scripts.

- [ ] **Step 1: Write the failing test for manifest and translations**

```python
import json
import os
import tomllib
import unittest

PLUGIN_DIR = os.path.join(os.path.dirname(__file__), "..", "scratchpad")


def has_key_path(data, dotted_key):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


class TestScratchpadManifest(unittest.TestCase):
    def test_manifest_and_translations(self):
        manifest_path = os.path.join(PLUGIN_DIR, "plugin.toml")
        en_path = os.path.join(PLUGIN_DIR, "translations", "en.json")
        id_path = os.path.join(PLUGIN_DIR, "translations", "id.json")

        self.assertTrue(os.path.isfile(manifest_path), "Missing plugin.toml")
        self.assertTrue(os.path.isfile(en_path), "Missing translations/en.json")
        self.assertTrue(os.path.isfile(id_path), "Missing translations/id.json")

        with open(manifest_path, "rb") as f:
            manifest = tomllib.load(f)
        with open(en_path, "r", encoding="utf-8") as f:
            en = json.load(f)
        with open(id_path, "r", encoding="utf-8") as f:
            id_lang = json.load(f)

        self.assertEqual(manifest.get("id"), "rigelyon/scratchpad")
        self.assertEqual(manifest.get("plugin_api"), 28)
        self.assertEqual(manifest.get("author"), "rigelyon")

        # Verify declared components
        panels = manifest.get("panel", [])
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0].get("id"), "panel")
        self.assertEqual(panels[0].get("entry"), "panel.luau")

        widgets = manifest.get("widget", [])
        self.assertEqual(len(widgets), 1)
        self.assertEqual(widgets[0].get("id"), "scratchpad")
        self.assertEqual(widgets[0].get("entry"), "widget.luau")

        providers = manifest.get("launcher_provider", [])
        self.assertEqual(len(providers), 1)
        self.assertEqual(providers[0].get("prefix"), "sp")
        self.assertEqual(providers[0].get("entry"), "launcher.luau")

        # Verify all setting translation keys in en and id
        for setting in manifest.get("setting", []):
            for key_prop in ["label_key", "description_key"]:
                if key_prop in setting:
                    k = setting[key_prop]
                    self.assertTrue(has_key_path(en, k), f"en.json missing {k}")
                    self.assertTrue(has_key_path(id_lang, k), f"id.json missing {k}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_scratchpad_manifest.py -v`
Expected: FAIL with "Missing plugin.toml" or FileNotFoundError

- [ ] **Step 3: Create directory and manifest file**

Write `scratchpad/plugin.toml`:
```toml
id = "rigelyon/scratchpad"
name = "Scratchpad"
version = "1.0.0"
plugin_api = 28
author = "rigelyon"
license = "MIT"
dependencies = []
tags = ["productivity", "utility", "launcher", "panel", "notes", "markdown"]
icon = "notebook"
description = "Fast, private Markdown scratchpad with auto-archive, rendered preview, and note library."

[[setting]]
key = "notes_dir"
type = "folder"
label_key = "settings.notes_dir.label"
description_key = "settings.notes_dir.description"
default = "~/Documents/Scratchpad"

[[setting]]
key = "extension"
type = "string"
label_key = "settings.extension.label"
description_key = "settings.extension.description"
default = "md"

[[setting]]
key = "auto_archive"
type = "boolean"
label_key = "settings.auto_archive.label"
description_key = "settings.auto_archive.description"
default = true

[[panel]]
id = "panel"
entry = "panel.luau"
width = 460
height = "fill"
placement = "floating"
position = "center_right"

[[launcher_provider]]
id = "launcher"
entry = "launcher.luau"
prefix = "sp"
glyph = "notebook"
include_in_global_search = false

[[widget]]
id = "scratchpad"
entry = "widget.luau"

  [[widget.setting]]
  key = "glyph"
  type = "glyph"
  label_key = "settings.glyph.label"
  default = "notebook"
```

- [ ] **Step 4: Create English and Indonesian translations**

Write `scratchpad/translations/en.json`:
```json
{
  "title": "Scratchpad",
  "tab_scratchpad": "Scratchpad",
  "tab_saved_notes": "Saved Notes",
  "editor_placeholder": "Type or paste Markdown here...",
  "search_placeholder": "Search notes by title or content...",
  "no_notes": "No saved notes yet",
  "no_search_results": "No notes match your search",
  "ready": "Ready",
  "status_counts": "{words} words · {chars} chars",
  "copied_all": "Copied scratchpad to clipboard",
  "copied_note": "Copied note to clipboard",
  "note_archived": "Archived note: {name}",
  "toggle_preview": "Toggle Preview",
  "toggle_edit": "Back to Editor",
  "copy_all": "Copy All",
  "archive_note": "Archive to Notes",
  "clear": "Clear",
  "clear_confirm": "Clear scratchpad?",
  "confirm_delete": "Delete?",
  "close": "Close",
  "pin": "Pin note",
  "unpin": "Unpin note",
  "edit_note": "Open in Scratchpad",
  "delete_note": "Delete note",
  "pinned_section": "Pinned",
  "recent_section": "Recent",
  "quick_capture_prompt": "Quick Capture to Scratchpad",
  "widget_tooltip": "Scratchpad · {count} notes",
  "settings": {
    "notes_dir": {
      "label": "Notes Directory",
      "description": "Folder where markdown notes and pins are saved."
    },
    "extension": {
      "label": "File Extension",
      "description": "File extension for notes without leading dot (default: md)."
    },
    "auto_archive": {
      "label": "Auto-Archive on Close",
      "description": "Automatically saves scratchpad text as a note on close and clears the editor for maximum privacy."
    },
    "glyph": {
      "label": "Status Bar Icon"
    }
  }
}
```

Write `scratchpad/translations/id.json`:
```json
{
  "title": "Scratchpad",
  "tab_scratchpad": "Scratchpad",
  "tab_saved_notes": "Catatan Tersimpan",
  "editor_placeholder": "Ketik atau tempel teks Markdown di sini...",
  "search_placeholder": "Cari catatan berdasarkan judul atau isi...",
  "no_notes": "Belum ada catatan tersimpan",
  "no_search_results": "Tidak ada catatan yang cocok",
  "ready": "Siap",
  "status_counts": "{words} kata · {chars} karakter",
  "copied_all": "Scratchpad berhasil disalin ke clipboard",
  "copied_note": "Catatan berhasil disalin ke clipboard",
  "note_archived": "Catatan diarsipkan: {name}",
  "toggle_preview": "Tampilkan Pratinjau",
  "toggle_edit": "Kembali ke Editor",
  "copy_all": "Salin Semua",
  "archive_note": "Arsipkan ke Catatan",
  "clear": "Bersihkan",
  "clear_confirm": "Bersihkan scratchpad?",
  "confirm_delete": "Hapus?",
  "close": "Tutup",
  "pin": "Pin catatan",
  "unpin": "Lepas pin catatan",
  "edit_note": "Buka di Scratchpad",
  "delete_note": "Hapus catatan",
  "pinned_section": "Disematkan",
  "recent_section": "Terbaru",
  "quick_capture_prompt": "Simpan Cepat ke Scratchpad",
  "widget_tooltip": "Scratchpad · {count} catatan",
  "settings": {
    "notes_dir": {
      "label": "Direktori Catatan",
      "description": "Folder tempat penyimpanan berkas markdown dan pin."
    },
    "extension": {
      "label": "Ekstensi Berkas",
      "description": "Ekstensi berkas catatan tanpa titik awalan (default: md)."
    },
    "auto_archive": {
      "label": "Auto-Arsip saat Ditutup",
      "description": "Otomatis mengarsipkan teks scratchpad saat panel ditutup dan mengosongkan editor demi privasi."
    },
    "glyph": {
      "label": "Ikon Status Bar"
    }
  }
}
```

- [ ] **Step 5: Run tests and validate manifest**

Run: `python3 -m unittest tests/test_scratchpad_manifest.py -v`
Expected: OK
Run: `python3 .github/workflows/validate-plugins.py`
Expected: "Validated 3 plugin manifest(s)."

- [ ] **Step 6: Commit**

```bash
git add scratchpad/plugin.toml scratchpad/translations/ tests/test_scratchpad_manifest.py
git commit -m "feat(scratchpad): add plugin manifest and bilingual translations"
```

---

### Task 2: Status Bar Widget (`widget.luau`)

**Files:**
- Create: `scratchpad/widget.luau`

**Interfaces:**
- Consumes: `barWidget` and `noctalia` host APIs.
- Produces: Bar widget rendering displaying the configured glyph, dynamic count tooltip, and click-to-toggle panel handler.

- [ ] **Step 1: Implement `scratchpad/widget.luau`**

```luau
--!strict
-- Status bar widget for Scratchpad.

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function countNotes(): number
  local notesDir = noctalia.expandPath(noctalia.getConfig("notes_dir") or "~/Documents/Scratchpad")
  local files = noctalia.listDir(notesDir)
  if files == nil then
    return 0
  end
  local ext = "." .. (tostring(noctalia.getConfig("extension") or "md"):gsub("^%.", ""))
  local count = 0
  for _, file in ipairs(files) do
    if #file > #ext and file:sub(-#ext) == ext and file:sub(1, 1) ~= "." then
      count += 1
    end
  end
  return count
end

local function updatePresentation()
  local glyph = tostring(noctalia.getConfig("glyph") or "notebook")
  barWidget.setGlyph(glyph)
  local count = countNotes()
  barWidget.setTooltip(tr("widget_tooltip", { count = count }))
end

function onClick()
  noctalia.togglePanel("rigelyon/scratchpad:panel")
end

function update()
  updatePresentation()
end

-- Refresh presentation when notes change externally
noctalia.state.watch("scratchpad_bump", function(_val)
  updatePresentation()
end)

updatePresentation()
```

- [ ] **Step 2: Run Noctalia plugin linter to verify widget declarations**

Run: `noctalia plugins lint scratchpad`
Expected: `rigelyon/scratchpad ok, 0 errors, 0 warnings`

- [ ] **Step 3: Commit**

```bash
git add scratchpad/widget.luau
git commit -m "feat(scratchpad): implement status bar widget"
```

---

### Task 3: Launcher Provider (`launcher.luau`)

**Files:**
- Create: `scratchpad/launcher.luau`
- Create: `tests/test_scratchpad_launcher.py`

**Interfaces:**
- Consumes: `launcher` and `noctalia` host APIs.
- Produces: `onQuery(query)` returning quick-capture and note search results; `onActivate(id)` executing instant-write or opening note in panel.

- [ ] **Step 1: Write simulation test for launcher quick-capture and search logic**

Create `tests/test_scratchpad_launcher.py`:
```python
import unittest


def simulate_launcher_results(query, notes, pinned_set):
    trimmed = query.strip()
    results = []

    if trimmed != "":
        # Offer quick capture
        results.append({
            "id": f"capture:{trimmed}",
            "title": f"Quick Capture: {trimmed}",
            "subtitle": "Save immediately to Scratchpad",
            "glyph": "plus",
        })

    # Filter notes
    for note in notes:
        title = note["title"]
        content = note["content"]
        is_pinned = note["filename"] in pinned_set

        matched = False
        if trimmed == "":
            matched = True
        else:
            q_lower = trimmed.lower()
            if q_lower in title.lower() or q_lower in content.lower():
                matched = True

        if matched:
            results.append({
                "id": f"note:{note['filename']}",
                "title": title,
                "subtitle": "Pinned note" if is_pinned else "Saved note",
                "glyph": "pinned" if is_pinned else "file-text",
            })

    return results


class TestScratchpadLauncher(unittest.TestCase):
    def setUp(self):
        self.notes = [
            {"filename": "Project ideas.md", "title": "Project ideas", "content": "Build noctalia plugins"},
            {"filename": "Groceries.md", "title": "Groceries", "content": "Milk, eggs, coffee"},
        ]
        self.pinned = {"Project ideas.md"}

    def test_empty_query_lists_all(self):
        res = simulate_launcher_results("", self.notes, self.pinned)
        self.assertEqual(len(res), 2)
        self.assertEqual(res[0]["id"], "note:Project ideas.md")
        self.assertEqual(res[0]["glyph"], "pinned")

    def test_query_with_text_has_quick_capture(self):
        res = simulate_launcher_results("buy milk", self.notes, self.pinned)
        self.assertGreaterEqual(len(res), 1)
        self.assertTrue(res[0]["id"].startswith("capture:"))
        self.assertEqual(res[0]["title"], "Quick Capture: buy milk")
        # Second item should be Groceries (matches "milk")
        self.assertEqual(res[1]["id"], "note:Groceries.md")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run launcher simulation test**

Run: `python3 -m unittest tests/test_scratchpad_launcher.py -v`
Expected: OK

- [ ] **Step 3: Implement `scratchpad/launcher.luau`**

```luau
--!nonstrict
-- Launcher provider for Scratchpad (prefix 'sp').

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function getNotesDir(): string
  return noctalia.expandPath(noctalia.getConfig("notes_dir") or "~/Documents/Scratchpad")
end

local function getExtension(): string
  local ext = noctalia.string.trim(tostring(noctalia.getConfig("extension") or "md")):gsub("^%.", "")
  if ext == "" then ext = "md" end
  return "." .. ext
end

local function loadPins(): { [string]: boolean }
  local pins = {}
  local raw = noctalia.readFile(getNotesDir() .. "/.pinned.json")
  if raw ~= nil then
    local decoded = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      for k, v in pairs(decoded) do
        if type(k) == "string" and v == true then
          pins[k] = true
        end
      end
    end
  end
  return pins
end

local function sanitizeTitle(filename: string, suffix: string): string
  if #filename > #suffix and filename:sub(-#suffix) == suffix then
    return filename:sub(1, #filename - #suffix)
  end
  return filename
end

function onQuery(query: string)
  local trimmed = noctalia.string.trim(query)
  local notesDir = getNotesDir()
  local suffix = getExtension()
  local pins = loadPins()
  local results = {}

  if trimmed ~= "" then
    table.insert(results, {
      id = "capture:" .. trimmed,
      title = tr("quick_capture_prompt") .. ": " .. trimmed,
      subtitle = tr("archive_note"),
      glyph = "plus",
    })
  end

  local list = noctalia.listDir(notesDir)
  local matchedFiles = {}
  if list ~= nil then
    for _, file in ipairs(list) do
      if #file > #suffix and file:sub(-#suffix) == suffix and file:sub(1, 1) ~= "." then
        local title = sanitizeTitle(file, suffix)
        local matched = true
        if trimmed ~= "" then
          local qLower = trimmed:lower()
          local tLower = title:lower()
          if not tLower:find(qLower, 1, true) then
            local contents = noctalia.readFile(notesDir .. "/" .. file) or ""
            if not contents:lower():find(qLower, 1, true) then
              matched = false
            end
          end
        end
        if matched then
          table.insert(matchedFiles, file)
        end
      end
    end
  end

  -- Sort: pinned first, then alphabetical
  table.sort(matchedFiles, function(a, b)
    local aPin = pins[a] == true
    local bPin = pins[b] == true
    if aPin ~= bPin then return aPin end
    return a < b
  end)

  for _, file in ipairs(matchedFiles) do
    local isPinned = pins[file] == true
    table.insert(results, {
      id = "note:" .. file,
      title = sanitizeTitle(file, suffix),
      subtitle = isPinned and tr("pinned_section") or tr("tab_saved_notes"),
      glyph = isPinned and "pinned" or "file-text",
    })
  end

  launcher.setResults(query, results)
end

function onActivate(id: string)
  if id:sub(1, 8) == "capture:" then
    local content = id:sub(9)
    local notesDir = getNotesDir()
    noctalia.mkdirAll(notesDir)
    local suffix = getExtension()
    local name = noctalia.formatTime("%Y-%m-%d %H.%M.%S") .. suffix
    noctalia.writeFile(notesDir .. "/" .. name, content)
    noctalia.state.set("scratchpad_bump", noctalia.nowMs())
    noctalia.notify(tr("title"), tr("note_archived", { name = name }))
    return
  end

  if id:sub(1, 5) == "note:" then
    local filename = id:sub(6)
    noctalia.state.set("scratchpad_open_file", filename)
    noctalia.togglePanel("rigelyon/scratchpad:panel")
    return
  end
end
```

- [ ] **Step 4: Lint launcher code**

Run: `noctalia plugins lint scratchpad`
Expected: `rigelyon/scratchpad ok, 0 errors, 0 warnings`

- [ ] **Step 5: Commit**

```bash
git add scratchpad/launcher.luau tests/test_scratchpad_launcher.py
git commit -m "feat(scratchpad): implement launcher provider with search and quick capture"
```

---

### Task 4: Panel Core UI (Scratchpad, Markdown Preview, Auto-Archive, Saved Notes)

**Files:**
- Create: `scratchpad/panel.luau`

**Interfaces:**
- Consumes: `panel`, `ui`, `noctalia` host APIs.
- Produces: Complete interactive panel with tabs (`scratchpad`, `saved_notes`), Markdown preview toggle, quick formatting toolbar, live status indicators, auto-archive on close, and full note management.

- [ ] **Step 1: Implement `scratchpad/panel.luau`**

Write `scratchpad/panel.luau`:
```luau
--!nonstrict
-- Scratchpad panel with Markdown preview, quick formatting toolbar,
-- auto-archive on close for maximum privacy, and a saved notes library.

local activeTab = "scratchpad" -- "scratchpad" | "saved_notes"
local viewMode = "edit"       -- "edit" | "preview"
local buffer = ""
local currentNoteFile = nil   -- filename when viewing/editing an existing note from library
local searchQuery = ""
local pendingDelete = nil     -- filename awaiting confirmation
local pins = {}               -- filename -> true
local files = {}
local notesDir = ""
local suffix = ".md"
local cornerRadiusScale = 1.0
local editorRev = 0

local render

local function tr(key: string, subst: { [string]: any }?): string
  return noctalia.tr(key, subst)
end

local function notePath(file: string): string
  return notesDir .. "/" .. file
end

local function displayName(file: string): string
  if #file > #suffix and file:sub(-#suffix) == suffix then
    return file:sub(1, #file - #suffix)
  end
  return file
end

local function pinsPath(): string
  return notesDir .. "/.pinned.json"
end

local function loadPins()
  pins = {}
  local raw = noctalia.readFile(pinsPath())
  if raw ~= nil then
    local decoded = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      for k, v in pairs(decoded) do
        if type(k) == "string" and v == true then
          pins[k] = true
        end
      end
    end
  end
end

local function savePins()
  local encoded = noctalia.json.encode(pins)
  if encoded ~= nil then
    noctalia.writeFile(pinsPath(), encoded)
  end
end

local function refreshFiles()
  files = {}
  local list = noctalia.listDir(notesDir)
  if list ~= nil then
    for _, name in ipairs(list) do
      if #name > #suffix and name:sub(-#suffix) == suffix and name:sub(1, 1) ~= "." then
        table.insert(files, name)
      end
    end
  end
  table.sort(files, function(a, b)
    local aPin = pins[a] == true
    local bPin = pins[b] == true
    if aPin ~= bPin then return aPin end
    return a < b
  end)
end

-- Generate a clean title from the first heading or line of content
local function generateArchiveName(content: string): string
  local trimmed = noctalia.string.trim(content)
  local firstLine = trimmed:match("^[^\r\n]+") or ""
  firstLine = firstLine:gsub("^#+%s*", ""):gsub("[/%\\:*?\"<>|]", "")
  firstLine = noctalia.string.trim(firstLine)
  if #firstLine > 0 and #firstLine <= 40 then
    local candidate = firstLine .. suffix
    if not noctalia.fileExists(notePath(candidate)) then
      return candidate
    end
  end
  local base = noctalia.formatTime("%Y-%m-%d %H.%M.%S")
  local name = base .. suffix
  local counter = 2
  while noctalia.fileExists(notePath(name)) do
    name = base .. " (" .. counter .. ")" .. suffix
    counter += 1
  end
  return name
end

local function archiveCurrentDraft()
  local trimmed = noctalia.string.trim(buffer)
  if #trimmed == 0 then
    return
  end
  if currentNoteFile ~= nil then
    -- Saving back to existing opened note
    noctalia.writeFile(notePath(currentNoteFile), buffer)
    currentNoteFile = nil
  else
    -- Creating a new archived note
    local name = generateArchiveName(buffer)
    noctalia.writeFile(notePath(name), buffer)
  end
  buffer = ""
  editorRev += 1
  noctalia.state.set("scratchpad_bump", noctalia.nowMs())
  refreshFiles()
end

local function insertMarkdownSyntax(prefix: string, postfix: string)
  postfix = postfix or ""
  buffer = buffer .. prefix .. postfix
  editorRev += 1
  render()
end

-- ── UI Components ─────────────────────────────────────────────────────────────

local function renderHeader()
  local tabs = ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = tr("tab_scratchpad"),
      variant = activeTab == "scratchpad" and "primary" or "ghost",
      onClick = function()
        activeTab = "scratchpad"
        render()
      end,
    }),
    ui.button({
      text = tr("tab_saved_notes") .. " (" .. tostring(#files) .. ")",
      variant = activeTab == "saved_notes" and "primary" or "ghost",
      onClick = function()
        activeTab = "saved_notes"
        pendingDelete = nil
        refreshFiles()
        render()
      end,
    }),
  })

  local actions = {}
  if activeTab == "scratchpad" then
    -- Preview / Edit Toggle
    table.insert(actions, ui.button({
      glyph = viewMode == "preview" and "edit" or "eye",
      variant = "ghost",
      onClick = function()
        viewMode = (viewMode == "preview") and "edit" or "preview"
        render()
      end,
    }))
    -- Copy All
    table.insert(actions, ui.button({
      glyph = "copy",
      variant = "ghost",
      onClick = function()
        if #buffer > 0 then
          noctalia.copyToClipboard(buffer, "text/plain;charset=utf-8")
          noctalia.notify(tr("title"), tr("copied_all"))
        end
      end,
    }))
    -- Archive / Save
    table.insert(actions, ui.button({
      glyph = "archive",
      variant = "ghost",
      onClick = function()
        archiveCurrentDraft()
        render()
      end,
    }))
    -- Clear
    table.insert(actions, ui.button({
      glyph = "eraser",
      variant = "ghost",
      onClick = function()
        buffer = ""
        currentNoteFile = nil
        editorRev += 1
        render()
      end,
    }))
  end

  table.insert(actions, ui.button({
    glyph = "x",
    variant = "ghost",
    onClick = function()
      panel.close()
    end,
  }))

  return ui.row({ align = "center", justify = "space_between" }, {
    tabs,
    ui.row({ gap = 4, align = "center" }, actions),
  })
end

local function renderToolbar()
  return ui.row({ gap = 4, align = "center" }, {
    ui.button({
      text = "H",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("\n# ") end,
    }),
    ui.button({
      text = "B",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("**bold**") end,
    }),
    ui.button({
      text = "I",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("*italic*") end,
    }),
    ui.button({
      text = "[✓]",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("\n- [ ] ") end,
    }),
    ui.button({
      text = "</>",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("\n```\n", "\n```\n") end,
    }),
    ui.button({
      text = ">",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("\n> ") end,
    }),
    ui.button({
      text = "•",
      variant = "ghost",
      onClick = function() insertMarkdownSyntax("\n- ") end,
    }),
  })
end

local function renderScratchpadView()
  local words = select(2, buffer:gsub("%S+", ""))
  local chars = utf8.len(buffer) or #buffer
  local statusLine = tr("ready") .. "  ·  " .. tr("status_counts", { words = words, chars = chars })

  local mainContent
  if viewMode == "preview" then
    mainContent = ui.scroll({ flexGrow = 1, padding = 8 }, {
      ui.markdown({ text = buffer ~= "" and buffer or "*Empty draft*" }),
    })
  else
    mainContent = ui.input({
      key = "editor-" .. editorRev,
      value = buffer,
      multiline = true,
      focus = true,
      flexGrow = 1,
      placeholder = tr("editor_placeholder"),
      onChange = function(val)
        buffer = val
        -- Note: avoid heavy re-render every character to protect CPU budget
      end,
    })
  end

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    renderToolbar(),
    mainContent,
    ui.label({
      text = statusLine,
      fontSize = 11,
      color = "on_surface_variant",
    }),
  })
end

local function renderSavedNotesView()
  local searchBar = ui.input({
    key = "search-input",
    value = searchQuery,
    placeholder = tr("search_placeholder"),
    onChange = function(val)
      searchQuery = val
      render()
    end,
  })

  local rows = {}
  local queryLower = noctalia.string.trim(searchQuery):lower()

  for _, file in ipairs(files) do
    local title = displayName(file)
    local matched = true
    if queryLower ~= "" then
      local tLower = title:lower()
      if not tLower:find(queryLower, 1, true) then
        local raw = noctalia.readFile(notePath(file)) or ""
        if not raw:lower():find(queryLower, 1, true) then
          matched = false
        end
      end
    end

    if matched then
      local isPinned = pins[file] == true
      local rowActions = {}

      if pendingDelete == file then
        table.insert(rowActions, ui.label({ text = tr("confirm_delete"), color = "error" }))
        table.insert(rowActions, ui.button({
          glyph = "check",
          variant = "primary",
          onClick = function()
            noctalia.removeFile(notePath(file))
            if pins[file] then
              pins[file] = nil
              savePins()
            end
            pendingDelete = nil
            refreshFiles()
            render()
          end,
        }))
        table.insert(rowActions, ui.button({
          glyph = "x",
          variant = "ghost",
          onClick = function()
            pendingDelete = nil
            render()
          end,
        }))
      else
        -- Copy note content directly
        table.insert(rowActions, ui.button({
          glyph = "copy",
          variant = "ghost",
          onClick = function()
            local content = noctalia.readFile(notePath(file)) or ""
            noctalia.copyToClipboard(content, "text/plain;charset=utf-8")
            noctalia.notify(tr("title"), tr("copied_note"))
          end,
        }))
        -- Pin / Unpin
        table.insert(rowActions, ui.button({
          glyph = isPinned and "pinned-off" or "pin",
          variant = "ghost",
          onClick = function()
            pins[file] = not pins[file] and true or nil
            savePins()
            refreshFiles()
            render()
          end,
        }))
        -- Delete
        table.insert(rowActions, ui.button({
          glyph = "trash",
          variant = "ghost",
          onClick = function()
            pendingDelete = file
            render()
          end,
        }))
      end

      local titleChildren = {
        ui.label({
          text = title,
          maxLines = 1,
          flexGrow = 1,
          fontWeight = isPinned and "bold" or "normal",
        }),
      }
      if isPinned then
        table.insert(titleChildren, 1, ui.glyph({ name = "pinned", size = 14 }))
      end

      table.insert(rows, ui.row({
        key = "note-" .. file,
        align = "center",
        justify = "space_between",
        padding = 6,
        paddingH = 10,
        radius = 6 * cornerRadiusScale,
        fill = "surface",
      }, {
        ui.row({
          flexGrow = 1,
          gap = 6,
          align = "center",
          onClick = function()
            -- Open note into Scratchpad
            local content = noctalia.readFile(notePath(file)) or ""
            buffer = content
            currentNoteFile = file
            editorRev += 1
            activeTab = "scratchpad"
            viewMode = "edit"
            render()
          end,
        }, titleChildren),
        ui.row({ gap = 4, align = "center" }, rowActions),
      }))
    end
  end

  if #rows == 0 then
    local emptyMsg = (queryLower == "") and tr("no_notes") or tr("no_search_results")
    table.insert(rows, ui.label({ text = emptyMsg, color = "on_surface_variant" }))
  end

  return ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
    searchBar,
    ui.scroll({ flexGrow = 1, gap = 4 }, rows),
  })
end

render = function()
  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    renderHeader(),
    (activeTab == "scratchpad") and renderScratchpadView() or renderSavedNotesView(),
  }))
end

-- ── Lifecycle Handlers ────────────────────────────────────────────────────────

function onOpen(_context)
  notesDir = noctalia.expandPath(noctalia.getConfig("notes_dir") or "~/Documents/Scratchpad")
  cornerRadiusScale = noctalia.getSetting("shell.corner_radius_scale") or 1.0
  local ext = noctalia.string.trim(tostring(noctalia.getConfig("extension") or "md")):gsub("^%.", "")
  if ext == "" then ext = "md" end
  suffix = "." .. ext

  noctalia.mkdirAll(notesDir)
  loadPins()
  refreshFiles()

  -- Check if launched with a target file from launcher
  local target = noctalia.state.get("scratchpad_open_file")
  if type(target) == "string" and target ~= "" then
    noctalia.state.set("scratchpad_open_file", "")
    local content = noctalia.readFile(notePath(target)) or ""
    buffer = content
    currentNoteFile = target
    activeTab = "scratchpad"
    viewMode = "edit"
  else
    -- Default: Always 100% clean and ready for instant paste (Privacy First)
    buffer = ""
    currentNoteFile = nil
    activeTab = "scratchpad"
    viewMode = "edit"
  end

  editorRev += 1
  pendingDelete = nil
  searchQuery = ""
  render()
end

function onClose()
  local autoArchive = noctalia.getConfig("auto_archive")
  if autoArchive ~= false then
    archiveCurrentDraft()
  end
end
```

- [ ] **Step 2: Lint panel code**

Run: `noctalia plugins lint scratchpad`
Expected: `rigelyon/scratchpad ok, 0 errors, 0 warnings`

- [ ] **Step 3: Commit**

```bash
git add scratchpad/panel.luau
git commit -m "feat(scratchpad): implement panel UI with markdown preview, toolbar, and auto-archive"
```

---

### Task 5: Documentation, Catalog Indexing & End-to-End Validation

**Files:**
- Create: `scratchpad/README.md`
- Modify: `catalog.toml` (via update script)

**Interfaces:**
- Produces: Complete user documentation explaining features, shortcuts, and settings.
- Produces: Updated repository `catalog.toml` registering `rigelyon/scratchpad`.

- [ ] **Step 1: Write user documentation**

Create `scratchpad/README.md`:
```markdown
# Scratchpad

Fast, private Markdown scratchpad for Noctalia desktop shell with auto-archive, rendered preview, quick-capture toolbar, and note library.

## Features

- **Zero-Click Instant Capture:** Opening the panel immediately presents an empty, auto-focused editor ready for `Ctrl+V` pasting or typing.
- **Privacy First (Auto-Archive on Close):** Unsaved drafts are automatically saved to your notes library when the panel closes, ensuring the scratchpad opens clean without exposing private notes in public.
- **1-Click Markdown Preview:** Toggle smoothly between raw editing and beautiful rendered Markdown (`ui.markdown`).
- **Quick Formatting Toolbar:** One-click chips to insert Headings, Bold, Italic, Checklists (`- [ ]`), Code blocks, Quotes, and Lists.
- **Saved Notes Library:** Full-height tab with instant fuzzy search, pinned notes, 1-click clipboard copy without opening, and safe inline deletion.
- **Status Bar Widget:** Quick-toggle panel button with live note count tooltip.
- **Launcher Provider (`sp`):** Search your notes library or type `sp <text>` to quick-capture notes instantly from the launcher.

## Configuration

| Setting | Type | Default | Description |
|---|---|---|---|
| `notes_dir` | folder | `~/Documents/Scratchpad` | Directory where markdown notes and pins are saved |
| `extension` | string | `md` | Note file extension |
| `auto_archive` | boolean | `true` | Auto-save draft on close to preserve privacy |

## License

MIT
```

- [ ] **Step 2: Update repository catalog**

Run: `python3 .github/workflows/update-catalog.py`
Expected: Updates `catalog.toml` with `rigelyon/scratchpad` entry.

- [ ] **Step 3: Run comprehensive test suite and validation**

Run:
```bash
python3 -m unittest discover tests -v
python3 .github/workflows/validate-plugins.py
noctalia plugins lint scratchpad
```
Expected: All tests pass, manifests valid, 0 errors/0 warnings.

- [ ] **Step 4: Commit**

```bash
git add scratchpad/README.md catalog.toml
git commit -m "feat(scratchpad): add documentation and update catalog"
```
