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
    "C_ClassColor",
    "C_GameRules",
    "Constants",
    "Enum",
    "GetProfessionInfo",
    "GetProfessions",
    "GetRealmName",
    "UnitClass",
    "UnitFactionGroup",
    "UnitName",
    "C_CurrencyInfo",
    "C_Item",
    "C_TradeSkillUI",
    "C_Timer",
    "CreateFrame",
    "GetLocale",
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "InCombatLockdown",
    "IsModifiedClick",
    "IsShiftKeyDown",
    "HandleModifiedItemClick",
    "PlaySound",

    -- UI helpers
    "Settings",
    "ProfessionsUtil",
    "GameTooltip_Hide",

    -- Frames
    "DEFAULT_CHAT_FRAME",
    "UIParent",
    "GameTooltip",
    "ProfessionsFrame",
    "AuctionHouseFrame",
    "Syndicator",

    -- Constants and global strings
    "SOUNDKIT",
    "ITEM_QUALITY_COLORS",
    "RETRIEVING_ITEM_INFO",
    "GREEN_FONT_COLOR",
    "LIGHTBLUE_FONT_COLOR",
    "RED_FONT_COLOR",
    "GRAY_FONT_COLOR",
    "NORMAL_FONT_COLOR",
    "QUESTION_MARK_ICON",
}
