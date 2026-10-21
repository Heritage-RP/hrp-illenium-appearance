-- Menu theme chosen by the server's UI theme (replicated convar hrp_ui_theme) among the themes other resources declare
-- (PRODUCTION-SERVER#520): game/declared_theme.lua, game/nui.lua get_theme_configuration, the configuration the menu and
-- web/dist/index.html fetch. Run: tests/run.sh (from the resource folder).

local H = dofile("tests/lua/harness.lua")
local check = H.check

local DUSK = {
    id = "dusk", borderRadius = "0px", fontColor = "224, 201, 166", fontColorHover = "224, 201, 166",
    fontColorSelected = "20, 16, 10", fontFamily = "Dusk Sans", primaryBackground = "20, 16, 10",
    primaryBackgroundSelected = "224, 201, 166", secondaryBackground = "40, 32, 20", scaleOnHover = false,
    sectionFontWeight = "normal", smoothBackgroundTransition = false,
}

local function config(state)
    return {
        name = "my-config",
        state = state or "started",
        metadata = { hrp_ui_theme = { "themes/dusk.css" }, hrp_appearance_theme = { "themes/appearance.json" } },
        files = { ["themes/appearance.json"] = DUSK },
    }
end

local function themeFor(convars, resources)
    local world = H.newWorld({ convars = convars, resources = resources or { config() } })
    local client = world.connect()
    return client.post("get_theme_configuration"), client, world
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
    check("unset: the fork's themes only", #theme.themes == #client.env.Config.Theme.themes and not hasTheme(theme.themes, "dusk"))
    check("unset: no stylesheet", theme.uiTheme.theme == "neutral" and theme.uiTheme.stylesheet == nil)
end

check("neutral: the upstream default theme", themeFor({ hrp_ui_theme = "neutral" }).currentTheme == "qb-core")

do
    local theme, client = themeFor({ hrp_ui_theme = " Dusk " })
    check("declared: its menu values become the current theme", theme.currentTheme == "dusk" and hasTheme(theme.themes, "dusk"))
    check("declared: its stylesheet goes to the page", theme.uiTheme.theme == "dusk"
        and theme.uiTheme.stylesheet == "nui://my-config/themes/dusk.css")
    check("declared: Config.Theme not rewritten", #client.env.Config.Theme.themes == #theme.themes - 1)
end

check("undeclared: the upstream default theme", themeFor({ hrp_ui_theme = "dawn" }).currentTheme == "qb-core")
check("declared by a stopped resource: the upstream default theme",
    themeFor({ hrp_ui_theme = "dusk" }, { config("stopped") }).currentTheme == "qb-core")

do -- a stylesheet without menu values: the themed page rules, the fork's own menu theme
    local resource = config()
    resource.metadata.hrp_appearance_theme = nil
    local theme = themeFor({ hrp_ui_theme = "dusk" }, { resource })
    check("stylesheet only: the page is themed", theme.uiTheme.stylesheet == "nui://my-config/themes/dusk.css")
    check("stylesheet only: the menu keeps its theme", theme.currentTheme == "qb-core")
end

do -- menu values that are not a theme are skipped
    local resource = config()
    resource.files["themes/appearance.json"] = { id = "dusk", fontColor = 3 }
    check("broken menu values: skipped", themeFor({ hrp_ui_theme = "dusk" }, { resource }).currentTheme == "qb-core")
end

do -- a server that picked another theme in shared/theme.lua keeps it unless a declared theme is selected
    local world = H.newWorld({ convars = { hrp_ui_theme = "neutral" }, resources = { config() } })
    local client = world.connect()
    client.env.Config.Theme.currentTheme = "default"
    check("own default kept", client.post("get_theme_configuration").currentTheme == "default")
    world.convars.hrp_ui_theme = "dusk"
    check("convar read each time the page asks", client.post("get_theme_configuration").currentTheme == "dusk")
    check("Config.Theme not rewritten", client.env.Config.Theme.currentTheme == "default")
end

do -- the page: themed rules from the tokens, only with a declared stylesheet, and no theme of a project
    local file = assert(io.open("web/dist/index.html", "r"))
    local html = file:read("a")
    file:close()
    check("index.html: themed rules drawn with the tokens", html:find("body.hrp-themed", 1, true) ~= nil
        and html:find("var(--hrp-accent)", 1, true) ~= nil)
    check("index.html: only with a declared stylesheet", html:find("uiTheme.stylesheet !== ''", 1, true) ~= nil)
    check("index.html: no named theme, no web font", not html:find("data-theme=", 1, true)
        and not html:find("fonts.googleapis", 1, true))
end

H.done()
