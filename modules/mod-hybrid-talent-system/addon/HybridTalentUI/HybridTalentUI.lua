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
    rows = {},
    byClass = {},
    selectedClass = 1,
    page = 1,
    loaded = false,
    filter = "all",
    search = "",
    selectedSpell = nil,
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
local ROWS_PER_PAGE = 9
local FILTERS = {
    { key = "all", label = "All" },
    { key = "available", label = "Available" },
    { key = "known", label = "Known" },
    { key = "locked", label = "Locked" },
}
local filterButtons = {}

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

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66d9efHybridTalentUI:|r " .. tostring(message))
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
    state.byClass = {}
    state.loaded = false
    SendCommand("hybridui refresh")
end

local function GetVisibleRows()
    local result = {}
    local search = string.lower(state.search or "")

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

        if classMatch and filterMatch and searchMatch then
            table.insert(result, row)
        end
    end
    return result
end

local function SetSelectedClass(index)
    state.selectedClass = index
    state.page = 1
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
        local count = state.byClass[index] or 0
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
        if button.filterKey == state.filter then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

local function GetSelectedRow()
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
        mainFrame.detailName:SetText("Select a spell")
        mainFrame.detailMeta:SetText("")
        mainFrame.detailDesc:SetText("Left-click an available spell to learn it. Right-click a known spell to unlearn it.")
        mainFrame.detailReason:SetText("")
        return
    end

    mainFrame.detailIcon:SetTexture(GetSpellIcon(row.spellId))
    mainFrame.detailName:SetText(row.name)
    mainFrame.detailMeta:SetText("Spell ID " .. row.spellId .. "  Level " .. row.requiredLevel .. "  Cost " .. row.cost)
    mainFrame.detailDesc:SetText(row.description ~= "" and row.description or "No description available.")
    mainFrame.detailReason:SetText(row.reason or "")
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

    mainFrame.points:SetText("Hybrid points: " .. state.available .. " available / " .. state.earned .. " earned")
    mainFrame.status:SetText("Level " .. state.level .. "  Unlock " .. state.minLevel .. "  +" .. state.pointsPerInterval .. " point / " .. state.interval .. " levels  Max " .. state.maxPoints)
    mainFrame.page:SetText("Page " .. state.page .. " / " .. pageCount)

    for rowIndex = 1, ROWS_PER_PAGE do
        local button = rowButtons[rowIndex]
        local data = rows[startIndex + rowIndex - 1]
        button.data = data

        if data then
            button.icon:SetTexture(GetSpellIcon(data.spellId))
            button.name:SetText(data.name)
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

            button:Show()
        else
            button:Hide()
        end
    end

    if #rows == 0 then
        if state.filter == "known" then
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

local function HandleServerMessage(body)
    local parts = SplitTabs(body)
    if parts[1] ~= "HYUI" then
        return
    end

    if parts[2] == "BEGIN" then
        state.earned = tonumber(parts[4] or "0") or 0
        state.spent = tonumber(parts[5] or "0") or 0
        state.available = tonumber(parts[6] or "0") or 0
        state.rows = {}
        state.byClass = {}
        state.loaded = false
    elseif parts[2] == "SPELL" then
        AddSpell(parts)
    elseif parts[2] == "STATUS" then
        state.level = tonumber(parts[3] or "0") or 0
        state.minLevel = tonumber(parts[4] or "0") or 0
        state.pointsPerInterval = tonumber(parts[5] or "0") or 0
        state.interval = tonumber(parts[6] or "0") or 0
        state.maxPoints = tonumber(parts[7] or "0") or 0
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

        ShowSpellTooltip(self, self.data)
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
        ShowSpellTooltip(self, GetSelectedRow())
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

local function CreateOpenButton()
    if openButton then
        return
    end

    openButton = CreateFrame("Button", "HybridTalentUIMicroButton", UIParent, "UIPanelButtonTemplate")
    SetFrameSize(openButton, 64, 22)
    openButton:SetText("Hybrid")

    if CharacterMicroButton then
        openButton:SetPoint("LEFT", CharacterMicroButton, "RIGHT", 4, 0)
    else
        openButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -8)
    end

    openButton:SetScript("OnClick", ToggleMainFrame)
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
