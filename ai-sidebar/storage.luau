--!strict
local storage = {}

export type Message = {
  role: string, -- "user" | "assistant" | "system"
  content: string,
  timestamp: number?,
}

export type Session = {
  id: string,
  title: string,
  created_at: number,
  updated_at: number,
  provider: string,
  model: string,
  messages: { Message },
}

export type ConfigTable = {
  active_provider: string,
  openai_key: string,
  openai_model: string,
  anthropic_key: string,
  anthropic_model: string,
  gemini_key: string,
  gemini_model: string,
  custom_base_url: string,
  custom_key: string,
  custom_model: string,
  system_prompt: string,
}

local function getDataDir(): string
  local dir = noctalia.pluginDataDir()
  if dir then
    noctalia.mkdirAll(dir)
    return dir
  end
  local fallback = noctalia.expandPath("~/.local/share/noctalia/ai-sidebar")
  noctalia.mkdirAll(fallback)
  return fallback
end

local function configPath(): string
  return getDataDir() .. "/config.json"
end

local function sessionsPath(): string
  return getDataDir() .. "/sessions.json"
end

function storage.generateTitle(firstMessage: string): string
  local trimmed = noctalia.string.trim(firstMessage or "")
  local firstLine = trimmed:match("^[^\r\n]+") or ""
  firstLine = firstLine:gsub("^#+%s*", ""):gsub("[/\\%%:*?\"<>|]", "")
  firstLine = firstLine:gsub("^%.+", "")
  firstLine = noctalia.string.trim(firstLine)
  if #firstLine == 0 then
    return "New Conversation"
  end
  if #firstLine > 40 then
    return firstLine:sub(1, 37) .. "..."
  end
  return firstLine
end

local function getSettingsTomlPath(): string
  local p = noctalia.expandPath("~/.local/state/noctalia/settings.toml")
  if noctalia.fileExists(p) then
    return p
  end
  local p2 = noctalia.expandPath("~/.config/noctalia/settings.toml")
  if noctalia.fileExists(p2) then
    return p2
  end
  return p
end

local function escapeTomlString(s: string?): string
  local val = s or ""
  local esc = val:gsub("\\", "\\\\")
                 :gsub('"', '\\"')
                 :gsub("\n", "\\n")
                 :gsub("\r", "\\r")
                 :gsub("\t", "\\t")
  return '"' .. esc .. '"'
end

