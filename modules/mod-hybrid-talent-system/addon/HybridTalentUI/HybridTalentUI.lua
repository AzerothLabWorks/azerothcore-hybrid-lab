local PREFIX = "AzerothCore"

local CLASS_NAMES = {
    "Warrior",
    "Paladin",
    "Hunter",
    "Rogue",
    "Priest",
    "Death Knight",
    "Shaman",
    "Mage",
    "Warlock",
    "Druid",
}

local state = {
    commandCounter = 0,
    earned = 0,
    spent = 0,
    available = 0,
    talentEarned = 0,
    talentSpent = 0,
    talentAvailable = 0,
    talentMinLevel = 0,
    talentPointsPerInterval = 0,
    talentInterval = 0,
    talentMaxPoints = 0,
    nextTalentPointLevel = 0,
    rows = {},
    talents = {},
    byClass = {},
    byTalentClass = {},
    selectedClass = 1,
    page = 1,
    loaded = false,
    mode = "spells",
    filter = "all",
    search = "",
    selectedSpell = nil,
    selectedTalent = nil,
    level = 0,
    minLevel = 0,
    pointsPerInterval = 0,
    interval = 0,
    maxPoints = 0,
    nextPointLevel = 0,
}

local mainFrame
local openButton
local classButtons = {}
local rowButtons = {}
local modeButtons = {}
local ROWS_PER_PAGE = 9
local MODES = {
    { key = "spells", label = "Spells" },
    { key = "talents", label = "Talents" },
}
local FILTERS = {
    { key = "all", label = "All" },
    { key = "available", label = "Available" },
    { key = "known", label = "Known" },
    { key = "locked", label = "Locked" },
}
local filterButtons = {}

local TALENT_TAB_NAMES = {
    [1] = { "Arms", "Fury", "Protection" },
    [2] = { "Holy", "Protection", "Retribution" },
    [3] = { "Beast Mastery", "Marksmanship", "Survival" },
    [4] = { "Assassination", "Combat", "Subtlety" },
    [5] = { "Discipline", "Holy", "Shadow" },
    [6] = { "Blood", "Frost", "Unholy" },
    [7] = { "Elemental", "Enhancement", "Restoration" },
    [8] = { "Arcane", "Fire", "Frost" },
    [9] = { "Affliction", "Demonology", "Destruction" },
    [10] = { "Balance", "Feral Combat", "Restoration" },
}

local HIDDEN_KNOWN_SUPPORT_SPELLS = {
    [196] = true,   -- One-Handed Axes
    [197] = true,   -- Two-Handed Axes
    [198] = true,   -- One-Handed Maces
    [199] = true,   -- Two-Handed Maces
    [200] = true,   -- Polearms
    [201] = true,   -- One-Handed Swords
    [202] = true,   -- Two-Handed Swords
    [203] = true,   -- Unarmed
    [204] = true,   -- Defense
    [227] = true,   -- Staves
    [264] = true,   -- Bows
    [266] = true,   -- Guns
    [674] = true,   -- Dual Wield
    [750] = true,   -- Plate Mail
    [8737] = true,  -- Mail
    [9077] = true,  -- Leather
    [9116] = true,  -- Shield
    [1180] = true,  -- Daggers
    [2567] = true,  -- Thrown
    [3127] = true,  -- Parry
    [5009] = true,  -- Wands
    [5011] = true,  -- Crossbows
    [15590] = true, -- Fist Weapons
}

local IMBUE_REMINDER_SPELLS = {
    [8017] = true,  -- Rockbiter Weapon
    [8018] = true,
    [8019] = true,
    [10399] = true,
    [16314] = true,
    [16315] = true,
    [16316] = true,
    [25479] = true,
    [25485] = true,
    [58794] = true,
    [58795] = true,
    [58796] = true,
    [8024] = true,  -- Flametongue Weapon
    [8027] = true,
    [8030] = true,
    [16339] = true,
    [16341] = true,
    [16342] = true,
    [25489] = true,
    [58785] = true,
    [58789] = true,
    [58790] = true,
    [8033] = true,  -- Frostbrand Weapon
    [8038] = true,
    [10456] = true,
    [16355] = true,
    [16356] = true,
    [25500] = true,
    [58797] = true,
    [58798] = true,
    [58799] = true,
    [8232] = true,  -- Windfury Weapon
    [8235] = true,
    [10486] = true,
    [16362] = true,
    [25505] = true,
    [58801] = true,
    [58803] = true,
    [58804] = true,
    [51730] = true, -- Earthliving Weapon
    [51988] = true,
    [51991] = true,
    [51992] = true,
    [51993] = true,
    [51994] = true,
    [8681] = true,  -- Instant Poison
    [8687] = true,
    [8691] = true,
    [11341] = true,
    [11342] = true,
    [11343] = true,
    [26891] = true,
    [57964] = true,
    [2823] = true,  -- Deadly Poison
    [2824] = true,
    [11355] = true,
    [11356] = true,
    [25351] = true,
    [26967] = true,
    [57969] = true,
    [3408] = true,  -- Crippling Poison
    [5761] = true,  -- Mind-numbing Poison
    [8694] = true,
    [11400] = true,
    [13220] = true, -- Wound Poison
    [13228] = true,
    [13229] = true,
    [13230] = true,
    [27283] = true,
    [57974] = true,
    [26785] = true, -- Anesthetic Poison
}

local IMBUE_REMINDER_NAMES = {
    ["Rockbiter Weapon"] = 8017,
    ["Flametongue Weapon"] = 8024,
    ["Frostbrand Weapon"] = 8033,
    ["Windfury Weapon"] = 8232,
    ["Earthliving Weapon"] = 51730,
    ["Instant Poison"] = 8681,
    ["Deadly Poison"] = 2823,
    ["Crippling Poison"] = 3408,
    ["Mind-numbing Poison"] = 5761,
    ["Wound Poison"] = 13220,
    ["Anesthetic Poison"] = 26785,
}

local imbueReminderFrames = {}
local imbueReminderPulse = 0
local imbueReminderElapsed = 0
local imbueReminderSettleRemaining = 0
local imbueReminderLastState = nil
local imbueReminderPendingSpell = nil
local imbueReminderClickedHand = nil
local imbueReminderLastMainItemLink = nil
local imbueReminderLastOffItemLink = nil
local IMBUE_REMINDER_DEFAULT_THRESHOLD_SECONDS = 300
local IMBUE_REMINDER_SETTLE_SECONDS = 6
local IMBUE_REMINDER_APPLY_SETTLE_SECONDS = 0.4
local resourceFrame
local RESOURCE_BARS = {
    { key = "mana", label = "Mana", powerType = 0, color = { 0.0, 0.45, 1.0 } },
    { key = "rage", label = "Rage", powerType = 1, color = { 0.85, 0.12, 0.12 } },
    { key = "energy", label = "Energy", powerType = 3, color = { 1.0, 0.82, 0.0 } },
}
local RESOURCE_FRAME_DEFAULT_WIDTH = 119
local RESOURCE_BAR_HEIGHT = 10
local RESOURCE_BAR_GAP = 2

local STANCE_RELAXED_SPELLS = {
    [100] = "Charge",
    [6178] = "Charge",
    [11578] = "Charge",
    [20252] = "Intercept",
    [20616] = "Intercept",
    [20617] = "Intercept",
    [25272] = "Intercept",
    [25275] = "Intercept",
    [7384] = "Overpower",
    [7887] = "Overpower",
    [11584] = "Overpower",
    [11585] = "Overpower",
    [694] = "Mocking Blow",
    [7400] = "Mocking Blow",
    [7402] = "Mocking Blow",
    [20559] = "Mocking Blow",
    [20560] = "Mocking Blow",
    [25266] = "Mocking Blow",
    [6572] = "Revenge",
    [6574] = "Revenge",
    [7379] = "Revenge",
    [11600] = "Revenge",
    [11601] = "Revenge",
    [25288] = "Revenge",
    [25269] = "Revenge",
    [30357] = "Revenge",
    [57823] = "Revenge",
    [676] = "Disarm",
    [871] = "Shield Wall",
    [20230] = "Retaliation",
    [1719] = "Recklessness",
    [18499] = "Berserker Rage",
    [6552] = "Pummel",
    [6554] = "Pummel",
    [1680] = "Whirlwind",
}

