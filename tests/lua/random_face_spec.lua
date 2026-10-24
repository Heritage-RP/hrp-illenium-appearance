-- Random face of the appearance menu (PRODUCTION-SERVER#560, game/random_face.lua): the lists are checked whole, the
-- draw stays within them, a resource's declaration replaces them, and the menu button applies the face to the ped.
-- Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- Pure part, in an environment of its own -----------------------------------------------------------------------------
local function vector(...) return { ... } end
local env = setmetatable({ vector2 = vector, vector3 = vector, vector4 = vector, vec2 = vector, vec3 = vector, vec4 = vector, joaat = H.joaat }, { __index = _G })
H.load(env, "shared/config.lua")
H.load(env, "game/constants.lua")
H.load(env, "game/random_face.lua")
local RandomFace = env.RandomFace
local defaults = env.Config.RandomFace
local FEATURES = env.constants.FACE_FEATURES

local settings = RandomFace.settings(defaults)
check("settings: the neutral defaults are valid", settings ~= nil and settings.male ~= nil and settings.female ~= nil)

do -- settings are checked whole: one bad part and the value is refused
    local function without(path, value)
        local copy = H.deepcopy(defaults)
        local t = copy
        for i = 1, #path - 1 do t = t[path[i]] end
        t[path[#path]] = value
        return RandomFace.settings(copy)
    end
    check("settings: a parent out of the game's range", without({ "male", "Parents" }, { { 21, 46 } }) == nil)
    check("settings: a parent pair of three", without({ "male", "Parents" }, { { 21, 0, 1 } }) == nil)
    check("settings: no parents", without({ "female", "Parents" }, {}) == nil)
    check("settings: likeness min above max", without({ "male", "Likeness" }, { 0.9, 0.6 }) == nil)
    check("settings: likeness above 1", without({ "male", "Likeness" }, { 0.6, 1.2 }) == nil)
    check("settings: a fractional hair colour", without({ "male", "HairColors" }, { 1.5 }) == nil)
    check("settings: a hair colour above 63", without({ "male", "HairColors" }, { 64 }) == nil)
    check("settings: a beard chance without beards", without({ "male", "Beards" }, {}) == nil)
    check("settings: no beard and no chance is fine", without({ "female", "Beards" }, {}) ~= nil)
    check("settings: a feature range above 1", without({ "FeatureRange" }, 2) == nil)
    check("settings: a sex missing", without({ "female" }, nil) == nil)
    check("settings: not a table", RandomFace.settings("faces") == nil)
end

do -- every draw stays within the lists (math.random, many draws)
    math.randomseed(560)
    local inside = true
    local beards, noBeards = 0, 0
    for _ = 1, 500 do
        for _, sex in ipairs({ "male", "female" }) do
            local lists = settings[sex]
            local face = RandomFace.roll(lists, settings.FeatureRange, FEATURES, math.random)
            local hb = face.headBlend
            local paired = false
            for _, pair in ipairs(lists.Parents) do
                if pair[1] == hb.shapeFirst and pair[2] == hb.shapeSecond then paired = true end
            end
            inside = inside and paired and hb.skinFirst == hb.shapeFirst and hb.skinSecond == hb.shapeSecond
            inside = inside and hb.shapeMix >= lists.Likeness[1] - 1e-9 and hb.shapeMix <= lists.Likeness[2] + 1e-9
            inside = inside and hb.skinMix == hb.shapeMix
            for _, name in ipairs(FEATURES) do
                local v = face.faceFeatures[name]
                inside = inside and type(v) == "number" and math.abs(v) <= settings.FeatureRange + 1e-9
            end
            inside = inside and face.hair ~= nil and contains(lists.HairStyles, face.hair.style)
            inside = inside and contains(lists.HairColors, face.hair.color) and face.hair.highlight == face.hair.color
            inside = inside and contains(lists.Eyebrows, face.eyebrows.style) and face.eyebrows.color == face.hair.color
            inside = inside and face.eyebrows.opacity >= lists.EyebrowsOpacity[1] - 1e-9
            inside = inside and face.eyebrows.opacity <= lists.EyebrowsOpacity[2] + 1e-9
            inside = inside and contains(lists.EyeColors, face.eyeColor)
            if face.beard.opacity > 0 then
                beards = beards + 1
                inside = inside and sex == "male" and contains(lists.Beards, face.beard.style)
            else
                noBeards = noBeards + 1
            end
        end
    end
    check("roll: parents, likeness, features, hair, eyebrows, eyes and beard within the lists", inside)
    check("roll: some men get a beard, the others none", beards > 0 and noBeards > 500)
end

do -- the skin follows the dominant parent: the same mix as the shape
    local lists = H.deepcopy(settings.male)
    lists.Parents = { { 25, 4 } }
    lists.Likeness = { 0.8, 0.8 }
    local face = RandomFace.roll(lists, 0, FEATURES, function(m, n) return m and n and m or 0 end)
    check("roll: mother then father, mix within the likeness",
        face.headBlend.shapeFirst == 25 and face.headBlend.shapeSecond == 4 and face.headBlend.shapeMix == 0.8)
    check("roll: skin from the same parents with the same mix",
        face.headBlend.skinFirst == 25 and face.headBlend.skinSecond == 4 and face.headBlend.skinMix == 0.8)
    check("roll: a feature range of 0 keeps every feature neutral", face.faceFeatures.noseWidth == 0)
end

do -- hair the ped may not wear is never drawn
    local lists = H.deepcopy(settings.male)
    lists.HairStyles = { 3, 7, 40 }
    math.randomseed(7)
    local only7 = true
    for _ = 1, 50 do
        local face = RandomFace.roll(lists, 0.25, FEATURES, math.random, function(style) return style == 7 end)
        only7 = only7 and face.hair.style == 7
    end
    check("roll: only the allowed hair styles", only7)
    local face = RandomFace.roll(lists, 0.25, FEATURES, math.random, function() return false end)
    check("roll: no allowed style, the hair is left alone", face.hair == nil)
end

do -- a resource's declaration replaces the lists, an invalid one is skipped
    local mine = H.deepcopy(defaults)
    mine.male.Parents = { { 45, 44 } }
    local broken = H.deepcopy(defaults)
    broken.male.Parents = { { 99, 0 } }
    local resources = {
        { name = "stopped", state = "stopped", files = { ["face.json"] = mine } },
        { name = "broken", state = "started", files = { ["face.json"] = broken } },
        { name = "config", state = "started", files = { ["face.json"] = mine } },
    }
    local natives = {
        GetNumResources = function() return #resources end,
        GetResourceByFindIndex = function(i) return resources[i + 1] and resources[i + 1].name end,
        GetResourceState = function(name)
            for _, r in ipairs(resources) do if r.name == name then return r.state end end
            return "missing"
        end,
        GetNumResourceMetadata = function(_, key)
            assert(key == "hrp_appearance_random_face", "metadata key " .. tostring(key))
            return 1
        end,
        GetResourceMetadata = function() return "face.json" end,
        LoadResourceFile = function(name, path) return name .. "/" .. path end,
        decode = function(text)
            for _, r in ipairs(resources) do
                if text == r.name .. "/face.json" then return H.deepcopy(r.files["face.json"]) end
            end
            error("not JSON")
        end,
    }
    local read, by = RandomFace.read(natives, defaults)
    check("read: the first valid declaration of a started resource", by == "config" and read.male.Parents[1][1] == 45)
    resources[3].state = "stopped"
    read, by = RandomFace.read(natives, defaults)
    check("read: no valid declaration, the defaults", by == nil and read.male.Parents[1][1] == 21)
end

-- The menu button, on a client ------------------------------------------------------------------------------------------
do
    local world = H.newWorld()
    local client = world.connect()
    local C = client.env
    local applied = { overlays = {} }
    C.GetNumberOfPedDrawableVariations = function() return 30 end
    C.SetPedHeadBlendData = function(_, first, second) applied.parents = { first, second } end
    C.SetPedFaceFeature = function(_, index, value) applied.features = (applied.features or 0) + 1 end
    C.SetPedComponentVariation = function(_, component, drawable)
        if component == 2 then applied.hair = drawable end
    end
    C.SetPedHeadOverlay = function(_, index, style, opacity) applied.overlays[index] = { style = style, opacity = opacity } end
    C.SetPedEyeColor = function(_, color) applied.eye = color end

    check("button: nothing happens outside the editor", client.post("appearance_random_face") ~= nil and applied.parents == nil)

    C.client.startPlayerCustomization(function() end, { headBlend = true, faceFeatures = true, headOverlays = true })
    local result = client.post("appearance_random_face")
    local male = settings.male
    local paired = false
    for _, pair in ipairs(male.Parents) do
        if applied.parents and pair[1] == applied.parents[1] and pair[2] == applied.parents[2] then paired = true end
    end
    check("button: parents from the lists", paired)
    check("button: every face feature set", applied.features == #FEATURES)
    check("button: hair from the lists", contains(male.HairStyles, applied.hair))
    check("button: eyebrows from the lists", applied.overlays[2] and contains(male.Eyebrows, applied.overlays[2].style))
    check("button: eye colour from the lists", contains(male.EyeColors, applied.eye))
    check("button: answers with the menu's new data", result.appearanceData ~= nil and result.appearanceSettings ~= nil)
    local logged = client.logs[#client.logs]
    check("button: the draw is logged with the sections drawn", logged and logged.msg == "random face drawn"
        and logged.attrs.headBlend == true and logged.attrs.headOverlays == true)

    applied = { overlays = {} }
    C.client.startPlayerCustomization(function() end, { headBlend = false, faceFeatures = false, headOverlays = true })
    client.post("appearance_random_face")
    check("button: closed sections are left alone", applied.parents == nil and applied.features == nil)
    check("button: open sections still drawn", applied.eye ~= nil)
end

H.done()
