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
| Random face button (`Config.RandomFace` lists per sex, replaced by a resource's `hrp_appearance_random_face '<path>.json'`), button tooltips in the locales, client records through HrpLog | generic | candidate | `game/random_face.lua`, `game/customization.lua`, `game/nui.lua`, `shared/config.lua`, `locales/en.lua`, `locales/fr.lua`, `fxmanifest.lua`, `web/dist/assets/*.js`, `web/dist/index.html` |
| Clothes of character creation limited to a server's lists (`Config.CreationClothes`, replaced by a resource's `hrp_appearance_creation_clothes '<path>.json'`): sections hidden, other drawables skipped, the creation save and the starting clothing items checked on the server (PRODUCTION-SERVER#561) | generic | no | `shared/creation_clothes.lua`, `shared/config.lua`, `game/customization.lua`, `client/client.lua`, `server/services/appearance.lua`, `server/server.lua`, `fxmanifest.lua`, `tests/lua/harness.lua`, `tests/lua/creation_clothes_spec.lua` |
| Appearance imposed by another resource on a player's character (server export `setRequiredAppearance(playerId, required)`: eye colour and head overlays, cleared at logout): the editor holds them on the ped and in its sliders (random face and model change included), every save of that player puts them back (PRODUCTION-SERVER#17) | generic | no | `shared/required_appearance.lua`, `game/customization.lua`, `game/nui.lua`, `server/services/appearance.lua`, `server/server.lua`, `fxmanifest.lua`, `tests/lua/harness.lua`, `tests/lua/required_appearance_spec.lua` |
| Same max health for every freemode character (`Config.PlayerMaxHealth`, female model included) | generic | candidate | `game/util.lua`, `shared/config.lua` |
| Clothes as hrp-item-clothes items: starting outfit equipped once, a clothing shop gives only the pieces changed | generic | no | `client/client.lua`, `server/services/clothing.lua`, `server/server.lua` |
| Appearance checked and saved in one transaction, outfit and boss-managed outfit routes protected | generic | candidate | `server/services/appearance.lua`, `server/services/outfit.lua`, `server/services/outfit_code.lua`, `server/database/*.lua`, `server/framework/ox/main.lua`, `server/server.lua`, `client/client.lua` |
| Private routing bucket only in the editor of a character just created | generic | candidate | `server/server.lua` |
| Tattoo shop: each tattoo paid once, bought tattoos kept on the character | generic | candidate | `game/customization.lua`, `game/nui.lua`, `game/util.lua`, `client/client.lua`, `server/server.lua`, `server/services/shop.lua`, `server/services/appearance.lua`, `web/dist/assets/*.js` |
| Menu theme from the replicated convar `hrp_ui_theme`: the theme a started resource declares (`hrp_ui_theme '<path>/<name>.css'` loaded by the page, its `--hrp-*` tokens for the themed rules; `hrp_appearance_theme '<path>.json'` for the menu values), PRODUCTION-SERVER#520 | generic | no | `game/declared_theme.lua`, `shared/theme.lua`, `game/nui.lua`, `web/dist/index.html`, `fxmanifest.lua` |
| Ped models declared by other resources (`hrp_appearance_ped '<model>'` in their fxmanifest) | generic | no | `game/declared_peds.lua`, `game/customization.lua`, `game/util.lua`, `fxmanifest.lua` |
| Editor open / closed for other resources: local client events `illenium-appearance:client:customizationStarted` and `customizationEnded` (`saved`), export `isPlayerCustomizing` (PRODUCTION-SERVER#558) | generic | candidate | `game/customization.lua`, `tests/lua/harness.lua`, `tests/lua/customization_events_spec.lua` |
| Beta-test bounties read by hrp-bounty | generic | no | `bounties.json`, `fxmanifest.lua` |
| Tests (Lua 5.4 in docker, `tests/run.sh`) | generic | no | `tests/**` |
| Documentation of the fork | generic | no | `README.md`, `PATCHES.md` |
