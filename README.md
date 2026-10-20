# illenium-appearance

A replacement for clothing resources for various frameworks

<div align='center'><h1><a href='https://docs.illenium.dev/free-resources/illenium-appearance/installation/'>Documentation</a></h3></div>
<br>

<img src="https://i.imgur.com/ltLSMmh.png" alt="illenium-appearance with Tattoos" />

Discord: https://discord.illenium.dev

**Note:** Do **NOT** use the `main` branch as it will most likely be broken for you. NO SUPPORT WILL BE PROVIDED IF YOU USE IT. Only use the [latest release](https://github.com/iLLeniumStudios/illenium-appearance/releases/latest)

## Supported Frameworks

- qb-core
- ESX
- ox_core

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core) (Latest) (Only for qb-core based servers)
- [es_extended](https://github.com/esx-framework/esx-legacy) (Latest) (Only for ESX based servers)
- [ox_core](https://github.com/overextended/ox_core) (experimental) (Only for ox_core based servers)
- [ox_lib](https://github.com/overextended/ox_lib)
- [qb-target](https://github.com/BerkieBb/qb-target) (Optional) (Only for qb-core based servers)

## Features

- Everything from standalone fivem-appearance
- UI from OX Lib
- Player outfits
- Rank based Clothing Rooms for Jobs / Gangs
- Job / Gang locked Stores
- Tattoo's Support
- Hair Textures
- Polyzone Support
- Ped Menu command (/pedmenu) (Configurable)
- Reload Skin command (/reloadskin)
- Improved code quality
- Plastic Surgeons
- qb-target Support
- Skin migration support (qb-clothing / old fivem-appearance / esx_skin)
- Player specific outfit locations (Restricted via CitizenID)
- Makeup Secondary Color
- Blacklist / Limit Components & Props to certain Jobs / Gangs / CitizenIDs / ACEs (Allows you to have VIP clothing on your Server)
- Blacklist / Limit Peds to certain Jobs / Gangs / CitizenIDs / ACEs
- Persist Job / Gang Clothes on reconnects / logout
- Themes Support (Default & QBCore provided out of the box)
- Disable Components / Props Entirely (Clothing as items support)

## New Preview (with Tattoos)

https://streamable.com/qev2h7

## Documentation

Read the docs here: https://docs.illenium.dev

## Credits
- Original Script: https://github.com/pedr0fontoura/fivem-appearance
- Tattoo's Support: https://github.com/franfdezmorales/fivem-appearance
- Last Maintained Fork for QB: https://github.com/mirrox1337/aj-fivem-appearance

## Fork (Heritage-RP)

This fork keeps only generic patches, listed in [PATCHES.md](PATCHES.md). The menu theme follows the replicated convar
`hrp_ui_theme` (`heritage` = the green terminal theme, anything else = upstream's), and any started resource can add ped
models to the ped menu with `hrp_appearance_ped '<model>'` lines in its `fxmanifest.lua`.

The menu's source is [Heritage-RP/hrp-illenium-appearance-ui](https://github.com/Heritage-RP/hrp-illenium-appearance-ui)
(fork of iLLeniumStudios/illenium-appearance-source): build it there (`cd web && npm ci --legacy-peer-deps && npm test &&
npm run build`), copy `web/dist/assets/index.<hash>.js` into `web/dist/assets/` here, delete the old bundle and update
the `<script>` tag of `web/dist/index.html` (keep that file: it holds the heritage theme rules). Lua tests:
`tests/run.sh` (Lua 5.4 in docker, `LUA=lua5.4 tests/run.sh` for a local one).
