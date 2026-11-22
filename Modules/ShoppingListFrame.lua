local _, ns = ...
local L = ns.L

-- Window of the shopping list: the recipes with an editable number of crafts, and below the
-- reagents they need in total with how many the character has ("owned/needed", green when
-- enough). Opened by the button in the profession window or "/gryphoncraft list".
--
-- Looks like the profession window (ButtonFrameTemplate, the same portrait frame). It is docked to
-- the right of or below the profession window while that is shown (ns.db.shoppingListDock), only
-- through anchors of the own frame: Blizzard's frame is not changed. Undocked or without the
-- profession window it is movable, the position is saved in ns.db.shoppingListPosition.
local ShoppingListFrame = ns:RegisterModule("ShoppingListFrame")

ShoppingListFrame.DOCK_RIGHT = "RIGHT"
ShoppingListFrame.DOCK_BOTTOM = "BOTTOM"
ShoppingListFrame.DOCK_NONE = "NONE"

local WIDTH, HEIGHT, DOCKED_BOTTOM_HEIGHT = 320, 420, 280
-- Docked right: past the profession tabs on the right edge of the profession window. Docked
-- below: leaves room for the portrait, which reaches above the frame.
local DOCK_RIGHT_OFFSET, DOCK_BOTTOM_OFFSET = 60, -16
local INSET_PADDING = 6
local SCROLL_BAR_SPACE = 20
local ROW_HEIGHT, ICON_SIZE = 20, 18
local SECTION_SPACING = 8
local REFRESH_DELAY = 0.2
local DEFAULT_POSITION = { point = "CENTER", x = 420, y = 0 }
-- Toggle button, like Blizzard's chat link button next to the profession skill bar.
local OPEN_BUTTON_SIZE, OPEN_ICON_SIZE = 23, 15

local ShoppingList = ns.modules.ShoppingList

local window, content, professionsFrame
-- The window was open when the profession window closed; it opens again with it.
local reopenWithProfessions = false
local recipeRows, reagentRows = {}, {}
local CreateCraftButton
local refreshPending = false

local function HideTooltip()
    GameTooltip:Hide()
end

