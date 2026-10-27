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
    local s = state.get()
    local items = s.items or {}

    -- Top Navigation Bar
    local navButtons = ui.row({ gap = 6, align = "center", justify = "space_between" }, {
        ui.row({ gap = 6, align = "center" }, {
            ui.button({
                onClick = function() activeTab = "stash" renderPanel() end,
                fill = if activeTab == "stash" then { hex = "#0284c7", alpha = 0.3 } else { hex = "#1e293b", alpha = 0.5 },
                border = if activeTab == "stash" then { hex = "#38bdf8", alpha = 1.0 } else { hex = "#334155", alpha = 0.6 },
                borderWidth = 1,
                radius = 6,
                paddingH = 10,
                paddingV = 6,
            }, {
                ui.row({ gap = 4, align = "center" }, {
                    ui.glyph({ name = "stack-2", fontSize = 13, color = { hex = "#f8fafc", alpha = 1.0 } }),
                    ui.label({ text = "Stash (" .. tostring(#items) .. ")", fontSize = 12 }),
                }),
            }),
            ui.button({
                onClick = function() activeTab = "settings" renderPanel() end,
                fill = if activeTab == "settings" then { hex = "#0284c7", alpha = 0.3 } else { hex = "#1e293b", alpha = 0.5 },
                border = if activeTab == "settings" then { hex = "#38bdf8", alpha = 1.0 } else { hex = "#334155", alpha = 0.6 },
                borderWidth = 1,
                radius = 6,
                paddingH = 10,
                paddingV = 6,
            }, {
                ui.row({ gap = 4, align = "center" }, {
                    ui.glyph({ name = "adjustments-horizontal", fontSize = 13, color = { hex = "#f8fafc", alpha = 1.0 } }),
                    ui.label({ text = "Overlay Setup", fontSize = 12 }),
                }),
            }),
        }),

        -- Quick Toggle Overlay Visibility
        ui.button({
            tooltip = "Toggle overlay visibility",
            onClick = function() state.toggleOverlay() end,
            fill = if s.overlay_visible then { hex = "#10b981", alpha = 0.2 } else { hex = "#f43f5e", alpha = 0.2 },
            border = if s.overlay_visible then { hex = "#10b981", alpha = 0.6 } else { hex = "#f43f5e", alpha = 0.6 },
            borderWidth = 1,
            radius = 6,
            paddingH = 8,
            paddingV = 6,
        }, {
            ui.row({ gap = 4, align = "center" }, {
                ui.glyph({ name = if s.overlay_visible then "eye" else "eye-off", fontSize = 13, color = { hex = "#ffffff", alpha = 1.0 } }),
                ui.label({ text = if s.overlay_visible then "Overlay ON" else "Overlay OFF", fontSize = 11 }),
            }),
        }),
    })

    -- Main Content Area
    local bodyContent = nil

    if activeTab == "stash" then
        -- Action Buttons: Paste, Browse, New Note
        local actionBar = ui.row({ gap = 8 }, {
            ui.button({
                onClick = onPasteClipboard,
                fill = { hex = "#0284c7", alpha = 0.9 },
                radius = 6,
                paddingH = 12,
                paddingV = 8,
                flexGrow = 1,
            }, {
                ui.row({ gap = 6, align = "center", justify = "center" }, {
                    ui.glyph({ name = "clipboard", fontSize = 14, color = { hex = "#ffffff", alpha = 1.0 } }),
                    ui.label({ text = "Paste to Stash", fontSize = 12, fontWeight = "bold", color = { hex = "#ffffff", alpha = 1.0 } }),
                }),
            }),
            ui.button({
                onClick = onBrowseFile,
                fill = { hex = "#1e293b", alpha = 0.8 },
                border = { hex = "#334155", alpha = 0.7 },
                borderWidth = 1,
                radius = 6,
                paddingH = 12,
                paddingV = 8,
                flexGrow = 1,
            }, {
                ui.row({ gap = 6, align = "center", justify = "center" }, {
                    ui.glyph({ name = "folder", fontSize = 14, color = { hex = "#f8fafc", alpha = 1.0 } }),
                    ui.label({ text = "Browse File...", fontSize = 12, color = { hex = "#f8fafc", alpha = 1.0 } }),
                }),
            }),
            ui.button({
                onClick = onOpenNewNote,
                fill = { hex = "#6366f1", alpha = 0.8 },
                radius = 6,
                paddingH = 12,
                paddingV = 8,
                flexGrow = 1,
            }, {
                ui.row({ gap = 6, align = "center", justify = "center" }, {
                    ui.glyph({ name = "plus", fontSize = 14, color = { hex = "#ffffff", alpha = 1.0 } }),
                    ui.label({ text = "New Note", fontSize = 12, fontWeight = "bold", color = { hex = "#ffffff", alpha = 1.0 } }),
                }),
            }),
        })

        -- Items List
        local cards = {}
        if #items == 0 then
            table.insert(cards, ui.box({
                fill = { hex = "#1e293b", alpha = 0.4 },
                radius = 8,
                padding = 32,
                align = "center",
                justify = "center",
            }, {
                ui.column({ gap = 8, align = "center" }, {
                    ui.glyph({ name = "pin", fontSize = 32, color = { hex = "#64748b", alpha = 1.0 } }),
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

        bodyContent = ui.column({ gap = 10, flexGrow = 1 }, {
            actionBar,
            ui.scroll({ flexGrow = 1, maxHeight = 430 }, {
                ui.column({ gap = 8 }, cards),
            }),
        })

    elseif activeTab == "editor" then
        bodyContent = ui.column({ gap = 10, flexGrow = 1 }, {
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
                    onClick = function() activeTab = "stash" renderPanel() end,
                    fill = { hex = "#334155", alpha = 0.5 },
                    radius = 6,
                    paddingH = 12,
                    paddingV = 6,
                }, {
                    ui.label({ text = "Cancel", fontSize = 12 }),
                }),
                ui.button({
                    onClick = onSaveNote,
                    fill = { hex = "#0284c7", alpha = 0.9 },
                    radius = 6,
                    paddingH = 14,
                    paddingV = 6,
                }, {
                    ui.label({ text = "Save Note", fontSize = 12, fontWeight = "bold", color = { hex = "#ffffff", alpha = 1.0 } }),
                }),
            }),
        })

    elseif activeTab == "settings" then
        local currentOpacityPct = math.floor((s.opacity or 0.85) * 100)
        bodyContent = ui.column({ gap = 12, flexGrow = 1 }, {
            -- Mode Switch
            ui.box({
                fill = { hex = "#1e293b", alpha = 0.5 },
                radius = 8,
                padding = 10,
            }, {
                ui.row({ gap = 8, align = "center", justify = "space_between" }, {
                    ui.column({ gap = 2 }, {
                        ui.label({ text = "Ghost Mode (Click-Through)", fontSize = 13, fontWeight = "bold" }),
                        ui.label({ text = "Clicks pass directly through to Minecraft or canvas", fontSize = 11, color = { hex = "#94a3b8", alpha = 1.0 } }),
                    }),
                    ui.button({
                        onClick = function() state.toggleGhost() end,
                        fill = if s.ghost_mode then { hex = "#4f46e5", alpha = 0.9 } else { hex = "#334155", alpha = 0.6 },
                        radius = 6,
                        paddingH = 12,
                        paddingV = 6,
                    }, {
                        ui.label({ text = if s.ghost_mode then "LOCKED" else "INTERACTIVE", fontSize = 11, fontWeight = "bold" }),
                    }),
                }),
            }),

            -- Corner Quadrant Position
            ui.column({ gap = 6 }, {
                ui.label({ text = "Screen Corner Position", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                components.quadrantSelector(s.anchor or "top_right", function(a) state.setAnchor(a) end),
            }),

            -- Scale / Size
            ui.column({ gap = 6 }, {
                ui.label({ text = "Overlay Window Scale", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                ui.row({ gap = 6 }, {
                    ui.button({
                        onClick = function() state.setScale("small") end,
                        fill = if s.scale == "small" then { hex = "#0284c7", alpha = 0.3 } else { hex = "#1e293b", alpha = 0.5 },
                        border = if s.scale == "small" then { hex = "#38bdf8", alpha = 1.0 } else { hex = "#334155", alpha = 0.6 },
                        borderWidth = 1,
                        radius = 6,
                        paddingH = 10,
                        paddingV = 6,
                        flexGrow = 1,
                    }, {
                        ui.label({ text = "Small (300px)", fontSize = 11, align = "center" }),
                    }),
                    ui.button({
                        onClick = function() state.setScale("medium") end,
                        fill = if s.scale == "medium" then { hex = "#0284c7", alpha = 0.3 } else { hex = "#1e293b", alpha = 0.5 },
                        border = if s.scale == "medium" then { hex = "#38bdf8", alpha = 1.0 } else { hex = "#334155", alpha = 0.6 },
                        borderWidth = 1,
                        radius = 6,
                        paddingH = 10,
                        paddingV = 6,
                        flexGrow = 1,
                    }, {
                        ui.label({ text = "Medium (420px)", fontSize = 11, align = "center" }),
                    }),
                    ui.button({
                        onClick = function() state.setScale("large") end,
                        fill = if s.scale == "large" then { hex = "#0284c7", alpha = 0.3 } else { hex = "#1e293b", alpha = 0.5 },
                        border = if s.scale == "large" then { hex = "#38bdf8", alpha = 1.0 } else { hex = "#334155", alpha = 0.6 },
                        borderWidth = 1,
                        radius = 6,
                        paddingH = 10,
                        paddingV = 6,
                        flexGrow = 1,
                    }, {
                        ui.label({ text = "Large (560px)", fontSize = 11, align = "center" }),
                    }),
                }),
            }),

            -- Opacity Quick Steps
            ui.column({ gap = 6 }, {
                ui.label({ text = "Overlay Opacity: " .. tostring(currentOpacityPct) .. "%", fontSize = 12, color = { hex = "#94a3b8", alpha = 1.0 } }),
                ui.row({ gap = 6 }, {
                    ui.button({
                        onClick = function() state.setOpacity(0.4) end,
                        fill = { hex = "#1e293b", alpha = 0.6 },
                        radius = 6,
                        paddingH = 8,
                        paddingV = 6,
                        flexGrow = 1,
                    }, { ui.label({ text = "40%", fontSize = 11 }) }),
                    ui.button({
                        onClick = function() state.setOpacity(0.65) end,
                        fill = { hex = "#1e293b", alpha = 0.6 },
                        radius = 6,
                        paddingH = 8,
                        paddingV = 6,
                        flexGrow = 1,
                    }, { ui.label({ text = "65%", fontSize = 11 }) }),
                    ui.button({
                        onClick = function() state.setOpacity(0.85) end,
                        fill = { hex = "#1e293b", alpha = 0.6 },
                        radius = 6,
                        paddingH = 8,
                        paddingV = 6,
                        flexGrow = 1,
                    }, { ui.label({ text = "85%", fontSize = 11 }) }),
                    ui.button({
                        onClick = function() state.setOpacity(1.0) end,
                        fill = { hex = "#1e293b", alpha = 0.6 },
                        radius = 6,
                        paddingH = 8,
                        paddingV = 6,
                        flexGrow = 1,
                    }, { ui.label({ text = "100%", fontSize = 11 }) }),
                }),
            }),

            -- Hyprland Bind Helper
            ui.box({
                fill = { hex = "#0f172a", alpha = 0.8 },
                border = { hex = "#334155", alpha = 0.5 },
                borderWidth = 1,
                radius = 6,
                padding = 10,
            }, {
                ui.column({ gap = 4 }, {
                    ui.label({ text = "Global Shortcut (Hyprland):", fontSize = 11, fontWeight = "bold", color = { hex = "#38bdf8", alpha = 1.0 } }),
                    ui.label({
                        text = "bind = SUPER ALT, G, exec, noctalia msg plugin rigelyon/pinboard:service all toggle-ghost",
                        fontSize = 10,
                        color = { hex = "#94a3b8", alpha = 1.0 },
                    }),
                }),
            }),
        })
    end

    panel.render(ui.box({
        fill = { hex = "#111827", alpha = 0.98 },
        padding = 12,
        gap = 12,
        flexGrow = 1,
    }, {
        navButtons,
        bodyContent,
    }))
end

-- Subscribe to state updates
state.subscribe(renderPanel)

-- Initial Render
renderPanel()
