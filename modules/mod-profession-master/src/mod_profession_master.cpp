#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DBCEnums.h"
#include "DBCStores.h"
#include "GossipDef.h"
#include "Item.h"
#include "ItemScript.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"
#include "WorldScript.h"

#include <algorithm>
#include <array>
#include <cstdint>
#include <string>

namespace
{
constexpr uint32 ACTION_LEARN_PROFESSION = 1000;
constexpr uint32 ACTION_SKILL_UP = 2000;
constexpr uint32 ACTION_LEARN_RECIPES = 3000;
constexpr uint32 ACTION_BACK = 9000;
constexpr uint32 ACTION_DISMISS = 9001;

struct ProfessionTemplate
{
    uint32 SkillId;
    uint32 BaseSpellId;
    char const* Name;
    bool Primary;
};

std::array<ProfessionTemplate, 14> const Professions =
{{
    { SKILL_ALCHEMY,       2259,  "Alchemy",       true  },
    { SKILL_BLACKSMITHING, 2018,  "Blacksmithing", true  },
    { SKILL_ENCHANTING,    7411,  "Enchanting",    true  },
    { SKILL_ENGINEERING,   4036,  "Engineering",   true  },
    { SKILL_HERBALISM,     2366,  "Herbalism",     true  },
    { SKILL_INSCRIPTION,   45357, "Inscription",   true  },
    { SKILL_JEWELCRAFTING, 25229, "Jewelcrafting", true  },
    { SKILL_LEATHERWORKING,2108,  "Leatherworking",true  },
    { SKILL_MINING,        2575,  "Mining",        true  },
    { SKILL_SKINNING,      8613,  "Skinning",      true  },
    { SKILL_TAILORING,     3908,  "Tailoring",     true  },
    { SKILL_COOKING,       2550,  "Cooking",       false },
    { SKILL_FIRST_AID,     3273,  "First Aid",     false },
    { SKILL_FISHING,       7620,  "Fishing",       false }
}};

bool Enabled = true;
uint32 TrainerNpcEntry = 190020;
uint32 BeaconItemEntry = 900020;
bool GrantBeaconOnLogin = true;
uint32 BeaconSummonDurationSeconds = 300;
uint32 MaxSkill = 450;
uint32 SkillStep = 25;
uint32 LearnProfessionCost = 10000;
uint32 SkillStepCost = 50000;
uint32 LearnRecipesCost = 100000;
bool AllowPrimaryProfessionLimitBypass = true;

ProfessionTemplate const* GetProfessionByAction(uint32 action, uint32 base)
{
    if (action < base)
        return nullptr;

    uint32 index = action - base;
    if (index >= Professions.size())
        return nullptr;

    return &Professions[index];
}

uint16 GetSkillTierMax(uint32 skillValue)
{
    if (skillValue <= 75)
        return 75;
    if (skillValue <= 150)
        return 150;
    if (skillValue <= 225)
        return 225;
    if (skillValue <= 300)
        return 300;
    if (skillValue <= 375)
        return 375;

    return 450;
}

uint16 GetSkillStepForMax(uint32 maxValue)
{
    if (maxValue <= 75)
        return 1;
    if (maxValue <= 150)
        return 2;
    if (maxValue <= 225)
        return 3;
    if (maxValue <= 300)
        return 4;
    if (maxValue <= 375)
        return 5;

    return 6;
}

std::string MoneyText(uint32 copper)
{
    if (!copper)
        return "free";

    uint32 gold = copper / 10000;
    uint32 silver = (copper % 10000) / 100;
    uint32 bronze = copper % 100;

    std::string result;
    if (gold)
        result += std::to_string(gold) + "g";
    if (silver)
        result += (result.empty() ? "" : " ") + std::to_string(silver) + "s";
    if (bronze || result.empty())
        result += (result.empty() ? "" : " ") + std::to_string(bronze) + "c";

    return result;
}

bool Charge(Player* player, uint32 cost)
{
    if (!cost)
        return true;

    if (player->GetMoney() < cost)
    {
        ChatHandler(player->GetSession()).SendNotification("You do not have enough gold.");
        return false;
    }

    player->ModifyMoney(-static_cast<int32>(cost));
    return true;
}

void Notify(Player* player, char const* message)
{
    ChatHandler(player->GetSession()).SendNotification(message);
}

uint32 CountPrimaryProfessions(Player* player)
{
    uint32 count = 0;

    for (ProfessionTemplate const& profession : Professions)
    {
        if (profession.Primary && player->HasSkill(profession.SkillId))
            ++count;
    }

    return count;
}

void LearnAvailableRecipes(Player* player, ProfessionTemplate const& profession)
{
    uint32 skillValue = player->GetPureSkillValue(profession.SkillId);
    if (!skillValue)
        return;

    for (SkillLineAbilityEntry const* skillLine : GetSkillLineAbilitiesBySkillLine(profession.SkillId))
    {
        if (!skillLine)
            continue;

        if (skillLine->SupercededBySpell)
            continue;

        if (skillLine->RaceMask && !(skillLine->RaceMask & player->getRaceMask()))
            continue;

        if (skillLine->ClassMask && !(skillLine->ClassMask & player->getClassMask()))
            continue;

        if (skillLine->AcquireMethod == SKILL_LINE_ABILITY_LEARNED_ON_SKILL_VALUE && skillLine->MinSkillLineRank > skillValue)
            continue;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(skillLine->Spell);
        if (!spellInfo || !SpellMgr::IsSpellValid(spellInfo))
            continue;

        if (!player->HasSpell(skillLine->Spell))
            player->learnSpell(skillLine->Spell, false, true);
    }
}

void ShowMainMenu(Player* player, Creature* creature)
{
    ClearGossipMenuFor(player);
    AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Learn a profession (" + MoneyText(LearnProfessionCost) + ")", GOSSIP_SENDER_MAIN, ACTION_LEARN_PROFESSION);
    AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Increase profession skill (" + MoneyText(SkillStepCost) + ")", GOSSIP_SENDER_MAIN, ACTION_SKILL_UP);
    AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Learn available recipes (" + MoneyText(LearnRecipesCost) + ")", GOSSIP_SENDER_MAIN, ACTION_LEARN_RECIPES);
    if (creature->IsSummon())
        if (TempSummon* summon = creature->ToTempSummon())
            if (summon->GetSummonerGUID() == player->GetGUID())
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Dismiss summoned trainer", GOSSIP_SENDER_MAIN, ACTION_DISMISS);
    SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
}

void GrantProfessionBeacon(Player* player)
{
    if (!player || !GrantBeaconOnLogin || !BeaconItemEntry)
        return;

    if (!player->HasItemCount(BeaconItemEntry, 1, true))
        player->AddItem(BeaconItemEntry, 1);
}

bool SummonProfessionMaster(Player* player)
{
    if (!player || !TrainerNpcEntry)
        return false;

    if (Creature* existing = player->FindNearestCreature(TrainerNpcEntry, 15.0f, true))
        if (existing->IsSummon())
            if (TempSummon* summon = existing->ToTempSummon())
                if (summon->GetSummonerGUID() == player->GetGUID())
                    existing->DespawnOrUnsummon();

    float x = player->GetPositionX();
    float y = player->GetPositionY();
    float z = player->GetPositionZ();
    player->GetClosePoint(x, y, z, player->GetObjectSize(), 2.0f);
    float orientation = player->GetOrientation() + 3.14159f;
    uint32 durationMs = BeaconSummonDurationSeconds * 1000;

    Creature* summon = player->SummonCreature(TrainerNpcEntry, x, y, z, orientation, TEMPSUMMON_TIMED_DESPAWN, durationMs);
    if (!summon)
    {
        Notify(player, "The Profession Master could not be summoned.");
        return false;
    }

    Notify(player, "Profession Master summoned.");
    return true;
}

void ShowProfessionMenu(Player* player, Creature* creature, uint32 actionBase)
{
    ClearGossipMenuFor(player);

    for (std::size_t i = 0; i < Professions.size(); ++i)
    {
        ProfessionTemplate const& profession = Professions[i];
        std::string label = profession.Name;

        if (player->HasSkill(profession.SkillId))
        {
            label += " (";
            label += std::to_string(player->GetPureSkillValue(profession.SkillId));
            label += "/";
            label += std::to_string(player->GetPureMaxSkillValue(profession.SkillId));
            label += ")";
        }

        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, label, GOSSIP_SENDER_MAIN, actionBase + static_cast<uint32>(i));
    }

    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, ACTION_BACK);
    SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
}

