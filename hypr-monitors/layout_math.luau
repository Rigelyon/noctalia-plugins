--!nonstrict
-- 2D Geometric Layout Calculations, Proportional Canvas Scaling, and Gapless Snap Alignment
local layout_math = {}

export type Monitor = {
  id: number?,
  name: string,
  description: string?,
  make: string?,
  model: string?,
  serial: string?,
  width: number,
  height: number,
  refreshRate: number,
  x: number,
  y: number,
  scale: number,
  transform: number,
  focused: boolean?,
  dpmsStatus: boolean?,
  vrr: number?,
  mirrorOf: string?,
  availableModes: { string }?,
  disabled: boolean?,
}

-- Returns effective virtual resolution considering display scale
function layout_math.getVirtualSize(m: Monitor): (number, number)
  local scale = m.scale or 1.0
  if scale <= 0 then scale = 1.0 end
  local w = m.width or 1920
  local h = m.height or 1080

  -- If transformed 90 or 270 degrees, swap width and height
  if m.transform == 1 or m.transform == 3 then
    w, h = h, w
  end

  local vw = math.floor(w / scale + 0.5)
  local vh = math.floor(h / scale + 0.5)
  return vw, vh
end

-- Snaps target monitor directly to the right of anchor monitor without gaps
function layout_math.snapRight(target: Monitor, anchor: Monitor)
  local anchorVw, _ = layout_math.getVirtualSize(anchor)
  target.x = (anchor.x or 0) + anchorVw
  target.y = anchor.y or 0
end

-- Snaps target monitor directly to the left of anchor monitor without gaps
function layout_math.snapLeft(target: Monitor, anchor: Monitor)
  local targetVw, _ = layout_math.getVirtualSize(target)
  target.x = (anchor.x or 0) - targetVw
  target.y = anchor.y or 0
end

-- Snaps target monitor directly above anchor monitor
function layout_math.snapAbove(target: Monitor, anchor: Monitor)
  local _, targetVh = layout_math.getVirtualSize(target)
  target.x = anchor.x or 0
  target.y = (anchor.y or 0) - targetVh
end

-- Snaps target monitor directly below anchor monitor
function layout_math.snapBelow(target: Monitor, anchor: Monitor)
  local _, anchorVh = layout_math.getVirtualSize(anchor)
  target.x = anchor.x or 0
  target.y = (anchor.y or 0) + anchorVh
end

-- Aligns top edge of target to anchor
function layout_math.alignTops(target: Monitor, anchor: Monitor)
  target.y = anchor.y or 0
end

-- Aligns bottom edge of target to anchor
function layout_math.alignBottoms(target: Monitor, anchor: Monitor)
  local _, anchorVh = layout_math.getVirtualSize(anchor)
  local _, targetVh = layout_math.getVirtualSize(target)
  target.y = (anchor.y or 0) + anchorVh - targetVh
end

-- Normalizes coordinates so the top-leftmost monitor starts at (0, 0)
function layout_math.normalizeCoordinates(monitors: { Monitor })
  if #monitors == 0 then return end
  local minX = nil
  local minY = nil

  for _, m in ipairs(monitors) do
    if not m.disabled then
      local mx = m.x or 0
      local my = m.y or 0
      if minX == nil or mx < minX then minX = mx end
      if minY == nil or my < minY then minY = my end
    end
  end

  if minX and minY and (minX ~= 0 or minY ~= 0) then
    for _, m in ipairs(monitors) do
      if not m.disabled then
        m.x = (m.x or 0) - minX
        m.y = (m.y or 0) - minY
      end
    end
  end
end

-- Projects all monitors onto canvas dimensions (viewportW x viewportH)
function layout_math.computeCanvasProjection(monitors: { Monitor }, viewportW: number, viewportH: number): {
  scaleFactor: number,
  offsetX: number,
  offsetY: number,
  items: { [string]: { x: number, y: number, w: number, h: number } },
}
  local minX = 0
  local minY = 0
  local maxX = 1920
  local maxY = 1080
  local count = 0

  for _, m in ipairs(monitors) do
    count = count + 1
    local vw, vh = layout_math.getVirtualSize(m)
    local mx = m.x or 0
    local my = m.y or 0
    if count == 1 then
      minX = mx
      minY = my
      maxX = mx + vw
      maxY = my + vh
    else
      if mx < minX then minX = mx end
      if my < minY then minY = my end
      if (mx + vw) > maxX then maxX = mx + vw end
      if (my + vh) > maxY then maxY = my + vh end
    end
  end

  local totalW = math.max(1, maxX - minX)
  local totalH = math.max(1, maxY - minY)

  -- Add padding margin inside canvas
  local padH = 28
  local padV = 16
  local availW = math.max(100, viewportW - padH * 2)
  local availH = math.max(60, viewportH - padV * 2)

  local scaleFactor = math.min(availW / totalW, availH / totalH)
  if scaleFactor <= 0 then scaleFactor = 0.1 end

  local renderedW = totalW * scaleFactor
  local renderedH = totalH * scaleFactor
  local offsetX = (viewportW - renderedW) / 2 - (minX * scaleFactor)
  local offsetY = (viewportH - renderedH) / 2 - (minY * scaleFactor)

  local totalMonitors = #monitors
  local maxCardW = (totalMonitors > 1) and math.floor((availW - (totalMonitors - 1) * 12) / totalMonitors) or availW

  local items = {}
  for _, m in ipairs(monitors) do
    local vw, vh = layout_math.getVirtualSize(m)
    local isPortrait = (m.transform == 1 or m.transform == 3)
    local px = math.floor((m.x or 0) * scaleFactor + offsetX)
    local py = math.floor((m.y or 0) * scaleFactor + offsetY)

    local minW = isPortrait and 76 or 110
    local minH = isPortrait and 110 or 64
    local pw = math.max(minW, math.floor(vw * scaleFactor))
    local ph = math.max(minH, math.floor(vh * scaleFactor))

    if totalMonitors == 1 then
      if isPortrait then
        pw = 110
        ph = 140
      else
        pw = 230
        ph = 125
      end
    else
      if not isPortrait and pw > maxCardW and maxCardW >= minW then
        pw = maxCardW
        ph = math.max(minH, math.floor(pw * (vh / vw)))
      end
    end
    items[m.name] = { x = px, y = py, w = pw, h = ph }
  end

  return {
    scaleFactor = scaleFactor,
    offsetX = offsetX,
    offsetY = offsetY,
    items = items,
  }
end

-- Preset: Extend horizontally side-by-side
function layout_math.presetExtend(monitors: { Monitor })
  local curX = 0
  for _, m in ipairs(monitors) do
    m.disabled = false
    m.mirrorOf = nil
    m.x = curX
    m.y = 0
    local vw, _ = layout_math.getVirtualSize(m)
    curX = curX + vw
  end
end

-- Preset: Mirror/Duplicate secondary to primary
function layout_math.presetMirror(monitors: { Monitor }, primaryName: string)
  for _, m in ipairs(monitors) do
    m.disabled = false
    if m.name == primaryName then
      m.mirrorOf = nil
      m.x = 0
      m.y = 0
    else
      m.mirrorOf = primaryName
      m.x = 0
      m.y = 0
    end
  end
end

-- Preset: Keep single monitor active, disable others
function layout_math.presetSingle(monitors: { Monitor }, keepName: string)
  for _, m in ipairs(monitors) do
    if m.name == keepName then
      m.disabled = false
      m.mirrorOf = nil
      m.x = 0
      m.y = 0
    else
      m.disabled = true
      m.mirrorOf = nil
    end
  end
end

return layout_math
