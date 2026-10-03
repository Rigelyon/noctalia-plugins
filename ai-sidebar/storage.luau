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
  system_prompt: string,
}

local function getDataDir(): string
  local dir, _ = noctalia.pluginDataDir()
  if not dir then
    dir = noctalia.expandPath("~/.local/share/noctalia/ai-sidebar")
  end
  noctalia.mkdirAll(dir)
  return dir
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
  firstLine = firstLine:gsub("^#+%s*", ""):gsub("[/%\\:*?\"<>|]", "")
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

function storage.loadConfig(): ConfigTable
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
    system_prompt = (noctalia.getConfig("system_prompt") or "You are a helpful and concise AI assistant.") :: string,
  }

  local raw = noctalia.readFile(configPath())
  if raw then
    local decoded, _ = noctalia.json.decode(raw)
    if type(decoded) == "table" then
      if type(decoded.active_provider) == "string" and decoded.active_provider ~= "" then
        cfg.active_provider = decoded.active_provider
      end
      if type(decoded.openai_key) == "string" then cfg.openai_key = decoded.openai_key end
      if type(decoded.openai_model) == "string" and decoded.openai_model ~= "" then cfg.openai_model = decoded.openai_model end
      if type(decoded.anthropic_key) == "string" then cfg.anthropic_key = decoded.anthropic_key end
      if type(decoded.anthropic_model) == "string" and decoded.anthropic_model ~= "" then cfg.anthropic_model = decoded.anthropic_model end
      if type(decoded.gemini_key) == "string" then cfg.gemini_key = decoded.gemini_key end
      if type(decoded.gemini_model) == "string" and decoded.gemini_model ~= "" then cfg.gemini_model = decoded.gemini_model end
      if type(decoded.system_prompt) == "string" and decoded.system_prompt ~= "" then cfg.system_prompt = decoded.system_prompt end
    end
  end
  return cfg
end

function storage.saveConfig(cfg: ConfigTable): boolean
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

return storage
