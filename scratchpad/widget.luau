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
