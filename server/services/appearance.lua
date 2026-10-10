--[[
    Appearance Service - Handles player appearance operations
    Following SOLID principles:
    - S: Single Responsibility - Only handles appearance save/load
]]

local AppearanceService = {}

-- The appearance comes from the client: only these models without a staff permission or a free edit, and only tattoos
-- already owned or paid this session (PRODUCTION-SERVER#327).
local FREEMODE_MODELS = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }
-- Same permission as /pedmenu (lib.addCommand grants `command.pedmenu` to Config.PedMenuGroup)
local STAFF_ACE = "command.pedmenu"
-- playerskins.skin is a TEXT column (65 535 bytes): a bigger JSON would fail the INSERT
local MAX_APPEARANCE_BYTES = 60000
-- Hair fades are tattoos of this zone, picked for free at the barber (paid on leaving the shop)
local FREE_TATTOO_ZONE = "ZONE_HAIR"

---playerId -> { charId, expires, oneSave }: may save any model and any tattoo (character creation, /pedmenu by staff)
local freeEdits = {}
---playerId -> { charId, [zone .. "/" .. name] = true }: tattoos paid this session
local paidTattoos = {}
---charId -> jobs waiting for the save in progress: saves of a character run one after another, in order
local queues = {}

local function tattooKey(zone, name)
    return zone .. "/" .. name
end

---@param playerId number
---@param charId number|string
---@param durationMs number how long the free edit lasts at most
---@param oneSave boolean|nil ends at the next save of this player
function AppearanceService.AllowFreeEdit(playerId, charId, durationMs, oneSave)
    if not charId then return end
    freeEdits[playerId] = { charId = charId, expires = GetGameTimer() + durationMs, oneSave = oneSave }
end

---@param playerId number
function AppearanceService.EndFreeEdit(playerId)
    freeEdits[playerId] = nil
end

---@param playerId number
---@param charId number|string
---@param tattoo table zone and name of a tattoo paid by ShopService.PayForTattoo
function AppearanceService.RecordPaidTattoo(playerId, charId, tattoo)
    if not charId or type(tattoo) ~= "table" or type(tattoo.zone) ~= "string" or type(tattoo.name) ~= "string" then
        return
    end
    local paid = paidTattoos[playerId]
    if not paid or paid.charId ~= charId then
        paid = { charId = charId }
        paidTattoos[playerId] = paid
    end
    paid[tattooKey(tattoo.zone, tattoo.name)] = true
end

---@param playerId number
function AppearanceService.ForgetPlayer(playerId)
    freeEdits[playerId] = nil
    paidTattoos[playerId] = nil
end

---@return boolean
local function hasFreeEdit(playerId, charId)
    local edit = freeEdits[playerId]
    if not edit then return false end
    if edit.charId ~= charId or GetGameTimer() > edit.expires then
        freeEdits[playerId] = nil
        return false
    end
    if edit.oneSave then freeEdits[playerId] = nil end
    return true
end

---@param stored table|nil appearance in the database
---@return table<string, true>
local function ownedTattoos(stored)
    local owned = {}
    if type(stored) ~= "table" or type(stored.tattoos) ~= "table" then return owned end
    for zone, list in pairs(stored.tattoos) do
        if type(zone) == "string" and type(list) == "table" then
            for i = 1, #list do
                local tattoo = list[i]
                if type(tattoo) == "table" and type(tattoo.name) == "string" then
                    owned[tattooKey(zone, tattoo.name)] = true
                end
            end
        end
    end
    return owned
end

---Already the player's: saved on the character, or paid this session (PRODUCTION-SERVER#12). Taken off then put back in
---the menu, or a second click on "Apply": not paid twice.
---@param playerId number
---@param charId number|string
---@param tattoo any zone and name sent by the client
---@return boolean
function AppearanceService.OwnsTattoo(playerId, charId, tattoo)
    if not charId or type(tattoo) ~= "table" or type(tattoo.zone) ~= "string" or type(tattoo.name) ~= "string" then
        return false
    end
    local key = tattooKey(tattoo.zone, tattoo.name)
    local paid = paidTattoos[playerId]
    if paid and paid.charId == charId and paid[key] then return true end
    return ownedTattoos(Framework.GetAppearance(charId))[key] == true
end

---@return table|nil the tattoo of shared/tattoos.lua with this zone and name
local function findConfigTattoo(zone, name)
    local list = type(zone) == "string" and Config.Tattoos[zone]
    if not list or type(name) ~= "string" then return end
    for i = 1, #list do
        if list[i].name == name then return list[i] end
    end
end