local NORMALIZED_DURATION_BUFF_NAMES = {
    ["Arcane Brilliance"] = true,
    ["Arcane Intellect"] = true,
    ["Amplify Magic"] = true,
    ["Battle Shout"] = true,
    ["Blessing of Kings"] = true,
    ["Blessing of Might"] = true,
    ["Blessing of Sanctuary"] = true,
    ["Blessing of Wisdom"] = true,
    ["Commanding Shout"] = true,
    ["Dampen Magic"] = true,
    ["Devotion Aura"] = true,
    ["Divine Spirit"] = true,
    ["Gift of the Wild"] = true,
    ["Greater Blessing of Kings"] = true,
    ["Greater Blessing of Might"] = true,
    ["Greater Blessing of Sanctuary"] = true,
    ["Greater Blessing of Wisdom"] = true,
    ["Mark of the Wild"] = true,
    ["Prayer of Fortitude"] = true,
    ["Prayer of Shadow Protection"] = true,
    ["Prayer of Spirit"] = true,
    ["Power Word: Fortitude"] = true,
    ["Shadow Protection"] = true,
    ["Thorns"] = true,
}

local function RemoveTooltipStanceRequirementLines(tooltip)
    if not tooltip or not tooltip.NumLines then
        return
    end

    for index = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. index]
        local text = line and line.GetText and line:GetText()
        if text and string.find(text, "Requires", 1, true) and string.find(text, "Stance", 1, true) then
            line:SetText("")
        end
    end
end

local function ApplyHybridTooltipNotes(tooltip, spellId)
    if not tooltip or not spellId then
        return
    end

    local spellName = STANCE_RELAXED_SPELLS[spellId]
    if spellName then
        RemoveTooltipStanceRequirementLines(tooltip)
        tooltip:AddLine("Hybrid rule: stance is not required for " .. spellName .. ".", 0.6, 0.8, 1)
    end

    local normalizedName = GetSpellInfo and GetSpellInfo(spellId) or nil
    if normalizedName and NORMALIZED_DURATION_BUFF_NAMES[normalizedName] then
        tooltip:AddLine("Hybrid rule: duration is normalized to 30 minutes on cast.", 0.6, 0.8, 1)
    end
end

local function HookGlobalSpellTooltipNotes()
    if not GameTooltip or GameTooltip.HybridTalentUINotesHooked then
        return
    end

    GameTooltip.HybridTalentUINotesHooked = true
    GameTooltip:HookScript("OnTooltipSetSpell", function(self)
        local _, _, spellId = self:GetSpell()
        ApplyHybridTooltipNotes(self, spellId)
    end)
end

local function GetSpellIcon(spellId)
    local _, _, icon = GetSpellInfo(spellId)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end


local spellDescriptionCache = {}
local scanTooltip

local function GetSpellDescriptionFromTooltip(spellId)
    if not CreateFrame or not UIParent then
        return ""
    end

    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "HybridTalentUIScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    scanTooltip:ClearLines()
    if scanTooltip.SetHyperlink then
        scanTooltip:SetHyperlink("spell:" .. spellId)
    else
        return ""
    end

    local lines = {}
    for index = 2, scanTooltip:NumLines() do
        local line = _G["HybridTalentUIScanTooltipTextLeft" .. index]
        local text = line and line.GetText and line:GetText()
        if text and text ~= "" then
            table.insert(lines, text)
        end
    end

    return table.concat(lines, " ")
end

local function GetClientSpellDescription(spellId)
    spellId = tonumber(spellId or 0) or 0
    if spellId <= 0 then
        return ""
    end

    if spellDescriptionCache[spellId] ~= nil then
        return spellDescriptionCache[spellId]
    end

    local description = ""
    if type(GetSpellDescription) == "function" then
        description = GetSpellDescription(spellId) or ""
    end

    if description == "" then
        description = GetSpellDescriptionFromTooltip(spellId)
    end

    spellDescriptionCache[spellId] = description or ""
    return spellDescriptionCache[spellId]
end

local function BuildSearchText(...)
    local values = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= "" then
            table.insert(values, tostring(value))
        end
    end

    return string.lower(table.concat(values, " "))
end

local function IsServerFallbackDescription(description)
    if not description or description == "" then
        return true
    end

    if string.find(description, " - Trainer", 1, true) then
        return true
    end

    return description == "Hybrid spell"
end

local function ResolveSpellDescription(serverDescription, clientDescription)
    if IsServerFallbackDescription(serverDescription) and clientDescription and clientDescription ~= "" then
        return clientDescription
    end

    return serverDescription or ""
end

local function CompactListDescription(description)
    description = description or ""
    description = string.gsub(description, "%s+", " ")
    description = string.gsub(description, "^%s+", "")
    description = string.gsub(description, "%s+$", "")

    local firstSentence = string.match(description, "^(.-%.)%s")
    if firstSentence and string.len(firstSentence) >= 24 then
        description = firstSentence
    end

    local maxLength = 82
    if string.len(description) > maxLength then
        description = string.sub(description, 1, maxLength - 3) .. "..."
    end

    return description
end

local function ShowSpellTooltip(owner, row)
    if not owner or not row then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("spell:" .. row.spellId)
        ApplyHybridTooltipNotes(GameTooltip, row.spellId)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(row.reason or "", 0.95, 0.82, 0.35)
        GameTooltip:AddLine("Left-click: learn if available", 0.6, 0.8, 1)
        GameTooltip:AddLine("Right-click: unlearn if known", 0.6, 0.8, 1)
    else
        GameTooltip:SetText(row.name)
        GameTooltip:AddLine(row.description, 1, 1, 1, 1)
        GameTooltip:AddLine(row.reason or "", 0.95, 0.82, 0.35)
        GameTooltip:AddLine("Left-click: learn if available", 0.6, 0.8, 1)
        GameTooltip:AddLine("Right-click: unlearn if known", 0.6, 0.8, 1)
    end
    GameTooltip:Show()
end

local function GetTalentTabName(row)
    if not row then
        return "Talent"
    end

    local tabs = TALENT_TAB_NAMES[row.classIndex]
    if tabs and tabs[row.tabPage + 1] then
        return tabs[row.tabPage + 1]
    end

    return "Talent"
end

local function ShowTalentTooltip(owner, row)
    if not owner or not row then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("spell:" .. row.spellId)
        ApplyHybridTooltipNotes(GameTooltip, row.spellId)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(GetTalentTabName(row) .. "  Rank " .. row.knownRank .. "/" .. row.maxRank, 0.95, 0.82, 0.35)
        GameTooltip:AddLine("Left-click: learn next rank if available", 0.6, 0.8, 1)
        GameTooltip:AddLine("Right-click: unlearn one rank if known", 0.6, 0.8, 1)
    else
        GameTooltip:SetText(row.name)
        GameTooltip:AddLine(GetTalentTabName(row) .. "  Rank " .. row.knownRank .. "/" .. row.maxRank, 0.95, 0.82, 0.35)
        GameTooltip:AddLine("Left-click: learn next rank if available", 0.6, 0.8, 1)
        GameTooltip:AddLine("Right-click: unlearn one rank if known", 0.6, 0.8, 1)
    end
    GameTooltip:Show()
end

local function ShowRowTooltip(owner, row)
    if state.mode == "talents" then
        ShowTalentTooltip(owner, row)
    else
        ShowSpellTooltip(owner, row)
    end
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66d9efHybridTalentUI:|r " .. tostring(message))
    end
end

local function FormatBoolean(value)
    if value then
        return "yes"
    end

    return "no"
end

local function FormatNextPointText(label, nextLevel)
    nextLevel = tonumber(nextLevel or 0) or 0
    if nextLevel > 0 then
        return label .. " next point at " .. nextLevel
    end

    return label .. " points maxed"
end

local function GetTalentProgressText(row)
    if not row then
        return ""
    end

    if row.knownRank >= row.maxRank then
        return "Rank " .. row.knownRank .. "/" .. row.maxRank .. "  Maxed"
    end

    return "Rank " .. row.knownRank .. "/" .. row.maxRank .. "  Next " .. (row.knownRank + 1) .. "/" .. row.maxRank
end

local function GetTalentStateText(row)
    if not row then
        return ""
    end

    if row.knownRank >= row.maxRank then
        return "Max rank learned."
    end

    if row.canLearn then
        return "Available: learn rank " .. (row.knownRank + 1) .. "/" .. row.maxRank .. " for 1 hybrid talent point."
    end

    local reason = row.reason or ""
    if reason == "" or reason == "Browse only" then
        reason = "Locked"
    end

    return "Locked: " .. reason .. "."
end

local function GetTalentRulesText(row)
    if not row then
        return ""
    end

    return "Free-pick hybrid talent: no prior points in this tree are required."
end

