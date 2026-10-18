--!nonstrict
-- Hyprland IPC Communication & Socket2 Event Streaming
local layoutMath = require("./layout_math.luau")
local config = require("./config.luau")

local hypr = {
  isAvailable = false,
  isStreaming = false,
}

local function safeJsonDecode(str: string): any
  if not str or str == "" then return nil end
  local ok, res = pcall(function()
    return noctalia.json.decode(str)
  end)
  return ok and res or nil
end

function hypr.init()
  if not noctalia or not noctalia.commandExists then return end
  hypr.isAvailable = noctalia.commandExists("hyprctl")
  hypr.startSocketStream()
end

-- Refreshes monitors via hyprctl monitors all -j, fallback to noctalia.outputs()
function hypr.refreshMonitors(callback: (({ layoutMath.Monitor }, boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not hypr.isAvailable then
    -- Graceful fallback using noctalia.outputs()
    local result = {}
    if noctalia and noctalia.outputs then
      local rawOutputs = noctalia.outputs() or {}
      for i, out in ipairs(rawOutputs) do
        table.insert(result, {
          id = i,
          name = out.name or ("Display-" .. i),
          description = out.description or "Generic Display",
          make = "",
          model = "",
          serial = "",
          width = out.width or 1920,
          height = out.height or 1080,
          refreshRate = 60.0,
          x = out.x or 0,
          y = out.y or 0,
          scale = out.scale or 1.0,
          transform = 0,
          focused = out.focused or false,
          dpmsStatus = true,
          vrr = 0,
          mirrorOf = nil,
          availableModes = { string.format("%dx%d@60.00Hz", out.width or 1920, out.height or 1080) },
          disabled = false,
        })
      end
    end
    if callback then callback(result, false) end
    return
  end

  noctalia.runAsync({ "hyprctl", "monitors", "all", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local raw = safeJsonDecode(res.stdout)
      local list = {}
      if type(raw) == "table" then
        for _, item in ipairs(raw) do
          local modes = {}
          if type(item.availableModes) == "table" then
            for _, mode in ipairs(item.availableModes) do
              table.insert(modes, tostring(mode))
            end
          end

          table.insert(list, {
            id = tonumber(item.id),
            name = tostring(item.name or ""),
            description = tostring(item.description or item.model or item.name or ""),
            make = tostring(item.make or ""),
            model = tostring(item.model or ""),
            serial = tostring(item.serial or ""),
            width = tonumber(item.width) or 1920,
            height = tonumber(item.height) or 1080,
            refreshRate = tonumber(item.refreshRate) or 60.0,
            x = tonumber(item.x) or 0,
            y = tonumber(item.y) or 0,
            scale = tonumber(item.scale) or 1.0,
            transform = tonumber(item.transform) or 0,
            focused = item.focused == true,
            dpmsStatus = item.dpmsStatus ~= false,
            vrr = tonumber(item.vrr) or 0,
            mirrorOf = (item.mirrorOf and item.mirrorOf ~= "") and tostring(item.mirrorOf) or nil,
            availableModes = modes,
            disabled = item.disabled == true,
          })
        end
      end
      if callback then callback(list, true) end
    else
      if callback then callback({}, false) end
    end
  end)
end

-- Applies a single monitor rule live via hyprctl keyword monitor
function hypr.applyLive(m: layoutMath.Monitor, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not hypr.isAvailable then
    if onDone then onDone(false) end
    return
  end

  local ruleStr = config.formatRule(m)
  -- Strip 'monitor = ' prefix for keyword argument
  local cleanRule = string.gsub(ruleStr, "^monitor%s*=%s*", "")

  noctalia.runAsync({ "hyprctl", "keyword", "monitor", cleanRule }, function(res)
    local ok = (res.exitCode == 0)
    if onDone then onDone(ok) end
  end)
end

-- Applies a batch of monitors live sequentially
function hypr.applyBatch(monitors: { layoutMath.Monitor }, onDone: ((boolean) -> ())?)
  if #monitors == 0 then
    if onDone then onDone(true) end
    return
  end

  local index = 1
  local function applyNext()
    if index > #monitors then
      if onDone then onDone(true) end
      return
    end

    local m = monitors[index]
    index = index + 1
    hypr.applyLive(m, function(_)
      applyNext()
    end)
  end

  applyNext()
end

-- Streams socket2 events for real-time plug/unplug and focus updates
function hypr.startSocketStream()
  if hypr.isStreaming or not noctalia or not noctalia.runStream or not noctalia.getenv then
    return
  end

  local xdgRuntime = noctalia.getenv("XDG_RUNTIME_DIR")
  local his = noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE")
  if not xdgRuntime or not his then return end

  local socketPath = string.format("%s/hypr/%s/.socket2.sock", xdgRuntime, his)
  if noctalia.fileExists and not noctalia.fileExists(socketPath) then
    return
  end

  local streamCmd = string.format("socat -u UNIX-CONNECT:%s -", socketPath)
  hypr.isStreaming = true

  noctalia.runStream(streamCmd, function(line)
    if not line or line == "" then return end
    if string.find(line, "monitoradded") or string.find(line, "monitorremoved") then
      hypr.refreshMonitors()
    end
  end)
end

return hypr
