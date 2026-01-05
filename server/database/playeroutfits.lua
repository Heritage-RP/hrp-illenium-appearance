Database.PlayerOutfits = {}

-- Controlled by convar: set appearance:useOutfitsTable "false" in server.cfg to disable database outfits
local useOutfitsTable = GetConvar("appearance:useOutfitsTable", "false") == "true"

function Database.PlayerOutfits.GetAllByCitizenID(citizenid)
    if not useOutfitsTable then return {} end
    return MySQL.query.await("SELECT * FROM player_outfits WHERE citizenid = ?", {citizenid})
end

function Database.PlayerOutfits.GetByID(id)
    if not useOutfitsTable then return nil end
    return MySQL.single.await("SELECT * FROM player_outfits WHERE id = ?", {id})
end

function Database.PlayerOutfits.GetByOutfit(name, citizenid) -- for validate duplicate name before insert
    if not useOutfitsTable then return nil end
    return MySQL.single.await("SELECT * FROM player_outfits WHERE outfitname = ? AND citizenid = ?", {name, citizenid})
end

function Database.PlayerOutfits.Add(citizenID, outfitName, model, components, props)
    if not useOutfitsTable then return nil end
    return MySQL.insert.await("INSERT INTO player_outfits (citizenid, outfitname, model, components, props) VALUES (?, ?, ?, ?, ?)", {
        citizenID,
        outfitName,
        model,
        components,
        props
    })
end

function Database.PlayerOutfits.Update(outfitID, model, components, props)
    if not useOutfitsTable then return nil end
    return MySQL.update.await("UPDATE player_outfits SET model = ?, components = ?, props = ? WHERE id = ?", {
        model,
        components,
        props,
        outfitID
    })
end

function Database.PlayerOutfits.DeleteByID(id)
    if not useOutfitsTable then return end
    MySQL.query.await("DELETE FROM player_outfits WHERE id = ?", {id})
end

