# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Shopping list: the bag icon with a plus next to "Create" in the profession window adds the
  selected recipe with the amount next to "Create". A window in the style of the profession window
  lists the recipes, whose number of crafts can be changed ("+" and "-"), and all reagents they
  need with how many you have and how many are missing ("/gryphoncraft list"). It can dock to the
  right of or below the profession window, or stays free (option). The bag icon next to the chat
  link button opens it, as does a button next to the search box of the auction house (option). A
  click on a reagent searches it in the open auction house. Recipes and reagents show the item
  tooltip. The list is shared by all your characters, so reagents can be gathered or crafted on
  several of them, and opens on login when it is not empty (option). A click on a recipe opens
  or selects it in the profession window, a second click crafts it; in the profession window a
  click on a reagent selects its recipe. Finished crafts are taken off the list.
- Own characters and their professions are remembered account-wide ("/gryphoncraft chars"). A
  reagent that one of your characters of the same faction and ruleset can craft shows its
  profession icon in the shopping list; a click adds that character's recipe, and what it crafts
  counts towards the reagent. A profession's recipes are read when its window is opened.
- Addon structure: slash command `/gryphoncraft` (version, debug, notify, options) and an options
  page in the game settings (Esc > Options > AddOns > GryphonCraft).
