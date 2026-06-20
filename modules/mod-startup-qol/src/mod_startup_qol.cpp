#include "Chat.h"
#include "Config.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldScript.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <sstream>
#include <string>
#include <vector>

namespace
{
struct ItemGrant
{
    uint32 Entry;
    uint32 Count;
};

bool Enabled = true;
bool NotifyPlayer = true;
bool LearnWeaponSkills = true;
bool LearnArmorSkills = true;
uint32 MoneyCopper = 200000000;
std::vector<uint32> RidingSpells;
std::vector<uint32> MountSpells;
std::vector<ItemGrant> Items;

constexpr std::array<uint16, 16> WeaponSkills =
{{
    SKILL_SWORDS,
    SKILL_AXES,
    SKILL_BOWS,
    SKILL_GUNS,
    SKILL_MACES,
    SKILL_2H_SWORDS,
    SKILL_STAVES,
    SKILL_2H_MACES,
    SKILL_UNARMED,
    SKILL_2H_AXES,
    SKILL_DAGGERS,
    SKILL_THROWN,
    SKILL_CROSSBOWS,
    SKILL_WANDS,
    SKILL_POLEARMS,
    SKILL_FIST_WEAPONS
}};

constexpr std::array<uint16, 5> ArmorSkills =
{{
    SKILL_CLOTH,
    SKILL_LEATHER,
    SKILL_MAIL,
    SKILL_PLATE_MAIL,
    SKILL_SHIELD
}};

std::string Trim(std::string value)
{
    value.erase(value.begin(), std::find_if(value.begin(), value.end(), [](unsigned char ch) { return !std::isspace(ch); }));
    value.erase(std::find_if(value.rbegin(), value.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), value.end());
    return value;
}

bool ParseUInt(std::string const& value, uint32& result)
{
    try
    {
        std::size_t parsed = 0;
        unsigned long number = std::stoul(value, &parsed, 10);
        if (parsed != value.size())
            return false;

        result = static_cast<uint32>(number);
        return true;
    }
    catch (...)
    {
        return false;
    }
}

std::vector<uint32> ParseUIntList(std::string const& raw)
{
    std::vector<uint32> values;
    std::stringstream stream(raw);
    std::string token;

    while (std::getline(stream, token, ','))
    {
        token = Trim(token);
        if (token.empty())
            continue;

        uint32 value = 0;
        if (ParseUInt(token, value) && value)
            values.push_back(value);
    }

    return values;
}

std::vector<ItemGrant> ParseItemList(std::string const& raw)
{
    std::vector<ItemGrant> values;
    std::stringstream stream(raw);
    std::string token;

    while (std::getline(stream, token, ','))
    {
        token = Trim(token);
        if (token.empty())
            continue;

        uint32 entry = 0;
        uint32 count = 1;
        std::size_t separator = token.find(':');

        if (separator == std::string::npos)
        {
            if (!ParseUInt(token, entry))
                continue;
        }
        else
        {
            if (!ParseUInt(Trim(token.substr(0, separator)), entry))
                continue;
            if (!ParseUInt(Trim(token.substr(separator + 1)), count))
                continue;
        }

        if (entry && count)
            values.push_back({ entry, count });
    }

    return values;
}

void LearnConfiguredSpells(Player* player, std::vector<uint32> const& spellIds)
{
    for (uint32 spellId : spellIds)
    {
        if (player->HasSpell(spellId))
            continue;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo || !SpellMgr::IsSpellValid(spellInfo))
            continue;

        player->learnSpell(spellId, false);
    }
}

void GrantItems(Player* player)
{
    for (ItemGrant const& item : Items)
        player->AddItem(item.Entry, item.Count);
}

void GrantWeaponSkills(Player* player)
{
    uint16 maxValue = std::max<uint16>(player->GetMaxSkillValueForLevel(), 1);

    for (uint16 skill : WeaponSkills)
        player->SetSkill(skill, 0, maxValue, maxValue);
}

void GrantArmorSkills(Player* player)
{
    for (uint16 skill : ArmorSkills)
        player->SetSkill(skill, 0, 1, 1);
}

void GrantStartupPackage(Player* player)
{
    LearnConfiguredSpells(player, RidingSpells);
    LearnConfiguredSpells(player, MountSpells);
    GrantItems(player);

    if (MoneyCopper)
        player->ModifyMoney(static_cast<int32>(MoneyCopper));

    if (LearnWeaponSkills)
        GrantWeaponSkills(player);

    if (LearnArmorSkills)
        GrantArmorSkills(player);

    if (NotifyPlayer)
        ChatHandler(player->GetSession()).SendNotification("Startup QoL package granted.");
}
}

class startup_qol_worldscript : public WorldScript
{
public:
    startup_qol_worldscript() : WorldScript("startup_qol_worldscript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        Enabled = sConfigMgr->GetOption<bool>("StartupQoL.Enable", true);
        NotifyPlayer = sConfigMgr->GetOption<bool>("StartupQoL.NotifyPlayer", true);
        LearnWeaponSkills = sConfigMgr->GetOption<bool>("StartupQoL.LearnWeaponSkills", true);
        LearnArmorSkills = sConfigMgr->GetOption<bool>("StartupQoL.LearnArmorSkills", true);
        MoneyCopper = sConfigMgr->GetOption<uint32>("StartupQoL.MoneyCopper", 200000000);
        RidingSpells = ParseUIntList(sConfigMgr->GetOption<std::string>("StartupQoL.RidingSpells", "33388,33391,34090,34091,54197"));
        MountSpells = ParseUIntList(sConfigMgr->GetOption<std::string>("StartupQoL.MountSpells", "58983,61425,17229,72808,60021,69395,32345,40192"));
        Items = ParseItemList(sConfigMgr->GetOption<std::string>("StartupQoL.Items", "23162:4"));
    }
};

class startup_qol_playerscript : public PlayerScript
{
public:
    startup_qol_playerscript() : PlayerScript("startup_qol_playerscript") { }

    void OnPlayerFirstLogin(Player* player) override
    {
        if (Enabled)
            GrantStartupPackage(player);
    }
};

void AddStartupQoLScripts()
{
    new startup_qol_worldscript();
    new startup_qol_playerscript();
}