-- Name of a reagent in its quality color; nil while the item is not cached yet (it is requested,
-- GET_ITEM_INFO_RECEIVED refreshes the window).
local function GetReagentDisplay(option)
    if option.currencyID then
        local info = C_CurrencyInfo.GetCurrencyInfo(option.currencyID)
        return info and info.name, info and info.iconFileID
    end
    local name = C_Item.GetItemNameByID(option.itemID)
    local icon = C_Item.GetItemIconByID(option.itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(option.itemID)
        return nil, icon
    end
    local quality = C_Item.GetItemQualityByID(option.itemID)
    local color = quality and ITEM_QUALITY_COLORS[quality]
    return color and color.color:WrapTextInColorCode(name) or name, icon
end

local function CreateIcon(row)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT")
end

local function CreateName(row, rightAnchor)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
    row.Name:SetPoint("RIGHT", rightAnchor, "LEFT", -6, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
end

local function ApplyCount(editBox)
    local row = editBox:GetParent()
    if row.entry then
        ShoppingList:SetCount(row.entry, editBox:GetNumber())
    end
end

local SHIFT_STEP = 10

-- Tooltip of the item the recipe makes; the recipe spell for recipes without an item (entries
-- saved before the output item was stored, or recipes without one).
local function ShowRecipeTooltip(self)
    local entry = self.entry
    if not entry then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if entry.outputItemID then
        GameTooltip:SetItemByID(entry.outputItemID)
    else
        GameTooltip:SetSpellByID(entry.recipeID)
    end
    GameTooltip:Show()
end

-- Shift-click links the item in chat, Ctrl-click shows it in the dressing room.
local function OnRecipeClick(self)
    local itemID = self.entry and self.entry.outputItemID
    if itemID and IsModifiedClick() then
        local link = select(2, C_Item.GetItemInfo(itemID))
        if link then
            HandleModifiedItemClick(link)
        end
    end
end

local function ShowStepTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.step > 0 and L["SHOPPING_LIST_INCREASE"] or L["SHOPPING_LIST_DECREASE"])
    GameTooltip:AddLine(format(L["SHOPPING_LIST_STEP_SHIFT"], SHIFT_STEP), 1, 1, 1, true)
    GameTooltip:Show()
end

-- "+" and "-" next to the number of crafts; Shift changes it by SHIFT_STEP. "-" stops at 1, the X
-- removes the recipe.
local function CreateStepButton(row, step, texture)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(16, 16)
    button.step = step
    button:SetNormalTexture(texture .. "-Up")
    button:SetPushedTexture(texture .. "-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    button:SetScript("OnClick", function(self)
        local entry = self:GetParent().entry
        if not entry then
            return
        end
        local amount = IsShiftKeyDown() and SHIFT_STEP or 1
        ShoppingList:SetCount(entry, math.max(1, entry.count + self.step * amount))
    end)
    button:SetScript("OnEnter", ShowStepTooltip)
    button:SetScript("OnLeave", HideTooltip)
    return button
end

local function GetRecipeRow(index)
    local row = recipeRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    CreateIcon(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", ShowRecipeTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnClick", OnRecipeClick)

    row.Remove = CreateFrame("Button", nil, row)
    row.Remove:SetSize(16, 16)
    row.Remove:SetPoint("RIGHT")
    row.Remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    row.Remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
    row.Remove:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
    row.Remove:SetScript("OnClick", function(self)
        ShoppingList:Remove(self:GetParent().entry)
    end)
    row.Remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SHOPPING_LIST_REMOVE"])
        GameTooltip:Show()
    end)
    row.Remove:SetScript("OnLeave", HideTooltip)

    row.Plus = CreateStepButton(row, 1, "Interface\\Buttons\\UI-PlusButton")
    row.Plus:SetPoint("RIGHT", row.Remove, "LEFT", -6, 0)

    row.Count = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.Count:SetSize(40, ROW_HEIGHT)
    row.Count:SetPoint("RIGHT", row.Plus, "LEFT", -4, 0)
    row.Count:SetAutoFocus(false)
    row.Count:SetNumeric(true)
    row.Count:SetMaxLetters(4)
    row.Count:SetJustifyH("RIGHT")
    -- InputBoxTemplate draws its right border inside the edit box (its left one 5 px outside), so
    -- right-aligned text needs room for it.
    row.Count:SetTextInsets(0, 8, 0, 0)
    row.Count:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    row.Count:SetScript("OnEscapePressed", function(self)
        -- Back to the saved number without applying the input.
        self:SetNumber(self:GetParent().entry.count)
        self:ClearFocus()
    end)
    row.Count:SetScript("OnEditFocusLost", ApplyCount)
    row.Count:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SHOPPING_LIST_COUNT_TOOLTIP"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row.Count:SetScript("OnLeave", HideTooltip)

    -- The edit box border reaches 5 px out to the left.
    row.Minus = CreateStepButton(row, -1, "Interface\\Buttons\\UI-MinusButton")
    row.Minus:SetPoint("RIGHT", row.Count, "LEFT", -9, 0)

    CreateName(row, row.Minus)
    recipeRows[index] = row
    return row
end

-- Searches the item in the open auction house, the way Blizzard's profession window does it for
-- reagents with a gamepad (Blizzard_ProfessionsFrame.lua): the name into the search box, then a
-- click on its search button.
local function SearchAuctionHouse(itemID)
    if not (AuctionHouseFrame and AuctionHouseFrame:IsVisible()) then
        ns:Print(L["SHOPPING_LIST_AH_CLOSED"])
        return
    end
    local name = C_Item.GetItemInfo(itemID)
    if name and AuctionHouseFrame:SetSearchText(name) then
        AuctionHouseFrame.SearchBar.SearchButton:Click()
    end
end

local function ShowCrafterTooltip(self)
    local total = self:GetParent().total
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOPPING_LIST_CRAFTERS"])
    for _, crafter in ipairs(total.crafters) do
        local recipe = C_TradeSkillUI.GetRecipeSchematic(crafter.recipeID, false)
        GameTooltip:AddDoubleLine(ns.modules.Characters:ColorizeName(crafter.fullName),
            format("%s (%s)", recipe and recipe.name or "?", crafter.professionName or "?"),
            nil, nil, nil, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(format(L["SHOPPING_LIST_CRAFT_HINT"],
        ns.modules.Characters:ColorizeName(total.crafters[1].fullName)), GREEN_FONT_COLOR:GetRGB())
    GameTooltip:Show()
end

-- Profession icon on reagents an own character can craft: adds that recipe to the list.
CreateCraftButton = function(row)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", ShowCrafterTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnClick", function(self)
        local total = self:GetParent().total
        if total and total.crafters[1] then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ShoppingList:AddCraft(total.crafters[1], total.missing)
        end
    end)
    return button
