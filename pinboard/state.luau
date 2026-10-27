--!nonstrict

local storage = require("./storage")

export type StashItem = storage.StashItem
export type PinboardData = storage.PinboardData

local state = {}

local SCALE_PRESETS = {
    small = { width = 300, maxHeight = 360, imageMaxHeight = 220 },
    medium = { width = 420, maxHeight = 500, imageMaxHeight = 320 },
    large = { width = 560, maxHeight = 680, imageMaxHeight = 440 },
}

local ANCHOR_PRESETS = {
    top_right = { anchors = { "top", "right" }, margins = { top = 24, right = 24 } },
    top_left = { anchors = { "top", "left" }, margins = { top = 24, left = 24 } },
    bottom_right = { anchors = { "bottom", "right" }, margins = { bottom = 24, right = 24 } },
    bottom_left = { anchors = { "bottom", "left" }, margins = { bottom = 24, left = 24 } },
}

local currentData: PinboardData = storage.load()
local listeners = {}

local function notify()
    storage.save(currentData)
    for _, cb in ipairs(listeners) do
        local ok, err = pcall(cb)
        if not ok then
            noctalia.log("[pinboard] Listener error: " .. tostring(err))
        end
    end
end

function state.get(): PinboardData
    return currentData
end

function state.subscribe(listener: () -> ()): () -> ()
    table.insert(listeners, listener)
    return function()
        for i, cb in ipairs(listeners) do
            if cb == listener then
                table.remove(listeners, i)
                break
            end
        end
    end
end

function state.toggleGhost(): boolean
    currentData.ghost_mode = not currentData.ghost_mode
    notify()
    return currentData.ghost_mode
end

function state.toggleOverlay(): boolean
    currentData.overlay_visible = not currentData.overlay_visible
    notify()
    return currentData.overlay_visible
end

function state.setAnchor(anchor: string)
    if ANCHOR_PRESETS[anchor] then
        currentData.anchor = anchor
        notify()
    end
end

function state.cycleAnchor()
    local order = { "top_right", "bottom_right", "bottom_left", "top_left" }
    local current = currentData.anchor or "top_right"
    local nextAnchor = order[1]
    for i, a in ipairs(order) do
        if a == current then
            nextAnchor = order[(i % #order) + 1]
            break
        end
    end
    state.setAnchor(nextAnchor)
end

function state.setOpacity(val: number)
    local clamped = math.max(0.1, math.min(1.0, val))
    currentData.opacity = clamped
    notify()
end

function state.setScale(scale: string)
    if SCALE_PRESETS[scale] then
        currentData.scale = scale
        notify()
    end
end

function state.cycleScale()
    local order = { "small", "medium", "large" }
    local current = currentData.scale or "medium"
    local nextScale = order[1]
    for i, s in ipairs(order) do
        if s == current then
            nextScale = order[(i % #order) + 1]
            break
        end
    end
    state.setScale(nextScale)
end

function state.setViewMode(mode: string)
    if mode == "image" or mode == "note" or mode == "split" then
        currentData.view_mode = mode
        notify()
    end
end

function state.cycleViewMode()
    local order = { "split", "image", "note" }
    local current = currentData.view_mode or "split"
    local nextMode = order[1]
    for i, m in ipairs(order) do
        if m == current then
            nextMode = order[(i % #order) + 1]
            break
        end
    end
    state.setViewMode(nextMode)
end

function state.getActiveItem(): StashItem?
    if not currentData.active_id or #currentData.items == 0 then
        if #currentData.items > 0 then
            currentData.active_id = currentData.items[1].id
            return currentData.items[1]
        end
        return nil
    end

    for _, it in ipairs(currentData.items) do
        if it.id == currentData.active_id then
            return it
        end
    end

    if #currentData.items > 0 then
        currentData.active_id = currentData.items[1].id
        return currentData.items[1]
    end

    return nil
end

function state.setActive(id: string)
    for _, it in ipairs(currentData.items) do
        if it.id == id then
            currentData.active_id = id
            notify()
            return
        end
    end
end

function state.nextItem()
    local items = currentData.items
    if #items <= 1 then
        return
    end

    local currentIdx = 1
    for i, it in ipairs(items) do
        if it.id == currentData.active_id then
            currentIdx = i
            break
        end
    end

    local nextIdx = (currentIdx % #items) + 1
    currentData.active_id = items[nextIdx].id
    notify()
end

function state.prevItem()
    local items = currentData.items
    if #items <= 1 then
        return
    end

    local currentIdx = 1
    for i, it in ipairs(items) do
        if it.id == currentData.active_id then
            currentIdx = i
            break
        end
    end

    local prevIdx = if currentIdx <= 1 then #items else currentIdx - 1
    currentData.active_id = items[prevIdx].id
    notify()
end

function state.addItem(item: StashItem): string
    if not item.id or item.id == "" then
        item.id = "item_" .. tostring(noctalia.nowMs())
    end
    if not item.created_at then
        item.created_at = os.time()
    end

    table.insert(currentData.items, 1, item)
    currentData.active_id = item.id
    currentData.overlay_visible = true
    notify()
    return item.id
end

function state.removeItem(id: string): boolean
    local index = nil
    for i, it in ipairs(currentData.items) do
        if it.id == id then
            index = i
            break
        end
    end

    if not index then
        return false
    end

    table.remove(currentData.items, index)
    if currentData.active_id == id then
        if #currentData.items > 0 then
            local nextIdx = math.min(index, #currentData.items)
            currentData.active_id = currentData.items[nextIdx].id
        else
            currentData.active_id = nil
        end
    end

    notify()
    return true
end

function state.updateItemContent(id: string, content: string): boolean
    for _, it in ipairs(currentData.items) do
        if it.id == id then
            it.content = content
            notify()
            return true
        end
    end
    return false
end

function state.getGeometry()
    local scaleKey = currentData.scale or "medium"
    local anchorKey = currentData.anchor or "top_right"

    local scaleInfo = SCALE_PRESETS[scaleKey] or SCALE_PRESETS.medium
    local anchorInfo = ANCHOR_PRESETS[anchorKey] or ANCHOR_PRESETS.top_right

    return {
        width = scaleInfo.width,
        maxHeight = scaleInfo.maxHeight,
        imageMaxHeight = scaleInfo.imageMaxHeight,
        anchors = anchorInfo.anchors,
        margins = anchorInfo.margins,
    }
end

return state
