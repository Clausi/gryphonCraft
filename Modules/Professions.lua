local _, ns = ...
local L = ns.L

-- Remembers the professions of the account's characters and which items each of them can craft,
-- in their record in ns.db.characters (Modules/Characters.lua):
--   professions = { [skillLineID] = { name, icon, rank, maxRank, crafts = { [itemID] = recipeID } } }
--
-- Name, icon and skill come from GetProfessions() on every login. The crafts of a profession are
-- read whenever its profession window is open (own professions only, not linked, guild or NPC
-- crafting lists). Recipes are only added: Blizzard's list honors the window's filters, so a scan
-- may not see every recipe. A profession the character no longer has is dropped on login.
local Professions = ns:RegisterModule("Professions")

local Characters = ns.modules.Characters

local SCAN_DELAY = 0.5

local scanPending = false
local listeners = {}

local function NotifyChanged()
    for _, callback in ipairs(listeners) do
        callback()
    end
end

local function GetPlayerProfessions()
    local record = Characters:GetPlayerRecord()
    return record and record.professions
end

-- The stored profession for the open profession window: by skill line, or else by name (in case
-- the window's profession ID differs from the skill line of GetProfessions()).
local function FindProfession(professions, professionID, name)
    if professions[professionID] then
        return professions[professionID]
    end
    for _, profession in pairs(professions) do
        if profession.name == name then
            return profession
        end
    end
end

-- Name, icon and skill of the current professions; drops the ones the character no longer has.
local function RecordProfessions()
    local professions = GetPlayerProfessions()
    if not professions then
        return
    end
    local current, currentNames = {}, {}
    for _, index in pairs({ GetProfessions() }) do
        local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
        if skillLine and name then
            local profession = FindProfession(professions, skillLine, name) or { crafts = {} }
            profession.name, profession.icon = name, icon
            profession.rank, profession.maxRank = rank, maxRank
            profession.crafts = profession.crafts or {}
            professions[skillLine] = profession
            current[skillLine] = true
            currentNames[name] = true
        end
    end
    for skillLine, profession in pairs(professions) do
        if not current[skillLine] and not currentNames[profession.name] then
            professions[skillLine] = nil
        end
    end
    NotifyChanged()
end

-- The open profession window shows the character's own list (not another player's, the guild's
-- or an NPC's).
local function IsOwnTradeSkill()
    return not (C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild()
        or C_TradeSkillUI.IsTradeSkillGuildMember() or C_TradeSkillUI.IsNPCCrafting())
end

local function ScanRecipes()
    scanPending = false
    local professions = GetPlayerProfessions()
    if not professions or not IsOwnTradeSkill() then
        return
    end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if not info or not info.professionID or info.professionID == 0 then
        return
    end
    local profession = FindProfession(professions, info.professionID, info.professionName)
    if not profession then
        return
    end

    local known = {}
    for _, recipeID in pairs(profession.crafts) do
        known[recipeID] = true
    end
    local added = 0
    for _, recipeID in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs()) do
        if not known[recipeID] then
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if recipeInfo and recipeInfo.learned and not recipeInfo.isDummyRecipe and not recipeInfo.isGatheringRecipe
                    and not recipeInfo.isRecraft and not recipeInfo.isSalvageRecipe then
                local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
                local itemID = schematic and schematic.outputItemID
                if itemID and not profession.crafts[itemID] then
                    profession.crafts[itemID] = recipeID
                    added = added + 1
                end
            end
        end
    end
    if added > 0 then
        ns:Debug("Recorded %d recipes of %s", added, profession.name)
        NotifyChanged()
    end
end

-- The list updates in bursts (filters, crafting); one scan shortly after is enough.
local function ScheduleScan()
    if not scanPending then
        scanPending = true
        C_Timer.After(SCAN_DELAY, ScanRecipes)
    end
end

function Professions:OnInitialize()
    ns:RegisterEvent("TRADE_SKILL_LIST_UPDATE", ScheduleScan)
    ns:RegisterEvent("NEW_RECIPE_LEARNED", ScheduleScan)
    ns:RegisterEvent("SKILL_LINES_CHANGED", RecordProfessions)
end

function Professions:OnEnable()
    RecordProfessions()
end

-- True while the profession window shows the logged-in character's own list.
function Professions:IsOwnTradeSkill()
    return IsOwnTradeSkill()
end

-- callback() runs after professions or crafts changed.
function Professions:OnUpdate(callback)
    listeners[#listeners + 1] = callback
end

-- Characters that can craft one of the items (itemIDs as keys or list) and can send it to the
-- logged-in character (Characters:CanTrade), the logged-in character first:
--   { { fullName, isCurrent, recipeID, itemID, professionName, professionIcon }, ... }
function Professions:GetCrafters(itemIDs)
    local result = {}
    local playerName = Characters:GetPlayerName()
    for _, character in ipairs(Characters:GetCharacters()) do
        local info = ns.db.characters[character.fullName]
        if character.canTrade and info.professions then
            for _, profession in pairs(info.professions) do
                for _, itemID in ipairs(itemIDs) do
                    local recipeID = profession.crafts and profession.crafts[itemID]
                    if recipeID then
                        result[#result + 1] = {
                            fullName = character.fullName,
                            isCurrent = character.fullName == playerName,
                            recipeID = recipeID,
                            itemID = itemID,
                            professionName = profession.name,
                            professionIcon = profession.icon,
                        }
                        break
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end
        return a.fullName < b.fullName
    end)
    return result
end

-- "Mining 150/300, Engineering 236/300" for a stored character, nil without professions.
function Professions:FormatProfessions(fullName)
    local info = ns.db.characters[fullName]
    if not (info and info.professions) then
        return nil
    end
    local parts = {}
    for _, profession in pairs(info.professions) do
        local text = profession.name
        if profession.rank and profession.maxRank then
            text = format("%s %d/%d", text, profession.rank, profession.maxRank)
        end
        if next(profession.crafts or {}) == nil then
            text = text .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["PROFESSION_NOT_SCANNED"])
        end
        parts[#parts + 1] = text
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or nil
end
