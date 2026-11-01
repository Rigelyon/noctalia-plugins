--!nonstrict
local state = require("./state.luau")
local presets = require("./presets.luau")

local lastRenderTime = 0
local activePollTimer = 0

local function tr(key: string, subst: { [string]: any }?): string
  if noctalia and noctalia.tr then
    return noctalia.tr(key, subst)
  end
  return key
end

local function executeProbe()
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  if state.isProbing then
    -- Watchdog: if probe has been pending for more than 4000ms, force reset
    if now - state.lastProbeTime < 4000 then
      return
    end
    state.isProbing = false
  end
  state.isProbing = true
  state.lastProbeTime = now

  local pluginDir = (noctalia and noctalia.pluginDir) and noctalia.pluginDir() or "."
  local probeScript = pluginDir .. "/probe.sh"
  local targetHost = state.getActiveTargetHost()

  if noctalia and noctalia.runAsync then
    local started = noctalia.runAsync({ probeScript, targetHost }, function(result)
      state.isProbing = false
      if result and result.exitCode == 0 and result.stdout and result.stdout ~= "" then
        state.processProbe(result.stdout)
      else
        state.processProbe("none|none|none|none|0|0|0")
      end
    end, 2000)
    if not started then
      state.isProbing = false
    end
  else
    state.isProbing = false
  end
end

-- Render segmented level meter [ ■ ■ ■ ■ ■ ] without rounded pills
function renderSegmentedMeter(status: string): UiNode
  local bars = 5
  local activeBars = 5
  local color = "primary"

  if status == "OPTIMAL" then
    activeBars = 5
    color = "primary"
  elseif status == "FAIR" then
    activeBars = 3
    color = "tertiary"
  elseif status == "POOR" then
    activeBars = 1
    color = "error"
  else
    activeBars = 0
    color = "outline"
  end

  local segmentChildren = {}
  for i = 1, bars do
    local isLit = i <= activeBars
    table.insert(segmentChildren, ui.box({
      width = 7,
      height = 14,
      fill = isLit and color or "surface",
      border = isLit and color or "outline",
      borderWidth = 1,
      radius = 1,
    }))
  end

  return ui.row({
    gap = 3,
    align = "center",
  }, segmentChildren)
end

