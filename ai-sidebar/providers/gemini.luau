--!strict
local gemini = {}

type Message = { role: string, content: string }

function gemini.buildChatRequest(messages: { Message }, systemPrompt: string, config: any): any
  local contents = {}
  for _, m in ipairs(messages) do
    local gRole = (m.role == "assistant") and "model" or "user"
    table.insert(contents, {
      role = gRole,
      parts = { { text = m.content } },
    })
  end

  local bodyObj: { [string]: any } = {
    contents = contents,
  }
  if systemPrompt and systemPrompt ~= "" then
    bodyObj.system_instruction = {
      parts = { { text = systemPrompt } },
    }
  end

  if config and config.enable_web_search == true and config.search_engine == "gemini_native" then
    bodyObj.tools = {
      { googleSearch = {} }
    }
  end

  local encoded, _ = noctalia.json.encode(bodyObj)
  local model = (config and config.gemini_model and config.gemini_model ~= "") and config.gemini_model or "gemini-1.5-flash"
  local apiKey = config and config.gemini_key or ""
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":streamGenerateContent?alt=sse&key=" .. apiKey

  return {
    url = url,
    method = "POST",
    headers = {
      "Content-Type: application/json",
    },
    body = encoded or "{}",
  }
end

function gemini.buildTestRequest(config: any): any
  local bodyObj = {
    contents = {
      { role = "user", parts = { { text = "ping" } } },
    },
  }
  local encoded, _ = noctalia.json.encode(bodyObj)
  local model = (config and config.gemini_model and config.gemini_model ~= "") and config.gemini_model or "gemini-1.5-flash"
  local apiKey = config and config.gemini_key or ""
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. apiKey

  return {
    url = url,
    method = "POST",
    headers = {
      "Content-Type: application/json",
    },
    body = encoded or "{}",
  }
end

function gemini.parseStreamLine(line: string): string?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) == "table" and type(decoded.candidates) == "table" then
    local cand = decoded.candidates[1]
    if type(cand) == "table" and type(cand.content) == "table" and type(cand.content.parts) == "table" then
      local part = cand.content.parts[1]
      if type(part) == "table" and type(part.text) == "string" then
        return part.text
      end
    end
  end
  return nil
end

function gemini.parseTestResponse(response: any): (boolean, string)
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

return gemini
