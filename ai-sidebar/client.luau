--!strict
local openai = require("./providers/openai.luau")
local anthropic = require("./providers/anthropic.luau")
local gemini = require("./providers/gemini.luau")
local custom = require("./providers/custom.luau")
local context = require("./context.luau")

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

local function buildEnvironmentPrompt(baseSystemPrompt: string?): string
  local timeStr = noctalia.formatTime("%Y-%m-%d %H:%M:%S")
  local envInfo = "\n\n[Environment Context: Current system time is " .. timeStr .. ", running on Noctalia Hyprland Shell inside custom Bazzite-DX image.]"
  local base = (baseSystemPrompt and baseSystemPrompt ~= "") and baseSystemPrompt or "You are a helpful and concise AI assistant."
  return base .. envInfo
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
  onStatus: ((status: string, attempt: number, maxRetries: number) -> ())?
): any
  local prov = getProvider(config.active_provider)
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt)
  
  -- Prepare rolling context to prevent token overflows and context amnesia
  local contextMessages = context.prepareContext(messages, 4096, augmentedPrompt)
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
    cancel = function()
      isCancelled = true
      errorReported = true
    end,
  }
end

return client
