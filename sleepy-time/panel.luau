--!nonstrict
-- panel.luau — Sleepy Time interactive setup & control panel

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

local function chunkIntoGrid(items: { any }, maxPerRow: number)
    local rows = {}
    local row = {}
    for i, item in ipairs(items) do
        table.insert(row, item)
        if #row >= maxPerRow or i == #items then
            table.insert(rows, ui.row({ gap = 6, align = "center" }, row))
            row = {}
        end
    end
    return ui.column({ gap = 6 }, rows)
end

-- ── Action Definition Table ──────────────────────────────────────────────────

local ACTIONS = {
    { id = "lock",           labelKey = "action.lock",           glyph = "lock" },
    { id = "suspend",        labelKey = "action.suspend",        glyph = "moon" },
    { id = "shutdown",       labelKey = "action.shutdown",       glyph = "power" },
    { id = "reboot",         labelKey = "action.reboot",         glyph = "rotate" },
    { id = "logout",         labelKey = "action.logout",         glyph = "logout" },
    { id = "kill-process",   labelKey = "action.kill-process",   glyph = "skull" },
    { id = "custom-command", labelKey = "action.custom-command", glyph = "terminal" },
}

-- ── Panel Render Functions ───────────────────────────────────────────────────

local function renderSetupView(presets: { any }, processList: { any })
    local sections = {}

    -- 1. Mode Switcher
    local modeSelector = ui.row({ gap = 8, justify = "center" }, {
        ui.button({
            text = noctalia.tr("mode.countdown"),
            glyph = "timer",
            variant = if uiState.mode == "countdown" then "primary" else "secondary",
            onClick = function()
                uiState.mode = "countdown"
                renderPanel()
            end,
            flexGrow = 1,
        }),
        ui.button({
            text = noctalia.tr("mode.scheduled"),
            glyph = "clock",
            variant = if uiState.mode == "scheduled" then "primary" else "secondary",
            onClick = function()
                uiState.mode = "scheduled"
                renderPanel()
            end,
            flexGrow = 1,
        }),
    })
    table.insert(sections, modeSelector)

    -- 2. Duration / Schedule Controls
    if uiState.mode == "countdown" then
        -- Quick Presets
        local presetButtons = {}
        for _, item in ipairs(presets) do
            local mins = item.minutes
            local isSelected = (uiState.selectedMins == mins)
            table.insert(presetButtons, ui.button({
                text = item.label,
                variant = if isSelected then "primary" else "secondary",
                onClick = function()
                    uiState.selectedMins = mins
                    uiState.customDuration = string.format("%d:00", mins)
                    uiState.inputKey = uiState.inputKey + 1
                    renderPanel()
                end,
                flexGrow = 1,
            }))
        end

        table.insert(sections, ui.column({ gap = 6 }, {
            ui.label({ text = noctalia.tr("panel.quick-timers"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
            chunkIntoGrid(presetButtons, 4),
        }))

        -- Custom Duration Input
        table.insert(sections, ui.column({ gap = 6 }, {
            ui.label({ text = noctalia.tr("panel.custom-duration"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
            ui.input({
                key = "custom-dur-" .. uiState.inputKey,
                value = uiState.customDuration,
                placeholder = noctalia.tr("panel.custom-duration-placeholder"),
                onChange = function(val)
                    uiState.customDuration = val
                    uiState.selectedMins = 0
                end,
            }),
        }))
    else
        -- At Time Input
        local diffSecs, isTomorrow = calculatePreviewTime(uiState.targetTime)
        local previewText = if isTomorrow then noctalia.tr("panel.time-preview-tomorrow", { time = formatPreviewDiff(diffSecs) })
                            else noctalia.tr("panel.time-preview", { time = formatPreviewDiff(diffSecs) })

        table.insert(sections, ui.column({ gap = 6 }, {
            ui.row({ justify = "space_between", align = "center" }, {
                ui.label({ text = noctalia.tr("panel.target-time"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
                ui.label({ text = previewText, fontSize = 12, color = "primary" }),
            }),
            ui.input({
                key = "target-time-" .. uiState.inputKey,
                value = uiState.targetTime,
                placeholder = noctalia.tr("panel.target-time-placeholder"),
                onChange = function(val)
                    uiState.targetTime = val
                end,
            }),
        }))
    end

    -- 3. Action Selector Grid
    local actionButtons = {}
    for _, act in ipairs(ACTIONS) do
        local isSelected = (uiState.selectedAction == act.id)
        table.insert(actionButtons, ui.button({
            text = noctalia.tr(act.labelKey),
            glyph = act.glyph,
            variant = if isSelected then "primary" else "secondary",
            onClick = function()
                uiState.selectedAction = act.id
                if act.id == "kill-process" then
                    noctalia.state.set("sleepy.cmd", { action = "fetchProcesses" })
                end
                renderPanel()
            end,
            flexGrow = 1,
        }))
    end

    table.insert(sections, ui.column({ gap = 6 }, {
        ui.label({ text = noctalia.tr("panel.action-label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
        chunkIntoGrid(actionButtons, 3),
    }))

    -- 4. Target Details (for Kill App or Custom Command)
    if uiState.selectedAction == "kill-process" then
        local procButtons = {}
        local maxShow = 6
        for i, proc in ipairs(processList) do
            if i <= maxShow then
                local isProcSelected = (uiState.selectedProcess == proc.name)
                table.insert(procButtons, ui.button({
                    text = proc.name,
                    variant = if isProcSelected then "primary" else "secondary",
                    onClick = function()
                        uiState.selectedProcess = proc.name
                        renderPanel()
                    end,
                    flexGrow = 1,
                }))
            end
        end

        local procBody
        if #procButtons > 0 then
            procBody = chunkIntoGrid(procButtons, 2)
        elseif #processList == 0 then
            procBody = ui.label({ text = noctalia.tr("panel.process-loading"), fontSize = 11, color = "on_surface_variant" })
        else
            procBody = ui.label({ text = noctalia.tr("panel.process-empty"), fontSize = 11, color = "on_surface_variant" })
        end

        table.insert(sections, ui.column({ gap = 6 }, {
            ui.label({ text = noctalia.tr("panel.process-label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
            procBody,
        }))

    elseif uiState.selectedAction == "custom-command" then
        table.insert(sections, ui.column({ gap = 6 }, {
            ui.label({ text = noctalia.tr("settings.custom_command.label"), fontSize = 12, fontWeight = "medium", color = "on_surface_variant" }),
            ui.input({
                key = "custom-cmd-" .. uiState.inputKey,
                value = uiState.customCmdText,
                placeholder = "e.g. notify-send 'Timer Finished'",
                onChange = function(val)
                    uiState.customCmdText = val
                end,
            }),
        }))
    end

    -- 5. Start Button
    local startButton = ui.button({
        text = noctalia.tr("button.start"),
        glyph = "player-play",
        variant = "primary",
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

            -- Automatically close panel on start
            panel.close()
        end,
        flexGrow = 1,
    })

    return ui.column({ flexGrow = 1, gap = 12 }, {
        ui.scroll({ flexGrow = 1, gap = 12 }, sections),
        startButton,
    })
end

local function renderActiveView(state: any)
    local isPaused = (state.status == "PAUSED")
    local isWarning = (state.status == "WARNING" or state.warningActive == true)
    local secsLeft = state.remaining or 0
    local totalSecs = state.duration or 1
    local progressRatio = if totalSecs > 0 then math.max(0, math.min(1, 1 - (secsLeft / totalSecs))) else 0
    local pctText = string.format("%d%%", math.floor(progressRatio * 100))

    local accentColor = if isWarning then "error" elseif isPaused then "warning" else "primary"
    local actName = noctalia.tr("action." .. (state.action or "lock"))

    -- Big Countdown & Progress Section
    local displayCard = ui.column({ align = "center", gap = 10, padding = 16, fill = "surface_variant/0.4", radius = 16 }, {
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

    -- Playback Controls
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

    local isRunning = (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING")

    -- Top Header
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
        content = renderSetupView(presets, processList)
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

-- Initial render
renderPanel()
