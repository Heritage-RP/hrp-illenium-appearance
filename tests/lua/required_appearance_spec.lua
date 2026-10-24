-- Appearance imposed by another resource (PRODUCTION-SERVER#17, shared/required_appearance.lua): the value is checked
-- whole, the editor holds the features on the ped and in its sliders, every save of that player keeps them, logout
-- clears them. Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

-- Pure part, in an environment of its own -----------------------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
H.load(env, "shared/required_appearance.lua")
local RequiredAppearance = env.RequiredAppearance

-- Marks of a rule of the server's world: eye colour and four head overlays at full opacity
local MARKS = {
    eyeColor = 26,
    headOverlays = {
        blemishes = { style = 21, opacity = 1.0 },
        ageing = { style = 14, opacity = 1.0 },
        sunDamage = { style = 8, opacity = 1.0 },
        bodyBlemishes = { style = 11, opacity = 1.0 },
    },
}

do -- settings: checked whole
    local settings = RequiredAppearance.settings(MARKS)
    check("settings: a valid value", settings ~= nil and settings.eyeColor == 26 and settings.headOverlays.ageing.style == 14)
    local function with(path, value)
        local copy = H.deepcopy(MARKS)
        local t = copy
        for i = 1, #path - 1 do t = t[path[i]] end
        t[path[#path]] = value
        return RequiredAppearance.settings(copy)
    end
    check("settings: an eye colour above 31", with({ "eyeColor" }, 32) == nil)
    check("settings: a fractional eye colour", with({ "eyeColor" }, 2.5) == nil)
    check("settings: an unknown overlay", with({ "headOverlays", "scars" }, { style = 1, opacity = 1 }) == nil)
    check("settings: an opacity above 1", with({ "headOverlays", "ageing", "opacity" }, 1.5) == nil)
    check("settings: a negative style", with({ "headOverlays", "ageing", "style" }, -1) == nil)
    check("settings: overlays not a table", with({ "headOverlays" }, "ageing") == nil)
    check("settings: only an eye colour", RequiredAppearance.settings({ eyeColor = 3 }) ~= nil)
    check("settings: nothing imposed", RequiredAppearance.settings({}) == nil)
    check("settings: not a table", RequiredAppearance.settings("ghoul") == nil)
end

do -- apply: puts the features back, keeps the colours, counts what differed
    local required = RequiredAppearance.settings(MARKS)
    local appearance = {
        model = "mp_f_freemode_01",
        eyeColor = 3,
        headOverlays = {
            blemishes = { style = 21, opacity = 1.0, color = 0, secondColor = 0 },
            ageing = { style = 2, opacity = 0.3, color = 0, secondColor = 0 },
            sunDamage = { style = 8, opacity = 0.5, color = 0, secondColor = 0 },
            beard = { style = 4, opacity = 0.8, color = 12, secondColor = 0 },
        },
    }
    local changed = RequiredAppearance.apply(appearance, required)
    check("apply: eye colour, ageing, sun damage changed and body blemishes added", changed == 4)
    check("apply: the imposed values", appearance.eyeColor == 26 and appearance.headOverlays.ageing.style == 14
        and appearance.headOverlays.ageing.opacity == 1.0 and appearance.headOverlays.bodyBlemishes.style == 11)
    check("apply: other overlays untouched", appearance.headOverlays.beard.style == 4 and appearance.headOverlays.beard.color == 12)
    check("apply: twice changes nothing", RequiredAppearance.apply(appearance, required) == 0)
    check("apply: an opacity at the menu's step counts as the same", RequiredAppearance.apply(
        { eyeColor = 26, headOverlays = { blemishes = { style = 21, opacity = 0.99999 }, ageing = { style = 14, opacity = 1 },
            sunDamage = { style = 8, opacity = 1 }, bodyBlemishes = { style = 11, opacity = 1 } } }, required) == 0)
    check("apply: no overlays sent", RequiredAppearance.apply({ eyeColor = 26 }, required) == 4)
    check("apply: nothing imposed", RequiredAppearance.apply({ eyeColor = 1 }, nil) == 0)
    check("applies to the freemode peds only", RequiredAppearance.appliesTo("mp_m_freemode_01")
        and not RequiredAppearance.appliesTo("a_c_chimp"))

    local settings = { eyeColor = { min = 0, max = 30 }, headOverlays = { ageing = { style = { min = 0, max = 14 },
        opacity = { min = 0, max = 1, factor = 0.1 } }, beard = { style = { min = 0, max = 28 } } } }
    RequiredAppearance.lockSettings(settings, required)
    check("lock: the eye colour holds one value", settings.eyeColor.min == 26 and settings.eyeColor.max == 26)
    check("lock: the overlay's style and opacity hold one value", settings.headOverlays.ageing.style.min == 14
        and settings.headOverlays.ageing.style.max == 14 and settings.headOverlays.ageing.opacity.min == 1.0)
    check("lock: other overlays free", settings.headOverlays.beard.style.max == 28)
end

-- The export and the server -------------------------------------------------------------------------------------------
local function savedOverlay(world, name)
    local saved = world.server.db[world.charId]
    return saved and saved.headOverlays and saved.headOverlays[name]
end

do
    local world = H.newWorld()
    local S = world.server.env
    local set = world.server.exports.setRequiredAppearance
    check("export: declared", type(set) == "function")
    check("export: an invalid value refused", set(world.playerId, { eyeColor = 99 }) == false)
    S.GetPlayerName = function() return nil end
    check("export: a player not connected refused", set(world.playerId, MARKS) == false)
    S.GetPlayerName = function() return "player" end
    check("export: set", set(world.playerId, MARKS) == true)

    -- A save sent without the features (a client that ignores them)
    world.server.emit("illenium-appearance:server:saveAppearance", {
        model = "mp_m_freemode_01", eyeColor = 4, tattoos = {},
        headOverlays = { ageing = { style = 0, opacity = 0, color = 0, secondColor = 0 } },
    })
    local ageing = savedOverlay(world, "ageing")
    check("server: the features put back in the save", ageing and ageing.style == 14 and ageing.opacity == 1.0
        and world.server.db[world.charId].eyeColor == 26)
    local warned = false
    for _, record in ipairs(world.server.logs) do
        if record.msg == "appearance save: required features put back" then warned = record.attrs.changed == 5 end
    end
    check("server: the put back is logged with its count", warned)

    -- Another model (a ped given by the staff): head overlays do not exist there
    world.server.db[world.charId] = { model = "a_c_chimp" }
    world.server.emit("illenium-appearance:server:saveAppearance", { model = "a_c_chimp", eyeColor = 4, tattoos = {} })
    check("server: not on another model", world.server.db[world.charId].eyeColor == 4)

    world.server.trigger("ox:playerLogout", world.playerId)
    world.server.db[world.charId] = nil
    world.server.emit("illenium-appearance:server:saveAppearance", {
        model = "mp_m_freemode_01", eyeColor = 4, tattoos = {}, headOverlays = {},
    })
    check("server: cleared at logout", world.server.db[world.charId].eyeColor == 4)

    check("export: set again", set(world.playerId, MARKS))
    check("export: nil clears", set(world.playerId, nil) == true)
    world.server.emit("illenium-appearance:server:saveAppearance", {
        model = "mp_m_freemode_01", eyeColor = 5, tattoos = {}, headOverlays = {},
    })
    check("server: cleared by nil", world.server.db[world.charId].eyeColor == 5)
end

-- The editor ----------------------------------------------------------------------------------------------------------
do -- creation: the editor holds the features on the ped and in its sliders, the save keeps them
    local world = H.newWorld()
    local client = world.connect()
    local C = client.env
    world.server.trigger("ox:createdCharacter", world.playerId, nil, world.charId)
    world.server.exports.setRequiredAppearance(world.playerId, MARKS)

    C.InitializeCharacter("Male", function() end)
    client.ui.open()
    check("editor: the ped wears the imposed eye colour", client.ped.eyeColor == 26)
    check("editor: the ped wears the imposed overlays", client.ped.overlays[3] and client.ped.overlays[3].style == 14
        and client.ped.overlays[11].style == 11 and client.ped.overlays[0].opacity == 1.0)
    check("editor: the menu starts from them", client.ui.data.eyeColor == 26 and client.ui.data.headOverlays.ageing.style == 14)

    local settings = C.client.getAppearanceSettings()
    check("editor: the eye colour slider holds one value", settings.eyeColor.min == 26 and settings.eyeColor.max == 26)
    check("editor: the overlay sliders hold one value", settings.headOverlays.sunDamage.style.min == 8
        and settings.headOverlays.sunDamage.style.max == 8 and settings.headOverlays.sunDamage.opacity.max == 1.0)
    check("editor: the other sliders free", settings.headOverlays.beard.opacity.min == 0 and settings.headOverlays.ageing.opacity.min == 1.0)

    -- The menu (or a crafted NUI post) tries to change them
    local overlays = H.deepcopy(client.ui.data.headOverlays)
    overlays.ageing = { style = 0, opacity = 0, color = 0, secondColor = 0 }
    client.post("appearance_change_head_overlay", overlays)
    client.post("appearance_change_eye_color", 3)
    check("editor: a change of an imposed overlay is held", client.ped.overlays[3].style == 14)
    check("editor: a change of the eye colour is held", client.ped.eyeColor == 26)

    -- The random face button
    C.client.randomizeFace(101)
    check("editor: the random face keeps them", client.ped.eyeColor == 26 and client.ped.overlays[7].style == 8)

    -- A new model: the features go back on the new ped
    client.post("appearance_change_model", "mp_f_freemode_01")
    check("editor: a new ped wears them again", client.ped.eyeColor == 26 and client.ped.overlays[3].style == 14)

    client.ui.data.eyeColor = 3
    client.ui.save()
    local saved = world.server.db[world.charId]
    check("save: the character keeps them", saved and saved.eyeColor == 26 and saved.headOverlays.bodyBlemishes.style == 11)
    check("editor closed", C.client.isPlayerCustomizing() == false)
end

do -- a player with nothing imposed: the editor as before
    local world = H.newWorld()
    local client = world.connect()
    client.env.OpenBarberShop()
    client.ui.open()
    local settings = client.env.client.getAppearanceSettings()
    check("barber: the eye colour free", settings.eyeColor.min == 0 and settings.eyeColor.max == 30)
    client.post("appearance_change_eye_color", 3)
    check("barber: the eye colour changes", client.ped.eyeColor == 3)
    client.ui.exit()
end

H.done()
