--!nonstrict
-- Hyprland IPC communication & socket2 event streaming
local state = require("./state.luau")

local hypr = {
  isStreaming = false,
  isAvailable = true,
}

local function safeJsonDecode(str: string): any
  if not str or str == "" then return nil end
  local ok, res = pcall(function()
    return noctalia.json.decode(str)
  end)
  return ok and res or nil
end

function hypr.refreshGlobalLayout(onDone: ((string?) -> ())?)
  if not noctalia or not noctalia.runAsync then return end
  noctalia.runAsync({ "hyprctl", "getoption", "general:layout", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local data = safeJsonDecode(res.stdout)
      if data and data.str then
        state.setGlobalLayout(data.str)
        if onDone then onDone(data.str) end
        return
      end
    else
      hypr.isAvailable = false
    end
    if onDone then onDone(nil) end
  end)
end

function hypr.refreshActiveWorkspace(onDone: ((number?, string?) -> ())?)
  if not noctalia or not noctalia.runAsync then return end
  noctalia.runAsync({ "hyprctl", "activeworkspace", "-j" }, function(res)
    if res.exitCode == 0 and res.stdout ~= "" then
      hypr.isAvailable = true
      local data = safeJsonDecode(res.stdout)
      if data and data.id then
        local wsId = tonumber(data.id) or 1
        local wsName = tostring(data.name or wsId)
        local monitor = tostring(data.monitor or "")
        state.setActiveWorkspace(wsId, wsName, monitor)
        if data.tiledLayout and type(data.tiledLayout) == "string" and data.tiledLayout ~= "" then
          local cleanTiled = string.lower(data.tiledLayout)
          local cleanGlobal = string.lower(state.globalLayout or "dwindle")
          if cleanTiled ~= cleanGlobal or state.hasWorkspaceOverride(wsId) then
            state.setWorkspaceLayout(wsId, cleanTiled)
          end
        end
        if onDone then onDone(wsId, wsName) end
        return
      end
    end
    if onDone then onDone(nil, nil) end
  end)
end

function hypr.refresh()
  hypr.refreshGlobalLayout()
  hypr.refreshActiveWorkspace()
end

function hypr.setLayout(layoutName: string, scope: string?, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not layoutName or layoutName == "" then
    if onDone then onDone(false) end
    return
  end
  local targetScope = scope or state.currentScope

  if targetScope == "workspace" then
    local wsId = state.activeWorkspaceId or 1
    -- Try modern Lua Hyprland workspace rule first via hyprctl eval
    local evalCmd = { "hyprctl", "eval", string.format("hl.workspace_rule({ workspace = %d, layout = '%s' })", wsId, layoutName) }
    noctalia.runAsync(evalCmd, function(res)
      local isOk = (res.exitCode == 0 and string.find(res.stdout, "ok", 1, true) ~= nil)
      if isOk then
        state.setWorkspaceLayout(wsId, layoutName)
        if onDone then onDone(true) end
      else
        -- Fallback to legacy keyword parser for standard hyprland.conf
        local legacyCmd = { "hyprctl", "keyword", "workspace", tostring(wsId) .. ",layout:" .. layoutName }
        noctalia.runAsync(legacyCmd, function(legacyRes)
          local ok = (legacyRes.exitCode == 0
            and string.find(legacyRes.stdout, "Use eval", 1, true) == nil
            and string.find(legacyRes.stdout, "non-legacy", 1, true) == nil)
          if ok then
            state.setWorkspaceLayout(wsId, layoutName)
          end
          if onDone then onDone(ok) end
        end)
      end
    end)
  else
    -- Try modern Lua Hyprland global config first via hyprctl eval
    local evalCmd = { "hyprctl", "eval", string.format("hl.config({ general = { layout = '%s' } })", layoutName) }
    noctalia.runAsync(evalCmd, function(res)
      local isOk = (res.exitCode == 0 and string.find(res.stdout, "ok", 1, true) ~= nil)
      if isOk then
        state.setGlobalLayout(layoutName)
        if onDone then onDone(true) end
      else
        -- Fallback to legacy keyword parser for standard hyprland.conf
        local legacyCmd = { "hyprctl", "keyword", "general:layout", layoutName }
        noctalia.runAsync(legacyCmd, function(legacyRes)
          local ok = (legacyRes.exitCode == 0
            and string.find(legacyRes.stdout, "Use eval", 1, true) == nil
            and string.find(legacyRes.stdout, "non-legacy", 1, true) == nil)
          if ok then
            state.setGlobalLayout(layoutName)
          end
          if onDone then onDone(ok) end
        end)
      end
    end)
  end
end

function hypr.resetWorkspaceToGlobal(wsId: number?, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync then
    if onDone then onDone(false) end
    return
  end
  local targetWsId = wsId or state.activeWorkspaceId or 1
  local globalLayout = state.globalLayout or "dwindle"

  -- 1. Try modern Lua Hyprland workspace rule reset via hyprctl eval
  local evalCmd = { "hyprctl", "eval", string.format("hl.workspace_rule({ workspace = %d, layout = '' })", targetWsId) }
  noctalia.runAsync(evalCmd, function(res)
    local isOk = (res.exitCode == 0 and string.find(res.stdout, "ok", 1, true) ~= nil)
    if not isOk then
      -- Fallback to explicit global layout
      local evalFallback = { "hyprctl", "eval", string.format("hl.workspace_rule({ workspace = %d, layout = '%s' })", targetWsId, globalLayout) }
      noctalia.runAsync(evalFallback, function() end)
    end

    -- Also fallback for legacy hyprland.conf if needed
    local legacyCmd = { "hyprctl", "keyword", "workspace", tostring(targetWsId) .. ",layout:" .. globalLayout }
    noctalia.runAsync(legacyCmd, function() end)

    -- Remove override from state
    state.removeWorkspaceOverride(targetWsId)

    -- Refresh active workspace
    hypr.refreshActiveWorkspace()

    if onDone then onDone(true) end
  end)
end

function hypr.dispatchSubAction(command: string, onDone: ((boolean) -> ())?)
  if not noctalia or not noctalia.runAsync or not command or command == "" then
    if onDone then onDone(false) end
    return
  end

  -- Try modern Lua Hyprland layout dispatcher first via hyprctl eval
  local evalCmd = { "hyprctl", "eval", string.format("hl.dispatch(hl.dsp.layout('%s'))", command) }
  noctalia.runAsync(evalCmd, function(res)
    local isOk = (res.exitCode == 0 and string.find(res.stdout, "error:", 1, true) == nil)
    if isOk then
      if onDone then onDone(true) end
    else
      -- Fallback to legacy dispatch
      local legacyCmd = {}
      if string.find(command, ":", 1, true) then
        local colonIdx = string.find(command, ":", 1, true)
        local dispatcher = string.sub(command, 1, colonIdx - 1)
        local arg = string.sub(command, colonIdx + 1)
        legacyCmd = { "hyprctl", "dispatch", dispatcher, arg }
      else
        legacyCmd = { "hyprctl", "dispatch", "layoutmsg", command }
      end

      noctalia.runAsync(legacyCmd, function(legacyRes)
        local ok = (legacyRes.exitCode == 0 and string.find(legacyRes.stdout, "error:", 1, true) == nil)
        if onDone then onDone(ok) end
      end)
    end
  end)
end

function hypr.startSocketStream()
  if hypr.isStreaming or not noctalia or not noctalia.runStream or not noctalia.getenv then
    return
  end

  local xdgRuntime = noctalia.getenv("XDG_RUNTIME_DIR") or "/run/user/" .. tostring(noctalia.getenv("UID") or "1000")
  local his = noctalia.getenv("HYPRLAND_INSTANCE_SIGNATURE")
  if not his or his == "" then
    return
  end

  local sockPath = xdgRuntime .. "/hypr/" .. his .. "/.socket2.sock"
  local streamCmd = "socat -U - UNIX-CONNECT:\"" .. sockPath .. "\""

  hypr.isStreaming = true
  noctalia.runStream(streamCmd, function(line)
    if not line or line == "" then return end
    if string.sub(line, 1, 11) == "workspace>>" then
      hypr.refreshActiveWorkspace()
    elseif string.sub(line, 1, 12) == "focusedmon>>" then
      hypr.refreshActiveWorkspace()
    elseif string.sub(line, 1, 16) == "configreloaded>>" then
      hypr.refreshGlobalLayout()
    end
  end)
end

function hypr.init()
  hypr.refresh()
  hypr.startSocketStream()
end

return hypr
