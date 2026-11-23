local _, ns = ...
local L = ns.L

-- Two own buttons on the crafting page of Blizzard's profession window:
-- - A bag icon next to the chat link button opens or closes the shopping list.
-- - A bag icon with a plus between the amount box and "Create" adds the selected recipe with the
--   number in Blizzard's amount box (at least 1) to the shopping list and opens it; a right-click
--   only opens or closes the list. Its visibility follows SchematicForm:Init (hooksecurefunc),
--   which runs on every recipe selection.
--
-- Blizzard_Professions is load on demand; Blizzard's controls are not changed.
local ProfessionsButton = ns:RegisterModule("ProfessionsButton")

local PROFESSIONS_ADDON = "Blizzard_Professions"
local BUTTON_SIZE = 24
-- Centered in the gap between the amount box (its arrow button) and "Create" on Forever.
local BUTTON_GAP = -14
local PLUS_SIZE = 14

local ICON = ns.modules.ShoppingList.ICON

local button, openButton

local function GetCraftingPage()
    return ProfessionsFrame and ProfessionsFrame.CraftingPage
end

-- Recipes without reagents to buy: gathering, dummy and recraft entries.
local function CanAddRecipe(recipeInfo)
    return recipeInfo ~= nil and not recipeInfo.isDummyRecipe and not recipeInfo.isGatheringRecipe
        and not recipeInfo.isRecraft
end

local function UpdateButton()
    local page = GetCraftingPage()
    button:SetShown(CanAddRecipe(page.SchematicForm:GetRecipeInfo()))
end

-- Blizzard's amount box is 0 and disabled when nothing can be crafted, so it falls back to 1; the
-- number can be changed in the shopping list.
local function GetAmount(page)
    local inputBox = page.CreateMultipleInputBox
    local value = inputBox:IsShown() and inputBox:GetValue() or 0
    return math.max(1, value)
end

local function OnClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.modules.ShoppingListFrame:Toggle()
        return
    end
    local page = GetCraftingPage()
    local form = page.SchematicForm
    local recipeInfo = form:GetRecipeInfo()
    if not CanAddRecipe(recipeInfo) then
        return
    end
    local entry = ns.modules.ShoppingList:Add(recipeInfo, form:GetCurrentRecipeLevel(), GetAmount(page))
    if entry then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.modules.ShoppingListFrame:Show()
    end
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["SHOPPING_LIST_ADD"])
    GameTooltip:AddLine(L["SHOPPING_LIST_ADD_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:AddLine(L["SHOPPING_LIST_OPEN_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
end

local function CreateButton(page)
    button = CreateFrame("Button", nil, page)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Follows "Create" when Blizzard moves it (minimized window, gamepad layout).
    button:SetPoint("RIGHT", page.CreateButton, "LEFT", BUTTON_GAP, 0)
    button:SetNormalTexture(ICON)
    button:SetPushedTexture(ICON)
    button:GetPushedTexture():SetVertexColor(0.7, 0.7, 0.7)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- Cuts off the icon's own border, the frame below draws one.
    button:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:GetPushedTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", -BUTTON_SIZE * 0.4, BUTTON_SIZE * 0.4)
    border:SetPoint("BOTTOMRIGHT", BUTTON_SIZE * 0.4, -BUTTON_SIZE * 0.4)

    -- A plus in the corner tells it apart from the open button next to the link button: it adds.
    local plus = button:CreateTexture(nil, "OVERLAY", nil, 1)
    plus:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    plus:SetSize(PLUS_SIZE, PLUS_SIZE)
    plus:SetPoint("BOTTOMRIGHT", 4, -4)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
end

-- Right of the chat link button. A child of the skill bar, so it is hidden with it (minimized
-- window, professions without a skill bar) like the link button.
local function CreateOpenButton(page)
    openButton = ns.modules.ShoppingListFrame:CreateToggleButton(page.RankBar)
    openButton:SetPoint("LEFT", page.LinkButton, "RIGHT", 2, 0)
end

local function Setup()
    local page = GetCraftingPage()
    if button or not page then
        return
    end
    CreateButton(page)
    CreateOpenButton(page)
    hooksecurefunc(page.SchematicForm, "Init", UpdateButton)
    UpdateButton()
    ns.modules.ShoppingListFrame:AttachToProfessions(ProfessionsFrame)
end

function ProfessionsButton:OnEnable()
    if C_AddOns.IsAddOnLoaded(PROFESSIONS_ADDON) then
        Setup()
    else
        ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
            if loadedName == PROFESSIONS_ADDON then
                Setup()
            end
        end)
    end
end

-- What a click on a recipe of the shopping list does in the profession window, for the logged-in
-- character's own recipes (entry.crafter, see ShoppingList):
--   "open"    profession window closed: opens it at the recipe
--   "select"  window open, another recipe selected: selects the recipe
--   "craft"   the recipe is selected: crafts it, as many times as the list wants and the reagents
--             allow (count, may be 0)
-- nil for recipes of other characters or a profession the character does not have. Selecting goes
-- through C_TradeSkillUI.OpenRecipe like Blizzard's recipe tracker, whose response Blizzard's own
-- event handler applies; crafting calls C_TradeSkillUI.CraftRecipe directly. Blizzard's controls
-- are not clicked or changed.
function ProfessionsButton:GetRecipeAction(entry)
    local playerName = ns.modules.Characters:GetPlayerName()
    if (entry.crafter and entry.crafter ~= playerName)
            or not C_TradeSkillUI.IsRecipeProfessionLearned(entry.recipeID) then
        return nil
    end
    if not (ProfessionsFrame and ProfessionsFrame:IsShown() and ns.modules.Professions:IsOwnTradeSkill()) then
        return "open"
    end
    local selected = GetCraftingPage().SchematicForm:GetRecipeInfo()
    if not (selected and selected.recipeID == entry.recipeID) then
        return "select"
    end
    local craftable = C_TradeSkillUI.GetCraftableCount(entry.recipeID, entry.recipeLevel) or 0
    return "craft", math.min(entry.count, craftable)
end

function ProfessionsButton:DoRecipeAction(entry)
    local action, count = self:GetRecipeAction(entry)
    if action == "open" or action == "select" then
        C_TradeSkillUI.OpenRecipe(entry.recipeID)
    elseif action == "craft" then
        if count > 0 then
            C_TradeSkillUI.CraftRecipe(entry.recipeID, count, nil, entry.recipeLevel)
        else
            ns:Print(L["SHOPPING_LIST_CANNOT_CRAFT"], entry.name)
        end
    end
    return action ~= nil
end
