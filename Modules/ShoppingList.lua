local _, ns = ...
local L = ns.L

-- Shopping list shared by all characters of the account: recipes with the number of crafts, and the
-- reagents they need in total compared with what the logged-in character has. So reagents can be
-- gathered or crafted on several characters. Filled from the profession window
-- (Modules/ProfessionsButton.lua), shown by Modules/ShoppingListFrame.lua.
--
-- Each entry of ns.db.shoppingList keeps the required reagents of its recipe as read when it was
-- added, so the list also works while the profession window is closed and on other characters:
--   { recipeID, recipeLevel, name, icon, count, reagents = { { options = { reagent, ... }, quantity } },
--     outputItemID, outputQuantity, crafter }
-- crafter is the full name of the character that crafts it (e.g. a miner smelting bars for an
-- engineer).
-- A reagent slot can be filled by several items (e.g. crafting qualities); options holds them all as
-- { itemID = n } or { currencyID = n }, like the reagents of C_TradeSkillUI.GetRecipeSchematic.
local ShoppingList = ns:RegisterModule("ShoppingList")

ShoppingList.MAX_COUNT = 9999
-- Icon of the button in the profession window and of the window.
ShoppingList.ICON = "Interface\\Icons\\INV_Misc_Bag_10"

local callbacks = {}

local function GetEntries()
    return ns.db.shoppingList
end

local function NotifyChanged()
    for _, callback in ipairs(callbacks) do
        callback()
    end
end

local function ClampCount(count)
    count = floor(tonumber(count) or 0)
    return math.max(0, math.min(count, ShoppingList.MAX_COUNT))
end

