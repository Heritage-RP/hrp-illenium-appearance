-- Clothes of character creation (PRODUCTION-SERVER#561, shared/creation_clothes.lua): a server's lists are checked
-- whole, the editor skips and hides what they leave out, and the server puts back a piece sent outside them and gives
-- no clothing item of it.
-- Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

-- Pure part, in an environment of its own -----------------------------------------------------------------------------
local function vector(...) return { ... } end
local env = setmetatable({ vector2 = vector, vector3 = vector, vector4 = vector, vec2 = vector, vec3 = vector, vec4 = vector, joaat = H.joaat }, { __index = _G })
H.load(env, "shared/config.lua")
H.load(env, "shared/creation_clothes.lua")
local CreationClothes = env.CreationClothes
local INITIAL = env.Config.InitialPlayerClothes

local LISTS = {
    male = { components = { ["11"] = { 5, 7 }, ["4"] = { 1, 2 } }, props = { ["0"] = { 3 } } },
    female = { components = { ["11"] = { 4 } } },
}

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

check("default: no limit (upstream behaviour)", env.Config.CreationClothes == false and CreationClothes.settings(false) == nil)

local settings = CreationClothes.settings(LISTS)
check("settings: valid lists", settings ~= nil and settings.male.components[11][5] and settings.male.components[4][2]
    and settings.male.props[0][3] and settings.female.components[11][4])
check("settings: props may be left out", settings ~= nil and next(settings.female.props) == nil)

do -- checked whole: one bad part and the lists are refused
    local function with(sex, kind, key, value)
        local copy = H.deepcopy(LISTS)
        copy[sex][kind] = copy[sex][kind] or {}
        copy[sex][kind][key] = value
        return CreationClothes.settings(copy)
    end
    check("settings: hair is not clothing", with("male", "components", "2", { 1 }) == nil)
    check("settings: the face is not clothing", with("male", "components", "0", { 1 }) == nil)
    check("settings: an unknown prop", with("male", "props", "3", { 1 }) == nil)
    check("settings: an empty list", with("male", "components", "8", {}) == nil)
    check("settings: a negative drawable", with("female", "components", "4", { -1 }) == nil)
    check("settings: a drawable that is not an integer", with("female", "components", "4", { 1.5 }) == nil)
    check("settings: a drawable that is not a number", with("female", "props", "1", { "2" }) == nil)
    local noFemale = H.deepcopy(LISTS)
    noFemale.female = nil
    check("settings: one sex missing", CreationClothes.settings(noFemale) == nil)
    check("settings: not a table", CreationClothes.settings("simple") == nil)
end

do -- read: the first valid declaration of a started resource, the config otherwise
    local function natives(resources)
        local function find(name)
            for _, r in ipairs(resources) do
                if r.name == name then return r end
            end
        end
        return {
            GetNumResources = function() return #resources end,
            GetResourceByFindIndex = function(i) return resources[i + 1] and resources[i + 1].name end,
            GetResourceState = function(name) return find(name).state or "started" end,
            GetNumResourceMetadata = function(name, key)
                assert(key == "hrp_appearance_creation_clothes", "metadata key " .. tostring(key))
                return #(find(name).files and find(name).declared or {})
            end,
            GetResourceMetadata = function(name, _, index) return find(name).declared[index + 1] end,
            LoadResourceFile = function(name, path) return find(name).files[path] end,
            decode = function(text)
                if type(text) ~= "table" then error("not JSON") end
                return text
            end,
        }
    end
    local broken = { male = { components = { ["2"] = { 1 } } }, female = {} }
    local read, by = CreationClothes.read(natives({
        { name = "stopped", state = "stopped", declared = { "a.json" }, files = { ["a.json"] = LISTS } },
        { name = "bad", declared = { "bad.json", "missing.json" }, files = { ["bad.json"] = broken } },
        { name = "config", declared = { "clothes.json" }, files = { ["clothes.json"] = LISTS } },
    }), false)
    check("read: a started resource's valid file, invalid and missing files skipped", by == "config" and read ~= nil
        and read.male.components[11][7])
    local fallback, none = CreationClothes.read(natives({}), false)
    check("read: no declaration and no config lists, no limit", fallback == nil and none == nil)
    local fromConfig = CreationClothes.read(natives({}), LISTS)
    check("read: the config's lists without a declaration", fromConfig ~= nil and fromConfig.female.components[11][4])
end

do -- the editor's blacklist
    local male = settings.male
    check("blocked: every drawable of a listed part but its own", same(CreationClothes.blocked(male, "components", 11, 0, 9),
        { 0, 1, 2, 3, 4, 6, 8, 9 }))
    check("blocked: a prop may always be taken off", same(CreationClothes.blocked(male, "props", 0, -1, 5), { 0, 1, 2, 4, 5 }))
    check("blocked: a part left out is not limited (its section is hidden)", CreationClothes.blocked(male, "components", 8, 0, 9) == nil)
    check("blocked: no allowed drawable in the ped's range, left free (no endless loop in the menu)",
        CreationClothes.blocked(male, "components", 11, 0, 3) == nil)
end

do -- what a part must hold
    local male = settings.male
    check("replacement: an allowed piece stays", CreationClothes.replacement(male, "components", 11, 7) == nil)
    local d, t = CreationClothes.replacement(male, "components", 11, 99)
    check("replacement: a piece outside the list takes the first allowed one", d == 5 and t == 0)
    check("replacement: a prop taken off stays off", CreationClothes.replacement(male, "props", 0, -1) == nil)
    d, t = CreationClothes.replacement(male, "components", 8, 15, { drawable = 0, texture = 0 })
    check("replacement: a part left out goes back to the starting piece", d == 0 and t == 0)
    check("replacement: the starting piece of a part left out stays",
        CreationClothes.replacement(male, "components", 8, 0, { drawable = 0, texture = 0 }) == nil)
    d, t = CreationClothes.replacement(male, "props", 1, 2)
    check("replacement: a prop left out, none at start: taken off", d == -1 and t == -1)
end

do -- an appearance saved at creation
    local function appearance(model)
        return {
            model = model,
            components = {
                { component_id = 2, drawable = 12, texture = 1 }, -- hair: not clothing
                { component_id = 11, drawable = 99, texture = 3 },
                { component_id = 4, drawable = 1, texture = 2 },
                { component_id = 8, drawable = 15, texture = 0 },
            },
            props = {
                { prop_id = 0, drawable = 7, texture = 0 },
                { prop_id = 1, drawable = 2, texture = 0 },
                { prop_id = 6, drawable = -1, texture = -1 },
            },
        }
    end
    local saved, replaced = CreationClothes.sanitize(appearance("mp_m_freemode_01"), settings, INITIAL)
    local c, p = saved.components, saved.props
    check("sanitize: four pieces put back", replaced == 4)
    check("sanitize: hair untouched", c[1].drawable == 12 and c[1].texture == 1)
    check("sanitize: a jacket outside the list takes the first allowed one", c[2].drawable == 5 and c[2].texture == 0)
    check("sanitize: allowed trousers kept with their texture", c[3].drawable == 1 and c[3].texture == 2)
    check("sanitize: a part left out back to the starting piece", c[4].drawable == 0)
    check("sanitize: a hat outside the list takes the allowed one", p[1].drawable == 3 and p[1].texture == 0)
    check("sanitize: glasses left out taken off", p[2].drawable == -1)
    check("sanitize: no watch at start, none kept", p[3].drawable == -1)

    local female = CreationClothes.sanitize(appearance("mp_f_freemode_01"), settings, INITIAL)
    check("sanitize: the female lists for a female ped", female.components[2].drawable == 4
        and female.components[3].drawable == 0 and female.props[1].drawable == -1)
    local _, staffPed = CreationClothes.sanitize(appearance("a_c_husky"), settings, INITIAL)
    check("sanitize: no limit on another model (a staff ped)", staffPed == 0)
    local _, free = CreationClothes.sanitize(appearance("mp_m_freemode_01"), nil, INITIAL)
    check("sanitize: no lists, nothing changed", free == 0)
end

do -- the starting clothing items
    local items = { jacket = { 7, 1 }, pants = { 9, 0 }, undershirt = { 0, 0 }, gloves = { 5, 0 }, cape = { 1, 0 } }
    local kept, dropped = CreationClothes.filterItems(H.deepcopy(items), CreationClothes.ITEM_COMPONENTS, "components",
        settings, "male", INITIAL)
    check("items: allowed and starting pieces given", kept.jacket and kept.undershirt and dropped == 3)
    check("items: trousers outside the list, gloves of a part left out, an unknown name: not given",
        not kept.pants and not kept.gloves and not kept.cape)
    local hats = CreationClothes.filterItems({ hat = { 3, 0 }, glasses = { 1, 0 } }, CreationClothes.ITEM_PROPS, "props",
        settings, "male", INITIAL)
    check("items: an allowed hat given, glasses left out not", hats.hat and not hats.glasses)
    local unknownSex = CreationClothes.filterItems({ jacket = { 4, 0 } }, CreationClothes.ITEM_COMPONENTS, "components",
        settings, nil, INITIAL)
    check("items: sex unknown, a piece one sex allows", unknownSex.jacket ~= nil)
    local all = CreationClothes.filterItems(H.deepcopy(items), CreationClothes.ITEM_COMPONENTS, "components", nil, "male", INITIAL)
    check("items: no lists, everything given", all.pants and all.gloves and all.cape)
end

-- The game: the creation editor, then the server --------------------------------------------------------------------
do
    local world = H.newWorld({
        resources = { { name = "server-config", metadata = { hrp_appearance_creation_clothes = { "clothes.json" } },
            files = { ["clothes.json"] = LISTS } } },
    })
    -- The server reads the same declaration
    world.server.env.Config.CreationClothes = LISTS
    local client = world.connect()
    local C = client.env
    local worn = {}
    C.GetNumberOfPedDrawableVariations = function() return 10 end
    C.GetNumberOfPedPropDrawableVariations = function() return 6 end
    C.GetPedDrawableVariation = function(_, id) return worn[id] or 0 end
    C.GetPedPropIndex = function(_, id) return worn["p" .. id] or -1 end
    C.SetPedComponentVariation = function(_, id, drawable) worn[id] = drawable end
    C.SetPedPropIndex = function(_, id, drawable) worn["p" .. id] = drawable end

    world.server.trigger("ox:createdCharacter", world.playerId, nil, world.charId)
    local submitted = false
    C.InitializeCharacter("Male", function() submitted = true end)
    client.ui.open()
    local components, props = client.ui.config.componentConfig, client.ui.config.propConfig
    check("editor: the listed parts keep their section", components.jackets and components.lowerBody and props.hats)
    check("editor: the parts left out lose theirs", not components.shirts and not components.masks and not props.glasses)
    check("editor: listed parts worn outside their list take the first allowed piece", worn[11] == 5 and worn[4] == 1)

    local jacket = C.client.getComponentSettings(101, 11)
    check("editor: the jacket choice skips every unlisted drawable", same(jacket.blacklist.drawables, { 0, 1, 2, 3, 4, 6, 8, 9 }))
    local hat = C.client.getPropSettings(101, 0)
    check("editor: the hat choice skips every unlisted drawable, taking it off stays", same(hat.blacklist.drawables, { 0, 1, 2, 4, 5 }))

    -- A client that sends a jacket outside the list anyway
    for _, part in ipairs(client.ui.data.components) do
        if part.component_id == 11 then part.drawable = 99 end
        if part.component_id == 8 then part.drawable = 15 end
    end
    client.ui.save()
    check("the creation went on", submitted)
    local saved = world.server.db[world.charId]
    local byId = {}
    for _, part in ipairs(saved and saved.components or {}) do byId[part.component_id] = part.drawable end
    check("server: the jacket outside the list put back to an allowed one", byId[11] == 5)
    check("server: a part left out back to the starting piece", byId[8] == 0)
    local given = world.server.firstClothing
    check("server: no clothing item of a piece outside the lists", given and given.components.jacket == nil
        and given.components.undershirt == nil)
    check("server: the allowed trousers given", given and given.components.pants ~= nil and given.components.pants[1] == 1)
    check("editor closed after saving", C.client.isPlayerCustomizing() == false)
end

do -- a shop later is not limited
    local world = H.newWorld({
        resources = { { name = "server-config", metadata = { hrp_appearance_creation_clothes = { "clothes.json" } },
            files = { ["clothes.json"] = LISTS } } },
    })
    local client = world.connect()
    client.env.GetNumberOfPedDrawableVariations = function() return 10 end
    client.env.OpenTattooShop()
    client.ui.open()
    check("shop: every section as before", client.ui.config.componentConfig.shirts == true)
    check("shop: no clothes skipped", #client.env.client.getComponentSettings(101, 11).blacklist.drawables == 0)
    client.ui.exit()
end

H.done()
