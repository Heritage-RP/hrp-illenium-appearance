--[[
    illenium-appearance Server
    Refactored following SOLID principles:
    - S: Single Responsibility - Logic delegated to focused services
    - O: Open/Closed - Services can be extended without modifying this file
    - D: Dependency Inversion - Services are injected via Services registry
]]

-- Get service references
local ShopService = Services.Get("ShopService")
local OutfitService = Services.Get("OutfitService")
local OutfitCodeService = Services.Get("OutfitCodeService")
local ManagementOutfitService = Services.Get("ManagementOutfitService")
local UniformService = Services.Get("UniformService")
local AppearanceService = Services.Get("AppearanceService")
local ClothingService = Services.Get("ClothingService")

-- ============================================================================
-- CALLBACKS
-- ============================================================================

lib.callback.register("illenium-appearance:server:generateOutfitCode", function(source, outfitID)
    return OutfitCodeService.GenerateCode(Framework.GetPlayerID(source), outfitID)
end)

lib.callback.register("illenium-appearance:server:importOutfitCode", function(source, outfitName, outfitCode)
    local citizenID = Framework.GetPlayerID(source)
    return OutfitCodeService.ImportByCode(citizenID, outfitName, outfitCode) or nil
end)

lib.callback.register("illenium-appearance:server:getAppearance", function(source, model)
    local citizenID = Framework.GetPlayerID(source)
    return AppearanceService.Get(citizenID, model)
end)

lib.callback.register("illenium-appearance:server:hasMoney", function(source, shopType)
    return ShopService.HasMoney(source, shopType)
end)

