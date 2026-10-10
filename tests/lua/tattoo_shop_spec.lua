-- Tattoo shop, end to end (PRODUCTION-SERVER#12): the menu's buttons -> game/nui.lua -> server -> database -> reconnect.
-- Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local A = H.tattoo("ZONE_TORSO", 1)
local B = H.tattoo("ZONE_TORSO", 2)
local C = H.tattoo("ZONE_HEAD", 1)

local function enterShop(client)
    client.env.OpenTattooShop()
    client.ui.open()
end

do -- (a) a second tattoo keeps the first one
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)

    check("(a) first tattoo applied and paid", client.ui.apply(A) == true and world.server.money == 200)
    client.ui.preview(B)
    check("(a) preview of a second tattoo keeps the first on the ped", client.wears(A) and client.wears(B))
    check("(a) second tattoo, same zone, applied", client.ui.apply(B) == true and world.server.money == 100)
    check("(a) both on the ped", client.wears(A) and client.wears(B))
    world.server.money = 100
    check("(a) third tattoo, other zone", client.ui.apply(C) == true)
    check("(a) all three on the ped", client.wears(A) and client.wears(B) and client.wears(C))
    client.ui.changeHair(3)
    check("(a) all three after a hair change", client.wears(A) and client.wears(B) and client.wears(C))
    client.ui.save()
    local saved = world.server.db[world.charId]
    check("(a) all three saved", saved and H.count(saved.tattoos) == 3 and H.has(saved.tattoos, A) and H.has(saved.tattoos, B))
    check("(a) all three still on the ped after saving", client.wears(A) and client.wears(B) and client.wears(C))
end

do -- (b) one paid tattoo stays: after Apply, a hair change, and "Exit customization"
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)

    check("(b) applied and paid", client.ui.apply(A) == true and world.server.money == 200)
    check("(b) on the ped after Apply", client.wears(A))
    client.ui.changeHair(5)
    check("(b) on the ped after a hair change (decorations re-applied)", client.wears(A))
    check("(b) kept in the appearance the game reads", H.has(client.env.client.getPedAppearance(101).tattoos, A))
    client.ui.exit()
    check("(b) on the ped after Exit customization", client.wears(A))
    check("(b) no other fee on leaving", world.server.money == 200)
    local saved = world.server.db[world.charId]
    check("(b) saved although the menu was left without saving", saved and H.has(saved.tattoos, A))

    -- (c) reloaded at the next connection
    local again = world.connect()
    again.env.InitAppearance()
    check("(c) on the ped after reconnecting", again.wears(A))
    check("(c) in the appearance after reconnecting", H.has(again.env.client.getPedAppearance(101).tattoos, A))

    -- A later visit: the tattoo is shown as applied and stays when another one is bought
    enterShop(again)
    check("(c) the menu lists the saved tattoo", H.has(again.ui.data.tattoos, A))
    world.server.money = 100
    check("(c) a second visit adds a tattoo", again.ui.apply(B) == true)
    again.ui.exit()
    local resaved = world.server.db[world.charId]
    check("(c) both kept after leaving the second visit", again.wears(A) and again.wears(B)
        and H.has(resaved.tattoos, A) and H.has(resaved.tattoos, B))
end

do -- Save after Apply: saved once, reloaded
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)
    client.ui.apply(A)
    client.ui.save()
    check("save: on the ped", client.wears(A))
    check("save: in the database", H.has(world.server.db[world.charId].tattoos, A))
    local again = world.connect()
    again.env.InitAppearance()
    check("save: on the ped after reconnecting", again.wears(A))
end

