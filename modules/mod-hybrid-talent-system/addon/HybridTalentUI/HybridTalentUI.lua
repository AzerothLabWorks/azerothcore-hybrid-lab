local ADDON_NAME = ...
local PREFIX = "AzerothCore"
local COMMAND_PREFIX = "AzerothCore"

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
    loaded = false,
    earned = 0,
    spent = 0,
    available = 0,
    selectedClass = 1,
    query = "",
    rows = {},
    byClass = {},
    commandCounter = 0,
}

local frame
local rows = {}
local classButtons = {}
local offset = 0
local ROW_COUNT = 11

local function SetFrameSize(target, width, height)
    target:SetWidth(width)
    target:SetHeight(height)
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

local function RegisterPrefix()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end
end

local function SendCommand(command)
    if not SendAddonMessage then
        DEFAULT_CHAT_FRAME:AddMessage("HybridTalentUI: SendAddonMessage is unavailable.")
        return
    end

    RegisterPrefix()
    SendAddonMessage(PREFIX, "i" .. NextCounter() .. command, "WHISPER", UnitName("player"))
end

local function Refresh()
    state.rows = {}
    state.byClass = {}
    state.loaded = false
    SendCommand("hybridui refresh")
end

local function RowMatches(row)
    if row.classIndex ~= state.selectedClass then
        return false
    end

    if state.query == "" then
        return true
    end

    local query = string.lower(state.query)
    return string.find(string.lower(row.name or ""), query, 1, true)
        or string.find(string.lower(row.description or ""), query, 1, true)
end

local function GetVisibleRows()
    local visible = {}
    for _, row in ipairs(state.rows) do
        if RowMatches(row) then
            table.insert(visible, row)
        end
    end
    return visible
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

