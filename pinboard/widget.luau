--!nonstrict

local state = require("./state.luau")

local function updateWidget()
    if not barWidget then
        return
    end

    local s = state.get()
    local items = s.items or {}
    local activeItem = state.getActiveItem()

    -- Set Glyph
    barWidget.setGlyph("pin")

    -- Format Status Text
    local statusText = "Pin"
    if not s.overlay_visible then
        statusText = "OFF"
    elseif s.ghost_mode then
        statusText = "GHOST"
    elseif #items > 0 then
        statusText = tostring(#items)
    end

    barWidget.setText(statusText)

    -- Construct Rich Tooltip
    local modeDesc = if not s.overlay_visible
        then "Hidden"
        elseif s.ghost_mode
        then "Ghost Mode (Click-Through)"
        else "Interactive Mode"

    local activeTitle = if activeItem then activeItem.title else "None"

    barWidget.setTooltip({
        { key = "Pinboard", value = modeDesc },
        { key = "Active", value = activeTitle },
        { key = "Stash Count", value = tostring(#items) },
        { key = "Left Click", value = "Open Stash Panel" },
        { key = "Right Click", value = "Toggle Ghost Mode" },
        { key = "Scroll", value = "Next / Previous Reference" },
    })
end

function update()
    updateWidget()
end

function onClick()
    noctalia.togglePanel("rigelyon/pinboard:panel")
end

function onRightClick()
    state.toggleGhost()
    updateWidget()
end

function onMiddleClick()
    state.toggleOverlay()
    updateWidget()
end

function onScroll(axis: string, steps: number, startsGesture: boolean)
    if steps > 0 then
        state.nextItem()
    else
        state.prevItem()
    end
    updateWidget()
end

-- Subscribe to state changes
state.subscribe(updateWidget)

-- Initial presentation
updateWidget()
