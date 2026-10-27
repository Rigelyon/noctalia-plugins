--!nonstrict

local storage = require("./storage.luau")
local state = require("./state.luau")
local components = require("./components.luau")

local activeTab = "stash" -- "stash" | "editor" | "settings"
local editingNoteTitle = ""
local editingNoteContent = ""
local editingItemId = nil

local function onPasteClipboard()
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
    noctalia.notify("Pinboard", "Added to stash: " .. newItem.title)
end

local function onBrowseFile()
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
            noctalia.notify("Pinboard", "Pinned: " .. filename)
        end
    end, 60000)
end

local function onOpenNewNote()
    editingItemId = nil
    editingNoteTitle = ""
    editingNoteContent = "### Notes & Checklist\n- [ ] Task 1\n- [ ] Task 2"
    activeTab = "editor"
    renderPanel()
end

local function onSaveNote()
    local title = noctalia.string.trim(editingNoteTitle)
    if title == "" then
        title = "Untitled Note"
    end

    if editingItemId then
        state.updateItemContent(editingItemId, editingNoteContent)
    else
        local newItem: storage.StashItem = {
            id = "item_" .. tostring(noctalia.nowMs()),
            type = "note",
            title = title,
            content = editingNoteContent,
            created_at = os.time(),
        }
        state.addItem(newItem)
    end

    activeTab = "stash"
    renderPanel()
end