---Tattoos the player may wear, rebuilt from shared/tattoos.lua (hashes and collection never come from the client)
---@param tattoos any tattoos sent by the client
---@param isAllowed fun(zone: string, name: string): boolean
---@return table tattoos
---@return integer dropped
local function sanitizeTattoos(tattoos, isAllowed)
    local result, dropped = {}, 0
    if type(tattoos) ~= "table" then return result, dropped end

    for zone, list in pairs(tattoos) do
        if type(zone) == "string" and Config.Tattoos[zone] and type(list) == "table" then
            local kept, seen = {}, {}
            for i = 1, #list do
                local sent = list[i]
                local tattoo = type(sent) == "table" and findConfigTattoo(zone, sent.name)
                if tattoo and not seen[tattoo.name] and isAllowed(zone, tattoo.name) then
                    seen[tattoo.name] = true
                    local entry = table.clone(tattoo)
                    if type(sent.opacity) == "number" then
                        entry.opacity = math.min(math.max(sent.opacity, 0.1), 1.0)
                    end
                    kept[#kept + 1] = entry
                else
                    dropped += 1
                end
            end
            -- One hair fade at a time (the menu replaces it)
            if zone == FREE_TATTOO_ZONE and #kept > 1 then
                dropped += #kept - 1
                kept = { kept[#kept] }
            end
            result[zone] = kept
        end
    end
    return result, dropped
end

---Checks an appearance sent by a client and keeps only what it may save
---@param playerId number
---@param charId number|string
---@param appearance any
---@param unrestricted boolean staff or free edit: any model, any tattoo of shared/tattoos.lua
---@return table|nil appearance
---@return string|nil reason
function AppearanceService.Validate(playerId, charId, appearance, unrestricted)
    if type(appearance) ~= "table" or type(appearance.model) ~= "string" then
        return nil, "malformed"
    end

    local ok, encoded = pcall(json.encode, appearance)
    if not ok or #encoded > MAX_APPEARANCE_BYTES then
        return nil, "too large"
    end

    if unrestricted then
        appearance.tattoos = sanitizeTattoos(appearance.tattoos, function() return true end)
        return appearance
    end

    local stored = Framework.GetAppearance(charId)
    -- A ped given by the staff (/pedmenu) stays allowed
    if not FREEMODE_MODELS[appearance.model] and not (type(stored) == "table" and stored.model == appearance.model) then
        return nil, "model"
    end

    local owned = ownedTattoos(stored)
    local paid = paidTattoos[playerId]
    if paid and paid.charId ~= charId then paid = nil end

    local tattoos, dropped = sanitizeTattoos(appearance.tattoos, function(zone, name)
        local key = tattooKey(zone, name)
        return zone == FREE_TATTOO_ZONE or owned[key] or (paid and paid[key]) or false
    end)
    appearance.tattoos = tattoos
    if dropped > 0 then
        HrpLog.business.warn("appearance save: unpaid or unknown tattoos dropped", { source = playerId, dropped = dropped })
    end
    return appearance
end

---Runs the jobs of one key one after another: the next starts once the previous one has finished its queries
---@param key any
---@param job function
local function runInOrder(key, job)
    local queue = queues[key]
    if queue then
        queue[#queue + 1] = job
        return
    end
    queue = { job }
    queues[key] = queue
    while queue[1] do
        local ok, err = pcall(queue[1])
        if not ok then
            HrpLog.error("appearance save failed", { charId = key, error = tostring(err) })
        end
        table.remove(queue, 1)
    end
    queues[key] = nil
end

---Get player appearance from database
---@param citizenId string|number Player's citizen ID
---@param model string|nil Optional model to filter by
---@return table|nil appearance
function AppearanceService.Get(citizenId, model)
    return Framework.GetAppearance(citizenId, model)
end

---Save player appearance to database
---@param citizenId string|number Player's citizen ID
---@param appearance table Appearance data
function AppearanceService.Save(citizenId, appearance)
    if appearance then
        runInOrder(citizenId, function()
            Framework.SaveAppearance(appearance, citizenId)
        end)
    end
end

---Save an appearance sent by a player, once checked (PRODUCTION-SERVER#327)
---@param playerId number
---@param appearance any
function AppearanceService.SaveFromPlayer(playerId, appearance)
    local charId = Framework.GetPlayerID(playerId)
    if not charId then return end

    -- Decided on reception: a free edit may end (next event) before a queued save runs
    local unrestricted = IsPlayerAceAllowed(playerId, STAFF_ACE) or hasFreeEdit(playerId, charId)
    runInOrder(charId, function()
        local checked, reason = AppearanceService.Validate(playerId, charId, appearance, unrestricted)
        if not checked then
            HrpLog.business.warn("appearance save refused", { source = playerId, reason = reason })
            return
        end
        if Framework.SaveAppearance(checked, charId) == false then
            HrpLog.error("appearance save failed", { source = playerId, charId = charId })
            return
        end

        local tattoos = 0
        for _, zone in pairs(checked.tattoos) do tattoos += #zone end
        HrpLog.business.debug("appearance saved", { source = playerId, tattoos = tattoos })
    end)
end

Services.Register("AppearanceService", AppearanceService)
return AppearanceService
