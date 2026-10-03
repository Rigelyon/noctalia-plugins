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

function export.notifyExport(fullPath: string, dir: string)
  local viewLabel = noctalia.tr("action_view")
  if viewLabel == "action_view" or viewLabel == "" then
    viewLabel = "View"
  end

  local folderLabel = noctalia.tr("action_open_folder")
  if folderLabel == "action_open_folder" or folderLabel == "" then
    folderLabel = "Open in Folder"
  end

  local deleteLabel = noctalia.tr("action_delete")
  if deleteLabel == "action_delete" or deleteLabel == "" then
    deleteLabel = "Delete"
  end

  local title = noctalia.tr("export_success_title")
  if title == "export_success_title" or title == "" then
    title = "Chat Exported"
  end

  local cmd = {
    "notify-send",
    "-a",
    "AI Sidebar",
    "-i",
    "document-save",
    "-A",
    "view=" .. viewLabel,
    "-A",
    "folder=" .. folderLabel,
    "-A",
    "delete=" .. deleteLabel,
    title,
    fullPath,
  }

  if not noctalia.runAsync then
    noctalia.notify(title, fullPath)
    return
  end

  noctalia.runAsync(cmd, function(result)
    if not result or not result.stdout then
      return
    end
    local rawAction = result.stdout
    local action = noctalia.string and noctalia.string.trim(rawAction) or rawAction:match("^%s*(.-)%s*$")
    if action == "view" then
      noctalia.runAsync({ "xdg-open", fullPath })
    elseif action == "folder" then
      noctalia.runAsync({ "xdg-open", dir })
    elseif action == "delete" then
      if noctalia.removeFile then
        noctalia.removeFile(fullPath)
      end
      local deletedMsg = noctalia.tr("export_deleted")
      if deletedMsg == "export_deleted" or deletedMsg == "" then
        deletedMsg = "Exported file deleted"
      end
      local appTitle = noctalia.tr("title")
      if appTitle == "title" or appTitle == "" then
        appTitle = "AI Sidebar"
      end
      noctalia.notify(appTitle, deletedMsg)
    end
  end)
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
    export.notifyExport(fullPath, dir)
    return true, fullPath
  end
  return false, err or "write_failed"
end

return export
