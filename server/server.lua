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

lib.callback.register("illenium-appearance:server:generateOutfitCode", function(_, outfitID)
    return OutfitCodeService.GenerateCode(outfitID)
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
    return ShopService.PayForTattoo(source, tattoo)
end)

lib.callback.register("illenium-appearance:server:getOutfits", function(source)
    local citizenID = Framework.GetPlayerID(source)
    return OutfitService.GetAll(citizenID)
end)

lib.callback.register("illenium-appearance:server:getManagementOutfits", function(source, mType, gender)
    return ManagementOutfitService.GetForPlayer(source, mType, gender)
end)

lib.callback.register("illenium-appearance:server:getUniform", function(source)
    return UniformService.Get(Framework.GetPlayerID(source))
end)

-- ============================================================================
-- SERVER EVENTS
-- ============================================================================

RegisterServerEvent("illenium-appearance:server:saveAppearance", function(appearance)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    AppearanceService.Save(citizenID, appearance)
end)

-- Give first clothing items during character creation
RegisterServerEvent("clothes:GiveFirstClothing", function(Props, Comps)
    local src = source
    ClothingService.GiveFirstClothing(src, Props, Comps)
end)

RegisterServerEvent("illenium-appearance:server:chargeCustomer", function(shopType)
    local src = source
    
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

RegisterNetEvent("illenium-appearance:server:saveManagementOutfit", function(outfitData)
    local src = source
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
    ManagementOutfitService.Delete(id)
end)

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

RegisterNetEvent("illenium-appearance:server:ChangeRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, src)
end)

RegisterNetEvent("illenium-appearance:server:ResetRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
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

