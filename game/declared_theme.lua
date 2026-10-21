-- The server's UI theme, declared by other resources (Heritage-RP/PRODUCTION-SERVER#520). The replicated convar
-- `hrp_ui_theme` names a theme; a started resource declares its stylesheet (`hrp_ui_theme '<path>/<name>.css'`, the
-- theme is the file's name, read by every NUI of the server) and, for this menu, its values
-- (`hrp_appearance_theme '<path>.json'`: an object with the fields of a Config.Theme.themes entry, `id` = the theme
-- name). game/nui.lua hands both to the page: the menu takes the declared values, web/dist/index.html loads the
-- stylesheet and turns on its themed rules (the `--hrp-*` tokens). `neutral`, an unknown name or a theme without menu
-- values keeps Config.Theme.currentTheme, the upstream look.

DeclaredTheme = {}

DeclaredTheme.CONVAR = "hrp_ui_theme"
DeclaredTheme.STYLESHEET_KEY = "hrp_ui_theme"
DeclaredTheme.MENU_KEY = "hrp_appearance_theme"
DeclaredTheme.DEFAULT = "neutral"

local ACTIVE_STATES = { started = true, starting = true }
-- the fields of a menu theme (shared/theme.lua) and their Lua types
local FIELDS = {
    borderRadius = "string", fontColor = "string", fontColorHover = "string", fontColorSelected = "string",
    fontFamily = "string", primaryBackground = "string", primaryBackgroundSelected = "string",
    secondaryBackground = "string", scaleOnHover = "boolean", sectionFontWeight = "string",
    smoothBackgroundTransition = "boolean",
}

---The theme name a value holds (lower case letters, digits and dashes, starting with a letter), nil otherwise
---@param value any
---@return string?
function DeclaredTheme.name(value)
    if type(value) ~= "string" then return nil end
    local name = value:match("^%s*(.-)%s*$"):lower()
    return name:match("^[a-z][a-z0-9%-]*$") and name or nil
end

---A menu theme from a decoded file: every field of Config.Theme.themes with its type, `id` a theme name; nil otherwise
---@param value any
---@return table?
function DeclaredTheme.menu(value)
    if type(value) ~= "table" or not DeclaredTheme.name(value.id) then return nil end
    local theme = { id = DeclaredTheme.name(value.id) }
    for field, kind in pairs(FIELDS) do
        if type(value[field]) ~= kind then return nil end
        theme[field] = value[field]
    end
    return theme
end

local function each(natives, key, fn)
    for i = 0, (tonumber(natives.GetNumResources()) or 0) - 1 do
        local resource = natives.GetResourceByFindIndex(i)
        if type(resource) == "string" and ACTIVE_STATES[natives.GetResourceState(resource)] then
            for j = 0, (tonumber(natives.GetNumResourceMetadata(resource, key)) or 0) - 1 do
                local value = natives.GetResourceMetadata(resource, key, j)
                if type(value) == "string" and value ~= "" then fn(resource, value) end
            end
        end
    end
end

---What the convar selects among the started resources' declarations: the theme name, its stylesheet
---(`nui://<resource>/<file>`) and its menu values (first declaration of a name wins); nil fields when not declared.
---@param natives table GetConvar, GetNumResources, GetResourceByFindIndex, GetResourceState, GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile, decode
---@return { name: string, stylesheet: string?, menu: table? }
function DeclaredTheme.read(natives)
    local name = DeclaredTheme.name(natives.GetConvar(DeclaredTheme.CONVAR, DeclaredTheme.DEFAULT))
    if not name or name == DeclaredTheme.DEFAULT then return { name = DeclaredTheme.DEFAULT } end

    local found = { name = name }
    each(natives, DeclaredTheme.STYLESHEET_KEY, function(resource, file)
        local base = file:match("([^/]+)%.[cC][sS][sS]%s*$")
        if not found.stylesheet and base and DeclaredTheme.name(base) == name then
            found.stylesheet = ("nui://%s/%s"):format(resource, (file:gsub("^/+", "")))
        end
    end)
    each(natives, DeclaredTheme.MENU_KEY, function(resource, file)
        if found.menu then return end
        local text = natives.LoadResourceFile(resource, file)
        local ok, decoded = pcall(natives.decode, text or "")
        local menu = ok and DeclaredTheme.menu(decoded)
        if menu and menu.id == name then found.menu = menu end
    end)
    if not found.stylesheet then return { name = DeclaredTheme.DEFAULT } end
    return found
end

---The theme configuration the menu fetches: the declared menu theme added to Config.Theme.themes and made current, the
---configuration as it is otherwise. The input is left as it is.
---@param config table Config.Theme
---@param declared { name: string, stylesheet: string?, menu: table? }
---@return { currentTheme: string, themes: table[], uiTheme: { theme: string, stylesheet: string? } }
function DeclaredTheme.configuration(config, declared)
    local themes = {}
    for i = 1, #config.themes do themes[i] = config.themes[i] end
    local current = config.currentTheme
    if declared.menu then
        themes[#themes + 1] = declared.menu
        current = declared.menu.id
    end
    return {
        currentTheme = current,
        themes = themes,
        uiTheme = { theme = declared.name, stylesheet = declared.stylesheet },
    }
end

---The configuration now (convar and declarations read at each call: a theme resource may start later)
---@return table
function DeclaredTheme.current()
    return DeclaredTheme.configuration(Config.Theme, DeclaredTheme.read({
        GetConvar = GetConvar,
        GetNumResources = GetNumResources,
        GetResourceByFindIndex = GetResourceByFindIndex,
        GetResourceState = GetResourceState,
        GetNumResourceMetadata = GetNumResourceMetadata,
        GetResourceMetadata = GetResourceMetadata,
        LoadResourceFile = LoadResourceFile,
        decode = json.decode,
    }))
end
