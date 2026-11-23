# GryphonCraft

A World of Warcraft addon that improves the default profession window.

## Features

- **Shopping list:** a bag icon with a plus next to "Create" in the profession window adds the
  selected recipe with the amount next to "Create" to a list. Its own window, styled like the
  profession window, free or docked to its right or below it (option), shows all reagents the recipes
  need in total, how many you have (bags and, where crafting may use it, the bank) and how many are
  missing. The number of crafts can be changed in the list. A bag icon next to the chat link button
  opens or closes the list, as does a button next to the search box of the auction house (option).
  The number of crafts changes with "+" and "-" (Shift: 10). A click on a reagent searches it in
  the open auction house. The list is shared by all characters of the account (reagents can be
  gathered or crafted on several of them) and opens on login when it is not empty (option). A click
  on a recipe opens or selects it in the profession window, a second click crafts it; with the
  profession window open, a click on a reagent selects its recipe. Finished crafts are taken off
  the list.
- **Own characters' professions:** every character is remembered account-wide with its
  professions; the recipes of a profession are read when its window is opened. A reagent on the
  shopping list that one of your characters of the same faction and ruleset (PvE, PvP, RP, ...)
  can craft shows that profession's icon: e.g. bars for an engineer that your miner can smelt. A
  click adds that recipe, marked with the character's name, and what it crafts counts towards the
  reagent.
- **Options:** automatic messages, where the shopping list docks and the auction house button, on an
  own page in the game options
  (Esc > Options > AddOns > GryphonCraft).

The full description for CurseForge and Wago is in [docs/addon-description.md](docs/addon-description.md).

## Supported clients

| Client  | Interface | Status    |
| ------- | --------- | --------- |
| Forever | 16001     | Supported |

Other clients are not supported.

## Installation

Copy (or symlink) the `GryphonCraft` folder into the client's AddOns folder:

```
World of Warcraft\_forever_\Interface\AddOns\GryphonCraft
```

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` to a new version section and bump
   `## Version` in `GryphonCraft.toc`, then merge that into `main`.
2. Tag the merge commit on `main` and push the tag:

   ```
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. The `Release` workflow runs luacheck, builds the package with the
   [BigWigs packager](https://github.com/BigWigsMods/packager) and uploads it to CurseForge (project
   ID from `X-Curse-Project-ID` in the TOC), Wago Addons (`X-Wago-ID`), WoWInterface
   (`X-WoWI-ID`) and as a GitHub release. Game versions come from `## Interface`. It needs the
   repository secrets `CF_API_KEY`, `WAGO_API_TOKEN` and `WOWI_API_TOKEN`. The project IDs are not
   in the TOC yet; until they are, the packager only creates the GitHub release.

## Structure

```
GryphonCraft/
├── .github/workflows/
│   ├── luacheck.yml       # luacheck on pushes to main and on pull requests
│   └── release.yml        # Builds and uploads a release on version tags (BigWigs packager)
├── .pkgmeta               # Packager config: changelog and files left out of the package
├── GryphonCraft.toc       # Addon manifest, defines load order
├── LICENSE                # MIT license
├── docs/
│   └── addon-description.md  # Description text for CurseForge / Wago, Markdown (not shipped)
├── Locales/
│   ├── enUS.lua           # Base locale (fallback, all keys)
│   ├── deDE.lua           # German translation
│   └── frFR.lua           # French translation
├── Core/
│   ├── Init.lua           # Namespace, module registry, event dispatcher, defaults
│   ├── Util.lua           # Print/Notify/Debug helpers, debug memory output, defaults merge
│   ├── Names.lua          # Character names on Forever ("First Surname"), from GryphonMail
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
    ├── Characters.lua     # Own characters account-wide: faction, ruleset ("/gryphoncraft chars")
    ├── Professions.lua    # Professions of the own characters and the items they can craft
    ├── ShoppingList.lua   # Shopping list data: recipes with counts, reagents added up ("/gryphoncraft list")
    ├── ShoppingListFrame.lua # Shopping list window: recipes with editable counts, reagents owned/needed, docking
    ├── AuctionHouseButton.lua # Button next to the auction house search box that opens the shopping list
    ├── ProfessionsButton.lua # Profession window buttons: add (next to "Create"), open (next to chat link)
    └── Options.lua        # Options page in the game settings ("/gryphoncraft options")
```

## Adding a module

1. Create `Modules/MyModule.lua`:

   ```lua
   local _, ns = ...
   local MyModule = ns:RegisterModule("MyModule")

   function MyModule:OnInitialize() end -- saved variables available
   function MyModule:OnEnable() end     -- PLAYER_LOGIN
   ```

2. Add it to `GryphonCraft.toc` above `Core\Main.lua`.

## Localization

All strings live in `Locales/`. Add new keys to `enUS.lua` first; other locales
only override what they translate. Missing keys fall back to English.

## Development

Lint with [luacheck](https://github.com/lunarmodules/luacheck). Place `luacheck.exe` in `.tools/`
(ignored by git) and run from the repo root:

```
./.tools/luacheck.exe .
```

## Slash commands

- `/gryphoncraft` – help
- `/gryphoncraft version` – show version
- `/gryphoncraft options` – open the options page
- `/gryphoncraft list` – open or close the shopping list
- `/gryphoncraft list clear` – empty the shopping list
- `/gryphoncraft chars` – list your characters with their professions; characters that can send
  items to the current one are marked with a mailbox icon
- `/gryphoncraft chars remove <number|name>` – forget a character
- `/gryphoncraft notify on|off` – automatic messages (login, hints) of the current character,
  default on
- `/gryphoncraft debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## License

[MIT](LICENSE)
