--!nonstrict
-- widget.luau — Sleepy Time bar widget

function onClick()
    noctalia.togglePanel("rigelyon/sleepy-time:panel")
end

function onRightClick()
    local state = noctalia.state.get("sleepy.state")
    if state and state.isRunning then
        noctalia.state.set("sleepy.command", { action = "cancel" })
    else
        noctalia.togglePanel("rigelyon/sleepy-time:panel")
    end
end

-- Config helpers
local function getConfig()
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

local function formatTime(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function getActionGlyph(action)
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

local function renderWidget(state)
    local cfg = getConfig()

    if not state or not state.isRunning then
        -- Idle state
        if not cfg.showWhenIdle then
            barWidget.setGlyph("moon-stars")
            barWidget.setText("")
            barWidget.setGlyphColor("default")
            barWidget.setColor("default")
            barWidget.setTooltip(noctalia.tr("panel.title"))
            return
        end

        barWidget.setGlyph("moon-stars")
        barWidget.setGlyphColor("default")
        barWidget.setColor("default")

        if cfg.idleText == "plugin-name" then
            barWidget.setText(noctalia.tr("panel.title"))
        elseif cfg.idleText == "next-action" and state and state.action then
            barWidget.setText(noctalia.tr("action." .. state.action))
        else
            barWidget.setText("")
        end

        barWidget.setTooltip("Sleepy Time — Click to set timer")
        return
    end

    -- Active / Paused / Warning state
    local glyph = "clock-hour-3"
    if state.warningActive then
        glyph = "alert-triangle"
    elseif state.isPaused then
        glyph = "clock-pause"
    elseif cfg.showActionIcon then
        glyph = getActionGlyph(state.action)
    end

    local color = cfg.activeColor
    if state.warningActive then
        color = cfg.warningColor
    elseif state.isPaused then
        color = cfg.pausedColor
    end

    barWidget.setGlyph(glyph)
    barWidget.setGlyphColor(color)
    barWidget.setColor(color)

    if cfg.showCountdownText then
        barWidget.setText(formatTime(state.secondsLeft))
    else
        barWidget.setText("")
    end

    local statusStr = if state.warningActive then noctalia.tr("status.warning")
                      elseif state.isPaused then noctalia.tr("status.paused")
                      else noctalia.tr("status.running")

    local actName = noctalia.tr("action." .. (state.action or "lock"))
    local tooltip = string.format("Sleepy Time: %s (%s)\nAction: %s\nLeft-click: Setup | Right-click: Cancel",
        formatTime(state.secondsLeft), statusStr, actName)
    barWidget.setTooltip(tooltip)
end

-- Initial render
barWidget.setGlyph("moon-stars")
local initialState = noctalia.state.get("sleepy.state")
renderWidget(initialState)

-- Watch state updates
noctalia.state.watch("sleepy.state", function(state)
    renderWidget(state)
end)
