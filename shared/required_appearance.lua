-- Appearance a server imposes on a player's character (Heritage-RP/PRODUCTION-SERVER#17): another resource sets it on
-- the server, `exports['illenium-appearance']:setRequiredAppearance(playerId, required)` (nil clears it; cleared at
-- logout and when the player leaves), e.g. the marks a rule of its world puts on a character:
--   { "eyeColor": 26, "headOverlays": { "ageing": { "style": 14, "opacity": 1.0 } } }
-- Only on a freemode ped. The editor shows these features fixed (their sliders hold one value, game/customization.lua)
-- and puts them on the ped, the server puts them back in every save of that player (server/services/appearance.lua).
-- Pure functions.

RequiredAppearance = {}

-- Head overlays of the game, by the names of the appearance (game/constants.lua HEAD_OVERLAYS)
RequiredAppearance.HEAD_OVERLAYS = {
    blemishes = true, beard = true, eyebrows = true, ageing = true, makeUp = true, blush = true, complexion = true,
    sunDamage = true, lipstick = true, moleAndFreckles = true, chestHair = true, bodyBlemishes = true,
}
local EYE_COLOR_MAX = 31
local STYLE_MAX = 254
-- Opacities are compared at the menu's step (0.1)
local OPACITY_EPSILON = 0.001
local FREEMODE = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }

local function integer(value, max)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= max
end

---The features a value imposes, checked whole: nil when any part is invalid or it imposes nothing
---@param value any
---@return table? { eyeColor?: integer, headOverlays: { [name]: { style: integer, opacity: number } } }
function RequiredAppearance.settings(value)
    if type(value) ~= "table" then return nil end
    local required, count = { headOverlays = {} }, 0
    if value.eyeColor ~= nil then
        if not integer(value.eyeColor, EYE_COLOR_MAX) then return nil end
        required.eyeColor = math.tointeger(value.eyeColor)
        count += 1
    end
    if value.headOverlays ~= nil then
        if type(value.headOverlays) ~= "table" then return nil end
        for name, overlay in pairs(value.headOverlays) do
            if not RequiredAppearance.HEAD_OVERLAYS[name] or type(overlay) ~= "table" then return nil end
            local opacity = overlay.opacity
            if not integer(overlay.style, STYLE_MAX) or type(opacity) ~= "number" or opacity < 0 or opacity > 1 then
                return nil
            end
            required.headOverlays[name] = { style = math.tointeger(overlay.style), opacity = opacity + 0.0 }
            count += 1
        end
    end
    if count == 0 then return nil end
    return required
end

---Whether a model takes these features (head overlays and eye colour exist on the freemode peds only)
---@param model any model name
function RequiredAppearance.appliesTo(model)
    return FREEMODE[model] == true
end

---Puts the features in an appearance (changed in place): `headOverlays` and `eyeColor` as the menu and the database
---hold them; the colours of an overlay are kept
---@param appearance table
---@param required table? RequiredAppearance.settings
---@return integer changed features that differed
function RequiredAppearance.apply(appearance, required)
    if not required then return 0 end
    local changed = 0
    if required.eyeColor and appearance.eyeColor ~= required.eyeColor then
        appearance.eyeColor = required.eyeColor
        changed += 1
    end
    if next(required.headOverlays) then
        if type(appearance.headOverlays) ~= "table" then appearance.headOverlays = {} end
        for name, wanted in pairs(required.headOverlays) do
            local overlay = appearance.headOverlays[name]
            if type(overlay) ~= "table" then
                overlay = { color = 0, secondColor = 0 }
                appearance.headOverlays[name] = overlay
            end
            local opacity = tonumber(overlay.opacity)
            if overlay.style ~= wanted.style or not opacity or math.abs(opacity - wanted.opacity) > OPACITY_EPSILON then
                overlay.style, overlay.opacity = wanted.style, wanted.opacity
                changed += 1
            end
        end
    end
    return changed
end

---Holds the menu's settings on the imposed values (changed in place): a slider whose min and max are the value
---@param settings table client.getAppearanceSettings()
---@param required table? RequiredAppearance.settings
function RequiredAppearance.lockSettings(settings, required)
    if not required then return end
    if required.eyeColor and settings.eyeColor then
        settings.eyeColor = { min = required.eyeColor, max = required.eyeColor }
    end
    for name, wanted in pairs(required.headOverlays) do
        local overlay = settings.headOverlays and settings.headOverlays[name]
        if overlay then
            overlay.style = { min = wanted.style, max = wanted.style }
            overlay.opacity = { min = wanted.opacity, max = wanted.opacity, factor = 0.1 }
        end
    end
end
