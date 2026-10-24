-- Clothes of character creation (Heritage-RP/PRODUCTION-SERVER#561): a server may limit the creation editor to simple
-- pieces. A resource declares the list in its fxmanifest, `hrp_appearance_creation_clothes '<path>.json'` (the first
-- valid declaration of a started resource wins, an invalid one is skipped), Config.CreationClothes otherwise (false = no
-- limit, upstream behaviour). The list, per sex, gives the drawables allowed for each clothing component and prop:
--   { "male":   { "components": { "11": [0, 5, 7], "4": [0, 1] }, "props": { "0": [5] } },
--     "female": { "components": { … }, "props": { … } } }
-- A part the list leaves out keeps the starting clothes (Config.InitialPlayerClothes) and its menu section is hidden; a
-- prop may always be taken off (-1); any texture of an allowed drawable. The client hides and skips the rest
-- (game/customization.lua), the server puts back what a client sends outside the list (server/services/appearance.lua)
-- and only gives the clothing items of allowed pieces (server/server.lua). Pure functions over the given natives.

CreationClothes = {}

CreationClothes.METADATA_KEY = "hrp_appearance_creation_clothes"

local ACTIVE_STATES = { started = true, starting = true }
local SEXES = { male = "Male", female = "Female" }
local FREEMODE = { mp_m_freemode_01 = "male", mp_f_freemode_01 = "female" }
-- Clothing parts (game/customization.lua COMPONENT_CONFIG_KEYS, PROP_CONFIG_KEYS): face (0) and hair (2) are not clothes
CreationClothes.COMPONENTS = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    [9] = true, [10] = true, [11] = true }
CreationClothes.PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }
-- Names of the starting clothing items (client/client.lua InitializeCharacter, hrp-item-clothes)
CreationClothes.ITEM_COMPONENTS = { mask = 1, gloves = 3, pants = 4, bag = 5, shoes = 6, chain = 7, undershirt = 8,
    bodyarmor = 9, jacket = 11 }
CreationClothes.ITEM_PROPS = { hat = 0, glasses = 1, earrings = 2, watch = 6, bracelet = 7 }
local DRAWABLE_MAX = 4095

---{ [drawable] = true } from a non-empty list of drawables, nil when one is not an integer of the game's range
local function drawables(value)
    if type(value) ~= "table" or #value == 0 then return nil end
    local set = {}
    for i = 1, #value do
        local n = value[i]
        if type(n) ~= "number" or n ~= math.floor(n) or n < 0 or n > DRAWABLE_MAX then return nil end
        set[math.tointeger(n)] = true
    end
    return set
end

---{ [part id] = { [drawable] = true } } from `{ "<id>": [drawables] }`, ids among `parts`
local function parts(value, known)
    if value == nil then return {} end
    if type(value) ~= "table" then return nil end
    local result = {}
    for key, list in pairs(value) do
        local id = math.tointeger(tonumber(key))
        if not id or not known[id] then return nil end
        result[id] = drawables(list)
        if not result[id] then return nil end
    end
    return result
end

---The lists a value holds (Config.CreationClothes or a declared file), checked whole; nil when any part is invalid
---@param value any
---@return table? { male = { components, props }, female = { components, props } }
function CreationClothes.settings(value)
    if type(value) ~= "table" then return nil end
    local settings = {}
    for sex in pairs(SEXES) do
        local lists = value[sex]
        if type(lists) ~= "table" then return nil end
        local components, props = parts(lists.components, CreationClothes.COMPONENTS), parts(lists.props, CreationClothes.PROPS)
        if not components or not props then return nil end
        settings[sex] = { components = components, props = props }
    end
    return settings
end

---The lists in use: the first valid file declared by a started resource, Config.CreationClothes otherwise (nil = no
---limit, also when that one is invalid)
---@param natives table GetNumResources, GetResourceByFindIndex, GetResourceState, GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile, decode
---@param defaults any Config.CreationClothes
---@return table? settings, string? declaredBy
function CreationClothes.read(natives, defaults)
    for i = 0, (tonumber(natives.GetNumResources()) or 0) - 1 do
        local resource = natives.GetResourceByFindIndex(i)
        if type(resource) == "string" and ACTIVE_STATES[natives.GetResourceState(resource)] then
            for j = 0, (tonumber(natives.GetNumResourceMetadata(resource, CreationClothes.METADATA_KEY)) or 0) - 1 do
                local file = natives.GetResourceMetadata(resource, CreationClothes.METADATA_KEY, j)
                local text = type(file) == "string" and natives.LoadResourceFile(resource, file) or nil
                local ok, decoded = pcall(natives.decode, text or "")
                local settings = ok and CreationClothes.settings(decoded)
                if settings then return settings, resource end
            end
        end
    end
    return CreationClothes.settings(defaults), nil
end

