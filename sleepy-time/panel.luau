--!nonstrict
-- panel.luau — Sleepy Time native declarative setup & control panel

-- ── Local UI State ───────────────────────────────────────────────────────────

local uiState = {
    mode            = "countdown", -- "countdown" | "scheduled"
    selectedAction  = "lock",
    selectedMins    = 30,
    customDuration  = "30:00",
    targetTime      = "23:30",
    selectedProcess = "",
    customCmdText   = "",
    inputKey        = 0,
}

-- ── Action Definitions ───────────────────────────────────────────────────────

local ACTIONS = {
    { id = "lock",           labelKey = "action.lock",           glyph = "lock" },
    { id = "suspend",        labelKey = "action.suspend",        glyph = "moon" },
    { id = "shutdown",       labelKey = "action.shutdown",       glyph = "power" },
    { id = "reboot",         labelKey = "action.reboot",         glyph = "rotate" },
    { id = "logout",         labelKey = "action.logout",         glyph = "logout" },
    { id = "kill-process",   labelKey = "action.kill-process",   glyph = "square-x" },
    { id = "custom-command", labelKey = "action.custom-command", glyph = "terminal" },
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function parseTimeStringToSeconds(str: string): number?
    if not str or str == "" then return nil end
    local clean = string.gsub(str, "%s+", "")
    clean = string.gsub(clean, "[^0-9:]", "")
    if clean == "" then return nil end

    local parts = {}
    for p in string.gmatch(clean, "%d+") do
        table.insert(parts, tonumber(p))
    end

    if #parts == 1 then
        return parts[1] * 60
    elseif #parts == 2 then
        return (parts[1] * 60) + parts[2]
    elseif #parts >= 3 then
        return (parts[1] * 3600) + (parts[2] * 60) + parts[3]
    end
    return nil
end

local function formatDurationHuman(mins: number): string
    local h = math.floor(mins / 60)
    local m = mins % 60
    if h > 0 and m > 0 then
        return string.format("%d hr %d min", h, m)
    elseif h > 0 then
        return string.format("%d hr", h)
    else
        return string.format("%d min", m)
    end
end

local function calculatePreviewTime(targetHHMM: string): (number, boolean)
    local h, m = string.match(targetHHMM, "^(%d+):(%d+)")
    if not h or not m then return 0, false end
    local targetH = tonumber(h) or 0
    local targetM = tonumber(m) or 0

    local now = os.date("*t")
    local currentSecs = (now.hour * 3600) + (now.min * 60) + now.sec
    local targetSecs = (targetH * 3600) + (targetM * 60)

    local diff = targetSecs - currentSecs
    local isTomorrow = false
    if diff <= 0 then
        diff = diff + 86400
        isTomorrow = true
    end
    return diff, isTomorrow
end

local function formatPreviewDiff(secs: number): string
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    else
        return string.format("%dm", m)
    end
end

local function section(title: string, control: any, extraLabel: string?)
    local headerItems = {
        ui.label({ text = title, fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
    }
    if extraLabel and extraLabel ~= "" then
        table.insert(headerItems, ui.label({ text = extraLabel, fontSize = 12, fontWeight = "medium", color = "primary" }))
    end

    return ui.column({ gap = 8 }, {
        ui.row({ justify = "space_between", align = "center" }, headerItems),
        control,
    })
end

-- ── Setup View (Idle State) ──────────────────────────────────────────────────

local function renderSetupView(presets: { any }, processList: { any }, isProcessesLoaded: boolean)
    local items = {}

    -- 1. Mode Selector (using ui.select)
    local modeOptions = {
        noctalia.tr("mode.countdown"),
        noctalia.tr("mode.scheduled"),
    }
    local selectedModeIndex = if uiState.mode == "countdown" then 0 else 1

    table.insert(items, section(noctalia.tr("panel.mode-label"), ui.select({
        options = modeOptions,
        selectedIndex = selectedModeIndex,
        onChange = function(index)
            uiState.mode = if tonumber(index) == 0 then "countdown" else "scheduled"
            renderPanel()
        end,
    })))

    -- 2. Duration / Scheduled Target Controls
    if uiState.mode == "countdown" then
        local currentHuman = formatDurationHuman(uiState.selectedMins)

        -- Interactive Slider
        local sliderControl = ui.slider({
            min = 5,
            max = 240,
            step = 5,
            value = uiState.selectedMins,
            onChange = function(val)
                local mins = math.floor(tonumber(val) or 30)
                uiState.selectedMins = mins
                uiState.customDuration = string.format("%d:00", mins)
                uiState.inputKey = uiState.inputKey + 1
                renderPanel()
            end,
        })

        -- Quick Preset Jump Pills
        local presetPills = {}
        for _, p in ipairs(presets) do
            local isSel = (uiState.selectedMins == p.minutes)
            table.insert(presetPills, ui.button({
                text = p.label,
                variant = if isSel then "primary" else "ghost",
                onClick = function()
                    uiState.selectedMins = p.minutes
                    uiState.customDuration = string.format("%d:00", p.minutes)
                    uiState.inputKey = uiState.inputKey + 1
                    renderPanel()
                end,
                flexGrow = 1,
            }))
        end

        table.insert(items, section(noctalia.tr("panel.duration-header"), ui.column({ gap = 8 }, {
            sliderControl,
            ui.row({ gap = 4, justify = "space_between", align = "center" }, presetPills),
        }), currentHuman))

    else
        -- Scheduled Time (HH:MM)
        local diffSecs, isTomorrow = calculatePreviewTime(uiState.targetTime)
        local previewText = if isTomorrow then noctalia.tr("panel.time-preview-tomorrow", { time = formatPreviewDiff(diffSecs) })
                            else noctalia.tr("panel.time-preview", { time = formatPreviewDiff(diffSecs) })

        table.insert(items, section(noctalia.tr("panel.target-time"), ui.input({
            key = "target-time-" .. uiState.inputKey,
            value = uiState.targetTime,
            placeholder = noctalia.tr("panel.target-time-placeholder"),
            onChange = function(val)
                uiState.targetTime = val
            end,
        }), previewText))
    end

    -- 3. Action Selector (using ui.select)
    local actionOptions = {}
    local selectedActionIndex = 0
    for i, act in ipairs(ACTIONS) do
        table.insert(actionOptions, noctalia.tr(act.labelKey))
        if uiState.selectedAction == act.id then
            selectedActionIndex = i - 1
        end
    end

    table.insert(items, section(noctalia.tr("panel.action-label"), ui.select({
        options = actionOptions,
        selectedIndex = selectedActionIndex,
        onChange = function(index)
            local idx = (tonumber(index) or 0) + 1
            if ACTIONS[idx] then
                uiState.selectedAction = ACTIONS[idx].id
                if ACTIONS[idx].id == "kill-process" then
                    noctalia.state.set("sleepy.cmd", { action = "fetchProcesses" })
                end
                renderPanel()
            end
        end,
    })))

    -- 4. Dynamic Target Parameters (Kill Process or Custom Command)
    if uiState.selectedAction == "kill-process" then
        local procOptions = { "-- Type custom or select --" }
        local selectedProcIndex = 0

        for i, proc in ipairs(processList) do
            table.insert(procOptions, proc.name)
            if uiState.selectedProcess == proc.name then
                selectedProcIndex = i
            end
        end

        local procControls = {
            ui.select({
                options = procOptions,
                selectedIndex = selectedProcIndex,
                onChange = function(index, text)
                    local idx = tonumber(index) or 0
                    if idx > 0 and processList[idx] then
                        uiState.selectedProcess = processList[idx].name
                    else
                        uiState.selectedProcess = ""
                    end
                    uiState.inputKey = uiState.inputKey + 1
                    renderPanel()
                end,
            }),
            ui.input({
                key = "proc-input-" .. uiState.inputKey,
                value = uiState.selectedProcess,
                placeholder = "Or type custom process name (e.g. spotify)",
                onChange = function(val)
                    uiState.selectedProcess = val
                end,
            }),
        }

        if not isProcessesLoaded then
            table.insert(procControls, ui.label({ text = noctalia.tr("panel.process-loading"), fontSize = 11, color = "on_surface_variant" }))
        end

        table.insert(items, section(noctalia.tr("panel.process-label"), ui.column({ gap = 8 }, procControls)))

    elseif uiState.selectedAction == "custom-command" then
        table.insert(items, section(noctalia.tr("settings.custom_command.label"), ui.input({
            key = "custom-cmd-" .. uiState.inputKey,
            value = uiState.customCmdText,
            placeholder = "e.g. notify-send 'Timer Finished'",
            onChange = function(val)
                uiState.customCmdText = val
            end,
        })))
    end

    -- 5. Bottom Start Button
    local startButton = ui.row({ justify = "end", align = "center" }, {
        ui.button({
            text = noctalia.tr("button.start"),
            glyph = "player-play",
            variant = "primary",
            controlSize = "md",
            onClick = function()
                local act = uiState.selectedAction
                local target = if act == "kill-process" then uiState.selectedProcess else uiState.customCmdText

                if uiState.mode == "scheduled" then
                    noctalia.state.set("sleepy.cmd", {
                        action       = "start",
                        mode         = "scheduled",
                        targetTime   = uiState.targetTime,
                        targetAction = act,
                        targetParam  = target,
                    })
                else
                    local secs = uiState.selectedMins * 60
                    local parsed = parseTimeStringToSeconds(uiState.customDuration)
                    if parsed and parsed > 0 then
                        secs = parsed
                    end
                    noctalia.state.set("sleepy.cmd", {
                        action       = "start",
                        mode         = "countdown",
                        seconds      = secs,
                        targetAction = act,
                        targetParam  = target,
                    })
                end

                panel.close()
            end,
        }),
    })

    return ui.column({ flexGrow = 1, gap = 12 }, {
        ui.scroll({ flexGrow = 1, gap = 14 }, items),
        startButton,
    })
end

-- ── Active View (Running / Paused / Warning State) ───────────────────────────

local function renderActiveView(state: any)
    local isPaused = (state.status == "PAUSED")
    local isWarning = (state.status == "WARNING" or state.warningActive == true)
    local secsLeft = state.remaining or 0
    local totalSecs = state.duration or 1
    local progressRatio = if totalSecs > 0 then math.max(0, math.min(1, 1 - (secsLeft / totalSecs))) else 0
    local pctText = string.format("%d%%", math.floor(progressRatio * 100))

    local accentColor = if isWarning then "error" elseif isPaused then "warning" else "primary"
    local actName = noctalia.tr("action." .. (state.action or "lock"))

    -- Big Digital Readout Card
    local displayCard = ui.column({ align = "center", gap = 12, padding = 16, fill = "surface_variant/0.4", radius = 16 }, {
        ui.label({
            text = state.formattedTime or "00:00",
            fontSize = 44,
            fontWeight = "bold",
            color = accentColor,
        }),
        ui.progress({
            progress = progressRatio,
            fill = accentColor,
            height = 8,
            radius = 4,
            width = 300,
        }),
        ui.row({ justify = "space_between", align = "center", flexGrow = 1 }, {
            ui.row({ gap = 6, align = "center" }, {
                ui.glyph({ name = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "moon-stars", size = 16, color = accentColor }),
                ui.label({ text = actName, fontSize = 13, fontWeight = "medium", color = "on_surface" }),
            }),
            ui.label({ text = pctText, fontSize = 13, color = "on_surface_variant" }),
        }),
    })

    -- Playback Controls Row
    local controlsRow = ui.row({ gap = 8, align = "center" }, {
        ui.button({
            text = if isPaused then noctalia.tr("button.resume") else noctalia.tr("button.pause"),
            glyph = if isPaused then "player-play" else "player-pause",
            variant = "primary",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = if isPaused then "resume" else "pause" })
            end,
            flexGrow = 1,
        }),
        ui.button({
            text = noctalia.tr("button.add-time"),
            variant = "secondary",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = 300 })
            end,
        }),
        ui.button({
            text = noctalia.tr("button.subtract-time"),
            variant = "secondary",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = -300 })
            end,
        }),
        ui.button({
            text = noctalia.tr("button.cancel"),
            glyph = "x",
            variant = "destructive",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "cancel" })
            end,
        }),
    })

    return ui.column({ flexGrow = 1, justify = "space_between", gap = 16 }, {
        displayCard,
        controlsRow,
    })