void LearnProfession(Player* player, Creature* creature, ProfessionTemplate const& profession)
{
    if (player->HasSkill(profession.SkillId))
    {
        Notify(player, "You already know that profession.");
        ShowMainMenu(player, creature);
        return;
    }

    if (profession.Primary && !AllowPrimaryProfessionLimitBypass && (CountPrimaryProfessions(player) >= 2 || !player->GetFreePrimaryProfessionPoints()))
    {
        Notify(player, "You already know two primary professions.");
        ShowMainMenu(player, creature);
        return;
    }

    if (!Charge(player, LearnProfessionCost))
    {
        ShowMainMenu(player, creature);
        return;
    }

    if (!player->HasSpell(profession.BaseSpellId))
        player->learnSpell(profession.BaseSpellId);

    if (!player->HasSkill(profession.SkillId))
        player->SetSkill(profession.SkillId, 1, 1, 75);

    player->learnSkillRewardedSpells(profession.SkillId, player->GetPureSkillValue(profession.SkillId));
    Notify(player, "Profession learned.");
    ShowMainMenu(player, creature);
}

void IncreaseSkill(Player* player, Creature* creature, ProfessionTemplate const& profession)
{
    if (!player->HasSkill(profession.SkillId))
    {
        Notify(player, "You do not know that profession yet.");
        ShowMainMenu(player, creature);
        return;
    }

    uint32 current = player->GetPureSkillValue(profession.SkillId);
    if (current >= MaxSkill)
    {
        Notify(player, "That profession is already at the configured cap.");
        ShowMainMenu(player, creature);
        return;
    }

    if (!Charge(player, SkillStepCost))
    {
        ShowMainMenu(player, creature);
        return;
    }

    uint32 newValue = std::min<uint32>(current + SkillStep, MaxSkill);
    uint16 tierMax = GetSkillTierMax(newValue);

    player->SetSkill(profession.SkillId, GetSkillStepForMax(tierMax), static_cast<uint16>(newValue), tierMax);
    player->learnSkillRewardedSpells(profession.SkillId, newValue);
    Notify(player, "Profession skill increased.");
    ShowMainMenu(player, creature);
}

