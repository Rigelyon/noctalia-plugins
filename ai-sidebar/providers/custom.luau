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
  local bodyObj: { [string]: any } = {
    model = model,
    messages = formattedMessages,
    stream = true,
  }

  if config and config.enable_web_search == true and config._disable_tools ~= true then
    bodyObj.tools = {
      {
        type = "function",
        ["function"] = {
          name = "web_search",
          description = "Search the live web for real-time information, recent events, facts, documentation, or queries needing current data.",
          parameters = {
            type = "object",
            properties = {
              query = {
                type = "string",
                description = "The targeted search keywords to query the search engine.",
              },
            },
            required = { "query" },
          },
        },
      },
    }
  end

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

export type StreamEvent = {
  type: "content" | "reasoning" | "tool_call" | "done",
  text: string?,
  toolCalls: { any }?,
}

function custom.parseStreamEvent(line: string, state: any?): StreamEvent?
  local trimmed = noctalia.string.trim(line)
  if not trimmed:match("^data:%s*") then return nil end

  local jsonStr = trimmed:gsub("^data:%s*", "")
  if jsonStr == "[DONE]" then
    return { type = "done" }
  end

  local decoded, _ = noctalia.json.decode(jsonStr)
  if type(decoded) ~= "table" or type(decoded.choices) ~= "table" then
    return nil
  end

  local choice = decoded.choices[1]
  if type(choice) ~= "table" then return nil end

  local delta = choice.delta
  if type(delta) ~= "table" then return nil end

  -- 1. Check for dedicated reasoning_content or reasoning (DeepSeek-R1 / Ollama / vLLM / OpenRouter)
  if type(delta.reasoning_content) == "string" and delta.reasoning_content ~= "" then
    return { type = "reasoning", text = delta.reasoning_content }
  elseif type(delta.reasoning) == "string" and delta.reasoning ~= "" then
    return { type = "reasoning", text = delta.reasoning }
  end

  -- 2. Check for tool_calls
  if type(delta.tool_calls) == "table" and #delta.tool_calls > 0 then
    return { type = "tool_call", toolCalls = delta.tool_calls }
  end

  -- 3. Check for content (with inline <think> state machine handling)
  if type(choice.delta.content) == "string" and choice.delta.content ~= "" then
    local contentText = choice.delta.content
    local inThink = state and (state.inThink == true) or false

    if inThink then
      local closeTagStart, closeTagEnd = contentText:find("</think>")
      if closeTagStart and closeTagEnd then
        if state then state.inThink = false end
        local rText = contentText:sub(1, closeTagStart - 1)
        local cText = contentText:sub(closeTagEnd + 1)
        if rText ~= "" then
          return { type = "reasoning", text = rText }
        elseif cText ~= "" then
          return { type = "content", text = cText }
        end
        return nil
      else
        return { type = "reasoning", text = contentText }
      end
    else
      local openTagStart, openTagEnd = contentText:find("<think>")
      if openTagStart and openTagEnd then
        if state then state.inThink = true end
        local afterOpen = contentText:sub(openTagEnd + 1)
        local closeTagStart, closeTagEnd = afterOpen:find("</think>")
        if closeTagStart and closeTagEnd then
          if state then state.inThink = false end
          local rText = afterOpen:sub(1, closeTagStart - 1)
          if rText ~= "" then
            return { type = "reasoning", text = rText }
          end
          local cText = afterOpen:sub(closeTagEnd + 1)
          if cText ~= "" then
            return { type = "content", text = cText }
          end
          return nil
        else
          if afterOpen ~= "" then
            return { type = "reasoning", text = afterOpen }
          end
          return nil
        end
      else
        return { type = "content", text = contentText }
      end
    end
  end

  return nil
end

function custom.parseStreamLine(line: string): string?
  local ev = custom.parseStreamEvent(line, nil)
  if ev and ev.type == "content" then
    return ev.text
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
