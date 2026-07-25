--!nonstrict
-- desktop.luau — Sleepy Time desktop widget

local timeFontFamily = noctalia.loadFont("JetBrainsMono-Regular.ttf")

desktopWidget.setWantsSecondTicks(true)

local function getDesktopConfig()
    return {
        color           = noctalia.getConfig("color") or "primary",
        showWhenIdle    = noctalia.getConfig("show_when_idle") == true,
        showProgress    = noctalia.getConfig("show_progress") ~= false,
        showPercentage  = noctalia.getConfig("show_percentage") ~= false,
        showActionLabel = noctalia.getConfig("show_action_label") ~= false,
        fontSize        = tonumber(noctalia.getConfig("font_size")) or 42,
        compactMode     = noctalia.getConfig("compact_mode") == true,
        pausedColor     = noctalia.getConfig("paused_color") or "#f59e0b",
        warningColor    = noctalia.getConfig("warning_color") or "#ef4444",
    }
end

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

function onCancelClick()
    noctalia.state.set("sleepy.command", { action = "cancel" })
end

local function renderDesktop(state)
    local cfg = getDesktopConfig()

    local isRunning = state and state.isRunning == true
    local isPaused  = state and state.isPaused == true
    local isWarning = state and state.warningActive == true

    if not isRunning then
        if not cfg.showWhenIdle then
            desktopWidget.render(ui.box({ width = 0, height = 0, opacity = 0 }))
            return
        end

        -- Render minimal idle chip
        desktopWidget.render(
            ui.row({ align = "center", justify = "center", padding = 12, gap = 8, radius = 16, fill = "surface_variant/0.4" }, {
                ui.glyph({ name = "moon-stars", size = 18, color = "primary" }),
                ui.label({ text = "Sleepy Time — Idle", fontSize = 12, color = "on_surface_variant" }),
            })
        )
        return
    end

    -- Running state calculations
    local secsLeft = state.secondsLeft or 0
    local totalSecs = state.totalSeconds or 1
    local progressRatio = if totalSecs > 0 then (1 - (secsLeft / totalSecs)) else 0
    local pctText = string.format("%d%%", math.floor(progressRatio * 100))

    local accentColor = cfg.color
    if isWarning then
        accentColor = cfg.warningColor
    elseif isPaused then
        accentColor = cfg.pausedColor
    end

    local actName = noctalia.tr("action." .. (state.action or "lock"))

    if cfg.compactMode then
        -- Compact single-row layout
        local rowItems = {
            ui.glyph({ name = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "moon-stars", size = 20, color = accentColor }),
            ui.label({
                text = formatTimeDisplay(secsLeft),
                fontSize = 20,
                fontWeight = "bold",
                fontFamily = timeFontFamily,
                color = accentColor,
            }),
        }

        if cfg.showProgress then
            table.insert(rowItems, ui.progress({ value = progressRatio, color = accentColor, width = 80 }))
        end
        if cfg.showPercentage then
            table.insert(rowItems, ui.label({ text = pctText, fontSize = 12, color = "on_surface_variant" }))
        end
        if cfg.showActionLabel then
            table.insert(rowItems, ui.label({ text = actName, fontSize = 12, fontWeight = "medium", color = "on_surface" }))
        end
        if isWarning then
            table.insert(rowItems, ui.button({ text = "✕", variant = "secondary", onClick = "onCancelClick" }))
        end

        desktopWidget.render(
            ui.row({ align = "center", justify = "center", gap = 10, padding = 12, radius = 16, fill = "surface_variant/0.6" }, rowItems)
        )
    else
        -- Standard card layout
        local items = {}

        -- Title header
        table.insert(items, ui.row({ align = "center", gap = 6 }, {
            ui.glyph({ name = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "moon-stars", size = 18, color = accentColor }),
            ui.label({
                text = if isWarning then "⚠️ Warning" elseif isPaused then "Paused" else "Sleepy Time",
                fontSize = 14,
                fontWeight = "bold",
                color = if isWarning then "error" else "on_surface",
            }),
        }))

        -- Timer Countdown display
        table.insert(items, ui.label({
            text = formatTimeDisplay(secsLeft),
            fontSize = cfg.fontSize,
            fontWeight = "bold",
            fontFamily = timeFontFamily,
            color = accentColor,
        }))

        -- Progress Bar
        if cfg.showProgress then
            table.insert(items, ui.progress({ value = progressRatio, color = accentColor, flexGrow = 1 }))
        end

        -- Footer info (Percentage & Action label)
        local footerItems = {}
        if cfg.showActionLabel then
            table.insert(footerItems, ui.label({ text = actName, fontSize = 12, fontWeight = "medium", color = "on_surface" }))
        end
        if cfg.showPercentage then
            table.insert(footerItems, ui.label({ text = pctText, fontSize = 12, color = "on_surface_variant" }))
        end

        if #footerItems > 0 then
            table.insert(items, ui.row({ justify = "space_between", align = "center" }, footerItems))
        end

        -- Quick cancel button during warning phase
        if isWarning then
            table.insert(items, ui.button({
                text = noctalia.tr("button.cancel") .. " Timer",
                glyph = "x",
                variant = "secondary",
                onClick = "onCancelClick",
            }))
        end

        desktopWidget.render(
            ui.column({ align = "center", justify = "center", gap = 8, padding = 16, radius = 20, fill = "surface_variant/0.6" }, items)
        )
    end
end

-- Initial render
local initialState = noctalia.state.get("sleepy.state")
renderDesktop(initialState)

-- Watch state updates
noctalia.state.watch("sleepy.state", function(state)
    renderDesktop(state)
end)
