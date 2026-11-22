local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters, like GryphonMail's Modules/Characters.lua. There is no
-- API listing them, so every character is recorded on login in ns.db.characters, keyed by full
-- name ("Tor Donnerstein"):
--   { class, faction, realm, ruleset, professions }
-- professions is filled by Modules/Professions.lua and kept when the character is recorded again.
--
-- Items can only go between characters of the same faction and ruleset by mail (Forever has one
-- mega server per ruleset: PvE, PvP, RP, RP PvP, hardcore), see Characters:CanTrade().
local Characters = ns:RegisterModule("Characters")

-- The logged-in character, read once on login: { name, faction, realm, ruleset }.
local player
local characterList
local listeners = {}

local FACTION_LABELS = {
    Alliance = L["FACTION_ALLIANCE"],
    Horde = L["FACTION_HORDE"],
    Neutral = L["FACTION_NEUTRAL"],
}

-- Minimap mailbox tracking icon at line height, marks trade partners in "/gryphoncraft chars".
local MAIL_TARGET_ICON = "|TInterface\\Minimap\\Tracking\\Mailbox:0|t"

local function InvalidateCaches()
    characterList = nil
    for _, callback in ipairs(listeners) do
        callback()
    end
end

-- Ruleset of the logged-in character from its game rules: "PvE", "PvP", "RP", "RPPvP" or "HC"
-- (hardcore); nil without the ruleset game rules. Since Forever build 71037 the only way to tell
-- the ruleset: GetRealmName() returns "" (as in GryphonMail's Compat.GetRuleset).
local function GetPlayerRuleset()
    local rules = Enum.GameRule
    if not (C_GameRules and rules and rules.PvPRuleset and rules.RPRuleset) then
        return nil
    end
    local isPvP = C_GameRules.IsGameRuleActive(rules.PvPRuleset)
    local isRP = C_GameRules.IsGameRuleActive(rules.RPRuleset)
    if isPvP and isRP then
        return "RPPvP"
    elseif isPvP then
        return "PvP"
    elseif isRP then
        return "RP"
    elseif rules.HardcoreRuleset and C_GameRules.IsGameRuleActive(rules.HardcoreRuleset) then
        return "HC"
    end
    return "PvE"
end

-- Ruleset from a Forever realm name ("CAMWOW US1 Realm 10 RP" -> "RP"), for characters recorded
-- before the game rules were used. See GetRulesetName in GryphonMail's Modules/Characters.lua.
local function GetRulesetName(realm)
    if type(realm) ~= "string" or realm == "" then
        return nil
    end
    local name = realm:match("Realm%s*%d+%s*(.-)%s*$") or realm:match("(%S+)%s*$")
    return name ~= "" and name or nil
end

local function GetRuleset(ruleset, realm)
    return ruleset or GetRulesetName(realm)
end

-- Comparable form: case and spaces differ between realm names and game rules ("RP PvP", "RPPvP").
local function GetRulesetKey(ruleset, realm)
    local name = GetRuleset(ruleset, realm)
    return name and (name:lower():gsub("%s+", ""))
end

local function GetSortedNames()
    local names = {}
    for fullName in pairs(ns.db.characters) do
        names[#names + 1] = fullName
    end
    table.sort(names)
    return names
end

local function ColorizeName(fullName)
    local info = ns.db.characters[fullName]
    local color = info and info.class and C_ClassColor.GetClassColor(info.class)
    return color and color:WrapTextInColorCode(fullName) or fullName
end

-- A number from the list, a full name or a unique first name, case-insensitive.
local function FindCharacter(input)
    local names = GetSortedNames()
    local number = tonumber(input)
    if number then
        return names[number]
    end
    local wanted = input:lower()
    local firstNameMatch
    local firstNameMatches = 0
    for _, fullName in ipairs(names) do
        if fullName:lower() == wanted then
            return fullName
        end
        if Names.GetFirstName(fullName):lower() == wanted then
            firstNameMatch = fullName
            firstNameMatches = firstNameMatches + 1
        end
    end
    return firstNameMatches == 1 and firstNameMatch or nil
end

local function ListCharacters()
    local characters = Characters:GetCharacters()
    if #characters == 0 then
        ns:Print(L["CHARS_EMPTY"])
        return
    end
    ns:Print(L["CHARS_HEADER"], MAIL_TARGET_ICON)
    for i, character in ipairs(characters) do
        local line = Characters:FormatCharacter(character)
        if character.canTrade and not character.isCurrent then
            line = MAIL_TARGET_ICON .. " " .. line
        end
        local professions = ns.modules.Professions:FormatProfessions(character.fullName)
        if professions then
            line = line .. ": " .. professions
        end
        ns:Print(("%d. %s"):format(i, line))
    end
end

local function RemoveCharacter(input)
    if input == "" then
        ns:Print(L["HELP_CHARS_REMOVE"])
        return
    end
    local fullName = FindCharacter(input)
    if not fullName then
        ns:Print(L["CHARS_NOT_FOUND"], input)
        return
    end
    Characters:Remove(fullName)
end

-- Reads the logged-in character and records it, keeping its recorded professions.
local function RecordPlayer()
    local fullName = Names.GetPlayerName()
    if not fullName then
        return
    end
    local stored = ns.db.characters[fullName] or {}
    -- Forever returns "" since build 71037; the realm recorded before still names the ruleset.
    local realm = GetRealmName()
    if realm == "" then
        realm = stored.realm ~= "" and stored.realm or nil
    end
    player = {
        name = fullName,
        faction = UnitFactionGroup("player"),
        realm = realm,
        ruleset = GetPlayerRuleset(),
    }
    local _, classFile = UnitClass("player")
    stored.class = classFile
    stored.faction = player.faction
    stored.realm = player.realm
    stored.ruleset = player.ruleset
    stored.professions = stored.professions or {}
    ns.db.characters[fullName] = stored
    InvalidateCaches()
end

function Characters:OnInitialize()
    ns:RegisterCommand("chars", function(args)
        local action, rest = args:match("^(%S*)%s*(.-)$")
        if action:lower() == "remove" then
            RemoveCharacter(rest)
        else
            ListCharacters()
        end
    end, { L["HELP_CHARS"], L["HELP_CHARS_REMOVE"] })

    -- A Pandaren picks a faction during the session.
    ns:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT", RecordPlayer)
end

function Characters:OnEnable()
    RecordPlayer()
end

-- Full name of the logged-in character, nil before login.
function Characters:GetPlayerName()
    return player and player.name
end

-- The stored record of the logged-in character, nil before login.
function Characters:GetPlayerRecord()
    return player and ns.db.characters[player.name]
end

-- True if items can go between the logged-in character and the stored one: the character itself,
-- or one of the same faction and ruleset (mail).
function Characters:CanTrade(fullName)
    if not player then
        return false
    end
    if fullName == player.name then
        return true
    end
    local info = ns.db.characters[fullName]
    if not info or info.faction ~= player.faction then
        return false
    end
    local key = GetRulesetKey(info.ruleset, info.realm)
    return key ~= nil and key == GetRulesetKey(player.ruleset, player.realm)
end

-- callback() runs after the stored characters or the logged-in character changed.
function Characters:OnUpdate(callback)
    listeners[#listeners + 1] = callback
end

-- The known characters, sorted by name. Cached, must not be modified:
--   { fullName, class, faction, ruleset, isCurrent, canTrade }
function Characters:GetCharacters()
    if characterList then
        return characterList
    end
    characterList = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        characterList[#characterList + 1] = {
            fullName = fullName,
            class = info.class,
            faction = info.faction,
            ruleset = GetRuleset(info.ruleset, info.realm),
            isCurrent = player ~= nil and fullName == player.name,
            canTrade = self:CanTrade(fullName),
        }
    end
    return characterList
end

-- Class-colored name, "(ruleset, faction)" in gray and "(current)".
function Characters:FormatCharacter(character)
    local line = ColorizeName(character.fullName)
    local details = {}
    details[#details + 1] = character.ruleset
    details[#details + 1] = FACTION_LABELS[character.faction] or character.faction
    if #details > 0 then
        line = line .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. table.concat(details, ", ") .. ")")
    end
    if character.isCurrent then
        line = line .. " " .. L["CHARS_CURRENT"]
    end
    return line
end

-- Class-colored name of a stored character.
function Characters:ColorizeName(fullName)
    return ColorizeName(fullName)
end

-- Forgets a stored character, not the logged-in one. Returns true if it was removed.
function Characters:Remove(fullName)
    if player and fullName == player.name then
        ns:Print(L["CHARS_REMOVE_CURRENT"])
        return false
    end
    if not ns.db.characters[fullName] then
        return false
    end
    local coloredName = ColorizeName(fullName)
    ns.db.characters[fullName] = nil
    InvalidateCaches()
    ns:Print(L["CHARS_REMOVED"], coloredName)
    return true
end
