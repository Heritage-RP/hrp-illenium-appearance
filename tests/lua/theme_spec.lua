-- Menu theme chosen by the server's UI theme (replicated convar hrp_ui_theme): game/nui.lua get_theme_configuration,
-- the configuration the menu and web/dist/index.html fetch. Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local function themeFor(convars)
    local world = H.newWorld({ convars = convars })
    local client = world.connect()
    return client.post("get_theme_configuration"), client
end

local function hasTheme(themes, id)
    for _, theme in ipairs(themes) do
        if theme.id == id then return true end
    end
    return false
end

do
    local theme, client = themeFor({})
    check("unset: the upstream default theme", theme.currentTheme == "qb-core")
    check("unset: every theme sent", #theme.themes == #client.env.Config.Theme.themes and hasTheme(theme.themes, "heritage"))
end

check("neutral: the upstream default theme", themeFor({ hrp_ui_theme = "neutral" }).currentTheme == "qb-core")
check("other value: the upstream default theme", themeFor({ hrp_ui_theme = "Heritage " }).currentTheme == "qb-core")
check("heritage: the heritage theme", themeFor({ hrp_ui_theme = "heritage" }).currentTheme == "heritage")

do -- a server that picked another theme in shared/theme.lua keeps it unless its UI theme is heritage
    local world = H.newWorld({ convars = { hrp_ui_theme = "neutral" } })
    local client = world.connect()
    client.env.Config.Theme.currentTheme = "default"
    check("own default kept", client.post("get_theme_configuration").currentTheme == "default")
    world.convars.hrp_ui_theme = "heritage"
    check("convar read each time the page asks", client.post("get_theme_configuration").currentTheme == "heritage")
    check("Config.Theme not rewritten", client.env.Config.Theme.currentTheme == "default")
end

do -- no theme id or class named after the lore
    local file = assert(io.open("web/dist/index.html", "r"))
    local html = file:read("a")
    file:close()
    check("index.html: heritage-theme rules, only on the heritage theme", html:find("body.heritage-theme", 1, true) ~= nil
        and html:find("theme.currentTheme === HERITAGE", 1, true) ~= nil)
    check("index.html: no lore word", not html:lower():find("pip", 1, true))
end

H.done()
