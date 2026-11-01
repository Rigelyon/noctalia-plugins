--!nonstrict
local state = require("./state.luau")
local presets = require("./presets.luau")

local lastRenderedStatus = ""
local lastRenderedGlyph = ""
local lastPollTime = 0

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function executeProbe()
  if state.isProbing then
    return
  end
  state.isProbing = true

  local pluginDir = (noctalia and noctalia.pluginDir) and noctalia.pluginDir() or "."
  local probeScript = pluginDir .. "/probe.sh"
  local targetHost = state.getActiveTargetHost()

  if noctalia and noctalia.runAsync then
    noctalia.runAsync({ probeScript, targetHost }, function(result)
      state.isProbing = false
      if result and result.exitCode == 0 and result.stdout then
        state.processProbe(result.stdout)
      end
    end, 2500)
  else
    state.isProbing = false
  end
end

local function updateWidget()
  if not barWidget then
    return
  end

  local status = state.getStatus()
  local glyph = "wifi"
  local colorRole = "primary"

  if status == "OPTIMAL" then
    glyph = "device-gamepad"
    colorRole = "primary"
  elseif status == "FAIR" then
    glyph = "wifi-2"
    colorRole = "warning"
  elseif status == "POOR" then
    glyph = "alert-triangle"
    colorRole = "destructive"
  elseif status == "CAPTIVE_PORTAL" then
    glyph = "login"
    colorRole = "warning"
  else -- OFFLINE
    glyph = "wifi-off"
    colorRole = "outline"
  end

  -- Dirty check to minimize barWidget calls and compositor redraws
  if glyph ~= lastRenderedGlyph or status ~= lastRenderedStatus then
    barWidget.setGlyph(glyph)
    barWidget.setGlyphColor(colorRole)
    lastRenderedGlyph = glyph
    lastRenderedStatus = status
  end

  -- Respect user constraint: icon-only by default
  local showText = false
  if noctalia and noctalia.getConfig then
    showText = noctalia.getConfig("show_text_in_bar") == true
  end

  if showText and state.gameMs then
    barWidget.setText(string.format("%.0fms", state.gameMs))
  else
    barWidget.setText("")
  end

  -- Rich Hover Tooltip
  local currentPreset = presets.getById(state.activePresetId)
  local targetName = currentPreset.regionName
  local gameLatencyStr = state.gameMs and string.format("%.1f ms", state.gameMs) or "--"
  local jitterStr = string.format("±%.1f ms", state.jitter)
  local lossStr = string.format("%.1f%%", state.lossPct)
  local gwStr = state.gwMs and string.format("%.1f ms", state.gwMs) or "--"
  
  local wifiStr = "Ethernet / Disconnected"
  if state.ssid ~= "" then
    local bandStr = state.freqMhz >= 5000 and "5 GHz" or "2.4 GHz"
    wifiStr = string.format("%s • %s • %.0f Mbps (%d%%)", state.ssid, bandStr, state.rateMbps, state.signalPct)
  end

  local tooltips = {
    { key = tr("widget.tooltip_title"), value = string.format("%s (%s)", tr("widget.status_" .. string.lower(status)), targetName) },
    { key = tr("widget.row_game_latency"), value = gameLatencyStr },
    { key = tr("widget.row_jitter"), value = jitterStr },
    { key = tr("widget.row_packet_loss"), value = lossStr },
    { key = tr("widget.row_gateway"), value = gwStr },
    { key = tr("widget.row_wifi_link"), value = wifiStr },
  }
  barWidget.setTooltip(tooltips)
end

function onClick()
  if noctalia and noctalia.togglePanel then
    noctalia.togglePanel("rigelyon/net-radar:panel")
  end
end

-- Subscribe to state updates
state.subscribe(function()
  updateWidget()
end)

-- Main tick handler with adaptive polling
function update(deltaMs: number)
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  
  local idleInterval = 5000
  if noctalia and noctalia.getConfig then
    local cfg = noctalia.getConfig("idle_poll_interval_sec")
    if type(cfg) == "number" and cfg >= 2 then
      idleInterval = cfg * 1000
    end
  end

  -- Backoff if offline
  if state.getStatus() == "OFFLINE" then
    idleInterval = math.max(idleInterval, 10000)
  end

  if now - lastPollTime >= idleInterval then
    lastPollTime = now
    executeProbe()
  end
end

-- Initial probe on startup
executeProbe()
updateWidget()