-- The required reagent slots of a recipe. Optional and finishing reagents are left out.
local function ReadReagents(recipeID, recipeLevel)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false, recipeLevel)
    if not schematic then
        return nil
    end
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.required and slot.quantityRequired > 0 then
            local options = {}
            for _, reagent in ipairs(slot.reagents) do
                if reagent.itemID then
                    options[#options + 1] = { itemID = reagent.itemID }
                elseif reagent.currencyID then
                    options[#options + 1] = { currencyID = reagent.currencyID }
                end
            end
            if #options > 0 then
                reagents[#reagents + 1] = { options = options, quantity = slot.quantityRequired }
            end
        end
    end
    return reagents, schematic
end

local function FindEntry(recipeID, recipeLevel)
    for index, entry in ipairs(GetEntries()) do
        if entry.recipeID == recipeID and entry.recipeLevel == recipeLevel then
            return entry, index
        end
    end
end

-- callback() runs after every change of the list.
function ShoppingList:RegisterCallback(callback)
    callbacks[#callbacks + 1] = callback
end

function ShoppingList:GetEntries()
    return GetEntries()
end

local function AddRecipe(recipeID, recipeLevel, count, name, icon, crafter)
    local reagents, schematic = ReadReagents(recipeID, recipeLevel)
    if not reagents or #reagents == 0 then
        ns:Print(L["SHOPPING_LIST_NO_REAGENTS"], name or (schematic and schematic.name) or "?")
        return nil
    end

    local entry = FindEntry(recipeID, recipeLevel)
    if entry then
        entry.count = ClampCount(entry.count + count)
        -- The reagents are read again, in case they changed since.
        entry.reagents = reagents
    else
        entry = {
            recipeID = recipeID,
            recipeLevel = recipeLevel,
            name = name or schematic.name,
            icon = icon or schematic.icon,
            count = ClampCount(count),
            reagents = reagents,
        }
        local entries = GetEntries()
        entries[#entries + 1] = entry
    end
    entry.crafter = crafter
    entry.outputItemID = schematic.outputItemID
    entry.outputQuantity = math.max(schematic.quantityMin or 1, 1)
    NotifyChanged()
    return entry
end

-- Adds count crafts of a recipe of the logged-in character; a recipe already on the list gets the
-- crafts added. recipeInfo is the TradeSkillRecipeInfo of the profession window (name and icon).
-- Returns the entry, or nil if the recipe has no required reagents.
function ShoppingList:Add(recipeInfo, recipeLevel, count)
    return AddRecipe(recipeInfo.recipeID, recipeLevel, count, recipeInfo.name, recipeInfo.icon,
        ns.modules.Characters:GetPlayerName())
end

-- Adds the recipe of a crafter (an entry of Professions:GetCrafters) that makes a reagent on the
-- list, with enough crafts for what is still missing (at least 1). What it crafts counts towards
-- the reagent.
function ShoppingList:AddCraft(crafter, missing)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(crafter.recipeID, false)
    local quantity = math.max(schematic and schematic.quantityMin or 1, 1)
    local count = math.max(1, math.ceil(missing / quantity))
    return AddRecipe(crafter.recipeID, nil, count, nil, nil, crafter.fullName)
end

-- Takes over the list each character kept before it was shared (ns.charDb.shoppingList): its
-- recipes join the shared list, crafted by that character unless another one was set.
local function MigrateCharacterList()
    local oldEntries = ns.charDb.shoppingList
    if type(oldEntries) ~= "table" then
        return
    end
    local playerName = ns.modules.Characters:GetPlayerName()
    for _, oldEntry in ipairs(oldEntries) do
        oldEntry.crafter = oldEntry.crafter or playerName
        local entry = FindEntry(oldEntry.recipeID, oldEntry.recipeLevel)
        if entry then
            entry.count = ClampCount(entry.count + oldEntry.count)
        else
            local entries = GetEntries()
            entries[#entries + 1] = oldEntry
        end
    end
    ns.charDb.shoppingList = nil
end

-- A finished craft of the logged-in character takes one craft off its recipe on the list (the
-- recipe goes at 0), so the reagents it used are no longer counted as needed. Also for crafts with
-- Blizzard's "Create" button. Recipe IDs are spell IDs. Event arguments may be secret values.
local function OnSpellcastSucceeded(_, unit, _, spellID)
    if unit ~= "player" or issecretvalue(spellID) then
        return
    end
    local playerName = ns.modules.Characters:GetPlayerName()
    for _, entry in ipairs(GetEntries()) do
        if entry.recipeID == spellID and (entry.crafter == nil or entry.crafter == playerName) then
            ShoppingList:SetCount(entry, entry.count - 1)
            return
        end
    end
end

-- After Characters:OnEnable, which knows the logged-in character.
function ShoppingList:OnEnable()
    MigrateCharacterList()
    NotifyChanged()
    ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", OnSpellcastSucceeded)
end

-- Sets the number of crafts of an entry; 0 removes it.
function ShoppingList:SetCount(entry, count)
    count = ClampCount(count)
    if count == 0 then
        self:Remove(entry)
        return
    end
    entry.count = count
    NotifyChanged()
end

function ShoppingList:Remove(entry)
    for index, other in ipairs(GetEntries()) do
        if other == entry then
            table.remove(GetEntries(), index)
            NotifyChanged()
            return
        end
    end
end

function ShoppingList:Clear()
    wipe(GetEntries())
    NotifyChanged()
end

-- Key of a reagent slot for adding up: its first item or currency. Slots of different recipes with
-- the same reagents count together.
local function GetReagentKey(options)
    local first = options[1]
    return first.itemID and ("item:" .. first.itemID) or ("currency:" .. first.currencyID)
end

-- The reagents of all entries added up, in the order they first appear:
--   { { options, needed, owned, planned, missing, crafters }, ... }
-- owned counts all options of the slot, with the bank where Blizzard's crafting would use it too
-- (ProfessionsUtil.AccumulateReagentsInPossession, as the reagent slots of the profession window).
-- planned is what entries of the list craft of it, missing = needed - owned - planned (at least 0).
-- crafters: own characters that can craft it and send it (Professions:GetCrafters), items only.
function ShoppingList:GetReagentTotals()
    local totals, byKey = {}, {}
    local produced = {}
    for _, entry in ipairs(GetEntries()) do
        if entry.outputItemID then
            produced[entry.outputItemID] = (produced[entry.outputItemID] or 0)
                + entry.count * (entry.outputQuantity or 1)
        end
    end
    for _, entry in ipairs(GetEntries()) do
        for _, reagent in ipairs(entry.reagents) do
            local key = GetReagentKey(reagent.options)
            local total = byKey[key]
            if not total then
                total = { options = reagent.options, needed = 0 }
                byKey[key] = total
                totals[#totals + 1] = total
            end
            total.needed = total.needed + reagent.quantity * entry.count
        end
    end
    for _, total in ipairs(totals) do
        total.owned = ProfessionsUtil.AccumulateReagentsInPossession(total.options)
        local itemIDs = {}
        total.planned = 0
        for _, option in ipairs(total.options) do
            if option.itemID then
                itemIDs[#itemIDs + 1] = option.itemID
                total.planned = total.planned + (produced[option.itemID] or 0)
            end
        end
        total.missing = math.max(0, total.needed - total.owned - total.planned)
        total.crafters = #itemIDs > 0 and ns.modules.Professions:GetCrafters(itemIDs) or {}
    end
    return totals
end

-- "/gryphoncraft list" toggles the window, "/gryphoncraft list clear" empties the list.
ns:RegisterCommand("list", function(args)
    if args:lower() == "clear" then
        ShoppingList:Clear()
        ns:Print(L["SHOPPING_LIST_CLEARED"])
        return
    end
    ns.modules.ShoppingListFrame:Toggle()
end, { L["HELP_LIST"], L["HELP_LIST_CLEAR"] })
