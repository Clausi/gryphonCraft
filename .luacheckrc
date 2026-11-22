-- luacheck configuration for GryphonCraft (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = 120
exclude_files = { ".tools/" }

-- Methods defined with ":" do not have to use the implicit self.
self = false

-- Globals the addon defines.
globals = {
    "GryphonCraftDB",
    "GryphonCraftCharDB",
    "SLASH_GRYPHONCRAFT1",
    "SlashCmdList",
}

-- WoW API and Blizzard UI globals the addon reads. Add new ones here when used.
read_globals = {
    -- WoW Lua extensions
    "format",
    "floor",
    "strtrim",
    "issecretvalue",
    "hooksecurefunc",
    "wipe",

    -- API
    "C_AddOns",
    "C_Timer",
    "CreateFrame",
    "GetLocale",
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "InCombatLockdown",

    -- UI helpers
    "Settings",

    -- Frames
    "DEFAULT_CHAT_FRAME",
    "UIParent",
}