do -- Exit without buying anything: nothing saved, the ped is back as it was
    local world = H.newWorld()
    world.server.db[world.charId] = { model = "mp_m_freemode_01", tattoos = { ZONE_TORSO = { A } } }
    local client = world.connect()
    client.env.InitAppearance()
    enterShop(client)
    client.ui.preview(B)
    client.ui.exit()
    check("exit without buying: the saved tattoo is back", client.wears(A) and not client.wears(B))
    check("exit without buying: nothing saved", #client.sent == 0)
end

do -- Not enough money: refused, nothing on the ped, nothing saved
    local world = H.newWorld({ money = 150 })
    local client = world.connect()
    enterShop(client)
    check("money: first paid", client.ui.apply(A) == true and world.server.money == 50)
    check("money: second refused", client.ui.apply(B) == false and world.server.money == 50)
    check("money: refused tattoo not on the ped", client.wears(A) and not client.wears(B))
    client.ui.save()
    local saved = world.server.db[world.charId]
    check("money: only the paid one saved", H.has(saved.tattoos, A) and not H.has(saved.tattoos, B))
end

do -- Remove then Save: gone, no fee
    local world = H.newWorld()
    world.server.db[world.charId] = { model = "mp_m_freemode_01", tattoos = { ZONE_TORSO = { A, B } } }
    local client = world.connect()
    client.env.InitAppearance()
    enterShop(client)
    client.ui.remove(A)
    check("remove: off the ped at once", not client.wears(A) and client.wears(B))
    client.ui.changeHair(2)
    check("remove: still off after a hair change", not client.wears(A) and client.wears(B))
    client.ui.save()
    local saved = world.server.db[world.charId]
    check("remove: saved without it, no fee", not H.has(saved.tattoos, A) and H.has(saved.tattoos, B) and world.server.money == 300)
end

do -- A tattoo removed then put back in the same visit is not paid twice
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)
    client.ui.apply(A)
    client.ui.remove(A)
    check("re-apply: put back", client.ui.apply(A) == true and client.wears(A))
    check("re-apply: paid once", world.server.money == 200)
end

do -- A saved tattoo removed then put back is free
    local world = H.newWorld()
    world.server.db[world.charId] = { model = "mp_m_freemode_01", tattoos = { ZONE_TORSO = { A } } }
    local client = world.connect()
    client.env.InitAppearance()
    enterShop(client)
    client.ui.remove(A)
    check("owned: put back for free", client.ui.apply(A) == true and world.server.money == 300)
end

do -- Double click on "Apply": one purchase
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)
    local chosen = H.deepcopy(A)
    chosen.opacity = 0.1
    local payload = { tattoo = chosen, updatedTattoos = { ZONE_TORSO = { chosen } } }
    world.holdServer = true
    local first, waiting = client.postAsync("appearance_apply_tattoo", payload)
    local second = client.postAsync("appearance_apply_tattoo", payload)
    world.holdServer = false
    check("double click: the first click waits for the server", waiting)
    check("double click: the second click is refused at once", second() == false)
    check("double click: the first one goes through", first() == true and client.wears(A))
    check("double click: paid once", world.server.money == 200)
end

do -- Save after Apply: no second fee on leaving the shop
    local world = H.newWorld()
    local client = world.connect()
    enterShop(client)
    client.ui.apply(A)
    client.ui.save()
    check("save: one fee only", world.server.money == 200)
end

do -- A client cannot save a tattoo it did not pay
    local world = H.newWorld()
    local client = world.connect()
    client.env.TriggerServerEvent("illenium-appearance:server:saveAppearance",
        { model = "mp_m_freemode_01", tattoos = { ZONE_TORSO = { A } } })
    local saved = world.server.db[world.charId]
    check("server: unpaid tattoo dropped from the save", saved and not H.has(saved.tattoos, A))
    check("server: an unpaid tattoo is not 'owned'", not world.server.env.Services.Get("AppearanceService")
        .OwnsTattoo(world.playerId, world.charId, A))
end

do -- Free in the staff ped menu and at character creation: no payment asked
    local world = H.newWorld()
    local client = world.connect()
    client.env.client.startPlayerCustomization(function() end, { tattoos = true })
    client.ui.open()
    check("free menu: applied without paying", client.ui.apply(A) == true and world.server.money == 300)
    check("free menu: on the ped", client.wears(A))
end

H.done()