end

local function GetReagentRow(index)
    local row = reagentRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    CreateIcon(row)
    row.Count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Count:SetPoint("RIGHT")
    row.Craft = CreateCraftButton(row)
    row.Craft:SetPoint("RIGHT", row.Count, "LEFT", -6, 0)
    CreateName(row, row.Craft)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", function(self)
        local option = self.option
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if option.currencyID then
            GameTooltip:SetCurrencyByID(option.currencyID)
        else
            GameTooltip:SetItemByID(option.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["SHOPPING_LIST_SEARCH_HINT"], GREEN_FONT_COLOR:GetRGB())
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", HideTooltip)
    -- Click searches the auction house while it is open. Shift-click links the item in chat (with
    -- the auction house open, Blizzard puts it into its search box), Ctrl-click shows it in the
    -- dressing room.
    row:SetScript("OnClick", function(self)
        local itemID = self.option.itemID
        if not itemID then
            return
        end
        if IsModifiedClick() then
            local link = select(2, C_Item.GetItemInfo(itemID))
            if link then
                HandleModifiedItemClick(link)
            end
        else
            SearchAuctionHouse(itemID)
        end
    end)
    reagentRows[index] = row
    return row
end

local function PlaceRow(row, offset)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -offset)
    row:SetPoint("TOPRIGHT", 0, -offset)
    row:Show()
    return offset + ROW_HEIGHT
end

local function PlaceHeader(header, offset)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 0, -offset)
    header:Show()
    return offset + header:GetStringHeight() + 4
end

-- "owned/needed", "+planned" for what recipes on the list craft of it.
local function FormatCount(total)
    local text = format("%d/%d", total.owned, total.needed)
    local color = total.missing == 0 and GREEN_FONT_COLOR or RED_FONT_COLOR
    text = color:WrapTextInColorCode(text)
    if total.planned > 0 then
        text = text .. " " .. NORMAL_FONT_COLOR:WrapTextInColorCode(format("+%d", total.planned))
    end
    return text
end

