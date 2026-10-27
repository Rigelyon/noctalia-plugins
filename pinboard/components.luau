--!nonstrict

local storage = require("./storage")

export type StashItem = storage.StashItem
export type PinboardData = storage.PinboardData

local components = {}

local COLOR_PRIMARY = { hex = "#38bdf8", alpha = 1.0 }
local COLOR_GHOST_BORDER = { hex = "#818cf8", alpha = 0.35 }
local COLOR_SURFACE = { hex = "#131722", alpha = 0.94 }
local COLOR_CARD = { hex = "#1a2130", alpha = 0.85 }
local COLOR_CARD_ACTIVE = { hex = "#223048", alpha = 0.95 }
local COLOR_TEXT_MUTED = { hex = "#94a3b8", alpha = 1.0 }
local COLOR_TEXT = { hex = "#f8fafc", alpha = 1.0 }
local COLOR_DANGER = { hex = "#f43f5e", alpha = 1.0 }

function components.badge(label: string, variant: string?): any
    local fill = if variant == "primary"
        then { hex = "#0284c7", alpha = 0.25 }
        elseif variant == "accent"
        then { hex = "#6366f1", alpha = 0.25 }
        else { hex = "#334155", alpha = 0.4 }

    local textFill = if variant == "primary"
        then COLOR_PRIMARY
        elseif variant == "accent"
        then { hex = "#a5b4fc", alpha = 1.0 }
        else COLOR_TEXT_MUTED

    return ui.box({
        fill = fill,
        radius = 4,
        paddingH = 6,
        paddingV = 2,
    }, {
        ui.label({
            text = label,
            fontSize = 11,
            color = textFill,
        }),
    })
end

function components.iconButton(glyphName: string, tooltipText: string?, onClickHandler: any, active: boolean?): any
    local fill = if active
        then { hex = "#0284c7", alpha = 0.4 }
        else { hex = "#1e293b", alpha = 0.6 }

    local border = if active
        then COLOR_PRIMARY
        else { hex = "#334155", alpha = 0.5 }

    return ui.button({
        tooltip = tooltipText,
        onClick = onClickHandler,
        fill = fill,
        border = border,
        borderWidth = 1,
        radius = 6,
        paddingH = 8,
        paddingV = 6,
        minHeight = 28,
    }, {
        ui.row({ gap = 4, align = "center" }, {
            ui.glyph({
                name = glyphName,
                fontSize = 14,
                color = if active then COLOR_PRIMARY else COLOR_TEXT,
            }),
        }),
    })
end

function components.floatingToolbar(currentState: PinboardData, callbacks: { [string]: any }): any
    local scaleLabel = string.upper(string.sub(currentState.scale or "M", 1, 1))
    local opacityPercent = math.floor((currentState.opacity or 0.85) * 100) .. "%"
    local viewMode = currentState.view_mode or "split"
    local modeGlyph = if viewMode == "image" then "photo" elseif viewMode == "note" then "notebook" else "layout-grid"

    return ui.box({
        fill = { hex = "#0f172a", alpha = 0.95 },
        radius = 8,
        border = { hex = "#334155", alpha = 0.8 },
        borderWidth = 1,
        padding = 6,
        hitSlop = 4,
    }, {
        ui.row({ gap = 6, align = "center", justify = "space_between" }, {
            -- Left cluster: Navigation
            ui.row({ gap = 4, align = "center" }, {
                components.iconButton("chevron-left", "Previous reference", callbacks.onPrev),
                components.iconButton("chevron-right", "Next reference", callbacks.onNext),
            }),

            -- Center cluster: Mode, Scale & Opacity
            ui.row({ gap = 4, align = "center" }, {
                components.iconButton(modeGlyph, "Switch view mode: " .. viewMode, callbacks.onViewMode, true),
                components.iconButton("arrows-maximize", "Size Scale: " .. scaleLabel, callbacks.onScale),
                components.iconButton("arrow-up-right", "Move corner anchor: " .. (currentState.anchor or "top_right"), callbacks.onAnchor),
                components.iconButton("sun", "Opacity: " .. opacityPercent .. " (Click to toggle)", callbacks.onOpacityCycle),
            }),

            -- Right cluster: Lock to Ghost Button
            ui.button({
                tooltip = "Lock to Ghost Mode (Click-Through)",
                onClick = callbacks.onLock,
                fill = { hex = "#4f46e5", alpha = 0.9 },
                radius = 6,
                paddingH = 10,
                paddingV = 6,
                minHeight = 28,
            }, {
                ui.row({ gap = 6, align = "center" }, {
                    ui.glyph({ name = "lock", fontSize = 13, color = { hex = "#ffffff", alpha = 1.0 } }),
                    ui.label({ text = "Ghost", fontSize = 12, color = { hex = "#ffffff", alpha = 1.0 } }),
                }),
            }),
        }),
    })
