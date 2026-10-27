--!nonstrict

export type StashItem = {
    id: string,
    type: "image" | "note",
    title: string,
    path: string?,
    content: string?,
    source_url: string?,
    created_at: number,
}

export type PinboardData = {
    version: number,
    active_id: string?,
    ghost_mode: boolean,
    overlay_visible: boolean,
    view_mode: string, -- "image" | "note" | "split"
    opacity: number, -- 0.2 to 1.0
    scale: string, -- "small" | "medium" | "large"
    anchor: string, -- "top_right" | "top_left" | "bottom_right" | "bottom_left"
    items: { StashItem },
}

export type ClipboardValidationResult = {
    valid: boolean,
    type: string?,
    value: string?,
    title: string?,
    reason: string?,
}

local storage = {}

local DATA_FILE_NAME = "pinboard.json"
local IMAGES_DIR_NAME = "images"
local IMAGE_EXTENSIONS = { ".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp" }

function storage.defaultData(): PinboardData
    return {
        version = 1,
        active_id = nil,
        ghost_mode = false,
        overlay_visible = true,
        view_mode = "split",
        opacity = 0.85,
        scale = "medium",
        anchor = "top_right",
        items = {},
    }
end

function storage.getDataPath(): string
    local dataDir, err = noctalia.pluginDataDir()
    if err or not dataDir then
        dataDir = noctalia.expandPath("~/.local/share/noctalia/plugins/pinboard")
    end
    noctalia.mkdirAll(dataDir)
    return dataDir .. "/" .. DATA_FILE_NAME
end

function storage.ensureImagesDir(): string
    local dataDir, err = noctalia.pluginDataDir()
    if err or not dataDir then
        dataDir = noctalia.expandPath("~/.local/share/noctalia/plugins/pinboard")
    end
    local imagesDir = dataDir .. "/" .. IMAGES_DIR_NAME
    noctalia.mkdirAll(imagesDir)
    return imagesDir
end

function storage.load(): PinboardData
    local path = storage.getDataPath()
    if not noctalia.fileExists(path) then
        local initial = storage.defaultData()
        storage.save(initial)
        return initial
    end

    local raw, err = noctalia.readFile(path)
    if err or not raw or raw == "" then
        noctalia.log("[pinboard] Failed to read data file, using defaults: " .. tostring(err))
        return storage.defaultData()
    end

    local decoded, jsonErr = noctalia.json.decode(raw)
    if jsonErr or not decoded or type(decoded) ~= "table" then
        noctalia.log("[pinboard] Failed to decode json, resetting to defaults: " .. tostring(jsonErr))
        return storage.defaultData()
    end

    local default = storage.defaultData()
    local result: PinboardData = {
        version = decoded.version or default.version,
        active_id = decoded.active_id,
        ghost_mode = if decoded.ghost_mode ~= nil then decoded.ghost_mode else default.ghost_mode,
        overlay_visible = if decoded.overlay_visible ~= nil then decoded.overlay_visible else default.overlay_visible,
        view_mode = decoded.view_mode or default.view_mode,
        opacity = decoded.opacity or default.opacity,
        scale = decoded.scale or default.scale,
        anchor = decoded.anchor or default.anchor,
        items = if type(decoded.items) == "table" then decoded.items else {},
    }

    return result
end

function storage.save(data: PinboardData): (boolean, string?)
    local path = storage.getDataPath()
    local encoded, err = noctalia.json.encode(data, true)
    if err or not encoded then
        noctalia.log("[pinboard] Failed to encode json: " .. tostring(err))
        return false, err
    end

    local ok, writeErr = noctalia.writeFile(path, encoded)
    if not ok then
        noctalia.log("[pinboard] Failed to write data file: " .. tostring(writeErr))
        return false, writeErr
    end

    return true, nil
end

local function hasImageExtension(path: string): boolean
    local lower = string.lower(path)
    for _, ext in ipairs(IMAGE_EXTENSIONS) do
        if string.sub(lower, -string.len(ext)) == ext then
            return true
        end
    end
    return false
end

function storage.validateClipboard(rawText: string?): ClipboardValidationResult
    if not rawText then
        return { valid = false, reason = "empty" }
    end

    local text = noctalia.string.trim(rawText)
    if text == "" then
        return { valid = false, reason = "whitespace_only" }
    end

    local lower = string.lower(text)

    -- 1. Check for file:// protocol URI
    if string.sub(lower, 1, 7) == "file://" then
        local filePath = string.sub(text, 8)
        if hasImageExtension(filePath) then
            local filename = string.match(filePath, "([^/\\]+)$") or "Image Reference"
            return {
                valid = true,
                type = "image",
                value = filePath,
                title = filename,
            }
        end
    end

    -- 2. Check for absolute or ~/ local paths
    if string.sub(text, 1, 1) == "/" or string.sub(text, 1, 2) == "~/" then
        if hasImageExtension(text) then
            local filename = string.match(text, "([^/\\]+)$") or "Image Reference"
            return {
                valid = true,
                type = "image",
                value = text,
                title = filename,
            }
        end
    end

    -- 3. Check for web URL to image
    if string.sub(lower, 1, 7) == "http://" or string.sub(lower, 1, 8) == "https://" then
        local urlWithoutQuery = string.match(text, "^([^?#]+)") or text
        if hasImageExtension(urlWithoutQuery) then
            local filename = string.match(urlWithoutQuery, "([^/]+)$") or "Web Image Reference"
            return {
                valid = true,
                type = "image",
                value = text,
                title = filename,
            }
        end
    end

    -- 4. Check for Markdown checklist or structured notes
    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        local trimmedLine = noctalia.string.trim(line)
        if trimmedLine ~= "" then
            table.insert(lines, trimmedLine)
        end
    end

    local hasChecklist = false
    local hasHeadings = false
    for _, l in ipairs(lines) do
        if string.match(l, "^[%-*]%s*%[[ xX]%]") then
            hasChecklist = true
            break
        end
        if string.match(l, "^#{1,6}%s+") then
            hasHeadings = true
        end
    end

    if hasChecklist or hasHeadings or #lines >= 3 then
        local firstLine = lines[1] or "Note Reference"
        local title = string.gsub(firstLine, "^#{1,6}%s*", "")
        title = string.gsub(title, "^[%-*]%s*%[[ xX]%]", "")
        title = noctalia.string.trim(title)
        if string.len(title) > 30 then
            title = string.sub(title, 1, 30) .. "..."
        end
        if title == "" then
            title = "Note Reference"
        end

        return {
            valid = true,
            type = "note",
            value = text,
            title = title,
        }
    end

    return { valid = false, reason = "unstructured_text" }
end

return storage
