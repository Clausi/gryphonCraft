local addonName, ns = ...

-- Shared addon namespace. All files receive the same `ns` table via `...`.
ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version")
ns.modules = {}

-- Default values for the saved variables. Missing keys are filled in on load.
-- Account-wide (GryphonCraftDB, ns.db): settings and data shared by all characters.
ns.defaults = {
    debug = false,
    -- Own characters with their professions and craftable items, keyed by full name ("Name
    -- Surname"). Filled by Modules/Characters.lua and Modules/Professions.lua.
    characters = {},
    -- Position of the shopping list window (point, relativePoint, x, y), empty until it is moved.
    -- Set by Modules/ShoppingListFrame.lua.
    shoppingListPosition = {},
    -- Where the shopping list window docks to the profession window: "RIGHT", "BOTTOM" or "NONE".
    shoppingListDock = "NONE",
    -- Button in the auction house ("Buy" page) that opens the shopping list.
    auctionHouseButton = true,
}

-- Per character (GryphonCraftCharDB, ns.charDb): data and settings only the logged-in character needs.
ns.charDefaults = {
    -- Automatic messages (login, hints). Change with "/gryphoncraft notify on|off".
    notifications = true,
    -- Recipes on the shopping list, in the order they were added. Filled by Modules/ShoppingList.lua.
    shoppingList = {},
}

-- Registers a module. A module may implement:
--   module:OnInitialize()  -- called once after saved variables are loaded
--   module:OnEnable()      -- called on PLAYER_LOGIN
function ns:RegisterModule(name)
    local module = { name = name }
    self.modules[#self.modules + 1] = module
    self.modules[name] = module
    return module
end

-- Registers a "/gryphoncraft <name> ..." subcommand.
--   handler(args)  -- args: the rest of the input after the command name, trimmed
--   helpLines      -- user-facing help lines (already localized), shown by "/gryphoncraft"
ns.commands = {}

function ns:RegisterCommand(name, handler, helpLines)
    local command = { name = name, handler = handler, helpLines = helpLines or {} }
    self.commands[#self.commands + 1] = command
    self.commands[name] = command
end

-- Simple event dispatcher: ns:RegisterEvent("EVENT", function(event, ...) end)
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then
        return
    end
    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)

function ns:RegisterEvent(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], handler)
end
