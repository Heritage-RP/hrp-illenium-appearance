--[[
    Management Outfit Service - Handles job/gang outfit management
    Following SOLID principles:
    - S: Single Responsibility - Only handles management outfits
]]

local ManagementOutfitService = {}

---Get management outfits for a player based on job/gang
---@param source number Player source
---@param mType string "Job" or "Gang"
---@param gender string Player gender
---@return table outfits List of available management outfits
function ManagementOutfitService.GetForPlayer(source, mType, gender)
    local job = Framework.GetJob(source)
    if mType == "Gang" then
        job = Framework.GetGang(source)
    end
    
    local grade = tonumber(job.grade.level)
    local managementOutfits = {}
    local result = Database.ManagementOutfits.GetAllByJob(mType, job.name, gender)
    
    for i = 1, #result, 1 do
        if grade >= result[i].minrank then
            managementOutfits[#managementOutfits + 1] = {
                id = result[i].id,
                name = result[i].name,
                model = result[i].model,
                gender = result[i].gender,
                components = json.decode(result[i].components),
                props = json.decode(result[i].props)
            }
        end
    end
    
    return managementOutfits
end

---Save a new management outfit
---@param outfitData table Outfit data (jobName, type, minRank, name, gender, model, props, components)
---@return number|nil id Created outfit ID
function ManagementOutfitService.Save(outfitData)
    return Database.ManagementOutfits.Add(outfitData)
end

---Delete a management outfit
---@param outfitId number Outfit ID
function ManagementOutfitService.Delete(outfitId)
    Database.ManagementOutfits.DeleteByID(outfitId)
end

Services.Register("ManagementOutfitService", ManagementOutfitService)
return ManagementOutfitService