local function UpdateRows()
    if not frame then
        return
    end

    frame.points:SetText("Hybrid points: " .. state.available .. " available / " .. state.earned .. " earned")

    local visible = GetVisibleRows()
    if offset > math.max(0, #visible - ROW_COUNT) then
        offset = math.max(0, #visible - ROW_COUNT)
    end

    for i = 1, ROW_COUNT do
        local rowFrame = rows[i]
        local data = visible[offset + i]
        if data then
            rowFrame.data = data
            rowFrame.icon:SetTexture(GetSpellTexture(data.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark")
            rowFrame.name:SetText(data.name)
            rowFrame.meta:SetText("Level " .. data.requiredLevel .. "  Cost " .. data.cost)
            rowFrame.description:SetText(data.description ~= "" and data.description or "No description available.")

            if data.known then
                rowFrame.action:SetText("Unlearn")
                rowFrame.action:Enable()
                rowFrame.status:SetText("Known")
                rowFrame.status:SetTextColor(0.3, 0.9, 0.45)
            elseif data.canLearn then
                rowFrame.action:SetText("Learn")
                rowFrame.action:Enable()
                rowFrame.status:SetText("Available")
                rowFrame.status:SetTextColor(0.95, 0.82, 0.35)
            else
                rowFrame.action:SetText("Locked")
                rowFrame.action:Disable()
                rowFrame.status:SetText("Locked")
                rowFrame.status:SetTextColor(0.65, 0.65, 0.65)
            end

            rowFrame:Show()
        else
            rowFrame.data = nil
            rowFrame:Hide()
        end
    end

    if #visible == 0 then
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
    frame.page:SetText(#visible == 0 and "0 / 0" or ((offset + 1) .. "-" .. math.min(offset + ROW_COUNT, #visible) .. " / " .. #visible))
    UpdateClassButtons()
end

local function SelectClass(index)
    state.selectedClass = index
    offset = 0
    UpdateRows()
end

local function AddSpell(parts)
    local classIndex = tonumber(parts[4] or "0") or 0
    local row = {
        spellId = tonumber(parts[3] or "0") or 0,
        classIndex = classIndex + 1,
        requiredLevel = tonumber(parts[5] or "1") or 1,
        cost = tonumber(parts[6] or "1") or 1,
        known = parts[7] == "1",
        canLearn = parts[8] == "1",
        name = parts[9] or "",
        description = parts[10] or "",
    }

    if row.spellId > 0 and CLASS_NAMES[row.classIndex] then
        table.insert(state.rows, row)
        state.byClass[row.classIndex] = (state.byClass[row.classIndex] or 0) + 1
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
    elseif parts[2] == "END" then
        state.loaded = true
        UpdateRows()
    elseif parts[2] == "ERROR" then
        DEFAULT_CHAT_FRAME:AddMessage("HybridTalentUI: " .. (parts[3] or "Server error."))
    end
end

local function HandleAddonMessage(message)
    if string.sub(message, 1, 12) ~= COMMAND_PREFIX .. "\t" then
        return
    end

    local opcode = string.sub(message, 13, 13)
    if opcode ~= "m" then
        return
    end

    local body = string.sub(message, 18)
    HandleServerMessage(body)
end

local function DoAction(row)
    if not row then
        return
    end

    if row.known then
        SendCommand("hybridui unlearn " .. row.spellId)
    elseif row.canLearn then
        SendCommand("hybridui learn " .. row.spellId)
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    SetFrameSize(row, 660, 42)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -96 - (index - 1) * 46)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    SetFrameSize(row.icon, 32, 32)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.meta:SetWidth(150)
    row.meta:SetJustifyH("LEFT")

    row.description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.description:SetPoint("LEFT", row.icon, "RIGHT", 170, 0)
    row.description:SetWidth(270)
    row.description:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", -92, 0)
    row.status:SetWidth(74)
    row.status:SetJustifyH("RIGHT")

    row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    SetFrameSize(row.action, 78, 22)
    row.action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.action:SetScript("OnClick", function(self)
        DoAction(self:GetParent().data)
    end)

    row:SetScript("OnEnter", function(self)
        if not self.data then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.data.spellId)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

local function CreateUI()
    frame = CreateFrame("Frame", "HybridTalentUIFrame", UIParent)
    SetFrameSize(frame, 760, 650)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -18)
    frame.title:SetText("Hybrid Training")

    frame.points = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.points:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -22)
    frame.points:SetJustifyH("RIGHT")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    SetFrameSize(frame.search, 180, 24)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -52)
    frame.search:SetAutoFocus(false)
    frame.search:SetText("")
    frame.search:SetScript("OnTextChanged", function(self)
        state.query = self:GetText() or ""
        offset = 0
        UpdateRows()
    end)

    frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    SetFrameSize(frame.refresh, 82, 24)
    frame.refresh:SetPoint("LEFT", frame.search, "RIGHT", 12, 0)
    frame.refresh:SetText("Refresh")
    frame.refresh:SetScript("OnClick", Refresh)

    for i, name in ipairs(CLASS_NAMES) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        SetFrameSize(button, 132, 22)
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + col * 140, -84 - row * 26)
        button:SetText(name)
        button:SetScript("OnClick", function()
            SelectClass(i)
        end)
        classButtons[i] = button
    end

    for i = 1, ROW_COUNT do
        rows[i] = CreateRow(frame, i)
    end

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("CENTER", frame, "CENTER", 0, -20)
    frame.empty:SetText("No spells match this view.")

    frame.prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    SetFrameSize(frame.prev, 70, 24)
    frame.prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 22)
    frame.prev:SetText("Prev")
    frame.prev:SetScript("OnClick", function()
        offset = math.max(0, offset - ROW_COUNT)
        UpdateRows()
    end)

    frame.page = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.page:SetPoint("LEFT", frame.prev, "RIGHT", 12, 0)
    frame.page:SetWidth(120)

    frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    SetFrameSize(frame.next, 70, 24)
    frame.next:SetPoint("LEFT", frame.page, "RIGHT", 12, 0)
    frame.next:SetText("Next")
    frame.next:SetScript("OnClick", function()
        offset = offset + ROW_COUNT
        UpdateRows()
    end)

    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta < 0 then
            offset = offset + 3
        else
            offset = math.max(0, offset - 3)
        end
        UpdateRows()
    end)
    frame:EnableMouseWheel(true)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        CreateUI()
        RegisterPrefix()
        SLASH_HYBRIDTALENTUI1 = "/hybridui"
        SLASH_HYBRIDTALENTUI2 = "/hyui"
        SlashCmdList.HYBRIDTALENTUI = function()
            if not frame then
                CreateUI()
            end
            if frame:IsShown() then
                frame:Hide()
            else
                frame:Show()
                Refresh()
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix == PREFIX then
            HandleAddonMessage(PREFIX .. "\t" .. message)
        end
    end
end)
