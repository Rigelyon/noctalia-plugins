--!nonstrict
-- panel.luau — Sleepy Time setup and control panel

local timeFontFamily = noctalia.loadFont("JetBrainsMono-Regular.ttf")

-- Local transient UI state
local uiState = {
    mode             = "countdown", -- "countdown" | "scheduled"
    selectedAction   = "lock",
    customDuration   = "30:00",     -- MM:SS or HH:MM:SS
    targetTime       = "23:00",     -- HH:MM
    selectedProcess  = "",
    customCmdText    = "",
    processFilter    = "",
}

local function formatTimeDisplay(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function parseTimeStringToSeconds(str)
    if not str or str == "" then return nil end
    local parts = {}
    for p in string.gmatch(str, "%d+") do
        table.insert(parts, tonumber(p))
    end
    if #parts == 1 then
        return parts[1] * 60
    elseif #parts == 2 then
        return parts[1] * 60 + parts[2]
    elseif #parts == 3 then
        return parts[1] * 3600 + parts[2] * 60 + parts[3]
    end
    return nil
end

-- Handlers called by UI callbacks

function onOpen(context)
    local state = noctalia.state.get("sleepy.state")
    if state and state.action then
        uiState.selectedAction = state.action
    end
    -- Trigger process list refresh
    noctalia.state.set("sleepy.command", { action = "fetchProcesses" })
    renderPanel()
end

function onModeSelect(newMode)
    uiState.mode = newMode
    renderPanel()
end

function onActionSelect(newAction)
    uiState.selectedAction = newAction
    if newAction == "kill-process" then
        noctalia.state.set("sleepy.command", { action = "fetchProcesses" })
    end
    renderPanel()
end

function onPresetClick(mins)
    uiState.mode = "countdown"
    local secs = mins * 60
    local state = noctalia.state.get("sleepy.state")
    local act = uiState.selectedAction or "lock"
    local target = if act == "kill-process" then uiState.selectedProcess else uiState.customCmdText

    noctalia.state.set("sleepy.command", {
        action       = "start",
        mode         = "countdown",
        seconds      = secs,
        targetAction = act,
        targetParam  = target,
    })
end

function onStartClick()
    local act = uiState.selectedAction or "lock"
    local target = if act == "kill-process" then uiState.selectedProcess else uiState.customCmdText

    if uiState.mode == "scheduled" then
        noctalia.state.set("sleepy.command", {
            action       = "start",
            mode         = "scheduled",
            targetTime   = uiState.targetTime,
            targetAction = act,
            targetParam  = target,
        })
    else
        local secs = parseTimeStringToSeconds(uiState.customDuration) or 1800
        noctalia.state.set("sleepy.command", {
            action       = "start",
            mode         = "countdown",
            seconds      = secs,
            targetAction = act,
            targetParam  = target,
        })
    end
end

function onPauseClick()
    noctalia.state.set("sleepy.command", { action = "pause" })
end

function onResumeClick()
    noctalia.state.set("sleepy.command", { action = "resume" })
end

function onCancelClick()
    noctalia.state.set("sleepy.command", { action = "cancel" })
end

function onAddTimeClick()
    noctalia.state.set("sleepy.command", { action = "addTime", seconds = 300 })
end

function onSubtractTimeClick()
    noctalia.state.set("sleepy.command", { action = "addTime", seconds = -300 })
end

function onProcessSelect(procName)
    uiState.selectedProcess = procName
    renderPanel()
end

-- Panel UI Renderer

function renderPanel()
    local state = noctalia.state.get("sleepy.state") or { isRunning = false, secondsLeft = 0, totalSeconds = 0 }
    local presets = noctalia.state.get("sleepy.presets") or {}
    local processList = noctalia.state.get("sleepy.processList") or {}

    local isRunning = state.isRunning == true
    local isPaused  = state.isPaused == true
    local isWarning = state.warningActive == true

    -- Header row
    local headerRow = ui.row({ align = "center", justify = "space_between" }, {
        ui.row({ align = "center", gap = 8 }, {
            ui.glyph({ name = "moon-stars", size = 20, color = "primary" }),
            ui.label({ text = noctalia.tr("panel.title"), fontSize = 18, fontWeight = "bold", color = "on_surface" }),
        }),
        ui.label({
            text = if isRunning then (if isPaused then "⏸ Paused" elseif isWarning then "⚠️ Warning" else "⏱ Running") else "💤 Idle",
            fontSize = 12,
            fontWeight = "medium",
            color = if isWarning then "error" elseif isPaused then "warning" elseif isRunning then "primary" else "on_surface_variant",
        })
    })

    -- Display Section (Live Timer or Duration Preview)
    local displaySection
    if isRunning then
        local progressRatio = if state.totalSeconds > 0 then (1 - (state.secondsLeft / state.totalSeconds)) else 0
        local pctText = string.format("%d%%", math.floor(progressRatio * 100))

        displaySection = ui.column({ align = "center", gap = 8, padding = 12 }, {
            ui.label({
                text = formatTimeDisplay(state.secondsLeft),
                fontSize = 44,
                fontWeight = "bold",
                fontFamily = timeFontFamily,
                color = if isWarning then "error" elseif isPaused then "warning" else "primary",
            }),
            ui.progress({
                value = progressRatio,
                color = if isWarning then "error" elseif isPaused then "warning" else "primary",
                flexGrow = 1,
            }),
            ui.row({ justify = "space_between", align = "center" }, {
                ui.label({
                    text = noctalia.tr("action." .. (state.action or "lock")),
                    fontSize = 12,
                    fontWeight = "medium",
                    color = "on_surface_variant",
                }),
                ui.label({
                    text = pctText,
                    fontSize = 12,
                    color = "on_surface_variant",
                }),
            }),
        })
    else
        -- Idle mode setup
        displaySection = ui.column({ align = "center", gap = 4, padding = 8 }, {
            ui.label({
                text = "Set Sleep Timer",
                fontSize = 16,
                fontWeight = "medium",
                color = "on_surface",
            }),
            ui.label({
                text = "Choose a preset, set custom duration, or schedule a target time",
                fontSize = 12,
                color = "on_surface_variant",
            }),
        })
    end

    -- Controls & Presets Section (only when not running or as preset selector)
    local setupControls = {}

    if not isRunning then
        -- Mode toggle buttons
        local modeRow = ui.row({ gap = 8, justify = "center" }, {
            ui.button({
                text = "⏱ Countdown",
                variant = if uiState.mode == "countdown" then "primary" else "secondary",
                onClick = function() onModeSelect("countdown") end,
                flexGrow = 1,
            }),
            ui.button({
                text = "🕐 At Time",
                variant = if uiState.mode == "scheduled" then "primary" else "secondary",
                onClick = function() onModeSelect("scheduled") end,
                flexGrow = 1,
            }),
        })
        table.insert(setupControls, modeRow)

        -- Quick Presets Grid (in countdown mode)
        if uiState.mode == "countdown" and #presets > 0 then
            local presetButtons = {}
            for _, item in ipairs(presets) do
                table.insert(presetButtons, ui.button({
                    text = item.label,
                    variant = "secondary",
                    onClick = function() onPresetClick(item.minutes) end,
                }))
            end
            table.insert(setupControls, ui.column({ gap = 4 }, {
                ui.label({ text = noctalia.tr("panel.quick-timers"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
                ui.row({ gap = 6, flexWrap = true }, presetButtons),
            }))
        end

        -- Action dropdown selector
        local actionOptions = {
          { value = "lock", label = "🔒  " .. noctalia.tr("action.lock") },
          { value = "suspend", label = "🌙  " .. noctalia.tr("action.suspend") },
          { value = "shutdown", label = "⏻  " .. noctalia.tr("action.shutdown") },
          { value = "reboot", label = "🔄  " .. noctalia.tr("action.reboot") },
          { value = "logout", label = "🚪  " .. noctalia.tr("action.logout") },
          { value = "kill-process", label = "☠️  " .. noctalia.tr("action.kill-process") },
          { value = "custom-command", label = "⌨️  " .. noctalia.tr("action.custom-command") },
        }

        local actionSelect = ui.column({ gap = 4 }, {
            ui.label({ text = noctalia.tr("panel.action-label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
            ui.select({
                value = uiState.selectedAction,
                options = actionOptions,
                onChange = "onActionSelect",
            }),
        })
        table.insert(setupControls, actionSelect)

        -- Extra Target Input (Process picker or Custom command string)
        if uiState.selectedAction == "kill-process" then
            local procRows = {}
            local limit = 0
            for _, proc in ipairs(processList) do
                if limit < 6 then
                    limit = limit + 1
                    local pName = proc.name
                    table.insert(procRows, ui.button({
                        text = pName .. " (PID " .. proc.pid .. ")",
                        variant = if uiState.selectedProcess == pName then "primary" else "secondary",
                        onClick = function() onProcessSelect(pName) end,
                    }))
                end
            end
            table.insert(setupControls, ui.column({ gap = 4 }, {
                ui.label({ text = noctalia.tr("panel.process-label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
                ui.column({ gap = 4 }, procRows),
            }))
        elseif uiState.selectedAction == "custom-command" then
            table.insert(setupControls, ui.column({ gap = 4 }, {
                ui.label({ text = noctalia.tr("settings.custom_command.label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
                ui.input({
                    value = uiState.customCmdText,
                    placeholder = "e.g., notify-send 'Timer Done'",
                    onChange = function(val) uiState.customCmdText = val end,
                }),
            }))
        end
    end

    -- Bottom Action Button Bar
    local actionButtons
    if isRunning then
        actionButtons = ui.row({ gap = 8 }, {
            ui.button({
                text = if isPaused then noctalia.tr("button.resume") else noctalia.tr("button.pause"),
                glyph = if isPaused then "player-play" else "player-pause",
                variant = "primary",
                onClick = if isPaused then "onResumeClick" else "onPauseClick",
                flexGrow = 1,
            }),
            ui.button({
                text = noctalia.tr("button.add-time"),
                variant = "secondary",
                onClick = "onAddTimeClick",
            }),
            ui.button({
                text = noctalia.tr("button.subtract-time"),
                variant = "secondary",
                onClick = "onSubtractTimeClick",
            }),
            ui.button({
                text = noctalia.tr("button.cancel"),
                glyph = "x",
                variant = "secondary",
                onClick = "onCancelClick",
            }),
        })
    else
        actionButtons = ui.button({
            text = "▶ " .. noctalia.tr("button.start"),
            variant = "primary",
            onClick = "onStartClick",
            flexGrow = 1,
        })
    end

    -- Assemble full panel column
    panel.render(
        ui.column({ flexGrow = 1, gap = 14, padding = 16 }, {
            headerRow,
            displaySection,
            ui.column({ gap = 10, flexGrow = 1 }, setupControls),
            actionButtons,
        })
    )
end

-- Render when state updates
noctalia.state.watch("sleepy.state", function(state)
    renderPanel()
end)

noctalia.state.watch("sleepy.processList", function(list)
    renderPanel()
end)

-- Initial render
renderPanel()
