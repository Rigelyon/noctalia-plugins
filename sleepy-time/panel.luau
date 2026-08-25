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

local function calculatePreviewTime(targetHHMM: string): (number?, boolean)
    if not targetHHMM or targetHHMM == "" then return nil, false end
    local clean = string.gsub(targetHHMM, "%s+", "")
    
    local h, m = string.match(clean, "^(%d+)[%.:](%d+)$")
    if not h or not m then
        local d4_h, d4_m = string.match(clean, "^(%d%d)(%d%d)$")
        if d4_h and d4_m then
            h, m = d4_h, d4_m
        else
            local single = string.match(clean, "^(%d+)$")
            if single then
                local sNum = tonumber(single) or 0
                if sNum <= 24 then
                    h, m = single, "0"
                end
            end
        end
    end

    if not h or not m then return nil, false end
    local targetH = tonumber(h) or 0
    local targetM = tonumber(m) or 0
    if targetH > 24 or targetM >= 60 then return nil, false end
    if targetH == 24 then targetH = 0 end

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

local function formatPreviewDiff(secs: number?): string
    if not secs then return "" end
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    if h > 0 and m > 0 then
        return string.format("%dh %dm", h, m)
    elseif h > 0 then
        return string.format("%dh", h)
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
        onChange = function(val, extra)
            if val == 1 or val == "1" or val == noctalia.tr("mode.scheduled") or extra == noctalia.tr("mode.scheduled") then
                uiState.mode = "scheduled"
            else
                uiState.mode = "countdown"
            end
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
        local previewText = ""
        if diffSecs then
            previewText = if isTomorrow then noctalia.tr("panel.time-preview-tomorrow", { time = formatPreviewDiff(diffSecs) })
                          else noctalia.tr("panel.time-preview", { time = formatPreviewDiff(diffSecs) })
        end

        table.insert(items, section(noctalia.tr("panel.target-time"), ui.input({
            key = "target-time-" .. uiState.inputKey,
            value = uiState.targetTime,
            placeholder = noctalia.tr("panel.target-time-placeholder"),
            onChange = function(val)
                uiState.targetTime = val
                renderPanel()
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
        onChange = function(arg1, arg2)
            local selectedActId = nil

            -- 1. Try if arg1 is numeric index (0-indexed or 1-indexed)
            local num = tonumber(arg1)
            if num ~= nil then
                if ACTIONS[num + 1] then
                    selectedActId = ACTIONS[num + 1].id
                elseif ACTIONS[num] then
                    selectedActId = ACTIONS[num].id
                end
            end

            -- 2. Try if arg1 is a string matching label or id
            if not selectedActId and type(arg1) == "string" then
                for _, act in ipairs(ACTIONS) do
                    if act.id == arg1 or noctalia.tr(act.labelKey) == arg1 or string.find(arg1, act.id) then
                        selectedActId = act.id
                        break
                    end
                end
            end

            -- 3. Try if arg2 is a string matching label or id
            if not selectedActId and type(arg2) == "string" then
                for _, act in ipairs(ACTIONS) do
                    if act.id == arg2 or noctalia.tr(act.labelKey) == arg2 or string.find(arg2, act.id) then
                        selectedActId = act.id
                        break
                    end
                end
            end

            if selectedActId then
                uiState.selectedAction = selectedActId
                if selectedActId == "kill-process" then
                    noctalia.state.set("sleepy.cmd", { action = "fetchProcesses" })
                end
                renderPanel()
            end
        end,
    })))

    -- 4. Dynamic Target Parameters (Kill Process or Custom Command)
    if uiState.selectedAction == "kill-process" then
        local procCards = {}
        local rawProc = uiState.selectedProcess or ""
        local filterText = string.lower(noctalia.string.trim(rawProc))

        if type(processList) == "table" then
            local limit = 20
            local count = 0
            for _, proc in ipairs(processList) do
                if type(proc) == "table" and proc.name and type(proc.name) == "string" then
                    local procName = proc.name
                    local matches = (filterText == "" or string.find(string.lower(procName), filterText, 1, true) ~= nil or rawProc == procName)
                    if matches then
                        count = count + 1
                        if count <= limit then
                            local isSelected = (rawProc == procName)

                            local iconNode
                            if proc.iconPath and type(proc.iconPath) == "string" and proc.iconPath ~= "" then
                                iconNode = ui.image({ path = proc.iconPath, width = 18, height = 18 })
                            else
                                iconNode = ui.glyph({ name = "app-window", size = 18, color = if isSelected then "primary" else "on_surface_variant" })
                            end

                            table.insert(procCards, ui.row({
                                gap = 8,
                                align = "center",
                                padding = 8,
                                radius = 10,
                                fill = if isSelected then "primary/0.2" else "surface_variant/0.3",
                                onClick = function()
                                    uiState.selectedProcess = procName
                                    uiState.inputKey = uiState.inputKey + 1
                                    renderPanel()
                                end,
                                flexGrow = 1,
                            }, {
                                iconNode,
                                ui.label({
                                    text = procName,
                                    fontSize = 12,
                                    fontWeight = if isSelected then "bold" else "normal",
                                    color = if isSelected then "primary" else "on_surface",
                                }),
                            }))
                        end
                    end
                end
            end
        end

        local procControls = {
            ui.input({
                key = "proc-input-" .. uiState.inputKey,
                value = uiState.selectedProcess,
                placeholder = "Search app or type process (e.g. spotify, steam)",
                onChange = function(val)
                    uiState.selectedProcess = val or ""
                    renderPanel()
                end,
            }),
        }

        if #procCards > 0 then
            table.insert(procControls, chunkIntoGrid(procCards, 2))
        elseif not isProcessesLoaded then
            table.insert(procControls, ui.label({ text = noctalia.tr("panel.process-loading"), fontSize = 11, color = "on_surface_variant" }))
        else
            table.insert(procControls, ui.label({ text = noctalia.tr("panel.process-empty"), fontSize = 11, color = "on_surface_variant" }))
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
    local ok, err = pcall(function()
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
    end)

    if not ok and err then
        noctalia.log("Sleepy Time panel render error: " .. tostring(err))
    end
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
