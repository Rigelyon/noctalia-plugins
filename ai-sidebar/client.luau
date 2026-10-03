--!strict
local openai = require("./providers/openai.luau")
local anthropic = require("./providers/anthropic.luau")
local gemini = require("./providers/gemini.luau")
local custom = require("./providers/custom.luau")
local context = require("./context.luau")
local search = require("./search.luau")

local client = {}

local function getProvider(name: string): any
  if name == "anthropic" then
    return anthropic
  elseif name == "gemini" then
    return gemini
  elseif name == "custom" then
    return custom
  else
    return openai
  end
end

local function buildEnvironmentPrompt(baseSystemPrompt: string?, searchContext: string?, webSearchEnabled: boolean?): string
  local timeStr = noctalia.formatTime("%Y-%m-%d %H:%M:%S")
  local envInfo = "\n\n[Environment Context: Current system time is " .. timeStr .. ", running on Noctalia Hyprland Shell inside custom Bazzite-DX image.]"
  local base = (baseSystemPrompt and baseSystemPrompt ~= "") and baseSystemPrompt or "You are a helpful and concise AI assistant."
  local prompt = base .. envInfo

  if webSearchEnabled == true then
    prompt = prompt .. "\n\n[Web Search Capability: Active and enabled. You have access to real-time web search. When asked if you can search the web or browse the internet, confirm that you have web search enabled.]"
  end

  if searchContext and searchContext ~= "" then
    prompt = prompt .. "\n\n" .. searchContext
  end
  return prompt
end

function client.prepareSearchContext(query: string, config: any, callback: (searchContext: string?) -> ()): ()
  if not (config and config.enable_web_search == true) then
    callback(nil)
    return
  end

  if config.active_provider == "gemini" and config.search_engine == "gemini_native" then
    -- Native grounding handles retrieval directly
    callback(nil)
    return
  end

  search.performSearch(query, config, function(ok, contextBlock, _err)
    if ok and contextBlock and contextBlock ~= "" then
      callback(contextBlock)
    else
      callback(nil)
    end
  end)
end

function client.testConnection(providerName: string, config: any, callback: (ok: boolean, msg: string) -> ())
  local prov = getProvider(providerName)
  local req = prov.buildTestRequest(config)
  local started = noctalia.http(req, function(resp)
    local ok, msg = prov.parseTestResponse(resp)
    callback(ok, msg)
  end)

  if not started then
    callback(false, "Failed to start HTTP request (check network or offline mode)")
  end
end

function client.streamChat(
  messages: { any },
  config: any,
  onChunk: (text: string) -> (),
  onError: (err: string) -> (),
  onDone: () -> (),
  onStatus: ((status: string, attempt: number, maxRetries: number) -> ())?,
  searchContext: string?
): any
  local prov = getProvider(config.active_provider)
  local isWebSearchActive = config and config.enable_web_search == true
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt, searchContext, isWebSearchActive)
  
  -- Prepare rolling context to prevent token overflows and context amnesia
  local contextMessages = context.prepareContext(messages, context.BUDGET_TOKENS or 4096, augmentedPrompt)
  local req = prov.buildChatRequest(contextMessages, augmentedPrompt, config)

  local hasReceivedChunk = false
  local errorReported = false
  local retryCount = 0
  local maxRetries = 2
  local isCancelled = false
  local currentHandle: any = nil

  local function startAttempt()
    if isCancelled then return end

    currentHandle = noctalia.httpStream(req, function(line: string)
      if isCancelled then return end
      local text = prov.parseStreamLine(line)
      if text and text ~= "" then
        hasReceivedChunk = true
        onChunk(text)
      end
    end, function(result: any)
      if isCancelled then return end
      local isError = not result.ok or (result.status ~= 0 and result.status >= 400)
      local isRetryable = isError and (result.status == 429 or result.status == 503 or result.status == 0)

      if isRetryable and not hasReceivedChunk and retryCount < maxRetries then
        retryCount += 1
        if onStatus then
          onStatus("retrying", retryCount, maxRetries)
        end
        local delaySec = retryCount == 1 and "1" or "2"
        noctalia.runAsync({ "sleep", delaySec }, function()
          if not isCancelled then
            startAttempt()
          end
        end)
        return
      end

      if isError then
        if not errorReported then
          errorReported = true
          onError("Stream error (HTTP " .. tostring(result.status) .. ")")
        end
      else
        if not hasReceivedChunk and not errorReported then
          onError("No response data received from provider")
        else
          onDone()
        end
      end
    end)

    if currentHandle == nil and not errorReported then
      if retryCount < maxRetries then
        retryCount += 1
        if onStatus then
          onStatus("retrying", retryCount, maxRetries)
        end
        local delaySec = retryCount == 1 and "1" or "2"
        noctalia.runAsync({ "sleep", delaySec }, function()
          if not isCancelled then
            startAttempt()
          end
        end)
      else
        onError("Unable to initialize HTTP stream (offline mode or network disabled)")
      end
    end
  end

  startAttempt()

  return {
    stop = function()
      isCancelled = true
      errorReported = true
      if currentHandle and currentHandle.stop then
        currentHandle.stop()
      end
    end,
    cancel = function()
      isCancelled = true
      errorReported = true
      if currentHandle and currentHandle.stop then
        currentHandle.stop()
      end
    end,
  }
end

function client.generateTitle(
  userPrompt: string,
  assistantReply: string,
  config: any,
  onSuccess: (title: string) -> ()
): ()
  local titlerMessages = {
    {
      role = "system",
      content = "You are a conversation summarizer. Summarize this conversation in a concise 3-5 word title. Return ONLY the title text, no quotes, no markdown, no punctuation.",
    },
    {
      role = "user",
      content = userPrompt:sub(1, 300),
    },
    {
      role = "assistant",
      content = assistantReply:sub(1, 500),
    },
  }

  local prov = getProvider(config.active_provider)
  local req = prov.buildChatRequest(titlerMessages, "You are a conversation summarizer.", config)
  if type(req.body) == "string" then
    req.body = req.body:gsub('"stream":%s*true', '"stream": false')
  end

  noctalia.http(req, function(resp: HttpResponse)
    if not resp.ok or resp.status < 200 or resp.status >= 300 then
      return
    end

    local decoded, err = noctalia.json.decode(resp.body)
    if err or type(decoded) ~= "table" then
      return
    end

    local title: string? = nil
    if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
      title = decoded.choices[1].message.content
    elseif decoded.content and decoded.content[1] and decoded.content[1].text then
      title = decoded.content[1].text
    elseif decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts then
      title = decoded.candidates[1].content.parts[1].text
    end

    if title and type(title) == "string" then
      local clean = noctalia.string.trim(title)
      clean = clean:gsub('^["\']+', ''):gsub('["\']+$', '')
      clean = clean:gsub("[/\\%%:*?\"<>|]", "")
      clean = noctalia.string.trim(clean)
      if #clean > 0 then
        if #clean > 45 then
          clean = clean:sub(1, 42) .. "..."
        end
        onSuccess(clean)
      end
    end
  end)
end

return client
