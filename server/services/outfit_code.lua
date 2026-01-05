--[[
    Outfit Code Service - Handles outfit sharing via codes
    Following SOLID principles:
    - S: Single Responsibility - Only handles outfit code generation and import
]]

local OutfitCodeService = {}

---Generate a unique outfit code
---@return string code Unique code
local function generateUniqueCode()
    local code, exists
    repeat
        code = GenerateNanoID(Config.OutfitCodeLength)
        exists = Database.PlayerOutfitCodes.GetByCode(code)
    until not exists
    return code
end

---Generate a shareable code for an outfit
---@param outfitId number Outfit ID
---@return string|nil code Generated code or nil on failure
function OutfitCodeService.GenerateCode(outfitId)
    local existingCode = Database.PlayerOutfitCodes.GetByOutfitID(outfitId)
    if existingCode then
        return existingCode.code
    end
    
    local code = generateUniqueCode()
    local id = Database.PlayerOutfitCodes.Add(outfitId, code)
    if not id then
        print("Something went wrong while generating outfit code")
        return nil
    end
    return code
end

---Import an outfit using a code
---@param citizenId string|number Player's citizen ID
---@param outfitName string Name for the imported outfit
---@param code string The outfit code to import
---@return boolean success
function OutfitCodeService.ImportByCode(citizenId, outfitName, code)
    local existingCode = Database.PlayerOutfitCodes.GetByCode(code)
    if not existingCode then
        return false
    end
    
    local playerOutfit = Database.PlayerOutfits.GetByID(existingCode.outfitid)
    if not playerOutfit then
        return false
    end
    
    -- Prevent duplicating own outfit
    if playerOutfit.citizenid == citizenId then
        return false
    end
    
    -- Check for duplicate outfit name
    if Database.PlayerOutfits.GetByOutfit(outfitName, citizenId) then
        return false
    end
    
    local OutfitService = Services.Get("OutfitService")
    local id = OutfitService.Save(
        citizenId, 
        outfitName, 
        playerOutfit.model, 
        json.decode(playerOutfit.components), 
        json.decode(playerOutfit.props)
    )
    
    return id ~= nil
end

Services.Register("OutfitCodeService", OutfitCodeService)
return OutfitCodeService
