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

  local bodyObj: { [string]: any } = {
    model = (config and config.openai_model and config.openai_model ~= "") and config.openai_model or "gpt-4o-mini",
    messages = apiMessages,
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

export type StreamEvent = {
  type: "content" | "reasoning" | "tool_call" | "done",
  text: string?,
  toolCalls: { any }?,
}

function openai.parseStreamEvent(line: string, state: any?): StreamEvent?
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

  -- 1. Check for dedicated reasoning_content or reasoning (o1/o3-mini / deepseek)
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

function openai.parseStreamLine(line: string): string?
  local ev = openai.parseStreamEvent(line, nil)
  if ev and ev.type == "content" then
    return ev.text
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