function storage.syncToSettingsToml(cfg: ConfigTable): boolean
  local path = getSettingsTomlPath()
  local rawToml, _ = noctalia.readFile(path)
  if not rawToml then
    return false
  end

  local pluginKeys: { [string]: string } = {
    default_provider = escapeTomlString(cfg.active_provider),
    openai_api_key = escapeTomlString(cfg.openai_key),
    openai_model = escapeTomlString(cfg.openai_model),
    anthropic_api_key = escapeTomlString(cfg.anthropic_key),
    anthropic_model = escapeTomlString(cfg.anthropic_model),
    gemini_api_key = escapeTomlString(cfg.gemini_key),
    gemini_model = escapeTomlString(cfg.gemini_model),
    custom_base_url = escapeTomlString(cfg.custom_base_url),
    custom_api_key = escapeTomlString(cfg.custom_key),
    custom_model = escapeTomlString(cfg.custom_model),
    system_prompt = escapeTomlString(cfg.system_prompt),
  }

  local lines = {}
  for line in (rawToml .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    table.insert(lines, line)
  end

  local newLines = {}
  local inSection = false
  local sectionFound = false
  local handledKeys: { [string]: boolean } = {}

  for _, line in ipairs(lines) do
    local sec = line:match("^%s*%[%s*([^%]]+)%s*%]")
    if sec then
      if inSection then
        for k, v in pairs(pluginKeys) do
          if not handledKeys[k] then
            table.insert(newLines, k .. " = " .. v)
            handledKeys[k] = true
          end
        end
        inSection = false
      end
      if sec:match('^plugin_settings%s*%.%s*["\']rigelyon/ai%-sidebar["\']') then
        inSection = true
        sectionFound = true
        table.insert(newLines, line)
      else
        table.insert(newLines, line)
      end
    elseif inSection then
      local k = line:match("^%s*([%w_%-]+)%s*=")
      if k and pluginKeys[k] ~= nil then
        table.insert(newLines, k .. " = " .. pluginKeys[k])
        handledKeys[k] = true
      else
        table.insert(newLines, line)
      end
    else
      table.insert(newLines, line)
    end
  end

  if inSection then
    for k, v in pairs(pluginKeys) do
      if not handledKeys[k] then
        table.insert(newLines, k .. " = " .. v)
        handledKeys[k] = true
      end
    end
  end

  if not sectionFound then
    table.insert(newLines, "")
    table.insert(newLines, '[plugin_settings."rigelyon/ai-sidebar"]')
    for k, v in pairs(pluginKeys) do
      table.insert(newLines, k .. " = " .. v)
    end
  end

  local updated = table.concat(newLines, "\n")
  local ok, _ = noctalia.writeFile(path, updated)
  return ok
end

function storage.loadConfig(): ConfigTable
  local tomlPath = getSettingsTomlPath()
  local tomlInfo = noctalia.fileInfo(tomlPath)
  local jsonInfo = noctalia.fileInfo(configPath())

  local activeProv = (noctalia.getConfig("default_provider") or noctalia.getConfig("provider") or "openai") :: string
  local geminiKey = (noctalia.getConfig("gemini_api_key") or noctalia.getConfig("api_key") or "") :: string
  local geminiModel = (noctalia.getConfig("gemini_model") or noctalia.getConfig("default_model") or "gemini-1.5-flash") :: string

  local cfg: ConfigTable = {
    active_provider = activeProv,
    openai_key = (noctalia.getConfig("openai_api_key") or "") :: string,
    openai_model = (noctalia.getConfig("openai_model") or "gpt-4o-mini") :: string,
    anthropic_key = (noctalia.getConfig("anthropic_api_key") or "") :: string,
    anthropic_model = (noctalia.getConfig("anthropic_model") or "claude-3-5-haiku-20241022") :: string,
    gemini_key = geminiKey,
    gemini_model = geminiModel,
    custom_base_url = (noctalia.getConfig("custom_base_url") or "http://localhost:11434/v1") :: string,
    custom_key = (noctalia.getConfig("custom_api_key") or "") :: string,
    custom_model = (noctalia.getConfig("custom_model") or "llama3.2") :: string,
    system_prompt = (noctalia.getConfig("system_prompt") or "You are a helpful and concise AI assistant.") :: string,
  }

  local raw = noctalia.readFile(configPath())
  if raw then
    local decoded, _ = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      local preferToml = (tomlInfo ~= nil and jsonInfo ~= nil and tomlInfo.mtime > jsonInfo.mtime)

      if not preferToml then
        if type(decoded.active_provider) == "string" and decoded.active_provider ~= "" then
          cfg.active_provider = decoded.active_provider
        end
        if type(decoded.openai_key) == "string" then cfg.openai_key = decoded.openai_key end
        if type(decoded.openai_model) == "string" and decoded.openai_model ~= "" then cfg.openai_model = decoded.openai_model end
        if type(decoded.anthropic_key) == "string" then cfg.anthropic_key = decoded.anthropic_key end
        if type(decoded.anthropic_model) == "string" and decoded.anthropic_model ~= "" then cfg.anthropic_model = decoded.anthropic_model end
        if type(decoded.gemini_key) == "string" then cfg.gemini_key = decoded.gemini_key end
        if type(decoded.gemini_model) == "string" and decoded.gemini_model ~= "" then cfg.gemini_model = decoded.gemini_model end
        if type(decoded.custom_base_url) == "string" and decoded.custom_base_url ~= "" then cfg.custom_base_url = decoded.custom_base_url end
        if type(decoded.custom_key) == "string" then cfg.custom_key = decoded.custom_key end
        if type(decoded.custom_model) == "string" and decoded.custom_model ~= "" then cfg.custom_model = decoded.custom_model end
        if type(decoded.system_prompt) == "string" and decoded.system_prompt ~= "" then cfg.system_prompt = decoded.system_prompt end
      else
        if cfg.openai_key == "" and type(decoded.openai_key) == "string" then cfg.openai_key = decoded.openai_key end
        if cfg.anthropic_key == "" and type(decoded.anthropic_key) == "string" then cfg.anthropic_key = decoded.anthropic_key end
        if cfg.gemini_key == "" and type(decoded.gemini_key) == "string" then cfg.gemini_key = decoded.gemini_key end
        if cfg.custom_key == "" and type(decoded.custom_key) == "string" then cfg.custom_key = decoded.custom_key end
        if cfg.system_prompt == "You are a helpful and concise AI assistant." and type(decoded.system_prompt) == "string" and decoded.system_prompt ~= "" then
          cfg.system_prompt = decoded.system_prompt
        end
      end
    end
  end
  return cfg
end

function storage.saveConfig(cfg: ConfigTable): boolean
  pcall(function()
    storage.syncToSettingsToml(cfg)
  end)

  local encoded, _ = noctalia.json.encode(cfg, true)
  if encoded then
    local ok, _ = noctalia.writeFile(configPath(), encoded)
    return ok
  end
  return false
end

function storage.loadSessions(): { Session }
  local sessions: { Session } = {}
  local raw = noctalia.readFile(sessionsPath())
  if raw then
    local decoded, _ = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      for _, item in ipairs(decoded) do
        if type(item) == "table" and type(item.id) == "string" then
          table.insert(sessions, {
            id = item.id,
            title = type(item.title) == "string" and item.title or "Conversation",
            created_at = type(item.created_at) == "number" and item.created_at or 0,
            updated_at = type(item.updated_at) == "number" and item.updated_at or 0,
            provider = type(item.provider) == "string" and item.provider or "openai",
            model = type(item.model) == "string" and item.model or "",
            messages = type(item.messages) == "table" and item.messages or {},
          })
        end
      end
    end
  end

  table.sort(sessions, function(a, b)
    return a.updated_at > b.updated_at
  end)
  return sessions
end

function storage.saveSessions(sessions: { Session }): boolean
  local encoded, _ = noctalia.json.encode(sessions, true)
  if encoded then
    local ok, _ = noctalia.writeFile(sessionsPath(), encoded)
    return ok
  end
  return false
end

function storage.createSession(initialPrompt: string?, provider: string?, model: string?): Session
  local nowSec = math.floor(noctalia.nowMs() / 1000)
  local title = initialPrompt and storage.generateTitle(initialPrompt) or "New Conversation"
  return {
    id = "sess_" .. tostring(noctalia.nowMs()),
    title = title,
    created_at = nowSec,
    updated_at = nowSec,
    provider = provider or "openai",
    model = model or "gpt-4o-mini",
    messages = {},
  }
end

function storage.deleteSession(sessionId: string, sessions: { Session }): { Session }
  local updated: { Session } = {}
  for _, sess in ipairs(sessions) do
    if sess.id ~= sessionId then
      table.insert(updated, sess)
    end
  end
  storage.saveSessions(updated)
  return updated
end

-- Sliding window for context: retain only the last maxCount (default 20) messages for API payload
function storage.capMessages(messages: { Message }, maxCount: number?): { Message }
  local limit = maxCount or 20
  local capped: { Message } = {}

  if #messages <= limit then
    for _, m in ipairs(messages) do
      table.insert(capped, m)
    end
  else
    local startIdx = #messages - limit + 1
    for i = startIdx, #messages do
      table.insert(capped, messages[i])
    end
  end

  -- Ensure context window always starts with a user message for provider schema compatibility
  while #capped > 0 and capped[1].role ~= "user" do
    table.remove(capped, 1)
  end

  return capped
end

function storage.rewindSession(sessions: { Session }, sessionId: string, targetIndex: number): boolean
  for _, s in ipairs(sessions) do
    if s.id == sessionId then
      local idx = targetIndex
      if idx < 0 then
        idx = 0
      end
      if idx > #s.messages then
        idx = #s.messages
      end

      local truncated: { Message } = {}
      for i = 1, idx do
        table.insert(truncated, s.messages[i])
      end
      s.messages = truncated
      s.updated_at = math.floor(noctalia.nowMs() / 1000)
      storage.saveSessions(sessions)
      return true
    end
  end
  return false
end

function storage.removeLastAssistantMessage(sessions: { Session }, sessionId: string): boolean
  for _, s in ipairs(sessions) do
    if s.id == sessionId then
      if #s.messages > 0 and s.messages[#s.messages].role == "assistant" then
        table.remove(s.messages, #s.messages)
        s.updated_at = math.floor(noctalia.nowMs() / 1000)
        storage.saveSessions(sessions)
        return true
      end
      return false
    end
  end
  return false
end

return storage