end

-- ── Root Panel Renderer ──────────────────────────────────────────────────────

function renderPanel()
    local state = noctalia.state.get("sleepy.state") or { status = "IDLE", remaining = 0, duration = 0 }
    local presets = noctalia.state.get("sleepy.presets") or {}
    local processList = noctalia.state.get("sleepy.processes") or {}
    local isProcessesLoaded = (noctalia.state.get("sleepy.processesLoaded") == true)

    local isRunning = (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING")

    -- Panel Header
    local headerRow = ui.row({ align = "center", justify = "space_between", gap = 8 }, {
        ui.row({ align = "center", gap = 8 }, {
            ui.glyph({ name = "moon-stars", size = 20, color = "primary" }),
            ui.label({ text = noctalia.tr("panel.title"), fontSize = 16, fontWeight = "bold", color = "on_surface" }),
        }),
        ui.button({
            glyph = "close",
            variant = "ghost",
            onClick = function()
                panel.close()
            end,
        }),
    })

    local content
    if isRunning then
        content = renderActiveView(state)
    else
        content = renderSetupView(presets, processList, isProcessesLoaded)
    end

    panel.render(
        ui.column({ flexGrow = 1, gap = 12 }, {
            headerRow,
            content,
        })
    )
end

-- ── Lifecycle & Event Listeners ──────────────────────────────────────────────

function onOpen(_context)
    local state = noctalia.state.get("sleepy.state")
    if state and state.action then
        uiState.selectedAction = state.action
    end
    noctalia.state.set("sleepy.cmd", { action = "fetchProcesses" })
    renderPanel()
end

noctalia.state.watch("sleepy.state", function(_state)
    renderPanel()
end)

noctalia.state.watch("sleepy.processes", function(_processes)
    renderPanel()
end)

noctalia.state.watch("sleepy.processesLoaded", function(_loaded)
    renderPanel()
end)

-- Initial render
renderPanel()
