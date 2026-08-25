--!nonstrict
-- widget.luau — Sleepy Time declarative bar widget

local Tooltip = {
    active = false,
}

local function setSafeTooltip(text: string?)
    if text and text ~= "" then
        barWidget.setTooltip(text)
        Tooltip.active = true
    elseif Tooltip.active then
        barWidget.clearTooltip()
        Tooltip.active = false
    end
end

local function getWidgetConfig()
    return {
        showWhenIdle      = noctalia.getConfig("show_when_idle") ~= false,
        idleIcon          = noctalia.getConfig("idle_icon") or "moon-stars",
        idleText          = noctalia.getConfig("idle_text") or "none",
        displayMode       = noctalia.getConfig("display_mode") or "icon_and_time",
        showCountdownText = noctalia.getConfig("show_countdown_text") ~= false,
        showProgressBar   = noctalia.getConfig("show_progress_bar") == true,
        showActionIcon    = noctalia.getConfig("show_action_icon") == true,
        activeColor       = noctalia.getConfig("active_color") or "primary",
        pausedColor       = noctalia.getConfig("paused_color") or "#f59e0b",
        warningColor      = noctalia.getConfig("warning_color") or "#ef4444",
    }
end

local function getActionGlyph(action: string?): string
    if action == "lock" then return "lock"
    elseif action == "suspend" then return "moon"
    elseif action == "shutdown" then return "power"
    elseif action == "reboot" then return "rotate"
    elseif action == "logout" then return "logout"
    elseif action == "kill-process" then return "square-x"
    elseif action == "custom-command" then return "terminal"
    end
    return "moon-stars"
end

local function renderWidget()
    pcall(function()
        local cfg = getWidgetConfig()
        local state = noctalia.state.get("sleepy.state") or { status = "IDLE", remaining = 0 }
        local isVertical = barWidget.isVertical()

        local isRunning = (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING")
        local isPaused  = (state.status == "PAUSED")
        local isWarning = (state.status == "WARNING" or state.warningActive == true)

        if not isRunning then
            -- IDLE STATE
            if not cfg.showWhenIdle then
                setSafeTooltip(nil)
                barWidget.render(ui.box({ width = 0, height = 0 }))
                return
            end

            local idleLabel = ""
            if cfg.idleText == "plugin-name" then
                idleLabel = noctalia.tr("panel.title")
            elseif cfg.idleText == "next-action" and state.action then
                idleLabel = noctalia.tr("action." .. state.action)
            end

            setSafeTooltip("Sleepy Time — Click to setup timer")

            local idleNode
            if isVertical or idleLabel == "" then
                idleNode = ui.column({ align = "center", justify = "center" }, {
                    ui.glyph({ name = cfg.idleIcon, color = "on_surface_variant" }),
                })
            else
                idleNode = ui.row({ gap = 6, align = "center" }, {
                    ui.glyph({ name = cfg.idleIcon, color = "on_surface_variant" }),
                    ui.label({ text = idleLabel, color = "on_surface_variant", fontSize = 13 }),
                })
            end

            barWidget.render(idleNode)
            return
        end

        -- RUNNING / PAUSED / WARNING STATE
        local secsLeft = state.remaining or 0
        local totalSecs = state.duration or 1
        local progressRatio = if totalSecs > 0 then math.max(0, math.min(1, 1 - (secsLeft / totalSecs))) else 0

        local glyph = "moon-stars"
        if isWarning then
            glyph = "alert-triangle"
        elseif isPaused then
            glyph = "clock-pause"
        elseif cfg.showActionIcon and state.action then
            glyph = getActionGlyph(state.action)
        end

        local color = cfg.activeColor
        if isWarning then
            color = cfg.warningColor
        elseif isPaused then
            color = cfg.pausedColor
        end

        local timeText = state.formattedTime or "00:00"
        local actName = noctalia.tr("action." .. (state.action or "lock"))
        local statusName = if isWarning then noctalia.tr("status.warning")
                           elseif isPaused then noctalia.tr("status.paused")
                           else noctalia.tr("status.running")

        local tooltipText = string.format("Sleepy Time: %s (%s)\nAction: %s\nLeft-click: Setup | Right-click: Cancel",
            timeText, statusName, actName)
        setSafeTooltip(tooltipText)

        if isVertical then
            local vNode = ui.column({ align = "center", justify = "center", gap = 4 }, {
                ui.glyph({ name = glyph, color = color }),
            })
            barWidget.render(vNode)
            return
        end

        -- Horizontal bar layout according to display_mode
        local rowItems = {}

        if cfg.displayMode == "icon_and_time" then
            table.insert(rowItems, ui.glyph({ name = glyph, color = color }))
            if cfg.showCountdownText then
                table.insert(rowItems, ui.label({
                    text = timeText,
                    color = color,
                    fontWeight = "bold",
                    fontSize = 13,
                }))
            end
        elseif cfg.displayMode == "time_only" then
            table.insert(rowItems, ui.label({
                text = timeText,
                color = color,
                fontWeight = "bold",
                fontSize = 13,
            }))
        elseif cfg.displayMode == "detailed" then
            table.insert(rowItems, ui.glyph({ name = glyph, color = color }))
            table.insert(rowItems, ui.label({
                text = timeText,
                color = color,
                fontWeight = "bold",
                fontSize = 13,
            }))
            local targetShort = state.actionTarget or ""
            if targetShort ~= "" and string.len(targetShort) > 12 then
                targetShort = string.sub(targetShort, 1, 10) .. "…"
            end
            local detailLabel = if targetShort ~= "" then targetShort else actName
            table.insert(rowItems, ui.label({
                text = "• " .. detailLabel,
                color = "on_surface_variant",
                fontSize = 12,
            }))
        end

        if cfg.showProgressBar then
            table.insert(rowItems, ui.progress({
                progress = progressRatio,
                fill = color,
                width = 36,
                height = 4,
                radius = 2,
            }))
        end

        local hNode = ui.row({ gap = 6, align = "center" }, rowItems)
        barWidget.render(hNode)
    end)
end

-- ── Callbacks & Watches ──────────────────────────────────────────────────────

function onClick()
    noctalia.togglePanel("rigelyon/sleepy-time:panel")
end

function onRightClick()
    local state = noctalia.state.get("sleepy.state")
    if state and (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING") then
        noctalia.state.set("sleepy.cmd", { action = "cancel" })
    else
        noctalia.togglePanel("rigelyon/sleepy-time:panel")
    end
end

function onConfigChanged()
    renderWidget()
end

function update()
    renderWidget()
end

noctalia.state.watch("sleepy.state", function(_state)
    renderWidget()
end)

-- Initial render
renderWidget()
