--!nonstrict

local state = require("./state")
local components = require("./components")

local function configureLayer()
    local s = state.get()
    local geo = state.getGeometry()

    noctalia.layer.configure("ref-overlay", {
        layer = "overlay",
        anchors = geo.anchors,
        margins = geo.margins,
        width = geo.width,
        clickThrough = s.ghost_mode,
    })
end

local function renderOverlay()
    local s = state.get()
    local geo = state.getGeometry()
    local activeItem = state.getActiveItem()

    configureLayer()

    local isGhost = s.ghost_mode
    local contentOpacity = if isGhost then (s.opacity or 0.85) else 1.0

    -- Container Border and Background
    local containerFill = if isGhost
        then { hex = "#000000", alpha = math.min(0.4, (s.opacity or 0.85) * 0.45) }
        else { hex = "#0f172a", alpha = 0.96 }

    local containerBorder = if isGhost
        then { hex = "#818cf8", alpha = 0.25 }
        else { hex = "#38bdf8", alpha = 0.6 }

    -- Build content node based on active item and view mode
    local contentChildren = {}

    -- 1. Floating Interactive Toolbar (Hidden in Ghost Mode)
    if not isGhost then
        table.insert(contentChildren, components.floatingToolbar(s, {
            onLock = function() state.toggleGhost() end,
            onAnchor = function() state.cycleAnchor() end,
            onScale = function() state.cycleScale() end,
            onOpacityCycle = function()
                local op = s.opacity or 0.85
                local nextOp = if op >= 0.9 then 0.4 elseif op >= 0.7 then 0.9 else 0.7
                state.setOpacity(nextOp)
            end,
            onViewMode = function() state.cycleViewMode() end,
            onPrev = function() state.prevItem() end,
            onNext = function() state.nextItem() end,
        }))
    end

    -- 2. Main Reference Display
    if not activeItem then
        table.insert(contentChildren, ui.box({
            fill = { hex = "#1e293b", alpha = 0.5 },
            radius = 6,
            padding = 24,
            align = "center",
            justify = "center",
        }, {
            ui.column({ gap = 8, align = "center" }, {
                ui.glyph({ name = "pin", fontSize = 28, color = { hex = "#64748b", alpha = 1.0 } }),
                ui.label({
                    text = "No Reference Pinned",
                    fontSize = 13,
                    color = { hex = "#94a3b8", alpha = 1.0 },
                }),
                ui.label({
                    text = "Open Pinboard Stash from status bar to add an image or note",
                    fontSize = 11,
                    color = { hex = "#64748b", alpha = 1.0 },
                }),
            }),
        }))
    else
        local viewMode = s.view_mode or "split"
        local showImage = (viewMode == "image" or viewMode == "split") and (activeItem.type == "image" or activeItem.path)
        local showNote = (viewMode == "note" or viewMode == "split") and (activeItem.type == "note" or activeItem.content)

        -- Fallback if view mode doesn't match active item type
        if not showImage and not showNote then
            if activeItem.type == "image" then
                showImage = true
            else
                showNote = true
            end
        end

        local mainNodes = {}

        -- Image Section
        if showImage and activeItem.path then
            table.insert(mainNodes, ui.box({
                radius = 6,
                border = { hex = "#334155", alpha = 0.4 },
                borderWidth = 1,
                padding = 4,
                fill = { hex = "#000000", alpha = 0.3 },
            }, {
                ui.image({
                    path = noctalia.expandPath(activeItem.path),
                    fit = "contain",
                    width = geo.width - 24,
                    height = if showNote then (geo.imageMaxHeight * 0.75) else geo.imageMaxHeight,
                    opacity = contentOpacity,
                    radius = 4,
                }),
            }))
        end

        -- Note / Checklist Section
        if showNote then
            local noteContent = activeItem.content or "No notes available."
            table.insert(mainNodes, ui.box({
                fill = { hex = "#1e293b", alpha = if isGhost then 0.6 else 0.8 },
                border = { hex = "#334155", alpha = 0.5 },
                borderWidth = 1,
                radius = 6,
                padding = 10,
                maxHeight = if showImage then 180 else geo.maxHeight - 70,
            }, {
                ui.scroll({
                    maxHeight = if showImage then 160 else geo.maxHeight - 90,
                }, {
                    ui.column({ gap = 4 }, {
                        ui.label({
                            text = activeItem.title or "Notes",
                            fontSize = 12,
                            fontWeight = "bold",
                            color = { hex = "#38bdf8", alpha = contentOpacity },
                        }),
                        ui.markdown({
                            source = noteContent,
                            opacity = contentOpacity,
                        }),
                    }),
                }),
            }))
        end

        table.insert(contentChildren, ui.column({ gap = 6 }, mainNodes))
    end

    -- 3. Render tree to layer shell
    layer.render(ui.box({
        fill = containerFill,
        border = containerBorder,
        borderWidth = if isGhost then 1 else 2,
        radius = 10,
        padding = 8,
        gap = 6,
        width = geo.width,
    }, contentChildren))
end

-- Subscribe to state updates
state.subscribe(renderOverlay)

-- Initial Render
renderOverlay()