local function Refresh()
    refreshPending = false
    if not (window and window:IsShown()) then
        return
    end

    local entries = ShoppingList:GetEntries()
    local offset = 0
    offset = PlaceHeader(window.RecipesHeader, offset)
    for index, entry in ipairs(entries) do
        local row = GetRecipeRow(index)
        row.entry = entry
        row.Icon:SetTexture(entry.icon)
        if entry.crafter then
            row.Name:SetText(entry.name .. " " .. ns.modules.Characters:ColorizeName(entry.crafter))
        else
            row.Name:SetText(entry.name)
        end
        if not row.Count:HasFocus() then
            row.Count:SetNumber(entry.count)
        end
        offset = PlaceRow(row, offset)
    end
    for index = #entries + 1, #recipeRows do
        recipeRows[index]:Hide()
        recipeRows[index].entry = nil
    end

    local totals = ShoppingList:GetReagentTotals()
    local missing = 0
    if #totals > 0 then
        offset = PlaceHeader(window.ReagentsHeader, offset + SECTION_SPACING)
    else
        window.ReagentsHeader:Hide()
    end
    for index, total in ipairs(totals) do
        local row = GetReagentRow(index)
        local option = total.options[1]
        local name, icon = GetReagentDisplay(option)
        row.option = option
        row.total = total
        row.Icon:SetTexture(icon)
        row.Name:SetText(name or RETRIEVING_ITEM_INFO)
        row.Count:SetText(FormatCount(total))
        local crafter = total.crafters[1]
        row.Craft:SetShown(crafter ~= nil)
        row.Craft:SetWidth(crafter and ICON_SIZE or 1)
        if crafter then
            row.Craft:SetNormalTexture(crafter.professionIcon or QUESTION_MARK_ICON)
        end
        if total.missing > 0 then
            missing = missing + 1
        end
        offset = PlaceRow(row, offset)
    end
    for index = #totals + 1, #reagentRows do
        reagentRows[index]:Hide()
    end

    content:SetHeight(math.max(offset, 1))
    window.Empty:SetShown(#entries == 0)
    window.Clear:SetEnabled(#entries > 0)
    if #totals == 0 then
        window.Summary:SetText("")
    elseif missing == 0 then
        window.Summary:SetText(GREEN_FONT_COLOR:WrapTextInColorCode(L["SHOPPING_LIST_COMPLETE"]))
    else
        window.Summary:SetText(format(L["SHOPPING_LIST_MISSING"], missing, #totals))
    end
end

-- Bag and item events come in bursts; one refresh shortly after is enough.
local function ScheduleRefresh()
    if refreshPending or not (window and window:IsShown()) then
        return
    end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, Refresh)
end


local function GetDock()
    return ns.db.shoppingListDock
end

local function IsDocked()
    return GetDock() ~= ShoppingListFrame.DOCK_NONE and professionsFrame ~= nil and professionsFrame:IsShown()
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    local position = ns.db.shoppingListPosition
    position.point, position.relativePoint, position.x, position.y = point, relativePoint, x, y
end

-- Anchors the window: docked to the profession window or at its saved position.
local function ApplyPosition()
    window:ClearAllPoints()
    local dock = GetDock()
    if IsDocked() and dock == ShoppingListFrame.DOCK_RIGHT then
        window:SetWidth(WIDTH)
        window:SetPoint("TOPLEFT", professionsFrame, "TOPRIGHT", DOCK_RIGHT_OFFSET, 0)
        window:SetPoint("BOTTOMLEFT", professionsFrame, "BOTTOMRIGHT", DOCK_RIGHT_OFFSET, 0)
    elseif IsDocked() and dock == ShoppingListFrame.DOCK_BOTTOM then
        window:SetHeight(DOCKED_BOTTOM_HEIGHT)
        window:SetPoint("TOPLEFT", professionsFrame, "BOTTOMLEFT", 0, DOCK_BOTTOM_OFFSET)
        window:SetPoint("TOPRIGHT", professionsFrame, "BOTTOMRIGHT", 0, DOCK_BOTTOM_OFFSET)
    else
        local position = ns.db.shoppingListPosition
        if not position.point then
            position = DEFAULT_POSITION
        end
        window:SetSize(WIDTH, HEIGHT)
        window:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x, position.y)
    end
end

local function OnDragStart(self)
    if not IsDocked() then
        self:StartMoving()
    end
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    if not IsDocked() then
        SavePosition()
    end
end

local function CreateWindow()
    -- The same frame template and art as the profession window (portrait, title, close button,
    -- inset). Not a UI panel: it is not shown through ShowUIPanel.
    window = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", OnDragStart)
    window:SetScript("OnDragStop", OnDragStop)
    window:SetScript("OnShow", Refresh)
    window:Hide()
    window:SetTitle(L["SHOPPING_LIST_TITLE"])
    window:SetPortraitToAsset(ShoppingList.ICON)
    -- The template's close button goes through the panel manager (HideParentPanel), which is
    -- blocked in combat for addon frames. This is the own frame's button, so its script is replaced.
    window.CloseButton:SetScript("OnClick", function()
        window:Hide()
    end)

    local inset = window.Inset
    local scrollFrame = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", INSET_PADDING, -INSET_PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE - INSET_PADDING, INSET_PADDING)
    scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
    end)

    window.RecipesHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    window.RecipesHeader:SetText(L["SHOPPING_LIST_RECIPES"])
    window.ReagentsHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    window.ReagentsHeader:SetText(L["SHOPPING_LIST_REAGENTS"])

    window.Empty = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    window.Empty:SetPoint("TOPLEFT", window.RecipesHeader, "BOTTOMLEFT", 0, -6)
    window.Empty:SetPoint("RIGHT")
    window.Empty:SetJustifyH("LEFT")
    window.Empty:SetText(L["SHOPPING_LIST_EMPTY"])

    -- Button bar below the inset, as in the profession window.
    window.Clear = CreateFrame("Button", nil, window, "SharedButtonSmallTemplate")
    window.Clear:SetSize(90, 22)
    window.Clear:SetPoint("BOTTOMRIGHT", -6, 3)
    window.Clear:SetText(L["SHOPPING_LIST_CLEAR"])
    window.Clear:SetScript("OnClick", function()
        ShoppingList:Clear()
    end)

    window.Summary = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    window.Summary:SetPoint("LEFT", window, "BOTTOMLEFT", 10, 14)
    window.Summary:SetPoint("RIGHT", window.Clear, "LEFT", -6, 0)
    window.Summary:SetJustifyH("LEFT")
    window.Summary:SetWordWrap(false)
end

local function OnProfessionsShow()
    if window and window:IsShown() then
        ApplyPosition()
    elseif reopenWithProfessions and GetDock() ~= ShoppingListFrame.DOCK_NONE then
        ShoppingListFrame:Show()
    end
    reopenWithProfessions = false
end

-- A docked window closes with the profession window and opens again with it.
local function OnProfessionsHide()
    if not (window and window:IsShown()) then
        return
    end
    if GetDock() == ShoppingListFrame.DOCK_NONE then
        return
    end
    reopenWithProfessions = true
    window:Hide()
end

function ShoppingListFrame:OnInitialize()
    ShoppingList:RegisterCallback(Refresh)
    ns.modules.Professions:OnUpdate(ScheduleRefresh)
    ns:RegisterEvent("BAG_UPDATE_DELAYED", ScheduleRefresh)
    ns:RegisterEvent("CURRENCY_DISPLAY_UPDATE", ScheduleRefresh)
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", ScheduleRefresh)
end

-- Called once Blizzard_Professions is loaded (Modules/ProfessionsButton.lua). HookScript only adds
-- own handlers after Blizzard's.
function ShoppingListFrame:AttachToProfessions(frame)
    if professionsFrame then
        return
    end
    professionsFrame = frame
    frame:HookScript("OnShow", OnProfessionsShow)
    frame:HookScript("OnHide", OnProfessionsHide)
    if window and window:IsShown() then
        ApplyPosition()
    end
end

local function SetOpenButtonState(self, state)
    local atlas = "common-button-tertiary-square-normal"
    if state == "pressed" then
        atlas = "common-button-tertiary-square-pressed"
    elseif state == "hover" then
        atlas = "common-button-tertiary-square-hover"
    end
    self.Background:SetAtlas(atlas)
end

local function OnOpenEnter(self)
    SetOpenButtonState(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(L["SHOPPING_LIST_TITLE"])
    GameTooltip:AddLine(L["SHOPPING_LIST_TOGGLE_TOOLTIP"], 1, 1, 1, true)
    GameTooltip:Show()
end

local function OnOpenLeave(self)
    SetOpenButtonState(self, "normal")
    GameTooltip_Hide()
end

-- Small button that opens or closes the shopping list, in the style of Blizzard's chat link button
-- next to the profession skill bar (ProfessionsLinkButtonMixin). The caller anchors it.
function ShoppingListFrame:CreateToggleButton(parent)
    local openButton = CreateFrame("Button", nil, parent)
    openButton:SetSize(OPEN_BUTTON_SIZE, OPEN_BUTTON_SIZE)
    openButton.Background = openButton:CreateTexture(nil, "BACKGROUND")
    openButton.Background:SetAllPoints()
    openButton.Icon = openButton:CreateTexture(nil, "ARTWORK")
    openButton.Icon:SetSize(OPEN_ICON_SIZE, OPEN_ICON_SIZE)
    openButton.Icon:SetPoint("CENTER")
    openButton.Icon:SetTexture(ShoppingList.ICON)
    openButton.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    SetOpenButtonState(openButton, "normal")
    openButton:SetScript("OnMouseDown", function(button)
        SetOpenButtonState(button, "pressed")
    end)
    openButton:SetScript("OnMouseUp", function(button)
        SetOpenButtonState(button, button:IsMouseOver() and "hover" or "normal")
    end)
    openButton:SetScript("OnEnter", OnOpenEnter)
    openButton:SetScript("OnLeave", OnOpenLeave)
    openButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ShoppingListFrame:Toggle()
    end)
    return openButton
end

function ShoppingListFrame:Show()
    if not window then
        CreateWindow()
    end
    ApplyPosition()
    window:Show()
end

function ShoppingListFrame:Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        self:Show()
    end
end

function ShoppingListFrame:GetDock()
    return GetDock()
end

function ShoppingListFrame:SetDock(dock)
    ns.db.shoppingListDock = dock
    if window and window:IsShown() then
        ApplyPosition()
    end
end
