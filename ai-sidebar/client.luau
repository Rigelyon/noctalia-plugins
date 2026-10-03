--!strict
local openai = require("./providers/openai.luau")
local anthropic = require("./providers/anthropic.luau")
local gemini = require("./providers/gemini.luau")
local custom = require("./providers/custom.luau")

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
  local envInfo = "\n\n[Environment Context: Current system time is " .. timeStr .. ", running on Noctalia Linux Desktop Shell.]"
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
  onDone: () -> ()
): any
  local prov = getProvider(config.active_provider)
  local augmentedPrompt = buildEnvironmentPrompt(config.system_prompt)
  local req = prov.buildChatRequest(messages, augmentedPrompt, config)

  local hasReceivedChunk = false
  local errorReported = false

  local handle = noctalia.httpStream(req, function(line: string)
    local text = prov.parseStreamLine(line)
    if text and text ~= "" then
      hasReceivedChunk = true
      onChunk(text)
    end
  end, function(result: any)
    if not result.ok or (result.status ~= 0 and result.status >= 400) then
      if not errorReported then
        errorReported = true
        onError("Stream error (HTTP " .. tostring(result.status) .. ")")
      end
    else
      if not hasReceivedChunk and not errorReported then
        -- In case provider sent error inside body
        onError("No response data received from provider")
      else
        onDone()
      end
    end
  end)

  if handle == nil then
    onError("Unable to initialize HTTP stream (offline mode or network disabled)")
    return nil
  end

  return handle
end

return client
