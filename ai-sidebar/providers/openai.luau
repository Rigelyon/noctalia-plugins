--!strict
local openai = {}

type Message = { role: string, content: string }

function openai.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local apiMessages = {}
  if systemPrompt and systemPrompt ~= "" then
    table.insert(apiMessages, { role = "system", content = systemPrompt })
  end
  for _, m in ipairs(messages) do
    table.insert(apiMessages, { role = m.role, content = m.content })
  end

  local bodyObj = {
    model = (config and config.openai_model and config.openai_model ~= "") and config.openai_model or "gpt-4o-mini",
    messages = apiMessages,
    stream = true,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.openai.com/v1/chat/completions",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "Authorization: Bearer " .. (config and config.openai_key or ""),
    },
    body = encoded or "{}",
  }
end

function openai.buildTestRequest(config: any): any
  local bodyObj = {
    model = (config and config.openai_model and config.openai_model ~= "") and config.openai_model or "gpt-4o-mini",
    messages = { { role = "user", content = "ping" } },
    max_tokens = 5,
    stream = false,
  }
  local encoded, _ = noctalia.json.encode(bodyObj)

  return {
    url = "https://api.openai.com/v1/chat/completions",
    method = "POST",
    headers = {
      "Content-Type: application/json",
      "Authorization: Bearer " .. (config and config.openai_key or ""),
    },
    body = encoded or "{}",
  }
end

function openai.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end
  if trimmed:match("^data:%s*%[DONE%]") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.choices) == "table" then
    local choice = decoded.choices[1]
    if type(choice) == "table" and type(choice.delta) == "table" and type(choice.delta.content) == "string" then
      return choice.delta.content
    end
  end
  return nil
end

function openai.parseTestResponse(response: any): (boolean, string)
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

return openai
