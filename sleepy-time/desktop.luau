--!nonstrict
-- desktop.luau — Sleepy Time declarative ambient desktop widget

local function getDesktopConfig()
    return {
        color           = noctalia.getConfig("color") or "primary",
        showWhenIdle    = noctalia.getConfig("show_when_idle") == true,
        showProgress    = noctalia.getConfig("show_progress") ~= false,
        showPercentage  = noctalia.getConfig("show_percentage") ~= false,
        showActionLabel = noctalia.getConfig("show_action_label") ~= false,
        fontSize        = tonumber(noctalia.getConfig("font_size")) or 38,
        compactMode     = noctalia.getConfig("compact_mode") == true,
        pausedColor     = noctalia.getConfig("paused_color") or "#f59e0b",
        warningColor    = noctalia.getConfig("warning_color") or "#ef4444",
    }
end

local function renderDesktop()
    local cfg = getDesktopConfig()
    local state = noctalia.state.get("sleepy.state") or { status = "IDLE", remaining = 0, duration = 0 }

    local isRunning = (state.status == "RUNNING" or state.status == "PAUSED" or state.status == "WARNING")
    local isPaused  = (state.status == "PAUSED")
    local isWarning = (state.status == "WARNING" or state.warningActive == true)

    if not isRunning then
        if not cfg.showWhenIdle then
            desktopWidget.render(ui.box({ width = 0, height = 0 }))
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

    -- Running state progress calculations
    local secsLeft = state.remaining or 0
    local totalSecs = state.duration or 1
    local progressRatio = if totalSecs > 0 then math.max(0, math.min(1, 1 - (secsLeft / totalSecs))) else 0
    local pctText = string.format("%d%%", math.floor(progressRatio * 100))

    local accentColor = cfg.color
    if isWarning then
        accentColor = cfg.warningColor
    elseif isPaused then
        accentColor = cfg.pausedColor
    end

    local actName = noctalia.tr("action." .. (state.action or "lock"))
    local glyphName = if isWarning then "alert-triangle" elseif isPaused then "clock-pause" else "clock"
    local timeText = state.formattedTime or "00:00"

    if cfg.compactMode then
        -- Compact single-row layout
        local rowItems = {
            ui.glyph({ name = glyphName, size = 20, color = accentColor }),
            ui.label({
                text = timeText,
                fontSize = 20,
                fontWeight = "bold",
                color = accentColor,
            }),
        }

        if cfg.showProgress then
            table.insert(rowItems, ui.progress({
                progress = progressRatio,
                fill = accentColor,
                width = 80,
                height = 6,
                radius = 3,
            }))
        end

        if cfg.showPercentage then
            table.insert(rowItems, ui.label({ text = pctText, fontSize = 12, color = "on_surface_variant" }))
        end

        if cfg.showActionLabel then
            table.insert(rowItems, ui.label({ text = actName, fontSize = 12, fontWeight = "medium", color = "on_surface" }))
        end

        table.insert(rowItems, ui.button({
            text = "✕",
            variant = "secondary",
            onClick = function()
                noctalia.state.set("sleepy.cmd", { action = "cancel" })
            end,
        }))

        desktopWidget.render(
            ui.row({ align = "center", justify = "center", gap = 10, padding = 12, radius = 16, fill = "surface_variant/0.5" }, rowItems)
        )
    else
        -- Standard ambient card layout
        local items = {}

        -- Title header
        table.insert(items, ui.row({ align = "center", gap = 6 }, {
            ui.glyph({ name = glyphName, size = 18, color = accentColor }),
            ui.label({
                text = if isWarning then "⚠️ Warning" elseif isPaused then "Paused" else "Sleepy Time",
                fontSize = 13,
                fontWeight = "bold",
                color = if isWarning then "error" else "on_surface",
            }),
        }))

        -- Timer Countdown display
        table.insert(items, ui.label({
            text = timeText,
            fontSize = cfg.fontSize,
            fontWeight = "bold",
            color = accentColor,
        }))

        -- Progress Bar
        if cfg.showProgress then
            table.insert(items, ui.progress({
                progress = progressRatio,
                fill = accentColor,
                height = 6,
                radius = 3,
                width = 180,
            }))
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
            table.insert(items, ui.row({ justify = "space_between", align = "center", width = 180 }, footerItems))
        end

        -- Quick adjustment buttons
        table.insert(items, ui.row({ gap = 6, justify = "center", align = "center" }, {
            ui.button({
                text = "+5m",
                variant = "secondary",
                onClick = function()
                    noctalia.state.set("sleepy.cmd", { action = "addTime", seconds = 300 })
                end,
            }),
            ui.button({
                text = if isPaused then "▶" else "⏸",
                variant = "secondary",
                onClick = function()
                    noctalia.state.set("sleepy.cmd", { action = if isPaused then "resume" else "pause" })
                end,
            }),
            ui.button({
                text = "✕",
                variant = "destructive",
                onClick = function()
                    noctalia.state.set("sleepy.cmd", { action = "cancel" })
                end,
            }),
        }))

        desktopWidget.render(
            ui.column({ align = "center", justify = "center", gap = 8, padding = 16, radius = 20, fill = "surface_variant/0.5" }, items)
        )
    end
end

-- ── Callbacks & Watches ──────────────────────────────────────────────────────

noctalia.state.watch("sleepy.state", function(_state)
    renderDesktop()
end)

-- Initial render
renderDesktop()