local function DebugPetActions()
    Print("pet exists: " .. FormatBoolean(UnitExists and UnitExists("pet")) .. ", name: " .. tostring(UnitName and UnitName("pet") or "none"))

    if HasPetSpells then
        Print("HasPetSpells: " .. tostring(HasPetSpells()))
    else
        Print("HasPetSpells API is unavailable.")
    end

    if GetNumSpellTabs then
        Print("spellbook tabs: " .. tostring(GetNumSpellTabs()))
    end

    if not GetPetActionInfo then
        Print("GetPetActionInfo API is unavailable.")
        return
    end

    for slot = 1, 10 do
        local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(slot)
        Print("pet slot " .. slot
            .. ": name=" .. tostring(name)
            .. ", subtext=" .. tostring(subtext)
            .. ", texture=" .. tostring(texture)
            .. ", token=" .. tostring(isToken)
            .. ", active=" .. tostring(isActive)
            .. ", autoAllowed=" .. tostring(autoCastAllowed)
            .. ", autoOn=" .. tostring(autoCastEnabled))
    end
end

local function SetFrameSize(frame, width, height)
    frame:SetWidth(width)
    frame:SetHeight(height)
end

local function SplitTabs(text)
    local parts = {}
    local value = text or ""
    local start = 1

    while true do
        local tab = string.find(value, "\t", start, true)
        if not tab then
            table.insert(parts, string.sub(value, start))
            return parts
        end

        table.insert(parts, string.sub(value, start, tab - 1))
        start = tab + 1
    end
end

local function NextCounter()
    state.commandCounter = state.commandCounter + 1
    if state.commandCounter > 9999 then
        state.commandCounter = 1
    end

    return string.format("%04d", state.commandCounter)
end

local function SendCommand(command)
    if not SendAddonMessage then
        Print("SendAddonMessage is unavailable in this client.")
        return
    end

    SendAddonMessage(PREFIX, "i" .. NextCounter() .. command, "WHISPER", UnitName("player"))
end

local function Refresh()
    state.rows = {}
    state.talents = {}
    state.byClass = {}
    state.byTalentClass = {}
    state.loaded = false
    SendCommand("hybridui refresh")
end

local function IsHiddenKnownSupportSpell(row)
    return row and row.known and HIDDEN_KNOWN_SUPPORT_SPELLS[row.spellId]
end

local function GetVisibleRows()
    local result = {}
    local search = string.lower(state.search or "")

    if state.mode == "talents" then
        for _, row in ipairs(state.talents) do
            local filterMatch = state.filter == "all"
                or (state.filter == "available" and row.canLearn)
                or (state.filter == "known" and row.knownRank > 0)
                or (state.filter == "locked" and not row.canLearn and row.knownRank == 0)

            local searchMatch = search == ""
                or string.find(row.searchText or "", search, 1, true)
                or string.find(string.lower(GetTalentTabName(row)), search, 1, true)
                or string.find(tostring(row.talentId), search, 1, true)
                or string.find(tostring(row.spellId), search, 1, true)

            local classMatch = state.filter == "known" or row.classIndex == state.selectedClass

            if classMatch and filterMatch and searchMatch then
                table.insert(result, row)
            end
        end
        return result
    end

    for _, row in ipairs(state.rows) do
        local filterMatch = state.filter == "all"
            or (state.filter == "available" and row.canLearn)
            or (state.filter == "known" and row.known)
            or (state.filter == "locked" and not row.canLearn and not row.known)

        local searchMatch = search == ""
            or string.find(row.searchText or "", search, 1, true)
            or string.find(tostring(row.spellId), search, 1, true)

        local classMatch = state.filter == "known" or row.classIndex == state.selectedClass
        local supportMatch = state.filter ~= "known" or not IsHiddenKnownSupportSpell(row)

        if classMatch and filterMatch and searchMatch and supportMatch then
            table.insert(result, row)
        end
    end
    return result
end

local function SetSelectedClass(index)
    state.selectedClass = index
    state.page = 1
    state.selectedSpell = nil
    state.selectedTalent = nil
end

