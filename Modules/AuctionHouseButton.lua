local _, ns = ...

-- Button in Blizzard's auction house that opens or closes the shopping list: right of the search
-- box of the "Buy" page, a child of AuctionHouseFrame.SearchBar, so it is only shown with it.
-- Turned off with ns.db.auctionHouseButton (options).
--
-- Blizzard_AuctionHouseUI is load on demand. Only an own button is added; Blizzard's search bar,
-- its anchors and scripts are not changed.
local AuctionHouseButton = ns:RegisterModule("AuctionHouseButton")

local AUCTION_HOUSE_ADDON = "Blizzard_AuctionHouseUI"
-- Between the search box and the filter button.
local BUTTON_OFFSET = 10

local button

local function Setup()
    local searchBar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    if button or not searchBar then
        return
    end
    button = ns.modules.ShoppingListFrame:CreateToggleButton(searchBar)
    button:SetPoint("LEFT", searchBar.SearchBox, "RIGHT", BUTTON_OFFSET, 0)
    button:SetShown(ns.db.auctionHouseButton)
end

function AuctionHouseButton:OnEnable()
    if C_AddOns.IsAddOnLoaded(AUCTION_HOUSE_ADDON) then
        Setup()
    else
        ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
            if loadedName == AUCTION_HOUSE_ADDON then
                Setup()
            end
        end)
    end
end

function AuctionHouseButton:IsEnabled()
    return ns.db.auctionHouseButton
end

function AuctionHouseButton:SetEnabled(enabled)
    ns.db.auctionHouseButton = enabled
    if button then
        button:SetShown(enabled)
    end
end
