--[[
    Outfit Service - Handles player outfit operations
    Following SOLID principles:
    - S: Single Responsibility - Only handles outfit CRUD operations
    - O: Open/Closed - Uses database abstraction, can be extended without modification
]]

local OutfitService = {}

-- Local cache for player outfits
local outfitCache = {}

---Load outfits from database into cache
---@param citizenId string|number Player's citizen ID
local function loadOutfitsToCache(citizenId)
    outfitCache[citizenId] = {}
    local result = Database.PlayerOutfits.GetAllByCitizenID(citizenId)
    for i = 1, #result, 1 do
        outfitCache[citizenId][#outfitCache[citizenId] + 1] = {
            id = result[i].id,
            name = result[i].outfitname,
            model = result[i].model,
            components = json.decode(result[i].components),
            props = json.decode(result[i].props)
        }
    end
end

---Get all outfits for a player
---@param citizenId string|number Player's citizen ID
---@return table outfits List of player outfits
function OutfitService.GetAll(citizenId)
    if outfitCache[citizenId] == nil then
        loadOutfitsToCache(citizenId)
    end
    return outfitCache[citizenId]
end

---Get a specific outfit by ID
---@param outfitId number Outfit ID
---@return table|nil outfit
function OutfitService.GetById(outfitId)
    return Database.PlayerOutfits.GetByID(outfitId)
end

---Save a new outfit
---@param citizenId string|number Player's citizen ID
---@param name string Outfit name
---@param model string Ped model
---@param components table Component data
---@param props table Prop data
---@return number|nil id Created outfit ID
function OutfitService.Save(citizenId, name, model, components, props)
    if outfitCache[citizenId] == nil then
        loadOutfitsToCache(citizenId)
    end
    
    local id = Database.PlayerOutfits.Add(citizenId, name, model, json.encode(components), json.encode(props))
    if not id then
        return nil
    end
    
    outfitCache[citizenId][#outfitCache[citizenId] + 1] = {
        id = id,
        name = name,
        model = model,
        components = components,
        props = props
    }
    
    return id
end

---Update an existing outfit
---@param citizenId string|number Player's citizen ID
---@param outfitId number Outfit ID
---@param model string Ped model
---@param components table Component data
---@param props table Prop data
---@return string|nil outfitName Name of updated outfit
function OutfitService.Update(citizenId, outfitId, model, components, props)
    if outfitCache[citizenId] == nil then
        loadOutfitsToCache(citizenId)
    end
    
    if not Database.PlayerOutfits.Update(outfitId, model, json.encode(components), json.encode(props)) then
        return nil
    end
    
    local outfitName = ""
    for i = 1, #outfitCache[citizenId], 1 do
        local outfit = outfitCache[citizenId][i]
        if outfit.id == outfitId then
            outfit.model = model
            outfit.components = components
            outfit.props = props
            outfitName = outfit.name
            break
        end
    end
    
    return outfitName
end

---Delete an outfit
---@param citizenId string|number Player's citizen ID
---@param outfitId number Outfit ID
function OutfitService.Delete(citizenId, outfitId)
    Database.PlayerOutfitCodes.DeleteByOutfitID(outfitId)
    Database.PlayerOutfits.DeleteByID(outfitId)
    
    for k, v in ipairs(outfitCache[citizenId]) do
        if v.id == outfitId then
            table.remove(outfitCache[citizenId], k)
            break
        end
    end
end

---Reset outfit cache for a player
---@param citizenId string|number Player's citizen ID
function OutfitService.ResetCache(citizenId)
    if citizenId then
        outfitCache[citizenId] = nil
    end
end

---Check if outfit name already exists for player
---@param citizenId string|number Player's citizen ID
---@param name string Outfit name
---@return boolean exists
function OutfitService.NameExists(citizenId, name)
    return Database.PlayerOutfits.GetByOutfit(name, citizenId) ~= nil
end

Services.Register("OutfitService", OutfitService)
return OutfitService