void LearnRecipes(Player* player, Creature* creature, ProfessionTemplate const& profession)
{
    if (!player->HasSkill(profession.SkillId))
    {
        Notify(player, "You do not know that profession yet.");
        ShowMainMenu(player, creature);
        return;
    }

    if (!Charge(player, LearnRecipesCost))
    {
        ShowMainMenu(player, creature);
        return;
    }

    LearnAvailableRecipes(player, profession);
    player->learnSkillRewardedSpells(profession.SkillId, player->GetPureSkillValue(profession.SkillId));
    Notify(player, "Available recipes learned.");
    ShowMainMenu(player, creature);
}
}

class profession_master_worldscript : public WorldScript
{
public:
    profession_master_worldscript() : WorldScript("profession_master_worldscript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        Enabled = sConfigMgr->GetOption<bool>("ProfessionMaster.Enable", true);
        TrainerNpcEntry = sConfigMgr->GetOption<uint32>("ProfessionMaster.TrainerNpcEntry", 190020);
        BeaconItemEntry = sConfigMgr->GetOption<uint32>("ProfessionMaster.BeaconItemEntry", 900020);
        GrantBeaconOnLogin = sConfigMgr->GetOption<bool>("ProfessionMaster.GrantBeaconOnLogin", true);
        BeaconSummonDurationSeconds = sConfigMgr->GetOption<uint32>("ProfessionMaster.BeaconSummonDurationSeconds", 300);
        MaxSkill = std::min<uint32>(sConfigMgr->GetOption<uint32>("ProfessionMaster.MaxSkill", 450), 450);
        SkillStep = std::max<uint32>(sConfigMgr->GetOption<uint32>("ProfessionMaster.SkillStep", 25), 1);
        LearnProfessionCost = sConfigMgr->GetOption<uint32>("ProfessionMaster.LearnProfessionCostCopper", 10000);
        SkillStepCost = sConfigMgr->GetOption<uint32>("ProfessionMaster.SkillStepCostCopper", 50000);
        LearnRecipesCost = sConfigMgr->GetOption<uint32>("ProfessionMaster.LearnRecipesCostCopper", 100000);
        AllowPrimaryProfessionLimitBypass = sConfigMgr->GetOption<bool>("ProfessionMaster.AllowPrimaryProfessionLimitBypass", true);
    }
};

