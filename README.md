# GryphonCraft

A World of Warcraft addon that improves the default profession window.

## Features

- **Options:** automatic messages, on an own page in the game options
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
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
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
- `/gryphoncraft notify on|off` – automatic messages (login, hints) of the current character,
  default on
- `/gryphoncraft debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## License

[MIT](LICENSE)