local function GetPageCount(rows)
    if #rows == 0 then
        return 1
    end
    return math.ceil(#rows / ROWS_PER_PAGE)
end

local function UpdateMicroButton()
    if not openButton then
        return
    end

    if state.loaded then
        openButton:SetText("Hybrid")
    else
        openButton:SetText("Load")
    end
end

local function UpdateClassButtons()
    for index, button in ipairs(classButtons) do
        local count = state.mode == "talents" and (state.byTalentClass[index] or 0) or (state.byClass[index] or 0)
        button:SetText(CLASS_NAMES[index] .. " (" .. count .. ")")
        if index == state.selectedClass then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

local function UpdateFilterButtons()
    for _, button in ipairs(filterButtons) do
        button:Enable()

        if button.filterKey == state.filter then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

local function UpdateModeButtons()
    for _, button in ipairs(modeButtons) do
        if button.modeKey == state.mode then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

local function GetSelectedRow()
    if state.mode == "talents" then
        if not state.selectedTalent then
            return nil
        end

        for _, row in ipairs(state.talents) do
            if row.talentId == state.selectedTalent then
                return row
            end
        end

        return nil
    end

    if not state.selectedSpell then
        return nil
    end

    for _, row in ipairs(state.rows) do
        if row.spellId == state.selectedSpell then
            return row
        end
    end

    return nil
end

local function UpdateDetails()
    if not mainFrame then
        return
    end

    local row = GetSelectedRow()
    if not row then
        mainFrame.detailIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        mainFrame.detailName:SetText(state.mode == "talents" and "Select a talent" or "Select a spell")
        mainFrame.detailMeta:SetText("")
        if state.mode == "talents" then
            mainFrame.detailDesc:SetText("Left-click an available talent to learn its next rank. Right-click a known talent to unlearn one rank.")
        else
            mainFrame.detailDesc:SetText("Left-click an available spell to learn it. Right-click a known spell to unlearn it.")
        end
        mainFrame.detailReason:SetText("")
        return
    end

    mainFrame.detailIcon:SetTexture(GetSpellIcon(row.spellId))
    mainFrame.detailName:SetText(row.name)
    if state.mode == "talents" then
        mainFrame.detailMeta:SetText(GetTalentTabName(row) .. "  Row " .. (row.row + 1) .. "  Column " .. (row.col + 1))
        local talentDescription = row.description ~= "" and row.description or GetTalentRulesText(row)
        mainFrame.detailDesc:SetText(GetTalentProgressText(row) .. "\n" .. talentDescription)
        mainFrame.detailReason:SetText(GetTalentStateText(row))
    else
        mainFrame.detailMeta:SetText("Spell ID " .. row.spellId .. "  Level " .. row.requiredLevel .. "  Cost " .. row.cost)
        mainFrame.detailDesc:SetText(row.description ~= "" and row.description or "No description available.")
        mainFrame.detailReason:SetText(row.reason or "")
    end
end

local function UpdateRows()
    if not mainFrame then
        return
    end

    local rows = GetVisibleRows()
    local pageCount = GetPageCount(rows)
    if state.page > pageCount then
        state.page = pageCount
    end

    local startIndex = (state.page - 1) * ROWS_PER_PAGE + 1

    if state.mode == "talents" then
        mainFrame.points:SetText("Hybrid talent points: " .. state.talentAvailable .. " available / " .. state.talentEarned .. " earned")
        mainFrame.status:SetText("Level " .. state.level .. "  " .. FormatNextPointText("Talent", state.nextTalentPointLevel) .. "  +" .. state.talentPointsPerInterval .. " / " .. state.talentInterval .. " levels  Max " .. state.talentMaxPoints)
    else
        mainFrame.points:SetText("Hybrid points: " .. state.available .. " available / " .. state.earned .. " earned")
        mainFrame.status:SetText("Level " .. state.level .. "  " .. FormatNextPointText("Spell", state.nextPointLevel) .. "  +" .. state.pointsPerInterval .. " / " .. state.interval .. " levels  Max " .. state.maxPoints)
    end
    mainFrame.page:SetText("Page " .. state.page .. " / " .. pageCount)

    for rowIndex = 1, ROWS_PER_PAGE do
        local button = rowButtons[rowIndex]
        local data = rows[startIndex + rowIndex - 1]
        button.data = data

        if data then
            button.icon:SetTexture(GetSpellIcon(data.spellId))
            button.name:SetText(data.name)
            if state.mode == "talents" then
                button.meta:SetText(GetTalentTabName(data) .. "  Row " .. (data.row + 1) .. " Col " .. (data.col + 1))
                button.desc:SetText(GetTalentProgressText(data))
                button.reason:SetText(data.canLearn and "Cost 1 point" or (data.reason or ""))
                if data.knownRank >= data.maxRank then
                    button.status:SetText("Known")
                    button.status:SetTextColor(0.25, 0.9, 0.35)
                elseif data.canLearn then
                    button.status:SetText("Learn rank " .. (data.knownRank + 1))
                    button.status:SetTextColor(0.95, 0.82, 0.35)
                elseif data.knownRank > 0 then
                    button.status:SetText("Rank " .. data.knownRank)
                    button.status:SetTextColor(0.6, 0.8, 1)
                else
                    button.status:SetText("Locked")
                    button.status:SetTextColor(0.6, 0.6, 0.6)
                end
            else
                button.meta:SetText("Level " .. data.requiredLevel .. "  Cost " .. data.cost)
                button.desc:SetText(data.listDescription ~= "" and data.listDescription or "No description available.")
                button.reason:SetText(data.reason or "")

                if data.known then
                    button.status:SetText("Known")
                    button.status:SetTextColor(0.25, 0.9, 0.35)
                elseif data.canLearn then
                    button.status:SetText("Available")
                    button.status:SetTextColor(0.95, 0.82, 0.35)
                else
                    button.status:SetText("Locked")
                    button.status:SetTextColor(0.6, 0.6, 0.6)
                end
            end

            button:Show()
        else
            button:Hide()
        end
    end

    if #rows == 0 then
        if state.mode == "talents" then
            if state.filter == "known" then
                mainFrame.empty:SetText("No known hybrid talents.")
            else
                mainFrame.empty:SetText("No talents available for this class.")
            end
        elseif state.filter == "known" then
            mainFrame.empty:SetText("No known hybrid spells.")
        else
            mainFrame.empty:SetText("No spells available for this class.")
        end
        mainFrame.empty:Show()
    else
        mainFrame.empty:Hide()
    end

    UpdateClassButtons()
    UpdateFilterButtons()
    UpdateModeButtons()
    UpdateDetails()
    UpdateMicroButton()
end

local function AddSpell(parts)
    local spellId = tonumber(parts[3] or "0") or 0
    local serverDescription = parts[10] or ""
    local clientDescription = GetClientSpellDescription(spellId)
    local classIndex = (tonumber(parts[4] or "0") or 0) + 1
    local row = {
        spellId = spellId,
        classIndex = classIndex,
        requiredLevel = tonumber(parts[5] or "1") or 1,
        cost = tonumber(parts[6] or "1") or 1,
        known = parts[7] == "1",
        canLearn = parts[8] == "1",
        name = parts[9] or "",
        description = ResolveSpellDescription(serverDescription, clientDescription),
        reason = parts[11] or "",
    }
    row.listDescription = CompactListDescription(row.description)
    row.searchText = BuildSearchText(row.name, row.description, clientDescription)

    if row.spellId > 0 and CLASS_NAMES[classIndex] then
        table.insert(state.rows, row)
        state.byClass[classIndex] = (state.byClass[classIndex] or 0) + 1
    end
end

local function AddTalent(parts)
    local classIndex = (tonumber(parts[5] or "0") or 0) + 1
    local row = {
        talentId = tonumber(parts[3] or "0") or 0,
        spellId = tonumber(parts[4] or "0") or 0,
        classIndex = classIndex,
        tabPage = tonumber(parts[6] or "0") or 0,
        row = tonumber(parts[7] or "0") or 0,
        col = tonumber(parts[8] or "0") or 0,
        maxRank = tonumber(parts[9] or "0") or 0,
        knownRank = tonumber(parts[10] or "0") or 0,
        canLearn = parts[11] == "1",
        name = parts[12] or "",
        reason = parts[13] or "",
    }
    row.description = GetClientSpellDescription(row.spellId)
    row.searchText = BuildSearchText(row.name, row.description, GetTalentTabName(row))

    if row.talentId > 0 and row.spellId > 0 and CLASS_NAMES[classIndex] then
        table.insert(state.talents, row)
        state.byTalentClass[classIndex] = (state.byTalentClass[classIndex] or 0) + 1
    end
end

local function HandleServerMessage(body)
    local parts = SplitTabs(body)
    if parts[1] ~= "HYUI" then
        return
    end

    if parts[2] == "BEGIN" then
        state.earned = tonumber(parts[4] or "0") or 0
        state.spent = tonumber(parts[5] or "0") or 0
        state.available = tonumber(parts[6] or "0") or 0
        state.talentEarned = 0
        state.talentSpent = 0
        state.talentAvailable = 0
        state.rows = {}
        state.talents = {}
        state.byClass = {}
        state.byTalentClass = {}
        state.loaded = false
    elseif parts[2] == "SPELL" then
        AddSpell(parts)
    elseif parts[2] == "TALENT" then
        AddTalent(parts)
    elseif parts[2] == "STATUS" then
        state.level = tonumber(parts[3] or "0") or 0
        state.minLevel = tonumber(parts[4] or "0") or 0
        state.pointsPerInterval = tonumber(parts[5] or "0") or 0
        state.interval = tonumber(parts[6] or "0") or 0
        state.maxPoints = tonumber(parts[7] or "0") or 0
        state.nextPointLevel = tonumber(parts[8] or "0") or 0
    elseif parts[2] == "TALENTSTATUS" then
        state.talentEarned = tonumber(parts[3] or "0") or 0
        state.talentSpent = tonumber(parts[4] or "0") or 0
        state.talentAvailable = tonumber(parts[5] or "0") or 0
        state.talentMinLevel = tonumber(parts[6] or "0") or 0
        state.talentPointsPerInterval = tonumber(parts[7] or "0") or 0
        state.talentInterval = tonumber(parts[8] or "0") or 0
        state.talentMaxPoints = tonumber(parts[9] or "0") or 0
        state.nextTalentPointLevel = tonumber(parts[10] or "0") or 0
    elseif parts[2] == "END" then
        state.loaded = true
        UpdateRows()
    elseif parts[2] == "ERROR" then
        Print(parts[3] or "server error")
    end
end

local function HandleAddonMessage(prefix, message)
    if prefix ~= PREFIX or type(message) ~= "string" then
        return
    end

    if string.sub(message, 1, 1) ~= "m" then
        return
    end

    HandleServerMessage(string.sub(message, 6))
end

local function OnSpellRowClick(self, mouseButton)
    local row = self.data
    if not row then
        return
    end

    if state.mode == "talents" then
        state.selectedTalent = row.talentId
        UpdateDetails()
        if mouseButton == "RightButton" then
            if row.knownRank > 0 then
                SendCommand("hybridui unlearntalent " .. row.talentId)
            else
                Print(row.name .. " is not currently learned as a hybrid talent.")
            end
            return
        end

        if row.canLearn then
            SendCommand("hybridui learntalent " .. row.talentId)
        elseif row.knownRank >= row.maxRank then
            Print(row.name .. " is already at maximum rank.")
        else
            Print(row.name .. " is locked: " .. (row.reason or "requirements not met") .. ".")
        end
        return
    end

    state.selectedSpell = row.spellId
    UpdateDetails()

    if mouseButton == "RightButton" then
        if row.known then
            SendCommand("hybridui unlearn " .. row.spellId)
        else
            Print(row.name .. " is not currently learned as a hybrid spell.")
        end
        return
    end

    if row.known then
        Print(row.name .. " is already learned. Right-click to unlearn.")
    elseif row.canLearn then
        SendCommand("hybridui learn " .. row.spellId)
    else
        Print(row.name .. " is locked: " .. (row.reason or "requirements not met") .. ".")
    end
end

local function CreateSpellRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    SetFrameSize(row, 558, 42)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -138 - ((index - 1) * 45))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    SetFrameSize(row.icon, 28, 28)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetWidth(145)
    row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.meta:SetWidth(150)
    row.meta:SetJustifyH("LEFT")

    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.desc:SetPoint("LEFT", row, "LEFT", 205, 0)
    row.desc:SetWidth(205)
    row.desc:SetJustifyH("LEFT")

    row.reason = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.reason:SetPoint("LEFT", row, "LEFT", 420, 0)
    row.reason:SetWidth(88)
    row.reason:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.status:SetWidth(90)
    row.status:SetJustifyH("RIGHT")

    row:SetScript("OnClick", OnSpellRowClick)
    row:SetScript("OnEnter", function(self)
        if not self.data then
            return
        end

        ShowRowTooltip(self, self.data)
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

local function CreateMainFrame()
    if mainFrame then
        return
    end

    mainFrame = CreateFrame("Frame", "HybridTalentUIFrame", UIParent)
    SetFrameSize(mainFrame, 900, 640)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    mainFrame:Hide()

    mainFrame.bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    mainFrame.bg:SetAllPoints(mainFrame)
    mainFrame.bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainFrame.title:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -18)
    mainFrame.title:SetText("Hybrid Training")

    mainFrame.points = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.points:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -46, -22)
    mainFrame.points:SetJustifyH("RIGHT")

    mainFrame.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mainFrame.status:SetPoint("TOPRIGHT", mainFrame.points, "BOTTOMRIGHT", 0, -3)
    mainFrame.status:SetJustifyH("RIGHT")

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)

    mainFrame.search = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    SetFrameSize(mainFrame.search, 180, 22)
    mainFrame.search:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -106)
    mainFrame.search:SetScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        state.page = 1
        UpdateRows()
    end)

    mainFrame.searchLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mainFrame.searchLabel:SetPoint("BOTTOMLEFT", mainFrame.search, "TOPLEFT", 0, 2)
    mainFrame.searchLabel:SetText("Search")

    for index, mode in ipairs(MODES) do
        local button = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        SetFrameSize(button, 82, 22)
        button:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 150 + ((index - 1) * 88), -18)
        button:SetText(mode.label)
        button.modeKey = mode.key
        button:SetScript("OnClick", function(self)
            state.mode = self.modeKey
            state.page = 1
            state.selectedSpell = nil
            state.selectedTalent = nil
            UpdateRows()
        end)
        modeButtons[index] = button
    end

    for index, filter in ipairs(FILTERS) do
        local button = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        SetFrameSize(button, 76, 22)
        button:SetPoint("LEFT", mainFrame.search, "RIGHT", 14 + ((index - 1) * 80), 0)
        button:SetText(filter.label)
        button.filterKey = filter.key
        button:SetScript("OnClick", function(self)
            state.filter = self.filterKey
            state.page = 1
            UpdateRows()
        end)
        filterButtons[index] = button
    end

    for index, className in ipairs(CLASS_NAMES) do
        local button = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        SetFrameSize(button, 132, 22)
        local col = (index - 1) - math.floor((index - 1) / 5) * 5
        local row = math.floor((index - 1) / 5)
        button:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20 + col * 138, -50 - row * 26)
        button:SetText(className)
        button:SetScript("OnClick", function()
            SetSelectedClass(index)
            UpdateRows()
        end)
        classButtons[index] = button
    end

    for index = 1, ROWS_PER_PAGE do
        rowButtons[index] = CreateSpellRow(mainFrame, index)
    end

    mainFrame.empty = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    mainFrame.empty:SetPoint("CENTER", mainFrame, "CENTER", 0, -10)
    mainFrame.empty:SetText("No spells available for this class.")

    mainFrame.detailIcon = mainFrame:CreateTexture(nil, "ARTWORK")
    SetFrameSize(mainFrame.detailIcon, 42, 42)
    mainFrame.detailIcon:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 604, -144)

    mainFrame.detailIconHit = CreateFrame("Frame", nil, mainFrame)
    SetFrameSize(mainFrame.detailIconHit, 42, 42)
    mainFrame.detailIconHit:SetPoint("CENTER", mainFrame.detailIcon, "CENTER", 0, 0)
    mainFrame.detailIconHit:EnableMouse(true)
    mainFrame.detailIconHit:SetScript("OnEnter", function(self)
        ShowRowTooltip(self, GetSelectedRow())
    end)
    mainFrame.detailIconHit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    mainFrame.detailName = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.detailName:SetPoint("TOPLEFT", mainFrame.detailIcon, "TOPRIGHT", 10, 0)
    mainFrame.detailName:SetWidth(210)
    mainFrame.detailName:SetJustifyH("LEFT")

    mainFrame.detailMeta = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mainFrame.detailMeta:SetPoint("TOPLEFT", mainFrame.detailName, "BOTTOMLEFT", 0, -3)
    mainFrame.detailMeta:SetWidth(220)
    mainFrame.detailMeta:SetJustifyH("LEFT")

    mainFrame.detailReason = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.detailReason:SetPoint("TOPLEFT", mainFrame.detailMeta, "BOTTOMLEFT", 0, -3)
    mainFrame.detailReason:SetWidth(220)
    mainFrame.detailReason:SetJustifyH("LEFT")
    mainFrame.detailReason:SetTextColor(0.95, 0.82, 0.35)

    mainFrame.detailDesc = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.detailDesc:SetPoint("TOPLEFT", mainFrame.detailIcon, "BOTTOMLEFT", 0, -14)
    mainFrame.detailDesc:SetWidth(265)
    mainFrame.detailDesc:SetJustifyH("LEFT")

    local prev = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    SetFrameSize(prev, 72, 24)
    prev:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 18)
    prev:SetText("Prev")
    prev:SetScript("OnClick", function()
        if state.page > 1 then
            state.page = state.page - 1
            UpdateRows()
        end
    end)

    mainFrame.page = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.page:SetPoint("LEFT", prev, "RIGHT", 14, 0)
    mainFrame.page:SetWidth(90)
    mainFrame.page:SetJustifyH("CENTER")

    local nextButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    SetFrameSize(nextButton, 72, 24)
    nextButton:SetPoint("LEFT", mainFrame.page, "RIGHT", 14, 0)
    nextButton:SetText("Next")
    nextButton:SetScript("OnClick", function()
        local pageCount = GetPageCount(GetVisibleRows())
        if state.page < pageCount then
            state.page = state.page + 1
            UpdateRows()
        end
    end)

    local refresh = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    SetFrameSize(refresh, 88, 24)
    refresh:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, 18)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", Refresh)