---The lists now (declarations read each time: a config resource may start later)
---@return table?
function CreationClothes.current()
    return (CreationClothes.read({
        GetNumResources = GetNumResources,
        GetResourceByFindIndex = GetResourceByFindIndex,
        GetResourceState = GetResourceState,
        GetNumResourceMetadata = GetNumResourceMetadata,
        GetResourceMetadata = GetResourceMetadata,
        LoadResourceFile = LoadResourceFile,
        decode = json.decode,
    }, Config.CreationClothes))
end

---The sex of a freemode model ("male", "female"), nil for any other model (no limit on a staff ped)
---@param model any
---@return string?
function CreationClothes.sexOf(model)
    return FREEMODE[model]
end

---The drawables a part may take in [min, max] (blacklist of the editor: every other one), nil when the part is not
---limited; a part with no allowed drawable in range is left free (the editor would loop on an empty choice)
---@param lists table one sex of CreationClothes.settings
---@param kind "components"|"props"
---@param id integer
---@param min integer
---@param max integer
---@return integer[]? blocked
function CreationClothes.blocked(lists, kind, id, min, max)
    local allowed = lists[kind][id]
    if not allowed then return nil end
    local blocked, free = {}, 0
    for drawable = min, max do
        if allowed[drawable] or (kind == "props" and drawable == -1) then
            free += 1
        else
            blocked[#blocked + 1] = drawable
        end
    end
    if free == 0 then return nil end
    return blocked
end

---The smallest allowed drawable of a limited part
local function firstAllowed(allowed)
    local first
    for drawable in pairs(allowed) do
        if not first or drawable < first then first = drawable end
    end
    return first
end

---What a part must hold: nil when its drawable is fine, else the drawable and texture to put instead
---@param lists table one sex of CreationClothes.settings
---@param kind "components"|"props"
---@param id integer
---@param drawable any
---@param initial table? the part in Config.InitialPlayerClothes (`{ drawable, texture }`)
---@return integer? drawable, integer? texture
function CreationClothes.replacement(lists, kind, id, drawable, initial)
    local allowed = lists[kind][id]
    if allowed then
        if allowed[drawable] or (kind == "props" and drawable == -1) then return nil end
        return firstAllowed(allowed), 0
    end
    -- Not in the list: the starting piece (no prop when the starting clothes have none)
    local start = initial and initial.drawable or (kind == "props" and -1 or 0)
    if drawable == start then return nil end
    return start, initial and initial.texture or (kind == "props" and -1 or 0)
end

local function initialParts(initial, kind)
    local byId = {}
    local list = type(initial) == "table" and initial[kind == "props" and "Props" or "Components"] or {}
    for _, part in ipairs(list) do
        byId[kind == "props" and part.prop_id or part.component_id] = part
    end
    return byId
end

---An appearance saved at creation, its clothes put back within the lists (changed in place)
---@param appearance table checked to be a table with a string `model`
---@param settings table? CreationClothes.settings
---@param initialClothes table Config.InitialPlayerClothes
---@return table appearance, integer replaced
function CreationClothes.sanitize(appearance, settings, initialClothes)
    local sex = CreationClothes.sexOf(appearance.model)
    if not settings or not sex then return appearance, 0 end
    local lists, replaced = settings[sex], 0
    for kind, known in pairs({ components = CreationClothes.COMPONENTS, props = CreationClothes.PROPS }) do
        local idKey = kind == "props" and "prop_id" or "component_id"
        local initial = initialParts(initialClothes[SEXES[sex]], kind)
        if type(appearance[kind]) == "table" then
            for _, part in pairs(appearance[kind]) do
                local id = type(part) == "table" and part[idKey]
                if known[id] then
                    local drawable, texture = CreationClothes.replacement(lists, kind, id, part.drawable, initial[id])
                    if drawable then
                        part.drawable, part.texture = drawable, texture
                        replaced += 1
                    end
                end
            end
        end
    end
    return appearance, replaced
end

---The starting clothing items a client sends (`{ [name] = { drawable, texture } }`), only those of pieces the lists
---allow — the piece of a part they leave out only when it is the starting one. Sex unknown (not a freemode ped): a
---piece one of the sexes allows.
---@param items any
---@param byName table CreationClothes.ITEM_COMPONENTS or ITEM_PROPS
---@param kind "components"|"props"
---@param settings table? CreationClothes.settings
---@param sex string?
---@param initialClothes table Config.InitialPlayerClothes
---@return table items, integer dropped
function CreationClothes.filterItems(items, byName, kind, settings, sex, initialClothes)
    if type(items) ~= "table" then return {}, 0 end
    if not settings then return items, 0 end
    local sexes = sex and { sex } or { "male", "female" }
    local kept, dropped = {}, 0
    for name, value in pairs(items) do
        local id = byName[name]
        local drawable = type(value) == "table" and value[1] or nil
        local allowed = false
        for _, s in ipairs(sexes) do
            local initial = initialParts(initialClothes[SEXES[s]], kind)
            if id and not CreationClothes.replacement(settings[s], kind, id, drawable, initial[id]) then allowed = true end
        end
        if allowed then
            kept[name] = value
        else
            dropped += 1
        end
    end
    return kept, dropped
end
