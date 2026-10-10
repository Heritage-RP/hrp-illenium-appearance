-- Test harness: runs the resource's real Lua files in plain Lua 5.4, with fakes for the natives, ox_lib, the NUI and the
-- server (PRODUCTION-SERVER#12). Run every spec with tests/run.sh (docker, nickblah/lua:5.4).
--
-- Each side gets its own environment (_ENV), like FiveM gives each script runtime its own globals:
--   client: shared/{config,blacklist,peds,tattoos}.lua, game/*.lua, client/defaults.lua, client/common.lua, client/client.lua
--   server: shared/config.lua, shared/tattoos.lua, server/services/{init,shop,appearance}.lua,
--           server/server.lua, server/permissions.lua
-- Natives nobody fakes below are no-ops returning 0 (truthy in Lua, like a model "in cdimage" or "loaded"); they are
-- callable tables, so `Services = Services or {}` still works.
-- CfxLua extensions are translated on load: `name` hash literals -> joaat("name"), `x += y` -> `x = x + (y)` (one
-- statement per line; other compound operators are not translated).

local H = {}

local failures, passed = 0, 0

function H.check(name, cond)
    if cond then
        passed = passed + 1
        io.write("ok   ", name, "\n")
    else
        failures = failures + 1
        io.write("FAIL ", name, "\n")
    end
end

function H.done()
    io.write(string.format("%d passed, %d failed\n", passed, failures))
    os.exit(failures == 0 and 0 or 1)
end

function H.deepcopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[H.deepcopy(k)] = H.deepcopy(v) end
    return copy
end

-- Same contract as FiveM's joaat: case-insensitive, a number. A readable string is enough for the fakes.
local function joaat(name)
    return "#" .. string.lower(tostring(name))
end
H.joaat = joaat

local function stub() return 0 end

local function vector(...)
    local v = { ... }
    return { x = v[1], y = v[2], z = v[3], w = v[4] }
end

-- CfxLua / ox_lib additions to `table`
local cfxTable = setmetatable({
    create = function() return {} end,
    clone = function(t)
        local c = {}
        for k, v in pairs(t) do c[k] = v end
        return c
    end,
}, { __index = table })

local function newEnv(fields)
    local env = fields or {}
    env._G = env
    env.table = cfxTable
    env.vector2, env.vector3, env.vector4 = vector, vector, vector
    env.vec2, env.vec3, env.vec4 = vector, vector, vector
    return setmetatable(env, {
        __index = function(self, key)
            local std = _G[key]
            if std ~= nil then return std end
            -- Natives and globals of files not loaded (PascalCase): callable, and a table for `X = X or {}`
            if type(key) == "string" and key:match("^%u") then
                local fake = setmetatable({}, { __call = stub })
                rawset(self, key, fake)
                return fake
            end
        end,
    })
end

function H.load(env, path)
    local file = assert(io.open(path, "r"))
    local source = file:read("a")
    file:close()
    source = source:gsub("`([^`\n]+)`", 'joaat("%1")')
    source = source:gsub("[^\n]+", function(line)
        local head, target, expr, tail = line:match("^(.-)([%w_%.]+)%s*%+=%s*(.-)(%s+end%s*)$")
        if not head then
            head, target, expr = line:match("^(.-)([%w_%.]+)%s*%+=%s*(.-)%s*$")
            tail = ""
        end
        if not head then return line end
        return head .. target .. " = " .. target .. " + (" .. expr .. ")" .. tail
    end)
    local chunk = assert(load(source, "@" .. path, "t", env))
    return chunk()
end

-- Records helpers shared by both sides
local function newLog(records)
    local function writer(level)
        return function(msg, attrs) records[#records + 1] = { level = level, msg = msg, attrs = attrs } end
    end
    local log = {}
    for _, level in ipairs({ "trace", "debug", "info", "warn", "error" }) do log[level] = writer(level) end
    log.business = {}
    log.api = {}
    for _, level in ipairs({ "trace", "debug", "info", "warn", "error" }) do
        log.business[level] = writer(level)
        log.api[level] = writer(level)
    end
    return log
end

local function newLib(callbacks, call)
    local callback = setmetatable({
        register = function(name, fn) callbacks[name] = fn end,
        await = function(name, _, ...) return call(name, ...) end,
    }, {
        __call = function(_, name, _, cb, ...) cb(call(name, ...)) end,
    })
    return setmetatable({ callback = callback }, { __index = function() return stub end })
end

local function newExports()
    return setmetatable({}, {
        __call = function() end,
        __index = function() return setmetatable({}, { __index = function() return stub end }) end,
    })
end

---A server with a fake database and wallet, and one client per connection. world.server.db[charId] is the saved skin.
---@return table world
function H.newWorld(opts)
    opts = opts or {}
    local world = { charId = opts.charId or 42, playerId = 1 }

    -- Server ----------------------------------------------------------------------------------------------------------
    local server = { db = {}, money = opts.money or 300, logs = {}, callbacks = {}, events = {} }
    world.server = server

    local S = newEnv({
        joaat = joaat,
        json = { encode = function() return "{}" end },
        HrpLog = newLog(server.logs),
        GetGameTimer = function() return 1000 end,
        IsPlayerAceAllowed = function() return opts.staff == true end,
        GetConvar = function(_, fallback) return fallback end,
        RegisterServerEvent = function(name, fn) if fn then server.events[name] = fn end end,
        RegisterNetEvent = function(name, fn) if fn then server.events[name] = fn end end,
        AddEventHandler = function() end,
        exports = newExports(),
        _L = function(key) return key end,
    })
    S.lib = newLib(server.callbacks, function() error("server-side lib.callback.await is not faked") end)
    S.lib.notify = function() end
    S.Framework = {
        GetPlayerID = function() return world.charId end,
        GetAppearance = function(charId) return H.deepcopy(server.db[charId]) end,
        SaveAppearance = function(appearance, charId)
            server.db[charId] = H.deepcopy(appearance)
            return true
        end,
        HasMoney = function(_, _, amount) return server.money >= amount end,
        RemoveMoney = function(_, _, amount)
            if server.money < amount then return false end
            server.money = server.money - amount
            return true
        end,
    }
    server.env = S

    H.load(S, "shared/config.lua")
    H.load(S, "shared/tattoos.lua")
    H.load(S, "server/services/init.lua")
    H.load(S, "server/services/shop.lua")
    H.load(S, "server/services/appearance.lua")
    H.load(S, "server/server.lua")
    H.load(S, "server/permissions.lua")

    function server.call(name, ...)
        local fn = assert(server.callbacks[name], "no server callback " .. name)
        local args = H.deepcopy({ ... })
        return table.unpack(H.deepcopy({ fn(world.playerId, table.unpack(args)) }))
    end

    function server.emit(name, ...)
        local fn = server.events[name]
        if not fn then return end
        S.source = world.playerId
        fn(table.unpack(H.deepcopy({ ... })))
    end

    world.connect = function() return H.newClient(world) end
    return world
end

---A game client: the real game/ and client/ files with a fake ped, NUI and ox_lib
function H.newClient(world)
    local server = world.server
    local ped = { model = joaat(world.model or "mp_m_freemode_01"), decorations = {} }
    local c = { ped = ped, nui = {}, sent = {} }

    local C = newEnv({
        joaat = joaat,
        json = { encode = function() return "" end },
        cache = { ped = 101, playerId = 1, vehicle = false },
        LocalPlayer = { state = {} },
        GetConvar = function(_, fallback) return fallback end,
        GetEntityModel = function() return ped.model end,
        IsScreenFadedIn = function() return true end,
        IsPlayerTeleportActive = function() return false end,
        IsPlayerSwitchInProgress = function() return false end,
        IsModelInCdimage = function() return true end,
        HasModelLoaded = function() return true end,
        HasAnimDictLoaded = function() return true end,
        IsPedFalling = function() return false end,
        IsPedCuffed = function() return false end,
        GetPedHeadOverlayData = function() return true, 255, 0, 0, 0, 0 end,
        GetEntityCoords = function() return vector(0, 0, 0) end,
        GetOffsetFromEntityInWorldCoords = function() return vector(0, 0, 0) end,
        Citizen = setmetatable({
            -- GET_PED_HEAD_BLEND_DATA (the only InvokeNative of game/util.lua)
            InvokeNative = function() return 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0 end,
        }, { __index = function() return stub end }),
        SetPlayerModel = function(_, model)
            ped.model = model
            ped.decorations = {} -- a new ped
        end,
        ClearPedDecorations = function() ped.decorations = {} end,
        -- The Lua wrapper hashes string arguments of Hash parameters (_ch in citizen/scripting/lua/natives_*.lua)
        AddPedDecorationFromHashes = function(_, collection, overlay)
            local function ch(hash)
                if type(hash) == "string" and hash:sub(1, 1) ~= "#" then return joaat(hash) end
                return hash
            end
            ped.decorations[#ped.decorations + 1] = { collection = ch(collection), overlay = ch(overlay) }
        end,
        RegisterNUICallback = function(name, fn) c.nui[name] = fn end,
        RegisterNetEvent = function() end,
        AddEventHandler = function() end,
        TriggerServerEvent = function(name, ...)
            c.sent[#c.sent + 1] = name
            server.emit(name, ...)
        end,
        exports = newExports(),
        _L = function(key) return key end,
    })
    -- world.holdServer: lib.callback.await waits (yields) until the test resumes it, like a slow network
    C.lib = newLib({}, function(name, ...)
        if world.holdServer and coroutine.isyieldable() then coroutine.yield("waiting for " .. name) end
        return server.call(name, ...)
    end)
    C.lib.notify = function() end
    C.Framework = setmetatable({}, { __index = function() return stub end })
    C.Framework.GetPlayerGender = function() return "Male" end
    c.env = C

    H.load(C, "shared/config.lua")
    H.load(C, "shared/blacklist.lua")
    H.load(C, "shared/peds.lua")
    H.load(C, "shared/tattoos.lua")
    H.load(C, "game/constants.lua")
    local f = io.open("game/tattoo_list.lua", "r")
    if f then
        f:close()
        H.load(C, "game/tattoo_list.lua")
    end
    H.load(C, "game/util.lua")
    H.load(C, "game/customization.lua")
    H.load(C, "game/nui.lua")
    H.load(C, "client/defaults.lua")
    H.load(C, "client/common.lua")
    H.load(C, "client/client.lua")

    ---What the ped shows: the overlay hash of each decoration (each name once)
    function c.decorations()
        local seen, list = {}, {}
        for _, d in ipairs(ped.decorations) do
            local key = tostring(d.overlay)
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = key
            end
        end
        return list
    end

    function c.wears(tattoo)
        local hash = joaat(tattoo.hashMale)
        for _, d in ipairs(ped.decorations) do
            if d.overlay == hash then return true end
        end
        return false
    end

    ---NUI post: JSON in both ways, like the browser
    function c.post(name, payload)
        local fn = assert(c.nui[name], "no NUI callback " .. name)
        local result
        fn(H.deepcopy(payload), function(r) result = H.deepcopy(r) end)
        return result
    end

    ---NUI post whose callback may wait for the server (world.holdServer): resume it with the returned function
    function c.postAsync(name, payload)
        local co = coroutine.create(function() return c.post(name, payload) end)
        local _, waiting = assert(coroutine.resume(co))
        return function()
            if coroutine.status(co) == "dead" then return waiting end
            local _, result = assert(coroutine.resume(co))
            return result
        end, coroutine.status(co) ~= "dead"
    end

    c.ui = H.newUi(c)
    return c
end

---The menu's React state and handlers (Heritage-RP/hrp-illenium-appearance-ui web/src/components/Appearance/index.tsx
-- and tattooList.ts): what each button sends to game/nui.lua
function H.newUi(c)
    local ui = {}

    function ui.open()
        local result = c.post("appearance_get_data")
        ui.data = result.appearanceData
        ui.config = result.config
    end

    ---"Apply": the menu sends its whole list plus the new tattoo, and keeps that list only if the game says it was paid
    function ui.apply(tattoo, opacity)
        local chosen = H.deepcopy(tattoo)
        chosen.opacity = opacity or 0.1
        local updated = H.deepcopy(ui.data.tattoos or {})
        local zone = updated[chosen.zone] or {}
        local present = false
        for i, t in ipairs(zone) do
            if t.name == chosen.name then
                zone[i] = H.deepcopy(chosen)
                present = true
            end
        end
        if not present then zone[#zone + 1] = H.deepcopy(chosen) end
        updated[chosen.zone] = zone
        local applied = c.post("appearance_apply_tattoo", { tattoo = chosen, updatedTattoos = updated })
        if applied then ui.data.tattoos = updated end
        return applied
    end

    ---Choosing a tattoo in the list only previews it
    function ui.preview(tattoo, opacity)
        local chosen = H.deepcopy(tattoo)
        chosen.opacity = opacity or 0.1
        c.post("appearance_preview_tattoo", { data = ui.data.tattoos, tattoo = chosen })
    end

    function ui.remove(tattoo)
        local updated = H.deepcopy(ui.data.tattoos)
        local kept = {}
        for _, t in ipairs(updated[tattoo.zone] or {}) do
            if t.name ~= tattoo.name then kept[#kept + 1] = t end
        end
        updated[tattoo.zone] = kept
        c.post("appearance_delete_tattoo", updated)
        ui.data.tattoos = updated
    end

    function ui.changeHair(style)
        local hair = H.deepcopy(ui.data.hair or {})
        hair.style = style
        ui.data.hair = hair
        c.post("appearance_change_hair", hair)
    end

    function ui.save() c.post("appearance_save", ui.data) end

    function ui.exit() c.post("appearance_exit") end

    return ui
end

function H.tattoo(zone, index)
    local env = newEnv({ Config = {} })
    H.load(env, "shared/tattoos.lua")
    return H.deepcopy(env.Config.Tattoos[zone][index])
end

---Number of tattoos per zone list
function H.count(tattoos)
    local n = 0
    for _, list in pairs(tattoos or {}) do n = n + #list end
    return n
end

function H.has(tattoos, tattoo)
    for _, t in ipairs((tattoos or {})[tattoo.zone] or {}) do
        if t.name == tattoo.name then return true end
    end
    return false
end

return H