class profession_master_playerscript : public PlayerScript
{
public:
    profession_master_playerscript() : PlayerScript("profession_master_playerscript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (Enabled)
            GrantProfessionBeacon(player);
    }
};

class npc_profession_master : public CreatureScript
{
public:
    npc_profession_master() : CreatureScript("npc_profession_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!Enabled || creature->GetEntry() != TrainerNpcEntry)
            return false;

        ShowMainMenu(player, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!Enabled || creature->GetEntry() != TrainerNpcEntry)
            return false;

        ClearGossipMenuFor(player);

        switch (action)
        {
            case ACTION_LEARN_PROFESSION:
                ShowProfessionMenu(player, creature, ACTION_LEARN_PROFESSION + 1);
                return true;
            case ACTION_SKILL_UP:
                ShowProfessionMenu(player, creature, ACTION_SKILL_UP + 1);
                return true;
            case ACTION_LEARN_RECIPES:
                ShowProfessionMenu(player, creature, ACTION_LEARN_RECIPES + 1);
                return true;
            case ACTION_BACK:
                ShowMainMenu(player, creature);
                return true;
            case ACTION_DISMISS:
                if (creature->IsSummon())
                    if (TempSummon* summon = creature->ToTempSummon())
                        if (summon->GetSummonerGUID() == player->GetGUID())
                        {
                            CloseGossipMenuFor(player);
                            creature->DespawnOrUnsummon();
                            return true;
                        }

                ShowMainMenu(player, creature);
                return true;
            default:
                break;
        }

        if (ProfessionTemplate const* profession = GetProfessionByAction(action, ACTION_LEARN_PROFESSION + 1))
        {
            LearnProfession(player, creature, *profession);
            return true;
        }

        if (ProfessionTemplate const* profession = GetProfessionByAction(action, ACTION_SKILL_UP + 1))
        {
            IncreaseSkill(player, creature, *profession);
            return true;
        }

        if (ProfessionTemplate const* profession = GetProfessionByAction(action, ACTION_LEARN_RECIPES + 1))
        {
            LearnRecipes(player, creature, *profession);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

class item_profession_master_beacon : public ItemScript
{
public:
    item_profession_master_beacon() : ItemScript("item_profession_master_beacon") { }

    bool OnUse(Player* player, Item* /*item*/, SpellCastTargets const& /*targets*/) override
    {
        if (!Enabled)
            return true;

        SummonProfessionMaster(player);
        player->InterruptNonMeleeSpells(false);
        return true;
    }
};

void AddProfessionMasterScripts()
{
    new profession_master_worldscript();
    new profession_master_playerscript();
    new npc_profession_master();
    new item_profession_master_beacon();
}
