Database.PlayerOutfitCodes = {}

-- Outfit codes share outfits of player_outfits: off with it (appearance:useOutfitsTable, PRODUCTION-SERVER#327)
local useOutfitsTable = GetConvar("appearance:useOutfitsTable", "false") == "true"

function Database.PlayerOutfitCodes.GetByCode(code)
    if not useOutfitsTable then return nil end
    return MySQL.single.await("SELECT * FROM player_outfit_codes WHERE code = ?", {code})
end

function Database.PlayerOutfitCodes.GetByOutfitID(outfitID)
    if not useOutfitsTable then return nil end
    return MySQL.single.await("SELECT * FROM player_outfit_codes WHERE outfitID = ?", {outfitID})
end

function Database.PlayerOutfitCodes.Add(outfitID, code)
    if not useOutfitsTable then return nil end
    return MySQL.insert.await("INSERT INTO player_outfit_codes (outfitid, code) VALUES (?, ?)", {outfitID, code})
end

function Database.PlayerOutfitCodes.DeleteByOutfitID(id)
    if not useOutfitsTable then return end
    MySQL.query.await("DELETE FROM player_outfit_codes WHERE outfitid = ?", {id})
end
