-- Ped models declared by other resources: one `hrp_appearance_ped '<model>'` line per model in their fxmanifest.lua.
-- They join the ped menu's list each time it opens (game/customization.lua) and the model names known to
-- getPedModel (game/util.lua), so the start order of the resources does not matter. A model already in Config.Peds or
-- declared twice is listed once (model names are case-insensitive, like joaat).

DeclaredPeds = {}

local METADATA_KEY = "hrp_appearance_ped"
local ACTIVE_STATES = { started = true, starting = true }

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

---Every model declared by a started (or starting) resource, in resource order, each once
---@param natives table GetNumResources, GetResourceByFindIndex, GetResourceState, GetNumResourceMetadata, GetResourceMetadata
---@return { model: string, resource: string }[]
function DeclaredPeds.read(natives)
    local declared, seen = {}, {}
    for i = 0, (tonumber(natives.GetNumResources()) or 0) - 1 do
        local resource = natives.GetResourceByFindIndex(i)
        if type(resource) == "string" and ACTIVE_STATES[natives.GetResourceState(resource)] then
            for j = 0, (tonumber(natives.GetNumResourceMetadata(resource, METADATA_KEY)) or 0) - 1 do
                local model = natives.GetResourceMetadata(resource, METADATA_KEY, j)
                model = type(model) == "string" and trim(model) or ""
                local key = model:lower()
                if model ~= "" and not seen[key] then
                    seen[key] = true
                    declared[#declared + 1] = { model = model, resource = resource }
                end
            end
        end
    end
    return declared
end

---The groups of Config.Peds.pedConfig, plus one group open to everyone with the declared models not listed yet.
---The input is left as it is.
---@param pedConfigs table[] Config.Peds.pedConfig
---@param declared { model: string }[]
---@return table[]
function DeclaredPeds.merge(pedConfigs, declared)
    local listed = {}
    for i = 1, #pedConfigs do
        local peds = pedConfigs[i].peds or {}
        for j = 1, #peds do listed[peds[j]:lower()] = true end
    end

    local extra = {}
    for i = 1, #declared do
        local key = declared[i].model:lower()
        if not listed[key] then
            listed[key] = true
            extra[#extra + 1] = declared[i].model
        end
    end
    if #extra == 0 then return pedConfigs end

    local merged = {}
    for i = 1, #pedConfigs do merged[i] = pedConfigs[i] end
    merged[#merged + 1] = { peds = extra }
    return merged
end

---The declarations not seen before: each model is logged once per session
---@param declared { model: string, resource: string }[]
---@param logged table<string, true> models already logged (lowercase), updated
---@return { model: string, resource: string }[]
function DeclaredPeds.unseen(declared, logged)
    local fresh = {}
    for i = 1, #declared do
        local key = declared[i].model:lower()
        if not logged[key] then
            logged[key] = true
            fresh[#fresh + 1] = declared[i]
        end
    end
    return fresh
end

local logged = {}

---The models declared right now by the started resources (natives of this client), each new one logged once
---@return { model: string, resource: string }[]
function DeclaredPeds.current()
    local declared = DeclaredPeds.read({
        GetNumResources = GetNumResources,
        GetResourceByFindIndex = GetResourceByFindIndex,
        GetResourceState = GetResourceState,
        GetNumResourceMetadata = GetNumResourceMetadata,
        GetResourceMetadata = GetResourceMetadata,
    })
    for _, entry in ipairs(DeclaredPeds.unseen(declared, logged)) do
        lib.print.info(("ped model %s declared by %s (%s)"):format(entry.model, entry.resource, METADATA_KEY))
    end
    return declared
end

---Config.Peds.pedConfig with the models declared by the started resources
---@param pedConfigs table[]
---@return table[]
function DeclaredPeds.withDeclared(pedConfigs)
    return DeclaredPeds.merge(pedConfigs, DeclaredPeds.current())
end
