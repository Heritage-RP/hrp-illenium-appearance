--[[
    Shop Service - Handles shop-related operations
    Following SOLID principles:
    - S: Single Responsibility - Only handles shop pricing and transactions
]]

local ShopService = {}

---Get the cost for a specific shop type
---@param shopType string The type of shop (clothing, barber, tattoo, surgeon)
---@return number The cost for that shop
function ShopService.GetCost(shopType)
    local costs = {
        clothing = Config.ClothingCost,
        barber = Config.BarberCost,
        tattoo = Config.TattooCost,
        surgeon = Config.SurgeonCost
    }
    return costs[shopType] or 0
end

---Check if player has enough money for a shop
---@param source number Player source
---@param shopType string The type of shop
---@return boolean hasMoney
---@return number cost
function ShopService.HasMoney(source, shopType)
    local cost = ShopService.GetCost(shopType)
    local hasMoney = Framework.HasMoney(source, "cash", cost)
    return hasMoney, cost
end

---Charge a player for a shop visit
---@param source number Player source
---@param shopType string The type of shop
---@return boolean success
function ShopService.ChargeCustomer(source, shopType)
    local cost = ShopService.GetCost(shopType)
    return Framework.RemoveMoney(source, "cash", cost)
end

---Process a tattoo purchase
---@param source number Player source
---@param tattoo table Tattoo data with cost and label
---@return boolean success
function ShopService.PayForTattoo(source, tattoo)
    local cost = tattoo.cost or Config.TattooCost
    
    if Framework.RemoveMoney(source, "cash", cost) then
        lib.notify(source, {
            title = _L("purchase.tattoo.success.title"),
            description = string.format(_L("purchase.tattoo.success.description"), tattoo.label, cost),
            type = "success",
            position = Config.NotifyOptions.position
        })
        return true
    else
        lib.notify(source, {
            title = _L("purchase.tattoo.failure.title"),
            description = _L("purchase.tattoo.failure.description"),
            type = "error",
            position = Config.NotifyOptions.position
        })
        return false
    end
end

---Notify player of successful purchase
---@param source number Player source
---@param cost number Amount charged
---@param shopType string The type of shop
function ShopService.NotifySuccess(source, cost, shopType)
    lib.notify(source, {
        title = _L("purchase.store.success.title"),
        description = string.format(_L("purchase.store.success.description"), cost, shopType),
        type = "success",
        position = Config.NotifyOptions.position
    })
end

---Notify player of failed purchase
---@param source number Player source
function ShopService.NotifyFailure(source)
    lib.notify(source, {
        title = _L("purchase.store.failure.title"),
        description = _L("purchase.store.failure.description"),
        type = "error",
        position = Config.NotifyOptions.position
    })
end

Services.Register("ShopService", ShopService)
return ShopService
