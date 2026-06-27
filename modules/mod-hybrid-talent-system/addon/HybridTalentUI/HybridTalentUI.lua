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

local function GetSpellIcon(spellId)
    local _, _, icon = GetSpellInfo(spellId)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ShowSpellTooltip(owner, row)
    if not owner or not row then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("spell:" .. row.spellId)
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
                or string.find(string.lower(row.name or ""), search, 1, true)
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
            or string.find(string.lower(row.name or ""), search, 1, true)
            or string.find(string.lower(row.description or ""), search, 1, true)
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
        mainFrame.detailDesc:SetText("Talent ID " .. row.talentId .. "  Spell ID " .. row.spellId .. "  Rank " .. row.knownRank .. "/" .. row.maxRank .. "  Cost 1")
        mainFrame.detailReason:SetText(row.reason or "Browse only")
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
        mainFrame.status:SetText("Level " .. state.level .. "  Unlock " .. state.talentMinLevel .. "  +" .. state.talentPointsPerInterval .. " point / " .. state.talentInterval .. " levels  Max " .. state.talentMaxPoints)
    else
        mainFrame.points:SetText("Hybrid points: " .. state.available .. " available / " .. state.earned .. " earned")
        mainFrame.status:SetText("Level " .. state.level .. "  Unlock " .. state.minLevel .. "  +" .. state.pointsPerInterval .. " point / " .. state.interval .. " levels  Max " .. state.maxPoints)
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
                button.desc:SetText("Rank " .. data.knownRank .. "/" .. data.maxRank .. "  Cost 1")
                button.reason:SetText(data.reason or "")
                if data.knownRank >= data.maxRank then
                    button.status:SetText("Known")
                    button.status:SetTextColor(0.25, 0.9, 0.35)
                elseif data.canLearn then
                    button.status:SetText("Available")
                    button.status:SetTextColor(0.95, 0.82, 0.35)
                elseif data.knownRank > 0 then
                    button.status:SetText("Partial")
                    button.status:SetTextColor(0.6, 0.8, 1)
                else
                    button.status:SetText("Locked")
                    button.status:SetTextColor(0.6, 0.6, 0.6)
                end
            else
                button.meta:SetText("Level " .. data.requiredLevel .. "  Cost " .. data.cost)
                button.desc:SetText(data.description ~= "" and data.description or "No description available.")
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
    local classIndex = (tonumber(parts[4] or "0") or 0) + 1
    local row = {
        spellId = tonumber(parts[3] or "0") or 0,
        classIndex = classIndex,
        requiredLevel = tonumber(parts[5] or "1") or 1,
        cost = tonumber(parts[6] or "1") or 1,
        known = parts[7] == "1",
        canLearn = parts[8] == "1",
        name = parts[9] or "",
        description = parts[10] or "",
        reason = parts[11] or "",
    }

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
    elseif parts[2] == "TALENTSTATUS" then
        state.talentEarned = tonumber(parts[3] or "0") or 0
        state.talentSpent = tonumber(parts[4] or "0") or 0
        state.talentAvailable = tonumber(parts[5] or "0") or 0
        state.talentMinLevel = tonumber(parts[6] or "0") or 0
        state.talentPointsPerInterval = tonumber(parts[7] or "0") or 0
        state.talentInterval = tonumber(parts[8] or "0") or 0
        state.talentMaxPoints = tonumber(parts[9] or "0") or 0
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
            Print(row.name .. " is locked or unaffordable.")
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
        Print(row.name .. " is locked or unaffordable.")
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
        if not state.loaded then
            Refresh()
        else
            UpdateRows()
        end
    end
end

local function EnsureSavedVariables()
    HybridTalentUIDB = HybridTalentUIDB or {}
    HybridTalentUIDB.openButton = HybridTalentUIDB.openButton or {}
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
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SLASH_HYBRIDTALENTUI1 = "/hybridui"
        SLASH_HYBRIDTALENTUI2 = "/hyui"
        SlashCmdList.HYBRIDTALENTUI = HandleSlash
        CreateOpenButton()
        Print("loaded. Click the Hybrid button or use /hybridui.")
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    end
end)
