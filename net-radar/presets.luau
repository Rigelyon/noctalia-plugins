--!nonstrict
local presets = {}

export type Preset = {
  id: string,
  labelKey: string,
  host: string,
  regionName: string,
}

presets.LIST = {
  {
    id = "sea_singapore",
    labelKey = "presets.sea_singapore",
    host = "103.10.124.1", -- Valve Singapore (CS2 / Dota 2)
    regionName = "Singapore (SEA)",
  },
  {
    id = "east_asia_tokyo",
    labelKey = "presets.east_asia_tokyo",
    host = "45.121.184.1", -- Tokyo Game Cluster
    regionName = "Tokyo (East Asia)",
  },
  {
    id = "us_west",
    labelKey = "presets.us_west",
    host = "162.254.194.1", -- Valve US West
    regionName = "US West (California)",
  },
  {
    id = "europe_west",
    labelKey = "presets.europe_west",
    host = "155.133.226.1", -- Valve Europe West (Frankfurt)
    regionName = "Europe West (Frankfurt)",
  },
  {
    id = "custom",
    labelKey = "presets.custom",
    host = "1.1.1.1",
    regionName = "Custom Host",
  },
}

function presets.getById(id: string): Preset
  for _, p in ipairs(presets.LIST) do
    if p.id == id then
      return p
    end
  end
  return presets.LIST[1]
end

return presets
