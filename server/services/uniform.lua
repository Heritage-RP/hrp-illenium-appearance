--[[
    Uniform Service - Handles player uniform state
    Following SOLID principles:
    - S: Single Responsibility - Only handles uniform caching/sync
]]

local UniformService = {}

-- Local cache for player uniforms
local uniformCache = {}

---Get the current uniform for a player
---@param citizenId string|number Player's citizen ID
---@return table|nil uniform
function UniformService.Get(citizenId)
    return uniformCache[citizenId]
end

---Set/sync the uniform for a player
---@param citizenId string|number Player's citizen ID
---@param uniform table|nil Uniform data or nil to clear
function UniformService.Set(citizenId, uniform)
    uniformCache[citizenId] = uniform
end

---Clear the uniform for a player
---@param citizenId string|number Player's citizen ID
function UniformService.Clear(citizenId)
    uniformCache[citizenId] = nil
end

Services.Register("UniformService", UniformService)
return UniformService