lib.callback.register("illenium-appearance:server:payForTattoo", function(source, tattoo)
    local charId = Framework.GetPlayerID(source)
    -- Saved on the character or already paid this session: put back for free (PRODUCTION-SERVER#12)
    if AppearanceService.OwnsTattoo(source, charId, tattoo) then
        HrpLog.business.debug("tattoo put back: already owned", { source = source, tattoo = tattoo.name, zone = tattoo.zone })
        return true
    end
    local paid = ShopService.PayForTattoo(source, tattoo)
    -- The next saveAppearance may keep it (PRODUCTION-SERVER#327)
    if paid then AppearanceService.RecordPaidTattoo(source, charId, tattoo) end
    return paid
end)

lib.callback.register("illenium-appearance:server:getOutfits", function(source)
    local citizenID = Framework.GetPlayerID(source)
    return OutfitService.GetAll(citizenID)
end)

lib.callback.register("illenium-appearance:server:getManagementOutfits", function(source, mType, gender)
    if not Config.BossManagedOutfits then return {} end
    return ManagementOutfitService.GetForPlayer(source, mType, gender)
end)

lib.callback.register("illenium-appearance:server:getUniform", function(source)
    return UniformService.Get(Framework.GetPlayerID(source))
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterServerEvent("illenium-appearance:server:saveAppearance", function(appearance)
    -- Checked before saving (PRODUCTION-SERVER#327): model, tattoos owned or paid, size
    AppearanceService.SaveFromPlayer(source, appearance)
end)

-- Character creation: any model of the list and any tattoo, free, until the editor is closed (clothes:GiveFirstClothing)
local CREATION_EDIT_MS = 60 * 60 * 1000
-- /pedmenu used by the staff on a player: one save, within this delay
local PEDMENU_EDIT_MS = 30 * 60 * 1000

AddEventHandler("ox:createdCharacter", function(playerId, _, charId)
    AppearanceService.AllowFreeEdit(playerId, charId, CREATION_EDIT_MS)
end)

AddEventHandler("ox:playerLogout", function(playerId)
    AppearanceService.ForgetPlayer(playerId)
end)

AddEventHandler("playerDropped", function()
    AppearanceService.ForgetPlayer(source)
end)

-- Characters created this session that have not received their starting outfit yet: playerId -> charId.
-- The outfit comes from the client, so it is accepted once, for the character that was just created
-- (PRODUCTION-SERVER#104 — before, any client could send it again and again to get clothes and bags).
local awaitingFirstClothing = {}

AddEventHandler("ox:createdCharacter", function(playerId, _, charId)
    awaitingFirstClothing[playerId] = charId
end)

AddEventHandler("playerDropped", function()
    awaitingFirstClothing[source] = nil
end)

-- Give first clothing items during character creation
RegisterServerEvent("clothes:GiveFirstClothing", function(Props, Comps)
    local src = source
    -- Sent right after the creation editor's saveAppearance: the free edit is over
    AppearanceService.EndFreeEdit(src)
    local charId = awaitingFirstClothing[src]
    if not charId or charId ~= Framework.GetPlayerID(src) then return end
    awaitingFirstClothing[src] = nil

    ClothingService.GiveFirstClothing(src, Props, Comps)
end)

RegisterServerEvent("illenium-appearance:server:chargeCustomer", function(shopType)
    local src = source
    -- Config.ChargePerTattoo: TattooCost is the price of each tattoo, already paid when applied — no second fee on
    -- leaving the shop (PRODUCTION-SERVER#12)
    if shopType == "tattoo" and Config.ChargePerTattoo then return end

    if ShopService.ChargeCustomer(src, shopType) then
        local cost = ShopService.GetCost(shopType)
        ShopService.NotifySuccess(src, cost, shopType)
        
        -- Give clothing items when purchasing from clothing shop
        if shopType == 'clothing' then
            ClothingService.GiveFromClientLists(src)
        end
    else
        ShopService.NotifyFailure(src)
    end
end)

RegisterNetEvent("illenium-appearance:server:saveOutfit", function(name, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    
    if model and components and props then
        local id = OutfitService.Save(citizenID, name, model, components, props)
        if id then
            lib.notify(src, {
                title = _L("outfits.save.success.title"),
                description = string.format(_L("outfits.save.success.description"), name),
                type = "success",
                position = Config.NotifyOptions.position
            })
        end
    end
end)

RegisterNetEvent("illenium-appearance:server:updateOutfit", function(id, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    
    if model and components and props then
        local outfitName = OutfitService.Update(citizenID, id, model, components, props)
        if outfitName then
            lib.notify(src, {
                title = _L("outfits.update.success.title"),
                description = string.format(_L("outfits.update.success.description"), outfitName),
                type = "success",
                position = Config.NotifyOptions.position
            })
        end
    end
end)

-- Job / gang outfits managed by their boss: off on Héritage RP, and ox_core has no job for Framework.GetJob. Without these
-- routes no client can fill or empty management_outfits (PRODUCTION-SERVER#327); when on, the staff permission is needed.
if Config.BossManagedOutfits then
    RegisterNetEvent("illenium-appearance:server:saveManagementOutfit", function(outfitData)
        local src = source
        if type(outfitData) ~= "table" or not IsPlayerAceAllowed(src, "command.pedmenu") then return end
        local id = ManagementOutfitService.Save(outfitData)

        if id then
            lib.notify(src, {
                title = _L("outfits.save.success.title"),
                description = string.format(_L("outfits.save.success.description"), outfitData.Name),
                type = "success",
                position = Config.NotifyOptions.position
            })
        end
    end)

    RegisterNetEvent("illenium-appearance:server:deleteManagementOutfit", function(id)
        if not IsPlayerAceAllowed(source, "command.pedmenu") then return end
        ManagementOutfitService.Delete(id)
    end)
end

RegisterNetEvent("illenium-appearance:server:syncUniform", function(uniform)
    local src = source
    UniformService.Set(Framework.GetPlayerID(src), uniform)
end)

RegisterNetEvent("illenium-appearance:server:deleteOutfit", function(id)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    OutfitService.Delete(citizenID, id)
end)

RegisterNetEvent("illenium-appearance:server:resetOutfitCache", function()
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    OutfitService.ResetCache(citizenID)
end)

-- A private routing bucket only while editing the appearance of a character just created (PRODUCTION-SERVER#307):
-- any client could send these at any time — vanish from everyone, or leave a bucket the staff imposed.
-- playerId -> true: created a character, may enter its editor bucket once.
local mayIsolate = {}
-- playerId -> bucket it was in before the editor, to go back to it.
local isolated = {}

AddEventHandler("ox:createdCharacter", function(playerId)
    mayIsolate[playerId] = true
end)

AddEventHandler("playerDropped", function()
    mayIsolate[source] = nil
    isolated[source] = nil
end)

RegisterNetEvent("illenium-appearance:server:ChangeRoutingBucket", function()
    local src = source
    if not mayIsolate[src] or isolated[src] then return end
    mayIsolate[src] = nil
    isolated[src] = GetPlayerRoutingBucket(src)
    SetPlayerRoutingBucket(src, src)
end)

RegisterNetEvent("illenium-appearance:server:ResetRoutingBucket", function()
    local src = source
    local previous = isolated[src]
    if previous == nil then return end
    isolated[src] = nil
    SetPlayerRoutingBucket(src, previous)
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

if Config.EnablePedMenu then
    lib.addCommand("pedmenu", {
        help = _L("commands.pedmenu.title"),
        params = {
            {
                name = "playerID",
                type = "number",
                help = "Target player's server id",
                optional = true
            },
        },
        restricted = Config.PedMenuGroup
    }, function(source, args)
        local target = source
        if args.playerID then
            local citizenID = Framework.GetPlayerID(args.playerID)
            if citizenID then
                target = args.playerID
            else
                lib.notify(source, {
                    title = _L("commands.pedmenu.failure.title"),
                    description = _L("commands.pedmenu.failure.description"),
                    type = "error",
                    position = Config.NotifyOptions.position
                })
                return
            end
        end
        -- The ped menu offers every model and free tattoos: its next save may keep them (PRODUCTION-SERVER#327)
        AppearanceService.AllowFreeEdit(target, Framework.GetPlayerID(target), PEDMENU_EDIT_MS, true)
        TriggerClientEvent("illenium-appearance:client:openClothingShopMenu", target, true)
    end)
end

if Config.EnableJobOutfitsCommand then
    lib.addCommand("joboutfits", { help = _L("commands.joboutfits.title"), }, function(source)
        TriggerClientEvent("illenium-apearance:client:outfitsCommand", source, true)
    end)

    lib.addCommand("gangoutfits", { help = _L("commands.gangoutfits.title"), }, function(source)
        TriggerClientEvent("illenium-apearance:client:outfitsCommand", source)
    end)
end

lib.addCommand("reloadskin", { help = _L("commands.reloadskin.title") }, function(source)
    TriggerClientEvent("illenium-appearance:client:reloadSkin", source)
end)

lib.addCommand("clearstuckprops", { help = _L("commands.clearstuckprops.title") }, function(source)
    TriggerClientEvent("illenium-appearance:client:ClearStuckProps", source)
end)

lib.versionCheck("iLLeniumStudios/illenium-appearance")