end

local function ToggleMainFrame()
    CreateMainFrame()

    if mainFrame:IsVisible() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        Refresh()
    end
end

local function EnsureSavedVariables()
    HybridTalentUIDB = HybridTalentUIDB or {}
    HybridTalentUIDB.openButton = HybridTalentUIDB.openButton or {}
    HybridTalentUIDB.imbueReminder = HybridTalentUIDB.imbueReminder or {}
    HybridTalentUIDB.imbueReminder.characters = HybridTalentUIDB.imbueReminder.characters or {}
    HybridTalentUIDB.resourceFrame = HybridTalentUIDB.resourceFrame or {}
    if HybridTalentUIDB.imbueReminder.enabled == nil then
        HybridTalentUIDB.imbueReminder.enabled = true
    end
    if HybridTalentUIDB.resourceFrame.enabled == nil then
        HybridTalentUIDB.resourceFrame.enabled = true
    end
    HybridTalentUIDB.imbueReminder.thresholdSeconds = HybridTalentUIDB.imbueReminder.thresholdSeconds or IMBUE_REMINDER_DEFAULT_THRESHOLD_SECONDS
end

local function GetImbueReminderDB()
    EnsureSavedVariables()
    return HybridTalentUIDB.imbueReminder
end

local function GetImbueReminderCharacterKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return tostring(realm or "Unknown") .. "::" .. tostring(name or "Unknown")
end

local function GetImbueReminderCharacterDB()
    local db = GetImbueReminderDB()
    local key = GetImbueReminderCharacterKey()
    db.characters[key] = db.characters[key] or {}
    return db.characters[key]
end

local function IsTrackedImbueSpell(spellId, spellName)
    if spellId and IMBUE_REMINDER_SPELLS[tonumber(spellId)] then
        return true
    end

    return spellName and IMBUE_REMINDER_NAMES[spellName] ~= nil
end

local function FindKnownImbueSpellId(spellName)
    if not spellName or not GetNumSpellTabs or not GetSpellTabInfo or not GetSpellBookItemName or not GetSpellBookItemInfo then
        return spellName and IMBUE_REMINDER_NAMES[spellName] or nil
    end

    local fallback = IMBUE_REMINDER_NAMES[spellName]
    for tabIndex = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset or 0) or 0
        numSpells = tonumber(numSpells or 0) or 0

        for spellBookIndex = offset + 1, offset + numSpells do
            local knownName = GetSpellBookItemName(spellBookIndex, BOOKTYPE_SPELL)
            if knownName == spellName then
                local _, spellId = GetSpellBookItemInfo(spellBookIndex, BOOKTYPE_SPELL)
                if spellId and IMBUE_REMINDER_SPELLS[spellId] then
                    return spellId
                end
            end
        end
    end

    return fallback
end

