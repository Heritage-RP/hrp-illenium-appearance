if not Framework.Ox() then return end

local Ox = require '@ox_core.lib.init'

function Framework.GetPlayerID(playerId)
    local player = Ox.GetPlayer(playerId)
    return player and player.charId
end

function Framework.HasMoney(playerId, item, amount)
    return exports.ox_inventory:GetItemCount(playerId, item) >= amount
end

function Framework.RemoveMoney(playerId, type, amount)
    return exports.ox_inventory:RemoveItem(playerId, type, amount)
end

function Framework.GetJob()
    return ---@todo
end

function Framework.GetGang()
    return ---@todo
end

---One transaction (PRODUCTION-SERVER#327): a failed INSERT no longer leaves the character without appearance
---@return boolean saved
function Framework.SaveAppearance(appearance, charId)
    return Database.PlayerSkins.Replace(charId, appearance.model, json.encode(appearance))
end

function Framework.GetAppearance(charId, model)
    local result = Database.PlayerSkins.GetByCitizenID(charId, model)
    if result then
        return json.decode(result)
    end
end
