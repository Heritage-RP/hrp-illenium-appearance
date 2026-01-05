--[[
    Clothing Service - Handles clothing item operations for inventory integration
    Following SOLID principles:
    - S: Single Responsibility - Only handles clothing item distribution
    - O: Open/Closed - Can be extended with new inventory systems without modification
]]

local ClothingService = {}

---Check if a clothing value is valid (not default/empty)
---@param value table {drawable, texture} tuple
---@return boolean isValid
local function isValidClothing(value)
    return tonumber(value[1]) ~= -99 
        and tonumber(value[1]) ~= -1 
        and tonumber(value[2]) ~= -99 
        and tonumber(value[2]) ~= -1
end

---Give clothing items to a player from components and props tables
---@param source number Player source
---@param components table Table of component clothing {name = {drawable, texture}}
---@param props table Table of prop clothing {name = {drawable, texture}}
function ClothingService.GiveItems(source, components, props)
    if components then
        for name, value in pairs(components) do
            if isValidClothing(value) then
                exports.ox_inventory:AddItem(source, name, 1, { 
                    texture = tonumber(value[2]), 
                    drawable = tonumber(value[1]) 
                })
            end
        end
    end
    
    if props then
        for name, value in pairs(props) do
            if isValidClothing(value) then
                exports.ox_inventory:AddItem(source, name, 1, { 
                    texture = tonumber(value[2]), 
                    drawable = tonumber(value[1]) 
                })
            end
        end
    end
end

---Give first-time clothing to a new character
---@param source number Player source
---@param props table Prop clothing data
---@param components table Component clothing data
function ClothingService.GiveFirstClothing(source, props, components)
    ClothingService.GiveItems(source, components, props)
end

---Get clothing lists from client and give items (for shop purchases)
---@param source number Player source
function ClothingService.GiveFromClientLists(source)
    local tableClothingProp = lib.callback.await('hrp-item-clothes:GetClothingListProp', source)
    local tableClothingComp = lib.callback.await('hrp-item-clothes:GetClothingListComp', source)
    ClothingService.GiveItems(source, tableClothingComp, tableClothingProp)
end

Services.Register("ClothingService", ClothingService)
return ClothingService