local function FormatDuration(seconds)
    seconds = math.max(0, tonumber(seconds or 0) or 0)
    if seconds >= 3600 then
        return math.ceil(seconds / 3600) .. "h"
    end

    if seconds >= 60 then
        return math.ceil(seconds / 60) .. "m"
    end

    return math.ceil(seconds) .. "s"
end

local function GetImbueReminderPositionDB(handKey)
    local db = GetImbueReminderDB()
    if handKey == "off" then
        db.offhand = db.offhand or {}
        return db.offhand
    end

    return db
end

local function GetImbueReminderSpellId(handKey)
    local db = GetImbueReminderCharacterDB()
    if handKey == "off" then
        return db.offSpellId
    end

    return db.mainSpellId
end

local function SetImbueReminderSpellId(handKey, spellId)
    local db = GetImbueReminderCharacterDB()
    if handKey == "off" then
        db.offSpellId = spellId
    else
        db.mainSpellId = spellId
    end
end

local function NormalizeEnchantPresence(value)
    return value == true or value == 1
end

local function GetImbueReminderHandState(handKey)
    if not GetWeaponEnchantInfo then
        return nil, nil
    end

    local mainRaw, mainHandExpiration, _, fourth, fifth, sixth, seventh, eighth = GetWeaponEnchantInfo()
    local hasMainHandEnchant = NormalizeEnchantPresence(mainRaw)
    local hasOffHandEnchant = NormalizeEnchantPresence(fourth)
    local offHandExpiration = fifth

    -- Some clients may include enchant IDs before the offhand fields. The QA 3.3.5 client
    -- returns numeric 1/0 presence flags, so only switch layouts for non-flag values.
    if fourth ~= nil and fourth ~= true and fourth ~= false and fourth ~= 0 and fourth ~= 1 then
        hasOffHandEnchant = NormalizeEnchantPresence(fifth)
        offHandExpiration = sixth
    elseif seventh ~= nil or eighth ~= nil then
        hasOffHandEnchant = NormalizeEnchantPresence(fifth)
        offHandExpiration = sixth
    end

    if handKey == "off" then
        return hasOffHandEnchant, offHandExpiration
    end

    return hasMainHandEnchant, mainHandExpiration
end

local UpdateImbueReminder

local function CaptureImbueReminderState()
    local mainHas, mainExpiration = GetImbueReminderHandState("main")
    local offHas, offExpiration = GetImbueReminderHandState("off")
    return {
        mainHas = mainHas,
        mainExpiration = tonumber(mainExpiration or 0) or 0,
        offHas = offHas,
        offExpiration = tonumber(offExpiration or 0) or 0,
    }
end

local function DidImbueHandChange(previousHas, previousExpiration, currentHas, currentExpiration)
    previousExpiration = tonumber(previousExpiration or 0) or 0
    currentExpiration = tonumber(currentExpiration or 0) or 0

    if currentHas and not previousHas then
        return true
    end

    if currentHas and previousHas and currentExpiration > previousExpiration + 30000 then
        return true
    end

    return false
end

local function RememberImbueSpellForHand(handKey, spellId)
    if not spellId then
        return
    end

    SetImbueReminderSpellId(handKey, spellId)
    imbueReminderLastState = CaptureImbueReminderState()
    UpdateImbueReminder()
end

local function SaveImbueReminderPosition(frame)
    if not frame or not frame.handKey then
        return
    end

    local pos = GetImbueReminderPositionDB(frame.handKey)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    pos.point = point
    pos.relativePoint = relativePoint
    pos.x = x
    pos.y = y
end

local function PositionImbueReminder(frame, useDefault)
    if not frame or not frame.handKey then
        return
    end

    local pos = GetImbueReminderPositionDB(frame.handKey)
    frame:ClearAllPoints()
    if not useDefault and pos.point and pos.relativePoint and pos.x and pos.y then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    elseif frame.handKey == "off" then
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -452, 150)
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -500, 150)
    end
end

local function UpdateImbueReminderFrame(handKey)
    local frame = imbueReminderFrames[handKey]
    if not frame then
        return
    end

    if imbueReminderSettleRemaining and imbueReminderSettleRemaining > 0 then
        frame:Hide()
        return
    end

    local db = GetImbueReminderDB()
    local spellId = tonumber(GetImbueReminderSpellId(handKey))
    if not db.enabled or not spellId or not GetWeaponEnchantInfo then
        frame:Hide()
        return
    end

    if handKey == "off" and not GetInventoryItemLink("player", 17) then
        frame:Hide()
        return
    end

    local hasEnchant, expiration = GetImbueReminderHandState(handKey)
    local thresholdMs = (tonumber(db.thresholdSeconds or IMBUE_REMINDER_DEFAULT_THRESHOLD_SECONDS) or IMBUE_REMINDER_DEFAULT_THRESHOLD_SECONDS) * 1000
    if hasEnchant and (tonumber(expiration or 0) or 0) > thresholdMs then
        frame:Hide()
        return
    end

    local spellName = spellId and GetSpellInfo(spellId) or "Weapon Imbue"
    frame.spellId = spellId
    if frame.SetAttribute and (not InCombatLockdown or not InCombatLockdown()) then
        local inventorySlot = handKey == "off" and 17 or 16
        frame:SetAttribute("type", "macro")
        frame:SetAttribute("macrotext", "/cast " .. spellName .. "\n/use " .. inventorySlot)
    end
    frame.icon:SetTexture(GetSpellIcon(spellId))
    frame.label:SetText(hasEnchant and FormatDuration((tonumber(expiration or 0) or 0) / 1000) or "!")
    frame.tooltipTitle = (handKey == "off" and "Off-hand " or "Main-hand ") .. (spellName or "Weapon Effect")
    frame.tooltipBody = hasEnchant and "Weapon effect is close to expiring." or "Weapon effect is missing."
    frame:Show()
end

function UpdateImbueReminder()
    UpdateImbueReminderFrame("main")
    UpdateImbueReminderFrame("off")
    if not imbueReminderSettleRemaining or imbueReminderSettleRemaining <= 0 then
        imbueReminderLastState = CaptureImbueReminderState()
    end
end

local function GetResourceFrameWidth()
    if PlayerFrameManaBar and PlayerFrameManaBar.GetWidth then
        local width = PlayerFrameManaBar:GetWidth()
        if width and width > 20 then
            return width
        end
    end

    if PlayerFrameHealthBar and PlayerFrameHealthBar.GetWidth then
        local width = PlayerFrameHealthBar:GetWidth()
        if width and width > 20 then
            return width
        end
    end

    return RESOURCE_FRAME_DEFAULT_WIDTH
end

local function FormatResourceValue(powerType, current, maximum)
    current = tonumber(current or 0) or 0
    maximum = tonumber(maximum or 0) or 0

    if powerType == 1 and maximum > 100 then
        return string.format("%d/%d", math.floor(current / 10 + 0.5), math.floor(maximum / 10 + 0.5))
    end

    return string.format("%d/%d", current, maximum)
end

local function SaveResourceFramePosition()
    if not resourceFrame then
        return
    end

    EnsureSavedVariables()
    local point, _, relativePoint, x, y = resourceFrame:GetPoint(1)
    local db = HybridTalentUIDB.resourceFrame
    db.point = point
    db.relativePoint = relativePoint
    db.x = x
    db.y = y
end

local function PositionResourceFrame(useDefault)
    if not resourceFrame then
        return
    end

    EnsureSavedVariables()
    resourceFrame:ClearAllPoints()
    local db = HybridTalentUIDB.resourceFrame
    if not useDefault and db.point and db.relativePoint and db.x and db.y then
        resourceFrame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    else
        resourceFrame:SetPoint("CENTER", UIParent, "CENTER", -8, -86)
    end
end

local function ResetResourceFramePosition()
    EnsureSavedVariables()
    HybridTalentUIDB.resourceFrame.point = nil
    HybridTalentUIDB.resourceFrame.relativePoint = nil
    HybridTalentUIDB.resourceFrame.x = nil
    HybridTalentUIDB.resourceFrame.y = nil
    PositionResourceFrame(true)
    Print("resource bars position reset.")
end

