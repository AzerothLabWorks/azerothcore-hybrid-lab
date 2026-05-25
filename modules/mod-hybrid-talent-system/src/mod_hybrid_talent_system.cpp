#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DatabaseEnv.h"
#include "GossipDef.h"
#include "Log.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include "WorldScript.h"

#include <algorithm>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace
{
    using namespace Acore::ChatCommands;

    struct HybridSpellTemplate
    {
        uint32 SpellId = 0;
        uint32 ClassMask = 0;
        uint8 RequiredLevel = 1;
        uint16 Cost = 1;
        std::string Category;
        uint8 RoleMask = 0;
        uint32 Flags = 0;
    };

    struct HybridSynergyTemplate
    {
        uint32 RequiredSpell1 = 0;
        uint32 RequiredSpell2 = 0;
        uint32 RewardSpell = 0;
    };

    bool Enabled = true;
    uint8 MinLevel = 10;
    uint16 PointsPerInterval = 1;
    uint8 PointIntervalLevels = 2;
    uint16 MaxPoints = 35;
    uint32 ResetCostCopper = 100000;
    uint32 TrainerNpcEntry = 190010;
    bool RestoreOnLogin = true;
    bool EnableSynergies = true;
    bool AutoUpgradeRanks = true;

    std::map<uint32, HybridSpellTemplate> SpellTemplates;
    std::vector<HybridSynergyTemplate> SynergyTemplates;

    enum HybridActions : uint32
    {
        ACTION_STATUS = GOSSIP_ACTION_INFO_DEF + 1,
        ACTION_BROWSE = GOSSIP_ACTION_INFO_DEF + 2,
        ACTION_RESET_CONFIRM = GOSSIP_ACTION_INFO_DEF + 3,
        ACTION_RESET_EXECUTE = GOSSIP_ACTION_INFO_DEF + 4,
        ACTION_LEARN_BASE = GOSSIP_ACTION_INFO_DEF + 100000
    };

    uint16 CalculateEarnedPoints(Player const* player)
    {
        if (!player || player->GetLevel() < MinLevel)
            return 0;

        uint8 interval = PointIntervalLevels ? PointIntervalLevels : 1;
        uint16 points = static_cast<uint16>(((player->GetLevel() - MinLevel) / interval + 1) * PointsPerInterval);
        return std::min<uint16>(points, MaxPoints);
    }

    uint16 GetSpentPoints(ObjectGuid::LowType guid)
    {
        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return 0;

        uint16 spent = 0;
        do
        {
            uint32 spellId = (*result)[0].Get<uint32>();
            auto itr = SpellTemplates.find(spellId);
            if (itr != SpellTemplates.end())
                spent += itr->second.Cost;
        } while (result->NextRow());

        return spent;
    }

    bool IsAllowedForPlayer(Player const* player, HybridSpellTemplate const& templ)
    {
        if (!player)
            return false;

        if (player->GetLevel() < templ.RequiredLevel)
            return false;

        if (templ.ClassMask && (templ.ClassMask & player->getClassMask()))
            return false;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
        if (!spellInfo)
            return false;

        return true;
    }

    uint32 GetFirstRankSpellId(uint32 spellId)
    {
        if (uint32 firstRank = sSpellMgr->GetFirstSpellInChain(spellId))
            return firstRank;

        return spellId;
    }

    bool IsSameSpellChain(uint32 leftSpellId, uint32 rightSpellId)
    {
        return GetFirstRankSpellId(leftSpellId) == GetFirstRankSpellId(rightSpellId);
    }

    bool HasHybridSpellInChain(ObjectGuid::LowType guid, uint32 spellId)
    {
        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return false;

        do
        {
            if (IsSameSpellChain((*result)[0].Get<uint32>(), spellId))
                return true;
        } while (result->NextRow());

        return false;
    }

    bool PlayerHasSpellInChain(Player const* player, uint32 spellId)
    {
        if (!player)
            return false;

        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
            if (player->HasSpell(currentSpellId))
                return true;

        return player->HasSpell(spellId);
    }

    void SaveHybridSpell(ObjectGuid::LowType guid, uint32 spellId)
    {
        CharacterDatabase.Execute("REPLACE INTO character_hybrid_spell (guid, spell_id) VALUES ({}, {})", guid, spellId);
    }

    void DeleteHybridSpells(ObjectGuid::LowType guid)
    {
        CharacterDatabase.Execute("DELETE FROM character_hybrid_spell WHERE guid = {}", guid);
    }

    std::set<uint32> GetKnownHybridSpellIds(ObjectGuid::LowType guid)
    {
        std::set<uint32> spellIds;

        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return spellIds;

        do
        {
            Field* fields = result->Fetch();
            spellIds.insert(fields[0].Get<uint32>());
        } while (result->NextRow());

        return spellIds;
    }

    uint32 GetBestHybridSpellRankForPlayer(Player const* player, uint32 spellId)
    {
        if (!player)
            return spellId;

        uint32 bestSpellId = spellId;
        for (uint32 nextSpellId = sSpellMgr->GetNextSpellInChain(bestSpellId); nextSpellId; nextSpellId = sSpellMgr->GetNextSpellInChain(bestSpellId))
        {
            SpellInfo const* nextSpellInfo = sSpellMgr->GetSpellInfo(nextSpellId);
            if (!nextSpellInfo)
                break;

            if (nextSpellInfo->SpellLevel && player->GetLevel() < nextSpellInfo->SpellLevel)
                break;

            bestSpellId = nextSpellId;
        }

        return bestSpellId;
    }

    void RemoveHybridSpellRanks(Player* player, uint32 spellId, uint32 exceptSpellId = 0)
    {
        if (!player)
            return;

        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
        {
            if (currentSpellId == exceptSpellId)
                continue;

            if (player->HasSpell(currentSpellId))
                player->removeSpell(currentSpellId, SPEC_MASK_ALL, false);
        }

        if (firstRank == spellId)
            return;

        if (!sSpellMgr->GetSpellInfo(firstRank) && player->HasSpell(spellId) && spellId != exceptSpellId)
            player->removeSpell(spellId, SPEC_MASK_ALL, false);
    }

    void UpdateHybridActionButtons(Player* player, uint32 spellId, uint32 bestSpellId)
    {
        if (!player)
            return;

        bool changed = false;
        std::set<uint32> chainSpellIds;
        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
            chainSpellIds.insert(currentSpellId);

        if (chainSpellIds.empty())
            chainSpellIds.insert(spellId);

        for (uint32 currentSpellId : chainSpellIds)
        {
            if (currentSpellId == bestSpellId)
                continue;

            for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            {
                ActionButton const* actionButton = player->GetActionButton(button);
                if (!actionButton || actionButton->GetType() != ACTION_BUTTON_SPELL || actionButton->GetAction() != currentSpellId)
                    continue;

                if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                    changed = true;
            }
        }

        QueryResult result = CharacterDatabase.Query("SELECT button, action FROM character_action WHERE guid = {} AND spec = {} AND type = {}",
            player->GetGUID().GetCounter(), player->GetActiveSpec(), ACTION_BUTTON_SPELL);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint8 button = fields[0].Get<uint8>();
                uint32 action = fields[1].Get<uint32>();

                if (!chainSpellIds.count(action))
                    continue;

                ActionButton const* actionButton = player->GetActionButton(button);
                if (actionButton && actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction() == bestSpellId)
                    continue;

                if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                    changed = true;
            } while (result->NextRow());
        }

        if (changed)
            player->SendActionButtons(1);
    }

    void RemoveHybridActionButtons(Player* player, uint32 spellId)
    {
        if (!player)
            return;

        bool changed = false;
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
        {
            for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            {
                ActionButton const* actionButton = player->GetActionButton(button);
                if (!actionButton || actionButton->GetType() != ACTION_BUTTON_SPELL || actionButton->GetAction() != currentSpellId)
                    continue;

                player->removeActionButton(button);
                changed = true;
            }

            CharacterDatabase.Execute("DELETE FROM character_action WHERE guid = {} AND type = {} AND action = {}", guid, ACTION_BUTTON_SPELL, currentSpellId);
        }

        if (changed)
            player->SendActionButtons(1);
    }

    uint32 LearnBestHybridSpellRank(Player* player, uint32 spellId)
    {
        if (!player)
            return spellId;

        uint32 bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;

        if (!player->HasSpell(bestSpellId))
            player->learnSpell(bestSpellId, false);

        UpdateHybridActionButtons(player, spellId, bestSpellId);
        RemoveHybridSpellRanks(player, spellId, bestSpellId);

        return bestSpellId;
    }

    void ApplySynergies(Player* player)
    {
        if (!EnableSynergies || !player)
            return;

        std::set<uint32> known = GetKnownHybridSpellIds(player->GetGUID().GetCounter());

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            bool qualifies = known.count(synergy.RequiredSpell1) && known.count(synergy.RequiredSpell2);

            if (qualifies && !player->HasSpell(synergy.RewardSpell))
                player->learnSpell(synergy.RewardSpell, false);
            else if (!qualifies && player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }
    }

    void RestoreHybridSpells(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::set<uint32> spellIds = GetKnownHybridSpellIds(guid);

        for (uint32 spellId : spellIds)
        {
            if (!SpellTemplates.count(spellId))
                continue;

            LearnBestHybridSpellRank(player, spellId);
        }

        ApplySynergies(player);
    }

    void ResetHybridBuild(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::set<uint32> spellIds = GetKnownHybridSpellIds(guid);

        for (uint32 spellId : spellIds)
        {
            RemoveHybridActionButtons(player, spellId);
            RemoveHybridSpellRanks(player, spellId);
        }

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            RemoveHybridActionButtons(player, synergy.RewardSpell);
            if (player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }

        DeleteHybridSpells(guid);
    }

    void LoadConfig()
    {
        Enabled = sConfigMgr->GetOption<bool>("HybridTalentSystem.Enable", true);
        MinLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MinLevel", 10));
        PointsPerInterval = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointsPerInterval", 1));
        PointIntervalLevels = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointIntervalLevels", 2));
        MaxPoints = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MaxPoints", 35));
        ResetCostCopper = sConfigMgr->GetOption<uint32>("HybridTalentSystem.ResetCostCopper", 100000);
        TrainerNpcEntry = sConfigMgr->GetOption<uint32>("HybridTalentSystem.TrainerNpcEntry", 190010);
        RestoreOnLogin = sConfigMgr->GetOption<bool>("HybridTalentSystem.RestoreOnLogin", true);
        EnableSynergies = sConfigMgr->GetOption<bool>("HybridTalentSystem.EnableSynergies", true);
        AutoUpgradeRanks = sConfigMgr->GetOption<bool>("HybridTalentSystem.AutoUpgradeRanks", true);
    }

    void LoadTemplates()
    {
        SpellTemplates.clear();
        SynergyTemplates.clear();

        QueryResult tableResult = WorldDatabase.Query("SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hybrid_spell_template' LIMIT 1");
        if (!tableResult)
        {
            LOG_WARN("module.hybridtalents", "Hybrid Talent System tables are missing. Import the module SQL or enable DB updates before using the module.");
            return;
        }

        QueryResult spellResult = WorldDatabase.Query("SELECT spell_id, class_mask, required_level, cost, category, role_mask, flags FROM hybrid_spell_template");
        if (spellResult)
        {
            do
            {
                Field* fields = spellResult->Fetch();

                HybridSpellTemplate templ;
                templ.SpellId = fields[0].Get<uint32>();
                templ.ClassMask = fields[1].Get<uint32>();
                templ.RequiredLevel = fields[2].Get<uint8>();
                templ.Cost = fields[3].Get<uint16>();
                templ.Category = fields[4].Get<std::string>();
                templ.RoleMask = fields[5].Get<uint8>();
                templ.Flags = fields[6].Get<uint32>();

                if (sSpellMgr->GetSpellInfo(templ.SpellId))
                    SpellTemplates[templ.SpellId] = templ;
            } while (spellResult->NextRow());
        }

        QueryResult synergyResult = WorldDatabase.Query("SELECT required_spell_1, required_spell_2, reward_spell FROM hybrid_synergy_template");
        if (synergyResult)
        {
            do
            {
                Field* fields = synergyResult->Fetch();

                HybridSynergyTemplate templ;
                templ.RequiredSpell1 = fields[0].Get<uint32>();
                templ.RequiredSpell2 = fields[1].Get<uint32>();
                templ.RewardSpell = fields[2].Get<uint32>();

                if (sSpellMgr->GetSpellInfo(templ.RewardSpell))
                    SynergyTemplates.push_back(templ);
            } while (synergyResult->NextRow());
        }
    }

    void SendMainMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View hybrid status", GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Learn hybrid spells", GOSSIP_SENDER_MAIN, ACTION_BROWSE);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Reset hybrid build", GOSSIP_SENDER_MAIN, ACTION_RESET_CONFIRM);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void SendBrowseMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        uint16 earned = CalculateEarnedPoints(player);
        uint16 spent = GetSpentPoints(player->GetGUID().GetCounter());
        uint16 available = earned > spent ? earned - spent : 0;

        bool foundSpell = false;
        for (auto const& pair : SpellTemplates)
        {
            HybridSpellTemplate const& templ = pair.second;
            if (!IsAllowedForPlayer(player, templ))
                continue;

            if (HasHybridSpellInChain(player->GetGUID().GetCounter(), templ.SpellId))
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
            std::string label = spellInfo ? spellInfo->SpellName[0] : std::to_string(templ.SpellId);
            label += " - ";
            label += std::to_string(templ.Cost);
            label += " point";
            label += templ.Cost == 1 ? "" : "s";

            if (available < templ.Cost)
                label += " (not enough points)";

            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, label, GOSSIP_SENDER_MAIN, ACTION_LEARN_BASE + templ.SpellId);
            foundSpell = true;
        }

        if (!foundSpell)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No hybrid spells are currently available.", GOSSIP_SENDER_MAIN, 0);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    bool TryLearnHybridSpell(Player* player, uint32 spellId)
    {
        auto itr = SpellTemplates.find(spellId);
        if (itr == SpellTemplates.end())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That spell is not available as a hybrid spell.");
            return false;
        }

        HybridSpellTemplate const& templ = itr->second;
        if (!IsAllowedForPlayer(player, templ))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not meet the requirements for that spell.");
            return false;
        }

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        if (HasHybridSpellInChain(guid, spellId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already know that spell.");
            return false;
        }

        if (PlayerHasSpellInChain(player, spellId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already know that spell.");
            return false;
        }

        uint16 earned = CalculateEarnedPoints(player);
        uint16 spent = GetSpentPoints(guid);
        if (earned < spent || earned - spent < templ.Cost)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough hybrid points.");
            return false;
        }

        SaveHybridSpell(guid, spellId);
        uint32 learnedSpellId = LearnBestHybridSpellRank(player, spellId);
        ApplySynergies(player);
        SpellInfo const* learnedSpellInfo = sSpellMgr->GetSpellInfo(learnedSpellId);
        if (learnedSpellId != spellId && learnedSpellInfo)
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid spell learned and upgraded to {}.", learnedSpellInfo->SpellName[0]);
        else
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid spell learned.");
        return true;
    }
}

