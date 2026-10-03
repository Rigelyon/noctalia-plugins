--!strict
local anthropic = {}

type Message = { role: string, content: string }

function anthropic.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local apiMessages = {}
  for _, m in ipairs(messages) do
    if m.role == "user" or m.role == "assistant" then
      table.insert(apiMessages, { role = m.role, content = m.content })
    end
  end

  local bodyObj: { [string]: any } = {
    model = (config and config.anthropic_model and config.anthropic_model ~= "") and config.anthropic_model or "claude-3-5-haiku-20241022",
    messages = apiMessages,
    max_tokens = 4096,
    stream = true,
  }
  if systemPrompt and systemPrompt ~= "" then
    bodyObj.system = systemPrompt
  end
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.anthropic.com/v1/messages",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "x-api-key: " .. (config and config.anthropic_key or ""),
      "anthropic-version: 2023-06-01",
    },
    body = encoded or "{}",
  }
end

function anthropic.buildTestRequest(config: any): any
  local bodyObj = {
    model = (config and config.anthropic_model and config.anthropic_model ~= "") and config.anthropic_model or "claude-3-5-haiku-20241022",
    messages = { { role = "user", content = "ping" } },
    max_tokens = 5,
    stream = false,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.anthropic.com/v1/messages",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "x-api-key: " .. (config and config.anthropic_key or ""),
      "anthropic-version: 2023-06-01",
    },
    body = encoded or "{}",
  }
end

function anthropic.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and decoded.type == "content_block_delta" then
    if type(decoded.delta) == "table" and type(decoded.delta.text) == "string" then
      return decoded.delta.text
    end
  end
  return nil
end

function anthropic.parseTestResponse(response: any): (boolean, string)
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
  end
  return false, msg
end

return anthropic
