# GryphonCraft

World of Warcraft addon that improves Blizzard's default profession window.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonCraft.

## Target clients

- **Forever** only (16001, `forever` branch of wow-ui-source, Mainline UI). Other clients are not
  supported, and Forever differs from Retail in many places.
- A single client needs no `ns.Compat`: no client checks, and `issecretvalue` is called directly.
- `Core/Names.lua` does not exist yet. When a feature needs names (e.g. crafting orders), take over
  `Core/Names.lua` from GryphonMail, without `Compat.HasRealmNames()`.
- The profession window is the load-on-demand addon `Blizzard_Professions` (`ProfessionsFrame`). It
  does not exist at login: hook it when `ADDON_LOADED` fires for it, or right away if
  `C_AddOns.IsAddOnLoaded("Blizzard_Professions")` is true. Read its source in the `forever` branch
  before hooking.

## Locales

`enUS` (base), `deDE`, `frFR`.

## Saved variables

`GryphonCraftDB` (account-wide) and `GryphonCraftCharDB` (per character).

## Commit scopes

`options`, `core`, `locales`, `toc`.
