--!nonstrict
-- panel.luau — Sleepy Time native declarative setup & control panel

-- ── Local UI State ───────────────────────────────────────────────────────────

local uiState = {
    mode              = "countdown", -- "countdown" | "scheduled"
    selectedAction    = "lock",
    selectedMins      = 30,
    customDuration    = "30:00",
    targetTime        = "23:30",
    selectedProcesses = {} :: { string },
    procSearchQuery   = "",
    customCmdText     = "",
    inputKey          = 0,
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
    local mTotal = math.max(0, math.floor(mins))
    local h = math.floor(mTotal / 60)
    local m = mTotal % 60
    if h > 0 and m > 0 then
        return string.format("%d hr %d min", h, m)
    elseif h > 0 then
        return string.format("%d hr", h)
    elseif m > 0 then
        return string.format("%d min", m)
    else
        return "< 1 min"
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

local function parseProcessSet(str: string): ({ [string]: boolean }, { string })
    local set = {}
    local list = {}
    if not str or str == "" then return set, list end
    for item in string.gmatch(str, "([^,]+)") do
        local clean = noctalia.string.trim(item)
        if clean ~= "" and not set[clean] then
            set[clean] = true
            table.insert(list, clean)
        end
    end
    return set, list
end

local function formatProcessList(list: { string }): string
    return table.concat(list, ", ")
end

local function getSelectedProcessSet(): { [string]: boolean }
    local set = {}
    for _, name in ipairs(uiState.selectedProcesses) do
        set[name] = true
    end
    return set
end

local function toggleProcessSelection(procName: string)
    local foundIndex = nil
    for i, name in ipairs(uiState.selectedProcesses) do
        if name == procName then
            foundIndex = i
            break
        end
    end
    if foundIndex then
        table.remove(uiState.selectedProcesses, foundIndex)
    else
        table.insert(uiState.selectedProcesses, procName)
    end
    renderPanel()
end

local function formatTargetSummary(targetStr: string, maxItems: number?): string
    if not targetStr or targetStr == "" then return "" end
    local max = maxItems or 1
    local items = {}
    for item in string.gmatch(targetStr, "([^,]+)") do
        local clean = noctalia.string.trim(item)
        if clean ~= "" then
            table.insert(items, clean)
        end
    end
    if #items == 0 then return "" end
    if #items == 1 then return items[1] end
    if #items <= max then return table.concat(items, ", ") end
    local remaining = #items - max
    local prefix = {}
    for i = 1, max do
        table.insert(prefix, items[i])
    end
    return table.concat(prefix, ", ") .. string.format(" (+%d more)", remaining)
end

local function chunkIntoGrid(items: { any }, cols: number)
    local rows = {}
    local currentRow = {}
    for i, item in ipairs(items) do
        table.insert(currentRow, item)
        if #currentRow == cols or i == #items then
            if #currentRow < cols then
                for _ = 1, cols - #currentRow do
                    table.insert(currentRow, ui.box({ flexGrow = 1 }))
                end
            end
            table.insert(rows, ui.row({ gap = 8, justify = "space_between", align = "center" }, currentRow))
            currentRow = {}
        end
    end
    return ui.column({ gap = 6 }, rows)
end

local function section(title: string, control: any, extraLabel: (string | any)?)
    local headerItems = {
        ui.label({ text = title, fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
    }
    if extraLabel then
        if type(extraLabel) == "string" and extraLabel ~= "" then
            table.insert(headerItems, ui.label({ text = extraLabel, fontSize = 12, fontWeight = "medium", color = "primary" }))
        elseif type(extraLabel) == "table" then
            table.insert(headerItems, extraLabel)
        end
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
        local procCards = {}
        local filterText = string.lower(noctalia.string.trim(uiState.procSearchQuery))
        local selectedSet = getSelectedProcessSet()

        if type(processList) == "table" then
            local limit = 16
            local count = 0
            for _, proc in ipairs(processList) do
                if type(proc) == "table" and proc.name and type(proc.name) == "string" then
                    local procName = proc.name
                    local isSelected = (selectedSet[procName] == true)
                    local matches = (filterText == "" or string.find(string.lower(procName), filterText, 1, true) ~= nil)
                    if matches then
                        count = count + 1
                        if count <= limit then
                            local iconNode
                            if proc.iconPath and type(proc.iconPath) == "string" and proc.iconPath ~= "" then
                                iconNode = ui.image({ path = proc.iconPath, width = 18, height = 18 })
                            else
                                iconNode = ui.glyph({ name = if isSelected then "check" else "app-window", size = 18, color = if isSelected then "primary" else "on_surface_variant" })
                            end

                            table.insert(procCards, ui.row({
                                gap = 8,
                                align = "center",
                                padding = 8,
                                radius = 10,
                                fill = if isSelected then "primary/0.2" else "surface_variant/0.3",
                                onClick = function()
                                    toggleProcessSelection(procName)
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

            -- Offer to add custom typed process if not already in list
            if filterText ~= "" and not selectedSet[filterText] then
                table.insert(procCards, ui.row({
                    gap = 8,
                    align = "center",
                    padding = 8,
                    radius = 10,
                    fill = "surface_variant/0.5",
                    onClick = function()
                        local cleanCustom = noctalia.string.trim(uiState.procSearchQuery)
                        if cleanCustom ~= "" then
                            toggleProcessSelection(cleanCustom)
                            uiState.procSearchQuery = ""
                            uiState.inputKey = uiState.inputKey + 1
                            renderPanel()
                        end
                    end,
                    flexGrow = 1,
                }, {
                    ui.glyph({ name = "plus", size = 18, color = "primary" }),
                    ui.label({
                        text = "Add '" .. uiState.procSearchQuery .. "'",
                        fontSize = 12,
                        fontWeight = "medium",
                        color = "primary",
                    }),
                }))
            end
        end

        local selectedChips = {}
        for _, procName in ipairs(uiState.selectedProcesses) do
            local shortName = procName
            if string.len(shortName) > 16 then
                shortName = string.sub(shortName, 1, 14) .. "…"
            end
            table.insert(selectedChips, ui.row({
                gap = 6,
                align = "center",
                padding = 6,
                radius = 8,
                fill = "primary/0.2",
                onClick = function()
                    toggleProcessSelection(procName)
                end,
            }, {
                ui.label({ text = shortName, fontSize = 11, fontWeight = "medium", color = "primary" }),
                ui.glyph({ name = "x", size = 11, color = "primary" }),
            }))
        end

        local procControls = {
            ui.input({
                key = "proc-input-" .. uiState.inputKey,
                value = uiState.procSearchQuery,
                placeholder = "Search app or type custom process...",
                onChange = function(val)
                    uiState.procSearchQuery = val or ""
                    renderPanel()
                end,
            }),
        }

        local procTitle = noctalia.tr("panel.process-label")
        local clearButton = nil

        if #uiState.selectedProcesses > 0 then
            procTitle = procTitle .. string.format(" (%d)", #uiState.selectedProcesses)
            clearButton = ui.button({
                text = "Clear all",
                variant = "ghost",
                controlSize = "sm",
                onClick = function()
                    uiState.selectedProcesses = {}
                    renderPanel()
                end,
            })

            table.insert(procControls, ui.row({ gap = 6, align = "center" }, selectedChips))
        end

        if #procCards > 0 then
            table.insert(procControls, chunkIntoGrid(procCards, 2))
        elseif not isProcessesLoaded then
            table.insert(procControls, ui.label({ text = noctalia.tr("panel.process-loading"), fontSize = 11, color = "on_surface_variant" }))
        else
            table.insert(procControls, ui.label({ text = noctalia.tr("panel.process-empty"), fontSize = 11, color = "on_surface_variant" }))
        end

        table.insert(items, section(procTitle, ui.column({ gap = 8 }, procControls), clearButton))

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
                local target = ""
                if act == "kill-process" then
                    if #uiState.selectedProcesses > 0 then
                        target = table.concat(uiState.selectedProcesses, ", ")
                    elseif uiState.procSearchQuery ~= "" then
                        target = noctalia.string.trim(uiState.procSearchQuery)
                    end
                elseif act == "custom-command" then
                    target = uiState.customCmdText
                end

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
    local actionTarget = state.actionTarget or ""

    local actGlyph = "moon"
    if state.action == "lock" then actGlyph = "lock"
    elseif state.action == "suspend" then actGlyph = "moon"
    elseif state.action == "shutdown" then actGlyph = "power"
    elseif state.action == "reboot" then actGlyph = "rotate"
    elseif state.action == "logout" then actGlyph = "logout"
    elseif state.action == "kill-process" then actGlyph = "square-x"
    elseif state.action == "custom-command" then actGlyph = "terminal"
    end

    local statusLabel = if isWarning then noctalia.tr("status.warning")
                        elseif isPaused then noctalia.tr("status.paused")
                        else noctalia.tr("status.running")

    -- Calculate estimated finish time
    local finishTimeStr = os.date("%H:%M", os.time() + secsLeft)
    local subInfoText = "Ends at " .. finishTimeStr
    if actionTarget ~= "" then
        local targetSummary = if state.action == "kill-process"
            then formatTargetSummary(actionTarget, 2)
            else actionTarget
        if string.len(targetSummary) > 28 then
            targetSummary = string.sub(targetSummary, 1, 26) .. "…"
        end
        subInfoText = subInfoText .. "  •  " .. targetSummary
    end

    -- 1. Status & Target Header (Clean typography & subtle indicator)
    local topHeader = ui.row({
        justify = "space_between",
        align = "center",
        width = 330,
    }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = actGlyph, size = 18, color = accentColor }),
            ui.label({ text = actName, fontSize = 13, fontWeight = "bold", color = "on_surface" }),
        }),
        ui.row({ gap = 6, align = "center" }, {
            ui.glyph({ name = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "circle-filled", size = 9, color = accentColor }),
            ui.label({ text = statusLabel, fontSize = 12, fontWeight = "medium", color = accentColor }),
        }),
    })

    -- 2. Hero Digital Countdown Display Card
    local displayCard = ui.column({
        align = "center",
        justify = "center",
        gap = 16,
        padding = 20,
        fill = "surface_variant/0.3",
        radius = 20,
    }, {
        topHeader,

        -- Big Time Display
        ui.column({ align = "center", gap = 4 }, {
            ui.label({
                text = state.formattedTime or "00:00",
                fontSize = 50,
                fontWeight = "bold",
                color = accentColor,
            }),
            ui.label({
                text = subInfoText,
                fontSize = 12,
                color = "on_surface_variant",
                fontWeight = "medium",
            }),
        }),

        -- Progress Bar & Metrics
        ui.column({ gap = 8 }, {
            ui.progress({
                progress = progressRatio,
                fill = accentColor,
                height = 8,
                radius = 4,
                width = 330,
            }),
            ui.row({ justify = "space_between", align = "center", width = 330 }, {
                ui.label({
                    text = string.format("%s left (%s)", formatDurationHuman(math.max(1, math.floor(secsLeft / 60))), pctText),
                    fontSize = 12,
                    color = "on_surface_variant",
                }),
                ui.label({
                    text = "Total " .. formatDurationHuman(math.floor(totalSecs / 60)),
                    fontSize = 12,
                    color = "on_surface_variant",
                    fontWeight = "medium",
                }),
            }),
        }),
    })

    -- 3. Quick Adjust Pills (+5m, +1m, -1m, -5m)
    local adjustRow = ui.row({ gap = 6, justify = "space_between", align = "center" }, {
        ui.button({
            text = "−5m",
            variant = "secondary",
            flexGrow = 1,
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = -300 })
            end,
        }),
        ui.button({
            text = "−1m",
            variant = "secondary",
            flexGrow = 1,
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = -60 })
            end,
        }),
        ui.button({
            text = "+1m",
            variant = "secondary",
            flexGrow = 1,
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = 60 })
            end,
        }),
        ui.button({
            text = "+5m",
            variant = "secondary",
            flexGrow = 1,
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = 300 })
            end,
        }),
    })

    -- 4. Main Control Buttons (Resume/Pause, Cancel)
    local playbackRow = ui.row({ gap = 10, align = "center" }, {
        ui.button({
            text = if isPaused then noctalia.tr("button.resume") else noctalia.tr("button.pause"),
            glyph = if isPaused then "player-play" else "player-pause",
            variant = "primary",
            flexGrow = 1,
            controlSize = "md",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = if isPaused then "resume" else "pause" })
            end,
        }),
        ui.button({
            text = noctalia.tr("button.cancel"),
            glyph = "x",
            variant = "destructive",
            flexGrow = 1,
            controlSize = "md",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "cancel" })
            end,
        }),
    })

    return ui.column({ flexGrow = 1, justify = "space_between", gap = 14 }, {
        displayCard,
        ui.column({ gap = 8 }, {
            adjustRow,
            playbackRow,
        }),
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
                glyph = "x",
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
        if state.actionTarget and state.actionTarget ~= "" then
            if state.action == "kill-process" then
                local _, list = parseProcessSet(state.actionTarget)
                uiState.selectedProcesses = list
                uiState.procSearchQuery = ""
            elseif state.action == "custom-command" then
                uiState.customCmdText = state.actionTarget
            end
        end
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
