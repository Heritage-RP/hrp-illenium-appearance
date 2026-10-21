# Patches

Upstream: https://github.com/iLLeniumStudios/illenium-appearance (main)

Fork of iLLeniumStudios/illenium-appearance for the core of Heritage-RP/PRODUCTION-SERVER. Every patch is generic: a
server sets its own values through convars or other resources (Heritage-RP/PRODUCTION-SERVER docs/dev/forks.md).

| Patch | Kind | Upstream | Files |
|---|---|---|---|
| Server split into services (shop, outfit, outfit code, management outfit, uniform, appearance, clothing) | generic | no | `server/services/init.lua`, `server/services/*.lua`, `server/server.lua`, `fxmanifest.lua` |
| Logs through HrpLog (`@hrp-metrics/lib/log.lua`) and `lib.print` | generic | no | `fxmanifest.lua`, `locales/locales.lua`, `server/server.lua`, `server/services/*.lua` |
| New female characters get the female model (ox_core sends the gender with the new character) | generic | candidate | `client/framework/ox/main.lua` |
| Ped list at character creation only for players allowed `/pedmenu` (`Config.NewCharacterSections.Ped = false`) | generic | no | `shared/config.lua`, `client/client.lua`, `server/permissions.lua` |
| Random outfit button (`Config.RandomOutfit`) | generic | candidate | `game/customization.lua`, `game/nui.lua`, `shared/config.lua`, `web/dist/assets/*.js` |
| Same max health for every freemode character (`Config.PlayerMaxHealth`, female model included) | generic | candidate | `game/util.lua`, `shared/config.lua` |
| Clothes as hrp-item-clothes items: starting outfit equipped once, a clothing shop gives only the pieces changed | generic | no | `client/client.lua`, `server/services/clothing.lua`, `server/server.lua` |
| Appearance checked and saved in one transaction, outfit and boss-managed outfit routes protected | generic | candidate | `server/services/appearance.lua`, `server/services/outfit.lua`, `server/services/outfit_code.lua`, `server/database/*.lua`, `server/framework/ox/main.lua`, `server/server.lua`, `client/client.lua` |
| Private routing bucket only in the editor of a character just created | generic | candidate | `server/server.lua` |
| Tattoo shop: each tattoo paid once, bought tattoos kept on the character | generic | candidate | `game/customization.lua`, `game/nui.lua`, `game/util.lua`, `client/client.lua`, `server/server.lua`, `server/services/shop.lua`, `server/services/appearance.lua`, `web/dist/assets/*.js` |
| Menu theme from the replicated convar `hrp_ui_theme`: the theme a started resource declares (`hrp_ui_theme '<path>/<name>.css'` loaded by the page, its `--hrp-*` tokens for the themed rules; `hrp_appearance_theme '<path>.json'` for the menu values), PRODUCTION-SERVER#520 | generic | no | `game/declared_theme.lua`, `shared/theme.lua`, `game/nui.lua`, `web/dist/index.html`, `fxmanifest.lua` |
| Ped models declared by other resources (`hrp_appearance_ped '<model>'` in their fxmanifest) | generic | no | `game/declared_peds.lua`, `game/customization.lua`, `game/util.lua`, `fxmanifest.lua` |
| Beta-test bounties read by hrp-bounty | generic | no | `bounties.json`, `fxmanifest.lua` |
| Tests (Lua 5.4 in docker, `tests/run.sh`) | generic | no | `tests/**` |
| Documentation of the fork | generic | no | `README.md`, `PATCHES.md` |
