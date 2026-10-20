-- Ped models declared by other resources (fxmanifest `hrp_appearance_ped '<model>'`, game/declared_peds.lua): the pure
-- functions, then the ped menu and getPedModel of a client whose resources change while it plays.
-- Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

local function count(list, value)
    local n = 0
    for i = 1, #list do
        if list[i]:lower() == value:lower() then n = n + 1 end
    end
    return n
end

-- Pure part, in an environment of its own -----------------------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
H.load(env, "game/declared_peds.lua")
local DeclaredPeds = env.DeclaredPeds

---Fake natives over a list of { name, state, peds }
local function natives(resources)
    local byName = {}
    for _, r in ipairs(resources) do byName[r.name] = r end
    return {
        GetNumResources = function() return #resources end,
        GetResourceByFindIndex = function(i) return resources[i + 1] and resources[i + 1].name end,
        GetResourceState = function(name) return byName[name] and byName[name].state or "missing" end,
        GetNumResourceMetadata = function(name, key)
            assert(key == "hrp_appearance_ped", "metadata key " .. tostring(key))
            return byName[name] and byName[name].peds and #byName[name].peds or 0
        end,
        GetResourceMetadata = function(name, key, index)
            assert(key == "hrp_appearance_ped", "metadata key " .. tostring(key))
            return byName[name].peds[index + 1]
        end,
    }
end

do -- read: every index of every started or starting resource, each model once
    local declared = DeclaredPeds.read(natives({
        { name = "a", state = "started", peds = { "Custom_Ped", "u_m_y_custom" } },
        { name = "b", state = "stopped", peds = { "stopped_ped" } },
        { name = "c", state = "starting", peds = { " spaced_ped ", "CUSTOM_PED", "" } },
        { name = "d", state = "started" },
    }))
    local models = {}
    for i, d in ipairs(declared) do models[i] = d.model end
    check("read: several models of one resource", contains(models, "Custom_Ped") and contains(models, "u_m_y_custom"))
    check("read: a stopped resource declares nothing", not contains(models, "stopped_ped"))
    check("read: a starting resource counts, value trimmed", contains(models, "spaced_ped"))
    check("read: same model in another case listed once", count(models, "custom_ped") == 1 and #models == 3)
    check("read: the declaring resource is kept", declared[1].resource == "a" and declared[3].resource == "c")
    check("read: no resource, no model", #DeclaredPeds.read(natives({})) == 0)
end

do -- merge: one open group with the models not listed yet, input untouched
    local pedConfigs = {
        { peds = { "mp_m_freemode_01", "a_c_cat_01" } },
        { peds = { "s_m_y_cop_01" }, jobs = { "police" } },
    }
    local merged = DeclaredPeds.merge(pedConfigs, {
        { model = "Custom_Ped" }, { model = "A_C_CAT_01" }, { model = "s_m_y_cop_01" },
    })
    check("merge: one group added", #merged == 3 and #pedConfigs == 2)
    check("merge: only the new model, open to everyone", #merged[3].peds == 1 and merged[3].peds[1] == "Custom_Ped"
        and merged[3].jobs == nil and merged[3].aces == nil)
    check("merge: existing groups kept as they are", merged[1] == pedConfigs[1] and merged[2] == pedConfigs[2])
    check("merge: nothing declared -> the same list", DeclaredPeds.merge(pedConfigs, {}) == pedConfigs)
end

do -- unseen: each model logged once
    local logged = {}
    local first = DeclaredPeds.unseen({ { model = "Custom_Ped", resource = "a" } }, logged)
    local again = DeclaredPeds.unseen({ { model = "custom_ped", resource = "a" }, { model = "x", resource = "b" } }, logged)
    check("unseen: first time", #first == 1)
    check("unseen: only the new one the second time", #again == 1 and again[1].model == "x")
end

-- In the client ------------------------------------------------------------------------------------------------------
local function menuPeds(client)
    return client.env.client.getAppearanceSettings().ped.model.items
end

do -- the ped menu lists the declared models when it opens, whatever the start order
    local world = H.newWorld({ resources = { { name = "ox_lib" } } })
    local client = world.connect()
    local before = menuPeds(client)
    check("menu: Config.Peds alone at first", not contains(before, "Custom_Ped") and contains(before, "a_c_cat_01"))

    -- a resource started after illenium-appearance
    world.resources[#world.resources + 1] = { name = "server-config", peds = { "Custom_Ped" } }
    local after = menuPeds(client)
    check("menu: the model declared later is listed", contains(after, "Custom_Ped"))
    check("menu: listed once", count(after, "Custom_Ped") == 1)
    check("menu: Config.Peds untouched", #client.env.Config.Peds.pedConfig == 1)
    menuPeds(client)
    local infos = 0
    for _, record in ipairs(client.logs) do
        if record.level == "info" and record.msg:find("Custom_Ped", 1, true) then infos = infos + 1 end
    end
    check("menu: the declaration logged once", infos == 1)

    world.resources[2].state = "stopped"
    check("menu: gone with its resource", not contains(menuPeds(client), "Custom_Ped"))
end

do -- a model already in Config.Peds is not listed twice
    local world = H.newWorld({ resources = { { name = "cfg", peds = { "A_C_Cat_01" } } } })
    local client = world.connect()
    check("menu: model of Config.Peds declared again, listed once", count(menuPeds(client), "a_c_cat_01") == 1)
end

do -- getPedModel names a declared model (appearance saved with the right model)
    local world = H.newWorld({ resources = {} })
    local client = world.connect()
    check("getPedModel: a model of Config.Peds", client.env.client.getPedModel(101) == "mp_m_freemode_01")
    world.resources[1] = { name = "cfg", peds = { "Custom_Ped" } }
    client.ped.model = H.joaat("Custom_Ped")
    check("getPedModel: a declared model, by its hash", client.env.client.getPedModel(101) == "Custom_Ped")
    check("getPedModel: saved appearance carries it", client.env.client.getPedAppearance(101).model == "Custom_Ped")
end

H.done()
