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
- `Core/Names.lua` is GryphonMail's, reduced to Forever names ("First Surname", no realm).
  Characters are keyed by full name; items can only go between characters of the same faction and
  ruleset (`Characters:CanTrade`, ruleset from the game rules or the stored realm name, as in
  GryphonMail's `Modules/Characters.lua`).
- The profession window is the load-on-demand addon `Blizzard_Professions` (`ProfessionsFrame`). It
  does not exist at login: hook it when `ADDON_LOADED` fires for it, or right away if
  `C_AddOns.IsAddOnLoaded("Blizzard_Professions")` is true. Read its source in the `forever` branch
  before hooking.

## Blizzard's profession window and auction house

`Modules/ProfessionsButton.lua` only adds own buttons to `ProfessionsFrame.CraftingPage`: the open
button as a child of `RankBar`, anchored to `LinkButton`; the add button anchored to `CreateButton`,
shown or hidden from a `hooksecurefunc` hook on `CraftingPage.SchematicForm:Init`. It reads the
amount from `CraftingPage.CreateMultipleInputBox` (0 and disabled when nothing can be crafted).
`Modules/ShoppingListFrame.lua` docks its own window to
`ProfessionsFrame` by anchoring the own frame and follows it with `HookScript` (OnShow, OnHide).
A click on a reagent searches the open auction house like Blizzard's gamepad reagent action
(`AuctionHouseFrame:SetSearchText`, then `SearchBar.SearchButton:Click()`).
A click on a recipe of the list selects it with `C_TradeSkillUI.OpenRecipe` (as Blizzard's recipe
tracker; Blizzard's own `OPEN_RECIPE_RESPONSE` handler applies it) and crafts it with
`C_TradeSkillUI.CraftRecipe` (`ProfessionsButton:DoRecipeAction`); Blizzard's "Create" button is
never clicked.
`Modules/AuctionHouseButton.lua` adds an own button to `AuctionHouseFrame.SearchBar` (load on demand,
`Blizzard_AuctionHouseUI`), anchored to its `SearchBox`.
Do not change Blizzard's controls, their anchors or scripts.

## Locales

`enUS` (base), `deDE`, `frFR`.

## Saved variables

`GryphonCraftDB` (account-wide: characters with professions and craftable items, the shopping list,
window settings) and `GryphonCraftCharDB` (per character: automatic messages). Lists each character
kept before the list was shared are moved into the shared list on that character's login.

## Commit scopes

`shopping-list`, `auction-house`, `characters`, `professions`, `options`, `core`, `locales`, `toc`.