local function renderPanel(): UiNode
  local status = state.getStatus()
  local currentPreset = presets.getById(state.activePresetId)
  local targetHost = state.getActiveTargetHost()

  local statusColor = "primary"
  local statusText = tr("widget.status_optimal")

  if status == "OPTIMAL" then
    statusColor = "primary"
    statusText = tr("widget.status_optimal")
  elseif status == "FAIR" then
    statusColor = "tertiary"
    statusText = tr("widget.status_fair")
  elseif status == "POOR" then
    statusColor = "error"
    statusText = tr("widget.status_poor")
  elseif status == "CAPTIVE_PORTAL" then
    statusColor = "tertiary"
    statusText = "CAPTIVE PORTAL"
  else
    statusColor = "outline"
    statusText = tr("widget.status_offline")
  end

  local diagText, diagGlyph, diagColor = state.getDiagnostics()
  local graphValues, minRtt, avgRtt, maxRtt = state.getGraphValues()

  -- Tactical Telemetry Header (Sharp 4px radius, 3px solid left accent border)
  local telemetryCard = ui.row({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    padding = 12,
    justify = "space_between",
    align = "center",
  }, {
    -- Left block with reactive color bar
    ui.row({
      gap = 10,
      align = "center",
    }, {
      ui.box({
        width = 4,
        height = 42,
        fill = statusColor,
        radius = 1,
      }),
      ui.column({
        gap = 4,
      }, {
        ui.label({
          text = statusText,
          fontSize = 14,
          fontWeight = "bold",
          color = statusColor,
        }),
        ui.label({
          text = string.format("%s: %s (%s)", tr("panel.target_label"), currentPreset.regionName, targetHost),
          fontSize = 11,
          color = "on_surface",
          opacity = 0.7,
        }),
      }),
    }),
    -- Right block with segmented meter & RTT number
    ui.row({
      gap = 10,
      align = "center",
    }, {
      renderSegmentedMeter(status),
      ui.column({
        align = "end",
      }, {
        ui.label({
          text = state.gameMs and string.format("%.0f ms", state.gameMs) or "--",
          fontSize = 18,
          fontWeight = "bold",
          color = statusColor,
        }),
        ui.label({
          text = tr("panel.rtt_unit"),
          fontSize = 9,
          opacity = 0.6,
        }),
      }),
    }),
  })

  -- Diagnostic Callout Banner
  local diagBanner = ui.row({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    paddingH = 10,
    paddingV = 8,
    align = "center",
    gap = 8,
  }, {
    ui.glyph({
      name = diagGlyph,
      size = 14,
      color = diagColor,
    }),
    ui.label({
      text = diagText,
      fontSize = 11,
      color = "on_surface",
      opacity = 0.85,
      flexGrow = 1,
    }),
  })

  -- Latency & Jitter Graph
  local graphCard = ui.column({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    padding = 10,
    gap = 6,
  }, {
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.label({
        text = tr("panel.graph_title"),
        fontSize = 10,
        fontWeight = "semibold",
        opacity = 0.7,
      }),
      ui.label({
        text = string.format("Jitter: ±%.1fms • Loss: %.1f%%", state.jitter, state.lossPct),
        fontSize = 10,
        fontWeight = "bold",
        color = state.lossPct > 0 and "error" or "on_surface",
      }),
    }),
    ui.graph({
      height = 70,
      values = graphValues,
      color = statusColor,
      lineWidth = 2,
      fillOpacity = 0.2,
    }),
    ui.label({
      text = tr("panel.graph_summary", {
        min = string.format("%.0f", minRtt),
        avg = string.format("%.0f", avgRtt),
        max = string.format("%.0f", maxRtt),
        jitter = string.format("%.1f", state.jitter),
        loss = string.format("%.1f", state.lossPct),
      }),
      fontSize = 10,
      opacity = 0.65,
    }),
  })

  -- Multi-Target Breakdown Cards (Gateway, DNS, Game)
  local targetCards = ui.row({
    gap = 8,
  }, {
    ui.column({
      flexGrow = 1,
      fill = "surface",
      border = "outline",
      borderWidth = 1,
      radius = 4,
      padding = 8,
      gap = 2,
    }, {
      ui.label({ text = tr("panel.target_gateway"), fontSize = 9, opacity = 0.6 }),
      ui.label({ text = state.gwMs and string.format("%.1f ms", state.gwMs) or "--", fontSize = 13, fontWeight = "bold" }),
      ui.label({ text = state.gwMs and "0% loss" or "Unreachable", fontSize = 9, color = state.gwMs and "primary" or "error" }),
    }),
    ui.column({
      flexGrow = 1,
      fill = "surface",
      border = "outline",
      borderWidth = 1,
      radius = 4,
      padding = 8,
      gap = 2,
    }, {
      ui.label({ text = tr("panel.target_dns"), fontSize = 9, opacity = 0.6 }),
      ui.label({ text = state.dnsMs and string.format("%.1f ms", state.dnsMs) or "--", fontSize = 13, fontWeight = "bold" }),
      ui.label({ text = state.dnsMs and "Connected" or "Blocked", fontSize = 9, color = state.dnsMs and "primary" or "error" }),
    }),
    ui.column({
      flexGrow = 1,
      fill = "surface",
      border = "outline",
      borderWidth = 1,
      radius = 4,
      padding = 8,
      gap = 2,
    }, {
      ui.label({ text = tr("panel.target_game"), fontSize = 9, opacity = 0.6 }),
      ui.label({ text = state.gameMs and string.format("%.1f ms", state.gameMs) or "--", fontSize = 13, fontWeight = "bold", color = statusColor }),
      ui.label({ text = string.format("%.1f%% loss", state.lossPct), fontSize = 9, color = state.lossPct > 0 and "error" or "primary" }),
    }),
  })

  -- Wi-Fi Physical Link Stats
  local wifiSummary = tr("panel.wired_connection")
  if state.ssid ~= "" then
    local band = state.freqMhz >= 5000 and "5 GHz" or "2.4 GHz"
    wifiSummary = string.format("%s: %s • %s: %s • %s: %d%% • %s: %.0f Mbps",
      tr("panel.wifi_ssid"), state.ssid,
      tr("panel.wifi_band"), band,
      tr("panel.wifi_signal"), state.signalPct,
      tr("panel.wifi_rate"), state.rateMbps)
  end

  local wifiCard = ui.row({
    fill = "surface",
    border = "outline",
    borderWidth = 1,
    radius = 4,
    padding = 8,
    gap = 8,
    align = "center",
  }, {
    ui.glyph({ name = "wifi", size = 14, color = "primary" }),
    ui.label({
      text = wifiSummary,
      fontSize = 10,
      opacity = 0.8,
      flexGrow = 1,
    }),
  })

  -- Region / Preset Select Dropdown
  local presetOptions = {}
  local selectedIndex = 0
  for i, p in ipairs(presets.LIST) do
    table.insert(presetOptions, p.regionName)
    if p.id == state.activePresetId then
      selectedIndex = i - 1 -- 0-based for ui.select
    end
  end

  local regionDropdown = ui.select({
    controlSize = "sm",
    options = presetOptions,
    selectedIndex = selectedIndex,
    onChange = function(indexStr, text)
      local idx = tonumber(indexStr) or 0
      local chosen = presets.LIST[idx + 1]
      if chosen and chosen.id ~= state.activePresetId then
        state.setPreset(chosen.id)
        executeProbe()
      end
    end,
  })

  -- Bottom Actions Bar
  local actionsBar = ui.row({
    justify = "space_between",
    align = "center",
  }, {
    ui.button({
      text = tr("panel.retest"),
      controlSize = "sm",
      onClick = function()
        executeProbe()
      end,
    }),
    regionDropdown,
  })

  return ui.column({
    padding = 16,
    gap = 10,
  }, {
    -- Panel Header
    ui.row({
      justify = "space_between",
      align = "center",
    }, {
      ui.label({
        text = tr("panel.title"),
        fontSize = 12,
        fontWeight = "bold",
        opacity = 0.7,
      }),
      ui.glyph({
        name = state.isProbing and "loader" or "activity",
        size = 14,
        color = state.isProbing and "primary" or "outline",
      }),
    }),

    telemetryCard,
    diagBanner,
    graphCard,
    targetCards,
    wifiCard,
    actionsBar,
  })
end

-- Render throttler to respect Luau CPU budget (>= 100ms)
local function throttledRender()
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  if now - lastRenderTime < 100 then
    return
  end
  lastRenderTime = now
  if panel and panel.render then
    panel.render(renderPanel())
  elseif render then
    render(renderPanel())
  end
end

state.subscribe(function()
  throttledRender()
end)

function update(deltaMs: number)
  local now = (noctalia and noctalia.nowMs) and noctalia.nowMs() or (os.clock() * 1000)
  local activeInterval = 2000
  if noctalia and noctalia.getConfig then
    local cfg = noctalia.getConfig("active_poll_interval_sec")
    if type(cfg) == "number" and cfg >= 1 then
      activeInterval = cfg * 1000
    end
  end

  if now - activePollTimer >= activeInterval then
    activePollTimer = now
    executeProbe()
  end
end

function onOpen()
  if panel and panel.setWantsSecondTicks then
    panel.setWantsSecondTicks(true)
  end
  executeProbe()
  throttledRender()
end

function onClose()
  if panel and panel.setWantsSecondTicks then
    panel.setWantsSecondTicks(false)
  end
end

-- Initial render
throttledRender()
