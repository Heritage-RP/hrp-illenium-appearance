--[[
    Appearance Service - Handles player appearance operations
    Following SOLID principles:
    - S: Single Responsibility - Only handles appearance save/load
]]

local AppearanceService = {}

---Get player appearance from database
---@param citizenId string|number Player's citizen ID
---@param model string|nil Optional model to filter by
---@return table|nil appearance
function AppearanceService.Get(citizenId, model)
    return Framework.GetAppearance(citizenId, model)
end

---Save player appearance to database
---@param citizenId string|number Player's citizen ID
---@param appearance table Appearance data
function AppearanceService.Save(citizenId, appearance)
    if appearance then
        Framework.SaveAppearance(appearance, citizenId)
    end
end

Services.Register("AppearanceService", AppearanceService)
return AppearanceService
