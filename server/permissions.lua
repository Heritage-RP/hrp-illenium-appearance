-- Same permission as /pedmenu (lib.addCommand grants `command.pedmenu` to Config.PedMenuGroup)
lib.callback.register("illenium-appearance:server:canUsePedMenu", function(source)
    return Config.EnablePedMenu and IsPlayerAceAllowed(source, "command.pedmenu")
end)

lib.callback.register("illenium-appearance:server:GetPlayerAces", function()
    local src = source
    local allowedAces = {}
    for i = 1, #Config.Aces do
        local ace = Config.Aces[i]
        if IsPlayerAceAllowed(src, ace) then
            allowedAces[#allowedAces+1] = ace
        end
    end
    return allowedAces
end)
