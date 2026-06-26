local PREFIX = "AzerothCore"

local state = {
    commandCounter = 0,
    earned = 0,
    spent = 0,
    available = 0,
    rows = {},
}

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66d9efHybridTalentUI:|r " .. tostring(message))
    end
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
    SendCommand("hybridui refresh")
end

local function PrintSummary()
    Print("points: " .. state.available .. " available / " .. state.earned .. " earned")

    local shown = 0
    for _, row in ipairs(state.rows) do
        if shown >= 12 then
            break
        end

        local status = row.known and "known" or (row.canLearn and "available" or "locked")
        Print(row.spellId .. " - " .. row.name .. " [" .. status .. ", level " .. row.requiredLevel .. ", cost " .. row.cost .. "]")
        shown = shown + 1
    end

    if #state.rows > shown then
        Print("showing " .. shown .. " of " .. #state.rows .. " spells")
    elseif #state.rows == 0 then
        Print("no spells received from server")
    end
end

local function AddSpell(parts)
    local row = {
        spellId = tonumber(parts[3] or "0") or 0,
        requiredLevel = tonumber(parts[5] or "1") or 1,
        cost = tonumber(parts[6] or "1") or 1,
        known = parts[7] == "1",
        canLearn = parts[8] == "1",
        name = parts[9] or "",
        description = parts[10] or "",
    }

    if row.spellId > 0 then
        table.insert(state.rows, row)
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
    elseif parts[2] == "SPELL" then
        AddSpell(parts)
    elseif parts[2] == "END" then
        PrintSummary()
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

    Refresh()
    Print("requested server spell list")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SLASH_HYBRIDTALENTUI1 = "/hybridui"
        SLASH_HYBRIDTALENTUI2 = "/hyui"
        SlashCmdList.HYBRIDTALENTUI = HandleSlash
        Print("loaded. Use /hybridui to request the dev spell list.")
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    end
end)