function renderPanel()
    if not panel or not panel.render then
        return
    end

    local s = state.get()
    local items = s.items or {}

    -- Top Navigation Bar
    local navButtons = ui.row({ gap = 6, align = "center", justify = "space_between" }, {
        ui.row({ gap = 6, align = "center" }, {
            ui.button({
                text = "Stash (" .. tostring(#items) .. ")",
                glyph = "stack-2",
                variant = if activeTab == "stash" then "primary" else "ghost",
                onClick = function()
                    activeTab = "stash"
                    renderPanel()
                end,
            }),
            ui.button({
                text = "Overlay Setup",
                glyph = "adjustments-horizontal",
                variant = if activeTab == "settings" then "primary" else "ghost",
                onClick = function()
                    activeTab = "settings"
                    renderPanel()
                end,
            }),
        }),

        -- Quick Toggle Overlay Visibility
        ui.button({
            text = if s.overlay_visible then "Overlay ON" else "Overlay OFF",
            glyph = if s.overlay_visible then "eye" else "eye-off",
            variant = if s.overlay_visible then "default" else "outline",
            tooltip = "Toggle overlay visibility",
            onClick = function()
                state.toggleOverlay()
            end,
        }),
    })

    -- Main Content Area
    local bodyContent = nil

    if activeTab == "stash" then
        -- Action Buttons: Paste, Browse, New Note
        local actionBar = ui.row({ gap = 8 }, {
            ui.button({
                text = "Paste to Stash",
                glyph = "clipboard",
                variant = "primary",
                flexGrow = 1,
                onClick = onPasteClipboard,
            }),
            ui.button({
                text = "Browse File...",
                glyph = "folder",
                variant = "secondary",
                flexGrow = 1,
                onClick = onBrowseFile,
            }),
            ui.button({
                text = "New Note",
                glyph = "plus",
                variant = "secondary",
                flexGrow = 1,
                onClick = onOpenNewNote,
            }),
        })

        -- Items List
        local cards = {}
        if #items == 0 then
            table.insert(cards, ui.column({
                fill = { hex = "#1e293b", alpha = 0.4 },
                radius = 8,
                padding = 32,
                gap = 8,
                align = "center",
            }, {
                ui.glyph({ name = "pin", size = 32, color = { hex = "#64748b", alpha = 1.0 } }),
                ui.label({
                    text = "Stash is empty",
                    fontSize = 14,
                    fontWeight = "bold",
                    color = { hex = "#94a3b8", alpha = 1.0 },
                }),
                ui.label({
                    text = "Click 'Paste to Stash' or 'Browse File...' to add your first reference.",
                    fontSize = 12,
                    color = { hex = "#64748b", alpha = 1.0 },
                }),
            }))
        else
            for _, item in ipairs(items) do
                local isItemActive = (s.active_id == item.id)
                table.insert(cards, components.stashCard(
                    item,
                    isItemActive,
                    function()
                        state.setActive(item.id)
                    end,
                    function()
                        state.removeItem(item.id)
                    end
                ))
            end
        end

        bodyContent = ui.column({ gap = 10, flexGrow = 1, align = "stretch" }, {
            actionBar,
            ui.scroll({ flexGrow = 1 }, {
                ui.column({ gap = 8, align = "stretch" }, cards),
            }),
        })

    elseif activeTab == "editor" then
        bodyContent = ui.column({ gap = 10, flexGrow = 1, align = "stretch" }, {
            ui.label({ text = "Note Title", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
            ui.input({
                value = editingNoteTitle,
                placeholder = "Note title (e.g. Nether Coordinates)...",
                onChange = function(val) editingNoteTitle = val end,
            }),
            ui.label({ text = "Markdown Content & Checklist", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
            ui.input({
                value = editingNoteContent,
                multiline = true,
                placeholder = "Markdown notes & checklist:\n- [ ] Task 1\n- [ ] Task 2",
                onChange = function(val) editingNoteContent = val end,
            }),
            ui.row({ gap = 8, justify = "end" }, {
                ui.button({
                    text = "Cancel",
                    variant = "ghost",
                    onClick = function()
                        activeTab = "stash"
                        renderPanel()
                    end,
                }),
                ui.button({
                    text = "Save Note",
                    variant = "primary",
                    onClick = onSaveNote,
                }),
            }),
        })

    elseif activeTab == "settings" then
        local currentOpacityPct = math.floor((s.opacity or 0.85) * 100)
        bodyContent = ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
            -- Mode Switch
            ui.column({
                fill = { hex = "#1e293b", alpha = 0.5 },
                radius = 8,
                padding = 10,
                gap = 6,
            }, {
                ui.row({ gap = 8, align = "center", justify = "space_between" }, {
                    ui.column({ gap = 2 }, {
                        ui.label({ text = "Ghost Mode (Click-Through)", fontSize = 13, fontWeight = "bold" }),
                        ui.label({ text = "Clicks pass directly through to Minecraft or canvas", fontSize = 11, color = { hex = "#94a3b8", alpha = 1.0 } }),
                    }),
                    ui.button({
                        text = if s.ghost_mode then "LOCKED" else "INTERACTIVE",
                        variant = if s.ghost_mode then "primary" else "outline",
                        onClick = function()
                            state.toggleGhost()
                        end,
                    }),
                }),
            }),

            -- Corner Quadrant Position
            ui.column({ gap = 6, align = "stretch" }, {
                ui.label({ text = "Screen Corner Position", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                components.quadrantSelector(s.anchor or "top_right", function(a)
                    state.setAnchor(a)
                end),
            }),

            -- Scale / Size
            ui.column({ gap = 6, align = "stretch" }, {
                ui.label({ text = "Overlay Window Scale", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                ui.row({ gap = 6 }, {
                    ui.button({
                        text = "Small (300px)",
                        variant = if s.scale == "small" then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setScale("small") end,
                    }),
                    ui.button({
                        text = "Medium (420px)",
                        variant = if s.scale == "medium" then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setScale("medium") end,
                    }),
                    ui.button({
                        text = "Large (560px)",
                        variant = if s.scale == "large" then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setScale("large") end,
                    }),
                }),
            }),

            -- Opacity Quick Steps
            ui.column({ gap = 6, align = "stretch" }, {
                ui.label({ text = "Overlay Opacity: " .. tostring(currentOpacityPct) .. "%", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                ui.row({ gap = 6 }, {
                    ui.button({
                        text = "40%",
                        variant = if s.opacity == 0.4 then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setOpacity(0.4) end,
                    }),
                    ui.button({
                        text = "65%",
                        variant = if s.opacity == 0.65 then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setOpacity(0.65) end,
                    }),
                    ui.button({
                        text = "85%",
                        variant = if s.opacity == 0.85 then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setOpacity(0.85) end,
                    }),
                    ui.button({
                        text = "100%",
                        variant = if s.opacity == 1.0 then "primary" else "ghost",
                        flexGrow = 1,
                        onClick = function() state.setOpacity(1.0) end,
                    }),
                }),
            }),

            -- Hyprland Bind Helper
            ui.column({
                fill = { hex = "#0f172a", alpha = 0.8 },
                border = { hex = "#334155", alpha = 0.5 },
                borderWidth = 1,
                radius = 6,
                padding = 10,
                gap = 4,
            }, {
                ui.label({ text = "Global Shortcut (Hyprland):", fontSize = 11, fontWeight = "bold", color = { hex = "#38bdf8", alpha = 1.0 } }),
                ui.label({
                    text = "bind = SUPER ALT, G, exec, noctalia msg plugin rigelyon/pinboard:service all toggle-ghost",
                    fontSize = 10,
                    color = { hex = "#94a3b8", alpha = 1.0 },
                }),
            }),
        })
    end

    panel.render(ui.column({
        flexGrow = 1,
        gap = 12,
        align = "stretch",
    }, {
        navButtons,
        bodyContent,
    }))
end

function onOpen(_context)
    renderPanel()
end

-- Subscribe to state updates
state.subscribe(renderPanel)

-- Initial Render
renderPanel()
