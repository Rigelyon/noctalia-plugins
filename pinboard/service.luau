--!nonstrict

local storage = require("./storage")
local state = require("./state")

local function syncLayerVisibility()
    local s = state.get()
    if s.overlay_visible and s.active_id then
        noctalia.layer.show("ref-overlay")
    else
        noctalia.layer.hide("ref-overlay")
    end
end

local function handlePasteClipboard()
    local clipText = noctalia.clipboardText()
    local validated = storage.validateClipboard(clipText)

    if not validated.valid then
        noctalia.notify("Pinboard", "Clipboard does not contain an image file, image URL, or markdown checklist.")
        return
    end

    local newItem: storage.StashItem = {
        id = "item_" .. tostring(noctalia.nowMs()),
        type = validated.type or "image",
        title = validated.title or "New Reference",
        path = if validated.type == "image" then validated.value else nil,
        content = if validated.type == "note" then validated.value else nil,
        created_at = os.time(),
    }

    state.addItem(newItem)
    syncLayerVisibility()
    noctalia.notify("Pinboard", "Added to stash: " .. newItem.title)
end

local function handleBrowseFile()
    -- Try Zenity first, then fallback to kdialog or XDG portal
    local cmd = "zenity --file-selection --title='Select Reference Image' --file-filter='Images | *.png *.jpg *.jpeg *.webp *.svg *.gif *.bmp' 2>/dev/null"
    if not noctalia.commandExists("zenity") and noctalia.commandExists("kdialog") then
        cmd = "kdialog --getopenfilename : 'Images (*.png *.jpg *.jpeg *.webp *.svg *.gif *.bmp)' 2>/dev/null"
    end

    noctalia.runAsync(cmd, function(res)
        if res.exitCode == 0 and res.stdout and res.stdout ~= "" then
            local path = noctalia.string.trim(res.stdout)
            local filename = string.match(path, "([^/\\]+)$") or "Image Reference"
            local item: storage.StashItem = {
                id = "item_" .. tostring(noctalia.nowMs()),
                type = "image",
                title = filename,
                path = path,
                created_at = os.time(),
            }
            state.addItem(item)
            syncLayerVisibility()
            noctalia.notify("Pinboard", "Pinned: " .. filename)
        end
    end, 60000)
end

function onIpc(event: string, payload: string?)
    if event == "toggle-ghost" then
        local isGhost = state.toggleGhost()
        local msg = if isGhost then "Ghost Mode: Click-Through Locked" else "Interactive Mode Unlocked"
        noctalia.notify("Pinboard", msg)

    elseif event == "toggle-overlay" then
        local isVisible = state.toggleOverlay()
        syncLayerVisibility()
        local msg = if isVisible then "Overlay Shown" else "Overlay Hidden"
        noctalia.notify("Pinboard", msg)

    elseif event == "set-anchor" and payload then
        state.setAnchor(payload)

    elseif event == "set-opacity" and payload then
        local num = tonumber(payload)
        if num then
            state.setOpacity(num)
        end

    elseif event == "set-scale" and payload then
        state.setScale(payload)

    elseif event == "next-item" then
        state.nextItem()
        syncLayerVisibility()

    elseif event == "prev-item" then
        state.prevItem()
        syncLayerVisibility()

    elseif event == "pin-item" and payload then
        state.setActive(payload)
        syncLayerVisibility()

    elseif event == "paste-clipboard" then
        handlePasteClipboard()

    elseif event == "browse-file" then
        handleBrowseFile()
    end
end

function onConfigChanged()
    local s = state.get()
    local defAnchor = noctalia.getConfig("default_anchor")
    if defAnchor and type(defAnchor) == "string" and not s.anchor then
        state.setAnchor(defAnchor)
    end

    local defScale = noctalia.getConfig("default_scale")
    if defScale and type(defScale) == "string" and not s.scale then
        state.setScale(defScale)
    end

    local defOpacity = noctalia.getConfig("default_opacity")
    if defOpacity and type(defOpacity) == "number" and not s.opacity then
        state.setOpacity(defOpacity)
    end
end

function onEnable()
    noctalia.log("[pinboard] Service initialized")
    state.subscribe(syncLayerVisibility)
    syncLayerVisibility()
end

-- Initialize
state.subscribe(syncLayerVisibility)
syncLayerVisibility()
