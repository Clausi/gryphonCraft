local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonCraft) as a vertical list.
-- The settings stay in ns.db and ns.charDb; proxy settings read and write them there.

local category

-- Proxy setting variables must be unique among all settings of the game and addons.
local function RegisterProxySetting(variable, varType, name, defaultValue, getValue, setValue)
    return Settings.RegisterProxySetting(category, "GRYPHONCRAFT_" .. variable, varType, name, defaultValue,
        getValue, setValue)
end

local function RegisterSettings()
    local notifications = RegisterProxySetting("NOTIFICATIONS", Settings.VarType.Boolean,
        L["OPTIONS_NOTIFICATIONS"], ns.charDefaults.notifications,
        function()
            return ns.charDb.notifications
        end,
        function(value)
            ns.charDb.notifications = value
        end)
    Settings.CreateCheckbox(category, notifications, L["OPTIONS_NOTIFICATIONS_TOOLTIP"])

    local ShoppingListFrame = ns.modules.ShoppingListFrame
    local dock = RegisterProxySetting("SHOPPING_LIST_DOCK", Settings.VarType.String,
        L["OPTIONS_SHOPPING_LIST_DOCK"], ns.defaults.shoppingListDock,
        function()
            return ShoppingListFrame:GetDock()
        end,
        function(value)
            ShoppingListFrame:SetDock(value)
        end)
    local function GetDockOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(ShoppingListFrame.DOCK_RIGHT, L["OPTIONS_SHOPPING_LIST_DOCK_RIGHT"])
        container:Add(ShoppingListFrame.DOCK_BOTTOM, L["OPTIONS_SHOPPING_LIST_DOCK_BOTTOM"])
        container:Add(ShoppingListFrame.DOCK_NONE, L["OPTIONS_SHOPPING_LIST_DOCK_NONE"])
        return container:GetData()
    end
    Settings.CreateDropdown(category, dock, GetDockOptions, L["OPTIONS_SHOPPING_LIST_DOCK_TOOLTIP"])

    local AuctionHouseButton = ns.modules.AuctionHouseButton
    local auctionHouseButton = RegisterProxySetting("AUCTION_HOUSE_BUTTON", Settings.VarType.Boolean,
        L["OPTIONS_AUCTION_HOUSE_BUTTON"], ns.defaults.auctionHouseButton,
        function()
            return AuctionHouseButton:IsEnabled()
        end,
        function(value)
            AuctionHouseButton:SetEnabled(value)
        end)
    Settings.CreateCheckbox(category, auctionHouseButton, L["OPTIONS_AUCTION_HOUSE_BUTTON_TOOLTIP"])
end

function Options:OnInitialize()
    category = Settings.RegisterVerticalLayoutCategory(ns.name)
    RegisterSettings()
    Settings.RegisterAddOnCategory(category)
end

-- "/gryphoncraft options" opens the options page. Opening it from addon code is blocked in combat
-- (ADDON_ACTION_BLOCKED for OpenSettingsPanel); Esc > Options still works there.
ns:RegisterCommand("options", function()
    if InCombatLockdown() then
        ns:Print(L["OPTIONS_IN_COMBAT"])
        return
    end
    Settings.OpenToCategory(category:GetID())
end, { L["HELP_OPTIONS"] })