local function UpdateResourceFrame()
    if not resourceFrame then
        return
    end

    EnsureSavedVariables()
    if not HybridTalentUIDB.resourceFrame.enabled then
        resourceFrame:Hide()
        return
    end

    local width = GetResourceFrameWidth()
    local shown = 0
    for _, info in ipairs(RESOURCE_BARS) do
        local bar = resourceFrame.bars[info.key]
        local current = UnitPower and UnitPower("player", info.powerType) or 0
        local maximum = UnitPowerMax and UnitPowerMax("player", info.powerType) or 0

        current = tonumber(current or 0) or 0
        maximum = tonumber(maximum or 0) or 0
        bar:SetMinMaxValues(0, math.max(maximum, 1))
        bar:SetValue(math.min(current, maximum))
        bar:SetWidth(width)
        bar.text:SetText(info.label .. " " .. FormatResourceValue(info.powerType, current, maximum))
        bar:Show()
        shown = shown + 1
    end

    resourceFrame:SetWidth(width)
    resourceFrame:SetHeight(shown * RESOURCE_BAR_HEIGHT + math.max(0, shown - 1) * RESOURCE_BAR_GAP)
    resourceFrame:Show()
end

local function CreateResourceFrame()
    if resourceFrame then
        return
    end

    resourceFrame = CreateFrame("Frame", "HybridTalentUIResourceFrame", UIParent)
    resourceFrame:SetMovable(true)
    resourceFrame:EnableMouse(true)
    resourceFrame:SetClampedToScreen(true)
    resourceFrame:RegisterForDrag("LeftButton")
    resourceFrame.bars = {}

    local previous
    for _, info in ipairs(RESOURCE_BARS) do
        local bar = CreateFrame("StatusBar", nil, resourceFrame)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(info.color[1], info.color[2], info.color[3])
        SetFrameSize(bar, RESOURCE_FRAME_DEFAULT_WIDTH, RESOURCE_BAR_HEIGHT)
        if previous then
            bar:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -RESOURCE_BAR_GAP)
        else
            bar:SetPoint("TOPLEFT", resourceFrame, "TOPLEFT", 0, 0)
        end

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar.bg:SetVertexColor(info.color[1] * 0.35, info.color[2] * 0.35, info.color[3] * 0.35, 0.85)

        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        bar.text:SetTextColor(1, 1, 1)

        resourceFrame.bars[info.key] = bar
        previous = bar
    end

    PositionResourceFrame(false)
    resourceFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    resourceFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveResourceFramePosition()
    end)
    resourceFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hybrid Resources")
        GameTooltip:AddLine("Drag to move. Use /hyui resources off to hide.", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    resourceFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateResourceFrame()
end

local function DelayImbueReminderRefresh(seconds)
    imbueReminderSettleRemaining = math.max(imbueReminderSettleRemaining or 0, seconds or IMBUE_REMINDER_SETTLE_SECONDS)
    UpdateImbueReminder()
end

local function UpdateImbueReminderForInventoryChange(forceDelay)
    local mainLink = GetInventoryItemLink and GetInventoryItemLink("player", 16) or nil
    local offLink = GetInventoryItemLink and GetInventoryItemLink("player", 17) or nil
    local itemChanged = forceDelay or mainLink ~= imbueReminderLastMainItemLink or offLink ~= imbueReminderLastOffItemLink

    imbueReminderLastMainItemLink = mainLink
    imbueReminderLastOffItemLink = offLink

    if itemChanged then
        DelayImbueReminderRefresh(1.5)
    else
        UpdateImbueReminder()
    end
end

local function DebugImbueReminder()
    if not GetWeaponEnchantInfo then
        Print("GetWeaponEnchantInfo API is unavailable.")
        return
    end

    local a, b, c, d, e, f, g, h = GetWeaponEnchantInfo()
    local mainHas, mainExpiration = GetImbueReminderHandState("main")
    local offHas, offExpiration = GetImbueReminderHandState("off")
    local characterDB = GetImbueReminderCharacterDB()

    Print("raw weapon enchants: 1=" .. tostring(a) .. ", 2=" .. tostring(b) .. ", 3=" .. tostring(c) .. ", 4=" .. tostring(d) .. ", 5=" .. tostring(e) .. ", 6=" .. tostring(f) .. ", 7=" .. tostring(g) .. ", 8=" .. tostring(h))
    Print("parsed imbues: MH=" .. tostring(mainHas) .. " exp=" .. tostring(mainExpiration) .. "; OH=" .. tostring(offHas) .. " exp=" .. tostring(offExpiration))
    Print("remembered spells: character=" .. tostring(GetImbueReminderCharacterKey()) .. "; MH=" .. tostring(characterDB.mainSpellId) .. "; OH=" .. tostring(characterDB.offSpellId) .. "; offhand item=" .. tostring(GetInventoryItemLink and GetInventoryItemLink("player", 17) or nil))
end

local function ResolveImbueSpellId(spellName, spellId)
    if not IsTrackedImbueSpell(spellId, spellName) then
        return nil
    end

    return (spellId and IMBUE_REMINDER_SPELLS[tonumber(spellId)] and tonumber(spellId)) or FindKnownImbueSpellId(spellName)
end

local function FinalizePendingImbueSpell()
    local pending = imbueReminderPendingSpell
    imbueReminderPendingSpell = nil
    if not pending or not pending.spellId then
        return
    end

    if pending.handKey then
        RememberImbueSpellForHand(pending.handKey, pending.spellId)
        return
    end

    local previous = pending.previousState or imbueReminderLastState or {}
    local current = CaptureImbueReminderState()
    local mainChanged = DidImbueHandChange(previous.mainHas, previous.mainExpiration, current.mainHas, current.mainExpiration)
    local offChanged = DidImbueHandChange(previous.offHas, previous.offExpiration, current.offHas, current.offExpiration)

    if mainChanged then
        SetImbueReminderSpellId("main", pending.spellId)
    end
    if offChanged then
        SetImbueReminderSpellId("off", pending.spellId)
    end

    if not mainChanged and not offChanged then
        if GetInventoryItemLink("player", 17) then
            SetImbueReminderSpellId("main", pending.spellId)
        else
            SetImbueReminderSpellId("main", pending.spellId)
        end
    end

    imbueReminderLastState = current
    UpdateImbueReminder()
end

local function StoreLastImbueSpell(spellName, spellId)
    local rememberedSpellId = ResolveImbueSpellId(spellName, spellId)
    if not rememberedSpellId then
        return
    end

    imbueReminderPendingSpell = {
        spellId = rememberedSpellId,
        handKey = imbueReminderClickedHand and imbueReminderClickedHand.handKey or nil,
        previousState = imbueReminderLastState or CaptureImbueReminderState(),
        remaining = IMBUE_REMINDER_APPLY_SETTLE_SECONDS,
    }
    imbueReminderClickedHand = nil
end

local function CreateImbueReminderFrame(handKey)
    if imbueReminderFrames[handKey] then
        return
    end

    local frameName = handKey == "off" and "HybridTalentUIOffhandImbueReminder" or "HybridTalentUIMainhandImbueReminder"
    local frame = CreateFrame("Button", frameName, UIParent, "SecureActionButtonTemplate")
    frame.handKey = handKey
    SetFrameSize(frame, 42, 42)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    frame.border:SetBlendMode("ADD")
    SetFrameSize(frame.border, 70, 70)
    frame.border:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.handLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.handLabel:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.handLabel:SetText(handKey == "off" and "OH" or "MH")
    frame.handLabel:SetTextColor(1, 0.9, 0.25)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    frame.label:SetTextColor(1, 0.9, 0.25)

    imbueReminderFrames[handKey] = frame
    PositionImbueReminder(frame, false)

    frame:SetScript("PreClick", function(self)
        imbueReminderClickedHand = { handKey = self.handKey, remaining = 2 }
    end)
    frame:SetScript("PostClick", function()
        UpdateImbueReminder()
    end)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveImbueReminderPosition(self)
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipTitle or "Weapon Effect")
        GameTooltip:AddLine(self.tooltipBody or "Your remembered weapon effect needs attention.", 0.95, 0.82, 0.35)
        GameTooltip:AddLine("Click to cast. Drag to move.", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        imbueReminderPulse = imbueReminderPulse + (elapsed or 0)
        if imbueReminderPulse > 0.8 then
            imbueReminderPulse = 0
        end
        self.border:SetAlpha(0.45 + (math.sin(imbueReminderPulse * 7.85) * 0.25))
    end)
end

local function PositionOpenButton(useDefault)
    if not openButton then
        return
    end

    EnsureSavedVariables()
    openButton:ClearAllPoints()

    local pos = HybridTalentUIDB.openButton
    if not useDefault and pos.point and pos.relativePoint and pos.x and pos.y then
        openButton:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        openButton:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -430, 116)
    end
end

