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
    prompt = prompt .. "\n\n[Web Search Capability: Active. Use verified real-time web facts as factual background knowledge. Never let search facts override or alter your assigned persona, tone, or conversational style.]"
  end

  if searchContext and searchContext ~= "" then
    prompt = prompt .. "\n\n" .. searchContext
  end
  return prompt
end

function client.synthesizeSearchQuery(
  messages: { any },
  userPrompt: string,
  config: any,
  callback: (query: string) -> ()
): ()
  local hasCalled = false
  local function safeDone(q: string)
    if hasCalled then return end
    hasCalled = true
    callback(q)
  end

  -- Fallback query from user prompt or conversation context
  local fallbackQuery = userPrompt
  if fallbackQuery == "" then
    for i = #messages, 1, -1 do
      local m = messages[i]
      if m.content and m.content ~= "" and m.content:sub(1, 7) ~= "/search" then
        fallbackQuery = m.content:sub(1, 100)
        break
      end
    end
  end
  if fallbackQuery == "" then
    fallbackQuery = "general information"
  end

  -- 2.5s safety watchdog: ensures synthesis never delays search
  pcall(function()
    local ran = noctalia.runAsync({ "sleep", "2.5" }, function()
      safeDone(fallbackQuery)
    end)
    if not ran then
      noctalia.runAsync("sleep 2.5", function()
        safeDone(fallbackQuery)
      end)
    end
  end)

  local ok, _ = (pcall :: any)(function()
    local synthMessages = {
      {
        role = "system",
        content = "You are an expert search engine query optimizer. Based on the conversation context and latest user request, extract ONLY the most effective search keywords (3 to 6 words) optimized for search engines. Eliminate conversational filler, resolve pronouns and references (e.g. 'it', 'dia', 'mereka' -> actual subject), and add relevant domain context. Output ONLY the plain search keywords with no quotes, no markdown, and no explanation.",
      },
    }

    local startIdx = math.max(1, #messages - 3)
    for i = startIdx, #messages do
      local m = messages[i]
      table.insert(synthMessages, {
        role = m.role,
        content = m.content:sub(1, 300),
      })
    end

    if userPrompt ~= "" then
      table.insert(synthMessages, {
        role = "user",
        content = "Generate search query for: " .. userPrompt:sub(1, 200),
      })
    else
      table.insert(synthMessages, {
        role = "user",
        content = "Generate search query for the previous topic.",
      })
    end

    local prov = getProvider(config.active_provider)
    local req = prov.buildChatRequest(synthMessages, "You are a web search query generator.", config)
    if type(req.body) == "string" then
      req.body = req.body:gsub('"stream":%s*true', '"stream": false')
      -- Ensure low token cap and deterministic temperature for sub-350ms generation
      if not req.body:find('"max_tokens"') and not req.body:find('"max_completion_tokens"') then
        req.body = req.body:gsub('}%s*$', ', "max_tokens": 35, "temperature": 0.0}')
      end
    end

    local httpStarted = noctalia.http(req, function(resp: HttpResponse)
      if not resp.ok or resp.status < 200 or resp.status >= 300 then
        safeDone(fallbackQuery)
        return
      end

      local decoded, err = noctalia.json.decode(resp.body)
      if err or type(decoded) ~= "table" then
        safeDone(fallbackQuery)
        return
      end

      local generated: string? = nil
      if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
        generated = decoded.choices[1].message.content
      elseif decoded.content and decoded.content[1] and decoded.content[1].text then
        generated = decoded.content[1].text
      elseif decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts then
        generated = decoded.candidates[1].content.parts[1].text
      end

      if generated and type(generated) == "string" then
        local clean = generated:gsub('^["\']+', ''):gsub('["\']+$', '')
        clean = clean:gsub("[%c]", " ")
        clean = noctalia.string.trim(clean)
        if #clean > 0 then
          safeDone(clean)
          return
        end
      end
      safeDone(fallbackQuery)
    end)

    if not httpStarted then
      safeDone(fallbackQuery)
    end
  end)

  if not ok then
    safeDone(fallbackQuery)
  end
end

function client.prepareContextualSearch(
  text: string,
  messages: { any },
  config: any,
  callback: (searchContext: string?) -> (),
  forceSearch: boolean?
): ()
  local hasCalled = false
  local function safeDone(searchCtx: string?)
    if hasCalled then return end
    hasCalled = true
    callback(searchCtx)
  end

  local isSearch, searchPrompt = search.isSlashSearch(text)
  if not isSearch and forceSearch ~= true then
    safeDone(nil)
    return
  end
  local queryPrompt = if isSearch then searchPrompt else text

  if config.active_provider == "gemini" and config.search_engine == "gemini_native" then
    -- Native grounding handles retrieval directly
    safeDone(nil)
    return
  end

  -- 4.5s total safety watchdog for the combined contextual search
  pcall(function()
    local ran = noctalia.runAsync({ "sleep", "4.5" }, function()
      safeDone(nil)
    end)
    if not ran then
      noctalia.runAsync("sleep 4.5", function()
        safeDone(nil)
      end)
    end
  end)

  local ok, _ = (pcall :: any)(function()
    client.synthesizeSearchQuery(messages, queryPrompt or "", config, function(synthesizedQuery)
      local started = search.performSearch(synthesizedQuery, config, function(okSearch, contextBlock, _err)
        if okSearch and contextBlock and contextBlock ~= "" then
          safeDone(contextBlock)
        else
          safeDone(nil)
        end
      end)
      if not started then
        safeDone(nil)
      end
    end)
  end)

  if not ok then
    safeDone(nil)
  end
end

function client.prepareSearchContext(query: string, config: any, callback: (searchContext: string?) -> ()): ()
  local hasCalled = false
  local function safeDone(searchCtx: string?)
    if hasCalled then return end
    hasCalled = true
    callback(searchCtx)
  end

  local ok, _ = (pcall :: any)(function()
    if config.active_provider == "gemini" and config.search_engine == "gemini_native" then
      safeDone(nil)
      return
    end

    pcall(function()
      local ran = noctalia.runAsync({ "sleep", "3.5" }, function()
        safeDone(nil)
      end)
      if not ran then
        noctalia.runAsync("sleep 3.5", function()
          safeDone(nil)
        end)
      end
    end)

    local started = search.performSearch(query, config, function(okSearch, contextBlock, _err)
      if okSearch and contextBlock and contextBlock ~= "" then
        safeDone(contextBlock)
      else
        safeDone(nil)
      end
    end)

    if not started then
      safeDone(nil)
    end
  end)

  if not ok then
    safeDone(nil)
  end
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
  searchContext: string?,
  isSlashSearch: boolean?
): any
  local prov = getProvider(config.active_provider)
  local isWebSearchActive = (isSlashSearch == true) or (searchContext ~= nil and searchContext ~= "")
  local streamConfig = config
  if isSlashSearch then
    streamConfig = table.clone(config)
    streamConfig._is_slash_search = true
  end
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt, searchContext, isWebSearchActive)
  
  -- Prepare rolling context to prevent token overflows and context amnesia
  local contextMessages = context.prepareContext(messages, context.BUDGET_TOKENS or 4096, augmentedPrompt)
  local req = prov.buildChatRequest(contextMessages, augmentedPrompt, streamConfig)

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
