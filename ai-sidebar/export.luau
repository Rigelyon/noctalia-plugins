--!strict
local storage = require("./storage.luau")
local export = {}

function export.formatMarkdown(session: storage.Session): string
  local formattedDate = noctalia.formatTime("%Y-%m-%d %H:%M:%S", session.created_at)
  local escapedTitle = session.title:gsub('\\', '\\\\'):gsub('"', '\\"')

  local lines: { string } = {
    "---",
    'title: "' .. escapedTitle .. '"',
    'date: "' .. formattedDate .. '"',
    'provider: "' .. session.provider .. '"',
    'model: "' .. session.model .. '"',
    "---",
    "",
  }

  for _, msg in ipairs(session.messages) do
    local heading = msg.role == "user" and "### User" or (msg.role == "assistant" and "### Assistant" or "### System")
    table.insert(lines, heading)
    table.insert(lines, msg.content)
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

function export.generateFilename(title: string, timestamp: number): string
  local datePrefix = noctalia.formatTime("%Y%m%d", timestamp)
  local clean = title:gsub("[/\\%%:*?\"<>|]", " ")
  clean = clean:gsub("%s+", "-")
  clean = clean:gsub("^%-+", ""):gsub("%-+$", "")
  clean = noctalia.string.trim(clean)
  if clean == "" then
    clean = "conversation"
  end
  if #clean > 40 then
    clean = clean:sub(1, 40)
  end
  return datePrefix .. "_" .. clean .. "_" .. tostring(timestamp) .. ".md"
end

function export.getExportDir(): string
  local docsDir = noctalia.expandPath("~/Documents/ai-sidebar")
  local ok = noctalia.mkdirAll(docsDir)
  if ok then
    return docsDir
  end
  local fallback = (noctalia.pluginDataDir() or noctalia.expandPath("~/.local/share/noctalia/ai-sidebar")) .. "/exports"
  noctalia.mkdirAll(fallback)
  return fallback
end

function export.saveSession(session: storage.Session): (boolean, string)
  if #session.messages == 0 then
    return false, "empty_session"
  end

  local dir = export.getExportDir()
  local filename = export.generateFilename(session.title, session.created_at)
  local fullPath = dir .. "/" .. filename
  local content = export.formatMarkdown(session)

  local ok, err = noctalia.writeFile(fullPath, content)
  if ok then
    noctalia.notify(noctalia.tr("export_success_title"), fullPath)
    return true, fullPath
  end
  return false, err or "write_failed"
end

return export
