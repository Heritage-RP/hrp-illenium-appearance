-- The editor tells other resources when it opens and closes (PRODUCTION-SERVER#558): local client events
-- illenium-appearance:client:customizationStarted / customizationEnded (saved = true when the appearance was kept),
-- and the isPlayerCustomizing export.
-- Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local function names(client)
    local out = {}
    for _, e in ipairs(client.events) do
        if e.name:find("^illenium%-appearance:client:customization") then out[#out + 1] = e end
    end
    return out
end

do -- left without saving
    local world = H.newWorld()
    local client = world.connect()
    check("closed before opening", client.env.client.isPlayerCustomizing() == false)
    client.env.OpenTattooShop()
    client.ui.open()
    local events = names(client)
    check("one start event when the editor opens", #events == 1 and events[1].name == "illenium-appearance:client:customizationStarted")
    check("open while the editor shows", client.env.client.isPlayerCustomizing() == true)
    client.ui.exit()
    events = names(client)
    check("an end event when it closes", #events == 2 and events[2].name == "illenium-appearance:client:customizationEnded")
    check("not saved when left with Exit", events[2].args[1] == false)
    check("closed after leaving", client.env.client.isPlayerCustomizing() == false)
end

do -- saved
    local world = H.newWorld()
    local client = world.connect()
    client.env.OpenTattooShop()
    client.ui.open()
    client.ui.save()
    local events = names(client)
    check("an end event on save", #events == 2 and events[2].name == "illenium-appearance:client:customizationEnded")
    check("saved = true on save", events[2].args[1] == true)
    check("closed after saving", client.env.client.isPlayerCustomizing() == false)
end

H.done()