class HybridTalentWorldScript : public WorldScript
{
public:
    HybridTalentWorldScript() : WorldScript("HybridTalentWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadConfig();
    }

    void OnStartup() override
    {
        if (!Enabled)
            return;

        LoadTemplates();
    }
};

class HybridTalentPlayerScript : public PlayerScript
{
public:
    HybridTalentPlayerScript() : PlayerScript("HybridTalentPlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (Enabled && RestoreOnLogin)
            RestoreHybridSpells(player);
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (Enabled)
            RestoreHybridSpells(player);
    }
};

class HybridTalentTrainerScript : public CreatureScript
{
public:
    HybridTalentTrainerScript() : CreatureScript("npc_hybrid_talent_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!Enabled || creature->GetEntry() != TrainerNpcEntry)
            return false;

        if (player->GetLevel() < MinLevel)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid training unlocks at level {}.", MinLevel);
            return true;
        }

        player->TalkedToCreature(creature->GetEntry(), creature->GetGUID());
        SendMainMenu(player, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        if (action == 0)
        {
            SendMainMenu(player, creature);
            return true;
        }

        if (action == ACTION_STATUS)
        {
            uint16 earned = CalculateEarnedPoints(player);
            uint16 spent = GetSpentPoints(player->GetGUID().GetCounter());
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid points: {} earned, {} spent, {} available.", earned, spent, earned > spent ? earned - spent : 0);
            SendMainMenu(player, creature);
            return true;
        }

        if (action == ACTION_BROWSE)
        {
            SendBrowseMenu(player, creature);
            return true;
        }

        if (action == ACTION_RESET_CONFIRM)
        {
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Confirm reset", GOSSIP_SENDER_MAIN, ACTION_RESET_EXECUTE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        if (action == ACTION_RESET_EXECUTE)
        {
            if (ResetCostCopper && !player->HasEnoughMoney(ResetCostCopper))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You need {} gold to reset your hybrid build.", ResetCostCopper / 10000);
                SendMainMenu(player, creature);
                return true;
            }

            if (ResetCostCopper)
                player->ModifyMoney(-static_cast<int32>(ResetCostCopper));

            ResetHybridBuild(player);
            ChatHandler(player->GetSession()).PSendSysMessage("Your hybrid build has been reset.");
            SendMainMenu(player, creature);
            return true;
        }

        if (action >= ACTION_LEARN_BASE)
        {
            TryLearnHybridSpell(player, action - ACTION_LEARN_BASE);
            SendBrowseMenu(player, creature);
            return true;
        }

        SendMainMenu(player, creature);
        return true;
    }
};

class HybridTalentCommandScript : public CommandScript
{
public:
    HybridTalentCommandScript() : CommandScript("HybridTalentCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable hybridCommands =
        {
            { "reload", HandleReloadCommand, SEC_ADMINISTRATOR, Console::No },
            { "reset",  HandleResetCommand,  SEC_ADMINISTRATOR, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "hybrid", hybridCommands }
        };

        return commandTable;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        LoadConfig();
        LoadTemplates();
        handler->PSendSysMessage("Hybrid Talent System templates reloaded. {} spells, {} synergies.", static_cast<uint32>(SpellTemplates.size()), static_cast<uint32>(SynergyTemplates.size()));
        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler)
    {
        Player* target = handler->getSelectedPlayer();
        if (!target)
        {
            handler->PSendSysMessage("Select a player first.");
            return false;
        }

        ResetHybridBuild(target);
        handler->PSendSysMessage("Hybrid build reset for {}.", target->GetName());
        return true;
    }
};

void AddHybridTalentSystemScripts()
{
    new HybridTalentWorldScript();
    new HybridTalentPlayerScript();
    new HybridTalentTrainerScript();
    new HybridTalentCommandScript();
}
