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
            local cLower = contents:lower()
            if not cLower:find(qLower, 1, true) then
              local anyTokenMatch = false
              for token in qLower:gmatch("%S+") do
                if tLower:find(token, 1, true) or cLower:find(token, 1, true) then
                  anyTokenMatch = true
                  break
                end
              end
              if not anyTokenMatch then
                matched = false
              end
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