local function SaveOpenButtonPosition()
    if not openButton then
        return
    end

    EnsureSavedVariables()
    local point, _, relativePoint, x, y = openButton:GetPoint(1)
    HybridTalentUIDB.openButton.point = point
    HybridTalentUIDB.openButton.relativePoint = relativePoint
    HybridTalentUIDB.openButton.x = x
    HybridTalentUIDB.openButton.y = y
end

local function ResetOpenButtonPosition()
    EnsureSavedVariables()
    HybridTalentUIDB.openButton = {}
    PositionOpenButton(true)
    Print("Hybrid button position reset.")
end

local function CreateOpenButton()
    if openButton then
        return
    end

    openButton = CreateFrame("Button", "HybridTalentUIMicroButton", UIParent, "UIPanelButtonTemplate")
    SetFrameSize(openButton, 64, 22)
    openButton:SetText("Hybrid")
    openButton:SetMovable(true)
    openButton:EnableMouse(true)
    openButton:SetClampedToScreen(true)
    openButton:RegisterForDrag("LeftButton")

    PositionOpenButton(false)

    openButton:SetScript("OnClick", ToggleMainFrame)
    openButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    openButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOpenButtonPosition()
    end)
    openButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Hybrid Training")
        GameTooltip:AddLine("Click to open. Drag to move.", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    openButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function HandleSlash(input)
    input = string.lower(input or "")

    local spellId = string.match(input, "^learn%s+(%d+)$")
    if spellId then
        SendCommand("hybridui learn " .. spellId)
        return
    end

    spellId = string.match(input, "^unlearn%s+(%d+)$")
    if spellId then
        SendCommand("hybridui unlearn " .. spellId)
        return
    end

    if input == "petdebug" or input == "pet debug" then
        DebugPetActions()
        return
    end

    if input == "resetbutton" or input == "reset button" then
        ResetOpenButtonPosition()
        return
    end

    if input == "resources" or input == "resource" then
        EnsureSavedVariables()
        local db = HybridTalentUIDB.resourceFrame
        Print("resource bars are " .. (db.enabled and "on" or "off") .. ".")
        return
    end

    if input == "resources on" or input == "resource on" then
        EnsureSavedVariables()
        HybridTalentUIDB.resourceFrame.enabled = true
        CreateResourceFrame()
        UpdateResourceFrame()
        Print("resource bars enabled.")
        return
    end

    if input == "resources off" or input == "resource off" then
        EnsureSavedVariables()
        HybridTalentUIDB.resourceFrame.enabled = false
        if resourceFrame then
            resourceFrame:Hide()
        end
        Print("resource bars disabled.")
        return
    end

    if input == "resources reset" or input == "resource reset" then
        ResetResourceFramePosition()
        UpdateResourceFrame()
        return
    end

    if input == "imbue" or input == "poison" or input == "weapon" then
        local db = GetImbueReminderDB()
        local characterDB = GetImbueReminderCharacterDB()
        local mainSpellName = characterDB.mainSpellId and GetSpellInfo(characterDB.mainSpellId) or "none remembered"
        local offSpellName = characterDB.offSpellId and GetSpellInfo(characterDB.offSpellId) or "none remembered"
        Print("weapon reminder is " .. (db.enabled and "on" or "off") .. "; main-hand spell: " .. tostring(mainSpellName) .. "; off-hand spell: " .. tostring(offSpellName) .. "; threshold: " .. tostring(db.thresholdSeconds) .. " seconds.")
        return
    end

    if input == "imbue debug" or input == "poison debug" or input == "weapon debug" then
        DebugImbueReminder()
        return
    end

    if input == "imbue on" or input == "poison on" or input == "weapon on" then
        GetImbueReminderDB().enabled = true
        UpdateImbueReminder()
        Print("weapon reminder enabled.")
        return
    end

    if input == "imbue off" or input == "poison off" or input == "weapon off" then
        GetImbueReminderDB().enabled = false
        UpdateImbueReminder()
        Print("weapon reminder disabled.")
        return
    end

    if input == "imbue reset" or input == "poison reset" or input == "weapon reset" then
        local db = GetImbueReminderDB()
        local characterDB = GetImbueReminderCharacterDB()
        characterDB.mainSpellId = nil
        characterDB.offSpellId = nil
        db.point = nil
        db.relativePoint = nil
        db.x = nil
        db.y = nil
        db.offhand = {}
        PositionImbueReminder(imbueReminderFrames.main, true)
        PositionImbueReminder(imbueReminderFrames.off, true)
        UpdateImbueReminder()
        Print("weapon reminder reset.")
        return
    end

    local imbueThreshold = string.match(input, "^imbue%s+threshold%s+(%d+)$") or string.match(input, "^poison%s+threshold%s+(%d+)$") or string.match(input, "^weapon%s+threshold%s+(%d+)$")
    if imbueThreshold then
        local seconds = math.max(30, tonumber(imbueThreshold) or IMBUE_REMINDER_DEFAULT_THRESHOLD_SECONDS)
        GetImbueReminderDB().thresholdSeconds = seconds
        UpdateImbueReminder()
        Print("weapon reminder threshold set to " .. seconds .. " seconds.")
        return
    end

    local petSlot = string.match(input, "^petcast%s+(%d+)$")
    if petSlot then
        petSlot = tonumber(petSlot)
        if CastPetAction and petSlot and petSlot >= 1 and petSlot <= 10 then
            CastPetAction(petSlot)
            Print("requested pet action slot " .. petSlot)
        else
            Print("pet action slot must be 1-10.")
        end
        return
    end

    ToggleMainFrame()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("UNIT_MANA")
eventFrame:RegisterEvent("UNIT_RAGE")
eventFrame:RegisterEvent("UNIT_ENERGY")
eventFrame:RegisterEvent("UNIT_MAXMANA")
eventFrame:RegisterEvent("UNIT_MAXRAGE")
eventFrame:RegisterEvent("UNIT_MAXENERGY")
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsed = elapsed or 0
    if imbueReminderSettleRemaining and imbueReminderSettleRemaining > 0 then
        imbueReminderSettleRemaining = imbueReminderSettleRemaining - elapsed
        if imbueReminderSettleRemaining <= 0 then
            imbueReminderSettleRemaining = 0
            UpdateImbueReminder()
        end
    end

    if imbueReminderClickedHand then
        imbueReminderClickedHand.remaining = (imbueReminderClickedHand.remaining or 0) - elapsed
        if imbueReminderClickedHand.remaining <= 0 then
            imbueReminderClickedHand = nil
        end
    end

    if imbueReminderPendingSpell then
        imbueReminderPendingSpell.remaining = (imbueReminderPendingSpell.remaining or 0) - elapsed
        if imbueReminderPendingSpell.remaining <= 0 then
            FinalizePendingImbueSpell()
        end
    end

    imbueReminderElapsed = imbueReminderElapsed + elapsed
    if imbueReminderElapsed >= 10 then
        imbueReminderElapsed = 0
        UpdateImbueReminder()
        UpdateResourceFrame()
    end
end)

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SLASH_HYBRIDTALENTUI1 = "/hybridui"
        SLASH_HYBRIDTALENTUI2 = "/hyui"
        SlashCmdList.HYBRIDTALENTUI = HandleSlash
        HookGlobalSpellTooltipNotes()
        CreateOpenButton()
        CreateImbueReminderFrame("main")
        CreateImbueReminderFrame("off")
        CreateResourceFrame()
        imbueReminderLastMainItemLink = GetInventoryItemLink and GetInventoryItemLink("player", 16) or nil
        imbueReminderLastOffItemLink = GetInventoryItemLink and GetInventoryItemLink("player", 17) or nil
        DelayImbueReminderRefresh(IMBUE_REMINDER_SETTLE_SECONDS)
        Print("loaded. Click the Hybrid button or use /hybridui.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateResourceFrame()
    elseif event == "PLAYER_LEVEL_UP" then
        state.loaded = false
        UpdateResourceFrame()
        if mainFrame and mainFrame:IsVisible() then
            Refresh()
        end
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName, _, _, spellId = ...
        if unit == "player" then
            StoreLastImbueSpell(spellName, spellId)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        UpdateImbueReminderForInventoryChange(false)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            UpdateImbueReminderForInventoryChange(false)
        end
    elseif event == "UNIT_DISPLAYPOWER" or event == "UNIT_MANA" or event == "UNIT_RAGE" or event == "UNIT_ENERGY" or event == "UNIT_MAXMANA" or event == "UNIT_MAXRAGE" or event == "UNIT_MAXENERGY" then
        local unit = ...
        if unit == "player" then
            UpdateResourceFrame()
        end
    end
end)