end

function components.stashCard(item: StashItem, isActive: boolean, onSelect: any, onDelete: any): any
    local fill = if isActive then COLOR_CARD_ACTIVE else COLOR_CARD
    local border = if isActive then COLOR_PRIMARY else { hex = "#334155", alpha = 0.6 }
    local typeGlyph = if item.type == "image" then "photo" else "notebook"
    local badgeVariant = if item.type == "image" then "primary" else "accent"

    return ui.box({
        fill = fill,
        border = border,
        borderWidth = if isActive then 2 else 1,
        radius = 8,
        padding = 10,
        gap = 8,
    }, {
        ui.row({ gap = 8, align = "center", justify = "space_between" }, {
            -- Left info
            ui.row({ gap = 8, align = "center", flexGrow = 1 }, {
                ui.glyph({ name = typeGlyph, fontSize = 18, color = if isActive then COLOR_PRIMARY else COLOR_TEXT_MUTED }),
                ui.column({ gap = 2, flexGrow = 1 }, {
                    ui.label({
                        text = item.title or "Untitled Reference",
                        fontSize = 13,
                        color = COLOR_TEXT,
                    }),
                    ui.row({ gap = 6, align = "center" }, {
                        components.badge(string.upper(item.type), badgeVariant),
                        ui.label({
                            text = if item.type == "image" then (item.path or "") else (string.sub(item.content or "", 1, 35) .. "..."),
                            fontSize = 11,
                            color = COLOR_TEXT_MUTED,
                        }),
                    }),
                }),
            }),

            -- Right actions
            ui.row({ gap = 6, align = "center" }, {
                if not isActive then
                    ui.button({
                        tooltip = "Pin to overlay",
                        onClick = onSelect,
                        fill = { hex = "#0284c7", alpha = 0.2 },
                        border = COLOR_PRIMARY,
                        borderWidth = 1,
                        radius = 6,
                        paddingH = 8,
                        paddingV = 4,
                    }, {
                        ui.row({ gap = 4, align = "center" }, {
                            ui.glyph({ name = "pin", fontSize = 13, color = COLOR_PRIMARY }),
                            ui.label({ text = "Pin", fontSize = 11, color = COLOR_PRIMARY }),
                        }),
                    })
                else
                    components.badge("PINNED", "primary"),

                ui.button({
                    tooltip = "Delete item",
                    onClick = onDelete,
                    fill = { hex = "#f43f5e", alpha = 0.15 },
                    border = { hex = "#f43f5e", alpha = 0.4 },
                    borderWidth = 1,
                    radius = 6,
                    paddingH = 6,
                    paddingV = 4,
                }, {
                    ui.glyph({ name = "trash", fontSize = 13, color = COLOR_DANGER }),
                }),
            }),
        }),
    })
end

function components.quadrantSelector(currentAnchor: string, onSelectAnchor: (anchor: string) -> ()): any
    local function makeQuadrantButton(anchorId: string, label: string)
        local isSel = currentAnchor == anchorId
        return ui.button({
            onClick = function() onSelectAnchor(anchorId) end,
            fill = if isSel then { hex = "#0284c7", alpha = 0.35 } else { hex = "#1e293b", alpha = 0.6 },
            border = if isSel then COLOR_PRIMARY else { hex = "#334155", alpha = 0.6 },
            borderWidth = 1,
            radius = 6,
            paddingH = 12,
            paddingV = 8,
            flexGrow = 1,
        }, {
            ui.row({ gap = 6, align = "center", justify = "center" }, {
                ui.glyph({
                    name = if isSel then "circle-check" else "circle",
                    fontSize = 13,
                    color = if isSel then COLOR_PRIMARY else COLOR_TEXT_MUTED,
                }),
                ui.label({
                    text = label,
                    fontSize = 12,
                    color = if isSel then COLOR_TEXT else COLOR_TEXT_MUTED,
                }),
            }),
        })
    end

    return ui.column({ gap = 6 }, {
        ui.row({ gap = 6 }, {
            makeQuadrantButton("top_left", "Top Left"),
            makeQuadrantButton("top_right", "Top Right"),
        }),
        ui.row({ gap = 6 }, {
            makeQuadrantButton("bottom_left", "Bottom Left"),
            makeQuadrantButton("bottom_right", "Bottom Right"),
        }),
    })
end

return components
