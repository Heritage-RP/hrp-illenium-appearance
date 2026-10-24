-- Random face of the appearance menu (Heritage-RP/PRODUCTION-SERVER#560): a believable face in one click, then the
-- player adjusts a detail. The draw never takes just any value: it picks from the lists of Config.RandomFace, per sex
-- (parents that go together, a likeness range, hair styles and colours, eyebrows, a beard with a chance, eye colours),
-- and draws each face feature in a small range around neutral. A server replaces the lists with a file of one of its
-- resources: `hrp_appearance_random_face '<path>.json'` in its fxmanifest, the shape of Config.RandomFace (the first
-- valid declaration of a started resource wins, an invalid one is skipped). Pure functions over the given natives;
-- game/customization.lua applies the face to the ped.

RandomFace = {}

RandomFace.METADATA_KEY = "hrp_appearance_random_face"

local ACTIVE_STATES = { started = true, starting = true }
local SEXES = { "male", "female" }
-- Value ranges of the game: head blend parents, hair colours, eye colours, eyebrows and beard overlays
local PARENT_MAX = 45
local HAIR_COLOR_MAX = 63
local EYE_COLOR_MAX = 31
local EYEBROWS_MAX = 33
local BEARD_MAX = 28

local function integer(value, min, max)
    if type(value) ~= "number" or value ~= math.floor(value) or value < min or value > max then return nil end
    return math.tointeger(value)
end

local function unit(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return nil end
    return value
end

---A list of integers within [min, max]; nil when one is not, or when empty and `allowEmpty` is not set
local function integers(value, min, max, allowEmpty)
    if type(value) ~= "table" then return nil end
    local list = {}
    for i = 1, #value do
        local n = integer(value[i], min, max)
        if not n then return nil end
        list[i] = n
    end
    if #list == 0 and not allowEmpty then return nil end
    return list
end

---{ min, max } within 0–1, min ≤ max
local function range(value)
    if type(value) ~= "table" then return nil end
    local min, max = unit(value[1]), unit(value[2])
    if not min or not max or min > max then return nil end
    return { min, max }
end

local function parents(value)
    if type(value) ~= "table" or #value == 0 then return nil end
    local list = {}
    for i = 1, #value do
        local pair = integers(value[i], 0, PARENT_MAX)
        if not pair or #pair ~= 2 then return nil end
        list[i] = pair
    end
    return list
end

local function sex(value)
    if type(value) ~= "table" then return nil end
    local settings = {
        Parents = parents(value.Parents),
        Likeness = range(value.Likeness),
        HairStyles = integers(value.HairStyles, 0, 255),
        HairColors = integers(value.HairColors, 0, HAIR_COLOR_MAX),
        Eyebrows = integers(value.Eyebrows, 0, EYEBROWS_MAX),
        EyebrowsOpacity = range(value.EyebrowsOpacity),
        BeardChance = unit(value.BeardChance),
        Beards = integers(value.Beards, 0, BEARD_MAX, true),
        BeardOpacity = range(value.BeardOpacity),
        EyeColors = integers(value.EyeColors, 0, EYE_COLOR_MAX),
    }
    for _, key in ipairs({ "Parents", "Likeness", "HairStyles", "HairColors", "Eyebrows", "EyebrowsOpacity",
        "BeardChance", "Beards", "BeardOpacity", "EyeColors" }) do
        if settings[key] == nil then return nil end
    end
    if settings.BeardChance > 0 and #settings.Beards == 0 then return nil end
    return settings
end

---The settings a value holds (Config.RandomFace or a declared file), checked whole; nil when any part is invalid
---@param value any
---@return table?
function RandomFace.settings(value)
    if type(value) ~= "table" then return nil end
    local settings = { FeatureRange = unit(value.FeatureRange) }
    if not settings.FeatureRange then return nil end
    for _, key in ipairs(SEXES) do
        settings[key] = sex(value[key])
        if not settings[key] then return nil end
    end
    return settings
end

local function round(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function pick(list, random)
    return list[random(1, #list)]
end

local function between(bounds, random)
    return round(bounds[1] + (bounds[2] - bounds[1]) * random())
end

---A face drawn from one sex of the settings
---@param settings table one sex of RandomFace.settings
---@param featureRange number
---@param featureNames string[] constants.FACE_FEATURES
---@param random function math.random: random() in [0, 1), random(m, n) an integer in [m, n]
---@param hairAllowed? fun(style: integer): boolean styles the ped may wear (the model's count, the blacklist)
---@return { headBlend: table, faceFeatures: table, hair: table?, eyebrows: table, beard: table, eyeColor: integer }
function RandomFace.roll(settings, featureRange, featureNames, random, hairAllowed)
    local pair = pick(settings.Parents, random)
    local mix = between(settings.Likeness, random)
    local face = {
        headBlend = {
            shapeFirst = pair[1], shapeSecond = pair[2], shapeThird = 0,
            skinFirst = pair[1], skinSecond = pair[2], skinThird = 0,
            shapeMix = mix, skinMix = mix, thirdMix = 0,
        },
        faceFeatures = {},
    }
    for _, name in ipairs(featureNames) do
        face.faceFeatures[name] = round((random() * 2 - 1) * featureRange)
    end

    local color = pick(settings.HairColors, random)
    local styles = {}
    for _, style in ipairs(settings.HairStyles) do
        if not hairAllowed or hairAllowed(style) then styles[#styles + 1] = style end
    end
    if #styles > 0 then
        face.hair = { style = pick(styles, random), texture = 0, color = color, highlight = color }
    end

    face.eyebrows = {
        style = pick(settings.Eyebrows, random),
        opacity = between(settings.EyebrowsOpacity, random),
        color = color,
        secondColor = 0,
    }
    if #settings.Beards > 0 and random() < settings.BeardChance then
        face.beard = {
            style = pick(settings.Beards, random),
            opacity = between(settings.BeardOpacity, random),
            color = color,
            secondColor = 0,
        }
    else
        face.beard = { style = 0, opacity = 0, color = color, secondColor = 0 }
    end
    face.eyeColor = pick(settings.EyeColors, random)
    return face
end

---The lists in use: the first valid file declared by a started resource, Config.RandomFace otherwise (nil when that
---one is invalid too)
---@param natives table GetNumResources, GetResourceByFindIndex, GetResourceState, GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile, decode
---@param defaults table Config.RandomFace
---@return table? settings, string? declaredBy
function RandomFace.read(natives, defaults)
    for i = 0, (tonumber(natives.GetNumResources()) or 0) - 1 do
        local resource = natives.GetResourceByFindIndex(i)
        if type(resource) == "string" and ACTIVE_STATES[natives.GetResourceState(resource)] then
            for j = 0, (tonumber(natives.GetNumResourceMetadata(resource, RandomFace.METADATA_KEY)) or 0) - 1 do
                local file = natives.GetResourceMetadata(resource, RandomFace.METADATA_KEY, j)
                local text = type(file) == "string" and natives.LoadResourceFile(resource, file) or nil
                local ok, decoded = pcall(natives.decode, text or "")
                local settings = ok and RandomFace.settings(decoded)
                if settings then return settings, resource end
            end
        end
    end
    return RandomFace.settings(defaults), nil
end

---The lists now (declarations read at each draw: a config resource may start later)
---@return table?
function RandomFace.current()
    return (RandomFace.read({
        GetNumResources = GetNumResources,
        GetResourceByFindIndex = GetResourceByFindIndex,
        GetResourceState = GetResourceState,
        GetNumResourceMetadata = GetNumResourceMetadata,
        GetResourceMetadata = GetResourceMetadata,
        LoadResourceFile = LoadResourceFile,
        decode = json.decode,
    }, Config.RandomFace))
end
