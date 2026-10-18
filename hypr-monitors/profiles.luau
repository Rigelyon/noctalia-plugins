--!nonstrict
-- Named Display Profiles Store & Auto-Matching Engine
local layoutMath = require("./layout_math.luau")

local profiles = {
  activeProfileId = nil,
  cachedProfiles = {},
}

export type Profile = {
  id: string,
  name: string,
  fingerprint: { string },
  monitors: { layoutMath.Monitor },
}

local function getStoragePath(): string?
  if not noctalia or not noctalia.pluginDataDir then return nil end
  local dir, _ = noctalia.pluginDataDir()
  if not dir then return nil end
  return dir .. "/profiles.json"
end

function profiles.loadProfiles(): { Profile }
  local path = getStoragePath()
  if not path or not noctalia.readFile or not noctalia.fileExists or not noctalia.fileExists(path) then
    return profiles.cachedProfiles
  end

  local content, _ = noctalia.readFile(path)
  if not content or content == "" then return profiles.cachedProfiles end

  local ok, data = pcall(function()
    return noctalia.json.decode(content)
  end)

  if ok and type(data) == "table" then
    profiles.activeProfileId = data.active_profile
    if type(data.profiles) == "table" then
      profiles.cachedProfiles = data.profiles
    end
  end

  return profiles.cachedProfiles
end

function profiles.saveProfile(name: string, currentMonitors: { layoutMath.Monitor }): (boolean, Profile?)
  local path = getStoragePath()
  if not path or not noctalia.writeFile then return false, nil end

  local names = {}
  local clonedMonitors = {}
  for _, m in ipairs(currentMonitors) do
    table.insert(names, m.name)
    table.insert(clonedMonitors, {
      name = m.name,
      width = m.width,
      height = m.height,
      refreshRate = m.refreshRate,
      x = m.x,
      y = m.y,
      scale = m.scale,
      transform = m.transform,
      vrr = m.vrr,
      mirrorOf = m.mirrorOf,
      disabled = m.disabled,
    })
  end
  table.sort(names)

  local profileId = string.lower(string.gsub(name, "%s+", "-")) .. "-" .. tostring(os.time())
  local newProf: Profile = {
    id = profileId,
    name = name,
    fingerprint = names,
    monitors = clonedMonitors,
  }

  table.insert(profiles.cachedProfiles, newProf)
  profiles.activeProfileId = profileId

  local payload = {
    active_profile = profiles.activeProfileId,
    profiles = profiles.cachedProfiles,
  }

  local enc, _ = noctalia.json.encode(payload, true)
  if enc then
    noctalia.writeFile(path, enc)
  end

  return true, newProf
end

function profiles.deleteProfile(id: string): boolean
  local path = getStoragePath()
  local updated = {}
  for _, p in ipairs(profiles.cachedProfiles) do
    if p.id ~= id then
      table.insert(updated, p)
    end
  end
  profiles.cachedProfiles = updated
  if profiles.activeProfileId == id then
    profiles.activeProfileId = nil
  end

  if path and noctalia.writeFile then
    local payload = {
      active_profile = profiles.activeProfileId,
      profiles = profiles.cachedProfiles,
    }
    local enc, _ = noctalia.json.encode(payload, true)
    if enc then
      noctalia.writeFile(path, enc)
    end
  end
  return true
end

-- Matches connected monitors against saved profile fingerprints
function profiles.findMatchingProfile(connectedMonitorNames: { string }): Profile?
  if #connectedMonitorNames == 0 then return nil end
  local sortedConn = {}
  for _, n in ipairs(connectedMonitorNames) do
    table.insert(sortedConn, n)
  end
  table.sort(sortedConn)

  for _, prof in ipairs(profiles.cachedProfiles) do
    if #prof.fingerprint == #sortedConn then
      local match = true
      for i, name in ipairs(prof.fingerprint) do
        if name ~= sortedConn[i] then
          match = false
          break
        end
      end
      if match then return prof end
    end
  end

  return nil
end

return profiles
