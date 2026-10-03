--!strict
local custom = {}

type Message = { role: string, content: string }

local function normalizeUrl(baseUrl: string?, endpoint: string): string
  local trimmed = (baseUrl and baseUrl ~= "") and noctalia.string.trim(baseUrl) or "http://localhost:11434/v1"
  -- Strip trailing slashes
  while trimmed:sub(-1) == "/" do
    trimmed = trimmed:sub(1, #trimmed - 1)
  end
  -- If endpoint is /chat/completions, ensure baseUrl ends with /v1 unless explicitly versioned
  if not trimmed:find("/v%d+$") and not trimmed:find("/v%d+%.%d+$") then
    trimmed = trimmed .. "/v1"
  end
  return trimmed .. endpoint
end

custom.normalizeUrl = normalizeUrl

function custom.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local formattedMessages = {}
  if systemPrompt and systemPrompt ~= "" then
    table.insert(formattedMessages, {
      role = "system",
      content = systemPrompt,
    })
  end

  for _, m in ipairs(messages) do
    table.insert(formattedMessages, {
      role = m.role,
      content = m.content,
    })
  end

  local model = (config and config.custom_model and config.custom_model ~= "") and config.custom_model or "llama3.2"
  local bodyObj = {
    model = model,
    messages = formattedMessages,
    stream = true,
  }

  local encoded, _ = noctalia.json.encode(bodyObj)
  local baseUrl = config and config.custom_base_url or "http://localhost:11434/v1"
  local url = normalizeUrl(baseUrl, "/chat/completions")

  local headers = {
    "Content-Type: application/json",
  }
  if config and config.custom_key and noctalia.string.trim(config.custom_key) ~= "" then
    table.insert(headers, "Authorization: Bearer " .. noctalia.string.trim(config.custom_key))
  end

  return {
    url = url,
    method = "POST",
    headers = headers,
    body = encoded or "{}",
  }
end

function custom.buildTestRequest(config: any): any
  local model = (config and config.custom_model and config.custom_model ~= "") and config.custom_model or "llama3.2"
  local bodyObj = {
    model = model,
    messages = {
      { role = "user", content = "ping" },
    },
    stream = false,
  }

  local encoded, _ = noctalia.json.encode(bodyObj)
  local baseUrl = config and config.custom_base_url or "http://localhost:11434/v1"
  local url = normalizeUrl(baseUrl, "/chat/completions")

  local headers = {
    "Content-Type: application/json",
  }
  if config and config.custom_key and noctalia.string.trim(config.custom_key) ~= "" then
    table.insert(headers, "Authorization: Bearer " .. noctalia.string.trim(config.custom_key))
  end

  return {
    url = url,
    method = "POST",
    headers = headers,
    body = encoded or "{}",
  }
end

function custom.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  if jsonStr == "[DONE]" then return nil end

  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.choices) == "table" then
    local choice = decoded.choices[1]
    if type(choice) == "table" and type(choice.delta) == "table" and type(choice.delta.content) == "string" then
      return choice.delta.content
    end
  end
  return nil
end

function custom.parseTestResponse(response: any): (boolean, string)
  if not response.ok then
    return false, "Network error (transport failure)"
  end
  if response.status == 200 then
    return true, "Connection successful"
  end
  local msg = "HTTP " .. tostring(response.status)
  local decoded, _ = noctalia.json.decode(response.body)
  if type(decoded) == "table" and type(decoded.error) == "table" and type(decoded.error.message) == "string" then
    msg = msg .. ": " .. decoded.error.message
  elseif type(decoded) == "table" and type(decoded.message) == "string" then
    msg = msg .. ": " .. decoded.message
  end
  return false, msg
end

return custom
