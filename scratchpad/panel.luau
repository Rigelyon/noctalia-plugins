--!nonstrict
-- Scratchpad panel with Markdown preview, quick formatting toolbar,
-- auto-archive on close for maximum privacy, and a saved notes library.

local activeTab = "scratchpad" -- "scratchpad" | "saved_notes"
local viewMode = "edit"       -- "edit" | "preview"
local buffer = ""
local currentNoteFile = nil   -- filename when viewing/editing an existing note from library
local searchQuery = ""
local pendingDelete = nil     -- filename awaiting confirmation
local pendingClear = nil      -- boolean awaiting clear confirmation
local noteContentCache = {}   -- filename -> content
local lastBump = nil
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

local function getNoteContent(file: string): string
  local cached = noteContentCache[file]
  if cached ~= nil then
    return cached
  end
  local content = noctalia.readFile(notePath(file)) or ""
  noteContentCache[file] = content
  return content
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
  firstLine = firstLine:gsub("^%.+", "")
  firstLine = noctalia.string.trim(firstLine)
  firstLine = firstLine:gsub("^%.+", "")
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
  noteContentCache = {}
  noctalia.state.set("scratchpad_bump", noctalia.nowMs())
  refreshFiles()
end

local function insertMarkdownSyntax(prefix: string, postfix: string?)
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
        pendingClear = nil
        render()
      end,
    }),
    ui.button({
      text = tr("tab_saved_notes") .. " (" .. tostring(#files) .. ")",
      variant = activeTab == "saved_notes" and "primary" or "ghost",
      onClick = function()
        activeTab = "saved_notes"
        pendingDelete = nil
        pendingClear = nil
        refreshFiles()
        render()
      end,
    }),
  })

  local actions = {}
  if activeTab == "scratchpad" then
    if pendingClear then
      table.insert(actions, ui.label({ text = tr("clear_confirm"), color = "error" }))
      table.insert(actions, ui.button({
        glyph = "check",
        variant = "primary",
        onClick = function()
          buffer = ""
          currentNoteFile = nil
          editorRev += 1
          pendingClear = nil
          render()
        end,
      }))
      table.insert(actions, ui.button({
        glyph = "x",
        variant = "ghost",
        onClick = function()
          pendingClear = nil
          render()
        end,
      }))
    else
      -- View Toggle (Split View or Full Preview based on split_view setting)
      local isSplitSetting = (noctalia.getConfig("split_view") ~= false)
      local isViewActive = (viewMode == "preview" or viewMode == "split")
      local viewGlyph = isViewActive and "edit" or (isSplitSetting and "layout-rows" or "eye")
      local viewTooltip = isViewActive and tr("toggle_edit") or (isSplitSetting and tr("toggle_split") or tr("toggle_preview"))

      table.insert(actions, ui.button({
        glyph = viewGlyph,
        variant = isViewActive and "primary" or "ghost",
        tooltip = viewTooltip,
        onClick = function()
          if isViewActive then
            viewMode = "edit"
          else
            viewMode = isSplitSetting and "split" or "preview"
          end
          render()
        end,
      }))
      -- Copy All
      table.insert(actions, ui.button({
        glyph = "copy",
        variant = "ghost",
        tooltip = tr("copy_all"),
        onClick = function()
          if #buffer > 0 then
            noctalia.copyToClipboard(buffer, "text/plain;charset=utf-8")
            noctalia.notify(tr("title"), tr("copied_all"))
          end
        end,
      }))
      -- Save Note
      table.insert(actions, ui.button({
        glyph = "device-floppy",
        variant = "ghost",
        tooltip = tr("archive_note"),
        onClick = function()
          archiveCurrentDraft()
          render()
        end,
      }))
      -- Clear
      table.insert(actions, ui.button({
        glyph = "eraser",
        variant = "ghost",
        tooltip = tr("clear"),
        onClick = function()
          pendingClear = true
          render()
        end,
      }))
    end
  end

  table.insert(actions, ui.button({
    glyph = "x",
    variant = "ghost",
    tooltip = tr("close"),
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
      tooltip = tr("toolbar_heading"),
      onClick = function() insertMarkdownSyntax("\n# ") end,
    }),
    ui.button({
      text = "B",
      variant = "ghost",
      tooltip = tr("toolbar_bold"),
      onClick = function() insertMarkdownSyntax("**bold**") end,
    }),
    ui.button({
      text = "I",
      variant = "ghost",
      tooltip = tr("toolbar_italic"),
      onClick = function() insertMarkdownSyntax("*italic*") end,
    }),
    ui.button({
      text = "[✓]",
      variant = "ghost",
      tooltip = tr("toolbar_task"),
      onClick = function() insertMarkdownSyntax("\n- [ ] ") end,
    }),
    ui.button({
      text = "</>",
      variant = "ghost",
      tooltip = tr("toolbar_code"),
      onClick = function() insertMarkdownSyntax("\n```\n", "\n```\n") end,
    }),
    ui.button({
      text = ">",
      variant = "ghost",
      tooltip = tr("toolbar_quote"),
      onClick = function() insertMarkdownSyntax("\n> ") end,
    }),
    ui.button({
      text = "•",
      variant = "ghost",
      tooltip = tr("toolbar_bullet"),
      onClick = function() insertMarkdownSyntax("\n- ") end,
    }),
  })
