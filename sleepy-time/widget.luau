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
        idleText          = noctalia.getConfig("idle_text") or "none",
        showCountdownText = noctalia.getConfig("show_countdown_text") ~= false,
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
    elseif action == "kill-process" then return "skull"
    elseif action == "custom-command" then return "terminal"
    end
    return "moon-stars"
end

local function renderWidget()
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

        if isVertical or idleLabel == "" then
            barWidget.render(
                ui.column({ align = "center", justify = "center" }, {
                    ui.glyph({ name = "moon-stars", color = "on_surface_variant" }),
                })
            )
        else
            barWidget.render(
                ui.row({ gap = 6, align = "center" }, {
                    ui.glyph({ name = "moon-stars", color = "on_surface_variant" }),
                    ui.label({ text = idleLabel, color = "on_surface_variant", fontSize = 13 }),
                })
            )
        end
        return
    end

    -- RUNNING / PAUSED / WARNING STATE
    local glyph = "timer"
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

    if isVertical or not cfg.showCountdownText then
        barWidget.render(
            ui.column({ align = "center", justify = "center" }, {
                ui.glyph({ name = glyph, color = color }),
            })
        )
    else
        barWidget.render(
            ui.row({ gap = 6, align = "center" }, {
                ui.glyph({ name = glyph, color = color }),
                ui.label({
                    text = timeText,
                    color = color,
                    fontWeight = "bold",
                    fontSize = 13,
                }),
            })
        )
    end
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

noctalia.state.watch("sleepy.state", function(_state)
    renderWidget()
end)

-- Initial render
renderWidget()