end

local function renderScratchpadView()
  local words = select(2, buffer:gsub("%S+", ""))
  local chars = utf8.len(buffer) or #buffer
  local statusLine = tr("ready") .. "  ·  " .. tr("status_counts", { words = words, chars = chars })

  local mainContent
  if viewMode == "split" then
    local editorBox = ui.input({
      key = "editor-" .. editorRev,
      value = buffer,
      multiline = true,
      focus = true,
      flexGrow = 1,
      placeholder = tr("editor_placeholder"),
      onChange = function(val)
        buffer = val
        -- Re-render live preview on edit in split view
        render()
      end,
    })

    local previewBox = ui.column({
      flexGrow = 1,
      gap = 4,
      align = "stretch",
    }, {
      ui.label({
        text = tr("preview_section"),
        fontSize = 11,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
      ui.scroll({
        flexGrow = 1,
        padding = 8,
        fill = "surface",
        radius = 6 * cornerRadiusScale,
      }, {
        ui.markdown({ text = buffer ~= "" and buffer or "*Empty draft*" }),
      }),
    })

    mainContent = ui.column({ flexGrow = 1, gap = 6, align = "stretch" }, {
      editorBox,
      ui.separator({}),
      previewBox,
    })
  elseif viewMode == "preview" then
    mainContent = ui.scroll({
      flexGrow = 1,
      padding = 8,
      fill = "surface",
      radius = 6 * cornerRadiusScale,
      onClick = function()
        viewMode = "edit"
        render()
      end,
    }, {
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
  local currentBump = noctalia.state.get("scratchpad_bump")
  if currentBump ~= lastBump then
    lastBump = currentBump
    noteContentCache = {}
  end

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
        local raw = getNoteContent(file)
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
          tooltip = tr("confirm_delete"),
          onClick = function()
            noctalia.removeFile(notePath(file))
            if pins[file] then
              pins[file] = nil
              savePins()
            end
            if currentNoteFile == file then
              currentNoteFile = nil
              buffer = ""
              editorRev += 1
            end
            noteContentCache = {}
            pendingDelete = nil
            noctalia.state.set("scratchpad_bump", noctalia.nowMs())
            refreshFiles()
            render()
          end,
        }))
        table.insert(rowActions, ui.button({
          glyph = "x",
          variant = "ghost",
          tooltip = tr("close"),
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
          tooltip = tr("copy_note"),
          onClick = function()
            local content = getNoteContent(file)
            noctalia.copyToClipboard(content, "text/plain;charset=utf-8")
            noctalia.notify(tr("title"), tr("copied_note"))
          end,
        }))
        -- Pin / Unpin
        table.insert(rowActions, ui.button({
          glyph = isPinned and "pinned-off" or "pin",
          variant = "ghost",
          tooltip = isPinned and tr("unpin") or tr("pin"),
          onClick = function()
            pins[file] = not pins[file] and true or nil
            savePins()
            noctalia.state.set("scratchpad_bump", noctalia.nowMs())
            refreshFiles()
            render()
          end,
        }))
        -- Delete
        table.insert(rowActions, ui.button({
          glyph = "trash",
          variant = "ghost",
          tooltip = tr("delete_note"),
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
            -- Protect active scratchpad draft before loading selected note
            if #noctalia.string.trim(buffer) > 0 and currentNoteFile == nil then
              archiveCurrentDraft()
            end
            -- Open note into Scratchpad
            local content = getNoteContent(file)
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

  noteContentCache = {}
  noctalia.mkdirAll(notesDir)
  loadPins()
  refreshFiles()

  local defaultView = (noctalia.getConfig("split_view") == true) and "split" or "edit"

  -- Check if launched with a target file from launcher
  local target = noctalia.state.get("scratchpad_open_file")
  if type(target) == "string" and target ~= "" then
    noctalia.state.set("scratchpad_open_file", "")
    local content = getNoteContent(target)
    buffer = content
    currentNoteFile = target
    activeTab = "scratchpad"
    viewMode = defaultView
  else
    -- Default: Always 100% clean and ready for instant paste (Privacy First)
    buffer = ""
    currentNoteFile = nil
    activeTab = "scratchpad"
    viewMode = defaultView
  end

  editorRev += 1
  pendingDelete = nil
  pendingClear = nil
  searchQuery = ""
  render()
end

function onClose()
  local autoArchive = noctalia.getConfig("auto_archive")
  if autoArchive ~= false then
    archiveCurrentDraft()
  end
end
